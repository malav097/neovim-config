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
      nnoremap <leader>a0 <C-W><C-o>
      nnoremap <leader>av <cmd>vertical split<cr>
      nnoremap <leader>as <cmd>split<cr>
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

  local out = vim.fn.systemlist({ "figlet", "-f", "banner", text })
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
    '  - [ ] pagar internet mio',
    '  - [ ] manda invoice',
    '  - [ ] pagar estacionamiento',
    '  - [ ] pagar renta y expensas',
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

-- Indentation maintains the highlight on the selected block
vim.keymap.set("v", ">", ">gv", { noremap = true })
vim.keymap.set("v", "<", "<gv", { noremap = true })
-- nvimtree leade e
vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeFindFileToggle<CR>", { noremap = true, silent = true })
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
-- AI remaps
vim.keymap.set(
  'v',
  '<leader>4d',
  [[:'<,'>AvanteEdit correct granmar and format in a professional way using markdown. use correct puntuation. no more than 80 characters per line and if it is in another language translate to english<CR>]],
  {
    noremap = true,
  }
)
vim.keymap.set(
  'v',
  '<leader>4e',
  [[:'<,'>AvanteEdit correct granmar and format in a professional way using markdown. use correct puntuation. Use proper capitalization. no more than 80 characters per line and if it is in another language translate to spanish<CR>]],
  {
    noremap = true,
  }
)

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

  -- Build the command. Add flags here if you like (e.g., "-f", "slant")
  local cmd = { "figlet", "-f", "banner", text }

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

-- Map <leader>f to run :Figlet with user input
vim.keymap.set("n", "<leader>07", function()
  local text = vim.fn.input("Figlet text: ")
  if text ~= "" then
    vim.cmd("Figlet " .. text)
  end
end, { desc = "Insert figlet ASCII art" })


-- vim: ts=2 sts=2 sw=2 et
