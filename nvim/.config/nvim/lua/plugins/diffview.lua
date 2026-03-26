return {
  "sindrets/diffview.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("diffview").setup({
      enhanced_diff_hl = true,
      use_icons = true,
    })
  end,
  keys = {
    {
      "<leader>gv",
      "<cmd>DiffviewOpen<cr>",
      desc = "Open Diffview",
    },
    {
      "<leader><tab>n",
      "<cmd>tabnext<cr>",
      desc = "Next Tab",
    },
    {
      "<leader><tab>p",
      "<cmd>tabprevious<cr>",
      desc = "Previous Tab",
    },
  },
}
