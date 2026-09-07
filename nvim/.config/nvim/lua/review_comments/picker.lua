-- Project-wide review comment list, shown in a configurable picker (snacks by default).
local buf = require("review_comments.buf")
local store = require("review_comments.store")
local anchor = require("review_comments.anchor")

local M = {}

---@class ReviewPickerItem
---@field comment ReviewComment
---@field file string absolute path
---@field lnum integer best-effort located line
---@field status string "exact"|"moved"|"outdated"|"old"

---@param root string
---@param c ReviewComment
---@return integer, string
local function locate_line(root, c)
  if c.side == "a" then
    -- Old-side comments reference a revision, not the working tree; line number is a hint only.
    return c.start_line, "old"
  end
  local lines
  for _, b in ipairs(buf.buffers_for(root, c.path)) do
    if b.info.side == "b" then
      lines = vim.api.nvim_buf_get_lines(b.bufnr, 0, -1, false)
      break
    end
  end
  local file = root .. "/" .. c.path
  if not lines and vim.fn.filereadable(file) == 1 then
    lines = vim.fn.readfile(file)
  end
  if not lines or #lines == 0 then
    return c.start_line, "outdated"
  end
  local loc = anchor.locate(c, lines)
  return loc.start, loc.status
end

---@param root string
---@return ReviewPickerItem[]
function M.items(root)
  local items = {}
  for _, c in ipairs(store.list(root)) do
    local lnum, status = locate_line(root, c)
    items[#items + 1] = { comment = c, file = root .. "/" .. c.path, lnum = lnum, status = status }
  end
  table.sort(items, function(a, b)
    if a.comment.path ~= b.comment.path then
      return a.comment.path < b.comment.path
    end
    return a.lnum < b.lnum
  end)
  return items
end

local function first_line(text)
  local l = vim.split(text, "\n", { plain = true })[1] or ""
  return (l:gsub("^%s+", ""))
end

local backends = {}

---@param items ReviewPickerItem[]
function backends.snacks(items)
  local ok, Snacks = pcall(require, "snacks")
  if not ok or not Snacks.picker then
    vim.notify("review_comments: snacks.nvim picker not available", vim.log.levels.ERROR)
    return backends.quickfix(items)
  end
  local pitems = {}
  for _, it in ipairs(items) do
    pitems[#pitems + 1] = {
      text = it.comment.path .. " " .. it.comment.text,
      file = it.file,
      pos = { it.lnum, 0 },
      item = it,
    }
  end
  local preview_ns = vim.api.nvim_create_namespace("review_comments_preview")
  Snacks.picker({
    title = "Review comments",
    items = pitems,
    preview = function(ctx)
      require("snacks.picker.preview").file(ctx)
      local it = ctx.item.item ---@type ReviewPickerItem
      local c = it.comment
      -- Always render the full comment box in the preview, even for resolved/outdated comments.
      local full = vim.tbl_extend("force", {}, c, { resolved = false })
      local loc = { status = "exact", start = it.lnum, finish = it.lnum }
      local ok_w, win_w = pcall(vim.api.nvim_win_get_width, ctx.win)
      local width = math.max((ok_w and win_w or 80) - 8, 20)
      local last = math.min(it.lnum + (c.end_line - c.start_line), vim.api.nvim_buf_line_count(ctx.buf))
      vim.api.nvim_buf_clear_namespace(ctx.buf, preview_ns, 0, -1)
      pcall(vim.api.nvim_buf_set_extmark, ctx.buf, preview_ns, last - 1, 0, {
        virt_lines = require("review_comments.render").virt_lines_for(full, loc, width),
        virt_lines_above = false,
      })
      for l = it.lnum, last do
        pcall(vim.api.nvim_buf_set_extmark, ctx.buf, preview_ns, l - 1, 0, {
          line_hl_group = "ReviewCommentRange",
          priority = 5,
        })
      end
    end,
    format = function(entry)
      local it = entry.item ---@type ReviewPickerItem
      local c = it.comment
      local ret = {}
      ret[#ret + 1] = { c.path, "SnacksPickerFile" }
      ret[#ret + 1] = { ":", "SnacksPickerDelim" }
      ret[#ret + 1] = { tostring(it.lnum), "Number" }
      ret[#ret + 1] = { " " }
      if c.resolved then
        ret[#ret + 1] = { "✓ ", "SnacksPickerDimmed" }
      end
      if it.status == "old" then
        ret[#ret + 1] = { "(old side) ", "SnacksPickerComment" }
      elseif it.status == "outdated" then
        ret[#ret + 1] = { "⚠ ", "DiagnosticWarn" }
      end
      ret[#ret + 1] = { first_line(c.text), c.resolved and "SnacksPickerDimmed" or "" }
      return ret
    end,
  })
end

---@param items ReviewPickerItem[]
function backends.quickfix(items)
  local qf = {}
  for _, it in ipairs(items) do
    local c = it.comment
    local prefix = (c.resolved and "[resolved] " or "") .. (it.status == "old" and "[old side] " or "")
    qf[#qf + 1] = { filename = it.file, lnum = it.lnum, text = prefix .. first_line(c.text) }
  end
  vim.fn.setqflist({}, " ", { title = "Review comments", items = qf })
  vim.cmd.copen()
end

--- Open the comment list.
---@param root string
---@param backend? string|fun(items: ReviewPickerItem[], root: string) picker backend, default "snacks"
function M.open(root, backend)
  local items = M.items(root)
  if #items == 0 then
    vim.notify("review_comments: no comments in this repository", vim.log.levels.INFO)
    return
  end
  if type(backend) == "function" then
    return backend(items, root)
  end
  local fn = backends[backend or "snacks"]
  if not fn then
    vim.notify("review_comments: unknown picker backend " .. tostring(backend), vim.log.levels.ERROR)
    fn = backends.quickfix
  end
  fn(items)
end

return M
