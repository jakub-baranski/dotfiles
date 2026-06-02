local M = {}

local function palette()
  if vim.o.background == "light" then
    return {
      [0] = { fg = "#e1e4e8" },
      [1] = { fg = "#9be9a8" },
      [2] = { fg = "#40c463" },
      [3] = { fg = "#30a14e" },
      [4] = { fg = "#216e39" },
    }
  end
  return {
    [0] = { fg = "#484f58" },
    [1] = { fg = "#347d39" },
    [2] = { fg = "#3fb950" },
    [3] = { fg = "#56d364" },
    [4] = { fg = "#7ee787" },
  }
end

local function setup_highlights()
  for level, hl in pairs(palette()) do
    vim.api.nvim_set_hl(0, "GitHeatmapL" .. level, hl)
  end
end

vim.api.nvim_create_autocmd("ColorScheme", { callback = setup_highlights })
setup_highlights()

local function level_for(count)
  if count == 0 then return 0 end
  if count <= 1 then return 1 end
  if count <= 3 then return 2 end
  if count <= 6 then return 3 end
  return 4
end

local function get_commit_counts(days)
  local result = vim.fn.system({
    "git", "log",
    "--since=" .. days .. " days ago",
    "--pretty=format:%cd",
    "--date=short",
  })
  if vim.v.shell_error ~= 0 then return {} end
  local counts = {}
  for line in result:gmatch("[^\n]+") do
    counts[line] = (counts[line] or 0) + 1
  end
  return counts
end

function M.build(opts)
  opts = opts or {}
  local weeks = opts.weeks or 16
  local start_wday = opts.week_start == "sunday" and 0 or 1
  setup_highlights()
  local counts = get_commit_counts(weeks * 7 + 7)

  local today = os.time()
  local today_wday = tonumber(os.date("%w", today))
  local today_pos = (today_wday - start_wday) % 7

  local labels = {}
  for wday, name in pairs({ [1] = "Mon", [3] = "Wed", [5] = "Fri" }) do
    labels[(wday - start_wday) % 7] = name
  end

  local chunks = {}
  local total = 0

  for row = 0, 6 do
    table.insert(chunks, { (labels[row] or "   ") .. " ", hl = "SnacksDashboardDesc" })
    for col = 1, weeks do
      local weeks_back = weeks - col
      local days_back = 7 * weeks_back + (today_pos - row)
      if days_back < 0 then
        table.insert(chunks, { "   " })
      else
        local date_str = os.date("%Y-%m-%d", today - days_back * 86400)
        local cnt = counts[date_str] or 0
        total = total + cnt
        table.insert(chunks, { "■  ", hl = "GitHeatmapL" .. level_for(cnt) })
      end
    end
    table.insert(chunks, { "\n" })
  end

  table.insert(chunks, {
    string.format("%d commits · last %d weeks", total, weeks),
    hl = "SnacksDashboardDesc",
  })

  return chunks
end

return M
