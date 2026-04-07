-- Uses build in undotree but instead of just changing buffer -
-- it displays a diff panel next to the undotree window,
-- showing changes in real time as you navigate through the undotree.

-- It also allows you to jump to the change in the source buffer and ensures
-- proper cleanup when closing the undotree.
local M = {}

local ns = vim.api.nvim_create_namespace("undotree_diff")

local function apply_inline_diff(source_buf, old_lines, new_lines)
  vim.api.nvim_buf_clear_namespace(source_buf, ns, 0, -1)

  local hunks =
    vim.diff(table.concat(old_lines, "\n") .. "\n", table.concat(new_lines, "\n") .. "\n", { result_type = "indices" })

  local line_count = vim.api.nvim_buf_line_count(source_buf)

  for _, hunk in ipairs(hunks) do
    local old_start, old_count, new_start, new_count = hunk[1], hunk[2], hunk[3], hunk[4]

    -- Highlight added/changed lines
    if new_count > 0 then
      local hl_group = old_count == 0 and "DiffAdd" or "DiffChange"
      for i = new_start, new_start + new_count - 1 do
        if i <= line_count then
          pcall(vim.api.nvim_buf_set_extmark, source_buf, ns, i - 1, 0, {
            line_hl_group = hl_group,
          })
        end
      end
    end

    -- Show deleted lines as virtual text
    if old_count > 0 then
      local virt_lines = {}
      for i = old_start, old_start + old_count - 1 do
        table.insert(virt_lines, { { old_lines[i] or "", "DiffDelete" } })
      end

      -- Place virtual lines above the new_start position
      local anchor = math.max(new_start - 1, 0)
      if anchor >= line_count then
        anchor = line_count - 1
      end

      pcall(vim.api.nvim_buf_set_extmark, source_buf, ns, anchor, 0, {
        virt_lines = virt_lines,
        virt_lines_above = true,
      })
    end
  end
end

local function jump_to_change(source_win, source_buf)
  if not vim.api.nvim_win_is_valid(source_win) then
    return
  end
  local pos = vim.api.nvim_buf_get_mark(source_buf, ".")
  if pos[1] > 0 then
    vim.api.nvim_win_set_cursor(source_win, { pos[1], pos[2] })
    vim.api.nvim_win_call(source_win, function()
      vim.cmd("normal! zz")
    end)
  end
end

local function cleanup(source_buf)
  vim.api.nvim_buf_clear_namespace(source_buf, ns, 0, -1)
  vim.cmd("close")
end

function M.toggle()
  local source_win = vim.api.nvim_get_current_win()
  local source_buf = vim.api.nvim_get_current_buf()

  local already_open = require("undotree").open({
    command = "topleft 30vnew",
  })

  if already_open then
    return
  end

  local prev_lines = vim.api.nvim_buf_get_lines(source_buf, 0, -1, false)

  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = 0,
    callback = function()
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(source_buf) then
          return
        end

        local new_lines = vim.api.nvim_buf_get_lines(source_buf, 0, -1, false)
        apply_inline_diff(source_buf, prev_lines, new_lines)
        prev_lines = new_lines

        jump_to_change(source_win, source_buf)
      end)
    end,
  })

  vim.keymap.set("n", "q", function()
    cleanup(source_buf)
  end, { buffer = 0 })
  vim.keymap.set("n", "<C-f>", function()
    vim.api.nvim_win_call(source_win, function()
      vim.cmd("normal! \x06") -- <C-f>
    end)
  end, { buffer = 0 })

  vim.keymap.set("n", "<C-b>", function()
    vim.api.nvim_win_call(source_win, function()
      vim.cmd("normal! \x02") -- <C-b>
    end)
  end, { buffer = 0 })

  vim.keymap.set("n", "<C-d>", function()
    vim.api.nvim_win_call(source_win, function()
      vim.cmd("normal! \x04") -- <C-d>
    end)
  end, { buffer = 0 })

  vim.keymap.set("n", "<C-u>", function()
    vim.api.nvim_win_call(source_win, function()
      vim.cmd("normal! \x15") -- <C-u>
    end)
  end, { buffer = 0 })
end

return M
