-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- TESTS/clone_spec.lua — the clone path: argv builders, the per-provider
-- managers, the shared info lookup and the shared executor.
--
-- No process is started. `controllers.clone_executor` is stubbed for the
-- manager blocks, and `utils.protection.safe_execute_shell_async` for the
-- executor block, so what is asserted is the exact argv that would have been
-- handed to the OS.

return function(H)
  ---------------------------------------------------------------------------
  -- Argv builders
  ---------------------------------------------------------------------------
  do
    local github = require("reposcope.providers.github.clone.clone_command")
    local url = "https://github.com/nvim-telescope/telescope.nvim.git"
    local out = "/tmp/clones/telescope.nvim"

    -- The whole point of returning a table rather than a shell string: a path
    -- with a space needs no quoting and behaves the same on cmd.exe and sh.
    local git = github.build_command("git", url, out)
    H.eq(git[1], "git", "the default tool is git")
    H.eq(git[2], "clone", "cloning")
    H.eq(git[3], url, "from the repository URL")
    H.eq(git[4], out, "into the target directory")
    H.eq(#git, 4, "and nothing else")

    H.eq(#github.build_command("", url, out), 4, "an unset clone type also means git")
    H.eq(github.build_command("anything-else", url, out)[1], "git", "as does an unrecognised one")

    local gh = github.build_command("gh", url, out)
    H.eq(table.concat(gh, " "), "gh repo clone " .. url .. " " .. out, "gh has its own subcommand")

    local curl = github.build_command("curl", url, out)
    H.eq(curl[1], "curl", "curl downloads an archive instead of cloning")
    H.eq(curl[2], "-L", "following redirects")
    H.eq(curl[3], "--max-time", "with a timeout")
    H.eq(curl[4], "300", "of 300s -- generous, because this is a whole repository")
    H.eq(curl[5], "-o", "written to a file")
    H.eq(curl[6], out .. ".zip", "named after the target directory")
    H.eq(
      curl[7],
      "https://github.com/nvim-telescope/telescope.nvim/archive/refs/heads/main.zip",
      "from GitHub's own archive route"
    )

    local wget = github.build_command("wget", url, out)
    H.eq(wget[1], "wget", "wget does the same")
    H.eq(wget[2], "--timeout=300", "with its own timeout spelling")
    H.eq(wget[3], "-O", "writing to")
    H.eq(wget[4], out .. ".zip", "the same archive name")
    H.eq(wget[5], curl[7], "and the same URL")
  end

  do
    local gitlab = require("reposcope.providers.gitlab.clone.clone_command")
    local url = "https://gitlab.com/gitlab-org/gitlab-runner.git"
    local out = "/tmp/clones/gitlab-runner"

    H.eq(gitlab.build_command("git", url, out)[1], "git", "git clone is the default here too")
    -- gh is a GitHub CLI; asking for it on GitLab must not produce a `gh` argv.
    H.eq(gitlab.build_command("gh", url, out)[1], "git", "gh is not supported for GitLab and degrades to git")

    local curl = gitlab.build_command("curl", url, out)
    H.eq(
      curl[#curl],
      "https://gitlab.com/gitlab-org/gitlab-runner/-/archive/main/gitlab-runner-main.zip",
      "GitLab's archive route is /-/archive/<branch>/<repo>-<branch>.zip, not GitHub's"
    )

    -- A nested group is part of the path, so the greedy owner match has to
    -- keep all of it.
    local nested = gitlab.build_command("curl", "https://gitlab.com/group/sub/proj.git", out)
    H.contains(nested[#nested], "https://gitlab.com/group/sub/proj/-/archive/", "a nested group survives the URL parse")

    -- A URL that does not look like gitlab.com still yields a usable name.
    local odd = gitlab.build_command("wget", "https://self.hosted/team/thing.git", out)
    H.contains(odd[#odd], "/thing/-/archive/main/thing-main.zip", "an unrecognised host still derives the project name")
  end

  do
    local codeberg = require("reposcope.providers.codeberg.clone.clone_command")
    local url = "https://codeberg.org/forgejo/forgejo.git"
    local out = "/tmp/clones/forgejo"

    H.eq(codeberg.build_command("git", url, out)[1], "git", "git clone is the default")
    H.eq(codeberg.build_command("gh", url, out)[1], "git", "gh is not supported for Codeberg either")

    local curl = codeberg.build_command("curl", url, out)
    H.eq(
      curl[#curl],
      "https://codeberg.org/forgejo/forgejo/archive/main.zip",
      "Gitea's archive route is /<owner>/<repo>/archive/<branch>.zip"
    )
    H.eq(
      codeberg.build_command("wget", url, out)[#codeberg.build_command("wget", url, out)],
      curl[#curl],
      "same URL for wget"
    )
  end

  ---------------------------------------------------------------------------
  -- clone_info: what the managers clone
  ---------------------------------------------------------------------------
  do
    local function with_info(selected, fn)
      H.with_stubs(
        {
          ["reposcope.cache.repository_cache"] = { get_selected = function() return selected end },
        },
        { "reposcope.controllers.clone_info" },
        function() fn(require("reposcope.controllers.clone_info").get_clone_informations()) end
      )
    end

    with_info(nil, function(info) H.eq(info, nil, "no selection means nothing to clone") end)
    with_info(
      { html_url = "https://x/y.git" },
      function(info) H.eq(info, nil, "a repository without a name is refused") end
    )
    with_info({ name = "y" }, function(info) H.eq(info, nil, "a repository without a URL is refused") end)
    with_info(
      { name = "", html_url = "https://x/y.git" },
      function(info) H.eq(info, nil, "an empty name is refused") end
    )
    with_info({ name = "y", html_url = "" }, function(info) H.eq(info, nil, "an empty URL is refused") end)
    with_info({ name = "telescope.nvim", html_url = "https://github.com/t/telescope.nvim.git" }, function(info)
      H.eq(info.name, "telescope.nvim", "a complete selection yields the name")
      H.eq(info.url, "https://github.com/t/telescope.nvim.git", "and the URL")
    end)
  end

  ---------------------------------------------------------------------------
  -- The managers
  ---------------------------------------------------------------------------
  local MANAGERS = {
    -- `suffix` is what the configured tool appends to the computed output
    -- directory: nothing for a real clone, `.zip` for an archive download.
    {
      name = "github",
      module = "reposcope.providers.github.clone.clone_manager",
      tool = "gh",
      head = "gh",
      suffix = "",
    },
    {
      name = "gitlab",
      module = "reposcope.providers.gitlab.clone.clone_manager",
      tool = "curl",
      head = "curl",
      suffix = ".zip",
    },
    {
      name = "codeberg",
      module = "reposcope.providers.codeberg.clone.clone_manager",
      tool = "git",
      head = "git",
      suffix = "",
    },
  }

  local dir, cleanup = H.fixture("clone")
  local ok_all, err_all = pcall(function()
    for _, m in ipairs(MANAGERS) do
      -- `isdir`, when given, stands in for vim.fn.isdirectory while the manager
      -- is loaded and run (it captures the function at require time).
      local function with_manager(fn, isdir)
        local env = {
          executed = {},
          mkdirs = {},
          notes = {},
          info = { name = "telescope.nvim", url = "https://github.com/t/telescope.nvim.git" },
        }
        H.with_stubs({
          ["reposcope.controllers.clone_info"] = {
            get_clone_informations = function() return env.info end,
          },
          ["reposcope.controllers.clone_executor"] = {
            execute = function(cmd, uuid, repo_name, repo_url)
              env.executed[#env.executed + 1] = { cmd = cmd, uuid = uuid, repo_name = repo_name, repo_url = repo_url }
            end,
          },
          ["reposcope.utils.protection"] = {
            safe_mkdir = function(path)
              env.mkdirs[#env.mkdirs + 1] = path
              return true
            end,
          },
          ["reposcope.utils.debug"] = {
            notify = function(msg) env.notes[#env.notes + 1] = msg end,
            is_dev_mode = function() return false end,
            debugf = function() end,
            options = { dev_mode = false },
          },
        }, { m.module }, function()
          local real_isdirectory = vim.fn.isdirectory
          if isdir then vim.fn.isdirectory = isdir end
          local config = require("reposcope.config")
          local saved = config.options.clone.type
          config.options.clone.type = m.tool

          local request_state = require("reposcope.state.requests_state")
          request_state.clear_all_requests()

          local ok, err = pcall(fn, require(m.module), env, request_state)

          config.options.clone.type = saved
          vim.fn.isdirectory = real_isdirectory
          request_state.clear_all_requests()
          if not ok then error(err, 0) end
        end)
      end

      -- Gating -------------------------------------------------------------
      with_manager(function(manager, env, request_state)
        manager.clone(dir, "unknown")
        H.eq(#env.executed, 0, m.name .. ": an unregistered UUID clones nothing")
        H.contains(env.notes[1], "UUID is not registered", "and says why")

        request_state.register_request("x")
        request_state.start_request("x")
        manager.clone(dir, "x")
        H.eq(#env.executed, 0, "an already-active UUID is skipped")
        H.contains(env.notes[2], "Already active", "and says why")
      end)

      -- The happy path -----------------------------------------------------
      with_manager(function(manager, env, request_state)
        request_state.register_request("y")
        manager.clone(dir, "y")

        H.eq(#env.executed, 1, m.name .. ": one clone is executed")
        H.eq(env.executed[1].cmd[1], m.head, "with the configured tool at the head of argv")
        H.eq(env.executed[1].repo_name, "telescope.nvim", "the repository name is passed for metrics")
        H.eq(env.executed[1].repo_url, "https://github.com/t/telescope.nvim.git", "as is the URL")
        H.eq(env.executed[1].uuid, "y", "and the request UUID")
        H.has(env.executed[1].cmd, dir .. "/telescope.nvim" .. m.suffix, "the target is <dir>/<repo name>")
        H.falsy(request_state.is_registered("y"), "the request is closed once the clone has been handed off")
      end)

      -- A trailing separator must not produce a doubled one ----------------
      with_manager(function(manager, env, request_state)
        request_state.register_request("z")
        manager.clone(dir .. "///", "z")
        H.has(
          env.executed[1].cmd,
          dir .. "/telescope.nvim" .. m.suffix,
          m.name .. ": trailing slashes are collapsed, not doubled"
        )
      end)

      -- Windows: a Tab-completed directory comes back with backslashes, and
      -- only `/` is stripped. Documented rather than pinned as a defect --
      -- the Win32 API accepts the mixed separator, so the clone still lands
      -- in the right place; the argv just looks like `E:\repos\/telescope.nvim`.
      -- The directory is declared to exist so the case runs on every OS.
      with_manager(function(manager, env, request_state)
        request_state.register_request("w")
        manager.clone("E:\\repos\\", "w")
        H.has(
          env.executed[1].cmd,
          "E:\\repos\\/telescope.nvim" .. m.suffix,
          m.name .. ": a trailing backslash is not collapsed"
        )
      end, function() return 1 end)

      -- Nothing to clone ---------------------------------------------------
      with_manager(function(manager, env, request_state)
        env.info = nil
        request_state.register_request("n")
        manager.clone(dir, "n")
        H.eq(#env.executed, 0, m.name .. ": with no selected repository nothing is executed")
        H.falsy(request_state.is_registered("n"), "and the request is closed rather than left active")
      end)

      -- A mistyped directory is rejected ----------------------------------
      -- `vim.fn.isdirectory()` answers with 0 or 1, and `0` is truthy in Lua:
      -- the guard compares with 1, or a missing directory went straight to
      -- `git clone` and the "Invalid path" branch was unreachable.
      with_manager(function(manager, env, request_state)
        request_state.register_request("bad")
        manager.clone(dir .. "/definitely-not-there", "bad")

        H.eq(#env.executed, 0, m.name .. ": a non-existent target directory starts no process")
        H.contains(table.concat(env.notes, "\n"), "Invalid path", "and says why")
        H.falsy(request_state.is_request_active("bad"), "without leaving the request active")
      end)

      -- The target directory is left to the tool: git/gh create it (and refuse
      -- a non-empty one), curl/wget write <target>.zip next to it.
      with_manager(function(manager, env, request_state)
        request_state.register_request("ok")
        manager.clone(dir, "ok")
        H.eq(#env.executed, 1, m.name .. ": an existing directory is cloned into")
        H.eq(#env.mkdirs, 0, "and no target directory is created up front")
      end)
    end
  end)
  cleanup()
  if not ok_all then error(err_all, 0) end

  ---------------------------------------------------------------------------
  -- The executor
  ---------------------------------------------------------------------------
  do
    local function with_executor(success, output, fn)
      -- `notes` are dev-mode-gated notify() calls (only level >= WARN reach the
      -- user outside dev mode); `toasts` are info() and toast() calls, shown
      -- always, each tagged with which of the two it was (toast() never echoes).
      local env = { spawned = {}, metrics = {}, notes = {}, toasts = {} }
      H.with_stubs(
        {
          ["reposcope.utils.protection"] = {
            safe_execute_shell_async = function(cmd, on_done)
              env.spawned[#env.spawned + 1] = cmd
              on_done(success, output)
              return { stop = function() end }
            end,
          },
          ["reposcope.utils.metrics"] = {
            record_metrics = function() return true end,
            increase_success = function(_uuid, _name, source, context, _duration, status, url)
              env.metrics[#env.metrics + 1] =
                { kind = "success", source = source, context = context, status = status, url = url }
            end,
            increase_failed = function(_uuid, _name, source, _context, _duration, status, err, url)
              env.metrics[#env.metrics + 1] =
                { kind = "failed", source = source, status = status, err = err, url = url }
            end,
          },
          ["reposcope.utils.debug"] = {
            notify = function(msg) env.notes[#env.notes + 1] = msg end,
            info = function(msg) env.toasts[#env.toasts + 1] = "info: " .. msg end,
            toast = function(msg) env.toasts[#env.toasts + 1] = "toast: " .. msg end,
            is_dev_mode = function() return false end,
            debugf = function() end,
            options = { dev_mode = false },
          },
        },
        { "reposcope.controllers.clone_executor" },
        function() fn(require("reposcope.controllers.clone_executor"), env) end
      )
    end

    with_executor(true, "", function(executor, env)
      executor.execute({ "git", "clone", "https://x/y.git", "/tmp/y" }, "uuid", "y", "https://x/y.git", "/tmp/y")
      H.eq(env.spawned[1][1], "git", "the argv reaches the async runner unchanged")
      H.eq(#env.spawned[1], 4, "with all four elements")
      H.eq(env.metrics[1].kind, "success", "a successful clone is recorded as one")
      H.eq(env.metrics[1].source, "clone", "tagged as a clone")
      H.eq(env.metrics[1].context, "clone_repo", "in the clone context")
      H.eq(env.metrics[1].status, 200, "with a synthetic 200 -- there is no HTTP status here")
      -- Outside dev mode too: a clone runs in the background for seconds to
      -- minutes, and these two toasts are all that shows it started and ended.
      H.contains(env.toasts[1], "Cloning y into /tmp/y", "the start is said outside dev mode, with the target")
      H.contains(env.toasts[2], "cloned successfully: /tmp/y", "and so is the success")
      -- Neither echoes: the clone starts right after the path prompt, and an echo
      -- stacked under the answered prompt line stops the editor at a hit-enter
      -- prompt (reposcope's notify_messages defaults to true).
      H.contains(env.toasts[1], "toast: ", "the start is a toast only, kept out of :messages")
      H.contains(env.toasts[2], "toast: ", "and so is the success")
    end)

    with_executor(true, "", function(executor, env)
      executor.execute({ "curl", "-o", "/tmp/z.zip", "u" }, "uuid", "z", "u", "/tmp/z")
      H.contains(env.toasts[2], "cloned successfully: /tmp/z.zip", "an archive download names the archive")
    end)

    with_executor(false, "fatal: repository not found", function(executor, env)
      executor.execute({ "git", "clone", "https://x/missing.git", "/tmp/m" }, "uuid", "m", "https://x/missing.git")
      H.eq(env.metrics[1].kind, "failed", "a failed clone is recorded as one")
      H.eq(env.metrics[1].status, 500, "with a synthetic 500")
      H.eq(env.metrics[1].err, "fatal: repository not found", "carrying git's own message")
      H.contains(table.concat(env.notes, "\n"), "repository not found", "which the user also sees")
    end)

    -- A failure with no output at all still produces a readable message.
    with_executor(false, nil, function(executor, env)
      executor.execute({ "git", "clone" }, "uuid", "m")
      H.contains(table.concat(env.notes, "\n"), "unknown error", "an empty failure still reads as a sentence")
    end)

    -- The cross-plugin event: fired once per successful git clone, with path and url.
    do
      local seen = {}
      local id = vim.api.nvim_create_autocmd("User", {
        pattern = "ReposcopeCloned",
        callback = function(a) seen[#seen + 1] = a.data end,
      })
      with_executor(
        true,
        "",
        function(executor)
          executor.execute({ "git", "clone", "https://x/y.git", "/tmp/y" }, "uuid", "y", "https://x/y.git", "/tmp/y")
        end
      )
      H.eq(#seen, 1, "a successful clone fires User ReposcopeCloned once")
      H.eq(seen[1] and seen[1].path, "/tmp/y", "with the repository path")
      H.eq(seen[1] and seen[1].url, "https://x/y.git", "and the URL")
      with_executor(
        false,
        "fatal",
        function(executor) executor.execute({ "git", "clone", "u", "/tmp/m" }, "uuid", "m", "u", "/tmp/m") end
      )
      H.eq(#seen, 1, "a failed clone fires nothing")
      with_executor(
        true,
        "",
        function(executor) executor.execute({ "curl", "-o", "/tmp/z.zip", "u" }, "uuid", "z", "u", "/tmp/z") end
      )
      H.eq(#seen, 1, "an archive download is no repository: no event")
      vim.api.nvim_del_autocmd(id)
    end
  end
end
