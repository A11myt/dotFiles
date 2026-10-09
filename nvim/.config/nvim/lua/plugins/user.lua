---@type LazySpec
local config = {
  {
    "L3MON4D3/LuaSnip",
    config = function(plugin, opts)
      require("astronvim.plugins.configs.luasnip")(plugin, opts) -- include the default astronvim config that calls the setup call
      -- add more custom luasnip configuration such as filetype extend or custom snippets
      local luasnip = require("luasnip")
      luasnip.filetype_extend("javascript", { "javascriptreact" })
    end,
  },
  {
    "windwp/nvim-autopairs",
    config = function(plugin, opts)
      require("astronvim.plugins.configs.nvim-autopairs")(plugin, opts) -- include the default astronvim config that calls the setup call
      local npairs = require("nvim-autopairs")
      local Rule = require("nvim-autopairs.rule")
      local cond = require("nvim-autopairs.conds")
      npairs.add_rules({
        Rule("$", "$", { "tex", "latex" })
          :with_pair(cond.not_after_regex("%%"))
          :with_pair(cond.not_before_regex("xxx", 3))
          :with_move(cond.none())
          :with_del(cond.not_after_regex("xx"))
          :with_cr(cond.none()),
      }, Rule("a", "a", "-vim"))
    end,
  },
  {
    "goolord/alpha-nvim",
    opts = function(_, opts)
      local dashboard = require("alpha.themes.dashboard")

      dashboard.section.header.val = {
        "   █████    ██   ██  ███    ███ ██    ██ ████████",
        "  ██   ██ ████ ████  ████  ████  ██  ██     ██   ",
        "  ███████   ██   ██  ██ ████ ██   ████      ██   ",
        "  ██   ██   ██   ██  ██  ██  ██    ██       ██   ",
        "  ██   ██   ██   ██  ██      ██    ██       ██   ",
        "",
        "        ███    ██ ██    ██ ██ ███    ███",
        "        ████   ██ ██    ██ ██ ████  ████",
        "        ██ ██  ██ ██    ██ ██ ██ ████ ██",
        "        ██  ██ ██  ██  ██  ██ ██  ██  ██",
        "        ██   ████   ████   ██ ██      ██",
        "",
      }

      dashboard.section.buttons.val = {
        dashboard.button("n", "  New File", ":ene <BAR> startinsert <CR>"),
        dashboard.button("f", "  Find File", ":Telescope find_files<CR>"),
        dashboard.button("o", "󰈙  Recent Files", ":Telescope oldfiles<CR>"),
        dashboard.button("w", "󰈭 Find Word", ":Telescope live_grep<CR>"),
        dashboard.button("'", "  Bookmarks", ":Telescope marks<CR>"),
        dashboard.button("s", "  Last Session", ":SessionManager load_last_session<CR>"),
      }

      vim.api.nvim_create_autocmd("User", {
        pattern = "LazyVimStarted",
        callback = function()
          local stats = require("lazy").stats()
          dashboard.section.footer.val = {
            string.format(
              "⚡ Neovim loaded %d/%d plugins in %.2fms",
              stats.loaded or 0,
              stats.count or 0,
              stats.startuptime or 0
            ),
          }
          dashboard.section.header.opts = { position = "center", hl = "DiagnosticVirtualTextInfo" }
          dashboard.section.footer.opts = { position = "center", hl = "Number" }
          pcall(vim.cmd.AlphaRedraw)
        end,
      })

      dashboard.layout = {
        { type = "padding", val = 2 },
        dashboard.section.header,
        { type = "padding", val = 1 },
        dashboard.section.buttons,
        { type = "padding", val = 1 },
        dashboard.section.footer,
      }
      opts.layout = {
        { type = "padding", val = 10 },
        dashboard.section.header,
        { type = "padding", val = 1 },
        dashboard.section.buttons,
        { type = "padding", val = 1 },
        dashboard.section.footer,
      }
    end,
  },
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("telescope").setup({
        defaults = {
          border = true,
          borderchars = { "─", "│", "─", "│", "┌", "┐", "┘", "└" },
          layout_strategy = "horizontal",
          sorting_strategy = "ascending",
          prompt_title = "",
          preview_title = "",
          results_title = "",
          layout_config = {
            horizontal = {
              preview_width = 0.55,
              results_width = 0.8,
            },
          },
          vimgrep_arguments = {
            "rg",
            "--color=never",
            "--no-heading",
            "--with-filename",
            "--line-number",
            "--column",
            "--smart-case",
          },
          prompt_prefix = "🔍 ",
          selection_caret = "➤ ",
          path_display = { "truncate" },
          mappings = {
            i = {
              ["<C-u>"] = false,
              ["<C-d>"] = false,
            },
          },
        },
      })
    end,
  },
  {
    "nvim-telescope/telescope-fzf-native.nvim",
    build = "make",
    dependencies = { "nvim-telescope/telescope.nvim" },
    config = function()
      require("telescope").load_extension("fzf")
    end,
  },
  {
    "kylechui/nvim-surround",
    config = function()
      require("nvim-surround").setup({
        surrounds = {
          ["<"] = {
            add = function()
              local tag = vim.fn.input("Tag: ")
              return { "<" .. tag .. ">", "</" .. tag .. ">" }
            end,
          },
        },
      })
    end,
  },
  {
    "christoomey/vim-tmux-navigator",
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
    },
    keys = {
      { "<c-h>", "<cmd>TmuxNavigateLeft<cr>" },
      { "<c-j>", "<cmd>TmuxNavigateDown<cr>" },
      { "<c-k>", "<cmd>TmuxNavigateUp<cr>" },
      { "<c-l>", "<cmd>TmuxNavigateRight<cr>" },
    },
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    config = function()
      require("neo-tree").setup({
        filesystem = {
          filtered_items = {
            visible = true, -- <== zeigt versteckte Dateien an
            show_hidden = true,
          },
        },
      })
    end,
  },
}
return config
