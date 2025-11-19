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

-- Window switching navigation
vim.keymap.set("n", "<M-j>", "<Cmd>NvimTmuxNavigateDown<CR>", { silent = true })
vim.keymap.set("n", "<M-k>", "<Cmd>NvimTmuxNavigateUp<CR>", { silent = true })
vim.keymap.set("n", "<M-l>", "<Cmd>NvimTmuxNavigateRight<CR>", { silent = true })
vim.keymap.set("n", "<M-h>", "<Cmd>NvimTmuxNavigateLeft<CR>", { silent = true })
vim.keymap.set("n", "<M-\\>", "<Cmd>NvimTmuxNavigateLastActive<CR>", { silent = true })
vim.keymap.set("n", "<C-Space>", "<Cmd>NvimTmuxNavigateNext<CR>", { silent = true })

vim.keymap.set("n", "<leader>yp", function()
  local filepath = vim.fn.expand("%:p")
  vim.fn.setreg("+", filepath)
  print("Yanked to clipboard: " .. filepath)
end, { noremap = true, silent = true, desc = "Yank buffer path to clipboard" })

-- Keybind to turn on and off colorcolumn

vim.keymap.set("n", "<leader>u2c", function()
  if vim.wo.colorcolumn == "" then
    vim.wo.colorcolumn = "100"
    print("Colorcolumn enabled at 100")
  else
    vim.wo.colorcolumn = ""
    print("Colorcolumn disabled")
  end
end, { noremap = true, silent = true, desc = "Toggle colorcolumn at 100" })
