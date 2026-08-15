local M = {}

local filetypes = require("config.filetypes")
local agda_filetypes = filetypes.agda
local compile_process
local compile_generation = 0

-- Agda 2.8 adopted GNU-style locations (`file:line.column`) while older
-- releases used commas. Keep both forms so compile output remains navigable
-- when working in projects pinned to either generation.
M.errorformat = table.concat({
  "%E%f:%l.%c-%e.%k: error: %m",
  "%E%f:%l.%c-%k: error: %m",
  "%E%f:%l.%c: error: %m",
  "%E%f:%l: error: %m",
  "%W%f:%l.%c-%e.%k: warning: %m",
  "%W%f:%l.%c-%k: warning: %m",
  "%W%f:%l.%c: warning: %m",
  "%W%f:%l: warning: %m",
  "%E%f:%l\\,%c-%e\\,%k: error: %m",
  "%E%f:%l\\,%c-%k: error: %m",
  "%E%f:%l\\,%c: error: %m",
  "%W%f:%l\\,%c-%e\\,%k: warning: %m",
  "%W%f:%l\\,%c-%k: warning: %m",
  "%W%f:%l\\,%c: warning: %m",
  "%E%f:%l:%c-%k: error: %m",
  "%E%f:%l:%c: error: %m",
  "%W%f:%l:%c-%k: warning: %m",
  "%W%f:%l:%c: warning: %m",
  "%E  %f:%l.%c-%e.%k",
  "%E  %f:%l.%c-%k",
  "%E  %f:%l.%c",
  "%E  %f:%l\\,%c-%e\\,%k",
  "%E  %f:%l\\,%c-%k",
  "%E  %f:%l\\,%c",
  "%E%f:%l\\,%c-%e\\,%k:%m",
  "%E%f:%l\\,%c:%m",
  "%C%m",
  "%-G%.%#",
}, ",")

---@param source? string
---@return string
function M.root(source)
  source = source or vim.api.nvim_buf_get_name(0)
  local directory = source ~= "" and vim.fs.dirname(vim.fs.normalize(source)) or vim.uv.cwd()
  directory = directory or vim.uv.cwd()

  local marker = vim.fs.find(function(name)
    return name == ".git" or name:match("%.agda%-lib$") ~= nil
  end, { path = directory, upward = true, limit = 1 })[1]

  return marker and vim.fs.dirname(marker) or directory
end

