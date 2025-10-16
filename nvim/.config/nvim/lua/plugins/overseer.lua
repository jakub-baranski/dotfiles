return {
  {
    "stevearc/overseer.nvim",
    opts = {},
    keys = {
      {
        "<leader>ot",
        function()
          require("overseer").toggle()
        end,
        desc = "Toggle Overseer",
      },
      {
        "<leader>or",
        function()
          require("overseer").run_template()
        end,
        desc = "Run Task",
      },
    },
  },
}
