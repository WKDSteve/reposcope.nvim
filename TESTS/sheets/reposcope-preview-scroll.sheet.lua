-- <C-d>/<C-u> scroll the README preview while the cursor stays in the prompt. The README of the fake host is made long
-- for this sheet (`_G.readme_of`); fake request tools and a temp cache directory (TESTS/sheets/_helpers.lua).
return {
  id = "reposcope.preview-scroll",
  feature = "reposcope.preview-scroll",
  title = "reposcope.nvim: <C-d> scrolls a long README preview down, <C-u> back up, typing stays in the prompt",
  sizes = { { rows = 40, cols = 140 } },
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.readme_of = function(owner, repo)
        local lines = { "# " .. repo, "" }
        for i = 1, 200 do
          lines[#lines + 1] = ("line %d of %s/%s"):format(i, owner, repo)
        end
        return table.concat(lines, "\n") .. "\n"
      end
      _G.top = function()
        local win = require("reposcope.state.ui.ui_state").windows.preview
        return vim.fn.getwininfo(win)[1].topline
      end
      _G.setup({ readme_precache_count = 0 })]],
      note = "every README is 200 lines long",
    },
    { keys = ":Reposcope start<CR>" },
    { wait = [[_G.in_field("keywords") and vim.fn.mode() == "i"]] },
    { input = "spotlight" },
    { wait = [[_G.typed("keywords", "spotlight")]] },
    { input = "<CR>" },
    { wait = [[_G.preview():find("line 200 of alice/spotlight", 1, true) ~= nil]] },
    { expect = [[_G.top() == 1]], note = "the preview starts at the top" },
    { input = "<C-d>" },
    { wait = [[_G.top() > 1]], note = "scrolled down" },
    {
      expect = [[_G.in_field("keywords") and vim.fn.mode() == "i"]],
      note = "the cursor stays in the prompt, still typing",
    },
    { lua = "_G.down = _G.top()" },
    { input = "<C-d>" },
    { wait = [[_G.top() > _G.down]], note = "further down" },
    { input = "<C-u><C-u>" },
    { wait = [[_G.top() == 1]], note = "back at the top" },
    { input = "x" },
    { wait = [[_G.typed("keywords", "spotlightx")]], note = "and the next key types into the field" },
  },
}
