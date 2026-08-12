local M = {}

local agda_filetypes = { "agda", "lagda", "lagda.md", "lagda.rst", "lagda.tex" }

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

  vim.cmd.write()
  return file
end

local function compile(run_after)
  local file = current_source()
  if not file then
    return
  end

  local directory = vim.fs.dirname(file)
  vim.notify("Compiling " .. vim.fs.basename(file) .. " with Agda/GHC…")

  vim.system({ "agda", "--compile", file }, { cwd = directory, text = true }, function(result)
    vim.schedule(function()
      local output = (result.stdout or "") .. (result.stderr or "")
      local lines = vim.split(output, "\n", { trimempty = true })

      vim.fn.setqflist({}, " ", {
        title = "Agda compile",
        lines = lines,
        efm = "%f:%l,%c-%*\\d:%m,%f:%l,%c:%m,%f:%l:%c:%m,%m",
      })

      if result.code ~= 0 then
        vim.cmd.copen()
        vim.notify("Agda compilation failed", vim.log.levels.ERROR)
        return
      end

      vim.cmd.cclose()
      vim.notify("Agda compilation succeeded")

      if run_after then
        local source_name = vim.fs.basename(file)
        local executable_name = source_name:gsub("%.lagda%.[^.]+$", ""):gsub("%.l?agda$", "")
        local executable = directory .. "/" .. executable_name
        if vim.fn.executable(executable) == 1 then
          require("snacks").terminal({ executable }, {
            cwd = directory,
            win = { position = "bottom", height = 0.35 },
          })
        else
          vim.notify("Compiled executable not found: " .. executable, vim.log.levels.WARN)
        end
      end
    end)
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

  local start = vim.fn.searchpairpos([[\V{!]], "", [[\V!}]], "bnW")
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
    pattern = { "*.agda", "*.lagda", "*.lagda.md", "*.lagda.rst", "*.lagda.tex" },
    command = "silent! CornelisLoad",
    desc = "Type-check Agda files after saving",
  })

  vim.api.nvim_create_autocmd("QuitPre", {
    group = group,
    pattern = { "*.agda", "*.lagda", "*.lagda.md", "*.lagda.rst", "*.lagda.tex" },
    command = "silent! CornelisCloseInfoWindows",
    desc = "Close Cornelis information windows",
  })

  if vim.tbl_contains(agda_filetypes, vim.bo.filetype) then
    map_buffer(vim.api.nvim_get_current_buf())
  end
end

return M
