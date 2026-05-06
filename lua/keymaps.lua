-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Diagnostic keymaps
-- vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- TIP: Disable arrow keys in normal mode
-- vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
-- vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
-- vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
-- vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
-- vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
-- vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
-- vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
-- vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })
-- malav keymaps

-- NOTE: Some terminals have colliding keymaps or are not able to send distinct keycodes
-- vim.keymap.set("n", "<C-S-h>", "<C-w>H", { desc = "Move window to the left" })
-- vim.keymap.set("n", "<C-S-l>", "<C-w>L", { desc = "Move window to the right" })
-- vim.keymap.set("n", "<C-S-j>", "<C-w>J", { desc = "Move window to the lower" })
-- vim.keymap.set("n", "<C-S-k>", "<C-w>K", { desc = "Move window to the upper" })

-- # Multiline Statements
--
-- old config
--
vim.schedule(function()
  vim.cmd([[
      nnoremap <leader>ff <cmd>Telescope find_files<cr>
      nnoremap <leader>fg <cmd>Telescope live_grep<cr>
      nnoremap <leader>fb <cmd>Telescope buffers<cr>
      nnoremap <leader>fh <cmd>Telescope help_tags<cr>
      nnoremap <leader>a] <cmd> vertical resize +5<cr>
      nnoremap <leader>a[ <cmd> vertical resize -5<cr>
      nnoremap <leader>a' <cmd> resize +5<cr>
      nnoremap <leader>a; <cmd> resize -5<cr>
      nnoremap <leader>ak :wincmd k<CR>
      nnoremap <leader>aj :wincmd j<CR>
      nnoremap <leader>ah :wincmd h<CR>
      nnoremap <leader>al :wincmd l<CR>
      nnoremap <leader>av <cmd>vnew<cr>
      nnoremap <leader>as <cmd>new<cr>
      tnoremap <leader><Esc> <C-\><C-n>j:
  ]])
end)

vim.g.vimwiki_list = {
  {
    path = '~/Dropbox/log',
    syntax = 'markdown',
    ext = '.md',
    diary_frequency = 'monthly',
    diary_rel_path = 'diary/monthly/',
  },
  {
    path = '~/Dropbox/log/general',
    syntax = 'markdown',
    ext = '.md',
    diary_frequency = 'monthly',
    diary_rel_path = 'diary/monthly/',
  },
}

vim.g.vimwiki_diary_frequency = 'monthly'
vim.g.vimwiki_diary_rel_path = 'diary/monthly/'
vim.g.vimwiki_diary_index = 'diary'
vim.g.vimwiki_diary_header = 'Diary'

local function figlet_banner_lines(text)
  if text == nil or text == '' then
    return nil
  end
  if vim.fn.executable("figlet") == 0 then
    return nil
  end

  local out = vim.fn.systemlist({ "figlet", "-f", "alligator", "-k", text })
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return out
end

local function month_name_es(month_num)
  local months = {
    "Enero",
    "Febrero",
    "Marzo",
    "Abril",
    "Mayo",
    "Junio",
    "Julio",
    "Agosto",
    "Septiembre",
    "Octubre",
    "Noviembre",
    "Diciembre",
  }
  return months[month_num]
end

local function year_month_from_filename(path)
  if path == nil or path == '' then
    return nil, nil
  end

  local year, month = path:match('(%d%d%d%d)%-(%d%d)%-%d%d%.md$')
  if year == nil then
    year, month = path:match('(%d%d%d%d)%-(%d%d)%.md$')
  end
  year = tonumber(year)
  month = tonumber(month)
  if year == nil or month == nil or month < 1 or month > 12 then
    return nil, nil
  end
  return year, month
end

local function month_num_from_filename(path)
  local _, month = year_month_from_filename(path)
  return month
end

local function diary_dir_from_path(path)
  if path == nil or path == '' then
    return nil
  end
  local dir = path:match('^(.*)/diary/monthly/')
  if dir == nil or dir == '' then
    return nil
  end
  return dir .. '/diary/monthly/'
end

local function previous_month_year_month(year, month)
  if year == nil or month == nil then
    return nil, nil
  end
  local prev_month = month - 1
  local prev_year = year
  if prev_month < 1 then
    prev_month = 12
    prev_year = year - 1
  end
  return prev_year, prev_month
end

local function is_separator_line(line)
  return line ~= nil and line:match('^%s*=+%s*$') ~= nil
end

local function extract_checkbox_task(line)
  if line == nil then
    return nil, nil
  end
  return line:match('^%s*%- %[(.)%]%s*(.-)%s*$')
end

local function is_task_section_label(text)
  if text == nil or text == '' then
    return false
  end
  local normalized = text:upper():gsub('[%s%-_]', '')
  return normalized == 'TAREASMENSUALES' or normalized == 'TAREASMESPASADO'
