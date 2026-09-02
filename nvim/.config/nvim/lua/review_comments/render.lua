-- Extmark rendering of review comments (gutter sign, range highlight, virtual lines).
local buf = require("review_comments.buf")
local store = require("review_comments.store")
local anchor = require("review_comments.anchor")

local M = {}

M.ns = vim.api.nvim_create_namespace("review_comments")
M.enabled = true
M.show_outdated = true

---@class ReviewRendered
---@field id string
---@field start integer
---@field finish integer
---@field status string

---@type table<integer, ReviewRendered[]>
local state = {}

local SIGN = "󰆉"

function M.setup_highlights()
  local set = function(name, opts)
    opts.default = true
    vim.api.nvim_set_hl(0, name, opts)
  end
  set("ReviewCommentSign", { link = "DiagnosticInfo" })
  set("ReviewCommentRange", { link = "CursorLine" })
  set("ReviewCommentBorder", { link = "Comment" })
  set("ReviewCommentTitle", { link = "Title" })
  set("ReviewComment", { link = "Normal" })
  set("ReviewCommentResolved", { link = "Comment" })
  set("ReviewCommentOutdated", { link = "DiagnosticWarn" })
end

---@param text string
---@param width integer
---@return string[]
local function wrap(text, width)
  local out = {}
  for _, para in ipairs(vim.split(text, "\n", { plain = true })) do
    if para == "" then
      out[#out + 1] = ""
    else
      local line = ""
      for word in para:gmatch("%S+") do
        if line == "" then
          line = word
        elseif vim.fn.strdisplaywidth(line .. " " .. word) > width then
          out[#out + 1] = line
          line = word
        else
          line = line .. " " .. word
        end
      end
      out[#out + 1] = line
    end
  end
  return out
end

local function first_line(text)
  local l = vim.split(text, "\n", { plain = true })[1] or ""
  return (l:gsub("^%s+", ""))
end

---@param c ReviewComment
---@param loc ReviewLocation
---@param width integer
local function virt_lines_for(c, loc, width)
  local pad = "  "
  if c.resolved then
    return {
      { { pad .. "✓ resolved · ", "ReviewCommentResolved" }, { first_line(c.text), "ReviewCommentResolved" } },
    }
  end
  if loc.status == "outdated" then
    return {
      {
        { pad .. "⚠ outdated (was L" .. c.start_line .. ") · ", "ReviewCommentOutdated" },
        { first_line(c.text), "ReviewCommentResolved" },
      },
    }
  end
  local lines = {}
  local title = "review"
  if loc.status == "moved" then
    title = title .. " (moved from L" .. c.start_line .. ")"
  end
  lines[#lines + 1] = { { pad .. "╭─ " .. SIGN .. " ", "ReviewCommentBorder" }, { title, "ReviewCommentTitle" } }
  for _, l in ipairs(wrap(c.text, width)) do
    lines[#lines + 1] = { { pad .. "│ ", "ReviewCommentBorder" }, { l, "ReviewComment" } }
  end
  lines[#lines + 1] = { { pad .. "╰─", "ReviewCommentBorder" } }
  return lines
end

---@param bufnr integer
function M.clear(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)
  end
  state[bufnr] = nil
end

function M.clear_all()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    M.clear(b)
  end
end

---@param bufnr integer
local function text_width(bufnr)
  local w = 100
  for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
    w = math.min(w, vim.api.nvim_win_get_width(win) - vim.fn.getwininfo(win)[1].textoff)
  end
  return math.max(w - 6, 20)
end

--- Map a line number from `from_lines` to the corresponding line in `to_lines` using a diff.
---@param from_lines string[]
---@param to_lines string[]
---@param lnum integer 1-based
---@return integer 1-based (clamped to `to_lines`)
local function map_line(from_lines, to_lines, lnum)
  local hunks = vim.diff(table.concat(from_lines, "\n") .. "\n", table.concat(to_lines, "\n") .. "\n", {
    result_type = "indices",
  }) or {}
  local mapped = lnum
  for _, h in ipairs(hunks) do
    local fs, fc, ts, tc = h[1], h[2], h[3], h[4]
    if lnum < fs then
      break
    elseif lnum < fs + fc then
      -- inside a changed/deleted region: land on the last line of the replacement (or the line before a deletion)
      mapped = math.max(ts + tc - 1, ts, 1)
      break
    else
      mapped = lnum + (ts + tc) - (fs + fc)
    end
  end
  return math.max(1, math.min(mapped, #to_lines))
end

--- In a diffview pane, insert blank virtual lines mirroring the comments shown in the opposite pane
--- so the two panes stay aligned.
---@param bufnr integer
---@param info ReviewBufInfo
---@param lines string[]
local function render_peer_fillers(bufnr, info, lines)
  local peer = buf.peer(bufnr)
  if not peer then
    return
  end
  local peer_side = info.side == "a" and "b" or "a"
  local peer_comments = vim.tbl_filter(function(c)
    return c.side == peer_side
  end, store.list(info.root, info.path))
  if #peer_comments == 0 then
    return
  end
  local peer_lines = vim.api.nvim_buf_get_lines(peer, 0, -1, false)
  local peer_width = text_width(peer)
  for _, c in ipairs(peer_comments) do
    local loc = anchor.locate(c, peer_lines)
    if loc.status ~= "outdated" or M.show_outdated then
      local n = #virt_lines_for(c, loc, peer_width)
      local filler = {}
      for _ = 1, n do
        filler[#filler + 1] = { { "", "ReviewCommentBorder" } }
      end
      local target = map_line(peer_lines, lines, loc.finish)
      pcall(vim.api.nvim_buf_set_extmark, bufnr, M.ns, target - 1, 0, {
        virt_lines = filler,
        virt_lines_above = false,
      })
    end
  end
end

---@param bufnr integer
---@param info? ReviewBufInfo
function M.render(bufnr, info)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    state[bufnr] = nil
    return
  end
  vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)
  state[bufnr] = nil
  if not M.enabled then
    return
  end
  info = info or buf.resolve(bufnr)
  if not info then
    return
  end
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  render_peer_fillers(bufnr, info, lines)

  local comments = vim.tbl_filter(function(c)
    return c.side == info.side
  end, store.list(info.root, info.path))
  if #comments == 0 then
    return
  end

  local width = text_width(bufnr)
  local rendered = {}

  for _, c in ipairs(comments) do
    local loc = anchor.locate(c, lines)
    if loc.status ~= "outdated" or M.show_outdated then
      local hl_range = not c.resolved and loc.status ~= "outdated"
      pcall(vim.api.nvim_buf_set_extmark, bufnr, M.ns, loc.start - 1, 0, {
        sign_text = SIGN,
        sign_hl_group = c.resolved and "ReviewCommentResolved" or "ReviewCommentSign",
        priority = 50,
      })
      if hl_range then
        for l = loc.start, loc.finish do
          pcall(vim.api.nvim_buf_set_extmark, bufnr, M.ns, l - 1, 0, {
            line_hl_group = "ReviewCommentRange",
            priority = 5,
          })
        end
      end
      pcall(vim.api.nvim_buf_set_extmark, bufnr, M.ns, loc.finish - 1, 0, {
        virt_lines = virt_lines_for(c, loc, width),
        virt_lines_above = false,
      })
      rendered[#rendered + 1] = { id = c.id, start = loc.start, finish = loc.finish, status = loc.status }
    end
  end

  table.sort(rendered, function(a, b)
    return a.start < b.start
  end)
  state[bufnr] = rendered
end

---@param bufnr integer
---@param lnum integer 1-based
---@return ReviewRendered?
function M.comment_at(bufnr, lnum)
  local best
  for _, r in ipairs(state[bufnr] or {}) do
    if lnum >= r.start and lnum <= r.finish then
      if not best or (r.finish - r.start) < (best.finish - best.start) then
        best = r
      end
    end
  end
  return best
end

---@param bufnr integer
---@return ReviewRendered[]
function M.rendered(bufnr)
  return state[bufnr] or {}
end

return M
