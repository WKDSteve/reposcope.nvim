-- Live check: the README viewer <C-v>, the scratch buffer <C-b>, the cheatsheet ? and <Esc>, section 1
-- (task reposcope.nvim/manual-checklist-run; ALL/manual-test-checklists/reposcope.md). Fake request tools and a
-- recording opener (TESTS/sheets/_helpers.lua): no network, no browser.
return {
  id = "reposcope.views",
  feature = "reposcope.views",
  title = "reposcope.nvim: <C-v> viewer (HTML to the browser), <C-b> scratch buffer, ? cheatsheet, <Esc> closes all",
  task = "reposcope.nvim/manual-checklist-run",
  sizes = { { rows = 40, cols = 140 } },
  steps = {
    {
      lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua"); _G.setup()
      _G.wins_before = #vim.api.nvim_list_wins()
      _G.bufs_before = #vim.api.nvim_list_bufs()]],
    },
    { keys = ":Reposcope start<CR>" },
    { wait = [[_G.in_field("keywords") and vim.fn.mode() == "i"]] },
    { input = "spotlight" },
    { wait = [[_G.typed("keywords", "spotlight")]] },
    { input = "<CR>" },
    { wait = [[_G.preview():find("README of alice/spotlight", 1, true) ~= nil]] },

    { input = "<C-v>", note = "the viewer" },
    { wait = [[vim.api.nvim_buf_get_name(0):find("reposcope://README.md", 1, true) ~= nil]] },
    {
      expect = [[_G.has(_G.text(), "README of alice/spotlight")
        and vim.api.nvim_win_get_width(0) >= vim.o.columns - 2 and vim.bo.filetype == "markdown"]],
      note = "fullscreen, the README itself",
    },
    { keys = "q" },
    { wait = [[_G.rbuf("readme_viewer") == nil and _G.in_field("keywords")]], note = "q goes back to the prompt" },

    { input = "<C-b>", note = "the scratch buffer" },
    { wait = [[vim.fn.bufnr("reposcope://README.md (spotlight)") > 0]] },
    {
      expect = [[(function()
        local b = vim.fn.bufnr("reposcope://README.md (spotlight)")
        return vim.fn.bufwinid(b) == -1 and vim.bo[b].modifiable and vim.bo[b].buflisted
          and _G.has(_G.text(b), "README of alice/spotlight")
      end)()]],
      note = "hidden, listed, real modifiable text",
    },

    { expect = [[vim.fn.mode() == "n"]], note = "the viewer left the prompt in normal mode" },
    { keys = "6<Down>", note = "to flare, whose README is HTML" },
    { wait = [[_G.selected() == 7]] },
    { wait = [[_G.preview():find("<div>", 1, true) ~= nil]] },
    { keys = "<C-v>" },
    { wait = [[_G.opened[1] == "https://github.com/frank/flare"]], note = "HTML goes to the browser" },
    { expect = [[_G.rbuf("readme_viewer") == nil]], note = "no viewer for HTML" },

    { keys = "?", note = "the cheatsheet" },
    { wait = [[_G.focused(" Prompt") and _G.focused("Toggle favorite")]] },
    {
      expect = [[(function()
        local keys = _G.documented_keys()
        assert(#keys >= 15, "too few documented keys: " .. #keys)
        for _, key in ipairs(keys) do _G.has(_G.text(), key) end
        return true
      end)()]],
      note = "every key of docs/BINDINGS.md 1.2 is in it",
    },
    { keys = "q" },
    { wait = [[#_G.floats() > 0 and _G.in_field("keywords")]], note = "back in the prompt" },

    { keys = "<Esc>", note = "close everything" },
    { wait = [[#_G.floats() == 0]] },
    {
      expect = [[#vim.api.nvim_list_wins() == _G.wins_before and _G.rbuf("list") == nil
        and _G.rbuf("preview") == nil and _G.rbuf("backg") == nil and vim.fn.bufnr("reposcope://prompt_keywords") == -1]],
      note = "no window or UI buffer is left behind",
    },

    { keys = "<Leader>rs", note = "the global keymaps: open" },
    { wait = [[_G.rbuf("list") ~= nil and _G.in_field("keywords")]] },
    { lua = [[vim.cmd("stopinsert")]] },
    { wait = [[vim.fn.mode() == "n"]] },
    { keys = "<Leader>rc", note = "close" },
    { wait = [[#_G.floats() == 0 and _G.rbuf("list") == nil]] },
  },
}
