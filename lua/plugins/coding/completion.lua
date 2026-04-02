--- @module plugins.completion
--- @brief Configuration for nvim-cmp and snippet integration.
--- @description Sets up the autocompletion engine using nvim-cmp, including
--- sources for LSP, snippets, paths, and buffers. Configures LuaSnip for
--- snippet expansion and provides custom keybindings for the completion menu.

vim.pack.add({
	"https://github.com/hrsh7th/nvim-cmp",
	"https://github.com/hrsh7th/cmp-nvim-lsp",
	"https://github.com/hrsh7th/cmp-buffer",
	"https://github.com/hrsh7th/cmp-path",
	"https://github.com/L3MON4D3/LuaSnip",
	"https://github.com/saadparwaiz1/cmp_luasnip",
	"https://github.com/rafamadriz/friendly-snippets",
})

local cmp = require("cmp")
local luasnip = require("luasnip")

local lspkind_ok, lspkind = pcall(require, "lspkind")

require("luasnip.loaders.from_vscode").lazy_load()

vim.o.pumheight = 5

cmp.setup({
	snippet = {
		expand = function(args)
			luasnip.lsp_expand(args.body)
		end,
	},
	window = {
		completion = cmp.config.window.bordered({ border = "none" }),
		documentation = cmp.config.window.bordered({ border = "none" }),
	},
	mapping = cmp.mapping.preset.insert({
		["<C-n>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
		["<C-p>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
		["<C-b>"] = cmp.mapping.scroll_docs(-4),
		["<C-f>"] = cmp.mapping.scroll_docs(4),
		["<C-Space>"] = cmp.mapping.complete(),
		["<C-e>"] = cmp.mapping.abort(),
		["<CR>"] = cmp.mapping.confirm({ select = false }),
		["<Tab>"] = cmp.mapping(function(fallback)
			if cmp.visible() then
				cmp.select_next_item()
			elseif luasnip.locally_jumpable(1) then
				luasnip.jump(1)
			else
				fallback()
			end
		end, { "i", "s" }),
		["<S-Tab>"] = cmp.mapping(function(fallback)
			if cmp.visible() then
				cmp.select_prev_item()
			elseif luasnip.locally_jumpable(-1) then
				luasnip.jump(-1)
			else
				fallback()
			end
		end, { "i", "s" }),
	}),

	sources = cmp.config.sources({
		{ name = "nvim_lsp" },
		{ name = "luasnip" },
		{ name = "path" },
	}, {
		{ name = "buffer", keyword_length = 3 },
	}),
	formatting = {
		format = (lspkind_ok and vim.g.have_nerd_font) and lspkind.cmp_format({
			maxwidth = 50,
			ellipsis_char = "...",
		}) or nil,
	},
	experimental = {
		ghost_text = true,
	},
})