end

local function extract_incomplete_task_sections(lines)
  local sections = {}
  if lines == nil then
    return sections
  end

  local current_section = nil
  local can_capture_title = false

  for _, line in ipairs(lines) do
    if is_separator_line(line) then
      current_section = {
        separator = line,
        title = nil,
        tasks = {},
      }
      table.insert(sections, current_section)
      can_capture_title = true
    elseif current_section ~= nil then
      if line:match('^%s*$') then
        -- ignore empty lines while scanning the section
      else
        local marker, text = extract_checkbox_task(line)
        if marker ~= nil then
          can_capture_title = false
          if marker == ' ' and text ~= '' and not is_task_section_label(text) then
            table.insert(current_section.tasks, line)
          end
        elseif can_capture_title and not line:match('^%s*%- ') then
          current_section.title = line
          can_capture_title = false
        end
      end
    end
  end

  local filtered_sections = {}
  for _, section in ipairs(sections) do
    if #section.tasks > 0 then
      table.insert(filtered_sections, section)
    end
  end
  return filtered_sections
end

local function append_task_section(lines, separator, title, tasks)
  if tasks == nil or #tasks == 0 then
    return
  end

  table.insert(lines, '')
  table.insert(lines, separator or '================================================================================ ')
  table.insert(lines, '')
  if title ~= nil and title ~= '' then
    table.insert(lines, title)
    table.insert(lines, '')
  end
  vim.list_extend(lines, tasks)
end

local function normalize_task_lines(tasks, indent)
  local normalized = {}
  local prefix = string.rep(' ', indent or 0) .. '- [ ] '

  if tasks == nil then
    return normalized
  end

  for _, line in ipairs(tasks) do
    local marker, text = extract_checkbox_task(line)
    if marker ~= nil and text ~= nil and text ~= '' then
      table.insert(normalized, prefix .. text)
    end
  end

  return normalized
end

local function previous_month_tasks_lines(year, month, diary_dir)
  local lines = {}
  if year == nil or month == nil or diary_dir == nil or diary_dir == '' then
    return lines
  end

  local prev_year, prev_month = previous_month_year_month(year, month)
  if prev_year == nil or prev_month == nil then
    return lines
  end

  local base_dir = vim.fn.expand(diary_dir)
  if base_dir:sub(-1) ~= '/' then
    base_dir = base_dir .. '/'
  end

  local prev_path = string.format('%s%04d-%02d-01.md', base_dir, prev_year, prev_month)
  if vim.fn.filereadable(prev_path) ~= 1 then
    return lines
  end

  local prev_lines = vim.fn.readfile(prev_path)
  local sections = extract_incomplete_task_sections(prev_lines)
  local untitled_tasks = {}
  local first_untitled_section = nil

  for index, section in ipairs(sections) do
    if section.title == nil or section.title == '' then
      if first_untitled_section == nil then
        first_untitled_section = {
          index = index,
          separator = section.separator,
        }
      end
      vim.list_extend(untitled_tasks, normalize_task_lines(section.tasks, 0))
    end
  end

  local untitled_emitted = false
  for index, section in ipairs(sections) do
    if section.title == nil or section.title == '' then
      if not untitled_emitted and first_untitled_section ~= nil and index == first_untitled_section.index then
        append_task_section(lines, first_untitled_section.separator, 'TAREAS MES PASADO', untitled_tasks)
        untitled_emitted = true
      end
    else
      append_task_section(lines, section.separator, section.title, section.tasks)
    end
  end

  return lines
end

local function monthly_template_lines()
  local buf = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(buf)
  local now = os.date("*t")
  local year, month_num = year_month_from_filename(name)
  if year == nil or month_num == nil then
    year = now.year
    month_num = now.month
  end
  local month_name = month_name_es(month_num) or month_name_es(now.month) or 'Mes'
  local header_lines = figlet_banner_lines(month_name) or { '# ' .. month_name }
  local lines = {}
  vim.list_extend(lines, header_lines)
  vim.list_extend(lines, {
    '',
    '================================================================================ ',
    '',
    '- [ ] TAREAS-MENSUALES',
    '  - [ ] cambiar dolares',
    '  - [ ] regar plantas',
    '  - [ ] lavar ropa',
    '  - [ ] pagar internet mama',
    '  - [ ] pagar internet personal',
    '  - [ ] pagar luz',
    '  - [ ] pagar renta',
    '  - [ ] manda invoice - fecha de arriba mes actual, due date mes siguiente',
    '  - [ ] pagar estacionamiento',
    '  - [ ] pagar tuenti',
    '  - [ ] pagar seguro hilux',
  })
  local diary_dir = diary_dir_from_path(name) or '~/Dropbox/log/diary/monthly/'
  local prev_lines = previous_month_tasks_lines(year, month_num, diary_dir)
  vim.list_extend(lines, prev_lines)
  return lines
