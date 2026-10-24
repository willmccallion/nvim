--- Type-aware views of the stopped program, run as lldb commands through lldb-dap
--- (whose REPL treats input starting with a backtick as a command): every variable
--- in the frame with its type, and the definition of a struct or class.

local dap = require("dap")

local M = {}

--- lldb-dap's default escape for "run this as an lldb command, not an expression".
local LLDB_COMMAND_PREFIX = "`"

local FLOAT_ID = "dap-types"

--- The struct a variable's type is about, so `const Shape &` or `Point *` look up
--- Shape and Point. Arrays (`int[3]`) are reduced to their element type.
---@param type_name string as an adapter reports it
---@return string
function M.underlying_type(type_name)
	local name = vim.trim(type_name)
	name = name:gsub("%s*%[%d*%]$", "")
	name = name:gsub("[%s%*&]+$", "")
	repeat
		local before = name
		name = name:gsub("^const%s+", ""):gsub("^volatile%s+", ""):gsub("^struct%s+", ""):gsub("^class%s+", "")
		name = name:gsub("%s+const$", "")
	until name == before
	return name
end

---@class (private) debug.TypeDefinition
---@field definition string[] the declaration's lines, e.g. "struct Point {" ... "}"
---@field size? string bytes
---@field decl? string file:line:column it is declared at

--- Picks the declaration out of `image lookup --type` output, which wraps it as
--- `compiler_type = "struct Point {...}"` after the id, size and location.
---@param output string
---@return debug.TypeDefinition?
function M.parse_type_lookup(output)
	local definition = (output .. "\n"):match('compiler_type = "(.-)"\n')
	if not definition then
		return nil
	end
	return {
		definition = vim.split(definition, "\n", { plain = true }),
		size = output:match("byte%-size = (%d+)"),
		decl = output:match("decl = ([^,\n]+)"),
	}
end

---@param lines string[]
---@param title string
local function show(lines, title)
	local filetype = vim.bo.filetype
	if not vim.tbl_contains({ "c", "cpp", "rust" }, filetype) then
		filetype = "cpp"
	end
	vim.lsp.util.open_floating_preview(lines, filetype, {
		focus_id = FLOAT_ID,
		title = " " .. title .. " ",
		max_width = math.floor(vim.o.columns * 0.8),
		max_height = math.floor(vim.o.lines * 0.7),
	})
end

---@return dap.Session?
local function stopped_lldb_session()
	local session = dap.session()
	if not session or not session.current_frame then
		vim.notify("Debug: the program is not stopped at a breakpoint", vim.log.levels.WARN)
		return nil
	end
	if session.config.type ~= "lldb" then
		vim.notify(
			"Debug: types are shown through lldb-dap, and this session uses " .. session.config.type,
			vim.log.levels.WARN
		)
		return nil
	end
	return session
end

---@param session dap.Session
---@param expression string
---@param context "repl"|"hover"
---@param on_result fun(body: table)
---@param on_error fun(message: string)
local function evaluate(session, expression, context, on_result, on_error)
	session:request("evaluate", {
		expression = expression,
		context = context,
		frameId = session.current_frame.id,
	}, function(err, body)
		if err or not body then
			on_error(err and (err.message or tostring(err)) or "no answer")
			return
		end
		on_result(body)
	end)
end

---@param session dap.Session
---@param command string
---@param on_output fun(output: string)
local function lldb_command(session, command, on_output)
	evaluate(session, LLDB_COMMAND_PREFIX .. command, "repl", function(body)
		on_output(body.result or "")
	end, function(message)
		vim.notify(("Debug: %s failed: %s"):format(command, message), vim.log.levels.ERROR)
	end)
end

--- Every local and argument, struct fields expanded, each with its type, like
--- `(Point) p = { (int) x = 1 ... }`.
function M.show_frame()
	local session = stopped_lldb_session()
	if not session then
		return
	end
	lldb_command(session, "frame variable --show-types", function(output)
		local lines = vim.split(vim.trim(output), "\n", { plain = true })
		if #lines == 1 and lines[1] == "" then
			lines = { "(no variables in this frame)" }
		end
		show(lines, "Frame variables with types")
	end)
