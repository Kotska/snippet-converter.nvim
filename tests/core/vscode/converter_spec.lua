local NodeType = require("snippet_converter.core.node_type")
local converter = require("snippet_converter.core.vscode.converter")

describe("VSCode converter should", function()
  it("convert basic snippet to JSON", function()
    local snippet = {
      trigger = "fn",
      description = "function",
      scope = { "javascript", "typescript" },
      -- "local ${1:name} = function($2)"
      body = {
        { type = NodeType.TEXT, text = "local " },
        {
          type = NodeType.PLACEHOLDER,
          int = "1",
          any = { { type = NodeType.TEXT, text = "name" } },
        },
        { type = NodeType.TEXT, text = " = function(" },
        { type = NodeType.TABSTOP, int = "2" },
        { type = NodeType.TEXT, text = ")" },
      },
    }
    local actual = converter.convert(snippet)
    local expected = {
      trigger = "fn",
      description = "function",
      scope = "javascript,typescript",
      body = "local ${1:name} = function($2)",
    }
    assert.are_same(expected, actual)
  end)

  it("correctly escape curly brace preceded by backslashes", function()
    local snippet = {
      trigger = "fn",
      body = {
        { type = NodeType.TEXT, text = [[\\{$1\\} $0]] },
      },
    }
    local actual = converter.convert(snippet)
    local expected = {
      trigger = "fn",
      -- In .convert, '\' was not yet escaped for JSON export
      body = [[\\{\$1\\\} \$0]],
    }
    assert.are_same(expected, actual)
  end)

  it("handle missing description with multiple lines in body", function()
    local snippet = {
      trigger = "fn",
      body = {
        { type = NodeType.TEXT, text = "local " },
        {
          type = NodeType.PLACEHOLDER,
          int = "1",
          any = { { type = NodeType.TEXT, text = "name" } },
        },
        { type = NodeType.TEXT, text = " = function(" },
        { type = NodeType.TABSTOP, int = "2" },
        { type = NodeType.TEXT, text = ")\nnewline" },
      },
    }
    local expected = {
      trigger = "fn",
      body = { "local ${1:name} = function($2)", "newline" },
    }
    local actual = converter.convert(snippet)
    assert.are_same(expected, actual)
  end)

  it("convert choice node", function()
    local snippet = {
      trigger = "fn",
      body = {
        { type = NodeType.CHOICE, int = "1", text = { "a", "b", "c" } },
        { type = NodeType.CHOICE, int = "2", text = { "a" } },
      },
    }
    local expected = {
      trigger = "fn",
      body = "${1|a,b,c|}${2|a|}",
    }
    local actual = converter.convert(snippet)
    assert.are_same(expected, actual)
  end)

  local function create_format_snippet(replacement)
    return {
      trigger = "fn",
      body = {
        {
          int = "1",
          transform = {
            regex = "",
            regex_kind = NodeType.RegexKind.JAVASCRIPT,
            options = "",
            replacement = replacement,
            type = NodeType.TRANSFORM,
          },
          type = NodeType.TABSTOP,
        },
      },
    }
  end

  it("convert format node with format modifier", function()
    local snippet = create_format_snippet {
      { int = "2", format_modifier = "upcase", type = NodeType.FORMAT },
    }
    local expected = {
      trigger = "fn",
      body = "${1//${2:/upcase}/}",
    }
    local actual = converter.convert(snippet)
    assert.are_same(expected, actual)
  end)

  it("convert format node without if and else text", function()
    local snippet = create_format_snippet { { int = "2", type = NodeType.FORMAT } }
    local expected = {
      trigger = "fn",
      body = "${1//$2/}",
    }
    local actual = converter.convert(snippet)
    assert.are_same(expected, actual)
  end)

  it("convert format node with if text", function()
    local snippet = create_format_snippet { { if_text = "if_text", int = "2", type = NodeType.FORMAT } }
    local expected = {
      trigger = "fn",
      body = "${1//${2:+if_text}/}",
    }
    local actual = converter.convert(snippet)
    assert.are_same(expected, actual)
  end)

  it("convert format node with else text", function()
    local snippet = create_format_snippet { { else_text = "else_text", int = "2", type = NodeType.FORMAT } }
    local expected = {
      trigger = "fn",
      body = "${1//${2:-else_text}/}",
    }
    local actual = converter.convert(snippet)
    assert.are_same(expected, actual)
  end)

  it("convert format node with if and else text", function()
    local snippet = create_format_snippet {
      { if_text = "if_text", else_text = "else_text", int = "2", type = NodeType.FORMAT },
    }
    local expected = {
      trigger = "fn",
      body = "${1//${2:?if_text:else_text}/}",
    }
    local actual = converter.convert(snippet)
    assert.are_same(expected, actual)
  end)

  it("convert visual placeholder to $TM_SELECTED_TEXT #18", function()
    local snippet = {
      trigger = "if",
      body = {
        { text = "if", type = NodeType.VISUAL_PLACEHOLDER },
        {
          any = {
            { type = NodeType.PLACEHOLDER, int = "1", any = { { type = NodeType.TEXT, text = "default" } } },
          },
          type = NodeType.VISUAL_PLACEHOLDER,
        },
      },
    }
    local expected = {
      trigger = "if",
      body = "${TM_SELECTED_TEXT:if}${TM_SELECTED_TEXT:${1:default}}",
    }
    local actual = converter.convert(snippet)
    assert.are_same(expected, actual)
  end)
end)

