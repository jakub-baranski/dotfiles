-- Colorscheme pairs come from the `theme` CLI (dotfiles/theme) via
-- ~/.local/state/theme/nvim.lua; auto-dark-mode picks the half, and the CLI
-- calls ThemeSync over the server socket on pair changes.

local function pair()
  local ok, p = pcall(dofile, vim.fn.expand("~/.local/state/theme/nvim.lua"))
  if ok and type(p) == "table" and p.light and p.dark then
    return p
  end
  return { light = "catppuccin-latte", dark = "tokyonight-moon" }
end

local function apply(bg)
  vim.o.background = bg
  vim.cmd.colorscheme(bg == "dark" and pair().dark or pair().light)
end

function ThemeSync()
  apply(vim.o.background)
end

return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {

      on_highlights = function(hl, c)
        -- Make line numbers a bit more visible
        hl.LineNrAbove = { fg = c.fg_dark }
        hl.LineNrBelow = { fg = c.fg_dark }

        -- Same thing for split separators
        hl.WinSeparator = { fg = c.fg_dark }
      end,
    },
  },
  -- Extra colorschemes used by theme pairs
  { "Aejkatappaja/cendre", lazy = false, priority = 1000 },
  { "rose-pine/neovim", name = "rose-pine", lazy = false, priority = 1000 },
  {
    "neanias/everforest-nvim",
    lazy = false,
    priority = 1000,
    config = function()
      -- Ghostty's built-in Everforest themes use the palette's dim
      -- background; match it so nvim panes blend with the terminal.
      require("everforest").setup({
        colours_override = function(palette)
          palette.bg0 = vim.o.background == "dark" and "#232a2e" or "#efebd4"
        end,
      })
    end,
  },
  {
    "f-person/auto-dark-mode.nvim",
    opts = {
      set_dark_mode = function()
        apply("dark")
      end,
      set_light_mode = function()
        apply("light")
      end,
      update_interval = 3000,
      fallback = "dark",
    },
  },
}
