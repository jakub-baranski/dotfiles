return {
  {
    "chriswritescode-dev/consolelog.nvim",
    enabled = false, -- This plugin seems cool, but have a lot of problems. Disable for now.
    config = function()
      require("consolelog").setup({
        keymaps = {
          enabled = false, -- Disable default keymaps
          -- toggle = "<leader>lt", -- Toggle ConsoleLog
          -- run = "<leader>lr", -- Run current file
          -- clear = "<leader>lx", -- Clear outputs
          -- inspect = "<leader>li", -- Inspect at cursor
          -- inspect_all = "<leader>la", -- Inspect all
          -- inspect_buffer = "<leader>lb", -- Inspect buffer
          -- reload = "<leader>lR", -- Reload plugin
          -- debug_toggle = "<leader>ld", -- Toggle debug logging
        },
      })
    end,
  },
}
