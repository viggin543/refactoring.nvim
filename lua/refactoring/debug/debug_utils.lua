local M = {}

local ts = vim.treesitter
local iter = vim.iter
local api = vim.api

---@param refactor Refactor
---@param point RefactorPoint
function M.get_debug_path(refactor, point)
    local node = assert(ts.get_node({
        bufnr = refactor.bufnr,
        pos = { point.row - 1, point.col },
    }))
    local debug_path = refactor.ts:get_debug_path(node)

    return iter(debug_path):map(tostring):rev():join("#")
end

---@param refactor Refactor
---@param opts {below: boolean}
---@return RefactorPoint insert_pos
---@return RefactorPoint path_pos
---@return TSNode? current_statement
function M.get_debug_points(refactor, opts)
    local cursor = refactor.cursor
    local current_line = api.nvim_buf_get_lines(
        refactor.bufnr,
        cursor.row - 1,
        cursor.row,
        true
    )[1]
    local _, non_white_space = current_line:find("^%s*()")

    local range =
        { cursor.row - 1, non_white_space, cursor.row - 1, non_white_space + 1 }
    local language_tree = refactor.ts.language_tree:language_for_range(range)

    assert(language_tree)
    local current =
        language_tree:named_node_for_range(range, { ignore_injections = false })
    assert(current)
    -- TODO: make this use nested languages
    local statements = refactor.ts:get_statements(refactor.root)
    local is_statement = false
    while current and not is_statement do
        is_statement = iter(statements):any(function(node)
            return node:equal(current)
        end)

        if not is_statement then
            current = current:parent()
        end
    end

    local insert_pos = cursor:clone()
    local path_pos = cursor:clone()
    if current then
        local start_row, start_col, end_row, end_col = current:range()

        insert_pos.row = opts.below and end_row + 1 or start_row + 1
        insert_pos.col = opts.below and end_col or start_col

        path_pos.row = opts.below and end_row + 1 or start_row
        path_pos.col = opts.below and end_col or vim.v.maxcol
    else
        insert_pos.col = opts.below and 0 or vim.v.maxcol

        path_pos.col = opts.below and 0 or vim.v.maxcol
    end

    return insert_pos, path_pos, current
end

return M
