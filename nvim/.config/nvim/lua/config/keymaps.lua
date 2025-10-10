-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--
--

-- Disable horizontal scrolling with mouse wheel
vim.keymap.set("n", "<ScrollWheelRight>", "<Nop>")

-- INDENTING
-- ------------------------------
-- For normal mode (command/normal mode)
vim.keymap.set("n", "<S-Tab>", "<<", { desc = "Shift indent left" })

-- For insert mode
vim.keymap.set("i", "<S-Tab>", "<C-d>", { desc = "Shift indent left in insert" })

-- Keep behaviour of option + backspace deleting left word in insert mode
vim.keymap.set("i", "<M-BS>", "<C-w>", { noremap = true })
