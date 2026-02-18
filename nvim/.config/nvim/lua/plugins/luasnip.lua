return {
  {
    "L3MON4D3/LuaSnip",
    dependencies = { "rafamadriz/friendly-snippets" },
    config = function()
      local ls = require("luasnip")
      local postfix = require("luasnip.extras.postfix").postfix
      local l = require("luasnip.extras").lambda

      require("luasnip.loaders.from_vscode").lazy_load()

      local js_filetypes = {
        "javascript",
        "typescript",
        "javascriptreact",
        "typescriptreact",
      }

      for _, ft in ipairs(js_filetypes) do
        ls.add_snippets(ft, {
          -- foo.log -> console.log(foo)
          postfix({ trig = ".log", match_pattern = "[%w_.]+$" }, {
            l("console.log(" .. l.POSTFIX_MATCH .. ")"),
          }),

          -- foo.warn -> console.warn(foo)
          postfix({ trig = ".warn", match_pattern = "[%w_.]+$" }, {
            l("console.warn(" .. l.POSTFIX_MATCH .. ")"),
          }),

          -- foo.err -> console.error(foo)
          postfix({ trig = ".err", match_pattern = "[%w_.]+$" }, {
            l("console.error(" .. l.POSTFIX_MATCH .. ")"),
          }),
        })
      end

      ls.add_snippets("python", {
        -- x.log -> print(x)
        postfix({ trig = ".log", match_pattern = "[%w_.]+$" }, {
          l("print(" .. l.POSTFIX_MATCH .. ")"),
        }),
        -- x.repr -> print(repr(x))
        postfix({ trig = ".repr", match_pattern = "[%w_.]+$" }, {
          l("print(repr(" .. l.POSTFIX_MATCH .. "))"),
        }),
        -- x.type -> print(type(x))
        postfix({ trig = ".type", match_pattern = "[%w_.]+$" }, {
          l("print(type(" .. l.POSTFIX_MATCH .. "))"),
        }),
      })
    end,
  },
}
