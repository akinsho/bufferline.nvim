local Tabpage = require("bufferline.models").Tabpage

describe("Duplicate Tests - ", function()
  local duplicates
  local config

  before_each(function()
    package.loaded["bufferline.duplicates"] = nil
    duplicates = require("bufferline.duplicates")
    config = require("bufferline.config")
  end)

  it("should mark duplicate files", function()
    config.setup({})
    config.apply()
    local result = duplicates.mark({
      {
        path = "/test/dir_a/dir_b/file.txt",
        name = "file.txt",
        ordinal = 1,
      },
      {
        path = "/test/dir_a/dir_c/file.txt",
        name = "file.txt",
        ordinal = 2,
      },
      {
        path = "/test/dir_a/result.txt",
        name = "result.txt",
        ordinal = 3,
      },
    })
    assert.is_equal(result[1].duplicated, "path")
    assert.is_equal(result[2].duplicated, "path")
    assert.falsy(result[3].duplicated)
    assert.is_equal(#result, 3)
  end)

  it("should show duplicates across groups", function()
    config.setup({ options = { duplicates_across_groups = true } })
    config.apply()
    local result = duplicates.mark({
      {
        path = "/test/dir_a/dir_b/file.txt",
        name = "file.txt",
        ordinal = 1,
        group = "A",
      },
      {
        path = "/test/dir_a/dir_c/file.txt",
        name = "file.txt",
        ordinal = 2,
        group = "A",
      },
      {
        path = "/test/dir_a/dir_d/file.txt",
        name = "file.txt",
        ordinal = 1,
        group = "B",
      },
    })
    assert.is_equal(result[1].duplicated, "path")
    assert.is_equal(result[2].duplicated, "path")
    assert.is_equal(result[3].duplicated, "path")
  end)

  it("should not show duplicates across groups", function()
    config.setup({ options = { duplicates_across_groups = false } })
    config.apply()
    local result = duplicates.mark({
      {
        path = "/test/dir_a/dir_b/file.txt",
        name = "file.txt",
        ordinal = 1,
        group = "A",
      },
      {
        path = "/test/dir_a/dir_c/file.txt",
        name = "file.txt",
        ordinal = 2,
        group = "A",
      },
      {
        path = "/test/dir_a/dir_d/file.txt",
        name = "file.txt",
        ordinal = 1,
        group = "B",
      },
    })
    assert.is_equal(result[1].duplicated, "path")
    assert.is_equal(result[2].duplicated, "path")
    assert.falsy(result[3].duplicated)
  end)

  it("should return the correct prefix count", function()
    local result = duplicates.mark({
      {
        path = "/test/dir_a/dir_b/file.txt",
        name = "file.txt",
        ordinal = 1,
      },
      {
        path = "/test/dir_a/dir_c/file.txt",
        name = "file.txt",
        ordinal = 2,
      },
      {
        path = "/test/dir_a/result.txt",
        name = "result.txt",
        ordinal = 3,
      },
    })
    assert.equal(result[1].prefix_count, 2)
    assert.equal(result[2].prefix_count, 2)
    assert.falsy(result[3].prefix_count)
  end)

  it("should indicate if a buffer is exactly the same as another", function()
    local result = duplicates.mark({
      {
        path = "/test/dir_a/dir_b/file.txt",
        name = "file.txt",
        ordinal = 1,
      },
      {
        path = "/test/dir_a/dir_b/file.txt",
        name = "file.txt",
        ordinal = 2,
      },
      {
        path = "/test/dir_a/result.txt",
        name = "result.txt",
        ordinal = 3,
      },
    })
    assert.equal(result[1].duplicated, "element")
    assert.equal(result[2].duplicated, "element")
    assert.falsy(result[3].prefix_count)
  end)

  it("should return a prefixed element if duplicated", function()
    config.setup({ options = { enforce_regular_tabs = false } })
    config.apply()

    local component = duplicates.component({
      current_highlights = { duplicate = "TestHighlight" },
      tab = Tabpage:new({
        path = "very_long_directory_name/test/dir_a/result.txt",
        buf = 1,
        buffers = { 1 },
        id = 1,
        ordinal = 1,
        diagnostics = {},
        hidden = false,
        focusable = true,
        duplicated = true,
        prefix_count = 2,
      }),
    })

    assert.truthy(component.text)
    assert.is_equal(component.text, "dir_a/")

    component = duplicates.component({
      current_highlights = { duplicate = "TestHighlight" },
      tab = Tabpage:new({
        path = "very_long_directory_name/test/dir_a/result.txt",
        buf = 1,
        buffers = { 1 },
        id = 1,
        ordinal = 1,
        diagnostics = {},
        hidden = false,
        focusable = true,
        duplicated = true,
        prefix_count = 3,
      }),
    })

    assert.truthy(component.text)
    assert.is_equal(component.text, "test/dir_a/")
  end)

  it("should truncate a very long directory name", function()
    config.setup({ options = { enforce_regular_tabs = false, max_prefix_length = 10 } })
    config.apply()

    local component = duplicates.component({
      current_highlights = { duplicate = "TestHighlight" },
      tab = Tabpage:new({
        path = "very_long_directory_name/dir_a/result.txt",
        buf = 1,
        buffers = { 1 },
        id = 1,
        ordinal = 1,
        diagnostics = {},
        hidden = false,
        focusable = true,
        duplicated = true,
        prefix_count = 3,
      }),
    })

    assert.is_true(vim.api.nvim_strwidth(component.text) <= 10)
    assert.is_equal(component.text, "ver…/dir…/")
  end)
end)
