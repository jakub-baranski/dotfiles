-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Use basedpyright as the Python LSP server inscktead of default pyright
vim.g.lazyvim_python_lsp = "basedpyright"

vim.opt.wrap = true
vim.opt.scrolloff = 8
vim.opt.colorcolumn = "100"

vim.cmd("set completeopt+=noselect")
--
vim.diagnostic.config({
  float = {
    wrap = true,
    border = "rounded",
    max_width = 100,
  },
})
