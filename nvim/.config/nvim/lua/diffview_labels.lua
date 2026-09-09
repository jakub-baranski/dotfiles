-- Winbar labels for diffview windows.
--
-- Roles are named after the operation in progress: during a rebase git's "ours"
-- is the branch being rebased onto and "theirs" is the commit being replayed,
-- which is the opposite of what those words suggest.
local M = {}

local CACHE_TTL_NS = 2e9 -- git state changes while conflicts are resolved
local GIT_TIMEOUT_MS = 200

local cache = { key = nil, at = 0, info = nil }
local subjects = {}

---@param cwd string
---@param args string[]
---@return string[]?
local function git(cwd, args)
  -- Bounded: these are all local reads, but a label is never worth a hang. A
  -- timeout kills the child and reports code 124, i.e. the same as a failure.
  local res = vim.system(vim.list_extend({ "git" }, args), { cwd = cwd, text = true }):wait(GIT_TIMEOUT_MS)
  if res.code ~= 0 then
    return nil
  end
  local out = vim.trim(res.stdout or "")
  if out == "" then
    return nil
  end
  return vim.split(out, "\n", { plain = true })
end

---@param path string
---@return string?
local function read_line(path)
  local fd = io.open(path, "r")
  if not fd then
    return nil
  end
  local line = fd:read("*l")
  fd:close()
  return line and vim.trim(line) ~= "" and vim.trim(line) or nil
end

---@param toplevel string
---@param rev string
---@return string? # "<short sha> <subject>"
local function describe(toplevel, rev)
  -- The symbolic heads (REBASE_HEAD, CHERRY_PICK_HEAD, ...) move as the
  -- operation advances, so resolve first and memoize on the sha.
  local out = git(toplevel, { "rev-parse", "--verify", "--quiet", rev })
  local sha = out and out[1]
  if not sha then
    return nil
  end

  local key = toplevel .. "\0" .. sha
  if subjects[key] == nil then
    out = git(toplevel, { "log", "-1", "--pretty=format:%h %s", sha, "--" })
    subjects[key] = out and out[1] or false
  end
  return subjects[key] or nil
end

---@param toplevel string
---@param rev string
---@return string?
local function ref_name(toplevel, rev)
  local out = git(toplevel, { "name-rev", "--name-only", "--refs=refs/heads/*", "--refs=refs/remotes/*", rev })
  local name = out and out[1]
  if not name or name == "" or name == "undefined" or name:find("^%^") then
    return nil
  end
  return (name:gsub("^remotes/", ""))
end

---@param toplevel string
---@return string # current branch, or "detached @ <sha>"
local function head_name(toplevel)
  local out = git(toplevel, { "symbolic-ref", "--short", "HEAD" })
  if out and out[1] and out[1] ~= "" then
    return out[1]
  end
  local sha = git(toplevel, { "rev-parse", "--short", "HEAD" })
  return "detached @ " .. ((sha and sha[1]) or "?")
end

---@param git_dir string
---@param toplevel string
---@return { kind: string, ours: string, theirs: string }?
local function merge_state(git_dir, toplevel)
  local join = function(...)
    return vim.fs.joinpath(git_dir, ...)
  end
  local exists = function(p)
    return vim.uv.fs_stat(p) ~= nil
  end

  local rebase_dir = (exists(join("rebase-merge")) and join("rebase-merge"))
    or (exists(join("rebase-apply")) and join("rebase-apply"))
    or nil

  if rebase_dir then
    local branch = read_line(vim.fs.joinpath(rebase_dir, "head-name")) or ""
    branch = branch:gsub("^refs/heads/", "")
    local onto = read_line(vim.fs.joinpath(rebase_dir, "onto"))
    local onto_name = onto and (ref_name(toplevel, onto) or describe(toplevel, onto)) or head_name(toplevel)
    local at = read_line(vim.fs.joinpath(rebase_dir, "msgnum")) or read_line(vim.fs.joinpath(rebase_dir, "next"))
    local total = read_line(vim.fs.joinpath(rebase_dir, "end")) or read_line(vim.fs.joinpath(rebase_dir, "last"))
    local progress = (at and total) and (" [%s/%s]"):format(at, total) or ""

    return {
      kind = "rebase",
      ours = ("rebasing onto %s"):format(onto_name or "?"),
      theirs = ("%s%s"):format(describe(toplevel, "REBASE_HEAD") or branch, progress),
    }
  end

  if exists(join("MERGE_HEAD")) then
    local name = ref_name(toplevel, "MERGE_HEAD")
    return {
      kind = "merge",
      ours = head_name(toplevel),
      theirs = name and ("%s (%s)"):format(name, describe(toplevel, "MERGE_HEAD") or "") or describe(
        toplevel,
        "MERGE_HEAD"
      ) or "MERGE_HEAD",
    }
  end

  for name, kind in pairs({ CHERRY_PICK_HEAD = "cherry-pick", REVERT_HEAD = "revert" }) do
    if exists(join(name)) then
      return {
        kind = kind,
        ours = head_name(toplevel),
        theirs = describe(toplevel, name) or name,
      }
    end
  end
end

---@param git_dir string
---@param toplevel string
local function state(git_dir, toplevel)
  local now = vim.uv.hrtime()
  if cache.key ~= git_dir or (now - cache.at) > CACHE_TTL_NS then
    cache = { key = git_dir, at = now, info = merge_state(git_dir, toplevel) }
  end
  return cache.info
end

-- Highlights ------------------------------------------------------------------

--- First foreground found among `names`, so labels follow the colorscheme.
---@param names string[]
---@return integer?
local function fg_of(names)
  for _, name in ipairs(names) do
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
    if ok and hl and hl.fg then
      return hl.fg
    end
  end
