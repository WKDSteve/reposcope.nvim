-- Live check: the hover.nvim source for `owner/repo`, section 3 (task reposcope.nvim/manual-checklist-run;
-- ALL/manual-test-checklists/reposcope.md). The real hover.nvim (TESTS/minimal_init.lua finds it, the sheet puts it on
-- the runtimepath), fake request tools and a temp cache directory (TESTS/sheets/_helpers.lua): no network.
return {
  id = "reposcope.hover",
  feature = "reposcope.hover",
  title = "reposcope.nvim: hover previews a cached owner/repo, declines prose and paths, :Hover show fetches once",
  task = "reposcope.nvim/manual-checklist-run",
  sizes = { { rows = 40, cols = 140 } },
  requires = {
    { lua = "vim.g.reposcope_sheets_hover_nvim ~= nil", reason = "hover.nvim not found by TESTS/minimal_init.lua" },
  },
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      vim.opt.rtp:append(vim.g.reposcope_sheets_hover_nvim)
      require("hover").enable({ trigger = { "cursor" }, delay_ms = 50, persist = false,
        auto_hover = { markdown = true, file = true } })
      _G.setup({ readme_precache_count = 0 })
      local cache = require("reposcope.cache.readme_cache")
      cache.set_ram("alice", "spotlight", "# spotlight\n\nCACHED README of alice/spotlight\n")
      cache.set_file("alice", "spotlight", "# spotlight\n\nCACHED README of alice/spotlight\n")
      _G.dir = vim.fs.normalize(vim.fn.tempname())
      vim.fn.mkdir(_G.dir .. "/lua/plugins", "p")
      vim.fn.chdir(_G.dir)
      vim.cmd.edit("note.md")
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "cached: alice/spotlight",
        "prose: and/or input/output",
        "uncached: bob/lantern",
        "missing: ghost/missing",
        "path: lua/plugins",
      })]],
    },
    { keys = "1G$", note = "on the cached slug" },
    { wait = [[#_G.floats() > 0]], note = "the automatic trigger" },
    {
      wait = [[(function()
        for _, w in ipairs(_G.floats()) do
          if _G.text(vim.api.nvim_win_get_buf(w)):find("CACHED README of alice/spotlight", 1, true) then return true end
        end
      end)()]],
      note = "the README as the preview",
    },
    { keys = "2G$", note = "on input/output" },
    { lua = "vim.wait(400)" },
    { expect = [[#_G.floats() == 0 and #_G.requests == 0]], note = "no preview, nothing fetched" },
    { keys = "2G10|", note = "on and/or" },
    { lua = "vim.wait(400)" },
    { expect = [[#_G.floats() == 0 and #_G.requests == 0]] },

    { keys = "3G$", note = "on the uncached slug, automatic trigger only" },
    { lua = "vim.wait(400)" },
    { expect = [[#_G.floats() == 0 and #_G.requests == 0]], note = "nothing happens, nothing is fetched" },
    { keys = ":Hover show<CR>" },
    { wait = [[_G.noted("fetching the README of bob/lantern")]], note = "a notice says the fetch started" },
    { wait = [[_G.asked("api.github.com/repos/bob/lantern/readme") == 1]] },
    {
      wait = [[(function()
        for _, w in ipairs(_G.floats()) do
          if _G.text(vim.api.nvim_win_get_buf(w)):find("README of bob/lantern", 1, true) then return true end
        end
      end)()]],
      note = "it arrives and shows, the cursor is still there",
    },
    { keys = "<Esc>" },
    { keys = ":Hover show<CR>", note = "again" },
    { lua = "vim.wait(300)" },
    { expect = [[_G.asked("bob/lantern") == 1]], note = "answered from the cache" },
    { keys = "1G$" },
    { lua = "vim.wait(300)" },
    { keys = "3G$", note = "the automatic trigger now previews it too" },
    {
      wait = [[(function()
        for _, w in ipairs(_G.floats()) do
          if _G.text(vim.api.nvim_win_get_buf(w)):find("README of bob/lantern", 1, true) then return true end
        end
      end)()]],
    },

    { keys = "4G$", note = "a repository that does not exist" },
    { keys = ":Hover show<CR>" },
    { wait = [[_G.noted("could not fetch a README for ghost/missing")]], note = "a failure notice" },
    { lua = "_G.n = #_G.requests" },
    { keys = ":Hover show<CR>", note = "again, at once" },
    { wait = [[_G.noted("no README found for ghost/missing (failed earlier")]], note = "says so" },
    { expect = [[#_G.requests == _G.n]], note = "instead of fetching again" },

    { keys = "5G$", note = "an existing relative path" },
    { keys = ":Hover show<CR>" },
    { lua = "vim.wait(300)" },
    { expect = [[_G.asked("plugins") == 0]], note = "never fetched as a repository" },
  },
}
