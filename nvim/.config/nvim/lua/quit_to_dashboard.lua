-- safe_close.lua

-- Command to run when the last real editor window would be closed
local function open_snacks_dashboard()
  vim.schedule(function()
    require("snacks").dashboard.open()
  end)
end

-- Helper: check if a window is a normal editor window
local function is_real_editor_window(win)
  local cfg = vim.api.nvim_win_get_config(win)
  if cfg.relative ~= "" then
    return false
  end
  local buf = vim.api.nvim_win_get_buf(win)
  local bt = vim.bo[buf].buftype
  local ft = vim.bo[buf].filetype
  if bt ~= "" and bt ~= "acwrite" then
    return false
  end
  if ft == "NvimTree" or ft == "neo-tree" or ft == "help" or ft == "qf" then
    return false
  end
  return true
end

-- Close to dashboard function
local function close_to_dashboard(force)
  local cur_win = vim.api.nvim_get_current_win()
  local remaining = 0
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win ~= cur_win and is_real_editor_window(win) then
      remaining = remaining + 1
    end
  end

  if remaining == 0 then
    open_snacks_dashboard()
  else
    vim.api.nvim_win_close(cur_win, force or false)
  end
end

-- Define a *new* command :Q (instead of :q)
vim.api.nvim_create_user_command("Q", function(opts)
  close_to_dashboard(opts.bang)
end, { bang = true, desc = "Close and - if there are no windows left - open dashboard" })

-- Override shortcut for closing window to use this new command instead of default :q
vim.keymap.set("n", "<leader>wq", close_to_dashboard, { desc = "Close window" })