end

--- The full type name in `frame variable --raw-output --show-types` output, which
--- spells out default template arguments that the short display name leaves off.
---@param output string
---@param expression string the variable path that was printed
---@return string?
function M.raw_type_name(output, expression)
	return output:match("^%((.-)%) " .. vim.pesc(expression) .. " =")
end

--- Namespaces of the C++ and Rust standard libraries.
local STANDARD_LIBRARY_PREFIXES = { "std::", "alloc::", "core::" }

--- Library templates are hundreds of lines of internals; their contents are what helps.
---@param type_name string
---@return boolean
local function is_standard_library(type_name)
	for _, prefix in ipairs(STANDARD_LIBRARY_PREFIXES) do
		if vim.startswith(type_name, prefix) then
			return true
		end
	end
	return false
end

---@param found debug.TypeDefinition
---@return string[]
local function definition_lines(found)
	local lines = vim.list_extend({}, found.definition)
	local details = {}
	if found.size then
		table.insert(details, found.size .. " bytes")
	end
	if found.decl then
		table.insert(details, "declared at " .. vim.fn.fnamemodify(found.decl, ":t"))
	end
	if #details > 0 then
		vim.list_extend(lines, { "", "// " .. table.concat(details, ", ") })
	end
	return lines
end

---@param session dap.Session
---@param type_name string
---@param on_missing fun()
local function show_definition(session, type_name, on_missing)
	lldb_command(session, ("image lookup --type '%s'"):format(type_name), function(output)
		local found = M.parse_type_lookup(output)
		if found then
			show(definition_lines(found), type_name)
		else
			on_missing()
		end
	end)
end

---@param type_name string
local function report_missing(type_name)
	vim.notify(("Debug: no definition found for type %s"):format(type_name), vim.log.levels.WARN)
end

--- A template's display name can omit default arguments (Stack<int> for
--- Stack<int, Alloc<int>>), which the lookup needs, so retry with the full name.
---@param session dap.Session
---@param expression string
---@param type_name string
local function show_definition_by_full_name(session, expression, type_name)
	lldb_command(session, ("frame variable --raw-output --depth 0 --show-types %s"):format(expression), function(output)
		local full_name = M.raw_type_name(output, expression)
		if not full_name or M.underlying_type(full_name) == type_name then
			report_missing(type_name)
			return
		end
		show_definition(session, M.underlying_type(full_name), function()
			report_missing(type_name)
		end)
	end)
end

---@param session dap.Session
---@param expression string
---@param type_name string
local function show_variable_type(session, expression, type_name)
	if is_standard_library(type_name) then
		vim.notify(
			("Debug: %s is a standard library type; <leader>dt shows what it holds"):format(type_name),
			vim.log.levels.INFO
		)
		return
	end
	show_definition(session, type_name, function()
		show_definition_by_full_name(session, expression, type_name)
	end)
end

---@return string
local function expression_at_cursor()
	if vim.fn.mode():match("[vV]") then
		local selected = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = vim.fn.mode() })
		return vim.trim(table.concat(selected, "\n"))
	end
	return vim.fn.expand("<cexpr>")
end

--- The definition of the type of the variable under the cursor (or selected), or
--- of the type named there when it is not a variable.
function M.show_type_definition()
	local session = stopped_lldb_session()
	if not session then
		return
	end
	local expression = expression_at_cursor()
	if expression == "" then
		return
	end
	evaluate(session, expression, "hover", function(body)
		local type_name = body.type and M.underlying_type(body.type) or ""
		if type_name == "" then
			type_name = expression
		end
		show_variable_type(session, expression, type_name)
	end, function()
		show_definition(session, expression, function()
			vim.notify(
				("Debug: %s is not a variable or a type in this program"):format(expression),
				vim.log.levels.WARN
			)
		end)
	end)
end

return M
