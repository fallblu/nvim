local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
local report = table.concat(lines, "\n")
print(report)

if report:find("ERROR", 1, true) then
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
