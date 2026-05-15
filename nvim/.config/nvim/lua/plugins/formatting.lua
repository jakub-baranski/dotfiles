return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      python = { "ruff" },
      lua = { "stylua" },
      javascript = { "eslint_d" },
      typescript = { "eslint_d" },
      typescriptreact = { "eslint_d" },
    },
  },
}
