describe("Number tests: ", function()
  local prefix = require("bufferline.numbers").prefix
  local test_buf = {
    id = 100,
    ordinal = 2,
  }
  it("should return an ordinal in the default style", function()
    local result = prefix(test_buf, "ordinal")
    assert.equal(result, "2.")
  end)

  it("should return a buffer id in the default style", function()
    local result = prefix(test_buf, "buffer_id")
    assert.equal(result, "100.")
  end)

  it("should return the correct default for both style", function()
    local result = prefix(test_buf, "both")
    assert.equal(result, "100.₂")
  end)

  it("should handle a custom numbers function", function()
    local function numbers_func(opts)
      return string.format("%s·%s", opts.raise(opts.id), opts.lower(opts.ordinal))
    end
    local result = prefix(test_buf, numbers_func)
    assert.equal(result, "¹⁰⁰·₂")
  end)

  it("should return two superscript numbers", function()
    local function numbers_func(opts)
      return string.format("%s·%s", opts.raise(opts.id), opts.raise(opts.ordinal))
    end
    local result = prefix(test_buf, numbers_func)
    assert.equal(result, "¹⁰⁰·²")
  end)
end)