---@param output string
---@param source string
---@param root string
---@return string?
function M.compiled_executable(output, source, root)
  local candidates = {}
  for _, pattern in ipairs({ "%-o%s+'([^']+)'", '%-o%s+"([^"]+)"', "%-o%s+([^%s]+)" }) do
    local candidate = output:match(pattern)
    if candidate then
      candidates[#candidates + 1] = candidate
      break
    end
  end

  local source_name = vim.fs.basename(source)
  local executable_name = source_name:gsub("%.lagda%.[^.]+$", ""):gsub("%.l?agda$", "")
  vim.list_extend(candidates, {
    vim.fs.joinpath(root, executable_name),
    vim.fs.joinpath(vim.fs.dirname(source), executable_name),
  })

  for _, candidate in ipairs(candidates) do
    if candidate and candidate ~= "" then
      if not vim.startswith(candidate, "/") then
        candidate = vim.fs.joinpath(root, candidate)
      end
      candidate = vim.fs.normalize(candidate)
      if vim.fn.executable(candidate) == 1 then
        return candidate
      end
    end
  end
end

local function command(name)
  return function()
    vim.cmd(name)
  end
end

local function current_source()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    vim.notify("Save the Agda buffer before compiling it", vim.log.levels.WARN)
    return nil
  end

  if vim.bo.modified or not vim.uv.fs_stat(file) then
    vim.cmd.write()
  end
  return file
end

local function compile(run_after)
  local file = current_source()
  if not file then
    return
  end

  compile_generation = compile_generation + 1
  local generation = compile_generation
  if compile_process then
    pcall(compile_process.kill, compile_process, 15)
    compile_process = nil
  end

  local root = M.root(file)
  vim.notify("Compiling " .. vim.fs.basename(file) .. " with Agda/GHC…")

  compile_process = vim.system({ "agda", "--compile", file }, { cwd = root, text = true }, function(result)
    vim.schedule(function()
      if generation ~= compile_generation then
        return
      end
      compile_process = nil

      local output = (result.stdout or "") .. (result.stderr or "")
      local lines = vim.split(output, "\n", { trimempty = true })

      vim.fn.setqflist({}, " ", {
        title = "Agda compile",
        lines = lines,
        efm = M.errorformat,
      })

      if result.code ~= 0 then
        vim.cmd.copen()
        vim.notify("Agda compilation failed", vim.log.levels.ERROR)
        return
      end

      vim.cmd.cclose()
      vim.notify("Agda compilation succeeded")

      if run_after then
        local executable = M.compiled_executable(output, file, root)
        if executable then
          require("snacks").terminal({ executable }, {
            cwd = root,
            win = { position = "bottom", height = 0.35 },
          })
        else
          vim.notify("Agda succeeded but did not produce a runnable executable", vim.log.levels.WARN)
        end
      end
    end)
  end)
end

---@param window integer
---@return boolean
function M.cursor_in_goal(window)
  return vim.api.nvim_win_call(window, function()
    local cursor = vim.api.nvim_win_get_cursor(window)
    local column = cursor[2] + 1
    local start = vim.fn.searchpos([[\V{!]], "bcnW")
    local previous_finish = vim.fn.searchpos([[\V!}]], "bnW")
    local finish = vim.fn.searchpos([[\V!}]], "cnW")

    if start[1] == 0 or finish[1] == 0 then
      return false
    end

    local closed_before_cursor = previous_finish[1] > start[1]
      or (previous_finish[1] == start[1] and previous_finish[2] > start[2])
    if closed_before_cursor then
      return false
    end

    local after_start = cursor[1] > start[1] or (cursor[1] == start[1] and column >= start[2])
    local before_finish = cursor[1] < finish[1] or (cursor[1] == finish[1] and column <= finish[2] + 1)
    return after_start and before_finish
  end)
end

local function start_insert_in_goal()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_get_current_line()
  local insert_column = cursor[2]
  local suffix = line:sub(insert_column + 1)

  if suffix:sub(1, 2) == "{!" then
    insert_column = insert_column + 2
    if line:sub(insert_column + 1, insert_column + 1) == " " then
      insert_column = insert_column + 1
    end
  end

  if insert_column < #line or line == "" then
    vim.api.nvim_win_set_cursor(0, { cursor[1], insert_column })
    vim.cmd.startinsert()
    return
  end

  vim.api.nvim_win_set_cursor(0, { cursor[1], 0 })
  vim.cmd.startinsert({ bang = true })
end

