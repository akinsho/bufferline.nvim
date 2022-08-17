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
end)
