describe("UI Tests", function()
  local ui = require("bufferline.ui")
  describe("Render tabline", function()
    it("should convert a list of segments to a tabline string", function()
      local components = {
        { text = "|", highlight = "BufferlineIndicatorSelected" },
        { text = " ", highlight = "BufferlineSelected" },
        { text = "buffer.txt", highlight = "BufferlineSelected", attr = { extends = {{id = "example"}} } },
        ui.set_id({ text = " ", highlight = "BufferlineExample" }, "example"),
        { text = "x", highlight = "BufferlineCloseButton" },
      }
      local str = ui.to_tabline_str(components)
      assert.equal(
        "%#BufferlineIndicatorSelected#|%#BufferlineSelected# %#BufferlineSelected#buffer.txt%#BufferlineSelected# %#BufferlineCloseButton#x",
        str
      )
    end)
  end)
end)
