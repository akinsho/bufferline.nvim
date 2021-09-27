describe("Sorters - ", function()
  local sorters = require("bufferline.sorters")

  it("should sort by ID correctly", function()
    local bufs = { { id = 12 }, { id = 2 }, { id = 3 }, { id = 8 } }
    sorters.sort_buffers("id", bufs)
    local ids = vim.tbl_map(function(buf)
      return buf.id
    end, bufs)
    assert.same(ids, { 2, 3, 8, 12 })
  end)

  it("should sort by components correctly", function()
    vim.cmd("e file1.txt")
    vim.cmd("tabnew file2.txt")
    vim.cmd("tabnew file3.txt")
    vim.cmd("bunload file2.txt")
    local bufs = vim.tbl_map(function(id)
      return { id = id }
    end, vim.api.nvim_list_bufs())

    sorters.sort_buffers("tabs", bufs)

    local buf_names = vim.tbl_map(function(buf)
      return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf.id), ":p:t")
    end, bufs)
    assert.same({ "file1.txt", "file3.txt", "file2.txt" }, buf_names)
  end)
end)
