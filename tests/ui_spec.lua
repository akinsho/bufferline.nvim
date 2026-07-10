---@diagnostic disable: need-check-nil
local utils = require("tests.utils")
local constants = require("bufferline.constants")
local MockBuffer = utils.MockBuffer

describe("UI Tests", function()
  local ui ---@module 'bufferline.ui'
  local config ---@module 'bufferline.config'
  local state ---@module 'bufferline.state'

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
      config.setup({ options = { indicator = { style = "underline" } } })
      config.apply()
      local result = ui.add_indicator({ tab = MockBuffer:new({}), highlights = {} })
      assert.is_truthy(result)
      assert.is_equal(result.text, " ")
    end)

    it("should render an indicator if the style is icon", function()
      config.setup({ highlights = { indicator_selected = { hl_group = "IndicatorSelected" } } })
      config.apply()
      local result = ui.add_indicator({ tab = MockBuffer:new({}), highlights = {} })
      assert.is_truthy(result)
      assert.is_equal(result.text, constants.indicator)
    end)

    it("should not truncate the tab name if disabled", function()
      config.setup({ options = { truncate_names = false } })
      config.apply()
      local segment = ui.get_name({
        tab = { name = "a_very_very_very_very_long_name_that_i_use.js", icon = "x" },
        current_highlights = {},
      })
      assert.is_equal(segment.text, "a_very_very_very_very_long_name_that_i_use.js")
    end)

    it("should truncate the tab name if enabled", function()
      config.setup({ options = { truncate_names = true } })
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
      config.setup({ options = { hover = { reveal = { "close" } } } })
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
      ui.on_hover_over(0, { cursor_pos = 12 })
      assert.is_truthy(state.hovered)
      assert.equal(state.hovered.id, 2)
    end)

    it("should remove the hovered item on mouse out", function()
      config.setup({ options = { hover = { reveal = { "close" } } } })
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
      config.setup({ options = { hover = { enabled = true, reveal = { "close" } } } })
      config.apply()
      local buf = MockBuffer:new({ id = 1, name = "file.txt", _is_current = false })
      local el = ui.element({}, buf)
      local segment = ui.to_tabline_str(el:component(1))
      assert.is_falsy(segment:match(config.options.buffer_close_icon))
    end)

    it("should render a close icon if hovered", function()
      config.setup({ options = { hover = { enabled = true, reveal = { "close" } } } })
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
      ui.on_hover_over(0, { cursor_pos = 5 })
      assert.equal(state.hovered, buf1)
      local b1 = ui.element({}, buf1)
      local b2 = ui.element({}, buf2)
      local s1 = ui.to_tabline_str(b1:component(1))
      assert.is_truthy(s1:match(config.options.buffer_close_icon))
      local s2 = ui.to_tabline_str(b2:component(1))
      assert.is_falsy(s2:match(config.options.buffer_close_icon))
    end)
  end)

  describe("Mouse scroll - ", function()
    local function flat_items()
      return {
        { id = 1, length = 10, component = function() return {} end },
        { id = 2, length = 10, component = function() return {} end },
        { id = 3, length = 10, component = function() return {} end },
        { id = 4, length = 10, component = function() return {} end },
      }
    end

    it("should clamp the scroll pivot so the last page stays flush against the right edge", function()
      -- suffix {3,4} = 20 fits in 25, {2,3,4} = 30 does not, so the furthest pivot is 3
      assert.equal(3, ui.max_scroll_pivot(flat_items(), 25))
    end)

    it("should build the visible window from the pivot and count the hidden markers", function()
      local marker = { left_count = 0, right_count = 0, left_element_size = 0, right_element_size = 0 }
      local _, m, visible = ui.scroll_window(flat_items(), 2, 25, marker)
      assert.equal(2, #visible)
      assert.equal(2, visible[1].id)
      assert.equal(3, visible[2].id)
      assert.equal(1, m.left_count)
      assert.equal(1, m.right_count)
    end)

    it("should update, capture and clamp the scroll offset on the handler", function()
      local scroll = utils.reload("bufferline.scroll")
      config.setup({ options = { mouse_scroll = { enabled = true, step = 1 } } })
      config.apply()
      state.set({
        components = flat_items(),
        visible_components = flat_items(),
        current_element_index = 1,
        scroll_pivot_hint = 0,
      })

      scroll.on_scroll(1)
      scroll.on_scroll(1)
      assert.equal(2, state.scroll_offset)
      -- the active id and list size are captured once, when scroll mode is entered
      assert.equal(1, state.scroll_current_id)
      assert.equal(4, state.scroll_count)

      -- scrolling back past the start is clamped to 0 (the upper clamp is render-side)
      scroll.on_scroll(-5)
      assert.equal(0, state.scroll_offset)
    end)
  end)
end)
