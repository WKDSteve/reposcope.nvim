-- TESTS/sheets/features.lua -- the functionalities of reposcope.nvim as its user meets them; `testing sheets report`
-- says which ones have a feature sheet (`feature = "<id>"`) and in which state, and K16 warns about a sheet that names
-- an id not listed here. Data: read with an empty environment like a sheet (testing.nvim docs/SHEETS.md).
-- The list follows docs/FEATURES/ (README.md and its pages) and ALL/manual-test-checklists/reposcope.md.
return {
  {
    id = "reposcope.search",
    title = "A search fills the result list, and moving the selection previews that repository's README",
    surface = { "command:Reposcope" },
    docs = "docs/FEATURES/UI.md",
  },
  {
    id = "reposcope.views",
    title = "<C-v> opens the README viewer, <C-b> a scratch buffer, ? the key cheatsheet; <Esc> closes the UI",
    docs = "docs/FEATURES/UI.md",
  },
  {
    id = "reposcope.preview-scroll",
    title = "<C-u>/<C-d> scroll the README preview without leaving the prompt",
    docs = "docs/FEATURES/UI.md",
  },
  {
    id = "reposcope.readme-image",
    title = "<C-p> shows the README image in the preview (needs images.nvim)",
    docs = "docs/FEATURES/UI.md",
  },
  {
    id = "reposcope.clone",
    title = "The selected repository is cloned with the tool of choice (git, gh, curl, wget)",
    docs = "docs/FEATURES/PROVIDERS.md",
  },
  {
    id = "reposcope.readme-cache",
    title = "READMEs are cached on disk, the top results pre-cached, fast scrolling debounced",
    docs = "docs/FEATURES/CACHE.md",
  },
  {
    id = "reposcope.filter-sort",
    title = ":Reposcope filter narrows the result list (completion, substring, reset), filter-prompt and sort order it",
    docs = "docs/FEATURES/UI.md",
  },
  {
    id = "reposcope.favorites",
    title = "<C-f> keeps a repository as favorite with its README; a fresh start shows the favorites without a request",
    docs = "docs/FEATURES/UI.md",
  },
  {
    id = "reposcope.session",
    title = ":Reposcope session save/restore/clear brings back provider, query, filter and sort",
    docs = "docs/FEATURES/WORKFLOW.md",
  },
  {
    id = "reposcope.queries",
    title = ":Reposcope queries lists the searches by how often they were made",
    docs = "docs/FEATURES/WORKFLOW.md",
  },
  {
    id = "reposcope.providers",
    title = "GitHub, GitLab and Codeberg are searched; :Reposcope providers lists the available and the active one",
    docs = "docs/FEATURES/PROVIDERS.md",
  },
  {
    id = "reposcope.hover",
    title = "A hover.nvim preview of a cached owner/repo; nothing and no error without hover.nvim or with hover = false",
    docs = "docs/hover.md",
  },
  {
    id = "reposcope.diagnostics",
    title = "checkhealth, notices as popups or vim.notify, :Reposcope messages, dev mode and stats",
    docs = "docs/FEATURES/WORKFLOW.md",
  },
}
