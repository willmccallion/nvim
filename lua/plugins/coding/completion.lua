--- Autocompletion via nvim-cmp with LuaSnip snippets.
--- Sources: LSP, snippets, path, buffer. Ghost text enabled.
--- Everything waits for the first InsertEnter except cmp-nvim-lsp, whose
--- capabilities LSP servers need before anything is typed. Its InsertEnter handler
--- requires cmp, so the autocmd here has to stay registered ahead of it, which
--- being set up during init.lua guarantees.

vim.pack.add({ "https://github.com/hrsh7th/cmp-nvim-lsp" })

vim.opt.pumheight = 5

local function setup_completion()
	vim.pack.add({
		"https://github.com/hrsh7th/nvim-cmp",
		"https://github.com/hrsh7th/cmp-buffer",
		"https://github.com/hrsh7th/cmp-path",
		"https://github.com/L3MON4D3/LuaSnip",
		"https://github.com/saadparwaiz1/cmp_luasnip",
		"https://github.com/rafamadriz/friendly-snippets",
	})

	local cmp = require("cmp")
	local luasnip = require("luasnip")

	require("luasnip.loaders.from_vscode").lazy_load()

	cmp.setup({
		--- cmp's own default only skips prompt buffers, and the vim.ui.input float is
		--- a scratch one, so it has to opt out by name.
		enabled = function()
			if vim.b.ui_input then
				return false
			end
			return require("cmp.config.default")().enabled()
		end,
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
		experimental = {
			ghost_text = true,
		},
	})
end

vim.api.nvim_create_autocmd("InsertEnter", {
	desc = "Load completion the first time it can be used",
	group = vim.api.nvim_create_augroup("load-completion", { clear = true }),
	once = true,
	callback = function()
		setup_completion()
		require("plugins.coding.autopairs")
		-- cmp maps its keys from its own InsertEnter handler, which is too new to see this one.
		vim.api.nvim_exec_autocmds("InsertEnter", { group = "___cmp___" })
	end,
})
