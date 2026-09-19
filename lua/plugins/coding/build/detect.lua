--- Pure build-system detection and default commands.
--- Given the marker files found in each directory from a buffer upward, picks
--- the project root and build system. Performs no I/O.

local M = {}

---@alias build.Kind "cargo" | "cmake" | "make"

---@class build.Project
---@field root string directory every command runs in
---@field kind? build.Kind nil when no build system was detected

---@class build.DirListing
---@field dir string
---@field files table<string, true> marker file names present in `dir`

---@class build.Command
---@field cmd string shell command, run from the project root
---@field compiler? string :compiler plugin whose 'errorformat' parses the output

---@class (private) build.Marker
---@field kind build.Kind
---@field files string[]
---@field use_outermost boolean

--- Checked in this order within a single directory, so Cargo beats CMake beats Make.
--- CMake and Cargo use the outermost match because nested CMakeLists.txt files are
--- pulled in by add_subdirectory and nested Cargo.toml files belong to a workspace.
---@type build.Marker[]
local MARKERS = {
	{ kind = "cargo", files = { "Cargo.toml" }, use_outermost = true },
	{ kind = "cmake", files = { "CMakeLists.txt" }, use_outermost = true },
	{ kind = "make", files = { "Makefile", "makefile", "GNUmakefile" }, use_outermost = false },
}

---@type table<build.Kind, build.Command[]>
local COMMANDS = {
	cargo = {
		{ cmd = "cargo build", compiler = "cargo" },
		{ cmd = "cargo run", compiler = "cargo" },
		{ cmd = "cargo test", compiler = "cargo" },
		{ cmd = "cargo clippy", compiler = "cargo" },
	},
	cmake = {
		{ cmd = "cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON && cmake --build build", compiler = "gcc" },
		{ cmd = "cmake --build build", compiler = "gcc" },
		{ cmd = "ctest --test-dir build --output-on-failure", compiler = "gcc" },
		{ cmd = "cmake --build build --target clean", compiler = "gcc" },
	},
	make = {
		{ cmd = "make", compiler = "gcc" },
		{ cmd = "make clean", compiler = "gcc" },
	},
}

--- Every marker file name, for the caller to look for on disk.
---@type string[]
M.marker_files = {}
for _, marker in ipairs(MARKERS) do
	vim.list_extend(M.marker_files, marker.files)
end

---@param listing build.DirListing
---@param marker build.Marker
---@return boolean
local function has_marker(listing, marker)
	for _, file in ipairs(marker.files) do
		if listing.files[file] then
			return true
		end
	end
	return false
end

---@param listings build.DirListing[]
---@param from integer index of the nearest listing with the marker
---@param marker build.Marker
---@return string
local function outermost_dir_with(listings, from, marker)
	local dir = listings[from].dir
	for i = from + 1, #listings do
		if has_marker(listings[i], marker) then
			dir = listings[i].dir
		end
	end
	return dir
end

--- The nearest directory with any marker decides the build system.
---@param listings build.DirListing[] ordered from the buffer's directory upward
---@param fallback_root string root used when no marker is found
---@return build.Project
function M.project(listings, fallback_root)
	for i, listing in ipairs(listings) do
		for _, marker in ipairs(MARKERS) do
			if has_marker(listing, marker) then
				local root = marker.use_outermost and outermost_dir_with(listings, i, marker) or listing.dir
				return { root = root, kind = marker.kind }
			end
		end
	end
	return { root = fallback_root }
end

--- Detected commands for a project; the first is the default.
---@param project build.Project
---@return build.Command[]
function M.commands(project)
	if not project.kind then
		return {}
	end
	return vim.deepcopy(COMMANDS[project.kind])
end

return M