end

vim.keymap.set('n', '<leader>w<leader>5', function()
  local buf = vim.api.nvim_get_current_buf()
  local first = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ''
  local template = monthly_template_lines()
  if vim.api.nvim_buf_line_count(buf) == 1 and first == '' then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, template)
  else
    local row = vim.api.nvim_win_get_cursor(0)[1]
    vim.api.nvim_buf_set_lines(buf, row, row, true, template)
  end
end, { desc = 'Insert monthly diary template' })

require('custom.diary_sync').setup()
require('custom.crypto_portfolio').setup()

-- Indentation maintains the highlight on the selected block
vim.keymap.set("v", ">", ">gv", { noremap = true })
vim.keymap.set("v", "<", "<gv", { noremap = true })
-- nvimtree leade e
vim.keymap.set("n", "<leader>e", function()
  local api = require("nvim-tree.api")
  local file_path = vim.api.nvim_buf_get_name(0)
  local dir_path = nil

  if file_path ~= "" and vim.fn.filereadable(file_path) == 1 then
    dir_path = vim.fn.fnamemodify(file_path, ":p:h")
  end

  if dir_path ~= nil then
    api.tree.toggle({
      path = dir_path,
      find_file = true,
      focus = true,
    })
  else
    api.tree.toggle({
      find_file = true,
      focus = true,
    })
  end
end, { noremap = true, silent = true })

vim.api.nvim_create_autocmd("BufEnter", {
  desc = "Keep nvim-tree rooted to the current file directory when visible",
  group = vim.api.nvim_create_augroup("workspace-nvimtree-follow-file", { clear = true }),
  callback = function(args)
    local ok_api, api = pcall(require, "nvim-tree.api")
    local ok_view, view = pcall(require, "nvim-tree.view")
    if not ok_api or not ok_view or not view.is_visible() then
      return
    end

    local file_path = vim.api.nvim_buf_get_name(args.buf)
    if file_path == "" or vim.fn.filereadable(file_path) ~= 1 then
      return
    end

    local dir_path = vim.fn.fnamemodify(file_path, ":p:h")
    api.tree.change_root(dir_path)
    api.tree.find_file({
      buf = args.buf,
      open = false,
      focus = false,
    })
  end,
})
-- delete highligt in to void registry
vim.keymap.set("x", "<leader>p", "\"_dP")
-- leader z to write and quit all
vim.keymap.set("n", "<leader>z", "<cmd>wqa!<CR>")
-- leader q to quit all
vim.keymap.set("n", "<leader>q", "<cmd>qa!<CR>")
-- wrap in backticks
vim.keymap.set('v', '<leader>09', 'c`<c-r>"`<cr>')
-- wrap in 3 backticks
vim.keymap.set('v', '<leader>11', 'c```<cr><c-r>"<cr>```')
-- insert separator
vim.keymap.set("n", "<leader>00",
  'i================================================================================<Esc>0')
-- insert todo
vim.keymap.set("n", "<leader>09", 'i  - [ ] ')
-- insert list
vim.keymap.set("n", "<leader>08", 'i  - ')
-- toggleterm
vim.keymap.set("n", "<leader>55", "<cmd>1ToggleTerm direction=float<CR>")
vim.keymap.set("n", "<leader>5h", "<cmd>ToggleTerm<CR>")
-- vertical term
vim.keymap.set("n", "<leader>5v", function()
  -- Open a vertical split to the right
  -- vim.cmd("vsplit")

  -- Resize it to 40% of total columns
  local total_cols = vim.o.columns
  local target_width = math.floor(total_cols * 0.4)
  vim.cmd(target_width .. "vsplit")

  -- Start terminal in the new split
  vim.cmd("term")
end, { desc = "Vertical terminal at 40% width" })

local function workspace_visible_buffers()
  local buffers = {}
  local seen = {}
  local windows = vim.api.nvim_tabpage_list_wins(0)

  table.sort(windows, function(a, b)
    local row_a, col_a = unpack(vim.api.nvim_win_get_position(a))
    local row_b, col_b = unpack(vim.api.nvim_win_get_position(b))

    if col_a == col_b then
      return row_a < row_b
    end

    return col_a < col_b
  end)

  for _, win in ipairs(windows) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.api.nvim_buf_is_valid(buf) and not seen[buf] then
      seen[buf] = true
      table.insert(buffers, buf)
    end
  end

  return buffers
end

