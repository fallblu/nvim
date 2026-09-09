local M = {}

M.default = "kanagawa-wave"
M.options = {
  { name = "kanagawa-wave", label = "Kanagawa Wave" },
  { name = "kanagawa-dragon", label = "Kanagawa Dragon" },
  { name = "catppuccin-mocha", label = "Catppuccin Mocha" },
  { name = "catppuccin-macchiato", label = "Catppuccin Macchiato" },
  { name = "tokyonight-night", label = "Tokyo Night" },
  { name = "tokyonight-moon", label = "Tokyo Night Moon" },
  { name = "tokyonight-storm", label = "Tokyo Night Storm" },
  { name = "rose-pine", label = "Rosé Pine" },
  { name = "rose-pine-moon", label = "Rosé Pine Moon" },
  { name = "gruvbox", label = "Gruvbox Dark" },
  { name = "nightfox", label = "Nightfox" },
  { name = "duskfox", label = "Duskfox" },
  { name = "carbonfox", label = "Carbonfox" },
  { name = "nordfox", label = "Nordfox" },
  { name = "terafox", label = "Terafox" },
  { name = "everforest", label = "Everforest" },
  { name = "oxocarbon", label = "Oxocarbon" },
}

local supported = {}
for _, option in ipairs(M.options) do
  supported[option.name] = true
end

---@return string
function M.state_file()
  return vim.fs.joinpath(vim.fn.stdpath("state"), "colorscheme")
end

---@param name string?
---@return boolean
function M.supports(name)
  return name ~= nil and supported[name] == true
end

---@param path? string
---@return string
function M.selected(path)
  path = path or M.state_file()
  local ok, lines = pcall(vim.fn.readfile, path)
  local name = ok and vim.trim(lines[1] or "") or ""
  return M.supports(name) and name or M.default
end

---@param name string
---@param path? string
---@return boolean success
---@return string? error
function M.persist(name, path)
  if not M.supports(name) then
    return false, "unsupported colorscheme: " .. name
  end

  path = path or M.state_file()
  local directory = vim.fn.fnamemodify(path, ":h")
  if vim.fn.mkdir(directory, "p") == 0 and vim.fn.isdirectory(directory) == 0 then
    return false, "could not create state directory: " .. directory
  end

  local ok, result = pcall(vim.fn.writefile, { name }, path)
  if not ok or result ~= 0 then
    return false, ok and "could not write colorscheme state" or tostring(result)
  end
  return true
end

---@param name string
---@return boolean success
---@return string? error
function M.apply(name)
  if not M.supports(name) then
    return false, "unsupported colorscheme: " .. name
  end
  vim.o.background = "dark"
  local ok, err = pcall(vim.cmd.colorscheme, name)
  return ok, ok and nil or tostring(err)
end

function M.load()
  local name = M.selected()
  local ok, err = M.apply(name)
  if not ok and name ~= M.default then
    ok, err = M.apply(M.default)
  end
  if not ok then
    error(err)
  end
end

function M.pick()
  local selected = M.selected()
  local snacks = require("snacks")
  local items = vim.tbl_map(function(option)
    return {
      text = option.name,
      label = option.label,
    }
  end, M.options)

  snacks.picker({
    title = "Dark colorschemes",
    items = items,
    format = function(item)
      return {
        { item.text == selected and "● " or "  ", hl = "Special" },
        { item.label },
      }
    end,
    preview = "colorscheme",
    preset = "vertical",
    confirm = function(picker, item)
      picker:close()
      if not item then
        return
      end

      picker.preview.state.colorscheme = nil
      vim.schedule(function()
        local applied, apply_error = M.apply(item.text)
        if not applied then
          vim.notify(apply_error or "could not apply colorscheme", vim.log.levels.ERROR, { title = "Colorscheme" })
          return
        end

        local persisted, persist_error = M.persist(item.text)
        if not persisted then
          vim.notify(persist_error or "could not save colorscheme", vim.log.levels.ERROR, { title = "Colorscheme" })
        end
      end)
    end,
  })
end

return M
