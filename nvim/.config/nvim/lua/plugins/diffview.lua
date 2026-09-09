return {
  "sindrets/diffview.nvim",
  -- Include commands for lazy loading
  cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFocusFiles", "DiffviewFileHistory" },
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  config = function()
    local labels = require("diffview_labels")
    labels.setup()

    require("diffview").setup({
      enhanced_diff_hl = true,
      use_icons = true,
      hooks = {
        diff_buf_win_enter = function(bufnr, winid, ctx)
          require("review_comments").refresh(bufnr)
          labels.set(bufnr, winid, ctx)
        end,
        view_opened = labels.reset,
      },
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
