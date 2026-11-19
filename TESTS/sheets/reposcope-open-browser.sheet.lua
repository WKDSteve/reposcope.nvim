-- <C-v> on a repository whose README is HTML hands its GitHub page to the system opener (lib.nvim's open_default):
-- `rundll32.exe url.dll,FileProtocolHandler <url>` on Windows and WSL, `open <url>` on macOS, `xdg-open <url>` on Linux.
-- The openers are recording stand-ins (TESTS/sheets/_helpers.lua `stand_ins`): no browser opens. The request tools
-- are the fake of _helpers.lua (no network).
return {
  id = "reposcope.open-browser",
  feature = "reposcope.open-browser",
  title = "reposcope.nvim: <C-v> on a repository with an HTML README opens its GitHub page through the system opener",
  sizes = { { rows = 40, cols = 140 } },
  steps = {
    {
      lua = [[_G.real_opener = true
      dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.fake = _G.stand_ins({ "rundll32", "open", "xdg-open" })
      _G.setup()]],
      note = "the real opener; rundll32, open and xdg-open are stand-ins",
    },
    { keys = ":Reposcope start<CR>" },
    { wait = [[_G.in_field("keywords") and vim.fn.mode() == "i"]] },
    { input = "spotlight" },
    { wait = [[_G.typed("keywords", "spotlight")]] },
    { input = "<CR>" },
    { wait = [[_G.preview():find("README of alice/spotlight", 1, true) ~= nil]] },
    { input = "<Esc>" },
    { wait = [[vim.fn.mode() == "n"]] },
    { keys = "6<Down>", note = "to flare, whose README is HTML" },
    { wait = [[_G.selected() == 7 and _G.preview():find("<div>", 1, true) ~= nil]] },
    { keys = "<C-v>" },
    {
      wait = [[#_G.fake:calls() == 1]],
      timeout = 10000,
      note = "one opener was started (a stand-in starts through cmd.exe on Windows: slow under load)",
    },
    {
      expect = [[_G.called(_G.fake, _G.fake:calls()[1].program, "https://github.com/frank/flare") == 1]],
      note = "with the repository's GitHub page",
    },
    { expect = [[_G.rbuf("readme_viewer") == nil]], note = "no viewer for HTML" },
  },
  manual = {
    "Once in the real editor: <C-v> on a repository with an HTML README opens its page in the default browser",
  },
}
