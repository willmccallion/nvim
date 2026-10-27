--- Colorscheme: Vague with a transparent background. TODO, WARN and FIXME in
--- comments are drawn as solid labels so they stand out; NOTE is only bold.

vim.pack.add({ "https://github.com/vague-theme/vague.nvim" })

---@param label string
---@param text string
---@return vim.api.keyset.highlight
local function comment_tag(label, text)
	return { fg = text, bg = label, bold = true }
end

require("vague").setup({
	transparent = true,
	on_highlights = function(highlights, colors)
		highlights["@comment.todo"] = comment_tag(colors.func, colors.bg)
		highlights["@comment.note"] = { fg = colors.constant, bold = true }
		highlights["@comment.warning"] = comment_tag(colors.warning, colors.bg)
		highlights["@comment.error"] = comment_tag(colors.error, colors.bg)
	end,
})

vim.cmd([[colorscheme vague]])
