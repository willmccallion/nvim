--- Tells whether an ELF executable carries DWARF debug info, by reading its section
--- names. Anything that is not ELF (a Mach-O binary on the Mac, a script) is
--- reported as unknown, so callers only act on a definite answer.

local M = {}

---@alias elf.DebugInfo "present" | "missing" | "unknown"

local DEBUG_INFO_SECTIONS = { [".debug_info"] = true, [".zdebug_info"] = true }

--- Field offsets that differ between 32- and 64-bit ELF files.
local LAYOUT = {
	[1] = {
		shoff = { 0x20, 4 },
		shentsize = { 0x2E, 2 },
		shnum = { 0x30, 2 },
		shstrndx = { 0x32, 2 },
		sh_link = { 0x18, 4 },
		sh_offset = { 0x10, 4 },
		sh_size = { 0x14, 4 },
	},
	[2] = {
		shoff = { 0x28, 8 },
		shentsize = { 0x3A, 2 },
		shnum = { 0x3C, 2 },
		shstrndx = { 0x3E, 2 },
		sh_link = { 0x28, 4 },
		sh_offset = { 0x18, 8 },
		sh_size = { 0x20, 8 },
	},
}

--- e_shstrndx when the real index is too big for it and lives in section 0's sh_link.
local SHN_XINDEX = 0xFFFF

---@param bytes string
---@param offset integer zero-based
---@param size integer
---@param little_endian boolean
---@return integer
local function read_uint(bytes, offset, size, little_endian)
	local value = 0
	for i = 0, size - 1 do
		local index = little_endian and (offset + size - i) or (offset + i + 1)
		value = value * 256 + bytes:byte(index)
	end
	return value
end

--- The names of every section, read through `read(offset, length)`.
---@param read fun(offset: integer, length: integer): string?
---@return string[]? nil when the data is not a well-formed ELF file
function M.section_names(read)
	local ident = read(0, 0x40)
	if not ident or #ident < 0x34 or ident:sub(1, 4) ~= "\127ELF" then
		return nil
	end
	local layout = LAYOUT[ident:byte(5)]
	local little_endian = ident:byte(6) == 1
	if not layout or #ident < layout.shstrndx[1] + 2 then
		return nil
	end
	local function field(bytes, spec, base)
		return read_uint(bytes, (base or 0) + spec[1], spec[2], little_endian)
	end

	local shoff = field(ident, layout.shoff)
	local shentsize = field(ident, layout.shentsize)
	if shoff == 0 or shentsize == 0 then
		return {}
	end
	local first_header = read(shoff, shentsize)
	if not first_header or #first_header < shentsize then
		return nil
	end
	-- Files with too many sections for the header's fields keep the real values in section 0.
	local shnum = field(ident, layout.shnum)
	if shnum == 0 then
		shnum = field(first_header, layout.sh_size)
	end
	local shstrndx = field(ident, layout.shstrndx)
	if shstrndx == SHN_XINDEX then
		shstrndx = field(first_header, layout.sh_link)
	end
	if shstrndx >= shnum then
		return nil
	end

	local headers = read(shoff, shnum * shentsize)
	if not headers or #headers < shnum * shentsize then
		return nil
	end
	local strtab_base = shstrndx * shentsize
	local strtab = read(field(headers, layout.sh_offset, strtab_base), field(headers, layout.sh_size, strtab_base))
	if not strtab then
		return nil
	end

	local names = {}
	for i = 0, shnum - 1 do
		local name_offset = read_uint(headers, i * shentsize, 4, little_endian)
		local name = strtab:match("^[^%z]*", name_offset + 1)
		if name then
			table.insert(names, name)
		end
	end
	return names
end

---@param path string
---@return elf.DebugInfo
function M.debug_info(path)
	local fd = vim.uv.fs_open(path, "r", 0)
	if not fd then
		return "unknown"
	end
	local names = M.section_names(function(offset, length)
		return vim.uv.fs_read(fd, length, offset)
	end)
	vim.uv.fs_close(fd)
	if not names then
		return "unknown"
	end
	for _, name in ipairs(names) do
		if DEBUG_INFO_SECTIONS[name] then
			return "present"
		end
	end
	return "missing"
end

return M
