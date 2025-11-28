return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "marilari88/neotest-vitest",
    },
    opts = {
      adapters = {
        ["neotest-vitest"] = {},
      },
      -- Not sure why this does not work.
      -- https://github.com/stevearc/overseer.nvim/blob/master/doc/third_party.md#neotest
      -- consumers = {
      --   overseer = require("neotest.consumers.overseer"),
      -- },
    },
  },
}
