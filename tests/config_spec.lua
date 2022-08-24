local fmt = string.format

describe("Config tests", function()
  local whitesmoke = "#F5F5F5"
  local config = require("bufferline.config")

  before_each(function() vim.opt.termguicolors = true end)

  after_each(function() config.__reset() end)

  describe("Setting config", function()
    it("should add defaults to user values", function()
      config.set({
        options = {
          show_close_icon = false,
        },
      })
      local under_test = config.apply()
      assert.is_false(under_test.options.show_close_icon)
      assert.is_false(vim.tbl_isempty(under_test.highlights))
      assert.is_true(vim.tbl_count(under_test.highlights) > 10)
    end)

    it("should create vim highlight groups names for the highlights", function()
      config.set({
        highlights = {
          fill = {
            guifg = "red",
          },
        },
      })
      local under_test = config.apply()

      assert.equal(under_test.highlights.fill.fg, "red")
      assert.equal(under_test.highlights.fill.hl_group, "BufferLineFill")
    end)

    it("should derive colors from the existing highlights", function()
      vim.cmd(fmt("hi Comment guifg=%s", whitesmoke))
      config.set({})
      local under_test = config.apply()
      assert.equal(whitesmoke:lower(), under_test.highlights.info.fg)
    end)

    it('should not underline anything if options.indicator.style = "icon"', function()
      config.set({ options = { indicator = { style = "icon" } } })
      local conf = config.apply()
      for _, value in pairs(conf.highlights) do
        assert.is_falsy(value.underline)
      end
    end)

    it('should only underline valid fields if options.indicator.style = "underline"', function()
      config.set({ options = { indicator = { style = "underline" } } })
      local conf = config.apply()
      local valid = {
        "numbers_selected",
        "buffer_selected",
        "modified_selected",
        "indicator_selected",
        "tab_selected",
        "close_button_selected",
        "tab_separator_selected",
        "duplicate_selected",
        "separator_selected",
        "pick_selected",
        "close_button_selected",
        "diagnostic_selected",
        "error_selected",
        "error_diagnostic_selected",
        "info_selected",
        "info_diagnostic_selected",
        "warning_selected",
        "warning_diagnostic_selected",
        "hint_selected",
        "hint_diagnostic_selected",
      }
      for hl, value in pairs(conf.highlights) do
        if vim.tbl_contains(valid, hl) then
          assert.is_true(value.underline)
        else
          assert.is_falsy(value.underline)
        end
      end
    end)
  end)
  describe("Resetting config -", function()
    it("should use updated colors when the colorscheme changes", function()
      vim.cmd("colorscheme blue")
      local colors = require("bufferline.colors")
      local blue_bg = colors.get_color({ name = "Normal", attribute = "bg" })
      local blue_fg = colors.get_color({ name = "Normal", attribute = "fg" })
      config.set()
      config.apply()
      assert.equal(config.highlights.buffer_selected.bg, blue_bg)
      assert.equal(config.highlights.buffer_selected.fg, blue_fg)
      vim.cmd("colorscheme desert")
      local desert_bg = colors.get_color({ name = "Normal", attribute = "bg" })
      local desert_fg = colors.get_color({ name = "Normal", attribute = "fg" })
      config.update_highlights()
      assert.equal(config.highlights.buffer_selected.bg, desert_bg)
      assert.equal(config.highlights.buffer_selected.fg, desert_fg)

      assert.not_equal(blue_bg, desert_bg)
    end)
  end)
end)
