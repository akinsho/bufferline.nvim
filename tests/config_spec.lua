local fmt = string.format

describe("Config tests", function()
  local whitesmoke = "#F5F5F5"
  local config = require("bufferline.config")

  after_each(function()
    config.__reset()
  end)

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

      assert.equal(under_test.highlights.fill.guifg, "red")
      assert.equal(under_test.highlights.fill.hl_name, "BufferLineFill")
    end)

    it("should derive colors from the existing highlights", function()
      vim.cmd(fmt("hi Comment guifg=%s", whitesmoke))
      config.set({})
      local under_test = config.apply()
      assert.equal(under_test.highlights.info.guifg, whitesmoke:lower())
    end)

    it('should update highlights on colorscheme change', function()
      config.set({
        highlights = {
          buffer_selected = {
            guifg = "red"
          }
        }
      })
      local conf = config.apply()
      conf = config.update_highlights()
      assert.is_equal(conf.highlights.buffer_selected.guifg, "red")
    end)
  end)
end)
