_G.__TEST = true
local bufferline = require("bufferline")

describe("Bufferline tests:", function()

  describe("render buffer - ", function()
    it("should create corresponding buffers in state", function()
      bufferline.setup()
      local tabline = nvim_bufferline()
      assert.truthy(tabline)
      assert.is.equal(vim.tbl_count(bufferline._state.buffers), 1)
    end)

    it('should allow configuring the indicator icon', function()
      local icon = "R"
      bufferline.setup {
        options = {
          indicator_icon = icon,
        }
      }
      local tabline = nvim_bufferline()
      assert.truthy(tabline)
      assert.is_truthy(tabline:match(icon))
    end)
  end)
end)
