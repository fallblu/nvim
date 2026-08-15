local M = {}

-- Cornelis' filetype detection has used both language-first and markup-first
-- names across versions. Keep the aliases together so lazy-loading, spelling,
-- and input-method setup agree about Literate Agda buffers.
M.agda = {
  "agda",
  "lagda",
  "markdown.agda",
  "rst.agda",
  "tex.agda",
  "lagda.md",
  "lagda.rst",
  "lagda.tex",
}

return M
