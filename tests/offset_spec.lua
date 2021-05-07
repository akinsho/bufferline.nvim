local fmt = string.format

local filetype = "test"

local function open_test_panel(ft, direction)
  direction = direction or "H"
  ft = ft or filetype
  vim.cmd("vsplit")
  vim.cmd(fmt("wincmd %s", direction))
  vim.cmd("vertical resize 20")
  vim.cmd(fmt("setfiletype %s", ft))
end

describe("Offset tests:", function()
  local offsets = require("bufferline.offset")
  it("should not trigger if no offsets are specified", function()
    local size, left, right = offsets.get({ options = {}, highlights = {} })
    assert.equal(0, size)
    assert.equal(left, "")
    assert.equal(right, "")
  end)

  it("should create an offset if a compatible panel if open", function()
    open_test_panel()
    local opts = {
      highlights = {},
      options = { offsets = { { filetype = filetype } } },
    }
    local size, left, right = offsets.get(opts)
    assert.equal(21, size)
    assert.equal(right, "")
    assert.is_truthy(left:match(" "))
  end)

  it("should include padded text if text is specified", function()
    open_test_panel()
    local opts = {
      highlights = {},
      options = { offsets = { { filetype = filetype, text = "Test buffer" } } },
    }
    local size, left, right = offsets.get(opts)
    assert.equal(21, size)
    assert.equal(right, "")
    assert.is_truthy(left:match("    Test buffer    "))
  end)

  it("should add the offset to the correct side", function()
    open_test_panel(nil, "L")
    local opts = {
      highlights = {},
      options = { offsets = { { filetype = filetype, text = "Test buffer" } } },
    }
    local size, left, right = offsets.get(opts)
    assert.equal(21, size)
    assert.equal(left, "")
    assert.is_truthy(right:match("Test buffer"))
  end)
end)
