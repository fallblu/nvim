local M = {}

local glyphs = {}

local function normalize_sequence(sequence)
  -- The original Vim mappings escape bars because `:map` treats them as
  -- command separators. They are ordinary characters in the committed input.
  return sequence:gsub([[\|]], "|")
end

local function fallback_tab(mapping)
  if type(mapping.callback) == "function" then
    return mapping.callback()
  end

  if mapping.expr == 1 and mapping.rhs and mapping.rhs ~= "" then
    return mapping.rhs
  end

  return "\t"
end

local function hide_completion()
  local ok, cmp = pcall(require, "blink.cmp")
  if ok then
    vim.schedule(cmp.hide)
  end
end

local function expansion_before_cursor(line, byte_col)
  local prefix = line:sub(1, byte_col)
  local slash

  for index = #prefix, 1, -1 do
    if prefix:sub(index, index) == [[\]] then
      slash = index
      break
    end
  end

  if not slash then
    return nil
  end

  local sequence = prefix:sub(slash + 1)
  local glyph = glyphs[sequence]
  if not glyph then
    return nil
  end

  local text, move_left = glyph:gsub("<left>$", "")
  return {
    start_col = slash - 1,
    end_col = byte_col,
    text = text,
    move_left = move_left == 1,
  }
end

function M.commit()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1
  local line = vim.api.nvim_get_current_line()
  local expansion = expansion_before_cursor(line, cursor[2])
  if not expansion then
    return
  end

  vim.api.nvim_buf_set_text(0, row, expansion.start_col, row, expansion.end_col, { expansion.text })

  local cursor_col = expansion.start_col + #expansion.text
  if expansion.move_left then
    local character_count = vim.fn.strchars(expansion.text)
    cursor_col = expansion.start_col + vim.fn.byteidx(expansion.text, character_count - 1)
  end
  vim.api.nvim_win_set_cursor(0, { row + 1, cursor_col })
end

function M.setup()
  vim.cmd.runtime("autoload/agda.vim")

  for sequence, glyph in pairs(vim.g["agda#glyphs"]) do
    local normalized = normalize_sequence(sequence)
    local existing = glyphs[normalized]

    if existing and existing ~= glyph then
      error(("Conflicting Agda input sequence: %s"):format(normalized))
    end

    glyphs[normalized] = glyph
  end

  local group = vim.api.nvim_create_augroup("agda_committed_input", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "agda",
    callback = function(event)
      local tab_mapping = vim.fn.maparg("<Tab>", "i", false, true)

      vim.keymap.set("i", "<Tab>", function()
        local cursor = vim.api.nvim_win_get_cursor(0)
        local line = vim.api.nvim_get_current_line()
        local expansion = expansion_before_cursor(line, cursor[2])
        if expansion then
          hide_completion()
          return "<Cmd>lua require('config.agda_input').commit()<CR>"
        end

        return fallback_tab(tab_mapping)
      end, {
        buffer = event.buf,
        desc = "Commit Agda Unicode input or use Tab",
        expr = true,
        replace_keycodes = true,
        silent = true,
      })
    end,
  })
end

return M
