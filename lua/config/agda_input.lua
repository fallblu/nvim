local M = {}

local glyphs = {}
local agda_filetypes = { "agda", "lagda", "lagda.md", "lagda.rst", "lagda.tex" }

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

local function decode_glyph(glyph)
  local text, move_left = glyph:gsub("<left>$", "")
  return text, move_left == 1
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

  local text, move_left = decode_glyph(glyph)
  return {
    start_col = slash - 1,
    end_col = byte_col,
    text = text,
    move_left = move_left,
  }
end

local function focus_origin(origin)
  if not vim.api.nvim_win_is_valid(origin.window) or not vim.api.nvim_buf_is_valid(origin.buffer) then
    vim.notify("The original Agda buffer is no longer available", vim.log.levels.WARN)
    return false
  end

  if vim.api.nvim_win_get_buf(origin.window) ~= origin.buffer then
    vim.notify("The original window no longer shows the Agda buffer", vim.log.levels.WARN)
    return false
  end

  vim.api.nvim_set_current_win(origin.window)
  return true
end

local function start_insert_at(window, row, byte_col)
  local line = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(window), row, row + 1, false)[1] or ""
  byte_col = math.min(byte_col, #line)

  vim.api.nvim_win_set_cursor(window, { row + 1, byte_col < #line and byte_col or 0 })
  if byte_col < #line or line == "" then
    vim.cmd.startinsert()
    return
  end

  vim.cmd.startinsert({ bang = true })
end

local function insert_choice(origin, choice)
  if not focus_origin(origin) then
    return
  end

  local text, move_left = decode_glyph(choice.glyph)
  local row = origin.cursor[1] - 1
  local column = origin.cursor[2]
  vim.api.nvim_buf_set_text(origin.buffer, row, column, row, column, { text })

  local insert_column = column + #text
  if move_left then
    insert_column = column + vim.fn.byteidx(text, vim.fn.strchars(text) - 1)
  end
  start_insert_at(origin.window, row, insert_column)
end

local function picker_entries()
  local entries = {}
  for sequence, glyph in pairs(glyphs) do
    local text = decode_glyph(glyph)
    entries[#entries + 1] = {
      character = text,
      glyph = glyph,
      sequence = sequence,
      text = text .. " \\" .. sequence .. "<Tab>",
    }
  end

  table.sort(entries, function(left, right)
    return left.sequence < right.sequence
  end)
  return entries
end

function M.pick()
  hide_completion()

  local origin = {
    buffer = vim.api.nvim_get_current_buf(),
    cursor = vim.api.nvim_win_get_cursor(0),
    insert_mode = vim.api.nvim_get_mode().mode:sub(1, 1) == "i",
    window = vim.api.nvim_get_current_win(),
  }

  require("snacks").picker.select(picker_entries(), {
    prompt = "Agda Unicode",
    format_item = function(item, supports_highlights)
      if supports_highlights then
        return {
          { item.character, "Special" },
          { "  \\" .. item.sequence .. "<Tab>", "Comment" },
        }
      end
      return item.text
    end,
  }, function(choice)
    if choice then
      insert_choice(origin, choice)
    elseif origin.insert_mode and focus_origin(origin) then
      start_insert_at(origin.window, origin.cursor[1] - 1, origin.cursor[2])
    end
  end)
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

function M.register(sequence, glyph)
  local normalized = normalize_sequence(sequence)
  local existing = glyphs[normalized]

  if existing and existing ~= glyph then
    error(("Conflicting Agda input sequence: %s"):format(normalized))
  end

  glyphs[normalized] = glyph
end

function M.setup()
  local group = vim.api.nvim_create_augroup("agda_committed_input", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = agda_filetypes,
    callback = function(event)
      if vim.b[event.buf].agda_input_configured then
        return
      end
      vim.b[event.buf].agda_input_configured = true

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

      vim.keymap.set({ "n", "i" }, "<C-Space>", M.pick, {
        buffer = event.buf,
        desc = "Search Agda Unicode input",
        silent = true,
      })

      vim.api.nvim_buf_create_user_command(event.buf, "AgdaUnicode", M.pick, {
        desc = "Search and insert an Agda Unicode character",
      })
    end,
  })
end

return M
