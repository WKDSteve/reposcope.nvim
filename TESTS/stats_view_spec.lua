-- TESTS/stats_view_spec.lua — `:Reposcope stats` (reposcope.utils.stats.show_stats).
--
-- Nothing is counted with `metrics = false`, the default. The window then says
-- so and how to turn counting on, instead of showing zeros that read like a
-- broken counter.

return function(H)
  local config = require("reposcope.config")
  local stats = require("reposcope.utils.stats")
  local saved = config.options.metrics

  local function shown()
    stats.show_stats()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local text = table.concat(lines, "\n")
    -- The float wraps: a line wider than the window pushes the last line out of its height.
    local win_width = vim.api.nvim_win_get_width(0)
    for _, line in ipairs(lines) do
      H.ok(vim.fn.strdisplaywidth(line) <= win_width, "the window fits the line: " .. line)
    end
    stats.close_stats()
    return text
  end

  local ok, err = pcall(function()
    config.options.metrics = false
    local off = shown()
    H.contains(off, "Reposcope Request Statistics", "the window opens")
    H.contains(off, "Counting is off (metrics = false)", "and says that nothing is counted")
    H.contains(off, "setup({ metrics = true })", "and how to turn it on")

    config.options.metrics = true
    local on = shown()
    H.excludes(on, "Counting is off", "with metrics on there is no such line")
    H.contains(on, "Successful requests", "only the counters")
  end)

  config.options.metrics = saved
  if not ok then error(err, 0) end
end
