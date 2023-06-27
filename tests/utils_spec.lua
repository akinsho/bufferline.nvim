local api = vim.api

local utils = require("bufferline.utils")
local constants = require("bufferline.constants")

describe("Utils tests", function()
  it("should correctly truncate a long name", function()
    local truncated = utils.truncate_name("/user/test/long/file/folder/name/extension", 10)
    assert.is_true(api.nvim_strwidth(truncated) <= 10)
  end)

  it("should prefer dropping a filename extension in order to meet word limit", function()
    local truncated = utils.truncate_name("filename.md", 10)
    assert.is_equal(truncated, "filename" .. constants.ELLIPSIS)
  end)

  it("should prefer dropping a SINGLE filename extension in order to meet word limit", function()
    local truncated = utils.truncate_name("filename.md.md", 13)
    assert.is_equal(truncated, "filename.md" .. constants.ELLIPSIS)
  end)

  it("should save/restore positions correctly", function()
    -- remove existing buffers
    vim.cmd("silent %bwipeout!")

    local names = { "c.txt", "a.txt", "d.txt", "e.txt", "b.txt" }
    local bufs = {}
    for _, name in ipairs(names) do
      vim.cmd.edit(name)
      bufs[name] = api.nvim_get_current_buf()
    end

    local ids = {
      bufs["a.txt"],
      bufs["b.txt"],
      bufs["c.txt"],
      bufs["d.txt"],
      bufs["e.txt"],
    }

    utils.save_positions(ids)

    assert.same(utils.restore_positions(), ids)

    -- restore_positions should not return invalid bufids

    vim.cmd("bwipeout! " .. bufs["c.txt"])

    ids = {
      bufs["a.txt"],
      bufs["b.txt"],
      bufs["d.txt"],
      bufs["e.txt"],
    }
    assert.same(utils.restore_positions(), ids)

    vim.g[constants.positions_key] = '["INVALID_PATH"]'
    assert.same(utils.restore_positions(), {})

    -- empty or invalid JSON should return nil

    vim.g[constants.positions_key] = "[]"
    assert.is_equal(utils.restore_positions(), nil)

    vim.g[constants.positions_key] = ""
    assert.is_equal(utils.restore_positions(), nil)
  end)
end)
