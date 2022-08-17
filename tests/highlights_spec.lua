describe("Highlights -", function()
  ---@module "bufferline.highlights"
  local highlights
  ---@module "bufferline.config"
  local config

  before_each(function()
    package.loaded["bufferline.highlights"] = nil
    package.loaded["bufferline.config"] = nil

    highlights = require("bufferline.highlights")
    config = require("bufferline.config")
  end)

  it("should set highlights as default", function()
    config.set({ options = { themable = true } })
    config.apply()
    local hl = highlights.set_one("BufferLineBufferSelected", { bold = true })
    assert.truthy(hl)
    assert.is_true(hl.default)
  end)

  it("should not set highlights as default if themable = false", function()
    config.set({ options = { themable = true } })
    config.apply()
    local hl = highlights.set_one("BufferLineBufferSelected", { bold = true })
    assert.truthy(hl)
    assert.is_true(hl.default)
  end)
end)
