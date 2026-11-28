---@module 'reposcope.controllers.clone_info'
---@brief Extracts repository name and URL for cloning.
---@description
--- Returns basic information needed for cloning the currently selected repository:
--- name and URL. Validates presence and structure before use.
--- Provider-agnostic: reads from the shared repository cache, shared by every
--- provider's clone manager.

---@class CloneInfoLookup : CloneInfoLookupModule
local M = {}

local notify = require("reposcope.utils.debug").notify

---Gets the name, URL and default branch of the selected repository
---@return CloneInfo|nil
function M.get_clone_informations()
  local repo = require("reposcope.cache.repository_cache").get_selected()
  if not repo then
    notify("[reposcope] Error cloning: Repository is nil", 4)
    return nil
  end

  local name = repo.name or ""
  local url = repo.html_url or ""

  if name == "" then
    notify("[reposcope] Error cloning: Repository name is invalid", 4)
    return nil
  end

  if url == "" then
    notify("[reposcope] Error cloning: Repository URL is invalid", 4)
    return nil
  end

  -- The default branch decides which archive curl/wget download; a provider
  -- that did not report one leaves it nil, and the builder falls back to HEAD.
  local branch = type(repo.default_branch) == "string" and repo.default_branch ~= "" and repo.default_branch or nil

  return { name = name, url = url, branch = branch }
end

return M
