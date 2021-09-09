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

  it("should return an ordinal number in superscript style", function()
    local result = prefix(test_buf, "ordinal", "superscript")
    assert.equal(result, "²")
  end)

  it("should return a buffer id number in superscript style", function()
    local result = prefix(test_buf, "buffer_id", "superscript")
    assert.equal(result, "¹⁰⁰")
  end)

  it("should return an ordinal number in subscript style", function()
    local result = prefix(test_buf, "ordinal", "subscript")
    assert.equal(result, "₂")
  end)

  it("should return a buffer id number in superscript style", function()
    local result = prefix(test_buf, "buffer_id", "subscript")
    assert.equal(result, "₁₀₀")
  end)

  it("should return a superscript buffer id and subscript ordinal", function()
    local result = prefix(test_buf, "both", { "subscript", "superscript" })
    assert.equal(result, "₁₀₀²")
  end)

  it("should return a subscript buffer id and superscript ordinal", function()
    local result = prefix(test_buf, "both", { "superscript", "subscript" })
    assert.equal(result, "¹⁰⁰₂")
  end)

  it("should return a superscript buffer_id and a default ordinal", function()
    local result = prefix(test_buf, "both", { "superscript", "none" })
    assert.equal(result, "¹⁰⁰2.")
  end)

  it("should return the correct default for both style", function()
    local result = prefix(test_buf, "both")
    assert.equal(result, "100.₂")
  end)

  it("should handle a custom numbers function", function()
    local function numbers_func(opts)
      return string.format("%s·%s", opts.raise(opts.id), opts.lower(opts.ordinal))
    end
    local result = prefix(test_buf, numbers_func, { "superscript", "subscript" })
    assert.equal(result, "¹⁰⁰·₂")
  end)
end)
