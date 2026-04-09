#!/bin/sh

set -eu

usage() {
  echo "usage: $0 <fetch|sync> </absolute/path/to/diary-file>" >&2
  exit 64
}

emit_kv() {
  key=$1
  value=$2
  printf '%s=%s\n' "$key" "$value"
}

emit_error() {
  emit_kv status error
  emit_kv message "$1"
  exit "${2:-2}"
}

fetch_upstream() {
  git -C "$repo_root" fetch --quiet "$remote" "$remote_ref"
}

update_counts() {
  if [ -n "$upstream" ]; then
    set -- $(git -C "$repo_root" rev-list --left-right --count HEAD..."$upstream")
    ahead=$1
    behind=$2
  else
    ahead=0
    behind=0
  fi
}

rebase_onto_upstream() {
  if [ -z "$upstream" ] || [ "$behind" -eq 0 ]; then
    return 0
  fi

  if git -C "$repo_root" diff --quiet --ignore-submodules -- \
    && git -C "$repo_root" diff --cached --quiet --ignore-submodules --
  then
    if git -C "$repo_root" rebase "$upstream" >/dev/null 2>&1; then
      rebased=1
      update_counts
      return 0
    fi
  elif git -C "$repo_root" rebase --autostash "$upstream" >/dev/null 2>&1; then
    rebased=1
    update_counts
    return 0
  fi

  git -C "$repo_root" rebase --abort >/dev/null 2>&1 || true
  return 1
}

push_branch() {
  if [ -n "$upstream" ]; then
    git -C "$repo_root" push --quiet "$remote" "HEAD:$remote_ref"
  else
    git -C "$repo_root" push --quiet -u "$remote" "$branch"
    upstream="$remote/$branch"
    remote_ref=$branch
  fi
}

[ $# -eq 2 ] || usage
mode=$1
file_path=$2

case "$mode" in
  fetch|sync) ;;
  *) usage ;;
esac

case "$file_path" in
  /*) ;;
  *) emit_error "file path must be absolute" ;;
esac

[ -f "$file_path" ] || emit_error "file does not exist: $file_path"

file_name=$(basename "$file_path")
file_dir=$(cd "$(dirname "$file_path")" && pwd -P)
file_path=$file_dir/$file_name

repo_root_raw=$(git -C "$file_dir" rev-parse --show-toplevel 2>/dev/null || true)
[ -n "$repo_root_raw" ] || emit_error "file is not inside a git repository"
repo_root=$(cd "$repo_root_raw" && pwd -P)
[ -n "$repo_root" ] || emit_error "file is not inside a git repository"

case "$file_path" in
  "$repo_root"/*) rel_path=${file_path#"$repo_root"/} ;;
  *) emit_error "unable to compute repository-relative path" ;;
esac

branch=$(git -C "$repo_root" branch --show-current 2>/dev/null || true)
[ -n "$branch" ] || emit_error "detached HEAD is not supported for diary sync"

upstream=$(git -C "$repo_root" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)
if [ -n "$upstream" ]; then
  remote=${upstream%%/*}
  remote_ref=${upstream#*/}
else
  remote=origin
  remote_ref=$branch
fi

state_dir=${XDG_STATE_HOME:-"$HOME/.local/state"}/nvim/diary-sync
mkdir -p "$state_dir"
lock_name=$(printf '%s:%s\n' "$repo_root" "$branch" | tr '/:[:space:]' '_')
lock_dir=$state_dir/"$lock_name".lock

if ! mkdir "$lock_dir" 2>/dev/null; then
  emit_kv mode "$mode"
  emit_kv repo "$repo_root"
  emit_kv path "$rel_path"
  emit_kv status busy
  emit_kv message "another diary sync job is already running"
  exit 0
fi

cleanup() {
  rmdir "$lock_dir" 2>/dev/null || true
}

trap cleanup EXIT HUP INT TERM

ahead=0
behind=0
committed=0
rebased=0
pushed=0

emit_kv mode "$mode"
emit_kv repo "$repo_root"
emit_kv path "$rel_path"
emit_kv branch "$branch"
emit_kv upstream "$upstream"

fetch_upstream || emit_error "git fetch failed"
update_counts

if [ "$mode" = "fetch" ]; then
  emit_kv status ok
  emit_kv ahead "$ahead"
  emit_kv behind "$behind"
  exit 0
fi

git -C "$repo_root" add -- "$rel_path" || emit_error "git add failed"

if ! git -C "$repo_root" diff --cached --quiet -- "$rel_path"; then
  commit_subject=$(basename "$rel_path" .md)
  if git -C "$repo_root" -c commit.gpgsign=false \
    commit -m "chore(diary): sync $commit_subject" -- "$rel_path" >/dev/null 2>&1
  then
    committed=1
  else
    emit_error "git commit failed"
  fi
fi

fetch_upstream || emit_error "git fetch failed after commit"
update_counts

if ! rebase_onto_upstream; then
  emit_kv status conflict
  emit_kv committed "$committed"
  emit_kv rebased "$rebased"
  emit_kv pushed "$pushed"
  emit_kv ahead "$ahead"
  emit_kv behind "$behind"
  emit_kv message "rebase conflict while syncing diary"
  exit 3
fi

if [ -z "$upstream" ] || [ "$ahead" -gt 0 ]; then
  if push_branch >/dev/null 2>&1; then
    pushed=1
    update_counts
  else
    fetch_upstream || emit_error "git fetch failed after push rejection"
    update_counts

    if ! rebase_onto_upstream; then
      emit_kv status conflict
      emit_kv committed "$committed"
      emit_kv rebased "$rebased"
      emit_kv pushed "$pushed"
      emit_kv ahead "$ahead"
      emit_kv behind "$behind"
      emit_kv message "rebase conflict after push rejection"
      exit 3
    fi

    if push_branch >/dev/null 2>&1; then
      pushed=1
      update_counts
    else
      emit_error "git push failed"
    fi
  fi
fi

if [ "$committed" -eq 0 ] && [ "$rebased" -eq 0 ] && [ "$pushed" -eq 0 ]; then
  emit_kv status noop
else
  emit_kv status ok
fi
emit_kv committed "$committed"
emit_kv rebased "$rebased"
emit_kv pushed "$pushed"
emit_kv ahead "$ahead"
emit_kv behind "$behind"