local function workspace_sorted_windows()
  local windows = vim.api.nvim_tabpage_list_wins(0)

  table.sort(windows, function(a, b)
    local row_a, col_a = unpack(vim.api.nvim_win_get_position(a))
    local row_b, col_b = unpack(vim.api.nvim_win_get_position(b))

    if col_a == col_b then
      return row_a < row_b
    end

    return col_a < col_b
  end)

  return windows
end

local function workspace_row_major_windows()
  local windows = vim.api.nvim_tabpage_list_wins(0)
  local bounds = {}
  local seen = {}
  local ordered = {}
  local min_row = math.huge
  local min_col = math.huge
  local max_row = -math.huge
  local max_col = -math.huge

  for _, win in ipairs(windows) do
    local row, col = unpack(vim.api.nvim_win_get_position(win))
    local height = vim.api.nvim_win_get_height(win)
    local width = vim.api.nvim_win_get_width(win)
    local item = {
      win = win,
      top = row,
      left = col,
      bottom = row + height - 1,
      right = col + width - 1,
    }
    table.insert(bounds, item)
    min_row = math.min(min_row, item.top)
    min_col = math.min(min_col, item.left)
    max_row = math.max(max_row, item.bottom)
    max_col = math.max(max_col, item.right)
  end

  for row = min_row, max_row do
    for col = min_col, max_col do
      for _, item in ipairs(bounds) do
        if not seen[item.win]
          and row >= item.top
          and row <= item.bottom
          and col >= item.left
          and col <= item.right then
          seen[item.win] = true
          table.insert(ordered, item.win)
          break
        end
      end
    end
  end

  for _, item in ipairs(bounds) do
    if not seen[item.win] then
      table.insert(ordered, item.win)
    end
  end

  return ordered
end

local function workspace_focus_window(index)
  local windows = workspace_row_major_windows()
  local target = windows[index]

  if target == nil or not vim.api.nvim_win_is_valid(target) then
    return
  end

  vim.api.nvim_set_current_win(target)
end

local workspace_focus_hint_windows = {}
local workspace_focus_hint_timer = nil

local function workspace_clear_focus_hints()
  if workspace_focus_hint_timer ~= nil then
    workspace_focus_hint_timer:stop()
    workspace_focus_hint_timer:close()
    workspace_focus_hint_timer = nil
  end

  for _, win in ipairs(workspace_focus_hint_windows) do
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  workspace_focus_hint_windows = {}
end

local function workspace_show_focus_hints()
  local labels = { "q", "w", "e", "r", "u", "i" }
  local windows = workspace_row_major_windows()

  workspace_clear_focus_hints()

  for index, target_win in ipairs(windows) do
    local label = labels[index]
    if label == nil or not vim.api.nvim_win_is_valid(target_win) then
      break
    end

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { " " .. label .. " " })

    local width = vim.api.nvim_win_get_width(target_win)
    local height = vim.api.nvim_win_get_height(target_win)
    local row = math.max(0, math.floor((height - 1) / 2))
    local col = math.max(0, math.floor((width - 3) / 2))

    local hint_win = vim.api.nvim_open_win(buf, false, {
      relative = "win",
      win = target_win,
      row = row,
      col = col,
      width = 3,
      height = 1,
      style = "minimal",
      border = "rounded",
      focusable = false,
      noautocmd = true,
      zindex = 250,
    })

    vim.wo[hint_win].winhighlight = "Normal:Visual,FloatBorder:WarningMsg"
    table.insert(workspace_focus_hint_windows, hint_win)
  end

  workspace_focus_hint_timer = vim.loop.new_timer()
  workspace_focus_hint_timer:start(1500, 0, vim.schedule_wrap(workspace_clear_focus_hints))
end

local workspace_build_layout_01
local workspace_build_layout_02
local workspace_build_layout_03

local function workspace_zoom_current_window()
  if vim.t.zoomed == 1 then
    return
  end

  vim.fn["zoom#toggle"]()
end

local function workspace_close_zoom_tab()
  if vim.t.zoomed ~= 1 then
    vim.notify("Current window is not zoomed", vim.log.levels.WARN)
    return
  end

  vim.fn["zoom#toggle"]()
end

local function workspace_open_empty_buffer_here()
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_win_set_buf(0, buf)
  vim.wo.winfixheight = false
  vim.wo.winfixwidth = false
end

local function workspace_fill_windows(target_buffers, opts)
  opts = opts or {}
  local windows = workspace_row_major_windows()

  for index, win in ipairs(windows) do
    vim.api.nvim_set_current_win(win)
    vim.wo.winfixheight = false
    vim.wo.winfixwidth = false

    local buf = target_buffers[index]
    if buf ~= nil and vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_win_set_buf(win, buf)
    else
      if opts.open_empty_when_missing then
        workspace_open_empty_buffer_here()
      end
    end
  end

  vim.cmd("wincmd =")
  vim.cmd("startinsert")
