-- A search goes out through the configured request tool: `request_tool = "curl"`, then "gh", then "wget", each a
-- real process start of the plugin (lib.nvim's spawn_capture). The three programs are recording stand-ins
-- (TESTS/sheets/_helpers.lua `stand_ins`) that print the fixture's search answer: nothing reaches GitHub.
return {
  id = "reposcope.request-tools",
  feature = "reposcope.request-tools",
  title = "reposcope.nvim: a search runs through curl, gh or wget, whichever is configured, and fills the list",
  sizes = { { rows = 40, cols = 140 } },
  steps = {
    {
      lua = [[_G.real_request_tools = true
      dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      local answer = { stdout = _G.search_body() }
      _G.fake = _G.stand_ins({ curl = answer, gh = answer, wget = answer })
      _G.setup({ request_tool = "curl", readme_precache_count = 0 })]],
      note = "request_tool = curl; curl, gh and wget are stand-ins that print the search answer",
    },
    { keys = ":Reposcope start<CR>" },
    { wait = [[_G.in_field("keywords") and vim.fn.mode() == "i"]], note = "the prompt waits in insert mode" },
    { input = "spotlight" },
    { wait = [[_G.typed("keywords", "spotlight")]] },
    { input = "<CR>", note = "search" },
    {
      wait = [[#_G.list() == #_G.fixture and _G.list()[1] ~= ""]],
      timeout = 10000,
      note = "the list is filled from curl's answer (a stand-in starts through cmd.exe on Windows: slow under load)",
    },
    { expect = [[_G.has(_G.list()[1], "alice/spotlight: Search everything fast")]] },
    {
      expect = [[_G.called(_G.fake, "curl", "api.github.com/search/repositories") >= 1]],
      note = "curl was started with the search URL",
    },
    { expect = [[#_G.fake:calls("gh") == 0 and #_G.fake:calls("wget") == 0]], note = "and no other tool" },
    {
      lua = [[require("reposcope.config").options.request_tool = "gh"]],
      note = "the config now says gh",
    },
    { input = "<CR>", note = "the same search again" },
    {
      wait = [[_G.called(_G.fake, "gh", "/search/repositories") >= 1 and #_G.list() == #_G.fixture]],
      timeout = 10000,
      note = "gh api answered, the list is full again",
    },
    {
      lua = [[require("reposcope.config").options.request_tool = "wget"]],
      note = "the config now says wget",
    },
    { input = "<CR>" },
    {
      wait = [[_G.called(_G.fake, "wget", "api.github.com/search/repositories") >= 1 and #_G.list() == #_G.fixture]],
      timeout = 10000,
      note = "wget answered, the list is full again",
    },
  },
  manual = {
    "Once with the real network and each tool installed: a search through curl, gh and wget fills the list",
  },
}
