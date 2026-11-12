-- Live check: `hover = false`, and no hover.nvim at all, section 3 (task reposcope.nvim/manual-checklist-run;
-- ALL/manual-test-checklists/reposcope.md). Fake request tools and a temp cache directory (TESTS/sheets/_helpers.lua).
return {
  id = "reposcope.hover-off",
  feature = "reposcope.hover",
  title = "reposcope.nvim: without hover.nvim, or with hover = false, a cached owner/repo shows nothing and no error",
  task = "reposcope.nvim/manual-checklist-run",
  sizes = { { rows = 30, cols = 100 } },
  requires = {
    { lua = "vim.g.reposcope_sheets_hover_nvim ~= nil", reason = "hover.nvim not found by TESTS/minimal_init.lua" },
  },
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua")
      _G.setup({ readme_precache_count = 0 })]],
      note = "hover.nvim is not on the runtimepath yet: setup() with the default hover = true",
    },
    { expect = [[vim.v.errmsg == "" and not _G.noted("hover")]], note = "no error at startup" },
    {
      lua = [[vim.opt.rtp:append(vim.g.reposcope_sheets_hover_nvim)
      require("hover").enable({ trigger = { "cursor" }, delay_ms = 50, persist = false,
        auto_hover = { markdown = true, file = true } })
      package.loaded["reposcope.hover"] = nil
      require("reposcope").setup({ readme_precache_count = 0, hover = false })
      local cache = require("reposcope.cache.readme_cache")
      cache.set_ram("alice", "spotlight", "# spotlight\n\nCACHED README\n")
      cache.set_file("alice", "spotlight", "# spotlight\n\nCACHED README\n")
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "x", "cached: alice/spotlight" })]],
      note = "now hover.nvim is there, and reposcope says hover = false",
    },
    { keys = "2G$" },
    { lua = "vim.wait(500)" },
    { expect = [[#_G.floats() == 0]], note = "no reposcope preview" },
    { keys = ":Hover show<CR>" },
    { lua = "vim.wait(300)" },
    {
      expect = [[(function()
        for _, w in ipairs(_G.floats()) do
          if _G.text(vim.api.nvim_win_get_buf(w)):find("CACHED README", 1, true) then return false end
        end
        return #_G.requests == 0
      end)()]],
      note = "not on request either, and nothing fetched",
    },
  },
}
