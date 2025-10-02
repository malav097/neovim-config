--
return {
  { "vimwiki/vimwiki" },
  -- { "rest-nvim/rest.nvim" },
  { "dhruvasagar/vim-zoom" },
  -- { "tidalcycles/vim-tidal" },
  {
    "tidalcycles/vim-tidal",
    init = function()
      vim.g.tidal_target = "tmux"
    end,
  },

  { "dhruvasagar/vim-table-mode" },
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    lazy = false,
    opts = {
      -- add any opts here
      version = false,
      mode = "legacy",
      providers = {
--        openai = { model = "gpt-4o", disable_tools = true },
        openai = { model = "gpt-5" },
      },
    },

    -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
    build = "make",
    -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
    dependencies = {
      "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      --- The below dependencies are optional,
      "echasnovski/mini.pick",         -- for file_selector provider mini.pick
      "nvim-telescope/telescope.nvim", -- for file_selector provider telescope
      "hrsh7th/nvim-cmp",              -- autocompletion for avante commands and mentions
      "ibhagwan/fzf-lua",              -- for file_selector provider fzf
      "nvim-tree/nvim-web-devicons",   -- or echasnovski/mini.icons
      "zbirenbaum/copilot.lua",        -- for providers='copilot'
      {
        -- support for image pasting
        "HakonHarnes/img-clip.nvim",
        event = "VeryLazy",
        opts = {
          -- recommended settings
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            drag_and_drop = {
              insert_mode = true,
            },
            -- required for Windows users
            use_absolute_path = true,
          },
        },
      },
--      {
--        -- Make sure to set this up properly if you have lazy=true
--        "MeanderingProgrammer/render-markdown.nvim",
--        opts = {
--          enbled = false,
--          file_types = { "markdown", "Avante" },
--        },
--        ft = { "markdown", "Avante" },
--      },
    },
  },

  {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    lazy = false,
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("nvim-tree").setup {}
    end,
  },
  {
    'lucidph3nx/nvim-sops',
    event = { 'BufEnter' },
    opts = {
      -- your configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    }
  },
  {
    -- amongst your other plugins
    {
      'akinsho/toggleterm.nvim',
      version = "*",
      opts = {
        highlights = {
          Normal = { guifg = "#00d6ec", ctermfg = 44 },
          NormalFloat = { guifg = "#00d6ec", ctermfg = 44 },
        },
      },
      config = function(_, opts)
        local cyan = "#00d6ec"
        local term = require("toggleterm")
        term.setup(opts)

        local cfg = require("toggleterm.config")
        cfg.highlights = cfg.highlights or {}
        cfg.highlights.Normal = cfg.highlights.Normal or {}
        cfg.highlights.Normal.guifg = cyan
        cfg.highlights.Normal.ctermfg = 44
        cfg.highlights.NormalFloat = cfg.highlights.NormalFloat or {}
        cfg.highlights.NormalFloat.guifg = cyan
        cfg.highlights.NormalFloat.ctermfg = 44

        local Terminal = require("toggleterm.terminal").Terminal
        local quake_term

        local termcodes = function(str)
          return vim.api.nvim_replace_termcodes(str, true, false, true)
        end

        local function leave_terminal_mode()
          if vim.api.nvim_get_mode().mode == "t" then
            vim.api.nvim_feedkeys(termcodes("<C-\\><C-n>"), "n", false)
          end
        end

        local function quake_toggle()
          leave_terminal_mode()

          if not quake_term then
            quake_term = Terminal:new({
              count = 54,
              direction = "float",
              float_opts = {
                border = "rounded",
                width = function()
                  return math.floor(vim.o.columns * 0.96)
                end,
                height = function()
                  return math.max(12, math.floor(vim.o.lines * 0.4))
                end,
                col = function()
                  local width = math.floor(vim.o.columns * 0.96)
                  return math.floor((vim.o.columns - width) / 2)
                end,
                row = function()
                  return 1
                end,
              },
            })
          end

          quake_term:toggle()
          if quake_term:is_open() then
            vim.schedule(function()
              if quake_term:is_open() then vim.cmd("startinsert!") end
            end)
          end
        end

        vim.keymap.set({ "n", "t" }, "<leader>54", quake_toggle, { desc = "ToggleTerm drop-down" })
      end,
    },
    -- or
  },

  -- add this to your lua/plugins.lua, lua/plugins/init.lua,  or the file you keep your other plugins:
  --   {
  --     "numToStr/Comment.nvim",
  --     event = "VeryLazy",
  --     opts = {
  --       -- turn off default mappings so we only use <leader>//:
  --       mappings = { basic = false, extra = false, extended = false },
  --     },
  --     config = function(_, opts)
  --       require("Comment").setup(opts)
  --
  --       local api = require("Comment.api")
  --
  --       -- Toggle current line
  --       vim.keymap.set(
  --         "n",
  --         "<leader>//",
  --         api.toggle.linewise.current,
  --         { desc = "Comment: toggle line", silent = true }
  --       )
  --
  --       -- Toggle selection (visual mode)
  --       vim.keymap.set("x", "<leader>//", function()
  --         api.toggle.linewise(vim.fn.visualmode())
  --       end, { desc = "Comment: toggle selection", silent = true })
  --     end,
  --   },
  -- {
  --   "jackMort/ChatGPT.nvim",
  --   event = "VeryLazy",
  --   config = function()
  --     require("chatgpt").setup({
  --       actions_paths = {'~/.config/lvim/actions.json'},
  --       -- this config assumes you have OPENAI_API_KEY environment variable set
  --       openai_params = {
  --         -- NOTE: model can be a function returning the model name
  --         -- this is useful if you want to change the model on the fly
  --         -- using commands
  --         -- Example:
  --         -- model = function()
  --         --     if some_condition() then
  --         --         return "gpt-4-1106-preview"
  --         --     else
  --         --         return "gpt-3.5-turbo"
  --         --     end
  --         -- end,
  --         model = "gpt-4-1106-preview",
  --         frequency_penalty = 0,
  --         presence_penalty = 0,
  --         max_tokens = 4095,
  --         temperature = 0.2,
  --         top_p = 0.1,
  --         n = 1,
  --       }
  --     })
  --   end,
  --   dependencies = {
  --     "MunifTanjim/nui.nvim",
  --     "nvim-lua/plenary.nvim",
  --       "folke/trouble.nvim", -- optional
  --     "nvim-telescope/telescope.nvim"
  --   }
  -- }

  -- lazy.nvim
  -- {
  --     "robitx/gp.nvim",
  --     config = function()
  --         local conf = {
  --           -- For customization, refer to Install > Configuration in the Documentation/Readme
  --           -- openai_api_key = os.getenv("OPENAI_API_KEY"),
  --         }
  --         require("gp").setup(conf)

  --         -- Setup shortcuts here (see Usage > Shortcuts in the Documentation/Readme)
  --     end,
  -- }

  -- {
  --   "vhyrro/luarocks.nvim",
  --   opts = {
  --     rocks = {  "lua-curl", "nvim-nio", "mimetypes", "xml2lua" }, -- Specify LuaRocks packages to install
  --   },
  -- }
  --     {"folke/tokyonight.nvim"},
  --     {
  --       "folke/trouble.nvim",
  --       cmd = "TroubleToggle",
  --     },
}
-- rest.nvim keybindings
-- lvim.keys.normal_mode["<leader>rr"] = "<Plug>RestNvim"
-- lvim.keys.normal_mode["<leader>rp"] = "<Plug>RestNvimPreview"
-- lvim.keys.normal_mode["<leader>rl"] = "<Plug>RestNvimLast"
