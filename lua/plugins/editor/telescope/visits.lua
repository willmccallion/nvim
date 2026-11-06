--- Remembers when files were visited, across sessions, so the file picker can rank the
--- files you open often and lately first. Kept in stdpath("state") by absolute path,
--- so nothing is written into repositories.

local json_file = require("lib.json_file")

local STORE_PATH = vim.fs.joinpath(vim.fn.stdpath("state"), "file_visits.json")

local HOUR_S = 3600
local DAY_S = 24 * HOUR_S

--- Entering a file again within this counts as the same visit, so flipping between two
--- files doesn't make them outrank everything.
local REVISIT_GAP_S = 10 * 60
local KEPT_VISITS = 10
local FORGET_AFTER_S = 90 * DAY_S

--- How much a visit counts by its age, the newest first.
local AGE_WEIGHTS = {
	{ within = 4 * HOUR_S, weight = 100 },
	{ within = DAY_S, weight = 70 },
	{ within = 3 * DAY_S, weight = 50 },
	{ within = 7 * DAY_S, weight = 30 },
	{ within = 30 * DAY_S, weight = 10 },
}

--- The most visited file's match score is cut by this share; others by less.
local MOST_VISITED_BOOST = 0.5

local M = {}

---@param visits integer[] times in seconds
---@param now integer
---@return number
function M.score(visits, now)
	local total = 0
	for _, visit in ipairs(visits) do
		for _, age in ipairs(AGE_WEIGHTS) do
			if now - visit <= age.within then
				total = total + age.weight
				break
			end
		end
	end
	return total
end

--- A file's visits with one at now added, unless the last is too recent, keeping only
--- the newest few and none past forgetting.
---@param visits integer[] oldest first
---@param now integer
---@return integer[]
function M.with_visit(visits, now)
	local kept = vim.tbl_filter(function(visit)
		return now - visit <= FORGET_AFTER_S
	end, visits)
	if #kept == 0 or now - kept[#kept] >= REVISIT_GAP_S then
		table.insert(kept, now)
	end
	return vim.list_slice(kept, math.max(#kept - KEPT_VISITS + 1, 1))
end

--- A sorter score, where lower is better and -1 filters the entry out, made better by
--- a share of up to MOST_VISITED_BOOST for a file with share of the top visit score.
---@param score number
---@param share number between 0 and 1
---@return number
function M.favoured(score, share)
	if score < 0 then
		return score
	end
	return score * (1 - MOST_VISITED_BOOST * share)
end

--- Each visited file's score as a share of the highest, by absolute path.
---@param now integer
---@return table<string, number>
local function shares(now)
	local scores, highest = {}, 0
	for path, visits in pairs(json_file.read(STORE_PATH) or {}) do
		scores[path] = M.score(visits, now)
		highest = math.max(highest, scores[path])
	end
	if highest == 0 then
		return {}
	end
	return vim.tbl_map(function(score)
		return score / highest
	end, scores)
end

--- Makes a sorter rank the files under folder you visit often and lately higher.
---@param sorter table a Telescope sorter, changed in place
---@param folder string what the entries' paths are relative to
---@return table sorter
function M.favour_visited(sorter, folder)
	local share_of = shares(os.time())
	local scoring_function = sorter.scoring_function
	sorter.scoring_function = function(self, prompt, line, entry, ...)
		local score = scoring_function(self, prompt, line, entry, ...)
		local share = entry and share_of[vim.fs.joinpath(folder, entry.value)]
		return share and M.favoured(score, share) or score
	end
	return sorter
end

---@param path string absolute
local function record(path)
	local all = json_file.read(STORE_PATH)
	if not all then
		return
	end
	all[path] = M.with_visit(all[path] or {}, os.time())
	vim.fn.mkdir(vim.fs.dirname(STORE_PATH), "p")
	json_file.write(STORE_PATH, all)
end

---@type table<string, integer> when each file was last recorded this session
local recorded_at = {}

vim.api.nvim_create_autocmd("BufEnter", {
	desc = "Remember the visit for the file picker's ranking",
	group = vim.api.nvim_create_augroup("file-visits", { clear = true }),
	callback = function(ev)
		local path = vim.api.nvim_buf_get_name(ev.buf)
		if vim.bo[ev.buf].buftype ~= "" or path == "" or vim.fn.filereadable(path) == 0 then
			return
		end
		local now = os.time()
		if recorded_at[path] and now - recorded_at[path] < REVISIT_GAP_S then
			return
		end
		recorded_at[path] = now
		record(path)
	end,
})

return M
