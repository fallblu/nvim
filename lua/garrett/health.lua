local M = {}

local health = vim.health
local start = health.start or health.report_start
local ok = health.ok or health.report_ok
local warn = health.warn or health.report_warn
local error = health.error or health.report_error
local info = health.info or health.report_info

---@param name string
---@param required boolean
---@param hint? string
---@return boolean
local function executable(name, required, hint)
  local path = vim.fn.exepath(name)
  if path == "" then
    local mason_path = vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "bin", name)
    if vim.fn.executable(mason_path) == 1 then
      path = mason_path
    end
  end
  if path ~= "" then
    ok(("%s found at %s"):format(name, path))
    return true
  end

  local message = ("%s was not found"):format(name)
  if hint then
    message = message .. "; " .. hint
  end
  if required then
    error(message)
  else
    warn(message)
  end
  return false
end

---@param language string
local function parser(language)
  local loaded, result = pcall(vim.treesitter.language.add, language)
  if loaded and result then
    ok(("Tree-sitter parser %s is installed"):format(language))
  else
    warn(("Tree-sitter parser %s is missing; run :TSInstall %s"):format(language, language))
  end
end

local function runtime()
  start("Runtime")

  if vim.fn.has("nvim-0.11") == 1 then
    ok("Neovim 0.11 or newer")
  else
    error("Neovim 0.11 or newer is required")
  end

  executable("git", true)
  executable("rg", true, "Snacks project search depends on ripgrep")
  executable("make", false, "needed when a plugin or parser must compile locally")
  executable("cc", false, "needed when a Tree-sitter parser must compile locally")

  local shell = vim.fn.expand(vim.o.shell)
  if shell ~= "" and vim.fn.executable(shell) == 1 then
    ok(("shell found at %s"):format(vim.fn.exepath(shell)))
  else
    error(("configured shell is unavailable: %s"):format(shell ~= "" and shell or "<empty>"))
  end

  if vim.fn.has("wsl") == 1 then
    if vim.fn.executable("win32yank.exe") == 1 then
      ok("WSL clipboard uses win32yank.exe")
    elseif vim.fn.executable("clip.exe") == 1 and vim.fn.executable("powershell.exe") == 1 then
      ok("WSL clipboard fallback has clip.exe and powershell.exe")
    else
      warn("WSL clipboard tools are incomplete; install win32yank.exe or provide clip.exe and powershell.exe")
    end
  else
    info("WSL clipboard fallback is not needed on this host")
  end
end

local function plugins()
  start("Workflow plugins")

  local lazy_ok, lazy_config = pcall(require, "lazy.core.config")
  if not lazy_ok then
    error("lazy.nvim configuration is unavailable")
    return
  end

  for _, name in ipairs({ "snacks.nvim", "hardtime.nvim", "precognition.nvim", "nvim-treesitter", "cornelis" }) do
    local plugin = lazy_config.plugins[name]
    if plugin and plugin.dir and vim.uv.fs_stat(plugin.dir) then
      ok(("%s is installed"):format(name))
    else
      error(("%s is not installed; run :Lazy sync"):format(name))
    end
  end

  parser("agda")
  parser("ocaml")
  parser("ocaml_interface")
  parser("ocamllex")
  parser("menhir")
end

local function python()
  start("Python")

  local terminal = require("config.terminal")
  local root = terminal.root()
  local python_command = terminal.python_command(root)
  local pytest_command = terminal.pytest_command(root)

  if python_command then
    ok("Python REPL command: " .. table.concat(python_command, " "))
  else
    warn("No Python interpreter is available for the embedded REPL")
  end

  if pytest_command then
    ok("pytest command: " .. table.concat(pytest_command, " "))
  else
    warn("pytest is unavailable; install it in the selected environment")
  end

  executable("pyright", false, "install it through Mason for Python type checking")
  executable("ruff", false, "install it through Mason for Python linting and formatting")
  executable("uv", false, "optional; uv.lock projects fall back to another interpreter without it")
end

local function ocaml()
  start("OCaml")

  if not executable("opam", false, "OCaml tools are resolved through OPAM") then
    return
  end

  local config = require("config.ocaml")
  local root = config.root()
  for _, tool in ipairs({
    { binary = "dune", package = "dune" },
    { binary = "ocamllsp", package = "ocaml-lsp-server" },
    { binary = "ocamlformat", package = "ocamlformat" },
    { binary = "ocp-indent", package = "ocp-indent" },
    { binary = "odoc", package = "odoc" },
    { binary = "utop", package = "utop" },
  }) do
    local available, location = config.tool_available(tool.binary, root)
    if available then
      ok(("%s is available in %s"):format(tool.binary, location))
    else
      warn(("%s is unavailable in %s; run opam install %s"):format(tool.binary, location, tool.package))
    end
  end
end

local function agda()
  start("Agda")

  executable("agda", false, "required for Cornelis and :AgdaCompile")
  executable("cornelis", false, "rebuild the pinned plugin with :Lazy build cornelis")
  executable("ghc", false, "required by Agda's GHC backend")
  executable("stack", false, "required only when rebuilding Cornelis")
end

local function optional_tools()
  start("Optional integrations")

  if vim.fn.executable("lazygit") == 1 then
    ok("lazygit is installed and <leader>;g is available")
  else
    info("lazygit is not installed, so <leader>;g is intentionally omitted")
  end
end

function M.check()
  runtime()
  plugins()
  python()
  ocaml()
  agda()
  optional_tools()
end

return M
