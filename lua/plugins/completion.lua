--- @file completion.lua
--- @brief Configuration for the nvim-cmp completion engine and snippet integration.

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
		--- Expands a snippet using the LuaSnip engine.
		--- @param args table The arguments provided by nvim-cmp, containing the snippet body.
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
		["<CR>"] = cmp.mapping.confirm({ select = true }),
		--- Handles the <Tab> key for completion and snippet navigation.
		--- If the completion menu is open, it selects the next item.
		--- If a snippet can be expanded or jumped, it performs that action.
		--- Otherwise, it falls back to the default tab behavior.
		--- @param fallback function The default Neovim behavior for the <Tab> key.
		["<Tab>"] = cmp.mapping(function(fallback)
			if cmp.visible() then
				cmp.select_next_item()
			elseif luasnip.expand_or_jumpable() then
				luasnip.expand_or_jump()
			else
				fallback()
			end
		end, { "i", "s" }),
		["<S-Tab>"] = cmp.mapping(function(fallback)
			if cmp.visible() then
				cmp.select_prev_item()
			elseif luasnip.jumpable(-1) then
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
