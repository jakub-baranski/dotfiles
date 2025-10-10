-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.opt.wrap = true

-- Use basedpyright as the Python LSP server instead of default pyright
vim.g.lazyvim_python_lsp = "basedpyright"
