-- TESTS/config_spec.lua — reposcope.config: what `setup()` does to the option
-- table.

return function(H)
  local config = require("reposcope.config")
  local DEFAULTS = require("reposcope.config.DEFAULTS")

  -- Exercise every boolean and number option that actually exists, so this
  -- spec does not have to be edited every time the option surface grows. Both
  -- kinds can be changed to a value of the same type, which setup() accepts
  -- for any of them (a string would be rejected by the options that are
  -- validated). One picked key was not enough: which one `pairs` returned
  -- first differs between hosts, and a `true` default that setup() validates
  -- only failed on Windows once. Skips the three token fields: like
  -- `clone.std_dir`, config/init.lua re-resolves them from the environment
  -- right after requiring DEFAULTS (LUA-06), so config.options[key] can
  -- legitimately differ from DEFAULTS[key] for those -- and on a machine with
  -- GITHUB_TOKEN set, it does.
  local names = {}
  for k, v in pairs(DEFAULTS) do
    if type(v) == "boolean" or type(v) == "number" then names[#names + 1] = k end
  end
  table.sort(names)
  H.ok(#names > 0, "DEFAULTS has at least one boolean or number option to test against")

  for _, k in ipairs(names) do
    local original = DEFAULTS[k]

    -- Defaults ----------------------------------------------------------------
    config.setup({})
    H.eq(config.options[k], original, k .. ": the option table starts at the defaults")

    -- A user value wins -------------------------------------------------------
    -- Not an `and/or` chain: `not original` is false for a `true` default,
    -- which would fall through to the next branch.
    local changed
    if type(original) == "boolean" then
      changed = not original
    else
      changed = original + 1
    end
    config.setup({ [k] = changed })
    H.eq(config.options[k], changed, k .. ": a user value wins")
    H.eq(DEFAULTS[k], original, k .. ": and DEFAULTS itself is not mutated")

    -- setup() rebuilds from defaults -------------------------------------------
    -- The merge target is a fresh table on every call:
    --
    --   M.options = vim.tbl_deep_extend("force", {}, defaults, opts)
    --
    -- so a later call cannot inherit anything an earlier one set -- `setup({})`
    -- is the documented way to get back to the defaults, and it actually does.
    config.setup({})
    H.eq(config.options[k], original, k .. ": setup({}) resets to the defaults")

    config.setup({ [k] = changed })
    H.eq(config.options[k], changed, k .. ": a later setup() call still applies its own value")

    config.setup({ [k] = original })
    H.eq(config.options[k], original, k .. ": restoring takes an explicit value")
  end
  local key, original = names[1], DEFAULTS[names[1]]

  -- Invalid input -------------------------------------------------------------
  -- A non-table is reported and ignored rather than raising: setup() runs from
  -- a user's config, where a crash costs them the rest of their startup.
  local ok = pcall(config.setup, "not a table")
  H.ok(ok, "a non-table argument does not raise")
  H.eq(config.options[key], original, "and changes nothing")

  -- A wrong type is reported and falls back to the default.
  config.setup({ results_limit = "many" })
  H.eq(config.options.results_limit, DEFAULTS.results_limit, "a wrong-typed option falls back to its default")
  config.setup({})

  -- The options share no table with the defaults ------------------------------
  -- A write into a section the user never overrode must not reach the defaults
  -- the next setup() starts from.
  local baseline = vim.deepcopy(config.options.prompt_keymaps)
  config.setup({})
  config.options.prompt_keymaps.confirm = "<C-y>"
  config.options.prompt_keymaps.focus_next[1] = "<C-y>"
  config.options.clone.type = "wget"
  config.setup({})
  H.eq(config.options.prompt_keymaps.confirm, baseline.confirm, "a scalar written into a section is gone after setup()")
  H.eq(
    config.options.prompt_keymaps.focus_next[1],
    baseline.focus_next[1],
    "a list element written into a section is gone"
  )
  H.eq(config.options.clone.type, DEFAULTS.clone.type, "a nested option written is gone")
  H.eq(DEFAULTS.prompt_keymaps.confirm, baseline.confirm, "and the DEFAULTS module was never touched")

  local given = { prompt_keymaps = { focus_next = { "<C-j>" } } }
  config.setup(given)
  config.options.prompt_keymaps.focus_next[1] = "<C-k>"
  H.eq(given.prompt_keymaps.focus_next[1], "<C-j>", "the caller's opts are not shared with the options")
  config.setup({})
end