end

workspace_build_layout_01 = function()
  vim.cmd("only")
  vim.cmd("vsplit")
  vim.cmd("wincmd h")
  vim.cmd("split")
  vim.cmd("wincmd l")
  vim.cmd("split")
end

workspace_build_layout_02 = function()
  vim.cmd("only")
  vim.cmd("vsplit")
  vim.cmd("vsplit")
end

workspace_build_layout_03 = function()
  vim.cmd("only")
  vim.cmd("vsplit")
end

local function workspace_tmux_socket_path()
  local dir = vim.fn.stdpath("state") .. "/workspace-tmux"
  vim.fn.mkdir(dir, "p")
  return dir .. "/workspace-init.sock"
end

local function workspace_tmux_debug_log(message)
  local log_path = vim.fn.stdpath("state") .. "/workspace-tmux/debug.log"
  local line = string.format(
    "[%s] %s",
    os.date("%Y-%m-%d %H:%M:%S"),
    tostring(message)
  )
  vim.fn.writefile({ line }, log_path, "a")
end

local function workspace_run_tmux(socket_path, args)
  local cmd = { "tmux", "-S", socket_path }
  vim.list_extend(cmd, args)
  local out = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    error(out)
  end
end

local function workspace_tmux_session_exists(socket_path, session_name)
  local cmd = {
    "tmux",
    "-S",
    socket_path,
    "has-session",
    "-t",
    session_name,
  }
  vim.fn.system(cmd)
  return vim.v.shell_error == 0
end

local function workspace_tmux_list_sessions(socket_path)
  local cmd = {
    "tmux",
    "-S",
    socket_path,
    "list-sessions",
    "-F",
    "#{session_name}",
  }
  local out = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    return {}
  end

  table.sort(out)
  return out
end

local function workspace_tmux_window_count(socket_path, session_name)
  local cmd = {
    "tmux",
    "-S",
    socket_path,
    "list-windows",
    "-t",
    session_name,
    "-F",
    "#{window_index}",
  }
  local out = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    return 0
  end

  return #out
end

local function workspace_tmux_ensure_two_windows(socket_path, session_name, cwd)
  local window_count = workspace_tmux_window_count(socket_path, session_name)

  while window_count < 2 do
    workspace_run_tmux(socket_path, {
      "new-window",
      "-d",
      "-t",
      session_name .. ":",
      "-n",
      window_count == 0 and "main" or "aux",
      "-c",
      cwd,
    })
    window_count = workspace_tmux_window_count(socket_path, session_name)
  end
end

local function workspace_prepare_tmux(socket_path, workspace_name, pane_count)
  local cwd = vim.loop.cwd()
  local session_names = workspace_tmux_list_sessions(socket_path)

  for _, session_name in ipairs(session_names) do
    workspace_tmux_ensure_two_windows(socket_path, session_name, cwd)
  end

  for index = #session_names + 1, pane_count do
    local session_name = string.format("%s-pane-%d", workspace_name, index)
    while workspace_tmux_session_exists(socket_path, session_name) do
      index = index + 1
      session_name = string.format("%s-pane-%d", workspace_name, index)
    end

    workspace_run_tmux(socket_path, {
      "new-session",
      "-d",
      "-s",
      session_name,
      "-n",
      "main",
      "-c",
      cwd,
    })
    workspace_run_tmux(socket_path, {
      "new-window",
      "-d",
      "-t",
      session_name .. ":",
      "-n",
      "aux",
      "-c",
      cwd,
    })
    table.insert(session_names, session_name)
  end

  return session_names
end

