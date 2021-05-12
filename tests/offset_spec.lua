local fn = vim.fn
local api = vim.api
local fmt = string.format

local filetype = "test"

local function open_test_panel(direction, ft)
  direction = direction or "H"
  ft = ft or filetype
  local win = api.nvim_get_current_win()
  vim.cmd(fmt("vnew %s", fn.tempname()))
  local win_id = api.nvim_get_current_win()
  vim.cmd(fmt("wincmd %s", direction))
  local new_ft = fmt("%s_%d", ft, win_id)
  vim.cmd(fmt("setfiletype %s", new_ft))
  api.nvim_win_set_width(api.nvim_get_current_win(), 20)
  api.nvim_set_current_win(win)
  vim.wo[win_id].winfixwidth = true
  return new_ft, win_id
end

local function remove_highlight(str)
  return str:gsub("%%#Normal#", "")
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
    assert.equal(20, size)
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
    assert.equal(20, size)
    assert.equal(right, "")
    assert.is_truthy(left:match("    Test buffer    "))
  end)

  it("should add the offset to the correct side", function()
    local ft = open_test_panel("L")
    local size, left, right = offsets.get({
      highlights = {},
      options = {
        offsets = { { filetype = ft, text = "Test buffer" } },
      },
    })

    assert.equal(20, size)
    assert.is_truthy(right:match("Test buffer"))
    assert.equal("", left)
  end)

  it("should correctly truncate offset text", function()
    local ft = open_test_panel()
    local size, left, right = offsets.get({
      highlights = {},
      options = {
        offsets = { { filetype = ft, text = "Test buffer buffer buffer buffer" } },
      },
    })

    assert.equal(20, size)
    assert.equal("", right)
    assert.is_equal(" Test buffer buffer ", remove_highlight(left))
  end)

  it("should allow left and right offsets", function()
    local ft1 = open_test_panel()
    local ft2 = open_test_panel("L")
    local size, left, right = offsets.get({
      highlights = {},
      options = {
        offsets = { { filetype = ft1, text = "Left" }, { filetype = ft2, text = "Right" } },
      },
    })

    assert.is_truthy(left:match("Left"))
    assert.is_truthy(right:match("Right"))
    assert.equal(40, size)
  end)

  it('should allow setting some extra padding', function()
    local ft1 = open_test_panel()
    local size, left, _ = offsets.get({
      highlights = {},
      options = {
        offsets = { { filetype = ft1, text = "Left", padding = 5 } },
      },
    })

    assert.is_truthy(left:match("Left"))
    assert.equal(25, size)
  end)

  it('should align the text to the right if specified', function()
    local ft1 = open_test_panel()
    local text = "Text"
    local size, left, _ = offsets.get({
      highlights = {},
      options = {
        offsets = { { filetype = ft1, text = text, text_align = "right" } },
      },
    })

    assert.equal(20, size)
    assert.equal(remove_highlight(left), string.rep(" ", size - (#text + 1))..text.." ")
  end)

  it('should align the text to the left if specified', function()
    local text = "Text"
    local ft1 = open_test_panel()
    local size, left, _ = offsets.get({
      highlights = {},
      options = {
        offsets = { { filetype = ft1, text = text, text_align = "left" } },
      },
    })

    assert.equal(20, size)
    assert.equal(remove_highlight(left), " "..text..string.rep(" ", size - (#text + 1)))
  end)
end)
