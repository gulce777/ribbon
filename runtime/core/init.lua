-- ribbon's core lua api.
-- this file is loaded first before default/* and user config.
-- do not modify this file, it is ribbon's api contract.
--
-- after capturing _ribbon_rust into a local, this file sets it to nil
-- so no plugin or user config can ever reach the raw rust bindings.

local _rust = _ribbon_rust
_ribbon_rust = nil

local ribbon = {
    _nodes = {},
    _frame_cmd = {},
    _draw_cbs = {},
    _quit = false,
}

_G.ribbon = ribbon
_G._rust = _rust

require("core.utils")
require("core.log")
require("core.events")
require("core.ui")
require("core.modes")
require("core.keymap")
require("core.theme")
require("core.cursor")
require("core.buffer")
require("core.config")
require("core.plugin")

function ribbon.quit()
    ribbon._quit = true
end

--- called by rust each frame.
--- returns the command table for this frame.
function ribbon._collect_frame(cols, rows)
    ribbon._frame_cmds = {}

    local ok, err = pcall(_rust.layout_compute, cols, rows)
    if not ok then
        ribbon.log.warn(("layout compute failed: %s"):format(tostring(err)))
        return ribbon._frame_cmds
    end

    -- collect all draw entries sorted globally by z_index.
    local all = {}
    for id, cbs in pairs(ribbon._draw_cbs) do
        local ok2, rect = pcall(_rust.layout_get, id)
        if ok2 and rect then
            for _, cb in ipairs(cbs) do
                table.insert(all, { id = id, cb = cb, rect = rect })
            end
        end
    end
    table.sort(all, function(a, b) return a.cb.z < b.cb.z end)

    for _, entry in ipairs(all) do
        local ctx = {
            x      = entry.rect.x,
            y      = entry.rect.y,
            width  = entry.rect.width,
            height = entry.rect.height,
        }
        local ok3, err3 = pcall(entry.cb.fn, ctx)
        if not ok3 then
            ribbon.log.error(
                ("on_draw error [node %s]: %s"):format(tostring(entry.id), tostring(err3))
            )
        end
    end

    return ribbon._frame_cmds
end

function ribbon._dispatch(event)
    ribbon.events.emit(event.type, event)
end

ribbon._rust = nil
_G._rust = nil
