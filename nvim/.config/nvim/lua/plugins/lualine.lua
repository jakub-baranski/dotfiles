return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.sections = opts.sections or {}
      opts.sections.lualine_c = opts.sections.lualine_c or {}

      -- Configuration for tokyonight.nvim colorscheme
      opts.theme = "tokyonight"

      -- Helper function to count tasks by status
      local function count_tasks_with_status(status)
        local overseer = require("overseer")
        local tasks = overseer.list_tasks()
        local count = 0
        for _, task in ipairs(tasks) do
          if task.status == status then
            count = count + 1
          end
        end
        return count
      end

      -- Table of status info: symbol and color
      local status_info = {
        RUNNING = { symbol = "", color = "DiagnosticWarn" },
        FAILURE = { symbol = "✘", color = "DiagnosticError" },
        SUCCESS = { symbol = "✔", color = "DiagnosticOk" },
        CANCELED = { symbol = "⚑", color = "DiagnosticInfo" },
        PENDING = { symbol = "…", color = "Normal" },
      }

      -- Add a lualine component for each status
      for status, info in pairs(status_info) do
        table.insert(opts.sections.lualine_c, {
          function()
            local count = count_tasks_with_status(status)
            return count > 0 and (info.symbol .. " " .. count) or ""
          end,
          color = info.color,
          cond = function()
            return count_tasks_with_status(status) > 0
          end,
        })
      end
    end,
  },
}
