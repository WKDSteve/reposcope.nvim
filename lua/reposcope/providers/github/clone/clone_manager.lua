---@module 'reposcope.providers.github.clone.clone_manager'
---@brief Coordinates cloning operations for GitHub repositories.
---@description
--- This module ensures that all clone operations are routed through a single
--- point of control. It manages the request lifecycle (UUID registration, activity checks),
--- validates input, and delegates execution to helper modules for building the
--- command, collecting repository info, and executing the shell command.
---
--- All clone operations should go through this manager to ensure that
--- the UUID-based `request_state` system works reliably and uniformly
--- across providers. This helps prevent duplicate or conflicting requests,
--- and enables metrics and logging integration.

---@class GithubCloneManager : CloneManagerModule
local M = {}

-- Request Tracking and Config
local request_state = require("reposcope.state.requests_state")
local config = require("reposcope.config")
-- Submodules
local get_clone_informations = require("reposcope.controllers.clone_info").get_clone_informations
local build_command = require("reposcope.providers.github.clone.clone_command").build_command
local execute_clone = require("reposcope.controllers.clone_executor").execute
-- Utils
local notify = require("reposcope.utils.debug").notify
local isdirectory = vim.fn.isdirectory
local expand_path = require("lib.nvim.cross.fs.expand_path")

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

  -- What the prompt returns is typed text: `~` and `$VAR` mean what they mean in a shell
  -- (std_dir gets the same expansion in config). isdirectory() expands neither, and git
  -- would take `~` as a literal directory name.
  if type(path) == "string" then path = expand_path(path) end

  if not path or isdirectory(path) ~= 1 then
    notify("[reposcope] Clone request: Invalid path", 4)
    request_state.end_request(uuid)
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

  local cmd = build_command(clone_type, repo_url, output_dir, infos.branch)
  execute_clone(cmd, uuid, repo_name, repo_url, output_dir)

  request_state.end_request(uuid)
end

return M