describe("VSCode converter should fail to convert", function()
  it("snippet with non-VSCode regex in transform node", function()
    local snippet = {
      trigger = "fn",
      body = {
        {
          type = NodeType.TABSTOP,
          transform = {
            type = NodeType.TRANSFORM,
            regex = "(.*)",
            regex_kind = NodeType.RegexKind.PYTHON,
            replacement = {
              { text = "abc", type = NodeType.TEXT },
            },
            options = "",
          },
        },
      },
    }
    local ok, msg = pcall(converter.convert, snippet)
    assert.is_false(ok)
    assert.are_same("conversion of Python regex in transform node is not supported", msg)
  end)

  it("snippet with YASnippet transform node", function()
    local snippet = {
      trigger = "fn",
      body = {
        {
          type = NodeType.TABSTOP,
          int = "2",
          -- YASnippet transform nodes don't have a regex kind
          transform = {
            type = NodeType.TRANSFORM,
            replacement = "capitalize yas-text",
          },
        },
      },
    }
    local ok, msg = pcall(converter.convert, snippet)
    assert.is_false(ok)
    assert.are_same("conversion of YASnippet transform node is not supported", msg)
  end)
end)

describe("VSCode converter (luasnip flavor) should", function()
  it("not create empty luasnip table", function()
    local snippet = {
      trigger = "fn",
      body = {},
    }
    local actual = converter.convert(snippet, nil, { flavor = "luasnip" })
    local expected = {
      trigger = "fn",
      body = "",
    }
    assert.are_same(expected, actual)
  end)

  it("convert autotrigger key from options", function()
    local snippet = {
      trigger = "fn",
      body = {},
      options = "iA",
      luasnip = {
        autotrigger = false,
      },
    }
    local actual = converter.convert(snippet, nil, { flavor = "luasnip" })
    local expected = {
      trigger = "fn",
      body = "",
      -- Original key is not modified (but ignored during export)
      options = "iA",
      luasnip = {
        autotrigger = true,
      },
    }
    assert.are_same(expected, actual)
  end)

  it("should convert autotrigger flag", function()
    local snippet = {
      trigger = "fn",
      body = {},
      autotrigger = true,
    }
    local actual = converter.convert(snippet, nil, { flavor = "luasnip" })
    local expected = {
      trigger = "fn",
      body = "",
      -- Original key is not modified
      autotrigger = true,
      luasnip = {
        autotrigger = true,
      },
    }
    assert.are_same(expected, actual)
  end)

  it("convert priority", function()
    local snippet = {
      trigger = "fn",
      body = { { type = NodeType.TEXT, text = "txt" } },
      priority = 100,
    }
    local actual = converter.convert(snippet, nil, { flavor = "luasnip" })
    local expected = {
      trigger = "fn",
      body = "txt",
      -- Original key is not modified
      priority = 100,
      luasnip = {
        priority = 100,
      },
    }
    assert.are_same(expected, actual)
  end)

  it("not convert variable nodes to Vimscript", function()
    local snippet = {
      trigger = "fn",
      body = {
        { type = NodeType.VARIABLE, var = "CURRENT_YEAR" },
        {
          type = NodeType.VARIABLE,
          var = "CURRENT_YEAR",
          any = {
            { type = NodeType.TEXT, text = "txt" },
          },
        },
        {
          type = NodeType.VARIABLE,
          var = "CURRENT_YEAR",
          any = {
            { type = NodeType.VARIABLE, var = "CURRENT_MONTH" },
          },
        },
      },
    }
    local actual = converter.convert(snippet, nil, { flavor = "luasnip" })
    assert.are_same({
      trigger = "fn",
      body = "${CURRENT_YEAR}${CURRENT_YEAR:txt}${CURRENT_YEAR:${CURRENT_MONTH}}",
    }, actual)
  end)
end)

describe("get_package_json_string", function()
  it("uses filename-derived filetype when no scopes available", function()
    local result = converter._get_package_json_string("t1", { "media" }, {})
    assert.is_true(result:find([["media"]]), "should include filetype")
    assert.is_true(result:find([["./media.json"]]), "should include path")
    assert.is_false(result:find([["php"]]), "should not include scope filetypes")
  end)

  it("uses collected snippet scopes for language when available", function()
    local scopes = { media = { "css", "html", "php" } }
    local result = converter._get_package_json_string("t1", { "media" }, {}, scopes)
    assert.is_true(result:find([["css"]]), "should include css")
    assert.is_true(result:find([["html"]]), "should include html")
    assert.is_true(result:find([["php"]]), "should include php")
    assert.is_false(result:find([["media"]]), "should not use filename filetype")
  end)

  it("falls back to langs_per_filetype when no scopes and no filetype match", function()
    local langs = { media = { "vim", "neovim" } }
    local result = converter._get_package_json_string("t1", { "media" }, langs)
    assert.is_true(result:find([["vim"]]), "should include vim")
    assert.is_true(result:find([["neovim"]]), "should include neovim")
  end)

  it("snippet scopes take priority over langs_per_filetype", function()
    local scopes = { media = { "css", "php" } }
    local langs = { media = { "vim" } }
    local result = converter._get_package_json_string("t1", { "media" }, langs, scopes)
    assert.is_true(result:find([["css"]]), "should include css from scopes")
    assert.is_true(result:find([["php"]]), "should include php from scopes")
    assert.is_false(result:find([["vim"]]), "should not include vim from langs")
  end)

  it("handles multiple filetypes with mixed scopes", function()
    local scopes = { all = { "php", "html" } }
    -- "css" not in scopes, falls back to filename
    local result = converter._get_package_json_string("t1", { "all", "css" }, {}, scopes)
    assert.is_true(result:find([["php"]]), "should include php for all")
    assert.is_true(result:find([["html"]]), "should include html for all")
    assert.is_true(result:find([["css"]]), "should include css filetype fallback")
  end)
end)
