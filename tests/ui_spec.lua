---@diagnostic disable: need-check-nil
local utils = require("tests.utils")
local constants = require("bufferline.constants")
local MockBuffer = utils.MockBuffer

describe("UI Tests", function()
  ---@module 'bufferline.ui'
  local ui
  ---@module 'bufferline.config'
  local config
  ---@module 'bufferline.state'
  local state

  before_each(function()
    ui = utils.reload("bufferline.ui")
    config = utils.reload("bufferline.config")
    state = utils.reload("bufferline.state")
  end)

  describe("Render tabline", function()
    it("should convert a list of segments to a tabline string", function()
      local components = {
        { text = "|", highlight = "BufferlineIndicatorSelected" },
        { text = " ", highlight = "BufferlineSelected" },
        {
          text = "buffer.txt",
          highlight = "BufferlineSelected",
          attr = { extends = { { id = "example" } } },
        },
        ui.set_id({ text = " ", highlight = "BufferlineExample" }, "example"),
        { text = "x", highlight = "BufferlineCloseButton" },
      }
      local str = ui.to_tabline_str(components)
      assert.equal(
        "%#BufferlineIndicatorSelected#|%#BufferlineSelected# %#BufferlineSelected#buffer.txt%#BufferlineSelected# %#BufferlineCloseButton#x",
        str
      )
    end)

    it("should not render an indicator if the style is underline", function()
      config.set({ options = { indicator = { style = "underline" } } })
      config.apply()
      local result = ui.add_indicator({ tab = MockBuffer:new({}), highlights = {} })
      assert.is_truthy(result)
      assert.is_equal(result.text, " ")
    end)

    it("should render an indicator if the style is icon", function()
      config.set({ highlights = { indicator_selected = { hl_group = "IndicatorSelected" } } })
      config.apply()
      local result = ui.add_indicator({ tab = MockBuffer:new({}), highlights = {} })
      assert.is_truthy(result)
      assert.is_equal(result.text, constants.indicator)
    end)

    it("should not truncate the tab name if disabled", function()
      config.set({ options = { truncate_names = false } })
      config.apply()
      local segment = ui.get_name({
        tab = { name = "a_very_very_very_very_long_name_that_i_use.js", icon = "x" },
        current_highlights = {},
      })
      assert.is_equal(segment.text, "a_very_very_very_very_long_name_that_i_use.js")
    end)

    it("should truncate the tab name if enabled", function()
      config.set({ options = { truncate_names = true } })
      config.apply()
      local segment = ui.get_name({
        tab = { name = "a_very_very_very_very_long_name_that_i_use.js", icon = "x" },
        current_highlights = {},
      })
      assert.is_equal(segment.text, "a_very_very_very_…")
    end)
  end)

  describe("Hover events - ", function()
    it("should set the state with on hover of a tab", function()
      config.set({ options = { hover = { reveal = { "close" } } } })
      config.apply()
      state.set({
        visible_components = {
          {
            id = 1,
            name = "file-1.text",
            length = 10,
          },
          {
            id = 2,
            name = "file-2.text",
            length = 15,
          },
        },
      })
      ui.on_hover_over(_, { cursor_pos = 12 })
      assert.is_truthy(state.hovered)
      assert.equal(state.hovered.id, 2)
    end)

    it("should remove the hovered item on mouse out", function()
      config.set({ options = { hover = { reveal = { "close" } } } })
      config.apply()
      state.set({
        visible_components = {
          {
            id = 1,
            name = "file-1.text",
            length = 10,
          },
          {
            id = 2,
            name = "file-2.text",
            length = 15,
          },
        },
        hovered = {
          id = 2,
          name = "file-2.text",
          length = 15,
        },
      })
      ui.on_hover_out()
      assert.is_falsy(state.hovered)
    end)

    it("should not render a close icon if not hovered", function()
      config.set({ options = { hover = { enabled = true, reveal = { "close" } } } })
      config.apply()
      local buf = MockBuffer:new({ id = 1, name = "file.txt", _is_current = false })
      local el = ui.element({}, buf)
      local segment = ui.to_tabline_str(el:component(1))
      assert.is_falsy(segment:match(config.options.buffer_close_icon))
    end)

    it("should render a close icon if hovered", function()
      config.set({ options = { hover = { enabled = true, reveal = { "close" } } } })
      config.apply()
      local buf1 = MockBuffer:new({ id = 1, name = "file.txt", length = 10, _is_current = true })
      local buf2 = MockBuffer:new({
        id = 2,
        name = "next.txt",
        length = 10,
        _is_current = false,
        _is_visible = true,
      })
      state.set({ visible_components = { buf1, buf2 } })
      ui.on_hover_over(_, { cursor_pos = 5 })
      assert.equal(state.hovered, buf1)
      local b1 = ui.element({}, buf1)
      local b2 = ui.element({}, buf2)
      local s1 = ui.to_tabline_str(b1:component(1))
      assert.is_truthy(s1:match(config.options.buffer_close_icon))
      local s2 = ui.to_tabline_str(b2:component(1))
      assert.is_falsy(s2:match(config.options.buffer_close_icon))
    end)
  end)
end)
