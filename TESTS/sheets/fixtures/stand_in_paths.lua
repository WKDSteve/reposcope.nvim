-- TESTS/sheets/fixtures/stand_in_paths.lua -- send the plugin's starts of some programs to recording stand-ins.
--
-- A stand-in first on the PATH is not enough: lib.nvim's spawn_capture starts through `vim.system`, and libuv looks
-- only for `.exe` and `.com` on Windows, so the `.cmd` stand-in of testing.nvim is passed over and the real `curl`
-- answers from the real network (seen 2026-11-19). So `vim.system` and `vim.fn.jobstart` (lib.nvim's `run_detached`
-- on Windows) are wrapped: a program the sheet names, with or without `.exe` (`rundll32.exe` on Windows and WSL), is
-- replaced by the absolute path of its stand-in, on every system. On Windows the characters cmd treats as operators
-- become `_` in its arguments (testing.nvim task fake-programs-der-windows-stand-in-fuehrt-die-teile-eines-ar).
--
-- Called as `chunk(dir, names)`. A sheet loads it with `load(text, "=<name>")`, never `dofile`: a chunk without a
-- file name is runtime to `testing perf`'s trace, so the plugin's own line stays the caller of the start (a `dofile`
-- from `TESTS/` would make every start the sheet's).
local dir, names = ...
local unpack = table.unpack or unpack
local windows = vim.fn.has("win32") == 1
local path_of = {}
for _, name in ipairs(names) do
  path_of[name] = dir .. "/" .. name .. (windows and ".cmd" or "")
end

local function redirect(cmd)
  if type(cmd) ~= "table" or type(cmd[1]) ~= "string" then return cmd end
  local name = vim.fs.basename(cmd[1]):gsub("%.[eE][xX][eE]$", "")
  local path = path_of[name]
  if not path then return cmd end
  local copy = { path }
  for i = 2, #cmd do
    copy[i] = windows and (tostring(cmd[i]):gsub("[&|<>^]", "_")) or cmd[i]
  end
  return copy
end

local system = vim.system
vim.system = function(cmd, opts, on_exit) return system(redirect(cmd), opts, on_exit) end

local jobstart = vim.fn.jobstart
vim.fn.jobstart = function(cmd, opts) return jobstart(redirect(cmd), opts) end

-- lib.nvim's spawn_capture (the request tools) calls libuv itself: `uv.spawn(file, { args = ... }, on_exit)`.
local uv = vim.uv or vim.loop
local spawn = uv.spawn
uv.spawn = function(file, options, on_exit)
  if type(file) == "string" and type(options) == "table" then
    local cmd = redirect({ file, unpack(options.args or {}) })
    if cmd[1] ~= file then
      options = vim.tbl_extend("force", options, { args = { unpack(cmd, 2) } })
      file = cmd[1]
    end
  end
  return spawn(file, options, on_exit)
end
