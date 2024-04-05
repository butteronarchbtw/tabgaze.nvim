local M = {}
local contents = {}
local ns_id = vim.api.nvim_create_namespace("tabgaze")
local bufnr = nil;
local win_id = nil;
local prev_cursor_pos = {1, 1};

local function close_menu()
    vim.api.nvim_win_close(win_id, true)
    prev_cursor_pos = {1, 1};
    win_id = nil
    bufnr = nil
end

local last_heading_extmark = -1;
local function highlight_current_row_heading(row)
    if last_heading_extmark > 0 then
        vim.api.nvim_buf_del_extmark(bufnr, ns_id, last_heading_extmark)
    end
    last_heading_extmark = vim.api.nvim_buf_set_extmark(
    bufnr,
    ns_id,
    row - 1,
    0,
    {
        hl_group = "Directory",
        end_row = row - 1,
        end_col = #contents[row]
    })
end

local function is_tabname_line(i)
	local pattern = "^[%s#%+>].*"
    return string.match(contents[i], pattern) == nil
end

function M.toggle_window()
    if win_id ~= nil and vim.api.nvim_win_is_valid(win_id) then
        close_menu()
        return
    end

    local width = 60
    local height = 10

    contents = {}
    local Tabs = vim.api.nvim_exec2("tabs", { output = true })
    for w in string.gmatch(Tabs.output, "[^\n]+") do
        table.insert(contents, w);
    end

    local win_config = {
        relative = "editor",
        style="minimal",
        border = "rounded",
        title = "TabGaze",
        title_pos="center",
        row = (vim.o.lines - height) / 2,
        col = (vim.o.columns - width) / 2,
        width = width,
        height = height
    };

    bufnr = vim.api.nvim_create_buf(false, false)
    win_id = vim.api.nvim_open_win(bufnr, false, win_config)
    vim.api.nvim_buf_set_name(bufnr, "tabgaze")
    vim.api.nvim_buf_set_option(bufnr, "buftype", "nowrite")
    vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
    vim.api.nvim_buf_set_lines(bufnr, 0, #contents, false, contents)

    for line=1,#contents do
        if not is_tabname_line(line) then
            vim.api.nvim_buf_set_extmark(bufnr, ns_id, line - 1, 0, {
                hl_group = "Comment",
                end_row = line - 1,
                end_col = #contents[line],
            })
        end
    end
    if #contents > 0 then
        highlight_current_row_heading(1)
    end 
    -- INFO: modifiable has to always be behind set_lines
    vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
    vim.api.nvim_buf_set_keymap(bufnr, "n", "<CR>", ":lua require('tabgaze').select_item()<CR>", {silent = true})
    vim.api.nvim_buf_set_keymap(bufnr, "n", "q", ":lua require('tabgaze').toggle_window()<CR>", {silent = true})
    vim.api.nvim_buf_set_keymap(bufnr, "n", "<ESC>", ":lua require('tabgaze').toggle_window()<CR>", {silent = true})
    vim.api.nvim_set_current_win(win_id)

    vim.cmd(string.format("autocmd CursorMoved <buffer=%s> lua require('tabgaze').on_cursor_moved()", bufnr))
    -- very specific bug, that if you use :q to leave the window, it does not reset the
    -- cursor pos
    vim.cmd(string.format("autocmd BufLeave <buffer=%s> lua require('tabgaze').toggle_window()", bufnr))
end

function M.on_cursor_moved()
    local prev_row, _ = unpack(prev_cursor_pos)
    local new_row, new_col = unpack(vim.api.nvim_win_get_cursor(win_id))
    if prev_row - new_row < 0 then
        -- down
        M.set_cursor_on_next_item()
    elseif prev_row - new_row > 0 then
        -- up
        M.set_cursor_on_prev_item()
    else
        -- horizontal
        print("horizontal")
    end
    -- cursor can be moved beforehand
    new_row, new_col = unpack(vim.api.nvim_win_get_cursor(win_id))
    prev_cursor_pos = {new_row, new_col}
end

function M.select_item()
    local idx = vim.fn.line(".");
    local selected = contents[idx];
    if is_tabname_line(idx) then
        local num_count = 0;
        -- this just counts how many digits there are in the tab name
        for i=1,#selected do
            if tonumber(string.sub(selected, i, i)) then
                num_count = num_count + 1
            end
        end
        local tab_nr = string.sub(selected, -num_count)
        close_menu()
        vim.cmd("tabn " .. tab_nr)
    end
end


function M.set_cursor_on_next_item()
    local old_idx = prev_cursor_pos[1]
    local new_idx = old_idx
    for i = old_idx + 1,#contents  do
        if is_tabname_line(i) then
            new_idx = i
            break
        end
    end
    vim.fn.cursor({new_idx, 1})
    highlight_current_row_heading(new_idx)
end

function M.set_cursor_on_prev_item()
    local old_idx = prev_cursor_pos[1]
    local new_idx = old_idx
    for i = old_idx - 1,1,-1  do
        if is_tabname_line(i) then
            new_idx = i
            break
        end
    end
    vim.fn.cursor({new_idx, 1})
    highlight_current_row_heading(new_idx)
end

function M.setup()
    vim.cmd("command! Tabgaze lua require('tabgaze').toggle_window()")
end

return M
