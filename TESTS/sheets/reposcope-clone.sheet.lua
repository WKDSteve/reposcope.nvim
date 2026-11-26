-- <C-c> clones the selected repository: the path prompt offers `clone.std_dir`, <CR> takes it, and
-- `git clone <url> <dir>/<name>` runs without blocking the editor (lib.nvim's run_async_captured). `git` is a
-- recording stand-in (TESTS/sheets/_helpers.lua `stand_ins`): nothing is fetched. The request tools are the fake of
-- _helpers.lua (no network).
return {
  id = "reposcope.clone",
  feature = "reposcope.clone",
  title = "reposcope.nvim: <C-c> asks for the clone path, <CR> clones the selected repository there with git",
  sizes = { { rows = 40, cols = 140 } },
  prompts = "real",
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.fake = _G.stand_ins({ "git" })
      _G.clone_dir = vim.fs.normalize(vim.fn.tempname())
      vim.fn.mkdir(_G.clone_dir, "p")
      _G.setup({ clone = { std_dir = _G.clone_dir, type = "git" } })
      _G.cloned_events = {}
      vim.api.nvim_create_autocmd("User", {
        pattern = "ReposcopeCloned",
        callback = function(a) _G.cloned_events[#_G.cloned_events + 1] = a.data end,
      })]],
      note = "clone.std_dir is an empty folder; git is a stand-in",
    },
    { keys = ":Reposcope start<CR>" },
    { wait = [[_G.in_field("keywords") and vim.fn.mode() == "i"]] },
    { input = "lantern" },
    { wait = [[_G.typed("keywords", "lantern")]] },
    { input = "<CR>" },
    { wait = [[_G.preview():find("README of alice/spotlight", 1, true) ~= nil]] },
    { input = "<Down>", note = "to bob/lantern" },
    { wait = [[_G.selected() == 2 and _G.preview():find("README of bob/lantern", 1, true) ~= nil]] },
    { input = "<C-c>", note = "clone: the path prompt offers clone.std_dir" },
    { input = "<CR>", note = "take it (a call into the child would wait for the prompt, so no wait in between)" },
    { wait = [[#_G.fake:calls("git") == 1]], timeout = 10000, note = "git was started (slow under load on Windows)" },
    {
      expect = [[_G.called(_G.fake, "git", "clone https://github.com/bob/lantern " .. _G.clone_dir .. "/lantern") == 1]],
      note = "git clone <url> <std_dir>/<name>",
    },
    {
      wait = [[#_G.cloned_events == 1]],
      timeout = 10000,
      note = "the clone finished: User ReposcopeCloned fired once",
    },
    {
      expect = [[_G.cloned_events[1].path == _G.clone_dir .. "/lantern" and _G.cloned_events[1].url == "https://github.com/bob/lantern"]],
      note = "with the new repository's path and its URL (gitsuite and terminal.nvim listen for it)",
    },
    { expect = [[vim.fn.mode() == "i" and _G.in_field("keywords")]], note = "back in the prompt, nothing blocked" },
  },
  manual = {
    "Once with the real network: <C-c> on a small repository clones it into the folder given at the prompt",
  },
}
