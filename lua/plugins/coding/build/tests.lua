--- Pure command building for running one test, or one module's tests, from the
--- place found under the cursor. Performs no I/O.

local M = {}

---@class build.RustTarget
---@field flags string[] cargo's target selection, empty to test every target
---@field modules string[] module path the file itself stands for

--- Cargo's own target layout: src/bin/<name> and tests/<name> are targets of their
--- own, and every other file under src/ is a module of the library or main binary.
---@param relative_file string relative to the package root (the nearest Cargo.toml)
---@return build.RustTarget? nil for files no test target is built from
function M.rust_target(relative_file)
	local parts = vim.split((relative_file:gsub("%.rs$", "")), "/", { plain = true })
	local flags, modules
	if parts[1] == "src" and parts[2] == "bin" and parts[3] then
		flags, modules = { "--bin", parts[3] }, vim.list_slice(parts, 4)
	elseif parts[1] == "src" and parts[2] then
		flags, modules = {}, vim.list_slice(parts, 2)
		if #modules == 1 and modules[1] == "lib" then
			modules = {}
		end
	elseif parts[1] == "tests" and parts[2] then
		flags, modules = { "--test", parts[2] }, vim.list_slice(parts, 3)
	else
		return nil
	end

	if #modules == 1 and modules[1] == "main" then
		modules = {}
	end
	if modules[#modules] == "mod" then
		table.remove(modules)
	end
	return { flags = flags, modules = modules }
end

---@class build.RustTest
---@field manifest? string Cargo.toml of the package, relative to the workspace root; nil when it is the root's own
---@field target build.RustTarget
---@field modules string[] inline `mod` blocks around the cursor, outermost first
---@field name? string the test function, nil for every test in the modules

--- The libtest filter: a test's full path matched exactly, or a module's path with
--- a trailing `::` matched as a prefix of every test in it.
---@param test build.RustTest
---@return string filter
---@return boolean exact
function M.rust_filter(test)
	local path = vim.list_extend(vim.list_extend({}, test.target.modules), test.modules)
	if test.name then
		table.insert(path, test.name)
		return table.concat(path, "::"), true
	end
	return table.concat(path, "::") .. "::", false
end

---@param test build.RustTest
---@return build.Command
function M.rust_command(test)
	local args = { "cargo", "test" }
	if test.manifest then
		vim.list_extend(args, { "--manifest-path", vim.fn.shellescape(test.manifest) })
	end
	vim.list_extend(args, test.target.flags)
	table.insert(args, "--")
	local filter, exact = M.rust_filter(test)
	if exact then
		table.insert(args, "--exact")
	end
	table.insert(args, filter)
	return { cmd = table.concat(args, " "), compiler = "cargo", label = exact and filter or filter .. "*" }
end

---@class build.PythonTest
---@field file string relative to the directory pytest runs in
---@field classes string[] enclosing Test classes, outermost first
---@field name? string the test function, nil for every test in the innermost class

---@param test build.PythonTest
---@return string
function M.pytest_node_id(test)
	local parts = { test.file }
	vim.list_extend(parts, test.classes)
	if test.name then
		table.insert(parts, test.name)
	end
	return table.concat(parts, "::")
end

--- `python3 -m pytest`, as `p test` runs it, so the dev shell's pytest is the one used.
---@param test build.PythonTest
---@return build.Command
function M.pytest_command(test)
	local node_id = M.pytest_node_id(test)
	return { cmd = "python3 -m pytest " .. vim.fn.shellescape(node_id), compiler = "pytest", label = node_id }
end

--- A libtest filter matching nothing still passes, so the count is how a wrong guess
--- at the test's path shows up.
---@param output string[]
---@return integer
function M.cargo_tests_run(output)
	local total = 0
	for _, line in ipairs(output) do
		local count = line:match("^running (%d+) tests?$")
		if count then
			total = total + tonumber(count)
		end
	end
	return total
end

return M
