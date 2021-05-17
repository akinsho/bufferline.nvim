local api = vim.api
local fmt = string.format
_G.__TEST = true

describe("Sorters -", function()
  -- local Buffer = require("bufferline.buffers").Buffer
  -- local get_buffers = bufferline.get_buffers_by_mode

  it("should sort buffers by the most recently used", function()
    local bufferline = require("bufferline")
    bufferline.setup({
      options = {
        sort_by = "recent"
      }
    })
    vim.cmd("e file1.txt")
    local buf1 = api.nvim_get_current_buf()
    vim.cmd("e file2.txt")
    local buf2 = api.nvim_get_current_buf()
    vim.cmd("e file3.txt")
    local buf3 = api.nvim_get_current_buf()

    vim.cmd(fmt("b %d", buf1))
    vim.cmd(fmt("b %d", buf3))

    local buffers = bufferline._state().buffers
    print("buffers: " .. vim.inspect(buffers))

    assert.equal(buf1, buffers[1].id)
    assert.equal(buf3, buffers[2].id)
    assert.equal(buf2, buffers[3].id)
  end)
end)
