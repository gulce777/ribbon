-- runtime/default/input.lua
-- the key chord engine.
--
-- drives ribbon.keymap from raw key events.
-- handles multi-key sequences (e.g. "gg", "<leader>w", "2dd").
--
-- state machine:
--   idle        → first key arrives → accumulate
--   accumulating → exact match found → execute, reset
--   accumulating → prefix match only → wait for next key
--   accumulating → no match at all   → if single key, try fallthrough; reset

local pending            = ""
local LEADER             = "<space>"

-- allow user config to change leader.
ribbon.keymap.set_leader = function(key)
    LEADER = key
end

ribbon.events.on("key", function(e)
    local k = e.key

    if k == LEADER then k = "<leader>" end

    pending = pending .. k
    local mode = ribbon.modes.current()

    if ribbon.keymap.has_exact(mode, pending) then
        ribbon.keymap.execute(mode, pending)
        pending = ""
    elseif ribbon.keymap.has_prefix(mode, pending) then
        -- TODO
    else
        -- no match found.
        if #pending > 1 then
            -- we had a prefix running but the new key broke it.
            -- retry with just the new key so single-key bindings still fire.
            pending = k
            if ribbon.keymap.has_exact(mode, pending) then
                ribbon.keymap.execute(mode, pending)
                pending = ""
            elseif not ribbon.keymap.has_prefix(mode, pending) then
                pending = ""
            end
        else
            -- single unrecognised key. discard.
            pending = ""
        end
    end
end)

-- normal mode defaults
ribbon.keymap.set("normal", "<c-c>", function() ribbon.quit() end)
ribbon.keymap.set("normal", "<c-q>", function() ribbon.quit() end)

-- clamped cursor movement.
-- normal mode: col capped at line length (last char).
-- always clamps line to 1..total_lines.
local function move(dl, dc)
    local buf  = ribbon.buffer.current()
    local line = ribbon.cursor.line()
    local col  = ribbon.cursor.col()

    if not buf then
        ribbon.cursor.set(math.max(1, line + dl), math.max(1, col + dc))
        return
    end

    local total    = ribbon.buffer.line_count(buf)
    local new_line = math.max(1, math.min(line + dl, total))
    local line_txt = ribbon.buffer.get_line(buf, new_line) or ""

    local max_col  = math.max(1, #line_txt)
    local new_col  = math.max(1, math.min(col + dc, max_col))
    ribbon.cursor.set(new_line, new_col)
end

ribbon.keymap.set("normal", "<char:i>", function()
    ribbon.modes.set("insert")
end)

ribbon.keymap.set("normal", "<char:a>", function()
    -- append: enter insert mode with cursor one step right
    local buf = ribbon.buffer.current()
    if buf then
        local line = ribbon.cursor.line()
        local text = ribbon.buffer.get_line(buf, line) or ""
        ribbon.cursor.set(line, math.min(ribbon.cursor.col() + 1, #text + 1))
    end
    ribbon.modes.set("insert")
end)

ribbon.keymap.set("normal", "<char:v>", function()
    ribbon.cursor.begin_selection()
    ribbon.modes.set("visual")
end)

ribbon.keymap.set("normal", "<char:j>", function() move(1, 0) end)
ribbon.keymap.set("normal", "<char:k>", function() move(-1, 0) end)
ribbon.keymap.set("normal", "<char:h>", function() move(0, -1) end)
ribbon.keymap.set("normal", "<char:l>", function() move(0, 1) end)

ribbon.keymap.set("normal", "<char:g><char:g>", function()
    ribbon.cursor.set(1, 1)
end)

ribbon.keymap.set("normal", "<char:G>", function()
    local buf = ribbon.buffer.current()
    if buf then
        local total = ribbon.buffer.line_count(buf)
        local text  = ribbon.buffer.get_line(buf, total) or ""
        ribbon.cursor.set(total, math.max(1, #text))
    end
end)

ribbon.keymap.set("normal", "<char:0>", function()
    ribbon.cursor.set(ribbon.cursor.line(), 1)
end)

ribbon.keymap.set("normal", "<char:$>", function()
    local buf = ribbon.buffer.current()
    if buf then
        local text = ribbon.buffer.get_line(buf, ribbon.cursor.line()) or ""
        ribbon.cursor.set(ribbon.cursor.line(), math.max(1, #text))
    end
end)

-- insert mode

ribbon.keymap.set("insert", "<esc>", function()
    -- snap cursor back to line content on leaving insert mode
    local buf = ribbon.buffer.current()
    if buf then
        local line = ribbon.cursor.line()
        local text = ribbon.buffer.get_line(buf, line) or ""
        local col  = math.max(1, math.min(ribbon.cursor.col(), math.max(1, #text)))
        ribbon.cursor.set(line, col)
    end
    ribbon.modes.set("normal")
end)

ribbon.keymap.set("insert", "<c-c>", function()
    ribbon.modes.set("normal")
end)

-- visual mode

ribbon.keymap.set("visual", "<esc>", function()
    ribbon.cursor.end_selection()
    ribbon.modes.set("normal")
end)

ribbon.keymap.set("visual", "<char:j>", function() move(1, 0) end)
ribbon.keymap.set("visual", "<char:k>", function() move(-1, 0) end)
ribbon.keymap.set("visual", "<char:h>", function() move(0, -1) end)
ribbon.keymap.set("visual", "<char:l>", function() move(0, 1) end)
