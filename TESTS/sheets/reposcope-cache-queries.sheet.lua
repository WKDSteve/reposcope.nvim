-- Live check: README pre-caching, the file cache, the debounce and :Reposcope skipped-readmes (section 2) and
-- :Reposcope queries (section 7) (task reposcope.nvim/manual-checklist-run; ALL/manual-test-checklists/reposcope.md).
-- Fake request tools and a temp cache directory (TESTS/sheets/_helpers.lua): no network. The README of carol/beacon
-- is put into the file cache before the plugin starts, as a former session would have left it.
return {
  id = "reposcope.cache-queries",
  title = "reposcope.nvim: top results pre-cached, file cache without a request, fast scrolling debounced, queries",
  task = "reposcope.nvim/manual-checklist-run",
  sizes = { { rows = 40, cols = 140 } },
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      local cache = require("reposcope.cache.readme_cache")
      local path = cache.file_path("carol", "beacon")
      vim.fn.mkdir(vim.fs.dirname(path), "p")
      vim.fn.writefile({ "# beacon", "", "FROM A FORMER SESSION" }, path)
      cache.set_updated_at("carol", "beacon", "2026-03-01T00:00:00Z")
      cache.readme_cache = {}
      _G.setup()]],
    },
    { keys = ":Reposcope start<CR>" },
    { wait = [[_G.in_field("keywords") and vim.fn.mode() == "i"]] },
    { input = "light" },
    { wait = [[_G.typed("keywords", "light")]] },
    { input = "<CR>" },
    { wait = [[_G.preview():find("README of alice/spotlight", 1, true) ~= nil]] },
    {
      wait = [[_G.asked("bob/lantern") == 1 and _G.asked("alice/prism") == 1 and _G.asked("dave/torch") == 1]],
      note = "results 2 to 5 fetched in the background, without touching the list",
    },
    { lua = "vim.wait(300)" },
    {
      expect = [[_G.asked("carol/beacon") == 0 and _G.asked("erin/candle") == 0 and _G.asked("frank/flare") == 0
        and _G.asked("alice/spotlight") == 1]],
      note = "beacon is on disk already; 6 and 7 are not pre-cached; each README once",
    },
    { lua = "_G.n = #_G.requests" },
    { input = "<Down><Down>", note = "to beacon" },
    { wait = [[_G.selected() == 3 and _G.preview():find("FROM A FORMER SESSION", 1, true) ~= nil]] },
    { input = "<Down>", note = "to prism, pre-cached" },
    { wait = [[_G.selected() == 4 and _G.preview():find("README of alice/prism", 1, true) ~= nil]] },
    { lua = "vim.wait(300)" },
    { expect = [[#_G.requests == _G.n]], note = "both warm: no request" },

    { lua = [[_G.skipped = require("reposcope.controllers.provider_controller").get_skipped_fetches()]] },
    { input = "<Down><Down><Down>", note = "a fast pass over torch and candle to flare" },
    { wait = [[_G.selected() == 7 and _G.preview():find("<div>", 1, true) ~= nil]] },
    { lua = "vim.wait(300)" },
    {
      expect = [[_G.asked("erin/candle") == 0 and _G.asked("frank/flare") == 1 and #_G.requests == _G.n + 1]],
      note = "only the row it settled on was fetched",
    },
    { input = "<Up><Up>", note = "back to torch" },
    { wait = [[_G.selected() == 5 and _G.preview():find("README of dave/torch", 1, true) ~= nil]] },
    { lua = "vim.wait(300)" },
    { expect = [[_G.asked("dave/torch") == 1]], note = "already fetched: no second request" },

    { input = "<Esc>" },
    { wait = [[vim.fn.mode() == "n"]] },
    { keys = ":Reposcope skipped-readmes<CR>" },
    {
      expect = [[(function()
        local n = tonumber(vim.fn.execute("messages"):match("Skipped readme fetches:%s+(%d+)"))
        return n ~= nil and n > _G.skipped
      end)()]],
      note = "a nonzero, grown skipped count",
    },
    {
      expect = [[(function()
        local subs = vim.fn.getcompletion("Reposcope ", "cmdline")
        table.sort(subs)
        local want = { "close", "favorites", "filter", "filter-clear", "filter-prompt", "messages", "print-dev",
          "prompt", "providers", "queries", "session", "skipped-readmes", "sort", "start", "stats", "toggle-dev" }
        assert(vim.deep_equal(subs, want), vim.inspect(subs))
        return type(require("reposcope.cache.readme_cache").clear) == "function"
      end)()]],
      note = "no subcommand refreshes one README; readme_cache.clear(owner, repo) is the Lua way",
    },

    { input = "i", note = "two more real <CR> searches: torch, then light again" },
    { wait = [[vim.fn.mode() == "i"]] },
    { input = "<End><BS><BS><BS><BS><BS>" },
    { wait = [[_G.typed("keywords", "")]] },
    { input = "torch" },
    { wait = [[_G.typed("keywords", "torch")]] },
    { input = "<CR>" },
    { wait = [[_G.asked("q=torch") == 1]] },
    { input = "<BS><BS><BS><BS><BS>" },
    { wait = [[_G.typed("keywords", "")]] },
    { input = "light" },
    { wait = [[_G.typed("keywords", "light")]] },
    { input = "<CR>" },
    { wait = [[_G.asked("q=light") == 2]] },
    { input = "<Esc>" },
    { wait = [[vim.fn.mode() == "n"]] },
    { keys = ":Reposcope queries<CR>", note = "recorded with no opt-in" },
    { wait = [[_G.focused("(2x) light")]] },
    {
      expect = [[_G.has(_G.text(), " 1. (2x) light") and _G.has(_G.text(), " 2. (1x) torch")]],
      note = "most frequent first",
    },
    { keys = "q" },
    { keys = ":Reposcope queries clear<CR>" },
    { wait = [[_G.noted("Query stats cleared.")]], note = "said outside dev mode too" },
    { expect = [[#require("reposcope.state.query_stats").top(10) == 0]], note = "reset" },
    { lua = "_G.wins = #vim.api.nvim_list_wins()" },
    { keys = ":Reposcope queries list<CR>" },
    { lua = "vim.wait(200)" },
    { expect = [[#vim.api.nvim_list_wins() == _G.wins]], note = "an empty list opens no view" },
  },
}
