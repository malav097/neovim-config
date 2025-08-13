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
      let g:vimwiki_list = [{'path': '~/Dropbox/log', 'syntax': 'markdown', 'ext': '.md'},
                        \ {'path': '~/Dropbox/log/general', 'syntax': 'markdown', 'ext': '.md'}]
  ]])
end)

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
vim.keymap.set("n", "<leader>5f", "<cmd>ToggleTerm direction=float<CR>")
vim.keymap.set("n", "<leader>5h", "<cmd>ToggleTerm<CR>")

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
