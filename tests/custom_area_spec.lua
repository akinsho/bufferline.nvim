describe('Custom areas -', function()
  local areas = require("bufferline.custom_area")
  it('should generate a custom area from config', function()
    local size, left = areas.get({
      options = {
        custom_areas = {
          left = function ()
            return {{text = "test", guifg = "red", guibg = "black"}}
          end
        }
      }
    })
    assert.is_truthy(left)
    assert.is_equal(4, size)
    assert.is_equal('%#BufferLineLeftCustomAreaText1#test', left)
  end)

  it('should handle sides correctly', function()
    local size, left, right = areas.get({
      options = {
        custom_areas = {
          left = function ()
            return {{text = "test", guifg = "red", guibg = "black"}}
          end,
          right = function ()
            return {{text = "test1", gui = "italic"}}
          end
        }
      }
    })
    assert.is_equal(9, size)

    assert.is_truthy(left)
    assert.is_equal('%#BufferLineLeftCustomAreaText1#test', left)

    assert.is_truthy(right)
    assert.is_equal('%#BufferLineRightCustomAreaText1#test1', right)
  end)
end)
