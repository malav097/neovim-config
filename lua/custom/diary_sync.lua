local M = {}

local FETCH_INTERVAL_MS = 3 * 60 * 1000
local EVENT_FETCH_DEBOUNCE_MS = 30 * 1000

local state = {
  last_behind = 0,
  last_fetch_started_at = 0,
  pending = nil,
  running = false,
  setup_done = false,
  timer = nil,
  timer_active = false,
}

local function normalize_path(path)
  if path == nil or path == '' then
    return ''
  end

  local expanded = vim.fn.fnamemodify(vim.fn.expand(path), ':p')
  local real = vim.uv.fs_realpath(expanded)
  return vim.fs.normalize(real or expanded)
end

local function primary_diary_dir()
  local wiki = vim.g.vimwiki_list and vim.g.vimwiki_list[1] or {}
  local root = wiki.path or '~/Dropbox/log'
  local rel_path = wiki.diary_rel_path or 'diary/monthly/'
  return normalize_path(root .. '/' .. rel_path)
end

local function current_month_path()
  return normalize_path(primary_diary_dir() .. '/' .. os.date('%Y-%m-01.md'))
end

local function script_path()
  return normalize_path(vim.fn.stdpath('config') .. '/scripts/diary-sync.sh')
end

local function parse_output(text)
  local result = {}
  if text == nil or text == '' then
    return result
  end

  for line in text:gmatch('[^\r\n]+') do
    local key, value = line:match('^([%w_]+)=(.*)$')
    if key ~= nil then
      result[key] = value
    end
  end

  return result
end

local function target_buffer_numbers()
  local target = current_month_path()
  local buffers = {}

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and normalize_path(vim.api.nvim_buf_get_name(buf)) == target then
      table.insert(buffers, buf)
    end
  end

  return buffers
end

local function has_target_window()
  local target = current_month_path()

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if normalize_path(vim.api.nvim_buf_get_name(buf)) == target then
      return true
    end
  end

  return false
end

local function is_target_buffer(bufnr)
  return normalize_path(vim.api.nvim_buf_get_name(bufnr)) == current_month_path()
end

local function run_checktime_for_target()
  for _, buf in ipairs(target_buffer_numbers()) do
    if vim.api.nvim_buf_is_valid(buf) and not vim.bo[buf].modified then
      vim.cmd('silent! checktime ' .. buf)
    end
  end
end

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = 'Diary Sync' })
end

local function notify_async(message, level, delay_ms)
  vim.defer_fn(function()
    notify(message, level)
  end, delay_ms or 0)
end

local function sync_success_message(result)
  local committed = result.committed == '1'
  local rebased = result.rebased == '1'
  local pushed = result.pushed == '1'
  local actions = {}

  if committed then
    table.insert(actions, 'commit')
  end
  if rebased then
    table.insert(actions, 'rebase')
  end
  if pushed then
    table.insert(actions, 'push')
  end

  if #actions == 0 then
    return 'Sync del diario completado. No había cambios nuevos para subir.'
  end

  return 'Sync del diario completado: ' .. table.concat(actions, ' + ')
end

local function handle_result(request, obj)
  local output = table.concat({
    obj.stdout or '',
    obj.stderr or '',
  }, '\n')
  local result = parse_output(output)
  local status = result.status or ((obj.code == 0) and 'ok' or 'error')
  local behind = tonumber(result.behind or '0') or 0
  local committed = result.committed == '1'
  local rebased = result.rebased == '1'
  local pushed = result.pushed == '1'

  if request.mode == 'fetch' then
    if status == 'ok' and behind > 0 then
      vim.schedule(function()
        M.enqueue('pull', request.path)
      end)
    elseif status == 'error' then
      notify(result.message or 'Falló el fetch periódico del diario.', vim.log.levels.ERROR)
    end
  elseif request.mode == 'pull' then
    if status == 'conflict' then
      notify('Conflicto al aplicar cambios remotos del diario.', vim.log.levels.ERROR)
    elseif status == 'error' then
      notify(result.message or 'Falló el pull del diario.', vim.log.levels.ERROR)
    elseif rebased then
      notify('Diario actualizado desde remoto.', vim.log.levels.INFO)
    end
  elseif status == 'conflict' then
    notify('Conflicto real al rebasear el diario. El commit local quedó guardado y el rebase fue abortado.', vim.log.levels.ERROR)
  elseif status == 'error' then
    notify(result.message or 'Falló el autosync del diario.', vim.log.levels.ERROR)
  elseif request.mode == 'sync' and (status == 'ok' or status == 'noop') then
    notify(sync_success_message(result), vim.log.levels.INFO)
  end

  state.last_behind = behind

  if (request.mode == 'sync' or request.mode == 'pull') and status == 'ok' and rebased then
    run_checktime_for_target()
  end

  state.running = false
  if state.pending ~= nil then
    local next_request = state.pending
    state.pending = nil
    M.enqueue(next_request.mode, next_request.path)
  end
