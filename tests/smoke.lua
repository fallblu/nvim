local failures = {}
local passed = 0

---@param value any
---@param message? string
local function assert_truthy(value, message)
  if not value then
    error(message or "expected a truthy value", 2)
  end
end

---@param actual any
---@param expected any
---@param message? string
local function assert_equal(actual, expected, message)
  if not vim.deep_equal(actual, expected) then
    error(
      (message or "values differ")
        .. ("\nexpected: %s\nactual:   %s"):format(vim.inspect(expected), vim.inspect(actual)),
      2
    )
  end
end

---@param name string
---@param callback fun()
local function test(name, callback)
  local success, result = xpcall(callback, debug.traceback)
  if success then
    passed = passed + 1
    print("ok - " .. name)
  else
    failures[#failures + 1] = ("%s\n%s"):format(name, result)
    print("not ok - " .. name)
  end
end

---@param name string
---@param specs table[]
---@return table
local function plugin_spec(name, specs)
  for _, spec in ipairs(specs) do
    if spec[1] == name then
      return spec
    end
  end
  error("plugin spec not found: " .. name)
end

---@param lines string[]
---@param callback fun(buffer: integer)
local function with_scratch_buffer(lines, callback)
  local previous = vim.api.nvim_get_current_buf()
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.bo[buffer].bufhidden = "wipe"
  vim.bo[buffer].swapfile = false
  vim.api.nvim_set_current_buf(buffer)
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)

  local success, result = xpcall(function()
    callback(buffer)
  end, debug.traceback)

  if vim.api.nvim_buf_is_valid(previous) then
    vim.api.nvim_set_current_buf(previous)
  end
  if vim.api.nvim_buf_is_valid(buffer) then
    vim.api.nvim_buf_delete(buffer, { force = true })
  end

  if not success then
    error(result)
  end
end

-- Headless startup can finish its command queue before LazyVim emits this
-- event, while an interactive session emits it immediately after startup.
vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy", modeline = false })
vim.wait(300)

test("loads every local module", function()
  for _, module in ipairs({
    "config.agda",
    "config.agda_input",
    "config.filetypes",
    "config.ocaml",
    "config.ocaml_cache",
    "config.ocaml_indent",
    "config.ocaml_output",
    "config.ocaml_workflow",
    "config.terminal",
    "garrett.health",
  }) do
    assert_truthy(require(module), "failed to load " .. module)
  end
end)

test("applies core options and global mappings", function()
  assert_equal(vim.o.breakindent, true)
  assert_equal(vim.o.mouse, "")
  assert_equal(vim.o.scrolloff, 8)
  assert_equal(vim.fn.maparg("<leader>uP", "n", false, true).desc, "Toggle Precognition")
  assert_equal(vim.fn.maparg("<leader>uH", "n", false, true).desc, "Toggle Hardtime")
  assert_equal(vim.fn.maparg("<C-/>", "n", false, true).desc, "Terminal (Root Dir)")
end)

test("keeps motion training recoverable", function()
  local hardtime = plugin_spec("m4xshen/hardtime.nvim", require("plugins.workflow"))
  assert_equal(hardtime.opts.force_exit_insert_mode, false)
  assert_equal(hardtime.opts.max_insert_idle_ms, nil)
  assert_equal(hardtime.opts.disabled_filetypes["snacks_.*"], true)

  local precognition = plugin_spec("tris203/precognition.nvim", require("plugins.precognition"))
  assert_equal(precognition.opts.startVisible, true)
  assert_equal(precognition.opts.showBlankVirtLine, false)
end)

