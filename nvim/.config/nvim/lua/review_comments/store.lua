-- Persistence for review comments: one JSON file per repository root.
local M = {}

M.FILENAME = ".review-comments.json"

---@class ReviewComment
---@field id string
---@field path string repo-relative path
---@field side "a"|"b" diff side the comment was written on ("b" = working tree / new)
---@field start_line integer 1-based
---@field end_line integer 1-based, inclusive
---@field snapshot string[] text of the commented lines at creation time
---@field text string
---@field resolved boolean
---@field created_at string
---@field updated_at string

---@type table<string, ReviewComment[]>
local cache = {}

local function file_path(root)
  return root .. "/" .. M.FILENAME
end

local function now()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function gen_id()
  return string.format("%06x%04x", math.random(0, 0xffffff), math.random(0, 0xffff))
end

---@param root string
---@return ReviewComment[]
function M.load(root)
  if cache[root] then
    return cache[root]
  end
  local comments = {}
  local f = io.open(file_path(root), "r")
  if f then
    local content = f:read("*a")
    f:close()
    local ok, data = pcall(vim.json.decode, content)
    if ok and type(data) == "table" and type(data.comments) == "table" then
      comments = data.comments
    else
      vim.notify("review_comments: could not parse " .. file_path(root), vim.log.levels.WARN)
    end
  end
  cache[root] = comments
  return comments
end

local KEY_ORDER =
  { "id", "path", "side", "start_line", "end_line", "resolved", "created_at", "updated_at", "text", "snapshot" }

-- Deterministic key order so the file diffs cleanly (vim.json.encode orders keys arbitrarily).
local function encode_comment(c)
  local parts = {}
  for _, k in ipairs(KEY_ORDER) do
    if c[k] ~= nil then
      parts[#parts + 1] = vim.json.encode(k) .. ":" .. vim.json.encode(c[k])
    end
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

---@param root string
function M.save(root)
  local comments = cache[root] or {}
  local out = { '{ "version": 1, "comments": [' }
  for i, c in ipairs(comments) do
    out[#out + 1] = "  " .. encode_comment(c) .. (i < #comments and "," or "")
  end
  out[#out + 1] = "] }"
  local ok, err = pcall(vim.fn.writefile, out, file_path(root))
  if not ok then
    vim.notify("review_comments: failed to write " .. file_path(root) .. ": " .. tostring(err), vim.log.levels.ERROR)
  end
end

---@param root string
---@param path? string filter by repo-relative path
---@return ReviewComment[]
function M.list(root, path)
  local all = M.load(root)
  if not path then
    return all
  end
  return vim.tbl_filter(function(c)
    return c.path == path
  end, all)
end

---@param root string
---@param id string
---@return ReviewComment?
function M.get(root, id)
  for _, c in ipairs(M.load(root)) do
    if c.id == id then
      return c
    end
  end
end

---@param root string
---@param fields { path: string, side: string, start_line: integer, end_line: integer, snapshot: string[], text: string }
---@return ReviewComment
function M.add(root, fields)
  local comments = M.load(root)
  local ts = now()
  ---@type ReviewComment
  local c = {
    id = gen_id(),
    path = fields.path,
    side = fields.side,
    start_line = fields.start_line,
    end_line = fields.end_line,
    snapshot = fields.snapshot,
    text = fields.text,
    resolved = false,
    created_at = ts,
    updated_at = ts,
  }
  comments[#comments + 1] = c
  M.save(root)
  return c
end

---@param root string
---@param id string
---@param fields table
---@return ReviewComment?
function M.update(root, id, fields)
  local c = M.get(root, id)
  if not c then
    return nil
  end
  for k, v in pairs(fields) do
    c[k] = v
  end
  c.updated_at = now()
  M.save(root)
  return c
end

---@param root string
---@param id string
---@return boolean removed
function M.remove(root, id)
  local comments = M.load(root)
  for i, c in ipairs(comments) do
    if c.id == id then
      table.remove(comments, i)
      M.save(root)
      return true
    end
  end
  return false
end

--- Drop the in-memory cache (e.g. after the file changed on disk).
function M.invalidate(root)
  if root then
    cache[root] = nil
  else
    cache = {}
  end
end

return M
