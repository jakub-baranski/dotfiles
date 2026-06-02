local source = {}
source.__index = source

local cache = { root = nil, files = nil, time = 0 }
local CACHE_TTL = 30

vim.api.nvim_create_autocmd("BufWritePost", {
  group = vim.api.nvim_create_augroup("BlinkAtFilesCache", { clear = true }),
  callback = function()
    cache.root, cache.files, cache.time = nil, nil, 0
  end,
})

local function get_root()
  local out = vim.fn.systemlist({ "git", "rev-parse", "--show-toplevel" })
  if vim.v.shell_error == 0 and out[1] and out[1] ~= "" then
    return out[1], true
  end
  return vim.fn.getcwd(), false
end

local function fetch_files(root, is_git, cb)
  local has_fd = vim.fn.executable("fd") == 1
  local cmd
  if has_fd then
    cmd = { "fd", "--type", "f", "--hidden", "--exclude", ".git", ".", root }
  elseif is_git then
    cmd = { "git", "-C", root, "ls-files", "--cached", "--others", "--exclude-standard" }
  else
    cb({})
    return
  end
  vim.system(cmd, { text = true }, function(result)
    if result.code ~= 0 then
      cb({})
      return
    end
    local files = {}
    local MAX = 2000
    for line in (result.stdout or ""):gmatch("[^\r\n]+") do
      if has_fd then
        files[#files + 1] = line:sub(#root + 2)
      else
        files[#files + 1] = line
      end
      if #files >= MAX then break end
    end
    cb(files)
  end)
end

function source.new(opts)
  return setmetatable({ opts = opts or {} }, source)
end

function source:get_trigger_characters()
  return { "@" }
end

function source:get_completions(ctx, callback)
  local line = ctx.line
  local cursor_row = ctx.cursor[1]
  local cursor_col = ctx.cursor[2]
  local before = line:sub(1, cursor_col)
  local at_pos = before:find("@[^@%s]*$")

  local function empty()
    callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
  end

  if not at_pos then
    empty()
    return function() end
  end

  -- Only trigger if @ is at start of line or preceded by whitespace
  -- (avoids firing inside email addresses, twitter handles, etc.)
  if at_pos > 1 then
    local prev = before:sub(at_pos - 1, at_pos - 1)
    if not prev:match("%s") then
      empty()
      return function() end
    end
  end

  local root, is_git = get_root()
  if not root then
    empty()
    return function() end
  end

  local at_char = at_pos - 1
  local end_char = cursor_col

  local function build_items(files)
    local items = {}
    for _, f in ipairs(files) do
      local text = "@" .. f
      local dir, name = f:match("^(.*/)([^/]+)$")
      if not name then
        dir, name = "", f
      end
      items[#items + 1] = {
        label = "@" .. name,
        labelDetails = { description = dir ~= "" and dir or nil },
        kind = vim.lsp.protocol.CompletionItemKind.File,
        insertText = text,
        filterText = text,
        textEdit = {
          newText = text,
          range = {
            start = { line = cursor_row - 1, character = at_char },
            ["end"] = { line = cursor_row - 1, character = end_char },
          },
        },
      }
    end
    return items
  end

  local now = os.time()
  if cache.root == root and cache.files and (now - cache.time) < CACHE_TTL then
    callback({
      items = build_items(cache.files),
      is_incomplete_forward = false,
      is_incomplete_backward = false,
    })
    return function() end
  end

  fetch_files(root, is_git, function(files)
    cache.root = root
    cache.files = files
    cache.time = os.time()
    vim.schedule(function()
      callback({
        items = build_items(files),
        is_incomplete_forward = false,
        is_incomplete_backward = false,
      })
    end)
  end)

  return function() end
end

return source
