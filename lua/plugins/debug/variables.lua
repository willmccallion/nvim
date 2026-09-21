--- Fuzzy search over the variables visible in the stopped frame.
--- Structured values are expanded one level, so a struct's fields are searchable
--- by name too. Selecting one pins it to the debug view's Watches panel.
--- Register banks are left out: they contribute hundreds of entries that bury
--- the handful of locals you are actually looking for.

local M = {}

---@class (private) debug.Variable
---@field scope string
---@field expression string what to watch, e.g. "p.x"
---@field type string
---@field value string

--- An expensive scope is one the adapter asks not to be read without being asked
--- for; nvim-dap leaves those unfetched too.
---@param scope dap.Scope
---@return boolean
local function is_searchable(scope)
	return scope.presentationHint ~= "registers" and not scope.expensive
end

--- lldb supplies evaluateName; gdb does not, so a child's expression has to be
--- built from its parent's or a watch on it resolves against the wrong scope.
---@param parent? string expression of the containing variable
---@param variable dap.Variable
---@return string
local function expression_for(parent, variable)
	if variable.evaluateName then
		return variable.evaluateName
	end
	if not parent then
		return variable.name
	end
	-- Subscripts already carry their brackets; named fields need the dot.
	if variable.name:sub(1, 1) == "[" then
		return parent .. variable.name
	end
	return parent .. "." .. variable.name
end

---@param scope_name string
---@param variable dap.Variable
---@param parent? string expression of the containing variable
---@return debug.Variable
local function to_entry(scope_name, variable, parent)
	return {
		scope = scope_name,
		expression = expression_for(parent, variable),
		type = variable.type or "",
		-- A value spanning lines would break the one-line picker row.
		value = (variable.value or ""):gsub("%s*\n%s*", " "),
	}
end

--- Gathers the frame's variables, then each structured one's fields.
---@param session dap.Session
---@param on_done fun(variables: debug.Variable[])
local function collect(session, on_done)
	local variables = {}
	-- Counts the loop itself, so an early reply cannot finish the gather short.
	local pending = 1

	local function settle()
		pending = pending - 1
		if pending > 0 then
			return
		end
		table.sort(variables, function(a, b)
			return a.expression < b.expression
		end)
		vim.schedule(function()
			on_done(variables)
		end)
	end

	--- Adds a scope's variables, then asks for the fields of each structured one.
	---@param scope_name string
	---@param scope_variables dap.Variable[]
	local function add_scope(scope_name, scope_variables)
		for _, variable in ipairs(scope_variables) do
			local entry = to_entry(scope_name, variable)
			table.insert(variables, entry)
			if (variable.variablesReference or 0) > 0 then
				pending = pending + 1
				local params = { variablesReference = variable.variablesReference }
				session:request("variables", params, function(_, response)
					for _, child in ipairs(response and response.variables or {}) do
						table.insert(variables, to_entry(scope_name, child, entry.expression))
					end
					settle()
				end)
			end
		end
	end

	for _, scope in ipairs(session.current_frame.scopes or {}) do
		if is_searchable(scope) then
			if scope.variables then
				add_scope(scope.name, scope.variables)
			else
				-- nvim-dap requests each scope's variables when the session stops, so
				-- searching straight after a stop can arrive before they have landed.
				pending = pending + 1
				local params = { variablesReference = scope.variablesReference }
				session:request("variables", params, function(_, response)
					add_scope(scope.name, response and response.variables or {})
					settle()
				end)
			end
		end
	end

	settle()
end

---@param variables debug.Variable[]
local function open_picker(variables)
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local entry_display = require("telescope.pickers.entry_display")

	local displayer = entry_display.create({
		separator = " ",
		items = { { width = 28 }, { width = 18 }, { remaining = true } },
	})

	pickers
		.new({}, {
			prompt_title = "Debug variables",
			finder = finders.new_table({
				results = variables,
				entry_maker = function(variable)
					return {
						value = variable,
						ordinal = variable.expression .. " " .. variable.type,
						display = function(entry)
							return displayer({
								entry.value.expression,
								{ entry.value.type, "Type" },
								{ entry.value.value, "String" },
							})
						end,
					}
				end,
			}),
			sorter = require("telescope.config").values.generic_sorter({}),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					if selection then
						require("dap-view").add_expr(selection.value.expression)
					end
				end)
				return true
			end,
		})
		:find()
end

--- Searches the stopped frame's variables, pinning the chosen one to Watches.
function M.pick()
	local session = require("dap").session()
	if not session or not session.current_frame then
		vim.notify("No debug session stopped at a frame", vim.log.levels.WARN)
		return
	end

	collect(session, function(variables)
		if vim.tbl_isempty(variables) then
			vim.notify("No variables in the current frame", vim.log.levels.WARN)
			return
		end
		open_picker(variables)
	end)
end

return M
