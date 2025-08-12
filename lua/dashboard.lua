-- pcall(function()

vim.api.nvim_create_autocmd("VimEnter", {
  group = group,
  callback = function()
    -- Only when launched without files/stdin
    if vim.fn.argc() ~= 0 or vim.fn.line2byte("$") ~= -1 then
      return
    end

    -- remember your global defaults (for restoring later)
    local default_number = vim.o.number
    local default_relativenumber = vim.o.relativenumber

    -- Create an unlisted scratch buffer (like dashboards do)
    local buf = vim.api.nvim_create_buf(false, true) -- listed=false, scratch=true
    vim.api.nvim_set_current_buf(buf)

    -- Buffer/window options so :wqa! never complains
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "startscreen"
    vim.bo[buf].modifiable = true

    vim.wo.number = false
    vim.wo.relativenumber = false
    vim.wo.signcolumn = "no"
    vim.wo.list = false
    vim.wo.cursorline = false

    -- opaque bg ONLY for this window
    local bg = "#1a1b26" -- tokyonight-night default
    pcall(function()
      local c = require("tokyonight.colors").setup({})
      if c and c.bg then
        bg = c.bg
      end
    end)
    vim.api.nvim_set_hl(0, "StartscreenNormal", { bg = bg })
    vim.wo.winhl = "Normal:StartscreenNormal,NormalNC:StartscreenNormal,EndOfBuffer:StartscreenNormal"

    -- Replace the old `local lines = { ... }` with this:
    local art = [[
malav config ver: 0.1.0........................................................
...............................................................................
...............................................................................
...............................###########.....................................
...........................###............#..######............................
........................##............................#+##.....................
....................###.....................................###................
.................###......................................##..#................
..............#+.......................................##+....#................
............######+.................................###.......#................
............#...........+######+.................###..........#................
............#.....................#-.#####.....##.............#................
............#................................#................#................
............#.........-......................#................#................
............+......##....#+.......####-......#................#................
............#.....#-......#.....##.....#.....#-..............##................
............#....##..##+..+#...##.......#....#...............##................
............#....+-.-###..#....#..####.##....#...............##................
............#.....#......#.....##.#-#..#.....................#+................
............#......######.......##...##-.....................##................
............#.....................-##........-................#................
............#................................#................#................
............#..........#########.............#................#................
............#.......###..........##..........#................#................
............+#.....##..............##........#..............###................
............-#....##................##.......#...........###...................
.............#.......................#-......#..........##.....................
.............#...............................#......-#+........................
.............#######.........................#....###..........................
.......................+#.##+##..............#..##.............................
..................................######+....###...............................
...........................................###.................................
...............................................................................
...............................................................................
...............................................................................
............._  _ _  _ _ _  _    ____ ____ _  _ ____ _ ____....................
.............|\ | |  | | |\/|    |    |  | |\ | |___ | | __....................
.............| \|  \/  | |  |    |___ |__| | \| |    | |__]....................
...............................................................................
...............................................................................
...............................................................................
...............................................................................
...............................................................................
...............................................................................
...............................................................................
...............................................................................
...............................................................................
...............................................................................
]]

    local lines = vim.split(art, "\n", { plain = true })

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    -- === make the art pink ===
    vim.opt.termguicolors = true
    local ns = vim.api.nvim_create_namespace("StartscreenArt")
    vim.api.nvim_set_hl(0, "StartscreenArtPink", { fg = "#ff69b4" }) -- hot pink
    for i = 0, #lines - 1 do
      vim.api.nvim_buf_add_highlight(buf, ns, "StartscreenArtPink", i, 0, -1)
    end

    -- Lock it down like dashboards
    vim.bo[buf].modifiable = false
    vim.bo[buf].readonly = true
    vim.bo[buf].modified = false -- <- crucial so :wqa! doesn't complain

    -- Re-apply/restore window-local settings when this buffer enters/leaves a window
    local dashfix = vim.api.nvim_create_augroup("StartscreenWindowLocal", { clear = true })

    vim.api.nvim_create_autocmd("BufWinEnter", {
      group = dashfix,
      buffer = buf,
      callback = function()
        -- ensure dashboard keeps its overrides if refocused
        vim.wo.number = false
        vim.wo.relativenumber = false
        vim.wo.winhl = "Normal:StartscreenNormal,NormalNC:StartscreenNormal,EndOfBuffer:StartscreenNormal"
      end,
    })

    vim.api.nvim_create_autocmd("BufWinLeave", {
      group = dashfix,
      buffer = buf,
      callback = function()
        -- leaving the dashboard window: restore your normal defaults
        vim.wo.winhl = ""
        vim.wo.number = default_number
        vim.wo.relativenumber = default_relativenumber
      end,
    })
    -- === OPEN NEO-TREE WITH THE DASHBOARD ===
    -- Use the API to avoid race conditions; works because you set lazy=false for neo-tree.
    -- pcall(function()
    -- require("neo-tree.command").execute({
    -- action = "show", -- or 'reveal' if you want to jump to current file when there is one
    -- position = "left",
    -- source = "filesystem",
    -- dir = vim.loop.cwd(),
    -- })
    -- end)

    vim.schedule(function()
      -- create right split and move focus there
      vim.cmd("vsplit")
      vim.cmd("enew") -- open empty buffer
      vim.cmd("wincmd l")

      -- launch Telescope via Lua (avoid :Telescope)
      require("telescope.builtin").find_files({
        layout_strategy = "cursor",
        layout_config = {
          width = 0.4, -- feels like a right sidebar
          height = 0.95,
          preview_cutoff = 0,
          preview_width = 0,
        },
        sorting_strategy = "ascending",
        default_text = "", -- force empty prompt, even if something sneaks in
      })
    end)
  end,
})
