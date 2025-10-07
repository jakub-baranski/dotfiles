return {
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    opts = function()
      local user = vim.env.USER or "User"
      user = user:sub(1, 1):upper() .. user:sub(2)
      return {
        model = "gpt-4.1", -- AI model to use
        auto_insert_mode = true,
        question_header = "  " .. user .. " ",
        auto_fold = true, -- Automatically folds non-assistant messages
        title = "🤖 AI Assistant",
        answer_header = "  Copilot ",
        separator = "━━",
        window = {
          width = 0.3, -- Fixed width in columns
        },
      }
    end,
  },
}
