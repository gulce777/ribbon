-- runtime/default/layout.lua
-- default visual layout.

local ui = ribbon.ui

ribbon.theme.set({
    ["editor.bg"]              = "#1A1819",
    ["editor.fg"]              = "#C8C1C4",
    ["editor.cursor"]          = "#E5A4B4",
    ["editor.line_number"]     = "#4A444A",
    ["editor.selection"]       = "#3A2E3E",
    ["sidebar.bg"]             = "#111010",
    ["sidebar.fg"]             = "#8C868A",
    ["sidebar.muted"]          = "#4A444A",
    ["statusline.bg"]          = "#0E0D0E",
    ["statusline.fg"]          = "#6A646A",
    ["statusline.mode.normal"] = "#E5A4B4",
    ["statusline.mode.insert"] = "#A4C4E5",
    ["statusline.mode.visual"] = "#A4E5B4",
})

local root      = ui.create_node({ direction = "vertical", constraint = ui.fill(1) })
local body      = ui.create_node({ direction = "horizontal", constraint = ui.fill(1) })
local sidebar   = ui.create_node({ direction = "vertical", constraint = ui.px(22) })
local statusbar = ui.create_node({ direction = "horizontal", constraint = ui.px(1) })

local ed        = editor.create({ line_numbers = true })

body:add_child(sidebar)
body:add_child(ed)
root:add_child(body)
root:add_child(statusbar)
ui.set_root(root)

-- open ribbon-app's main.rs as a demo, or an empty buffer if not found.
do
    local paths = {
        "runtime/core/init.lua",
        "README.md",
    }
    local opened = false
    for _, p in ipairs(paths) do
        local id = ribbon.buffer.open(p)
        if id then
            ribbon.buffer.set_current(id)
            opened = true
            break
        end
    end
    if not opened then
        local id = ribbon.buffer.new()
        ribbon.buffer.set_current(id)
    end
end

sidebar:on_draw(function(ctx)
    local bg    = ribbon.theme.get("sidebar.bg", "#111010")
    local fg    = ribbon.theme.get("sidebar.fg", "#8C868A")
    local muted = ribbon.theme.get("sidebar.muted", "#4A444A")

    ribbon.ui.draw_block(ctx, { bg = bg })

    ribbon.ui.draw_text(ctx, {
        text = "  files", x = 0, y = 0, fg = muted, bg = bg,
    })

    local row = 2
    for id, meta in pairs(ribbon.buffer._buffers) do
        if row >= ctx.height then break end
        local is_cur = (id == ribbon.buffer.current())
        local mark   = meta.modified and "●" or " "
        local name   = (is_cur and "▸ " or "  ") .. mark .. " " .. meta.name
        ribbon.ui.draw_text(ctx, {
            text      = name,
            x         = 0,
            y         = row,
            fg        = is_cur and fg or muted,
            bg        = bg,
            max_width = ctx.width,
        })
        row = row + 1
    end
end)

statusbar:on_draw(function(ctx)
    local bg          = ribbon.theme.get("statusline.bg", "#0E0D0E")
    local fg          = ribbon.theme.get("statusline.fg", "#6A646A")

    local mode        = ribbon.modes.current()
    local mode_colors = {
        normal = ribbon.theme.get("statusline.mode.normal", "#E5A4B4"),
        insert = ribbon.theme.get("statusline.mode.insert", "#A4C4E5"),
        visual = ribbon.theme.get("statusline.mode.visual", "#A4E5B4"),
    }
    local mode_fg     = mode_colors[mode] or fg

    local buf         = ribbon.buffer.current()
    local buf_name    = buf and ribbon.buffer.name(buf) or "[No Name]"
    local modified    = buf and ribbon.buffer.is_modified(buf) and " ●" or ""
    local pos         = (" %d:%d"):format(ribbon.cursor.line(), ribbon.cursor.col())
    local mode_str    = (" " .. mode:upper() .. " ")

    ribbon.ui.draw_block(ctx, { bg = bg })

    ribbon.ui.draw_text(ctx, {
        text = mode_str, x = 0, y = 0, fg = bg, bg = mode_fg, bold = true,
    })

    ribbon.ui.draw_text(ctx, {
        text = "  " .. buf_name .. modified,
        x = #mode_str + 1,
        y = 0,
        fg = fg,
        bg = bg,
    })

    ribbon.ui.draw_text(ctx, {
        text = pos,
        x = ctx.width - #pos,
        y = 0,
        fg = fg,
        bg = bg,
        max_width = #pos,
    })
end)
