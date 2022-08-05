describe("Sorters - ", function()
  local sorters = require("bufferline.sorters")
  ---@module "bufferline"
  local bufferline
  ---@type BufferlineState
  local state

  before_each(function()
    package.loaded["bufferline"] = nil
    package.loaded["bufferline.state"] = nil
    bufferline = require("bufferline")
    package.loaded["bufferline.commands"] = nil
    state = require("bufferline.state")
  end)

  after_each(function() vim.cmd("silent %bwipeout!") end)

  it("should always return a list", function()
    bufferline.setup({ options = { sort_by = "none" } })
    local bufs = { { id = 12 }, { id = 2 }, { id = 3 }, { id = 8 } }
    local list = sorters.sort(bufs)
    assert.is_true(vim.tbl_islist(list))
  end)

  it("should return an unsorted list sort is none", function()
    bufferline.setup({ options = { sort_by = "none" } })
    local bufs = { { id = 12 }, { id = 2 }, { id = 3 }, { id = 8 } }
    local list = sorters.sort(bufs)
    assert.is_true(vim.tbl_islist(list))
    local ids = vim.tbl_map(function(buf) return buf.id end, list)
    assert.same(ids, { 12, 2, 3, 8 })
  end)

  it("should sort by ID correctly", function()
    bufferline.setup({ options = { sort_by = "id" } })
    local bufs = { { id = 12 }, { id = 2 }, { id = 3 }, { id = 8 } }
    sorters.sort(bufs)
    local ids = vim.tbl_map(function(buf) return buf.id end, bufs)
    assert.same(ids, { 2, 3, 8, 12 })
  end)

  it("should sort by components correctly", function()
    bufferline.setup({ options = { sort_by = "tabs" } })
    vim.cmd("e file1.txt")
    vim.cmd("tabnew file2.txt")
    vim.cmd("tabnew file3.txt")
    vim.cmd("bunload file2.txt")
    local bufs = vim.tbl_map(function(id) return { id = id } end, vim.api.nvim_list_bufs())

    sorters.sort(bufs)

    local buf_names = vim.tbl_map(
      function(buf) return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf.id), ":p:t") end,
      bufs
    )
    assert.same({ "file1.txt", "file3.txt", "file2.txt" }, buf_names)
  end)

  it("should add to the end of the buffer list", function()
    bufferline.setup({
      options = {
        sort_by = "insert_at_end",
      },
    })
    vim.cmd("edit! a.txt")
    vim.cmd("edit b.txt")
    vim.cmd("edit c.txt")
    vim.cmd("edit d.txt")
    vim.cmd("edit e.txt")
    nvim_bufferline()
    vim.cmd("b b.txt")
    nvim_bufferline()
    assert.is_equal(2, state.current_element_index)
    vim.cmd("edit g.txt")
    nvim_bufferline()
    local comp = state.components[#state.components]:as_element()
    assert.is_truthy(comp)
    assert.is_true(comp.name:match("g.txt") ~= nil)
  end)

  it("should open the new buffer beside the current", function()
    bufferline.setup({
      options = {
        sort_by = "insert_after_current",
      },
    })
    vim.cmd("edit! a.txt")
    vim.cmd("edit b.txt")
    vim.cmd("edit c.txt")
    vim.cmd("edit d.txt")
    vim.cmd("edit e.txt")
    nvim_bufferline()
    vim.cmd("b b.txt")
    nvim_bufferline()
    assert.is_equal(2, state.current_element_index)
    vim.cmd("edit g.txt")
    nvim_bufferline()
    local comp = state.components[3]:as_element()
    assert.is_truthy(comp)
    assert.is_true(comp.name:match("g.txt") ~= nil)
  end)
end)
