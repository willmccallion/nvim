--- The panel's pure logic, without a repo or a window.

local function assert_equal(actual, expected, what)
	if not vim.deep_equal(actual, expected) then
		error(("%s: expected %s, got %s"):format(what, vim.inspect(expected), vim.inspect(actual)), 2)
	end
end

local function span(old_line, line)
	return { require("plugins.editor.git_changes.tint").changed_span(old_line, line) }
end

local function changes()
	return require("plugins.editor.git_changes.changes")
end

local function render()
	return require("plugins.editor.git_changes.render")
end

local tests = {}

function tests.identical_lines_have_no_changed_span()
	assert_equal(span("same", "same"), { nil, 0, 0 }, "span")
end

function tests.changed_span_is_what_lies_between_the_common_start_and_end()
	assert_equal(span("abcXdef", "abcYYdef"), { 3, 5, 4 }, "span")
end

function tests.changed_span_of_an_addition_at_the_end_starts_after_the_old_line()
	assert_equal(span("abc", "abcdef"), { 3, 6, 3 }, "span")
end

function tests.changed_span_keeps_the_common_start_and_end_from_overlapping()
	assert_equal(span("aa", "aaa"), { 2, 3, 2 }, "span")
end

function tests.panel_width_has_a_floor_and_a_ceiling()
	assert_equal(render().width({ lines = { "x" } }), 25, "narrow content")
	assert_equal(render().width({ lines = { ("x"):rep(30) } }), 32, "content plus padding")
	assert_equal(render().width({ lines = { ("x"):rep(200) } }), 50, "wide content")
end

function tests.a_folder_gets_one_header_above_its_files()
	local content = render().content({
		{ path = "root.txt", status = "M" },
		{ path = "lib/one.txt", status = "A" },
		{ path = "lib/two.txt", status = "D" },
	})
	assert_equal(content.lines[2], "lib/", "header")
	assert_equal(#content.lines, 4, "lines")
	assert_equal(content.files_by_line[2], nil, "header is not a file")
	assert_equal(content.files_by_line[4].path, "lib/two.txt", "row of the last file")
end

function tests.a_title_and_an_empty_list_are_notes_with_no_files()
	local content = render().content({}, "since abc")
	assert_equal(content.lines, { "since abc", "No changes" }, "lines")
	assert_equal(content.files_by_line, {}, "files")
end

function tests.line_of_falls_back_to_the_first_file()
	local files_by_line = { [2] = { path = "a" }, [4] = { path = "b" } }
	assert_equal(render().line_of(files_by_line, "b"), 4, "found")
	assert_equal(render().line_of(files_by_line, "missing"), 2, "fallback")
	assert_equal(render().line_of({}, "b"), nil, "empty")
end

function tests.the_end_of_a_range_names_a_commit_or_the_staged_files()
	local commit = changes().commit_end("abc123")
	assert_equal(changes().end_name(commit), "abc123", "commit name")
	assert_equal(changes().end_source(commit), "abc123:", "commit source")
	assert_equal(changes().end_name(changes().STAGED), "staged", "staged name")
	assert_equal(changes().end_source(changes().STAGED), ":", "staged source")
end

function tests.only_a_range_with_an_end_shows_copies()
	assert_equal(changes().shows_copies(nil), false, "uncommitted")
	assert_equal(changes().shows_copies({ commit = "a", summary = "a" }), false, "since a commit")
	assert_equal(changes().shows_copies({ commit = "a", summary = "a", to = changes().STAGED }), true, "staged")
end

function tests.titles_name_the_range()
	assert_equal(changes().title_of(nil), nil, "uncommitted")
	assert_equal(changes().title_of({ commit = "a", summary = "a one" }), "since a one", "since")
	local range = { commit = "a", summary = "a one", label = "empty", to = changes().commit_end("b") }
	assert_equal(changes().title_of(range), "empty → b", "label wins over the commit")
end

function tests.the_nothing_message_fits_what_was_asked_for()
	assert_equal(changes().nothing_message(nil), "No changes", "uncommitted")
	assert_equal(changes().nothing_message({ commit = "a", summary = "a one" }), "No changes since a one", "since")
	local staged = { commit = "a", summary = "a one", to = changes().STAGED }
	assert_equal(changes().nothing_message(staged), "Nothing staged", "staged")
end

return tests