local function move_to_current_goal_start()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local suffix = vim.api.nvim_get_current_line():sub(cursor[2] + 1)
  if suffix:sub(1, 2) == "{!" then
    return
  end

  if not M.cursor_in_goal(vim.api.nvim_get_current_win()) then
    return
  end

  local start = vim.fn.searchpos([[\V{!]], "bcnW")
  if start[1] > 0 then
    vim.api.nvim_win_set_cursor(0, { start[1], start[2] - 1 })
  end
end

local function jump_goal(name, enter_insert)
  if vim.api.nvim_get_mode().mode:sub(1, 1) == "i" then
    vim.cmd.stopinsert()
  end

  if name == "CornelisPrevGoal" then
    -- Cornelis considers the start of the current hole a previous goal when
    -- the cursor is inside it, so rewind first to reach the preceding hole.
    move_to_current_goal_start()
  end

  local buffer = vim.api.nvim_get_current_buf()
  local window = vim.api.nvim_get_current_win()
  local cursor = vim.api.nvim_win_get_cursor(window)
  local jump_id = (vim.b[buffer].agda_goal_jump_id or 0) + 1
  vim.b[buffer].agda_goal_jump_id = jump_id
  vim.cmd(name)

  local attempts = 0
  local function finish_after_jump()
    if
      not vim.api.nvim_buf_is_valid(buffer)
      or not vim.api.nvim_win_is_valid(window)
      or vim.api.nvim_win_get_buf(window) ~= buffer
      or vim.b[buffer].agda_goal_jump_id ~= jump_id
      or vim.api.nvim_get_current_win() ~= window
    then
      return
    end

    local current = vim.api.nvim_win_get_cursor(window)
    local moved = current[1] ~= cursor[1] or current[2] ~= cursor[2]
    attempts = attempts + 1
    if not moved and attempts < 100 then
      vim.defer_fn(finish_after_jump, 10)
      return
    end

    if not moved or not M.cursor_in_goal(window) then
      return
    end

    vim.api.nvim_set_current_win(window)
    vim.cmd("normal! zz")
    if enter_insert then
      start_insert_in_goal()
    end
  end

  vim.defer_fn(finish_after_jump, 10)
end

local function action_picker()
  local actions = {
    { label = "Load and type-check", command = "CornelisLoad" },
    { label = "Show all goals", command = "CornelisGoals" },
    { label = "Give goal contents", command = "CornelisGive" },
    { label = "Refine goal", command = "CornelisRefine" },
    { label = "Elaborate goal contents", command = "CornelisElaborate" },
    { label = "Case split", command = "CornelisMakeCase" },
    { label = "Show goal type and context", command = "CornelisTypeContext" },
    { label = "Show goal context and inferred type", command = "CornelisTypeContextInfer" },
    { label = "Infer type of goal contents", command = "CornelisTypeInfer" },
    { label = "Normalize goal contents", command = "CornelisNormalize" },
    { label = "Solve constraints", command = "CornelisSolve" },
    { label = "Run automatic proof search", command = "CornelisAuto" },
    { label = "Explain why name is in scope", command = "CornelisWhyInScope" },
    { label = "Copy helper function type", command = "CornelisHelperFunc" },
    { label = "Expand ? into a goal", command = "CornelisQuestionToMeta" },
    { label = "Go to definition", command = "CornelisGoToDefinition" },
    { label = "Abort current Agda command", command = "CornelisAbort" },
    { label = "Restart Cornelis", command = "CornelisRestart" },
    { label = "Compile with GHC", command = "AgdaCompile" },
    { label = "Compile and run", command = "AgdaRun" },
  }

  require("snacks").picker.select(actions, {
    prompt = "Agda actions",
    format_item = function(action, supports_highlights)
      if supports_highlights then
        return {
          { action.label },
          { "  :" .. action.command, "Comment" },
        }
      end
      return action.label .. " " .. action.command
    end,
  }, function(action)
    if action then
      vim.cmd(action.command)
    end
  end)
end

local function map_buffer(buffer)
  if vim.b[buffer].agda_workflow_configured then
    return
  end
  vim.b[buffer].agda_workflow_configured = true

  local function map(lhs, rhs, description, modes)
    vim.keymap.set(modes or "n", lhs, rhs, { buffer = buffer, silent = true, desc = description })
  end

  map("<localleader>l", command("CornelisLoad"), "Agda: load/type-check")
  map("<localleader>g", command("CornelisGive"), "Agda: give")
  map("<localleader>r", command("CornelisRefine"), "Agda: refine")
  map("<localleader>e", command("CornelisElaborate"), "Agda: elaborate")
  map("<localleader>c", command("CornelisMakeCase"), "Agda: case split")
  map("<localleader>t", command("CornelisTypeContext"), "Agda: type/context")
  map("<localleader>T", command("CornelisTypeContextInfer"), "Agda: type/context/infer")
  map("<localleader>i", command("CornelisTypeInfer"), "Agda: infer type")
  map("<localleader>n", command("CornelisNormalize"), "Agda: normalize")
  map("<localleader>s", command("CornelisSolve"), "Agda: solve")
  map("<localleader>a", command("CornelisAuto"), "Agda: auto")
  map("<localleader>w", command("CornelisWhyInScope"), "Agda: why in scope")
  map("<localleader>h", command("CornelisHelperFunc"), "Agda: copy helper type")
  map("<localleader>q", command("CornelisQuestionToMeta"), "Agda: expand ? into goal")
  map("<localleader>A", command("CornelisAbort"), "Agda: abort command")
  map("<localleader>R", command("CornelisRestart"), "Agda: restart Cornelis")
  map("<localleader>?", command("CornelisGoals"), "Agda: show goals")
  map("<localleader>p", action_picker, "Agda: pick action")
  map("<localleader>b", function()
    compile(false)
  end, "Agda: compile with GHC")
  map("<localleader>x", function()
    compile(true)
  end, "Agda: compile and run")
  map("gd", command("CornelisGoToDefinition"), "Agda: go to definition")
  map("[g", function()
    jump_goal("CornelisPrevGoal", false)
  end, "Agda: previous goal")
  map("]g", function()
    jump_goal("CornelisNextGoal", false)
  end, "Agda: next goal")
  map("<C-k>", function()
    jump_goal("CornelisPrevGoal", true)
  end, "Agda: previous goal and insert", { "n", "i" })
  map("<C-j>", function()
    jump_goal("CornelisNextGoal", true)
  end, "Agda: next goal and insert", { "n", "i" })
  map("<C-g>c", function()
    require("blink.cmp").show()
  end, "Agda: show completion", "i")
  map("<C-g>s", function()
    require("blink.cmp").show_signature()
  end, "Agda: show signature help", "i")
  map("<C-a>", command("CornelisInc"), "Agda: increment numeral")
  map("<C-x>", command("CornelisDec"), "Agda: decrement numeral")

  vim.api.nvim_buf_create_user_command(buffer, "AgdaCompile", function()
    compile(false)
  end, { desc = "Compile the current Agda module with GHC" })
  vim.api.nvim_buf_create_user_command(buffer, "AgdaRun", function()
    compile(true)
  end, { desc = "Compile and run the current Agda module" })
  vim.api.nvim_buf_create_user_command(buffer, "AgdaActions", action_picker, {
    desc = "Search available Agda actions",
  })

  local ok, which_key = pcall(require, "which-key")
  if ok then
    which_key.add({ { "<localleader>", group = "Agda", buffer = buffer } })
  end
end

local function reload_after_save(buffer)
  local reload_id = (vim.b[buffer].agda_reload_id or 0) + 1
  vim.b[buffer].agda_reload_id = reload_id

  vim.defer_fn(function()
    if
      not vim.api.nvim_buf_is_valid(buffer)
      or vim.b[buffer].agda_reload_id ~= reload_id
      or not vim.tbl_contains(agda_filetypes, vim.bo[buffer].filetype)
      or vim.fn.exists(":CornelisLoad") ~= 2
    then
      return
    end

    local ok, error_message = pcall(vim.api.nvim_buf_call, buffer, function()
      vim.cmd.CornelisLoad()
    end)
    if not ok then
      vim.notify("Cornelis reload failed: " .. tostring(error_message), vim.log.levels.WARN)
    end
  end, 200)
end

function M.setup()
  local group = vim.api.nvim_create_augroup("cornelis_agda_workflow", { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = agda_filetypes,
    callback = function(event)
      map_buffer(event.buf)
    end,
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = filetypes.agda_patterns,
    callback = function(event)
      reload_after_save(event.buf)
    end,
    desc = "Type-check Agda files after saving",
  })

  vim.api.nvim_create_autocmd("QuitPre", {
    group = group,
    pattern = filetypes.agda_patterns,
    command = "silent! CornelisCloseInfoWindows",
    desc = "Close Cornelis information windows",
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      compile_generation = compile_generation + 1
      if compile_process then
        pcall(compile_process.kill, compile_process, 15)
        compile_process = nil
      end
    end,
    desc = "Stop an active Agda compiler",
  })

  if vim.tbl_contains(agda_filetypes, vim.bo.filetype) then
    map_buffer(vim.api.nvim_get_current_buf())
  end
end

return M
