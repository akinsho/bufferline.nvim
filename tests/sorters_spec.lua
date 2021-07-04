describe("Sorters - ", function()
  it("should sort by ID correctly", function()
    local bufs = { { id = 12 }, { id = 2 }, { id = 3 }, { id = 8 } }
    require("bufferline.sorters").sort_buffers("id", bufs)
    local ids = vim.tbl_map(function(buf)
      return buf.id
    end, bufs)
    assert.same(ids, { 2, 3, 8, 12 })
  end)
end)
