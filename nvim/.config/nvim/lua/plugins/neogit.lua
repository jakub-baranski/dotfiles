return {
  {
    "NeogitOrg/neogit",
    -- dir = "/Users/jakubbaranski/Projects/neogit",
    dependencies = {
      "nvim-lua/plenary.nvim", -- required
      "sindrets/diffview.nvim", -- optional - Diff integration
      "folke/snacks.nvim", -- optional
    },
    opts = {
      treesitter_diff_highlight = true,
      log_date_format = "%Y-%m-%d",
      graph_style = "kitty",
    },
    keys = {
      {
        "<leader>gg",
        function()
          require("neogit").open()
        end,
        desc = "Neogit Open",
      },
    },
  },
}
