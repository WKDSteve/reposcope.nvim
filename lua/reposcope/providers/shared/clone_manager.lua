---@module 'reposcope.providers.shared.clone_manager'
---@brief The clone operations for a provider, the same for Codeberg and GitLab.
---@description
--- A factory rather than a table of functions, so that each provider keeps its own
--- module state and reads its own sibling modules by name. GitHub differs more and
--- keeps its own files.

local S = {}

---@param name string The provider's folder under `reposcope.providers`
---@return CloneManagerModule
function S.new(name)
  local base = "reposcope.providers." .. name
  local M = {}

  -- Request Tracking and Config
  local request_state = require("reposcope.state.requests_state")
  local config = require("reposcope.config")
  -- Submodules
  local get_clone_informations = require("reposcope.controllers.clone_info").get_clone_informations
  local build_command = require(base .. ".clone.clone_command").build_command
  local execute_clone = require("reposcope.controllers.clone_executor").execute
  -- Utils
  local notify = require("reposcope.utils.debug").notify
  local isdirectory = vim.fn.isdirectory

  ---Starts a clone operation using the given path and UUID
  ---@param path string The target directory for cloning
  ---@param uuid string A unique request identifier
  ---@return nil
  function M.clone(path, uuid)
    if not request_state.is_registered(uuid) then
      notify("[reposcope] Clone request: UUID is not registered", 2)
      return
    end

    if request_state.is_request_active(uuid) then
      notify("[reposcope] Clone request: Already active for UUID", 2)
      return
    end

    if not path or isdirectory(path) ~= 1 then
      notify("[reposcope] Clone request: Invalid path", 4)
      return
    end

    request_state.start_request(uuid)

    local infos = get_clone_informations()
    if not infos then
      request_state.end_request(uuid)
      return
    end

    local repo_name = infos.name
    local repo_url = infos.url
    local clone_type = config.options.clone.type

    -- Normalize the path. The target directory itself is not created here: git/gh
    -- create it (and refuse a non-empty one), curl/wget write <target>.zip beside it.
    path = path:gsub("/+$", "") .. "/"
    local output_dir = path .. repo_name

    local cmd = build_command(clone_type, repo_url, output_dir)
    execute_clone(cmd, uuid, repo_name, repo_url, output_dir)

    request_state.end_request(uuid)
  end

  return M
end

return S
