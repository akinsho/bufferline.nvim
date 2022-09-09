local fn = vim.fn
local api = vim.api
local fmt = string.format

local constants = require("bufferline.constants")

local filetype = "test"

local function open_test_panel(direction, ft, on_open)
  direction = direction or "H"
  ft = ft or filetype
  local win = api.nvim_get_current_win()
  vim.cmd(fmt("vnew %s", fn.tempname()))
  local win_id = api.nvim_get_current_win()
  vim.cmd(fmt("wincmd %s", direction))
  local new_ft = fmt("%s_%d", ft, win_id)
  vim.cmd(fmt("setfiletype %s", new_ft))
  api.nvim_win_set_width(api.nvim_get_current_win(), 20)
  if on_open then on_open() end
  api.nvim_set_current_win(win)
  vim.wo[win_id].winfixwidth = true
  return new_ft, win_id
end

local function remove_highlight(str) return str:gsub("%%#Normal#", "") end

describe("Offset tests:", function()
  local bufferline
  local offsets = require("bufferline.offset")
  vim.o.hidden = true
  vim.o.swapfile = false

  before_each(function()
    package.loaded["bufferline"] = nil
    bufferline = require("bufferline")
  end)

  after_each(function()
    vim.cmd("silent only")
    --- FIXME: open a new tab so that new windows get assigned each time
    vim.cmd("tabnew")
  end)

  it("should not trigger if no offsets are specified", function()
    bufferline.setup({ options = {}, highlights = {} })
    local data = offsets.get()
    assert.equal(0, data.total_size)
    assert.equal(data.left, "")
    assert.equal(data.right, "")
  end)

  it("should create an offset if a compatible panel if open", function()
    local ft = open_test_panel()
    local opts = {
      highlights = {},
      options = { offsets = { { filetype = ft } } },
    }
    bufferline.setup(opts)
    local data = offsets.get()
    assert.equal(20, data.total_size)
    assert.equal(data.right, "")
    assert.is_truthy(data.left:match(" "))
  end)

  it("should include padded text if text is specified", function()
    local ft = open_test_panel()
    bufferline.setup({
      highlights = {},
      options = { offsets = { { filetype = ft, text = "Test buffer" } } },
    })
    local data = offsets.get()
    assert.equal(20, data.total_size)
    assert.equal(data.right, "")
    assert.is_truthy(data.left:match("    Test buffer    "))
  end)

  it("should add the offset to the correct side", function()
    local ft = open_test_panel("L")
    bufferline.setup({
      highlights = {},
      options = {
        offsets = { { filetype = ft, text = "Test buffer" } },
      },
    })
    local data = offsets.get()

    assert.equal(20, data.total_size)
    assert.is_truthy(data.right:match("Test buffer"))
    assert.equal("", data.left)
  end)

  it("should correctly truncate offset text", function()
    local ft = open_test_panel()
    bufferline.setup({
      highlights = {},
      options = {
        offsets = { { filetype = ft, text = "Test buffer buffer buffer buffer" } },
      },
    })
    local data = offsets.get()

    assert.equal(20, data.total_size)
    assert.equal("", data.right)
    assert.is_equal(fmt(" Test buffer buffe%s ", constants.ELLIPSIS), remove_highlight(data.left))
  end)

  it("should allow left and right offsets", function()
    local ft1 = open_test_panel()
    local ft2 = open_test_panel("L")
    bufferline.setup({
      highlights = {},
      options = {
        offsets = { { filetype = ft1, text = "Left" }, { filetype = ft2, text = "Right" } },
      },
    })
    local data = offsets.get()

    assert.is_truthy(data.left:match("Left"))
    assert.is_truthy(data.right:match("Right"))
    assert.equal(40, data.total_size)
  end)

  it("should allow setting some extra padding", function()
    local ft1 = open_test_panel()
    bufferline.setup({
      highlights = {},
      options = {
        offsets = { { filetype = ft1, text = "Left", padding = 5 } },
      },
    })
    local data = offsets.get()

    assert.is_truthy(data.left:match("Left"))
    assert.equal(25, data.total_size)
  end)

  it("should align the text to the right if specified", function()
    local ft1 = open_test_panel()
    local text = "Text"
    bufferline.setup({
      highlights = {},
      options = {
        offsets = { { filetype = ft1, text = text, text_align = "right" } },
      },
    })
    local data = offsets.get()

    assert.equal(20, data.total_size)
    assert.equal(remove_highlight(data.left), string.rep(" ", data.total_size - (#text + 1)) .. text .. " ")
  end)

  it("should align the text to the left if specified", function()
    local text = "Text"
    local ft1 = open_test_panel()
    bufferline.setup({
      highlights = {},
      options = {
        offsets = { { filetype = ft1, text = text, text_align = "left" } },
      },
    })
    local data = offsets.get()

    assert.equal(20, data.total_size)
    assert.equal(remove_highlight(data.left), " " .. text .. string.rep(" ", data.total_size - (#text + 1)))
  end)

  it("should handle a vertical panel with horizontal splits inside it", function()
    local ft = open_test_panel("H", filetype, function()
      -- add some child horizontal splits to the panel
      vim.cmd("split")
      vim.cmd("split")
    end)
    bufferline.setup({
      highlights = {},
      options = { offsets = { { filetype = ft } } },
    })
    local data = offsets.get()
    assert.equal(20, data.total_size)
    assert.equal(data.right, "")
    assert.is_truthy(data.left:match(" "))
  end)
end)
