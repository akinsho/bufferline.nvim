describe("UI Tests", function()
  local ui = require("bufferline.ui")
  local config = require("bufferline.config")
  local constants = require("bufferline.constants")
  local MockBuffer = require("tests.utils").MockBuffer

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
  end)
end)
