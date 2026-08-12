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

local function map_buffer(buffer)
  if vim.b[buffer].agda_workflow_configured then
    return
  end
  vim.b[buffer].agda_workflow_configured = true

  local function map(lhs, rhs, description)
    vim.keymap.set("n", lhs, rhs, { buffer = buffer, silent = true, desc = description })
  end

  map("<localleader>l", command("CornelisLoad"), "Agda: load/type-check")
  map("<localleader>g", command("CornelisGive"), "Agda: give")
  map("<localleader>r", command("CornelisRefine"), "Agda: refine")
  map("<localleader>c", command("CornelisMakeCase"), "Agda: case split")
  map("<localleader>t", command("CornelisTypeContext"), "Agda: type/context")
  map("<localleader>T", command("CornelisTypeContextInfer"), "Agda: type/context/infer")
  map("<localleader>n", command("CornelisNormalize"), "Agda: normalize")
  map("<localleader>s", command("CornelisSolve"), "Agda: solve")
  map("<localleader>a", command("CornelisAuto"), "Agda: auto")
  map("<localleader>?", command("CornelisGoals"), "Agda: show goals")
  map("<localleader>b", function()
    compile(false)
  end, "Agda: compile with GHC")
  map("<localleader>x", function()
    compile(true)
  end, "Agda: compile and run")
  map("gd", command("CornelisGoToDefinition"), "Agda: go to definition")
  map("[g", command("CornelisPrevGoal"), "Agda: previous goal")
  map("]g", command("CornelisNextGoal"), "Agda: next goal")

  vim.api.nvim_buf_create_user_command(buffer, "AgdaCompile", function()
    compile(false)
  end, { desc = "Compile the current Agda module with GHC" })
  vim.api.nvim_buf_create_user_command(buffer, "AgdaRun", function()
    compile(true)
  end, { desc = "Compile and run the current Agda module" })
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
