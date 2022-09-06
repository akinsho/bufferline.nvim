describe("Custom areas -", function()
  local areas = require("bufferline.custom_area")

  local bufferline

  before_each(function()
    package.loaded["bufferline"] = nil
    bufferline = require("bufferline")
  end)

  it("should generate a custom area from config", function()
    bufferline.setup({
      options = {
        custom_areas = {
          left = function() return { { text = "test", fg = "red", bg = "black" } } end,
        },
      },
    })
    local size, left = areas.get()
    assert.is_truthy(left)
    assert.is_equal(4, size)
    assert.is_equal("%#BufferLineLeftCustomAreaText1#test", left)
  end)

  it("should handle sides correctly", function()
    bufferline.setup({
      highlights = {
        fill = {
          fg = "#000000",
        },
      },
      options = {
        custom_areas = {
          left = function() return { { text = "test", fg = "red", bg = "black" } } end,
          right = function() return { { text = "test1", italic = true } } end,
        },
      },
    })
    local size, left, right = areas.get()
    assert.is_equal(9, size)

    assert.is_truthy(left)
    assert.is_equal("%#BufferLineLeftCustomAreaText1#test", left)

    assert.is_truthy(right)
    assert.is_equal("%#BufferLineRightCustomAreaText1#test1", right)
  end)

  it("should handle user errors gracefully", function()
    bufferline.setup({
      options = {
        custom_areas = {
          left = function() return { { text = { "test" }, fg = "red", bg = "black" } } end,
          right = function() error("This failed mysteriously") end,
        },
      },
    })
    local size, left, right = areas.get()
    assert.is_equal(0, size)
    assert.is_equal("", left)
    assert.is_equal("", right)
  end)
end)
