-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- TESTS/favorites_clear_spec.lua — `:Reposcope favorites clear` after the start view.
--
-- With favorites saved, `:Reposcope start` shows them as the result set. Clearing
-- the favorites must take that set along: the next `start` of the session redrew
-- the former results, which were the favorites just cleared. A real search stays.

return function(H)
  local dir, cleanup = H.fixture("favorites_clear")
  local config = require("reposcope.config")
  local saved_path_fn = config.get_favorites_path
  config.get_favorites_path = function() return dir .. "/favorites.json" end

  local ok, err = pcall(function()
    package.loaded["reposcope.state.favorites_state"] = nil
    local favorites = require("reposcope.state.favorites_state")
    local cache = require("reposcope.cache.repository_cache")
    local repo = {
      owner = { login = "bob" },
      name = "lantern",
      description = "A lamp",
      html_url = "https://github.com/bob/lantern",
      default_branch = "main",
    }

    -- The start view, without the windows and the README fetch behind it.
    local function start_view()
      H.with_stubs(
        {
          ["reposcope.controllers.list_controller"] = { display_repositories = function() end },
          ["reposcope.controllers.provider_controller"] = { fetch_readme_for_selected = function() end },
        },
        { "reposcope.controllers.start_view_controller" },
        function()
          H.ok(require("reposcope.controllers.start_view_controller").show_favorites_if_any(), "favorites shown")
        end
      )
    end

    favorites.toggle(repo)
    start_view()
    H.eq(cache.get_list()[1], "bob/lantern: A lamp", "the start view holds the favorite")

    require("reposcope.bindings.usrcmds")
    vim.cmd("Reposcope favorites clear")
    H.eq(#favorites.list(), 0, "the favorites are gone")
    H.eq(cache.get_list()[1], "", "and so is the result set the start view made of them")
    H.eq(cache.relevance_result, nil, "including its relevance snapshot, which `sort relevance` would restore")

    -- A real search's results are not the start view's: clearing favorites leaves them.
    favorites.toggle(repo)
    start_view()
    cache.set({ total_count = 1, items = { vim.deepcopy(repo) } }, true)
    vim.cmd("Reposcope favorites clear")
    H.eq(cache.get_list()[1], "bob/lantern: A lamp", "a search's results stay")
    cache.clear()
    cache.clear_relevance_result()
  end)

  config.get_favorites_path = saved_path_fn
  package.loaded["reposcope.state.favorites_state"] = nil
  cleanup()
  if not ok then error(err, 0) end
end
