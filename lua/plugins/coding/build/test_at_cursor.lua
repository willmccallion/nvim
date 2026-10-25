--- Finds the test the cursor is in from the buffer's syntax tree: a Rust #[test]
--- function or pytest test function, else the inline module or Test class around
--- the cursor, whose tests are then run together.

local M = {}

---@param node TSNode
---@param buf integer
---@return string?
local function name_of(node, buf)
	local name = node:field("name")[1]
	return name and vim.treesitter.get_node_text(name, buf) or nil
end

--- #[test], and the attributes like #[tokio::test] that wrap it, end their path in `test`.
---@param attribute_item TSNode
---@param buf integer
---@return boolean
local function is_test_attribute(attribute_item, buf)
	local attribute = attribute_item:named_child(0)
	local path = attribute and attribute:named_child(0)
	if not path then
		return false
	end
	local text = vim.treesitter.get_node_text(path, buf)
	return text == "test" or vim.endswith(text, "::test")
end

--- Attributes are the function's preceding siblings, with doc comments among them.
---@param function_item TSNode
---@param buf integer
---@return boolean
local function is_rust_test(function_item, buf)
	local sibling = function_item:prev_named_sibling()
	while sibling do
		local kind = sibling:type()
		if kind == "attribute_item" then
			if is_test_attribute(sibling, buf) then
				return true
			end
		elseif kind ~= "line_comment" and kind ~= "block_comment" then
			return false
		end
		sibling = sibling:prev_named_sibling()
	end
	return false
end

---@class build.TestPlace
---@field scopes string[] enclosing modules or classes, outermost first
---@field name? string the test function, nil when the cursor is only in a scope

--- Walks up from the cursor; a function nested in a test (a helper defined inside
--- it) is passed over, so the test itself is found.
---@param buf integer
---@param is_test fun(function_node: TSNode): boolean
---@param function_type string
---@param scope_type string
---@param is_scope fun(scope_node: TSNode): boolean
---@return build.TestPlace?
local function find_place(buf, is_test, function_type, scope_type, is_scope)
	local parser = vim.treesitter.get_parser(buf, nil, { error = false })
	if not parser then
		return nil
	end
	parser:parse()
	local node = vim.treesitter.get_node({ bufnr = buf, ignore_injections = true })
	local name
	local scopes = {}
	while node do
		local kind = node:type()
		if kind == function_type and not name and #scopes == 0 and is_test(node) then
			name = name_of(node, buf)
		elseif kind == scope_type and is_scope(node) then
			table.insert(scopes, 1, name_of(node, buf))
		end
		node = node:parent()
	end
	if not name and #scopes == 0 then
		return nil
	end
	return { scopes = scopes, name = name }
end

---@param buf integer
---@return build.TestPlace?
function M.rust(buf)
	local function is_test(node)
		return is_rust_test(node, buf)
	end
	local function is_module()
		return true
	end
	return find_place(buf, is_test, "function_item", "mod_item", is_module)
end

--- pytest's default discovery: test* functions, inside Test* classes when in one.
---@param buf integer
---@return build.TestPlace?
function M.python(buf)
	local function is_test(node)
		return vim.startswith(name_of(node, buf) or "", "test")
	end
	local function is_test_class(node)
		return vim.startswith(name_of(node, buf) or "", "Test")
	end
	return find_place(buf, is_test, "function_definition", "class_definition", is_test_class)
end

return M
