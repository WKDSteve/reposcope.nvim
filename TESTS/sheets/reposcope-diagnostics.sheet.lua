-- Live check: :checkhealth reposcope (setup), :Reposcope providers (section 8) and the diagnostics of section 9:
-- popups and their fallback, :Reposcope messages [clear], notify_messages, toggle-dev / print-dev, dev output, stats
-- (task reposcope.nvim/manual-checklist-run; ALL/manual-test-checklists/reposcope.md). Fake request tools and a temp
-- cache directory (TESTS/sheets/_helpers.lua): no network.
return {
  id = "reposcope.diagnostics",
  feature = "reposcope.diagnostics",
  title = "reposcope.nvim: checkhealth, providers, notices as popups or vim.notify, messages, dev mode, stats",
  task = "reposcope.nvim/manual-checklist-run",
  sizes = { { rows = 40, cols = 140 } },
  steps = {
    { lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua"); _G.setup({ readme_precache_count = 0 })]] },

    { keys = ":checkhealth reposcope<CR>", note = "setup: the health check" },
    { wait = [[_G.focused("Reposcope: plugin healthcheck")]] },
    {
      expect = [[(function()
        local t = _G.text()
        for _, bin in ipairs({ "gh", "curl", "wget" }) do
          assert(t:find("- ✅ OK " .. bin .. " is installed", 1, true) or t:find(bin .. " is not installed", 1, true), bin)
        end
        assert(t:find("Configured request tool: ", 1, true) or t:find("Request tool not properly configured", 1, true))
        return _G.has(t, "Core Reposcope modules loaded") and _G.has(t, "GITHUB_TOKEN")
      end)()]],
      note = "each binary on its own, the configured request tool, the token",
    },
    {
      expect = [[_G.has(_G.text(), "WARNING GITHUB_TOKEN not set")]],
      note = "no token in the child: a warning, not an error",
    },
    { keys = ":bwipeout<CR>" },

    { keys = ":Reposcope providers<CR>" },
    { wait = [[_G.focused("* github")]] },
    {
      expect = [[_G.has(_G.text(), "  codeberg") and _G.has(_G.text(), "  gitlab")]],
      note = "all three, github marked",
    },
    { keys = "q" },

    { keys = ":Reposcope session restore<CR>", note = "no session: a warning" },
    { wait = [[_G.noted("No saved session found.")]] },
    { expect = [[#_G.toasts() > 0]], note = "shown as a popup" },
    {
      expect = [[_G.has(vim.fn.execute("messages"), "No saved session found.")]],
      note = "notify_messages: in :messages as well",
    },
    {
      lua = [[_G.real_popup = package.loaded["lib.nvim.notify.popup"]
      _G.real_notify = vim.notify
      _G.fallback = {}
      package.loaded["lib.nvim.notify.popup"] = { deliver = function() error("popup unavailable") end }
      vim.notify = function(msg) _G.fallback[#_G.fallback + 1] = msg end]],
      note = "the popup is unavailable",
    },
    { keys = ":Reposcope favorites bogus<CR>", note = "a usage warning" },
    { wait = [[_G.fallback[1] ~= nil]] },
    { expect = [[_G.has(_G.fallback[1], "Usage: :Reposcope favorites list|clear")]], note = "it reaches vim.notify" },
    { lua = [[package.loaded["lib.nvim.notify.popup"] = _G.real_popup; vim.notify = _G.real_notify]] },

    { keys = ":Reposcope messages<CR>" },
    { wait = [[vim.api.nvim_buf_get_name(0):find("notify://reposcope", 1, true) ~= nil]] },
    { expect = [[_G.has(_G.text(), "No saved session found.")]], note = "the notices of this session" },
    { keys = "gg/No saved<CR>yy" },
    { expect = [[_G.has(vim.fn.getreg('"'), "No saved session found.")]], note = "yankable" },
    { keys = "q" },
    { keys = ":Reposcope messages clear<CR>" },
    { keys = ":Reposcope messages<CR>" },
    { wait = [[vim.api.nvim_buf_get_name(0):find("notify://reposcope", 1, true) ~= nil]] },
    { expect = [[not _G.focused("No saved session found.")]], note = "an empty history" },
    { keys = "q" },

    { lua = [[_G.setup({ readme_precache_count = 0, notify_messages = false }); vim.cmd("messages clear")]] },
    { keys = ":Reposcope session restore<CR>" },
    { wait = [[_G.noted("No saved session found.")]], note = ":Reposcope messages still has it" },
    {
      expect = [[not vim.fn.execute("messages"):find("No saved session found.", 1, true)]],
      note = "notify_messages = false: not in :messages",
    },

    { keys = ":Reposcope toggle-dev<CR>" },
    { keys = ":Reposcope print-dev<CR>" },
    { expect = [[_G.has(vim.fn.execute("messages"), "dev_mode: true")]], note = "print-dev says the state" },
    { keys = ":Reposcope start<CR>" },
    { wait = [[_G.in_field("keywords") and vim.fn.mode() == "i"]] },
    { input = "light" },
    { wait = [[_G.typed("keywords", "light")]] },
    { input = "<CR>" },
    { wait = [[_G.noted("7 repositories received from GitHub.")]], note = "dev mode: the debug notices" },
    { expect = [[_G.noted("REPOSCOPE START SEQUENCE FINISHED")]] },
    { input = "<Esc>" },
    { wait = [[vim.fn.mode() == "n"]] },
    { keys = ":Reposcope toggle-dev<CR>" },
    { keys = ":Reposcope print-dev<CR>" },
    { expect = [[_G.has(vim.fn.execute("messages"), "dev_mode: false")]], note = "off again" },

    { keys = ":Reposcope stats<CR>" },
    { wait = [[_G.focused("Reposcope Request Statistics")]] },
    { expect = [[_G.focused("Counting is off (metrics = false)")]], note = "metrics off (the default): it says so" },
    { lua = [[_G.hits = tonumber(_G.text():match("Session:.-Cache Hits: (%d+)"))]] },
    { keys = "q" },
    { lua = [[require("reposcope.utils.metrics").set_record_metrics(true)]], note = "metrics = true" },
    { keys = "<Down>" },
    { wait = [[_G.preview():find("README of bob/lantern", 1, true) ~= nil]] },
    { keys = "<Up>" },
    { wait = [[_G.preview():find("README of alice/spotlight", 1, true) ~= nil]] },
    { keys = "<Down>", note = "back to a cached README" },
    { wait = [[_G.preview():find("README of bob/lantern", 1, true) ~= nil]] },
    { lua = "vim.wait(200)" },
    { expect = [[_G.asked("bob/lantern") == 1]], note = "from the cache" },
    { keys = ":Reposcope stats<CR>" },
    { wait = [[_G.focused("Reposcope Request Statistics")]] },
    {
      expect = [[tonumber(_G.text():match("Session:.-Cache Hits: (%d+)")) > _G.hits]],
      note = "the numbers move",
    },
    { expect = [[not _G.focused("Counting is off")]], note = "and the hint is gone" },
    { keys = "q" },

    {
      expect = [[(function()
        local cache = require("reposcope.cache.readme_cache")
        local config = require("reposcope.config")
        assert(cache.get("alice", "spotlight"), "cached on github")
        config.options.provider = "gitlab"
        local other = cache.get("alice", "spotlight")
        config.options.provider = "github"
        return other == nil
      end)()]],
      note = "section 8: the README cache is per provider, a gitlab alice/spotlight is another entry",
    },
  },
}