test("gives each custom shell terminal a stable identity", function()
  local terminal_spec = plugin_spec("folke/snacks.nvim", require("plugins.terminal"))
  local captures = {}
  local original_snacks = package.loaded.snacks
  package.loaded.snacks = {
    terminal = function(command, opts)
      captures[#captures + 1] = { command = command, opts = opts }
    end,
  }

  local success, result = xpcall(function()
    for _, lhs in ipairs({ "<leader>;t", "<leader>;s", "<leader>;v" }) do
      local mapping
      for _, candidate in ipairs(terminal_spec.keys) do
        if candidate[1] == lhs then
          mapping = candidate
          break
        end
      end
      assert_truthy(mapping, "missing terminal mapping " .. lhs)
      mapping[2]()
    end
  end, debug.traceback)
  package.loaded.snacks = original_snacks
  if not success then
    error(result)
  end

  assert_equal(
    vim.tbl_map(function(item)
      return item.opts.count
    end, captures),
    { 2, 3, 4 }
  )
  assert_truthy(captures[1].opts.cwd and captures[1].opts.cwd ~= "")
end)

test("resolves runnable Python and pytest commands", function()
  local terminal = require("config.terminal")
  local root = terminal.root()
  local python = terminal.python_command(root)
  local pytest = terminal.pytest_command(root)

  assert_truthy(python and #python > 0, "no Python command resolved")
  assert_truthy(pytest and #pytest > 0, "no pytest command resolved")
  assert_equal(terminal.directory_exists(root), true)
end)

test("keeps Agda aliases and parser setup synchronized", function()
  local filetypes = require("config.filetypes").agda
  local seen = {}
  for _, filetype in ipairs(filetypes) do
    assert_truthy(not seen[filetype], "duplicate Agda filetype: " .. filetype)
    seen[filetype] = true
  end
  for _, filetype in ipairs({ "agda", "lagda", "markdown.agda", "rst.agda", "tex.agda" }) do
    assert_truthy(seen[filetype], "missing Agda filetype: " .. filetype)
  end

  local agda_specs = require("plugins.agda")
  local treesitter = plugin_spec("nvim-treesitter/nvim-treesitter", agda_specs)
  local opts = { ensure_installed = {} }
  treesitter.opts(nil, opts)
  assert_truthy(vim.tbl_contains(opts.ensure_installed, "agda"))

  local loaded, result = pcall(vim.treesitter.language.add, "agda")
  assert_truthy(loaded and result, "Agda Tree-sitter parser is not installed")
end)

test("parses modern Agda diagnostics into navigable quickfix entries", function()
  local agda = require("config.agda")
  vim.fn.setqflist({}, " ", {
    lines = {
      "Checking Example (/tmp/Example.agda).",
      "/tmp/Example.agda:11.8-46.18: error: [UnsolvedInteractionMetas]",
      "Unsolved interaction metas at the following locations:",
      "  /tmp/Example.agda:14.10-11",
      "  /tmp/Example.agda:17.18-19",
    },
    efm = agda.errorformat,
  })

  local items = vim.fn.getqflist()
  assert_equal(#items, 3)
  assert_equal({ items[1].lnum, items[1].col, items[1].end_lnum, items[1].end_col, items[1].type }, {
    11,
    8,
    46,
    18,
    "E",
  })
  assert_equal({ items[2].lnum, items[2].col, items[2].end_col }, { 14, 10, 11 })
  vim.fn.setqflist({})
end)

test("resolves Agda project roots and compiler output", function()
  local agda = require("config.agda")
  local root = vim.fs.normalize(vim.fn.getcwd())
  local source = vim.fs.joinpath(root, "tests", "Example.agda")
  assert_equal(agda.root(source), root)

  local shell = vim.fn.exepath("sh")
  assert_truthy(shell ~= "")
  assert_equal(agda.compiled_executable("Calling: ghc -o " .. shell .. " Main.hs", source, root), shell)
  assert_equal(agda.compiled_executable(('Calling: ghc -o "%s" Main.hs'):format(shell), source, root), shell)
end)

test("distinguishes Agda goals from text between them", function()
  local agda = require("config.agda")
  local line = "first = {! !}  between  second = {! value !}"

  with_scratch_buffer({ line }, function()
    local first_start = assert(line:find("{!", 1, true)) - 1
    local between = assert(line:find("between", 1, true)) - 1
    local second_start = assert(line:find("{!", first_start + 3, true)) - 1
    local final_brace = #line - 1

    vim.api.nvim_win_set_cursor(0, { 1, first_start })
    assert_equal(agda.cursor_in_goal(0), true)
    vim.api.nvim_win_set_cursor(0, { 1, between })
    assert_equal(agda.cursor_in_goal(0), false)
    vim.api.nvim_win_set_cursor(0, { 1, second_start + 3 })
    assert_equal(agda.cursor_in_goal(0), true)
    vim.api.nvim_win_set_cursor(0, { 1, final_brace })
    assert_equal(agda.cursor_in_goal(0), false)
  end)
end)

test("commits multibyte Agda input without corrupting cursor offsets", function()
  local input = require("config.agda_input")
  input.register("nvim-test-arrow", "→")

  local prefix = [[value = \nvim-test-arrow]]
  with_scratch_buffer({ prefix .. "x" }, function()
    vim.api.nvim_win_set_cursor(0, { 1, #prefix })
    input.commit()
    assert_equal(vim.api.nvim_get_current_line(), "value = →x")
    assert_equal(vim.api.nvim_win_get_cursor(0)[2], #"value = →")
  end)
end)

test("parses Dune diagnostics and warning severity", function()
  local output = table.concat({
    'File "lib/example.ml", line 3, characters 2-8:',
    "Error: This expression has type int",
    'File "test/example_test.ml", lines 9-10, characters 0-4:',
    "Warning 8 [partial-match]: this pattern-matching is not exhaustive",
  }, "\n")
  local root = vim.fs.normalize(vim.fn.getcwd())
  local items = require("config.ocaml_output").parse_dune(output, root)

  assert_equal(#items, 2)
  assert_equal(items[1].filename, vim.fs.joinpath(root, "lib", "example.ml"))
  assert_equal({ items[1].lnum, items[1].col, items[1].type }, { 3, 3, "E" })
  assert_equal({ items[2].lnum, items[2].col, items[2].type }, { 9, 1, "W" })
end)

test("keeps OCaml roots and cache paths project scoped", function()
  local root = vim.fs.normalize(vim.fn.getcwd())
  local ocaml = require("config.ocaml")
  local cache = require("config.ocaml_cache")

  assert_equal(ocaml.root(vim.fs.joinpath(root, "lua", "config", "ocaml.lua")), root)
  assert_equal(ocaml.is_dune_project(root), false)

  local prefix = ocaml.opam_prefix("dune", root)
  assert_equal(prefix[#prefix - 1], "--")
  assert_equal(prefix[#prefix], "dune")

  local directories = cache.project_dirs(root)
  assert_equal(#directories, 2)
  assert_truthy(directories[1]:find("/ocaml%-watch/", 1) ~= nil)
  assert_truthy(directories[2]:find("/ocaml%-utop/", 1) ~= nil)
  assert_truthy(directories[1] ~= cache.project_dirs(root .. "-other")[1])
end)

test("does not inherit an OPAM switch across a project boundary", function()
  local root = vim.fs.normalize(vim.fn.getcwd())
  local ocaml = require("config.ocaml")
  local fixture = vim.fs.joinpath(root, "tests", "fixtures")
  local nested = vim.fs.joinpath(fixture, "ocaml-parent", "nested")
  local nested_source = vim.fs.joinpath(nested, "lib", "example.ml")
  local local_root = vim.fs.joinpath(fixture, "ocaml-local")
  local local_source = vim.fs.joinpath(local_root, "lib", "example.ml")

  assert_equal(ocaml.root(nested_source), nested)
  assert_equal(ocaml.local_switch(nested_source), nil)
  assert_equal(ocaml.root(local_source), local_root)
  assert_equal(ocaml.local_switch(local_source), local_root)
end)

if #failures > 0 then
  print(("\n%d test(s) passed; %d failed"):format(passed, #failures))
  for _, failure in ipairs(failures) do
    print("\n" .. failure)
  end
  vim.cmd("cquit 1")
else
  print(("\nAll %d smoke tests passed"):format(passed))
  vim.cmd("qa!")
end
