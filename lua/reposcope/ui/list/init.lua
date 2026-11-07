---@module 'reposcope.ui.list.init'
---@brief Entry point for initializing and restoring the repository list UI
---@description
--- This module acts as the orchestration layer for the repository list UI.
--- It integrates the list window and list manager components, and ensures
--- that any cached repository results are restored and displayed after startup.

---@class ListUI : ListUIModule
local M = {}

-- UI Components
local open_window = require("reposcope.ui.list.list_window").open_window
local show_list = require("reposcope.ui.list.list_manager").show_list
-- Cache Management
local get_list = require("reposcope.cache.repository_cache").get_list
-- Debugging Utility
local notify = require("reposcope.utils.debug").notify

---Initializes the list UI and dynamically loads if cached repositories exist.
---@return nil
function M.initialize()
  if not open_window() then
    notify("[reposcope] List initialization failed.", 4)
    return
  end

  -- Redraw the results of a former search, if any. The list is read when the
  -- tick comes, not now: `open_ui()` shows the favorites (the start view) in
  -- between, and a snapshot taken here drew the old search over them while
  -- the cache already held only the favorites.
  if #get_list()[1] > 1 then
    vim.schedule(function()
      local actual_repo_list = get_list()
      if #actual_repo_list[1] > 1 then show_list(actual_repo_list) end
    end)
  end
end

return M
