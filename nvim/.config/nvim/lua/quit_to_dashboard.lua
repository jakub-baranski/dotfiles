-- Helper: check if a window is a normal editor window
local function is_real_editor_window(win)
  local cfg = vim.api.nvim_win_get_config(win)
  if cfg.relative ~= "" then
    return false
  end

  local buf = vim.api.nvim_win_get_buf(win)
  local bt = vim.bo[buf].buftype

  -- Early return for non-editor buffers
  if bt ~= "" and bt ~= "acwrite" then
    return false
  end

  -- Single filetype check (most common case first)
  local ft = vim.bo[buf].filetype
  return ft ~= "NvimTree" and ft ~= "neo-tree" and ft ~= "help" and ft ~= "qf"
end

-- Close to dashboard function
local function close_to_dashboard(force)
  local cur_win = vim.api.nvim_get_current_win()
  local wins = vim.api.nvim_tabpage_list_wins(0)

  local has_other_real_windows = false
  for _, win in ipairs(wins) do
    if win ~= cur_win and is_real_editor_window(win) then
      has_other_real_windows = true
      break -- Early exit once we find one
    end
  end

  if not has_other_real_windows then
    require("snacks").dashboard.open()
  else
    vim.api.nvim_win_close(cur_win, force or false)
  end
end

-- Define command and keymap
vim.api.nvim_create_user_command("Q", function(opts)
  close_to_dashboard(opts.bang)
end, { bang = true, desc = "Close and open dashboard if no windows left" })

vim.keymap.set("n", "<leader>wq", close_to_dashboard, { desc = "Close window" })
