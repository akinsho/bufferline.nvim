local colors = require("bufferline.colors")
local fn = vim.fn
local fmt = string.format

describe("Colors:", function()
  local color1 = "#FFB13B"
  local hl1 = "TestHighlight"
  before_each(function()
    -- Set a specific colorscheme that is bundled with vim and predictable
    vim.cmd("colorscheme industry")
    vim.cmd(fmt("highlight %s guifg=%s", hl1, color1))
  end)

  describe("get_color - ", function()
    it("should correctly derive normal color", function()
      local norm_fg = colors.get_color({ name = "Normal", attribute = "fg" })
      assert.is_truthy(norm_fg)
      assert.is_true(#norm_fg > 0)
    end)

    it("should use fallback if main is unavailable", function()
      local normal = fn.synIDattr(fn.hlID("Normal"), "fg#", "gui")
      local norm_fg = colors.get_color({
        name = "FakeHighlight",
        attribute = "fg",
        fallback = { name = "Normal", attribute = "fg" },
      })
      assert.is_truthy(norm_fg)
      assert.equal(norm_fg, normal)
    end)

    it("should use fallbacks recursively", function()
      local actual_fg = fn.synIDattr(fn.hlID(hl1), "fg#", "gui")
      local test_fg = colors.get_color({
        name = "FakeHighlight",
        attribute = "fg",
        fallback = {
          name = "NextFakeHighlight",
          attribute = "fg",
          fallback = { name = hl1, attribute = "fg" },
        },
      })
      assert.is_truthy(test_fg)
      assert.equal(test_fg, actual_fg:lower())
    end)

    it("should not return a value if it set to not_match", function()
      local normal = fn.synIDattr(fn.hlID("Normal"), "fg#", "gui")
      local norm_fg = colors.get_color({
        name = "Normal",
        attribute = "fg",
        not_match = normal,
      })
      assert.equal(norm_fg, "NONE")
    end)
  end)
end)
