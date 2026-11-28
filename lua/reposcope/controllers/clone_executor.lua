---@module 'reposcope.controllers.clone_executor'
---@brief Executes shell clone commands and records metrics.
---@description
--- Executes cloning using a shell command, measures execution time,
--- and reports success/failure metrics. Also logs feedback to the user.
--- Provider-agnostic: shared by every provider's clone manager.

---@class CloneExecutor : CloneExecutorModule
local M = {}

local hrtime = vim.uv.hrtime
local notify = require("reposcope.utils.debug").notify
local toast = require("reposcope.utils.debug").toast
local metrics = require("reposcope.utils.metrics")
local safe_execute_shell_async = require("reposcope.utils.protection").safe_execute_shell_async

---@param cmd string[]
---@param uuid string
---@param repo_name string
---@param repo_url? string The repository's clone/web URL, for metrics logging
---@param repo_path? string Target directory of the clone; with it a successful git/gh clone fires `User ReposcopeCloned`
---@return nil
--- Asynchronous: `git clone` is a network operation that runs for seconds and,
--- on a large repository or a slow link, minutes. It used to go through the
--- blocking `safe_execute_shell`, freezing Neovim for the whole clone. Nothing
--- here consumed a return value -- the function only notifies and records
--- metrics -- so moving it behind a callback changes no caller.
---
--- The duration measurement still spans the real wall-clock time of the clone;
--- `start` is captured before the spawn and read in the callback.
function M.execute(cmd, uuid, repo_name, repo_url, repo_path)
  local start = hrtime()
  local is_repository = cmd[1] == "git" or cmd[1] == "gh"
  -- Where the result lands: the repository directory, or the archive beside it for curl/wget.
  local target = repo_path and (is_repository and repo_path or repo_path .. ".zip")

  -- Start and success are said outside dev mode too: a clone runs for seconds to
  -- minutes in the background, and without them nothing shows it started or finished.
  -- Toasts only (no :messages echo): this runs right after the path prompt, and an
  -- echo under the answered prompt line would stop the editor at a hit-enter prompt.
  toast("[reposcope] Cloning " .. repo_name .. (target and (" into " .. target) or "") .. "...")

  safe_execute_shell_async(cmd, function(success, output)
    local duration = (hrtime() - start) / 1e6

    if success then
      if metrics.record_metrics() then
        metrics.increase_success(uuid, repo_name, "clone", "clone_repo", duration, 200, repo_url)
      end
      toast("[reposcope] Repository cloned successfully" .. (target and (": " .. target) or ""))
      -- Soft integration point: gitsuite / terminal.nvim listen for this and pick the repo up.
      -- curl/wget only download an archive, so no repository exists there yet: no event.
      if repo_path and is_repository then
        vim.api.nvim_exec_autocmds("User", {
          pattern = "ReposcopeCloned",
          modeline = false,
          data = { path = repo_path, url = repo_url },
        })
      end
    else
      if metrics.record_metrics() then
        metrics.increase_failed(uuid, repo_name, "clone", "clone_repo", duration, 500, output, repo_url)
      end
      notify("[reposcope] Clone failed: " .. (output or "unknown error"), 4)
    end
  end)
end

return M
