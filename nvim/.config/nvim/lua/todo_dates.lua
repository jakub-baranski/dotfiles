local M = {}

local ns = vim.api.nvim_create_namespace("todo_dates")
local cache = {}
local inflight = {}
local timer
local DEBOUNCE_MS = 150

local function is_valid_buf(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return false end
  if vim.bo[buf].buftype ~= "" then return false end
  return true
end

local function is_valid_win(win)
  if not vim.api.nvim_win_is_valid(win) then return false end
  local cfg = vim.api.nvim_win_get_config(win)
  if cfg and cfg.relative and cfg.relative ~= "" then return false end
  return true
end

local function set_virt(buf, lnum, date)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  pcall(vim.api.nvim_buf_clear_namespace, buf, ns, lnum, lnum + 1)
  pcall(vim.api.nvim_buf_set_extmark, buf, ns, lnum, 0, {
    virt_text = { { date, "Comment" } },
    virt_text_pos = "right_align",
    hl_mode = "combine",
    priority = 100,
  })
end

local function blame(buf, lnum, line_text)
  local key = buf .. ":" .. lnum
  if inflight[key] then return end
  local file = vim.api.nvim_buf_get_name(buf)
  if file == "" or vim.fn.filereadable(file) == 0 then return end

  inflight[key] = true
  vim.system(
    { "git", "blame", "-L", (lnum + 1) .. "," .. (lnum + 1), "--porcelain", "--", file },
    { cwd = vim.fs.dirname(file), text = true },
    vim.schedule_wrap(function(res)
      inflight[key] = nil
      if not vim.api.nvim_buf_is_valid(buf) then return end
      cache[buf] = cache[buf] or {}

      local current = vim.api.nvim_buf_get_lines(buf, lnum, lnum + 1, false)[1]
      if current ~= line_text then return end

      if res.code ~= 0 then
        cache[buf][lnum] = { hash = line_text, date = false }
        return
      end
      local sha = (res.stdout or ""):sub(1, 40)
      if sha:match("^0+$") then
        cache[buf][lnum] = { hash = line_text, date = false }
        return
      end
      local ts = res.stdout:match("\nauthor%-time (%d+)")
      if not ts then return end
      local date = os.date("%Y-%m-%d", tonumber(ts))
      cache[buf][lnum] = { hash = line_text, date = date }
      set_virt(buf, lnum, date)
    end)
  )
end

local function refresh(win)
  win = win or vim.api.nvim_get_current_win()
  if not is_valid_win(win) then return end
  local buf = vim.api.nvim_win_get_buf(win)
  if not is_valid_buf(buf) then return end

  local ok_hl, hl = pcall(require, "todo-comments.highlight")
  if not ok_hl then return end

  local first = vim.fn.line("w0", win) - 1
  local last = vim.fn.line("w$", win) - 1
  if last < first then return end
  local lines = vim.api.nvim_buf_get_lines(buf, first, last + 1, false)
  cache[buf] = cache[buf] or {}

  local modified = vim.bo[buf].modified

  for i, line in ipairs(lines) do
    local lnum = first + i - 1
    local ok, s = pcall(hl.match, line)
    local matched = ok and s ~= nil

    if matched then
      local is_comment = hl.is_comment(buf, lnum, s - 1)
      if is_comment == false then
        matched = false
      end
    end

    local entry = cache[buf][lnum]

    if matched then
      if entry and entry.hash == line and entry.date then
        set_virt(buf, lnum, entry.date)
      elseif not entry or entry.hash ~= line then
        pcall(vim.api.nvim_buf_clear_namespace, buf, ns, lnum, lnum + 1)
        if not modified then
          blame(buf, lnum, line)
        end
      end
    else
      if entry then cache[buf][lnum] = nil end
      pcall(vim.api.nvim_buf_clear_namespace, buf, ns, lnum, lnum + 1)
    end
  end
end

local function schedule_refresh()
  local win = vim.api.nvim_get_current_win()
  if timer then
    timer:stop()
    timer:close()
  end
  timer = vim.uv.new_timer()
  timer:start(DEBOUNCE_MS, 0, vim.schedule_wrap(function()
    if timer then
      timer:close()
      timer = nil
    end
    refresh(win)
  end))
end

local function invalidate_range(buf, first, last)
  if not cache[buf] then return end
  for lnum = first, last do
    cache[buf][lnum] = nil
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("TodoDates", { clear = true })

  vim.api.nvim_create_autocmd({ "BufWinEnter", "WinScrolled", "BufWritePost" }, {
    group = group,
    callback = schedule_refresh,
  })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group,
    callback = function(ev)
      local buf = ev.buf
      local win = vim.api.nvim_get_current_win()
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
        local first = vim.fn.line("w0", win) - 1
        local last = vim.fn.line("w$", win) - 1
        invalidate_range(buf, first, last)
      end
      schedule_refresh()
    end,
  })

  vim.api.nvim_create_autocmd("BufReadPost", {
    group = group,
    callback = function(ev)
      cache[ev.buf] = nil
      schedule_refresh()
    end,
  })

  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = group,
    callback = function(ev)
      cache[ev.buf] = nil
      if vim.api.nvim_buf_is_valid(ev.buf) then
        pcall(vim.api.nvim_buf_clear_namespace, ev.buf, ns, 0, -1)
      end
    end,
  })
end

return M
