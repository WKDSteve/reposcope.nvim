-- Live check: favorites, <C-f>, :Reposcope favorites [clear], the start view from favorites, section 5
-- (task reposcope.nvim/manual-checklist-run; ALL/manual-test-checklists/reposcope.md). Fake request tools and a
-- temp cache directory (TESTS/sheets/_helpers.lua): no network, the real favorites.json is never touched.
return {
  id = "reposcope.favorites",
  title = "reposcope.nvim: <C-f> toggles a favorite, the list shows it, a fresh start shows favorites without a request",
  task = "reposcope.nvim/manual-checklist-run",
  sizes = { { rows = 40, cols = 140 } },
  steps = {
    { lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua"); _G.setup({ readme_precache_count = 0 })]] },
    { keys = ":Reposcope start<CR>" },
    { wait = [[_G.in_field("keywords") and vim.fn.mode() == "i"]] },
    { expect = [[_G.list()[1] == "" or #_G.list() == 0]], note = "no favorites yet: the plain empty prompt" },
    { input = "light" },
    { wait = [[_G.typed("keywords", "light")]] },
    { input = "<CR>" },
    { wait = [[_G.preview():find("README of alice/spotlight", 1, true) ~= nil]] },
    { input = "<Down>" },
    { wait = [[_G.preview():find("README of bob/lantern", 1, true) ~= nil]] },
    { input = "<C-f>", note = "favorite bob/lantern" },
    {
      wait = [[require("reposcope.state.favorites_state").is_favorite("bob", "lantern")]],
    },
    {
      expect = [[(function()
        local path = vim.fs.normalize(require("reposcope.config").get_favorites_path())
        _G.has(path, _G.cache_home)
        return _G.has(table.concat(vim.fn.readfile(path), "\n"), "lantern")
      end)()]],
      note = "written at once, as JSON under the plugin's cache directory",
    },
    { input = "<Esc>" },
    { wait = [[vim.fn.mode() == "n"]] },

    { keys = ":Reposcope favorites<CR>" },
    { wait = [[_G.focused("bob/lantern")]] },
    {
      expect = [[_G.has(_G.text(), "A lamp for the terminal") and _G.has(_G.text(), "300")
        and _G.has(_G.text(), "https://github.com/bob/lantern")]],
      note = "owner, name, description, stars, URL",
    },
    { keys = "q" },
    { wait = [[_G.in_field("keywords")]] },

    { keys = ":Reposcope close<CR>" },
    { wait = [[#_G.floats() == 0]] },
    { lua = [[_G.requests = {}]] },
    { keys = ":Reposcope start<CR>", note = "fresh open, favorites exist" },
    { wait = [[#_G.list() == 1 and _G.list()[1]:find("bob/lantern", 1, true) ~= nil]], note = "the favorite at once" },
    { wait = [[_G.preview():find("README of bob/lantern", 1, true) ~= nil]], note = "its README warm" },
    { lua = "vim.wait(300)" },
    { expect = [[#_G.requests == 0]], note = "no network call, the README from the favorite's own snapshot" },
    { input = "<C-f>", note = "un-favorite" },
    { wait = [[not require("reposcope.state.favorites_state").is_favorite("bob", "lantern")]] },
    { input = "<Down>" },
    { input = "<C-f>", note = "favorite it again, for clear" },
    { wait = [[require("reposcope.state.favorites_state").is_favorite("bob", "lantern")]] },

    {
      expect = [[(function()
        local name = "reposcope.state.favorites_state"
        local running = package.loaded[name]
        package.loaded[name] = nil
        local ok, fresh = pcall(require, name)
        package.loaded[name] = running
        return ok and fresh.is_favorite("bob", "lantern")
      end)()]],
      note = "persisted: a fresh copy of the module, as after a restart, reads it from the file",
    },
    { lua = [[vim.cmd("stopinsert")]] },
    { wait = [[vim.fn.mode() == "n"]] },
    { keys = ":Reposcope favorites clear<CR>" },
    { wait = [[#require("reposcope.state.favorites_state").list() == 0]] },
    { keys = ":Reposcope favorites<CR>" },
    { wait = [[_G.focused("No favorites yet.")]], note = "the list is empty" },
    { keys = "q" },
    { wait = [[_G.in_field("keywords")]] },
    {
      expect = [[require("reposcope.controllers.start_view_controller").show_favorites_if_any() == false]],
      note = "the next start falls back to the empty prompt (in this session it redraws the former results)",
    },
  },
  manual = {
    "There is no marker on a favorited row in the list (see the task: open question)",
    "After a restart, :Reposcope start without favorites shows the empty prompt",
  },
}
