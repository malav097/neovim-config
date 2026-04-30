-- NOTE: Plugins can specify dependencies.
--
-- The dependencies are proper plugin specifications as well - anything
-- you do for a plugin at the top level, you can do for a dependency.
--
-- Use the `dependencies` key to specify the dependencies of a particular plugin

return {
	{ -- Fuzzy Finder (files, lsp, etc)
		"nvim-telescope/telescope.nvim",
		event = "VimEnter",
		dependencies = {
			"nvim-lua/plenary.nvim",
			{ -- If encountering errors, see telescope-fzf-native README for installation instructions
				"nvim-telescope/telescope-fzf-native.nvim",

				-- `build` is used to run some command when the plugin is installed/updated.
				-- This is only run then, not every time Neovim starts up.
				build = "make",

				-- `cond` is a condition used to determine whether this plugin should be
				-- installed and loaded.
				cond = function()
					return vim.fn.executable("make") == 1
				end,
			},
			{ "nvim-telescope/telescope-ui-select.nvim" },

			-- Useful for getting pretty icons, but requires a Nerd Font.
			{ "nvim-tree/nvim-web-devicons", enabled = vim.g.have_nerd_font },
		},
		config = function()
			-- Telescope is a fuzzy finder that comes with a lot of different things that
			-- it can fuzzy find! It's more than just a "file finder", it can search
			-- many different aspects of Neovim, your workspace, LSP, and more!
			--
			-- The easiest way to use Telescope, is to start by doing something like:
			--  :Telescope help_tags
			--
			-- After running this command, a window will open up and you're able to
			-- type in the prompt window. You'll see a list of `help_tags` options and
			-- a corresponding preview of the help.
			--
			-- Two important keymaps to use while in Telescope are:
			--  - Insert mode: <c-/>
			--  - Normal mode: ?
			--
			-- This opens a window that shows you all of the keymaps for the current
			-- Telescope picker. This is really useful to discover what Telescope can
			-- do as well as how to actually do it!

			-- [[ Configure Telescope ]]
			-- See `:help telescope` and `:help telescope.setup()`
			require("telescope").setup({
				-- You can put your default mappings / updates / etc. in here
				--  All the info you're looking for is in `:help telescope.setup()`
				--
				-- defaults = {
				--   mappings = {
				--     i = { ['<c-enter>'] = 'to_fuzzy_refine' },
				--   },
				-- },
				-- pickers = {
          -- find_files = {hidden = true},
        -- },
				extensions = {
					["ui-select"] = {
						require("telescope.themes").get_dropdown(),
					},
				},
			})

			-- Enable Telescope extensions if they are installed
			pcall(require("telescope").load_extension, "fzf")
			pcall(require("telescope").load_extension, "ui-select")

			-- See `:help telescope.builtin`
			local builtin = require("telescope.builtin")
			local pickers = require("telescope.pickers")
			local finders = require("telescope.finders")
			local conf = require("telescope.config").values
			local actions = require("telescope.actions")
			local action_state = require("telescope.actions.state")

			local function window_cwd(win)
				if win ~= nil and vim.api.nvim_win_is_valid(win) then
					return vim.fn.getcwd(win)
				end
				return vim.fn.getcwd(0)
			end

			local function find_files_in_window_cwd()
				builtin.find_files({ cwd = window_cwd() })
			end

			local function live_grep_in_window_cwd()
				builtin.live_grep({ cwd = window_cwd() })
			end

			local function sync_tmux_terminal_cwd_for_buffer(buf, selected_cwd)
				if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
					return
				end
				if vim.bo[buf].buftype ~= "terminal" then
					return
				end

				local ok_socket, socket_path = pcall(vim.api.nvim_buf_get_var, buf, "workspace_tmux_socket_path")
				local ok_session, session_name = pcall(vim.api.nvim_buf_get_var, buf, "workspace_tmux_session_name")
				if not ok_socket or not ok_session then
					return
				end
				if type(socket_path) ~= "string" or socket_path == "" then
					return
				end
				if type(session_name) ~= "string" or session_name == "" then
					return
				end

				local shell_commands = {
					sh = true,
					bash = true,
					zsh = true,
					fish = true,
					dash = true,
					ksh = true,
				}

				local window_targets = vim.fn.systemlist({
					"tmux",
					"-S",
					socket_path,
					"list-windows",
					"-t",
					session_name,
					"-F",
					"#{window_id}",
				})
				if vim.v.shell_error ~= 0 or window_targets[1] == nil then
					return
				end

				for _, window_target in ipairs(window_targets) do
					local pane_state_lines = vim.fn.systemlist({
						"tmux",
						"-S",
						socket_path,
						"list-panes",
						"-t",
						window_target,
						"-F",
						"#{pane_id}\t#{pane_in_mode}\t#{pane_current_command}",
					})
					if vim.v.shell_error == 0 then
						for _, pane_state in ipairs(pane_state_lines) do
							local pane_id, pane_in_mode, pane_command = pane_state:match("^(%%%d+)\t(%d+)\t(.+)$")
							if pane_id ~= nil and pane_in_mode == "0" and shell_commands[pane_command] then
								vim.fn.system({
									"tmux",
									"-S",
									socket_path,
									"send-keys",
									"-t",
									pane_id,
									"-l",
									"cd " .. vim.fn.shellescape(selected_cwd),
								})
								if vim.v.shell_error == 0 then
									vim.fn.system({
										"tmux",
										"-S",
										socket_path,
										"send-keys",
										"-t",
										pane_id,
										"Enter",
									})
								end
							end
						end
					end
				end
			end

			local function select_window_cwd()
				local source_win = vim.api.nvim_get_current_win()
				local source_buf = vim.api.nvim_win_get_buf(source_win)
				local current_cwd = window_cwd(source_win)
				local cwd_items = { current_cwd }
				local seen = { [current_cwd] = true }
				local allowed_hidden_roots = {
					vim.fn.expand("~/.config/nvim"),
					vim.fn.expand("~/.codex"),
					vim.fn.expand("~/.claude"),
				}

				local function add_cwd_item(path)
					local normalized = vim.fn.fnamemodify(path, ":p")
					normalized = normalized:gsub("/+$", "")
					if normalized ~= "" and not seen[normalized] then
						table.insert(cwd_items, normalized)
						seen[normalized] = true
					end
				end

				local function add_fd_directories(root)
					if vim.fn.isdirectory(root) ~= 1 or vim.fn.executable("fd") ~= 1 then
						return
					end

					local child_dirs = vim.fn.systemlist({
						"fd",
						"--type",
						"directory",
						"--max-depth",
						"3",
						"--exclude",
						".git",
						"--exclude",
						"node_modules",
						"--exclude",
						".venv",
						"--exclude",
						"venv",
						"--exclude",
						"dist",
						"--exclude",
						"build",
						".",
						root,
					})

					table.sort(child_dirs)
					for _, dir in ipairs(child_dirs) do
						add_cwd_item(dir)
					end
				end

				local parent = vim.fn.fnamemodify(current_cwd, ":h")

				while parent ~= nil and parent ~= "" and parent ~= current_cwd do
					add_cwd_item(parent)
					current_cwd = parent
					parent = vim.fn.fnamemodify(current_cwd, ":h")
				end

				add_fd_directories(window_cwd(source_win))

				for _, root in ipairs(allowed_hidden_roots) do
					if vim.fn.isdirectory(root) == 1 then
						add_cwd_item(root)
						add_fd_directories(root)
					end
				end

				pickers.new({}, {
					prompt_title = "Select Window CWD",
					finder = finders.new_table({
						results = cwd_items,
					}),
					sorter = conf.generic_sorter({}),
						attach_mappings = function(prompt_bufnr, _)
							actions.select_default:replace(function()
								local selection = action_state.get_selected_entry()
								actions.close(prompt_bufnr)
								if selection ~= nil and selection[1] ~= nil then
									if vim.api.nvim_win_is_valid(source_win) then
										vim.api.nvim_win_call(source_win, function()
											vim.cmd.lcd(vim.fn.fnameescape(selection[1]))
										end)
										source_buf = vim.api.nvim_win_get_buf(source_win)
									end
									sync_tmux_terminal_cwd_for_buffer(source_buf, selection[1])
								end
							end)
						return true
					end,
				}):find()
			end

			vim.keymap.set("n", "<leader>sh", builtin.help_tags, { desc = "[S]earch [H]elp" })
			vim.keymap.set("n", "<leader>sk", builtin.keymaps, { desc = "[S]earch [K]eymaps" })
			vim.keymap.set("n", "<leader>sf", find_files_in_window_cwd, { desc = "[S]earch [F]iles" })
			vim.keymap.set("n", "<leader>ss", builtin.builtin, { desc = "[S]earch [S]elect Telescope" })
			vim.keymap.set("n", "<leader>sw", builtin.grep_string, { desc = "[S]earch current [W]ord" })
			vim.keymap.set("n", "<leader>sg", live_grep_in_window_cwd, { desc = "[S]earch by [G]rep" })
			vim.keymap.set("n", "<leader>sd", builtin.diagnostics, { desc = "[S]earch [D]iagnostics" })
			vim.keymap.set("n", "<leader>sr", builtin.oldfiles, { desc = "[S]earch Recent Files" })
			vim.keymap.set("n", "<leader>s.", builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
			vim.keymap.set("n", "<leader>fc", select_window_cwd, { desc = "[F]ind [C]wd" })
			vim.keymap.set("n", "<leader><leader>", builtin.buffers, { desc = "[ ] Find existing buffers" })
			vim.keymap.set("n", "<leader>fg", live_grep_in_window_cwd, { desc = "[F]ind by [G]rep" })
			vim.keymap.set("n", "<leader>ff", find_files_in_window_cwd, { desc = "[F]ind [F]iles" })

			-- Slightly advanced example of overriding default behavior and theme
			vim.keymap.set("n", "<leader>.", function()
				-- You can pass additional configuration to Telescope to change the theme, layout, etc.
				builtin.current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
					winblend = 10,
					previewer = false,
				}))
			end, { desc = "[/] Fuzzily search in current buffer" })

			-- It's also possible to pass additional configuration options.
			--  See `:help telescope.builtin.live_grep()` for information about particular keys
			vim.keymap.set("n", "<leader>s/", function()
				builtin.live_grep({
					grep_open_files = true,
					prompt_title = "Live Grep in Open Files",
				})
			end, { desc = "[S]earch [/] in Open Files" })

			-- Shortcut for searching your Neovim configuration files
			vim.keymap.set("n", "<leader>sn", function()
				builtin.find_files({ cwd = vim.fn.stdpath("config") })
			end, { desc = "[S]earch [N]eovim files" })
		end,
	},
}
-- vim: ts=2 sts=2 sw=2 et
