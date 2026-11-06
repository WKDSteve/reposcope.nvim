---@module 'reposcope.providers.shared.repository_manager'
---@brief The repository search for a provider, the same for Codeberg and GitLab.
---@description
--- A factory rather than a table of functions, so that each provider keeps its own
--- module state and reads its own sibling modules by name. GitHub differs more and
--- keeps its own files.

local S = {}

---@param name string The provider's folder under `reposcope.providers`
---@return RepositoryManagerModule
function S.new(name)
  local base = "reposcope.providers." .. name
  local M = {}

  -- Submodules
  local fetcher = require(base .. ".repositories.repository_fetcher")
  local ui_loader = require("reposcope.controllers.repository_ui_loader")
  -- State & Utilities
  local request_state = require("reposcope.state.requests_state")
  local notify = require("reposcope.utils.debug").notify
  local clear_list = require("reposcope.ui.list.list_manager").clear_list
  local clear_preview = require("reposcope.ui.preview.preview_manager").clear_preview
  local repo_cache_clear = require("reposcope.cache.repository_cache").clear

  ---Handles clearing UI and state in case of API or fetch errors
  ---@private
  ---@internal
  ---@return nil
  local function _handle_fetch_failure()
    repo_cache_clear()
    clear_list()
    clear_preview()
  end

  ---Fetches the provider repositories without UI logic (for headless or cache-only usage)
  ---@param query string
  ---@param uuid string
  ---@param on_success? fun(): nil
  ---@param on_failure? fun(): nil
  ---@return nil
  function M.fetch(query, uuid, on_success, on_failure)
    if not request_state.is_registered(uuid) then
      notify("[reposcope] Skipped fetch: UUID not registered", 3)
      return
    end
    if request_state.is_request_active(uuid) then
      notify("[reposcope] Skipped fetch: Request already active for UUID " .. uuid, 3)
      return
    end

    request_state.start_request(uuid)

    fetcher.fetch_repositories(query, function()
      if on_success then on_success() end
    end, function()
      if on_failure then
        on_failure()
      else
        _handle_fetch_failure()
      end
    end)
  end

  ---@param query string
  ---@param uuid string
  ---@param on_success? fun(): nil
  ---@param on_failure? fun(): nil
  function M.refresh_results(query, uuid, on_success, on_failure)
    if not request_state.is_registered(uuid) then
      notify("[reposcope] Skipped fetch: UUID not registered", 3)
      return
    end
    if request_state.is_request_active(uuid) then
      notify("[reposcope] Skipped fetch: Request already active for UUID " .. uuid, 3)
      return
    end

    request_state.start_request(uuid)

    fetcher.fetch_repositories(query, function()
      ui_loader.load_ui_after_fetch()
      if on_success then on_success() end
    end, function()
      if on_failure then
        on_failure()
      else
        _handle_fetch_failure()
      end
    end)
  end

  return M
end

return S
