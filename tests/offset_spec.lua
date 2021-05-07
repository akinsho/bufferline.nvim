local api = vim.api
local fmt = string.format

local filetype = "test"

local function open_test_panel(ft, direction)
  direction = direction or "H"
  ft = ft or filetype
  vim.cmd("vnew file")
  vim.cmd(fmt("wincmd %s", direction))
  local new_ft = fmt("%s_%d", ft, vim.fn.win_getid())
  vim.cmd(fmt("setfiletype %s", new_ft))
  api.nvim_win_set_width(0, 20)
  return new_ft
end

describe("Offset tests:", function()
  local offsets = require("bufferline.offset")
  vim.o.hidden = true
  vim.o.swapfile = false

  after_each(function()
    vim.cmd("silent only")
    --- FIXME: open a new tab so that new windows get assigned each time
    vim.cmd("tabnew")
  end)

  it("should not trigger if no offsets are specified", function()
    local size, left, right = offsets.get({ options = {}, highlights = {} })
    assert.equal(0, size)
    assert.equal(left, "")
    assert.equal(right, "")
  end)

  it("should create an offset if a compatible panel if open", function()
    local ft = open_test_panel()
    local opts = {
      highlights = {},
      options = { offsets = { { filetype = ft } } },
    }
    local size, left, right = offsets.get(opts)
    assert.equal(21, size)
    assert.equal(right, "")
    assert.is_truthy(left:match(" "))
  end)

  it("should include padded text if text is specified", function()
    local ft = open_test_panel()
    local opts = {
      highlights = {},
      options = { offsets = { { filetype = ft, text = "Test buffer" } } },
    }
    local size, left, right = offsets.get(opts)
    assert.equal(21, size)
    assert.equal(right, "")
    assert.is_truthy(left:match("    Test buffer    "))
  end)

  it("should add the offset to the correct side", function()
    local ft = open_test_panel(nil, "L")
    local size, left, right = offsets.get({
      highlights = {},
      options = {
        offsets = { { filetype = ft, text = "Test buffer" } },
      },
    })

    assert.equal(21, size)
    assert.is_truthy(right:match("Test buffer"))
    assert.equal("", left)
  end)
end)
