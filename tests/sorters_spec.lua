describe("Sorters - ", function()
  local sorters = require("bufferline.sorters")
  local bufferline

  before_each(function()
    package.loaded["bufferline"] = nil
    bufferline = require("bufferline")
  end)

  it("should sort by ID correctly", function()
    bufferline.setup({ options = { sort_by = "id" } })
    local bufs = { { id = 12 }, { id = 2 }, { id = 3 }, { id = 8 } }
    sorters.sort(bufs)
    local ids = vim.tbl_map(function(buf)
      return buf.id
    end, bufs)
    assert.same(ids, { 2, 3, 8, 12 })
  end)

  it("should sort by components correctly", function()
    bufferline.setup({ options = { sort_by = "tabs" } })
    vim.cmd("e file1.txt")
    vim.cmd("tabnew file2.txt")
    vim.cmd("tabnew file3.txt")
    vim.cmd("bunload file2.txt")
    local bufs = vim.tbl_map(function(id)
      return { id = id }
    end, vim.api.nvim_list_bufs())

    sorters.sort(bufs)

    local buf_names = vim.tbl_map(function(buf)
      return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf.id), ":p:t")
    end, bufs)
    assert.same({ "file1.txt", "file3.txt", "file2.txt" }, buf_names)
  end)
end)