local function workspace_current_tmux_target()
  local buf = vim.api.nvim_get_current_buf()
  workspace_tmux_debug_log(string.format("resolve:start buf=%s name=%s buftype=%s", buf, vim.api.nvim_buf_get_name(buf), vim.bo[buf].buftype))
  if vim.bo[buf].buftype ~= "terminal" then
    workspace_tmux_debug_log("resolve:skip non-terminal")
    return nil, nil
  end

  local ok_socket, socket_path = pcall(vim.api.nvim_buf_get_var, buf, "workspace_tmux_socket_path")
  local ok_session, session_name = pcall(vim.api.nvim_buf_get_var, buf, "workspace_tmux_session_name")
  if ok_socket and ok_session then
    if type(socket_path) == "string" and socket_path ~= "" and type(session_name) == "string" and session_name ~= "" then
      workspace_tmux_debug_log(string.format("resolve:bufvars socket=%s session=%s", socket_path, session_name))
      return socket_path, session_name
    end
  end

  local ok_pid, job_pid = pcall(vim.api.nvim_buf_get_var, buf, "terminal_job_pid")
  workspace_tmux_debug_log(string.format("resolve:jobpid ok=%s pid=%s", tostring(ok_pid), tostring(job_pid)))
  if ok_pid and type(job_pid) == "number" then
    local socket_guess = workspace_tmux_socket_path()
    local client_lines = vim.fn.systemlist({
      "tmux",
      "-S",
      socket_guess,
      "list-clients",
      "-F",
      "#{client_pid}\t#{client_session}\t#{client_tty}",
    })
    workspace_tmux_debug_log(string.format("resolve:client_pid shell_error=%s lines=%s", vim.v.shell_error, table.concat(client_lines, " | ")))
    if vim.v.shell_error == 0 then
      for _, line in ipairs(client_lines) do
        local client_pid, client_session = line:match("^(%d+)\t(%S+)\t")
        if tonumber(client_pid) == job_pid and client_session ~= nil then
          workspace_tmux_debug_log(string.format("resolve:client_pid_match socket=%s session=%s", socket_guess, client_session))
          return socket_guess, client_session
        end
      end
    end

    local tty_name = vim.fn.systemlist({ "ps", "-o", "tty=", "-p", tostring(job_pid) })[1]
    workspace_tmux_debug_log(string.format("resolve:tty shell_error=%s tty=%s", vim.v.shell_error, tostring(tty_name)))
    if vim.v.shell_error == 0 and tty_name ~= nil and tty_name ~= "" and tty_name ~= "?" then
      tty_name = tty_name:gsub("^%s+", ""):gsub("%s+$", "")
      local tty_path = tty_name:match("^/dev/") and tty_name or ("/dev/" .. tty_name)
      client_lines = vim.fn.systemlist({
        "tmux",
        "-S",
        socket_guess,
        "list-clients",
        "-F",
        "#{client_tty}\t#{client_session}",
      })
      workspace_tmux_debug_log(string.format("resolve:client_tty shell_error=%s lines=%s", vim.v.shell_error, table.concat(client_lines, " | ")))
      if vim.v.shell_error == 0 then
        for _, line in ipairs(client_lines) do
          local client_tty, client_session = line:match("^(%S+)\t(%S+)$")
          if client_tty == tty_path and client_session ~= nil then
            workspace_tmux_debug_log(string.format("resolve:client_tty_match socket=%s session=%s", socket_guess, client_session))
            return socket_guess, client_session
          end
        end
      end
    end
  end

  workspace_tmux_debug_log("resolve:failed")
  return nil, nil
end

local function workspace_tmux_command_for_current_buffer(args)
  local socket_path, session_name = workspace_current_tmux_target()
  if socket_path == nil or session_name == nil then
    workspace_tmux_debug_log("command:resolve_failed")
    vim.notify("Current buffer is not a workspace tmux terminal", vim.log.levels.WARN)
    return
  end

  local cmd = { "tmux", "-S", socket_path }
  vim.list_extend(cmd, args(session_name))
  workspace_tmux_debug_log(string.format("command:run %s", table.concat(cmd, " ")))
  local out = vim.fn.system(cmd)
  workspace_tmux_debug_log(string.format("command:result shell_error=%s out=%s", vim.v.shell_error, tostring(out)))
  if vim.v.shell_error ~= 0 then
    vim.notify("tmux command failed", vim.log.levels.ERROR)
  end
end

local function workspace_open_tmux_terminal_here(socket_path, session_name)
  vim.cmd("enew")
  vim.fn.termopen({ "tmux", "-S", socket_path, "attach-session", "-t", session_name })
  vim.bo.buflisted = true
  vim.api.nvim_buf_set_var(0, "workspace_tmux_socket_path", socket_path)
  vim.api.nvim_buf_set_var(0, "workspace_tmux_session_name", session_name)
  vim.wo.winfixheight = false
  vim.wo.winfixwidth = false
end

local function workspace_fill_tmux_windows(socket_path, session_names)
  local windows = workspace_sorted_windows()

  for index, win in ipairs(windows) do
    vim.api.nvim_set_current_win(win)
    local session_name = session_names[index]
    if session_name ~= nil then
      workspace_open_tmux_terminal_here(socket_path, session_name)
    end
  end

  vim.cmd("wincmd =")
  vim.cmd("startinsert")
end

vim.api.nvim_create_user_command("Workspace4", function()
  local target_buffers = workspace_visible_buffers()

  workspace_build_layout_01()
  workspace_fill_windows(target_buffers, { open_empty_when_missing = true })
end, { desc = "Open a 2x2 workspace in the current tab" })

