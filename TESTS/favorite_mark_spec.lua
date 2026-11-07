-- TESTS/favorite_mark_spec.lua — reposcope.ui.list.list_window.mark_favorites.
--
-- A favorited row of the list shows `favorite_mark` in front of it, drawn as
-- inline virtual text: the row's text stays `owner/name: description`, which
-- is what the selection is parsed from.

return function(H)
  local ui_state = require("reposcope.state.ui.ui_state")
  local config = require("reposcope.config")
  local saved_list = ui_state.buffers.list
  local saved_mark = config.options.favorite_mark

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "alice/spotlight: Search", "bob/lantern: A lamp", "carol/x: y" })
  ui_state.buffers.list = buf

  local function marks()
    local out = {}
    local ns = vim.api.nvim_create_namespace("reposcope.list.favorites")
    for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })) do
      out[#out + 1] = { row = m[2], text = m[4].virt_text[1][1], pos = m[4].virt_text_pos }
    end
    return out
  end

  local ok, err = pcall(function()
    H.with_stubs({
      ["reposcope.state.favorites_state"] = {
        is_favorite = function(owner, name) return owner == "bob" and name == "lantern" end,
      },
    }, { "reposcope.ui.list.list_window" }, function()
      local list_window = require("reposcope.ui.list.list_window")

      config.options.favorite_mark = nil
      H.eq(require("reposcope.config.DEFAULTS").favorite_mark, "\u{2605} ", "the default mark is a star")
      config.options.favorite_mark = "\u{2605} "
      list_window.mark_favorites()
      local got = marks()
      H.eq(#got, 1, "only the favorited row is marked")
      H.eq(got[1].row, 1, "the row of bob/lantern")
      H.eq(got[1].text, "\u{2605} ", "with the mark")
      H.eq(got[1].pos, "inline", "in front of the row, as virtual text")
      H.eq(vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1], "bob/lantern: A lamp", "the row's text is unchanged")

      list_window.mark_favorites()
      H.eq(#marks(), 1, "drawing again replaces the marks, it does not add to them")

      config.options.favorite_mark = ""
      list_window.mark_favorites()
      H.eq(#marks(), 0, "an empty favorite_mark hides it")
    end)
  end)

  config.options.favorite_mark = saved_mark
  ui_state.buffers.list = saved_list
  vim.api.nvim_buf_delete(buf, { force = true })
  if not ok then error(err, 0) end
end
