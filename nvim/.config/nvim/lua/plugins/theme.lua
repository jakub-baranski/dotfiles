return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      transparent = true,

      -- Make line numbers a bit more visible
      on_highlights = function(hl, c)
        hl.LineNrAbove = { fg = c.fg_dark }
        hl.LineNrBelow = { fg = c.fg_dark }
      end,
    },

    keys = {
      {
        -- Toggle transparency keybinding
        "<leader>ut",
        function()
          require("tokyonight").setup({
            transparent = not require("tokyonight.config").options.transparent,
          })
          vim.cmd("colorscheme tokyonight")
        end,
        desc = "Toggle Transparency",
      },
    },
  },
  {
    "rose-pine/neovim",
    enabled = false,
    name = "rose-pine",
    config = function()
      vim.cmd("colorscheme rose-pine")
    end,
  },
  {
    "f-person/auto-dark-mode.nvim",
    opts = {
      set_dark_mode = function()
        vim.api.nvim_set_option_value("background", "dark", {})
        vim.cmd("colorscheme tokyonight-moon")
      end,
      set_light_mode = function()
        vim.api.nvim_set_option_value("background", "light", {})
        vim.cmd("colorscheme tokyonight-day")
      end,
      update_interval = 3000,
      fallback = "dark",
    },
  },
}
