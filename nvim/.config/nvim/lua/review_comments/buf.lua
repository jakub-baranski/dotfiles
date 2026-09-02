-- Resolve a buffer to { root, path, side } for both diffview buffers and normal file buffers.
local M = {}

---@class ReviewBufInfo
---@field root string git toplevel (normalized, no trailing slash)
---@field path string repo-relative path
---@field side "a"|"b"

local root_cache = {} ---@type table<string, string|false>

local function normalize(p)
  p = vim.fs.normalize(p)
  return (p:gsub("/+$", ""))
end

---@param dir string
---@return string?
local function git_root(dir)
  local cached = root_cache[dir]
  if cached ~= nil then
    return cached or nil
  end
  local res = vim.system({ "git", "-C", dir, "rev-parse", "--show-toplevel" }, { text = true }):wait()
  local root = nil
  if res.code == 0 and res.stdout then
    root = normalize(vim.trim(res.stdout))
  end
  root_cache[dir] = root or false
  return root
end

---@param bufnr integer
---@return ReviewBufInfo?
local function resolve_diffview(bufnr)
  local ok, lib = pcall(require, "diffview.lib")
  if not ok then
    return nil
  end
  for _, view in ipairs(lib.views or {}) do
    local layout = view.cur_layout
    if layout and layout.files then
      local ok_files, files = pcall(layout.files, layout)
      if ok_files then
        for _, f in ipairs(files) do
          if f.bufnr == bufnr and f.path and f.adapter and f.adapter.ctx then
            return {
              root = normalize(f.adapter.ctx.toplevel),
              path = f.path,
              side = f.symbol == "a" and "a" or "b",
            }
          end
        end
      end
    end
  end
  return nil
end

---@param bufnr integer
---@return ReviewBufInfo?
local function resolve_file(bufnr)
  if vim.bo[bufnr].buftype ~= "" then
    return nil
  end
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" or name:match("^%w+://") then
    return nil
  end
  local abs = normalize(vim.fn.fnamemodify(name, ":p"))
  local root = git_root(vim.fs.dirname(abs))
  if not root or abs:sub(1, #root + 1) ~= root .. "/" then
    return nil
  end
  return { root = root, path = abs:sub(#root + 2), side = "b" }
end

---@param bufnr integer
---@return ReviewBufInfo?
function M.resolve(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "diffview://null" then
    return nil
  end
  return resolve_diffview(bufnr) or resolve_file(bufnr)
end

--- For a diffview buffer, the buffer shown on the opposite side of the same layout.
---@param bufnr integer
---@return integer? peer_bufnr
function M.peer(bufnr)
  local ok, lib = pcall(require, "diffview.lib")
  if not ok then
    return nil
  end
  for _, view in ipairs(lib.views or {}) do
    local layout = view.cur_layout
    if layout and layout.files then
      local ok_files, files = pcall(layout.files, layout)
      if ok_files then
        local mine
        for _, f in ipairs(files) do
          if f.bufnr == bufnr then
            mine = f
          end
        end
        if mine then
          for _, f in ipairs(files) do
            if f ~= mine and f.symbol ~= mine.symbol and f.bufnr and vim.api.nvim_buf_is_valid(f.bufnr) then
              if vim.api.nvim_buf_get_name(f.bufnr) ~= "diffview://null" then
                return f.bufnr
              end
            end
          end
        end
      end
    end
  end
  return nil
end

--- Loaded buffers showing the given root/path (any side).
---@param root string
---@param path string
---@return { bufnr: integer, info: ReviewBufInfo }[]
function M.buffers_for(root, path)
  local out = {}
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) then
      local info = M.resolve(b)
      if info and info.root == root and info.path == path then
        out[#out + 1] = { bufnr = b, info = info }
      end
    end
  end
  return out
end

return M
