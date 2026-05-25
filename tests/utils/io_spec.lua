local io_utils = require("snippet_converter.utils.io")

describe("IO utils - read_json", function()
  local write_temp_json = function(content)
    local path = vim.fn.tempname()
    vim.fn.writefile(vim.split(content, "\n"), path)
    return path
  end

  describe("standard JSON", function()
    it("parses valid JSON", function()
      local path = write_temp_json([[
{
  "key": "value",
  "num": 42
}]])
      local result = io_utils.read_json(path)
      assert.are_same({ key = "value", num = 42 }, result)
    end)

    it("parses empty JSON object", function()
      local path = write_temp_json("{}")
      local result = io_utils.read_json(path)
      assert.are_same({}, result)
    end)

    it("parses nested objects and arrays", function()
      local path = write_temp_json([[
{
  "list": [1, 2, 3],
  "obj": { "inner": true }
}]])
      local result = io_utils.read_json(path)
      assert.are_same({ list = { 1, 2, 3 }, obj = { inner = true } }, result)
    end)
  end)

  describe("JSONC (requires json5)", function()
    it("strips // line comments before parsing", function()
      local path = write_temp_json([[
// Place your global snippets here.
{
  "key": "value"
}]])
      local result = io_utils.read_json(path)
      assert.are_same({ key = "value" }, result)
    end)

    it("strips inline // comments", function()
      local path = write_temp_json([[
{
  "key": "value", // inline comment
  "num": 42 // another
}]])
      local result = io_utils.read_json(path)
      assert.are_same({ key = "value", num = 42 }, result)
    end)

    it("strips /* */ block comments", function()
      local path = write_temp_json([[
{
  /* block comment */
  "key": "value"
}]])
      local result = io_utils.read_json(path)
      assert.are_same({ key = "value" }, result)
    end)

    it("preserves // inside string values", function()
      local path = write_temp_json([[
{
  "url": "https://example.com/path",
  "comment": "// not a comment"
}]])
      local result = io_utils.read_json(path)
      assert.are_same({
        url = "https://example.com/path",
        comment = "// not a comment",
      }, result)
    end)
  end)
end)
