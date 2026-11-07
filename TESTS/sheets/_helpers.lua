-- TESTS/sheets/_helpers.lua -- what the reposcope.nvim test sheets need in their child editor. Not a sheet
-- (`testing.sheet` only reads *.sheet.lua); a sheet's first step runs it with `dofile`, the child's cwd is the
-- project root. The directory is in the spec's @cache-inputs, so a change here re-runs the sheets.
--
-- Nothing here reaches GitHub, GitLab or Codeberg: the three request tools (gh, curl, wget) are replaced by a fake
-- that answers from the fixture below and records every URL it was asked for. The cache directory of the plugin
-- (stdpath("cache")/reposcope) is a fresh temp directory per sheet, so the user's real favorites, sessions and
-- READMEs are never read or written.

vim.opt.shortmess:append("I")
vim.o.swapfile = false
vim.o.hidden = true
-- The preview and the README views switch buffers between "text" and "markdown". The undo_ftplugin of Neovim's own
-- markdown ftplugin then runs `silent! nunmap <buffer> [[` and friends, which leaves E31 in v:errmsg, nothing shown;
-- a `keys` step would count that as an error of the plugin. Without the ftplugin's maps there is nothing to undo.
vim.g.no_markdown_maps = 1

---The project root (the child's cwd when the first step runs).
_G.root = vim.fs.normalize(vim.fn.getcwd())

-- stdpath("cache") reads $XDG_CACHE_HOME on every call; reposcope.config resolves its cache root when it is first
-- required, which is below, after this line.
_G.cache_home = vim.fs.normalize(vim.fn.tempname())
vim.fn.mkdir(_G.cache_home, "p")
vim.env.XDG_CACHE_HOME = _G.cache_home

---Fixture: what the fake GitHub search answers. Owner, name and description differ on purpose, so a filter can match
---one part alone.
---@type table[]
_G.fixture = {
  { owner = "alice", name = "spotlight", desc = "Search everything fast", stars = 50 },
  { owner = "bob", name = "lantern", desc = "A lamp for the terminal", stars = 300 },
  { owner = "carol", name = "beacon", desc = "Signals across editors", stars = 10 },
  { owner = "alice", name = "prism", desc = "Splits light into colors", stars = 120 },
  { owner = "dave", name = "torch", desc = "Burns through logs", stars = 75 },
  { owner = "erin", name = "candle", desc = "Small and steady", stars = 5 },
  { owner = "frank", name = "flare", desc = "Very bright, very short", stars = 900 },
}

---@type string[] every URL the fake was asked for, in order
_G.requests = {}

---The search answer for the fixture, as the GitHub API would send it.
---@return string
local function search_body()
  local items = {}
  for i, r in ipairs(_G.fixture) do
    items[i] = {
      name = r.name,
      owner = { login = r.owner },
      description = r.desc,
      html_url = "https://github.com/" .. r.owner .. "/" .. r.name,
      default_branch = "main",
      stargazers_count = r.stars,
      forks_count = i,
      updated_at = ("2026-0%d-01T00:00:00Z"):format(i),
      language = "Lua",
    }
  end
  return vim.json.encode({ total_count = #items, items = items })
end

---The README the fake sends for `owner/repo`; nil for a repository that does not exist.
---@param owner string
---@param repo string
---@return string|nil
function _G.readme_of(owner, repo)
  if repo == "missing" then return nil end
  if repo == "flare" then return "<div>\n<h1>flare</h1>\n</div>\n" end
  return ("# %s\n\nREADME of %s/%s from the fake host.\n"):format(repo, owner, repo)
end

---The fake request: answers asynchronously, like a spawned process.
---@param method string
---@param url string
---@param callback fun(response: string|nil, err?: string)
local function fake_request(method, url, callback)
  _G.requests[#_G.requests + 1] = url
  vim.defer_fn(function()
    if method == "GET" and url:find("/search/repositories?q=", 1, true) then
      callback(search_body())
      return
    end
    local owner, repo = url:match("^https://raw%.githubusercontent%.com/([^/]+)/([^/]+)/")
    if not owner then
      owner, repo = url:match("^https://api%.github%.com/repos/([^/]+)/([^/]+)/readme")
    end
    local body = owner and _G.readme_of(owner, repo)
    if body and url:find("api.github.com", 1, true) then
      body = vim.json.encode({ content = vim.base64.encode(body) })
    end
    if body then
      callback(body)
    else
      callback(nil, "fake host: 404 for " .. url)
    end
  end, 20)
end

for _, tool in ipairs({ "gh", "curl", "wget" }) do
  require("reposcope.network.request_tools." .. tool).request = fake_request
end
-- No PATH probe: the fake stands in for whichever tool would be found.
require("reposcope.utils.checks").ensure_request_tool = function() return true end

-- The system opener (browser) is a recorder: `_G.opened` holds every URL handed to it.
_G.opened = {}
require("reposcope.utils.os").open_url = function(url) _G.opened[#_G.opened + 1] = url end

---How many requests so far went to a URL holding `part` (plain).
---@param part string
---@return integer
function _G.asked(part)
  local n = 0
  for _, url in ipairs(_G.requests) do
    if url:find(part, 1, true) then n = n + 1 end
  end
  return n
end

---Whether a toast of reposcope so far holds `text` (plain), read from the history behind `:Reposcope messages`.
---@param text string
---@return boolean
function _G.noted(text)
  for _, entry in ipairs(require("lib.nvim.notify.popup").history("reposcope")) do
    if tostring(entry.message):find(text, 1, true) then return true end
  end
  return false
end

---`text` holds `part` (plain), or an error that shows the text.
---@param text string
---@param part string
---@return boolean
function _G.has(text, part)
  if not tostring(text):find(part, 1, true) then
    error(("no %s in %s"):format(vim.inspect(part), vim.inspect(text)), 0)
  end
  return true
end

---The lines of a buffer (default the current one) as one string, joined by a newline.
---@param buf integer|nil
---@return string
function _G.text(buf) return table.concat(vim.api.nvim_buf_get_lines(buf or 0, 0, -1, false), "\n") end

---The reposcope buffer `name` of ui_state (list, preview, prompt, ...).
---@param name string
---@return integer|nil
function _G.rbuf(name)
  local b = require("reposcope.state.ui.ui_state").buffers[name]
  return (type(b) == "number" and vim.api.nvim_buf_is_valid(b)) and b or nil
end

---The text typed into prompt field `name` (keywords, owner, language): its second line.
---@param name string
---@return string|nil
function _G.field(name)
  local b = (require("reposcope.state.ui.ui_state").buffers.prompt or {})[name]
  if not (b and vim.api.nvim_buf_is_valid(b)) then return nil end
  return vim.api.nvim_buf_get_lines(b, 1, 2, false)[1]
end

---The lines of the result list.
---@return string[]
function _G.list()
  local b = _G.rbuf("list")
  return b and vim.api.nvim_buf_get_lines(b, 0, -1, false) or {}
end

---The text of the README preview.
---@return string
function _G.preview()
  local b = _G.rbuf("preview")
  return b and _G.text(b) or ""
end

---The 1-based list line that is selected.
---@return integer|nil
function _G.selected() return require("reposcope.ui.list.list_window").highlighted_line end

---The floating windows of this tab.
---@return integer[]
function _G.floats()
  return vim.tbl_filter(
    function(w) return vim.api.nvim_win_get_config(w).relative ~= "" end,
    vim.api.nvim_tabpage_list_wins(0)
  )
end

---The buffer of the focused window holds `part` (plain).
---@param part string
---@return boolean
function _G.focused(part) return _G.text():find(part, 1, true) ~= nil end

---Load reposcope with these options, as a lazy.nvim spec would on first use.
---@param opts table|nil
function _G.setup(opts) require("reposcope").setup(opts or {}) end

---Field `name` shows `text` and the prompt state has it (what a search reads). The state follows the field on
---TextChangedI, which fires once the typed keys are through: a key queued right behind the text (a <Tab> to the next
---field) would otherwise arrive first, which a person typing never does.
---@param name string
---@param text string
---@return boolean
function _G.typed(name, text)
  return _G.field(name) == text and require("reposcope.state.ui.prompt_state").get_field_text(name) == text
end

---The cursor is in prompt field `name`.
---@param name string
---@return boolean
function _G.in_field(name)
  return vim.api.nvim_get_current_buf() == (require("reposcope.state.ui.ui_state").buffers.prompt or {})[name]
end

---The keys of the prompt table (section 1.2) of docs/BINDINGS.md, every `<...>` or single key in its key column.
---@return string[]
function _G.documented_keys()
  local keys, inside = {}, false
  for _, line in ipairs(vim.fn.readfile(_G.root .. "/docs/BINDINGS.md")) do
    if line:match("^### 1%.2 ") then
      inside = true
    elseif line:match("^### ") then
      inside = false
    elseif inside and line:match("^| `%l") then
      local col = vim.split(line, "|", { plain = true })[3]
      for key in col:gmatch("`([^`]+)`") do
        keys[#keys + 1] = key
      end
    end
  end
  return keys
end
