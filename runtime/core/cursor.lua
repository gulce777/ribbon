-- all cursor state lives here in lua. rust knows nothing about cursors.
-- the only thing rust receives is `DrawCommand::SetCursor` — one per frame —
-- telling the terminal where to blink. every other cursor concept (multi-cursor,
-- selection, visual mode highlight) is expressed through normal draw commands.
--
-- cursor table shape:
--   { line = number, col = number, anchor = {line, col} | nil }
-- `anchor` is set during selection. nil means no active selection.

local ribbon = _G.ribbon

ribbon.cursor = {}

-- primary cursor initialised at top-left.
ribbon.cursor._cursors = { { line = 1, col = 1, anchor = nil } }

--- returns the primary cursor's line (1-based).
function ribbon.cursor.line()
    return ribbon.cursor._cursors[1].line
end

--- returns the primary cursor's column (1-based).
function ribbon.cursor.col()
    return ribbon.cursor._cursors[1].col
end

--- sets the primary cursor position. clamps to minimum 1.
function ribbon.cursor.set(line, col)
    assert_type(line, "number", "cursor line")
    assert_type(col, "number", "cursor col")
    ribbon.cursor._cursors[1].line = math.max(1, math.floor(line))
    ribbon.cursor._cursors[1].col  = math.max(1, math.floor(col))
end

--- moves the primary cursor by (delta_line, delta_col). clamps to minimum 1.
function ribbon.cursor.move(dl, dc)
    local c = ribbon.cursor._cursors[1]
    c.line  = math.max(1, c.line + (dl or 0))
    c.col   = math.max(1, c.col + (dc or 0))
end

--- returns all cursors (read-only intent — modifications allowed but not encouraged).
function ribbon.cursor.all()
    return ribbon.cursor._cursors
end

--- returns the cursor at 1-based index `i`. nil if out of range.
function ribbon.cursor.get(i)
    return ribbon.cursor._cursors[i or 1]
end

--- returns the number of active cursors.
function ribbon.cursor.count()
    return #ribbon.cursor._cursors
end

--- adds a new cursor at (line, col). silently deduplicates.
function ribbon.cursor.add(line, col)
    assert_type(line, "number", "cursor line")
    assert_type(col, "number", "cursor col")
    for _, c in ipairs(ribbon.cursor._cursors) do
        if c.line == line and c.col == col then return end
    end
    table.insert(ribbon.cursor._cursors, {
        line   = math.max(1, math.floor(line)),
        col    = math.max(1, math.floor(col)),
        anchor = nil,
    })
end

--- removes cursor at index `i`. the primary cursor (index 1) cannot be removed.
function ribbon.cursor.remove(i)
    if (i or 1) <= 1 then return end
    table.remove(ribbon.cursor._cursors, i)
end

--- collapses all extra cursors back to the primary (exits multi-cursor).
function ribbon.cursor.collapse()
    for i = #ribbon.cursor._cursors, 2, -1 do
        table.remove(ribbon.cursor._cursors, i)
    end
end

--- begins a selection for cursor at index `i` by anchoring it at its current position.
function ribbon.cursor.begin_selection(i)
    local c = ribbon.cursor._cursors[i or 1]
    if c then
        c.anchor = { line = c.line, col = c.col }
    end
end

--- clears the selection for cursor at index `i`.
function ribbon.cursor.end_selection(i)
    local c = ribbon.cursor._cursors[i or 1]
    if c then c.anchor = nil end
end

--- returns the normalised selection for cursor `i`, or nil if no selection.
--- "normalised" means `from` is always <= `to` in document order.
--- shape: { from = {line, col}, to = {line, col} }
function ribbon.cursor.selection(i)
    local c = ribbon.cursor._cursors[i or 1]
    if not c or not c.anchor then return nil end
    local a = c.anchor
    local b = { line = c.line, col = c.col }
    -- swap if anchor is after cursor
    if a.line > b.line or (a.line == b.line and a.col > b.col) then
        a, b = b, a
    end
    return { from = a, to = b }
end
