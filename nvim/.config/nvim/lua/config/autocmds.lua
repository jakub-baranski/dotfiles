-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
--
-- In ~/.config/nvim/lua/config/autocmds.lua or a new snippets file

-- General Settings
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

local general = augroup("General", { clear = true })

-- Auto save when leaving insert mode or leaving buffer/window
-- NOTE: I don't think that is actually a good idea to have autosave...
-- autocmd({ "FocusLost", "BufLeave", "BufWinLeave", "InsertLeave" }, {
--
--   -- nested = true, -- for format on save
--   callback = function()
--     if vim.bo.filetype ~= "" and vim.bo.buftype == "" and vim.bo.modified then
--       vim.cmd("silent! w")
--     end
--   end,
--   group = general,
--   desc = "Auto Save",
-- })
