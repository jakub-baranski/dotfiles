-- Local review comments: annotate lines/ranges in diffview or normal buffers,
-- persisted in <git root>/.review-comments.json.
local buf = require("review_comments.buf")
local store = require("review_comments.store")
local render = require("review_comments.render")
local editor = require("review_comments.editor")

local M = {}

---@class ReviewOpts
---@field picker string|fun(items: ReviewPickerItem[], root: string) "snacks" (default), "quickfix", or a custom function
M.opts = { picker = "snacks" }

local DEBOUNCE_MS = 150
local timer

--- Repo root of the current buffer, falling back to the cwd's repo.
---@return string?
local function project_root()
  local info = buf.resolve(vim.api.nvim_get_current_buf())
  if info then
    return info.root
  end
  local res = vim.system({ "git", "rev-parse", "--show-toplevel" }, { cwd = vim.fn.getcwd(), text = true }):wait()
  if res.code == 0 then
    return vim.trim(res.stdout)
  end
end

---@param bufnr? integer
function M.refresh(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  render.render(bufnr)
  -- keep the opposite diffview pane's alignment fillers in sync
  local peer = buf.peer(bufnr)
  if peer then
    render.render(peer)
  end
end

local function refresh_path(root, path)
  for _, b in ipairs(buf.buffers_for(root, path)) do
    render.render(b.bufnr, b.info)
  end
end

local function schedule_refresh(bufnr)
  if timer then
    timer:stop()
    timer:close()
  end
  timer = vim.uv.new_timer()
  timer:start(
    DEBOUNCE_MS,
    0,
    vim.schedule_wrap(function()
      if timer then
        timer:close()
        timer = nil
      end
      M.refresh(bufnr)
    end)
  )
end

---@param bufnr integer
---@return ReviewBufInfo?
local function require_info(bufnr)
  local info = buf.resolve(bufnr)
  if not info then
    vim.notify("review_comments: buffer is not a file inside a git repository", vim.log.levels.WARN)
  end
  return info
end

---@param bufnr integer
---@return ReviewComment?, ReviewBufInfo?
local function comment_at_cursor(bufnr)
  local info = require_info(bufnr)
  if not info then
    return nil
  end
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local r = render.comment_at(bufnr, lnum)
  if not r then
    vim.notify("review_comments: no comment under cursor", vim.log.levels.INFO)
    return nil, info
  end
  return store.get(info.root, r.id), info
end

--- Current line range: visual selection if in visual mode, else cursor line.
---@return integer, integer
local function current_range()
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    local s = vim.fn.getpos("v")[2]
    local e = vim.fn.getpos(".")[2]
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
    return math.min(s, e), math.max(s, e)
  end
  local l = vim.api.nvim_win_get_cursor(0)[1]
  return l, l
end

---@param start_line? integer
---@param end_line? integer
function M.add(start_line, end_line)
  local bufnr = vim.api.nvim_get_current_buf()
  local info = require_info(bufnr)
  if not info then
    return
  end
  if not start_line then
    start_line, end_line = current_range()
  end
  end_line = end_line or start_line
  local snapshot = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local range = start_line == end_line and tostring(start_line) or (start_line .. "-" .. end_line)

  editor.open({
    title = "Review · " .. info.path .. ":" .. range,
    insert = true,
    on_submit = function(text)
      if text == "" then
        return
      end
      store.add(info.root, {
        path = info.path,
        side = info.side,
        start_line = start_line,
        end_line = end_line,
        snapshot = snapshot,
        text = text,
      })
      refresh_path(info.root, info.path)
    end,
  })
end

--- Show the full comment under the cursor in a floating window.
function M.show()
  local bufnr = vim.api.nvim_get_current_buf()
  local c = comment_at_cursor(bufnr)
  if not c then
    return
  end
  local header = string.format(
    "%s:%d%s%s%s",
    c.path,
    c.start_line,
    c.end_line ~= c.start_line and ("-" .. c.end_line) or "",
    c.resolved and " · resolved" or "",
    c.side == "a" and " · old side" or ""
  )
  local lines = vim.list_extend({ header, "" }, vim.split(c.text, "\n", { plain = true }))
  vim.lsp.util.open_floating_preview(lines, "markdown", {
    border = "rounded",
    focusable = true,
    focus = true,
    wrap = true,
    max_width = 80,
    title = " Review comment ",
    close_events = { "CursorMoved", "BufLeave" },
  })
end

function M.edit()
  local bufnr = vim.api.nvim_get_current_buf()
  local c, info = comment_at_cursor(bufnr)
  if not c or not info then
    return
  end
  editor.open({
    title = "Edit · " .. c.path .. ":" .. c.start_line,
    text = c.text,
    on_submit = function(text)
      if text == "" or text == c.text then
        return
      end
      store.update(info.root, c.id, { text = text })
      refresh_path(info.root, info.path)
    end,
  })
end

function M.delete()
  local bufnr = vim.api.nvim_get_current_buf()
  local c, info = comment_at_cursor(bufnr)
  if not c or not info then
    return
  end
  if vim.fn.confirm("Delete review comment?\n" .. c.text, "&Yes\n&No", 2) ~= 1 then
    return
  end
  store.remove(info.root, c.id)
  refresh_path(info.root, info.path)
end

function M.toggle_resolved()
  local bufnr = vim.api.nvim_get_current_buf()
  local c, info = comment_at_cursor(bufnr)
  if not c or not info then
    return
  end
  store.update(info.root, c.id, { resolved = not c.resolved })
  refresh_path(info.root, info.path)
end

function M.toggle()
  render.enabled = not render.enabled
  if render.enabled then
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(b) then
        render.render(b)
      end
    end
  else
    render.clear_all()
  end
  vim.notify("review_comments: " .. (render.enabled and "enabled" or "disabled"))
end

---@param dir 1|-1
local function jump(dir)
  local bufnr = vim.api.nvim_get_current_buf()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local items = render.rendered(bufnr)
  local target
  if dir > 0 then
    for _, r in ipairs(items) do
      if r.start > lnum then
        target = r
        break
      end
    end
  else
    for i = #items, 1, -1 do
      if items[i].start < lnum then
        target = items[i]
        break
      end
    end
  end
  if not target then
    vim.notify("review_comments: no more comments", vim.log.levels.INFO)
    return
  end
  vim.api.nvim_win_set_cursor(0, { target.start, 0 })
end

--- Copy all unresolved comments of the current repo to the clipboard as markdown,
--- ready to paste into an agent prompt.
function M.export()
  local root = project_root()
  if not root then
    vim.notify("review_comments: not inside a git repository", vim.log.levels.WARN)
    return
  end
  local comments = vim.tbl_filter(function(c)
    return not c.resolved
  end, store.list(root))
  if #comments == 0 then
    vim.notify("review_comments: no unresolved comments", vim.log.levels.INFO)
    return
  end
  table.sort(comments, function(a, b)
    if a.path ~= b.path then
      return a.path < b.path
    end
    return a.start_line < b.start_line
  end)

  local out = { "# Review comments", "" }
  for i, c in ipairs(comments) do
    local range = c.start_line == c.end_line and tostring(c.start_line) or (c.start_line .. "-" .. c.end_line)
    local side = c.side == "a" and " (on the old/removed version of these lines)" or ""
    out[#out + 1] = string.format("## %d. `%s:%s`%s", i, c.path, range, side)
    out[#out + 1] = ""
    out[#out + 1] = "Referenced code:"
    out[#out + 1] = "```"
    vim.list_extend(out, c.snapshot)
    out[#out + 1] = "```"
    out[#out + 1] = ""
    vim.list_extend(out, vim.split(c.text, "\n", { plain = true }))
    out[#out + 1] = ""
  end
  local text = table.concat(out, "\n")
  vim.fn.setreg("+", text)
  vim.fn.setreg('"', text)
  vim.notify(("review_comments: copied %d comment(s) to clipboard"):format(#comments))
end

--- List all comments in the repository in the configured picker.
function M.list()
  local root = project_root()
  if not root then
    vim.notify("review_comments: not inside a git repository", vim.log.levels.WARN)
    return
  end
  require("review_comments.picker").open(root, M.opts.picker)
end

function M.next()
  jump(1)
end

function M.prev()
  jump(-1)
end

---@param opts? ReviewOpts
function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})
  render.setup_highlights()
  local group = vim.api.nvim_create_augroup("ReviewComments", { clear = true })

  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = render.setup_highlights })

  vim.api.nvim_create_autocmd({ "BufWinEnter", "BufWritePost" }, {
    group = group,
    callback = function(ev)
      schedule_refresh(ev.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group,
    callback = function(ev)
      schedule_refresh(ev.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = group,
    callback = function(ev)
      render.clear(ev.buf)
    end,
  })

  -- Reload the store when the comments file is written by something else (e.g. another nvim).
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = "*/" .. store.FILENAME,
    callback = function()
      store.invalidate()
    end,
  })

  vim.api.nvim_create_user_command("ReviewComment", function(opts)
    local sub = opts.fargs[1] or "add"
    if sub == "add" then
      if opts.range > 0 then
        M.add(opts.line1, opts.line2)
      else
        M.add()
      end
    elseif sub == "show" then
      M.show()
    elseif sub == "edit" then
      M.edit()
    elseif sub == "delete" then
      M.delete()
    elseif sub == "resolve" then
      M.toggle_resolved()
    elseif sub == "toggle" then
      M.toggle()
    elseif sub == "refresh" then
      store.invalidate()
      M.refresh()
    elseif sub == "export" then
      M.export()
    elseif sub == "list" then
      M.list()
    elseif sub == "next" then
      M.next()
    elseif sub == "prev" then
      M.prev()
    else
      vim.notify("ReviewComment: unknown subcommand " .. sub, vim.log.levels.ERROR)
    end
  end, {
    nargs = "?",
    range = true,
    complete = function()
      return { "add", "show", "edit", "delete", "resolve", "toggle", "refresh", "export", "list", "next", "prev" }
    end,
  })
end

return M
