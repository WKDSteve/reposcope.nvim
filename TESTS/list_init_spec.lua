-- TESTS/list_init_spec.lua — reposcope.ui.list.initialize's redraw of the former results.
--
-- Opening the UI again redraws the results of the former search, one tick later. What it draws must be what the
-- repository cache holds when that tick comes: `:Reposcope start` puts the favorites into the cache in between (the
-- start view), and a list drawn from a snapshot taken before that showed the old search over them, with a cache
-- that no longer held its rows.

return function(H)
  local queued = {}
  local shown = {}
  local repositories = { list = { "old/search: before" } }

  H.with_stubs({
    ["reposcope.ui.list.list_window"] = { open_window = function() return true end },
    ["reposcope.ui.list.list_manager"] = { show_list = function(lines) shown[#shown + 1] = lines end },
    ["reposcope.cache.repository_cache"] = { get_list = function() return repositories.list end },
    ["reposcope.utils.debug"] = { notify = function() end },
  }, { "reposcope.ui.list.init" }, function()
    local original_schedule = vim.schedule
    vim.schedule = function(fn) queued[#queued + 1] = fn end
    local ok, err = pcall(require("reposcope.ui.list.init").initialize)
    vim.schedule = original_schedule
    if not ok then error(err, 0) end

    H.eq(#queued, 1, "the former results are drawn one tick later")
    -- The start view replaces the cache's list before that tick (repository_cache.set builds a new table).
    repositories.list = { "bob/lantern: the favorite" }
    queued[1]()

    H.eq(#shown, 1, "drawn once")
    H.eq(shown[1][1], "bob/lantern: the favorite", "what the cache holds then, not the snapshot of the old search")
  end)
end
