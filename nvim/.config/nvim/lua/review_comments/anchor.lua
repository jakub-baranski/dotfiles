-- Locate a comment inside a buffer's current lines.
local M = {}

---@class ReviewLocation
---@field start integer 1-based
---@field finish integer 1-based inclusive
---@field status "exact"|"moved"|"outdated"

local function rtrim(s)
  return (s:gsub("%s+$", ""))
end

---@param lines string[]
---@param snapshot string[]
---@param at integer 1-based index to test
---@return boolean
local function matches_at(lines, snapshot, at)
  for i, s in ipairs(snapshot) do
    local l = lines[at + i - 1]
    if l == nil or rtrim(l) ~= rtrim(s) then
      return false
    end
  end
  return true
end

---@param comment ReviewComment
---@param lines string[]
---@return ReviewLocation
function M.locate(comment, lines)
  local n = #lines
  local snap = comment.snapshot or {}
  local len = math.max(#snap, 1)
  local start = comment.start_line

  if #snap > 0 then
    if matches_at(lines, snap, start) then
      return { start = start, finish = start + len - 1, status = "exact" }
    end
    -- Search outwards from the original position so the closest match wins.
    local max_dist = math.max(start - 1, n - start)
    for d = 1, max_dist do
      for _, cand in ipairs({ start - d, start + d }) do
        if cand >= 1 and cand + len - 1 <= n and matches_at(lines, snap, cand) then
          return { start = cand, finish = cand + len - 1, status = "moved" }
        end
      end
    end
  end

  local s = math.max(1, math.min(start, n))
  return { start = s, finish = s, status = "outdated" }
end

return M
