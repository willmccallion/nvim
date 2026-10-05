--- nixd LSP config for Nix.
--- Formatting is handled by conform (nixfmt), not the server.
--- In a flake that defines nixosConfigurations.<this host>, nixd completes and
--- documents that system's NixOS and home-manager options, evaluated from the
--- flake itself; any other flake or directory gets nixd's defaults.

--- Nix expressions for nixd's nixpkgs and options settings. Each falls back to an
--- empty value rather than an evaluation error when the flake lacks the attribute.
---@param flake_root string
---@param host string
---@return table
local function flake_settings(flake_root, host)
	local flake = ('(builtins.getFlake "%s")'):format(flake_root)
	local system = ('%s.nixosConfigurations."%s"'):format(flake, host)
	return {
		nixpkgs = { expr = ("import (%s.inputs.nixpkgs or <nixpkgs>) { }"):format(flake) },
		options = {
			nixos = { expr = ("%s.options or { }"):format(system) },
			home_manager = {
				expr = ("let system = %s or null; in "):format(system)
					.. 'if system == null || !(system.options ? "home-manager") then { } '
					.. "else system.options.home-manager.users.type.getSubOptions [ ]",
			},
		},
	}
end

---@type vim.lsp.Config
return {
	cmd = { "nixd" },
	filetypes = { "nix" },
	root_markers = { "flake.nix", ".git" },
	settings = { nixd = {} },
	before_init = function(_, config)
		local root = config.root_dir
		if not root or not vim.uv.fs_stat(vim.fs.joinpath(root, "flake.nix")) then
			return
		end
		-- Mutated in place: the client already holds this table and sends it as is.
		config.settings.nixd = flake_settings(root, vim.uv.os_gethostname())
	end,
}
