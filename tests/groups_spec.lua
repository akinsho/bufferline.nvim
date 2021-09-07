describe("Group tests - ", function()
  local groups

  before_each(function()
    package.loaded["bufferline.groups"] = nil
    groups = require("bufferline.groups")
  end)

  it("should add user groups on setup", function()
    groups.setup({
      options = {
        groups = {
          {
            name = "test-group",
            matcher = function(buf)
              return buf.name:includes("dummy")
            end,
          },
        },
      },
    })
    assert.is_equal(vim.tbl_count(groups.user_groups), 2)
  end)

  it("should sanitise invalid names", function()
    groups.setup({
      options = {
        groups = {
          {
            name = "test group",
            matcher = function(buf)
              return buf.name:includes("dummy")
            end,
          },
        },
      },
    })
    assert.is_equal(groups.user_groups[1].name, "test_group")
  end)

  it("should set highlights on setup", function()
    local config = {
      highlights = {
        buffer_selected = {
          guifg = "black",
          guibg = "white",
        },
        buffer_visible = {
          guifg = "black",
          guibg = "white",
        },
        buffer = {
          guifg = "black",
          guibg = "white",
        },
      },
      options = {
        groups = {
          {
            name = "test-group",
            highlight = { guifg = "red" },
            matcher = function(buf)
              return buf.name:includes("dummy")
            end,
          },
        },
      },
    }
    groups.setup(config)
    assert.truthy(config.highlights.test_group_selected)
    assert.truthy(config.highlights.test_group_visible)
    assert.truthy(config.highlights.test_group)

    assert.equal(config.highlights.test_group.guifg, "red")
  end)

  it("should sort tabs by groups", function()
    groups.setup({
      options = {
        groups = {
          {
            name = "test-group",
            matcher = function(buf)
              return buf.name:includes("dummy")
            end,
          },
        },
      },
    })
    local sorted = groups.sort_by_groups({
      { filename = "dummy-1.txt", group = 1 },
      { filename = "dummy-2.txt", group = 1 },
      { filename = "file-2.txt", group = 2 },
    })
    assert.is_equal(#sorted, 3)
    assert.equal(sorted[1].filename, "dummy-1.txt")
    assert.equal(sorted[#sorted].filename, "file-2.txt")

    assert.is_equal(vim.tbl_count(groups.tabs_by_group), 2)
  end)
end)