vim.api.nvim_create_user_command("Workspace3", function()
  local target_buffers = workspace_visible_buffers()

  workspace_build_layout_02()
  workspace_fill_windows(target_buffers, { open_empty_when_missing = true })
end, { desc = "Open a 3-column workspace in the current tab" })

vim.api.nvim_create_user_command("Workspace2", function()
  local target_buffers = workspace_visible_buffers()

  workspace_build_layout_03()
  workspace_fill_windows(target_buffers, { open_empty_when_missing = true })
end, { desc = "Open a 2-column workspace in the current tab" })

vim.keymap.set("n", "<leader>aq", function()
  workspace_focus_window(1)
end, { desc = "Focus workspace window 1" })

vim.keymap.set("n", "<leader>aw", function()
  workspace_focus_window(2)
end, { desc = "Focus workspace window 2" })

vim.keymap.set("n", "<leader>ae", function()
  workspace_focus_window(3)
end, { desc = "Focus workspace window 3" })

vim.keymap.set("n", "<leader>ar", function()
  workspace_focus_window(4)
end, { desc = "Focus workspace window 4" })

vim.keymap.set("n", "<leader>au", function()
  workspace_focus_window(5)
end, { desc = "Focus workspace window 5" })

vim.keymap.set("n", "<leader>ai", function()
  workspace_focus_window(6)
end, { desc = "Focus workspace window 6" })

vim.keymap.set("n", "<leader>at", function()
  workspace_show_focus_hints()
end, { desc = "Show workspace focus hints" })

vim.keymap.set("n", "<leader>aa4", function()
  vim.cmd("Workspace4")
end, { desc = "Open 4-pane workspace" })

vim.keymap.set("n", "<leader>aa3", function()
  vim.cmd("Workspace3")
end, { desc = "Open 3-pane workspace" })

vim.keymap.set("n", "<leader>aa2", function()
  vim.cmd("Workspace2")
end, { desc = "Open 2-pane workspace" })

vim.keymap.set("n", "<leader>a4", function()
  vim.cmd("WorkspaceInit4")
end, { desc = "Open 4-pane tmux workspace" })

vim.keymap.set("n", "<leader>a3", function()
  vim.cmd("WorkspaceInit3")
end, { desc = "Open 3-pane tmux workspace" })

vim.keymap.set("n", "<leader>a2", function()
  vim.cmd("WorkspaceInit2")
end, { desc = "Open 2-pane tmux workspace" })

vim.keymap.set("n", "<leader>tn", function()
  workspace_tmux_command_for_current_buffer(function(session_name)
    return { "next-window", "-t", session_name }
  end)
end, { desc = "tmux next window for current workspace terminal" })

vim.keymap.set("n", "<leader>tp", function()
  workspace_tmux_command_for_current_buffer(function(session_name)
    return { "previous-window", "-t", session_name }
  end)
end, { desc = "tmux previous window for current workspace terminal" })

vim.keymap.set("n", "<leader>t[", function()
  workspace_tmux_command_for_current_buffer(function(session_name)
    return { "copy-mode", "-t", session_name }
  end)
end, { desc = "tmux copy mode for current workspace terminal" })

vim.keymap.set("n", "<leader>a0", function()
  workspace_zoom_current_window()
end, { desc = "Maximize current workspace window" })

vim.keymap.set("n", "<leader>a9", function()
  workspace_close_zoom_tab()
end, { desc = "Close workspace zoom tab" })

vim.api.nvim_create_user_command("WorkspaceInit4", function()
  local socket_path = workspace_tmux_socket_path()

  local ok, err = pcall(function()
    local session_names = workspace_prepare_tmux(socket_path, "workspace-init4", 4)
    workspace_build_layout_01()
    workspace_fill_tmux_windows(socket_path, session_names)
  end)
  if not ok then
    vim.notify("WorkspaceInit4 tmux error:\n" .. err, vim.log.levels.ERROR)
    return
  end
end, { desc = "Open a 2x2 tmux-backed workspace in the current tab" })

vim.api.nvim_create_user_command("WorkspaceInit3", function()
  local socket_path = workspace_tmux_socket_path()

  local ok, err = pcall(function()
    local session_names = workspace_prepare_tmux(socket_path, "workspace-init3", 3)
    workspace_build_layout_02()
    workspace_fill_tmux_windows(socket_path, session_names)
  end)
  if not ok then
    vim.notify("WorkspaceInit3 tmux error:\n" .. err, vim.log.levels.ERROR)
    return
  end
end, { desc = "Open a 3-column tmux-backed workspace in the current tab" })

