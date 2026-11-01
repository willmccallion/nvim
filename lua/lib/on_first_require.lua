--- Runs a plugin's setup the first time anything requires one of its modules, so
--- every way in (a key, a command, another plugin's picker) finds it configured.

---@param name string the module being required
---@param modules string[]
---@return boolean
local function belongs_to(name, modules)
	for _, module in ipairs(modules) do
		if name == module or vim.startswith(name, module .. ".") then
			return true
		end
	end
	return false
end

---@param loader function
local function remove_loader(loader)
	for index, candidate in ipairs(package.loaders) do
		if candidate == loader then
			table.remove(package.loaders, index)
			return
		end
	end
end

---@param modules string[] top-level module names; their submodules count too
---@param setup fun()
return function(modules, setup)
	local function run_setup_first(name)
		if not belongs_to(name, modules) then
			return nil
		end
		remove_loader(run_setup_first)
		setup()
		-- Here rather than in the loader: require() marks the module as loading in between.
		local module = require(name)
		return function()
			return module
		end
	end
	table.insert(package.loaders, 1, run_setup_first)
end
