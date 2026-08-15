local M = {}

local function absolute_path(path, root)
  if path:sub(1, 1) == "/" or path:match("^%a:[/\\]") then
    return vim.fs.normalize(path)
  end
  return vim.fs.joinpath(root, path)
end

---@param output string
---@param root string
---@return table[]
function M.parse_dune(output, root)
  local items = {}
  local current

  local function finish()
    if not current then
      return
    end
    current.text = vim.trim(table.concat(current.message, "\n"))
    current.message = nil
    current.type = current.text:match("^Warning") and "W" or "E"
    items[#items + 1] = current
    current = nil
  end

  for _, line in ipairs(vim.split(output, "\n", { plain = true })) do
    local filename, lnum, col = line:match('^File "(.-)", line (%d+), characters (%d+)%-%d+:')
    if not filename then
      local _range_end
      filename, lnum, _range_end, col = line:match('^File "(.-)", lines (%d+)%-(%d+), characters (%d+)%-%d+:')
    end

    if filename then
      finish()
      current = {
        filename = absolute_path(filename, root),
        lnum = tonumber(lnum),
        col = tonumber(col) + 1,
        message = {},
      }
    elseif current then
      current.message[#current.message + 1] = line
    end
  end
  finish()

  if #items == 0 then
    for _, line in ipairs(vim.split(output, "\n", { plain = true, trimempty = true })) do
      items[#items + 1] = { text = line, valid = 0 }
    end
  end

  return items
end

return M