vim.api.nvim_create_user_command("WorkspaceInit2", function()
  local socket_path = workspace_tmux_socket_path()

  local ok, err = pcall(function()
    local session_names = workspace_prepare_tmux(socket_path, "workspace-init2", 2)
    workspace_build_layout_03()
    workspace_fill_tmux_windows(socket_path, session_names)
  end)
  if not ok then
    vim.notify("WorkspaceInit2 tmux error:\n" .. err, vim.log.levels.ERROR)
    return
  end
end, { desc = "Open a 2-column tmux-backed workspace in the current tab" })

vim.keymap.set("c", "<CR>", function()
  if vim.fn.getcmdtype() == ":" and vim.fn.getcmdline() == "workspace-4" then
    return "<C-u>Workspace4<CR>"
  end
  if vim.fn.getcmdtype() == ":" and vim.fn.getcmdline() == "workspace-3" then
    return "<C-u>Workspace3<CR>"
  end
  if vim.fn.getcmdtype() == ":" and vim.fn.getcmdline() == "workspace-2" then
    return "<C-u>Workspace2<CR>"
  end
  if vim.fn.getcmdtype() == ":" and vim.fn.getcmdline() == "workspace-init4" then
    return "<C-u>WorkspaceInit4<CR>"
  end
  if vim.fn.getcmdtype() == ":" and vim.fn.getcmdline() == "workspaceinit4" then
    return "<C-u>WorkspaceInit4<CR>"
  end
  if vim.fn.getcmdtype() == ":" and vim.fn.getcmdline() == "workspace-init3" then
    return "<C-u>WorkspaceInit3<CR>"
  end
  if vim.fn.getcmdtype() == ":" and vim.fn.getcmdline() == "workspaceinit3" then
    return "<C-u>WorkspaceInit3<CR>"
  end
  if vim.fn.getcmdtype() == ":" and vim.fn.getcmdline() == "workspace-init2" then
    return "<C-u>WorkspaceInit2<CR>"
  end
  if vim.fn.getcmdtype() == ":" and vim.fn.getcmdline() == "workspaceinit2" then
    return "<C-u>WorkspaceInit2<CR>"
  end
  return "<CR>"
end, { expr = true, desc = "Workspace command aliases" })



-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.hl.on_yank()`
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking (copying) text",
  group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

vim.api.nvim_create_autocmd("TermOpen", {
  desc = "Show line numbers in terminal buffers",
  group = vim.api.nvim_create_augroup("kickstart-terminal-numbers", { clear = true }),
  callback = function()
    local cyan = "#00d6ec"
    vim.api.nvim_set_hl(0, "TermLineNr", { fg = cyan, ctermfg = 44 })
    vim.api.nvim_set_hl(0, "TermCursorLineNr", { fg = cyan, ctermfg = 44, bold = true })
    vim.opt_local.number = true
    vim.opt_local.relativenumber = true
    vim.opt_local.winhighlight = "LineNr:TermLineNr,CursorLineNr:TermCursorLineNr"
  end,
})


-- :Figlet some text
-- Also works on a visual range, e.g. :'<,'>Figlet some text
vim.api.nvim_create_user_command("Figlet", function(opts)
  -- Join args so spaces are allowed: :Figlet Hello World
  local text = table.concat(opts.fargs, " ")
  if text == "" then
    vim.notify("Figlet: please provide some text, e.g. :Figlet Hello", vim.log.levels.WARN)
    return
  end

  if vim.fn.executable("figlet") == 0 then
    vim.notify("Figlet: 'figlet' is not installed or not in PATH.", vim.log.levels.ERROR)
    return
  end

  -- Keep the ad-hoc Figlet command aligned with the diary template style.
  local cmd = { "figlet", "-f", "alligator", "-k", text }

  -- Run and capture output as a list of lines
  local out = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify("Figlet error:\n" .. table.concat(out, "\n"), vim.log.levels.ERROR)
    return
  end

  -- Insert at cursor line, or replace a visual/line range if provided
  if opts.range > 0 then
    vim.api.nvim_buf_set_lines(0, opts.line1 - 1, opts.line2, true, out)
  else
    local row = vim.api.nvim_win_get_cursor(0)[1]
    vim.api.nvim_buf_set_lines(0, row, row, true, out)
  end
end, {
  nargs = "+",  -- require at least one arg so :Figlet <text>
  range = true, -- allow replacing a selected range
})

-- :CryptoPortfolio — fetch live balances and insert tables at cursor
vim.keymap.set('n', '<leader>cp', '<cmd>CryptoPortfolio<CR>', { desc = 'Insert crypto portfolio tables' })

-- Map <leader>f to run :Figlet with user input
vim.keymap.set("n", "<leader>07", function()
  local text = vim.fn.input("Figlet text: ")
  if text ~= "" then
    vim.cmd("Figlet " .. text)
  end
end, { desc = "Insert figlet ASCII art" })


-- vim: ts=2 sts=2 sw=2 et
