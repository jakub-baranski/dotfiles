return {
  "saghen/blink.cmp",
  opts = {
    sources = {
      per_filetype = {
        markdown = { "at_files", "lsp", "path", "snippets", "buffer" },
        gitcommit = { "at_files", "path", "buffer" },
        NeogitCommitMessage = { "at_files", "path", "buffer" },
      },
      providers = {
        at_files = {
          name = "@files",
          module = "blink_at_files",
          score_offset = 100,
        },
      },
    },
  },
}
