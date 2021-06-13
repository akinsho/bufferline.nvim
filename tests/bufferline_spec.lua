_G.__TEST = true

describe("Bufferline tests:", function()
  vim.opt.swapfile = false
  vim.opt.hidden = true

  local bufferline = require("bufferline")

  describe("render buffer - ", function()
    it("should create corresponding buffers in state", function()
      bufferline.setup()
      local tabline = nvim_bufferline()
      assert.truthy(tabline)
      assert.is.equal(vim.tbl_count(bufferline._state.buffers), 1)
    end)

    it("should allow configuring the indicator icon", function()
      local icon = "R"
      bufferline.setup({
        options = {
          indicator_icon = icon,
        },
      })
      local tabline = nvim_bufferline()
      assert.truthy(tabline)
      assert.is_truthy(tabline:match(icon))
    end)

    it("should left handle mouse clicks correctly", function()
      local bufnum = vim.api.nvim_get_current_buf()
      bufferline.setup({
        options = {
          left_mouse_command = "vertical sbuffer %d",
        },
      })
      bufferline.handle_click(bufnum, "l")
      assert.is_equal(#vim.api.nvim_list_wins(), 2)
    end)

    it("should middle handle mouse clicks correctly", function()
      local bufnum = vim.api.nvim_get_current_buf()
      bufferline.setup({
        options = {
          middle_mouse_command = function(bufid)
            vim.bo[bufid].filetype = "test"
          end,
        },
      })
      bufferline.handle_click(bufnum, "m")
      assert.is_equal(vim.bo[bufnum].filetype, "test")
    end)

    it("should right handle mouse clicks correctly", function()
      local bufnum = vim.api.nvim_get_current_buf()
      bufferline.setup({
        options = {
          right_mouse_command = "setfiletype egg",
        },
      })
      bufferline.handle_click(bufnum, "r")
      assert.is_equal(vim.bo.filetype, "egg")
    end)

    it("should handle close click correctly", function()
      local bufnum = vim.api.nvim_get_current_buf()
      local count = 1
      local expected = bufnum + count
      bufferline.setup({
        options = {
          close_command = function(bufid)
            count = count + bufid
          end,
        },
      })
      bufferline.handle_close_buffer(bufnum)
      assert.is_equal(count, expected)
    end)

    pending("should close buffers to the right of the current buffer", function()
      bufferline.setup()
      vim.cmd("edit a.txt")
      vim.cmd("edit b.txt")
      vim.cmd("edit c.txt")
      vim.cmd("edit d.txt")
      vim.cmd("edit e.txt")

      vim.cmd("edit c.txt")
      bufferline.close_in_direction("right")
      assert.is_equal(3, #bufferline._state.buffers)
    end)
  end)
end)
