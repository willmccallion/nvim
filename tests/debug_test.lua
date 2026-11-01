--- The debugger's logic that needs no running session: reading ELF files and lldb's output.

local h = require("helpers")

local function elf()
	return require("plugins.debug.elf")
end

local function types()
	package.loaded["dap"] = package.loaded["dap"] or {}
	return require("plugins.debug.types")
end

---@param flags string[]
---@return string path
local function compiled(flags)
	local dir = h.temp_dir()
	local source = dir .. "/a.c"
	vim.fn.writefile({ "int main(void) { return 0; }" }, source)
	local output = dir .. "/a"
	local result = vim.system(vim.list_extend({ "cc", source, "-o", output }, flags), { text = true }):wait()
	assert(result.code == 0, result.stderr)
	return output
end

local tests = {}

function tests.a_program_built_with_g_has_debug_info()
	h.assert_equal(elf().debug_info(compiled({ "-g" })), "present", "debug info")
end

function tests.a_stripped_program_has_none()
	h.assert_equal(elf().debug_info(compiled({ "-s" })), "missing", "debug info")
end

function tests.anything_but_an_elf_file_is_unknown()
	local dir = h.temp_dir()
	vim.fn.writefile({ "#!/bin/sh" }, dir .. "/script")
	h.assert_equal(elf().debug_info(dir .. "/script"), "unknown", "script")
	h.assert_equal(elf().debug_info(dir .. "/missing"), "unknown", "missing file")
end

function tests.a_truncated_elf_header_is_not_well_formed()
	local function read_only(bytes)
		return function(offset, length)
			return bytes:sub(offset + 1, offset + length)
		end
	end
	h.assert_equal(elf().section_names(read_only("\127ELF")), nil, "too short")
	h.assert_equal(elf().section_names(read_only("\127ELF\9" .. ("\0"):rep(0x3F))), nil, "unknown class")
end

function tests.a_header_with_no_sections_has_no_names()
	local header = "\127ELF\2\1" .. ("\0"):rep(0x3A)
	local names = elf().section_names(function(offset, length)
		return header:sub(offset + 1, offset + length)
	end)
	h.assert_equal(names, {}, "names")
end

function tests.the_underlying_type_drops_pointers_references_and_qualifiers()
	local cases = {
		["const Shape &"] = "Shape",
		["Point *"] = "Point",
		["struct Point **"] = "Point",
		["const volatile struct Foo *"] = "Foo",
		["int[3]"] = "int",
		["class Bar const"] = "Bar",
		["  Baz  "] = "Baz",
		["ns::Type"] = "ns::Type",
	}
	for input, expected in pairs(cases) do
		h.assert_equal(types().underlying_type(input), expected, input)
	end
end

function tests.a_type_lookup_gives_its_definition_size_and_location()
	local output = table.concat({
		"Best match found in /a.out:",
		'id = {0x1}, name = "Point", byte-size = 8, decl = point.h:3:8, compiler_type = "struct Point {',
		"    int x;",
		'}"',
	}, "\n")
	h.assert_equal(types().parse_type_lookup(output), {
		definition = { "struct Point {", "    int x;", "}" },
		size = "8",
		decl = "point.h:3:8",
	}, "parsed")
end

function tests.a_type_lookup_with_no_definition_finds_nothing()
	h.assert_equal(types().parse_type_lookup("no type was found"), nil, "parsed")
end

function tests.the_raw_type_name_comes_from_the_line_for_that_variable()
	h.assert_equal(
		types().raw_type_name("(std::vector<int, alloc>) v = size=1", "v"),
		"std::vector<int, alloc>",
		"type"
	)
	h.assert_equal(types().raw_type_name("(int) a.b = 1", "a.b"), "int", "path with a dot")
	h.assert_equal(types().raw_type_name("(int) other = 1", "v"), nil, "another variable")
end

return tests
