return {
  'nvim-neo-tree/neo-tree.nvim',
  version = '*',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons',
    'MunifTanjim/nui.nvim',
  },
  lazy = false,
  keys = {
    { '<leader>e', '<cmd>Neotree toggle<CR>', desc = 'NeoTree toggle', silent = true },
  },
  opts = {
    -- global Neo-tree window options
    window = {
      width = 25, -- << make it less wide than default (usually ~40)
      position = 'left',
    },
    filesystem = {
      window = {
        mappings = {
          ['\\'] = 'close_window',
        },
      },
    },
  },
}
