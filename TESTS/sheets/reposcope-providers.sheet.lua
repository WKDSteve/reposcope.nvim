-- :Reposcope providers lists GitHub, GitLab and Codeberg and marks the active one. Nothing is requested.
return {
  id = "reposcope.providers",
  feature = "reposcope.providers",
  title = "reposcope.nvim: :Reposcope providers lists github, gitlab and codeberg with the active one marked",
  sizes = { { rows = 30, cols = 120 } },
  steps = {
    { lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua"); _G.setup({ provider = "gitlab" })]] },
    { keys = ":Reposcope providers<CR>" },
    { wait = [[_G.focused("codeberg")]] },
    {
      expect = [[_G.has(_G.text(), "github") and _G.has(_G.text(), "gitlab") and _G.has(_G.text(), "codeberg")]],
      note = "all three",
    },
    { expect = [[_G.has(_G.text(), "* gitlab") and _G.has(_G.text(), "  github")]], note = "the active one marked" },
    { expect = [[#_G.requests == 0]], note = "no request for a list" },
  },
}
