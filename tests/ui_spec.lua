---@diagnostic disable: need-check-nil
local utils = require("tests.utils")
local constants = require("bufferline.constants")
local MockBuffer = utils.MockBuffer

describe("UI Tests", function()
  local ui
  local config
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
  end)
end)
