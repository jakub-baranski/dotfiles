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
          require("dap").run({
            type = "python",
            request = "launch",
            name = "Django: runserver (debug)",
            program = vim.fn.getcwd() .. "/manage.py",
            args = { "runserver", "--noreload" },
            django = true,
            justMyCode = false,
            console = "integratedTerminal",
          })
        end,
        desc = "Debug Django runserver",
      },
    },
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>o", group = "overseer", icon = { icon = "", color = "green" } },
        { "<leader>ot", icon = { icon = "󰒓", color = "green" } },
        { "<leader>or", icon = { icon = "", color = "yellow" } },
      },
    },
  },
}
