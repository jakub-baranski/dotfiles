-- Floating markdown editor for writing a comment.
local M = {}

---@param opts { title: string, text?: string, on_submit: fun(text: string), insert?: boolean }
function M.open(opts)
  local submitted = false

  local function submit(win)
    if submitted then
      return
    end
    submitted = true
    local lines = vim.api.nvim_buf_get_lines(win.buf, 0, -1, false)
    -- trim leading/trailing blank lines
    while #lines > 0 and lines[1]:match("^%s*$") do
      table.remove(lines, 1)
    end
    while #lines > 0 and lines[#lines]:match("^%s*$") do
      table.remove(lines)
    end
    vim.bo[win.buf].modified = false
    win:close()
    opts.on_submit(table.concat(lines, "\n"))
  end

  local function cancel(win)
    vim.bo[win.buf].modified = false
    win:close()
  end

  local win = Snacks.win({
    title = " " .. opts.title .. " ",
    title_pos = "center",
    footer = " <C-s>/:w save · q cancel ",
    footer_pos = "center",
    width = function()
      return math.min(80, vim.o.columns - 4)
    end,
    height = function()
      return math.min(12, vim.o.lines - 6)
    end,
    border = "rounded",
    enter = true,
    ft = "markdown",
    text = opts.text or "",
    bo = { buftype = "acwrite", filetype = "markdown", swapfile = false, bufhidden = "wipe" },
    wo = { wrap = true, linebreak = true, number = false, relativenumber = false, signcolumn = "no" },
    keys = {
      q = { cancel, mode = "n", desc = "Cancel" },
      ["<C-s>"] = { submit, mode = { "n", "i" }, desc = "Save comment" },
    },
    on_buf = function(self)
      vim.api.nvim_buf_set_name(self.buf, "review-comment://" .. self.buf)
      vim.api.nvim_create_autocmd("BufWriteCmd", {
        buffer = self.buf,
        callback = function()
          submit(self)
        end,
      })
    end,
  })

  if opts.insert then
    vim.schedule(function()
      if win:valid() then
        vim.cmd("startinsert!")
      end
    end)
  end
  return win
end

return M
