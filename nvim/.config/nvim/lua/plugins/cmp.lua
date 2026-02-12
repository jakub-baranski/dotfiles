return {
  "saghen/blink.cmp",
  opts = {
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
      providers = {
        snippets = {
          score_offset = 100, -- Higher score = higher priority
        },
      },
    },
    completion = {
      -- Disable automatic selection of first item
      list = {
        selection = {
          preselect = false,
          auto_insert = true,
        },
      },
    },
  },
}
