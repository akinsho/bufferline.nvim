local fmt = string.format

describe("Config tests", function()
  local whitesmoke = "#F5F5F5"
  local config = require("bufferline.config")

  before_each(function() vim.opt.termguicolors = true end)

  after_each(function() config.__reset() end)

  describe("Setting config", function()
    it("should add defaults to user values", function()
      config.setup({
        options = {
          show_close_icon = false,
        },
      })
      local under_test = config.apply()
      assert.is_false(under_test.options.show_close_icon)
      assert.is_false(vim.tbl_isempty(under_test.highlights))
      assert.is_true(vim.tbl_count(under_test.highlights) > 10)
    end)

    it("should derive colors from the existing highlights", function()
      vim.cmd(fmt("hi Comment guifg=%s", whitesmoke))
      config.setup({})
      local under_test = config.apply()
      assert.equal(whitesmoke:lower(), under_test.highlights.info.fg)
    end)

    it('should not underline anything if options.indicator.style = "icon"', function()
      config.setup({ options = { indicator = { style = "icon" } } })
      local conf = config.apply()
      for _, value in pairs(conf.highlights) do
        assert.is_falsy(value.underline)
      end
    end)

    it('should only underline valid fields if options.indicator.style = "underline"', function()
      config.setup({ options = { indicator = { style = "underline" } } })
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

    describe("- Style Presets - ", function()
      it("should disable all bolding if the preset contains no bold", function()
        config.setup({ options = { style_preset = config.STYLE_PRESETS.no_bold } })
        local conf = config.apply()
        local some_italic = false
        for _, value in pairs(conf.highlights) do
          if not some_italic and value.italic then some_italic = true end
          assert.is_falsy(value.bold)
        end
        assert.is_true(some_italic)
      end)

      it("should disable all italics if the preset contains no italic", function()
        config.setup({ options = { style_preset = config.STYLE_PRESETS.no_italic } })
        local conf = config.apply()
        local some_bold = false
        for _, value in pairs(conf.highlights) do
          if not some_bold and value.bold then some_bold = true end
          assert.is_falsy(value.italic)
        end
        assert.is_true(some_bold)
      end)

      it("should disable both italics and bold, if no_bold and no_italic are specified", function()
        config.setup({
          options = {
            style_preset = { config.STYLE_PRESETS.no_italic, config.STYLE_PRESETS.no_bold },
          },
        })
        local conf = config.apply()
        for _, value in pairs(conf.highlights) do
          assert.is_falsy(value.italic)
          assert.is_falsy(value.bold)
        end
      end)
    end)
  end)

  describe("Resetting config -", function()
    it("should use updated colors when the colorscheme changes", function()
      vim.cmd("colorscheme blue")
      local colors = require("bufferline.colors")
      local blue_bg = colors.get_color({ name = "Normal", attribute = "bg" })
      local blue_fg = colors.get_color({ name = "Normal", attribute = "fg" })
      config.setup()
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