end

local GROUPS = {
  DiffviewLabelOurs = { "GitSignsAdd", "DiffviewFilePanelInsertions", "diffAdded", "Added", "String" },
  DiffviewLabelTheirs = { "GitSignsChange", "DiffviewFilePanelPath", "diffChanged", "Changed", "Function" },
  DiffviewLabelResult = { "WarningMsg", "DiagnosticWarn", "Special" },
  DiffviewLabelBase = { "Comment" },
  DiffviewLabelRev = { "Title", "Directory", "Identifier" },
}

local function set_highlights()
  for group, sources in pairs(GROUPS) do
    vim.api.nvim_set_hl(0, group, { fg = fg_of(sources), bold = true })
  end
  vim.api.nvim_set_hl(0, "DiffviewLabelDetail", { link = "Comment" })
end

-- Labels ----------------------------------------------------------------------

---@param group string
---@param label string
---@param detail? string
---@return string
local function render(group, label, detail)
  -- `%` is a statusline escape, so anything taken from git (commit subjects,
  -- branch names) has to be doubled up.
  local escape = function(s)
    return (s:gsub("%%", "%%%%"))
  end

  local out = ("%%#%s# %s"):format(group, escape(label))
  if detail and detail ~= "" then
    out = out .. ("%%#DiffviewLabelDetail#  %s"):format(escape(detail))
  end
  return out .. "%#Normal#"
end

---@param symbol string # "a" ours, "b" working tree, "c" theirs, "d" base
---@param info { kind: string, ours: string, theirs: string }?
---@return string
local function conflict_label(symbol, info)
  local kind = info and info.kind or "merge"

  if symbol == "b" then
    return render("DiffviewLabelResult", "RESULT", "working tree — resolve the conflict here")
  elseif symbol == "d" then
    return render("DiffviewLabelBase", "BASE", "common ancestor, before either side changed it")
  elseif symbol == "a" then
    if kind == "rebase" then
      return render("DiffviewLabelOurs", "TARGET", info and info.ours or "the branch you are rebasing onto")
    end
    return render("DiffviewLabelOurs", "CURRENT", info and info.ours or "HEAD")
  elseif symbol == "c" then
    local label = ({
      merge = "INCOMING",
      rebase = "YOUR COMMIT",
      ["cherry-pick"] = "PICKED COMMIT",
      revert = "REVERTED COMMIT",
    })[kind] or "INCOMING"
    return render("DiffviewLabelTheirs", label, info and info.theirs or nil)
  end

  return ""
end

---@param file table # vcs.File
---@param toplevel string
---@param side? string # "before" | "after"
---@return string
local function rev_label(file, toplevel, side)
  local RevType = require("diffview.vcs.rev").RevType
  local rev = file.rev
  local prefix = side == "before" and "◀ BEFORE" or (side == "after" and "▶ AFTER" or nil)

  local label, detail
  if not rev then
    label, detail = "FILE", nil
  elseif rev.type == RevType.LOCAL then
    label, detail = "WORKING TREE", "unsaved and unstaged changes included"
  elseif rev.type == RevType.STAGE then
    if rev.stage == 0 then
      label, detail = "INDEX", "staged content"
    else
      label, detail = "INDEX", ("stage %d"):format(rev.stage)
    end
  elseif rev.type == RevType.COMMIT then
    label = "COMMIT"
    detail = describe(toplevel, rev.commit) or (rev.commit and rev.commit:sub(1, 10))
  else
    label, detail = "REVISION", tostring(rev)
  end

  if prefix then
    label = ("%s · %s"):format(prefix, label)
  end

  return render(side == "before" and "DiffviewLabelBase" or "DiffviewLabelRev", label, detail)
end

---@param view table
---@param winid integer
---@return table? # scene Window
local function window_of(view, winid)
  local layout = view and view.cur_layout
  for _, win in ipairs(layout and layout.windows or {}) do
    if win.id == winid then
      return win
    end
  end
end

---@param winid integer
---@param ctx { symbol: string, layout_name: string }
local function set_winbar(winid, ctx)
  local lib = require("diffview.lib")
  local view = lib.get_current_view()
  local win = window_of(view, winid)
  local file = win and win.file
  if not file or not vim.api.nvim_win_is_valid(winid) then
    return
  end

  local adapter = file.adapter or (view and view.adapter)
  local toplevel = adapter and adapter.ctx and adapter.ctx.toplevel or vim.fn.getcwd()
  local symbol = ctx and ctx.symbol or file.symbol

  local winbar
  if file.kind == "conflicting" then
    local git_dir = adapter and adapter.ctx and adapter.ctx.dir
    winbar = conflict_label(symbol, git_dir and state(git_dir, toplevel) or nil)
  else
    local n = #(view and view.cur_layout and view.cur_layout.windows or {})
    local side = n == 2 and (symbol == "a" and "before" or symbol == "b" and "after") or nil
    winbar = rev_label(file, toplevel, side)
  end

  if winbar ~= "" then
    vim.wo[winid].winbar = winbar
  end
end

--- Called from the `diff_buf_win_enter` hook, which fires after diffview has set
--- its own winbar. Labelling reads diffview internals, so a failure has to
--- degrade to "no label" rather than throw on every window enter.
---@param bufnr integer
---@param winid integer
---@param ctx { symbol: string, layout_name: string }
function M.set(bufnr, winid, ctx)
  pcall(set_winbar, winid, ctx)
end

function M.reset()
  cache = { key = nil, at = 0, info = nil }
  subjects = {}
end

function M.setup()
  set_highlights()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("diffview_labels_hl", { clear = true }),
    callback = set_highlights,
  })
end

return M
