return {
  "lewis6991/gitsigns.nvim",
  opts = function(_, opts)
    local lazyvim_on_attach = opts.on_attach
    opts.on_attach = function(buffer)
      if lazyvim_on_attach then
        lazyvim_on_attach(buffer)
      end

      local gs = package.loaded.gitsigns

      local function nav(direction)
        return function()
          if vim.wo.diff then
            vim.cmd.normal({ direction == "next" and "]c" or "[c", bang = true })
          else
            gs.nav_hunk(direction, {}, function()
              gs.preview_hunk_inline()
            end)
          end
        end
      end

      vim.keymap.set("n", "]h", nav("next"), { buffer = buffer, silent = true, desc = "Next Hunk (preview)" })
      vim.keymap.set("n", "[h", nav("prev"), { buffer = buffer, silent = true, desc = "Prev Hunk (preview)" })
    end
  end,
}