end

local function start_request(mode, path)
  state.running = true
  if mode == 'sync' then
    notify_async('Ejecutando sync del diario...', vim.log.levels.INFO, 10)
  end
  vim.system({ script_path(), mode, path }, { text = true }, function(obj)
    vim.schedule(function()
      handle_result({ mode = mode, path = path }, obj)
    end)
  end)
end

function M.enqueue(mode, path)
  local normalized = normalize_path(path)
  if normalized ~= current_month_path() then
    return
  end

  local request = {
    mode = mode,
    path = normalized,
  }

  if state.running then
    local pending_mode = state.pending and state.pending.mode
    if state.pending == nil
      or mode == 'sync'
      or (mode == 'pull' and pending_mode == 'fetch') then
      state.pending = request
    end
    return
  end

  start_request(mode, normalized)
end

local function maybe_fetch(force)
  if not has_target_window() then
    return
  end

  local now = vim.uv.now()
  local min_interval = force and EVENT_FETCH_DEBOUNCE_MS or FETCH_INTERVAL_MS
  if (now - state.last_fetch_started_at) < min_interval then
    return
  end

  local target = current_month_path()
  if target == '' then
    return
  end

  state.last_fetch_started_at = now
  M.enqueue('fetch', target)
end

local function refresh_timer()
  if state.timer == nil then
    state.timer = vim.uv.new_timer()
  end

  if has_target_window() then
    if not state.timer_active then
      state.timer:start(
        FETCH_INTERVAL_MS,
        FETCH_INTERVAL_MS,
        vim.schedule_wrap(function()
          maybe_fetch(false)
        end)
      )
      state.timer_active = true
    end
  elseif state.timer_active then
    state.timer:stop()
    state.timer_active = false
  end
end

function M.setup()
  if state.setup_done then
    return
  end
  state.setup_done = true

  local group = vim.api.nvim_create_augroup('current-month-diary-sync', { clear = true })

  vim.api.nvim_create_autocmd('BufWritePost', {
    group = group,
    callback = function(args)
      if is_target_buffer(args.buf) then
        M.enqueue('sync', vim.api.nvim_buf_get_name(args.buf))
      end
    end,
  })

  vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter', 'FocusGained' }, {
    group = group,
    callback = function(args)
      local buf = args.buf
      if buf == nil or buf == 0 or not vim.api.nvim_buf_is_valid(buf) then
        buf = vim.api.nvim_get_current_buf()
      end

      if is_target_buffer(buf) then
        maybe_fetch(true)
      end
      refresh_timer()
    end,
  })

  vim.api.nvim_create_autocmd({ 'BufLeave', 'BufWinLeave', 'WinClosed' }, {
    group = group,
    callback = function()
      refresh_timer()
    end,
  })

  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function()
      if state.timer ~= nil then
        state.timer:stop()
        state.timer:close()
        state.timer = nil
        state.timer_active = false
      end
    end,
  })

  vim.api.nvim_create_user_command('DiarySyncNow', function()
    if has_target_window() then
      M.enqueue('sync', current_month_path())
      return
    end
    notify('El archivo mensual actual del diario no está abierto.', vim.log.levels.WARN)
  end, { desc = 'Sync the current monthly diary file now' })

  vim.api.nvim_create_user_command('DiaryFetchNow', function()
    if has_target_window() then
      state.last_fetch_started_at = 0
      maybe_fetch(true)
      return
    end
    notify('El archivo mensual actual del diario no está abierto.', vim.log.levels.WARN)
  end, { desc = 'Fetch remote updates for the current monthly diary file' })

  refresh_timer()
end

return M
