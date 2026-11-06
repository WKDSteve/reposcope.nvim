---@module 'reposcope.providers.shared.readme_fetcher'
---@brief The README downloads, raw file first and the API as fallback for a provider, the same for Codeberg and GitLab.
---@description
--- A factory rather than a table of functions, so that each provider keeps its own
--- module state and reads its own sibling modules by name. GitHub differs more and
--- keeps its own files.

local S = {}

---@param name string The provider's folder under `reposcope.providers`
---@return ReadmeFetcherModule
function S.new(name)
  local base = "reposcope.providers." .. name
  local M = {}

  -- Network utilities
  local request = require("reposcope.network.clients.api_client").request
  local decode_base64 = require("reposcope.utils.encoding").decode_base64
  local get_urls = require(base .. ".readme.readme_urls").get_urls

  ---Fetches the README using the provider's raw file URL
  ---@param owner string Repository owner
  ---@param repo string Repository name
  ---@param branch string Target branch (e.g., "main")
  ---@param cb fun(success: boolean, content: string|nil, err: string|nil): nil Callback receiving result
  ---@return nil
  function M.fetch_raw(owner, repo, branch, cb)
    local urls = get_urls(owner, repo, branch)
    if not urls or not urls.raw then
      cb(false, nil, "Missing raw URL")
      return
    end

    request("GET", urls.raw, function(response, err)
      if err or not response then
        cb(false, nil, err or "empty response") -- The manager decides what, if anything, the user sees
        return
      end
      cb(true, response)
    end, nil, "readme_fetch_raw")
  end

  ---Fetches the README from the provider's API (base64-encoded)
  ---@param owner string Repository owner
  ---@param repo string Repository name
  ---@param branch string Target branch (e.g., "main")
  ---@param cb fun(success: boolean, content: string|nil, err: string|nil): nil Callback receiving result
  ---@return nil
  function M.fetch_api(owner, repo, branch, cb)
    local urls = get_urls(owner, repo, branch)
    if not urls or not urls.api then
      cb(false, nil, "Missing API URL")
      return
    end

    request("GET", urls.api, function(response, err)
      if err or not response then
        cb(false, nil, err or "empty response") -- The manager decides what, if anything, the user sees
        return
      end

      local ok, decoded = pcall(vim.json.decode, response)
      if not ok or not decoded or not decoded.content then
        cb(false, nil, "Invalid JSON or missing content")
        return
      end

      local content = decode_base64(decoded.content)
      cb(true, content)
    end, nil, "readme_fetch_api")
  end

  return M
end

return S
