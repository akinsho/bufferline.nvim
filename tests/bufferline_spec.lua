local api = vim.api
local fn = vim.fn

_G.__TEST = true
local bufferline = require("bufferline")

describe("Bufferline tests:", function()
  bufferline.setup()

  before_each(function()
  end)

  after_each(function()
  end)

  describe("render buffer - ", function()
    it("should create corresponding buffers in state", function()
      local tabline = nvim_bufferline()
      assert.truthy(tabline)
      assert.is.equal(vim.tbl_count(bufferline._state.buffers), 1)
    end)
  end)
end)
