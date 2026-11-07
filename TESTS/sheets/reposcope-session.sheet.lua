-- Live check: :Reposcope session save|restore|clear, section 6 (task reposcope.nvim/manual-checklist-run;
-- ALL/manual-test-checklists/reposcope.md). Fake request tools and a temp cache directory
-- (TESTS/sheets/_helpers.lua): no network, the real session.json is never touched.
return {
  id = "reposcope.session",
  title = "reposcope.nvim: a saved session restores provider, query, filter and sort, asynchronously; clear forgets it",
  task = "reposcope.nvim/manual-checklist-run",
  sizes = { { rows = 40, cols = 140 } },
  steps = {
    { lua = [[dofile(vim.fn.getcwd() .. "/TESTS/sheets/_helpers.lua"); _G.setup({ readme_precache_count = 0 })]] },
    { keys = ":Reposcope start<CR>" },
    { wait = [[_G.in_field("keywords") and vim.fn.mode() == "i"]] },
    { input = "light" },
    { input = "<Tab>" },
    { wait = [[_G.in_field("owner")]] },
    { input = "alice" },
    { wait = [[_G.field("keywords") == "light" and _G.field("owner") == "alice"]] },
    { input = "<CR>" },
    { wait = [[#_G.list() == #_G.fixture and _G.list()[1] ~= ""]] },
    { input = "<Esc>" },
    { wait = [[vim.fn.mode() == "n"]] },
    { keys = ":Reposcope filter light<CR>", note = "spotlight and prism (description)" },
    { wait = [[#_G.list() == 2]] },
    { keys = ":Reposcope sort<CR>" },
    { wait = [[_G.focused("stars")]] },
    { keys = "jj<CR>", note = "stars" },
    { wait = [[_G.list()[1]:find("alice/prism", 1, true) ~= nil]] },
    { lua = "_G.saved_query = _G.requests[1]" },
    { keys = ":Reposcope session save<CR>" },
    {
      expect = [[(function()
        local data = vim.json.decode(table.concat(vim.fn.readfile(require("reposcope.config").get_session_path()), "\n"))
        local keys = vim.tbl_keys(data)
        table.sort(keys)
        assert(vim.deep_equal(keys, { "fields", "filter_text", "input", "provider", "query", "sort_mode" }), vim.inspect(keys))
        return data.provider == "github" and data.filter_text == "light" and data.sort_mode == "stars"
          and data.input.keywords == "light" and data.input.owner == "alice"
      end)()]],
      note = "provider, prompt values, query, filter, sort; nothing of the window layout",
    },

    { keys = ":Reposcope close<CR>" },
    { wait = [[#_G.floats() == 0]] },
    { keys = ":Reposcope start<CR>" },
    { wait = [[_G.in_field("keywords") and vim.fn.mode() == "i"]] },
    { input = "<End>", note = "the field still holds light (<C-u> scrolls the preview here)" },
    { wait = [[vim.api.nvim_win_get_cursor(0)[2] == 5]] },
    { input = "<BS><BS><BS><BS><BS>" },
    { wait = [[_G.field("keywords") == ""]] },
    { input = "torch" },
    { wait = [[_G.field("keywords") == "torch"]] },
    { input = "<CR>", note = "another search" },
    { wait = [[#_G.requests == 2 and #_G.list() == #_G.fixture]] },
    { input = "<Esc>" },
    { wait = [[vim.fn.mode() == "n"]] },
    { lua = [[require("reposcope.config").options.provider = "gitlab"]], note = "another provider is active" },

    {
      lua = [[vim.cmd("Reposcope session restore"); _G.on_return = { n = #_G.list(), requests = #_G.requests }]],
      note = "restore, and what the list is the moment the command returns",
    },
    {
      expect = [[_G.on_return.n == #_G.fixture and _G.on_return.requests == 3]],
      note = "the search is under way, the list not yet filtered: asynchronous",
    },
    { wait = [[#_G.list() == 2 and _G.list()[1]:find("alice/prism", 1, true) ~= nil]], note = "filter and sort after" },
    { expect = [[_G.requests[3] == _G.saved_query]], note = "the saved query, on GitHub again" },
    {
      expect = [[require("reposcope.config").get_option("provider") == "github"
        and require("reposcope.state.ui.prompt_state").get_field_text("keywords") == "light"
        and require("reposcope.state.ui.prompt_state").get_field_text("owner") == "alice"]],
      note = "provider and prompt values restored",
    },
    { expect = [[_G.field("keywords") == "light" and _G.field("owner") == "alice"]], note = "and shown in the prompt" },
    { keys = ":Reposcope providers<CR>" },
    { wait = [[_G.focused("* github")]], note = ":Reposcope providers marks github" },
    { keys = "q" },

    { keys = ":Reposcope session clear<CR>" },
    { expect = [[vim.fn.filereadable(require("reposcope.config").get_session_path()) == 0]] },
    { lua = [[_G.restored = require("reposcope.state.session_state").restore()]] },
    { expect = [[_G.restored == false]], note = "as if no session ever existed" },
    { wait = [[_G.noted("No saved session found.")]], note = "a notice, no error" },
  },
}
