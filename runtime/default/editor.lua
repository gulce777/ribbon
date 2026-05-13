-- runtime/default/editor.lua
-- the text editor widget.
--
-- exposes _G.editor with editor.create(opts) -> node.
-- layout.lua calls editor.create() and places the returned node in the tree.

local editor = {}
_G.editor = editor

editor._viewport = { line = 1 }  -- first visible line (1-based, per-editor state)

--- creates an editor layout node and wires up all drawing logic.
--- opts = { line_numbers = bool }  (default: true)
function editor.create(opts)
    opts = opts or {}
    local show_ln = opts.line_numbers ~= false

    local node = ribbon.ui.create_node({
        id         = "editor",
        direction  = "vertical",
        constraint = ribbon.ui.fill(1),
    })
    editor._node = node

    node:on_draw(function(ctx)
        local buf = ribbon.buffer.current()

        local bg       = ribbon.theme.get("editor.bg",          "#1A1819")
        local fg       = ribbon.theme.get("editor.fg",          "#C8C1C4")
        local cur_bg   = ribbon.theme.get("editor.cursor",      "#E5A4B4")
        local lnum_fg  = ribbon.theme.get("editor.line_number", "#4A444A")
        local sel_bg   = ribbon.theme.get("editor.selection",   "#3A2E3E")

        ribbon.ui.draw_block(ctx, { bg = bg })

        if not buf then
            ribbon.ui.draw_text(ctx, {
                text = "no buffer open",
                x = 2, y = math.floor(ctx.height / 2),
                fg = lnum_fg,
            })
            return
        end

        local total     = ribbon.buffer.line_count(buf)
        local rows      = ctx.height
        local cur_line  = ribbon.cursor.line()
        local cur_col   = ribbon.cursor.col()
        local mode      = ribbon.modes.current()

        -- gutter width scales with line count ("999 " = 4, "9999 " = 5, etc.)
        local gutter_w  = show_ln and (math.max(3, #tostring(total)) + 1) or 0
        local text_w    = ctx.width - gutter_w

        -- keep cursor visible: scroll viewport
        if cur_line < editor._viewport.line then
            editor._viewport.line = cur_line
        elseif cur_line >= editor._viewport.line + rows then
            editor._viewport.line = cur_line - rows + 1
        end
        local vp = editor._viewport.line

        local sel = ribbon.cursor.selection()

        for row = 0, rows - 1 do
            local lnum = vp + row
            if lnum > total then break end

            local text = ribbon.buffer.get_line(buf, lnum) or ""

            -- ── gutter ───────────────────────────────────────────────────────
            if show_ln then
                ribbon.ui.draw_text(ctx, {
                    -- "% (gutter_w-1) d " → e.g. "%3d " → "  1 " (total = gutter_w chars)
                    text      = string.format("%-" .. (gutter_w - 1) .. "d ", lnum),
                    x = 0, y = row,
                    fg        = (lnum == cur_line) and fg or lnum_fg,
                    bg        = bg,
                    max_width = gutter_w,
                })
            end

            -- ── selection segments ────────────────────────────────────────────
            local s_start, s_end
            if sel and lnum >= sel.from.line and lnum <= sel.to.line then
                s_start = (lnum == sel.from.line) and (sel.from.col - 1) or 0
                s_end   = (lnum == sel.to.line)   and (sel.to.col   - 1) or #text
            end

            if s_start then
                local a = text:sub(1, s_start)
                local b = text:sub(s_start + 1, s_end)
                local c = text:sub(s_end + 1)
                local ox = gutter_w
                if #a > 0 then ribbon.ui.draw_text(ctx, { text=a, x=ox,    y=row, fg=fg, bg=bg,     max_width=text_w        }) end
                if #b > 0 then ribbon.ui.draw_text(ctx, { text=b, x=ox+#a, y=row, fg=fg, bg=sel_bg, max_width=text_w-#a     }) end
                if #c > 0 then ribbon.ui.draw_text(ctx, { text=c, x=ox+#a+#b, y=row, fg=fg, bg=bg,  max_width=text_w-#a-#b }) end
            else
                ribbon.ui.draw_text(ctx, {
                    text=text, x=gutter_w, y=row, fg=fg, bg=bg, max_width=text_w,
                })
            end

            -- ── cursor ────────────────────────────────────────────────────────
            if lnum == cur_line then
                local scr_x = ctx.x + gutter_w + (cur_col - 1)
                local scr_y = ctx.y + row

                if mode == "insert" then
                    -- insert mode: thin blinking cursor only
                    ribbon.ui.set_cursor(scr_x, scr_y)
                else
                    -- normal/visual: block cursor (inverted cell)
                    local ch = text:sub(cur_col, cur_col)
                    if ch == "" then ch = " " end
                    ribbon.ui.draw_text(ctx, {
                        text      = ch,
                        x         = gutter_w + (cur_col - 1),
                        y         = row,
                        fg        = bg,
                        bg        = cur_bg,
                        bold      = true,
                        max_width = 1,
                    })
                    ribbon.ui.set_cursor(scr_x, scr_y)
                end
            end
        end
    end)

    return node
end

-- ── insert mode key handling ───────────────────────────────────────────────

ribbon.events.on("key", function(e)
    if ribbon.modes.current() ~= "insert" then return end

    local buf  = ribbon.buffer.current()
    if not buf then return end

    local k    = e.key
    local line = ribbon.cursor.line()

    -- clamp col to valid insert position (1 .. line_length+1)
    local function safe_col()
        local text = ribbon.buffer.get_line(buf, line) or ""
        return math.max(1, math.min(ribbon.cursor.col(), #text + 1))
    end

    -- printable character: "<char:x>"
    local ch = k:match("^<char:(.-)>$")
    if ch then
        local col = safe_col()
        ribbon.cursor.set(line, col)
        ribbon.buffer.insert(buf, line, col, ch)
        ribbon.cursor.set(line, col + 1)
        return
    end

    if k == "<enter>" then
        local col = safe_col()
        ribbon.cursor.set(line, col)
        ribbon.buffer.insert(buf, line, col, "\n")
        ribbon.cursor.set(line + 1, 1)
        return
    end

    if k == "<bs>" then
        local col = safe_col()
        if col > 1 then
            ribbon.buffer.delete(buf, line, col - 1, col)
            ribbon.cursor.set(line, col - 1)
        elseif line > 1 then
            local prev_len = #(ribbon.buffer.get_line(buf, line - 1) or "")
            ribbon.buffer.delete(buf, line - 1, prev_len + 1, prev_len + 2)
            ribbon.cursor.set(line - 1, prev_len + 1)
        end
        return
    end

    if k == "<del>" then
        local col = safe_col()
        local cur  = ribbon.buffer.get_line(buf, line) or ""
        if col <= #cur then
            ribbon.buffer.delete(buf, line, col, col + 1)
        end
        return
    end
end)
