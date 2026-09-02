return {
  {
    dir = vim.fn.expand("~/Projects/learn/surfaces/learn.nvim"),
    name = "learn.nvim",
    dependencies = { "folke/snacks.nvim" },
    cmd = "Learn",
    opts = { cli = "learn", tutor = "claude", model = "sonnet" },
  },
}
