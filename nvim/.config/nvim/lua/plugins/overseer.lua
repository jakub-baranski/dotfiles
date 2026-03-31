return {
  {
    "stevearc/overseer.nvim",
    opts = {
      task_list = {
        direction = "bottom",
        sort = function(a, b)
          return a.id > b.id
        end,
      },
    },
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
