-- Live check: :Reposcope filter (completion, substring, reset), filter-prompt and sort, section 4
-- (task reposcope.nvim/manual-checklist-run; ALL/manual-test-checklists/reposcope.md). Fake request tools
-- (TESTS/sheets/_helpers.lua): no network.
return {
  id = "reposcope.filter-sort",
  title = "reposcope.nvim: filter completes from the result set, matches the description, resets; filter-prompt; sort",
  task = "reposcope.nvim/manual-checklist-run",
  sizes = { { rows = 40, cols = 140 } },
  steps = {
    { lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua"); _G.setup({ readme_precache_count = 0 })]] },
    { keys = ":Reposcope start<CR>" },
    { wait = [[_G.in_field("keywords") and vim.fn.mode() == "i"]] },
    { input = "light" },
    { wait = [[_G.typed("keywords", "light")]] },
    { input = "<CR>" },
    { wait = [[#_G.list() == #_G.fixture and _G.list()[1] ~= ""]] },
    { input = "<Esc>" },
    { wait = [[vim.fn.mode() == "n"]] },

    {
      expect = [[vim.deep_equal(vim.fn.getcompletion("Reposcope filter a", "cmdline"), { "alice" })]],
      note = "<Tab> offers the owner in the result set, prefix-matched",
    },
    {
      expect = [[vim.deep_equal(vim.fn.getcompletion("Reposcope filter b", "cmdline"), { "beacon", "bob" })]],
      note = "names and owners",
    },
    {
      expect = [[#vim.fn.getcompletion("Reposcope filter z", "cmdline") == 0
        and #vim.fn.getcompletion("Reposcope filter ight", "cmdline") == 0]],
      note = "nothing outside the result set, no infix match",
    },

    { keys = ":Reposcope filter TERMINAL<CR>", note = "a word of bob/lantern's description only, upper case" },
    { wait = [[#_G.list() == 1]] },
    { expect = [[_G.has(_G.list()[1], "bob/lantern: A lamp for the terminal")]] },
    { keys = ":Reposcope filter<CR>", note = "no argument: reset" },
    { wait = [[#_G.list() == #_G.fixture]] },
    { expect = [[_G.has(_G.list()[1], "alice/spotlight")]], note = "in relevance order again" },

    { input = ":Reposcope filter-prompt<CR>", note = "input: keys would end the insert mode it opens in" },
    { wait = [[#_G.floats() > 0 and vim.api.nvim_get_current_buf() ~= _G.rbuf("list") and vim.fn.mode() == "i"]] },
    { input = "ALICE" },
    { wait = [[vim.api.nvim_get_current_line():find("ALICE", 1, true) ~= nil]] },
    { input = "<CR>" },
    { wait = [[#_G.list() == 2]], note = "same matching: alice's two repositories" },
    { expect = [[_G.has(_G.list()[1], "alice/spotlight") and _G.has(_G.list()[2], "alice/prism")]] },
    { keys = ":Reposcope filter<CR>" },
    { wait = [[#_G.list() == #_G.fixture]] },
    { input = ":Reposcope filter-prompt<CR>", note = "input: keys would end the insert mode it opens in" },
    { wait = [[vim.fn.mode() == "i" and not _G.in_field("keywords")]] },
    { input = "<CR>", note = "empty input" },
    { lua = "vim.wait(300)" },
    { expect = [[#_G.list() == #_G.fixture]], note = "cancels, does not filter to nothing" },
    { lua = [[vim.cmd("stopinsert")]] },
    { wait = [[vim.fn.mode() == "n"]] },

    { keys = ":Reposcope sort<CR>", note = "the menu" },
    { wait = [[_G.focused("stars") and _G.focused("relevance")]] },
    { keys = "jj<CR>", note = "stars" },
    { wait = [[_G.list()[1] ~= nil and _G.list()[1]:find("frank/flare", 1, true) ~= nil]], note = "900 stars first" },
    { expect = [[_G.has(_G.list()[2], "bob/lantern") and _G.has(_G.list()[#_G.list()], "erin/candle")]] },
    { keys = ":Reposcope sort<CR>" },
    { wait = [[_G.focused("relevance")]] },
    { keys = "<CR>", note = "name" },
    { wait = [[_G.list()[1]:find("carol/beacon", 1, true) ~= nil]], note = "alphabetical by name" },

    { keys = ":Reposcope filter prism<CR>" },
    { wait = [[#_G.list() == 1]] },
    { keys = ":Reposcope filter-clear<CR>", note = "the bindings checklist: filter-clear" },
    { wait = [[#_G.list() == #_G.fixture and _G.list()[1]:find("alice/spotlight", 1, true) ~= nil]] },

    { keys = ":Reposcope prompt prefix keywords<CR>", note = "the bindings checklist: prompt" },
    {
      wait = [[vim.deep_equal(require("reposcope.ui.prompt.prompt_config").get_fields(), { "prefix", "keywords" })
        and _G.in_field("keywords")]],
      note = "the UI reopens with these fields",
    },
    {
      expect = [[vim.fn.bufwinid("reposcope://prompt_keywords") ~= -1 and vim.fn.bufwinid("reposcope://prompt_owner") == -1]],
      note = "owner is no longer shown",
    },
  },
}
