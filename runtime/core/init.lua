-- ribbon's core lua api.
-- this file is loaded first before default/* and user config.
-- do not modify this file, it is ribbon's api contract.
--
-- after capturing _ribbon_rust into a local, this file sets it to nil
-- so no plugin or user config can ever reach the raw rust bindings.

local _rust = _ribbon_rust
_ribbon_rust = nil

local function assert_type(value, expected, name)
    if type(value) ~= expected then
        error(("ribbon: '%s' must be a %s, got %s"):format(name, expected, type(value)), 3)
    end
end

local function assert_not_nil(value, name)
    if value == nil then
        error(("ribbon: '%s' must not be nil"):format(name), 3)
    end
end

local ribbon       = {}

ribbon._nodes      = {}
ribbon._draw_cbs   = {}
ribbon._frame_cmds = {}
ribbon._quit       = false

ribbon.log         = {}

function ribbon.log.info(msg)
    _rust.log("info", tostring(msg))
end

function ribbon.log.warn(msg)
    _rust.log("warn", tostring(msg))
end

function ribbon.log.error(msg)
    _rust.log("error", tostring(msg))
end

-- ribbon.events
ribbon.events           = {}
ribbon.events._handlers = {} -- event_type -> { { fn, id }, ... }
ribbon.events._next_id  = 0

local function next_handler_id()
    ribbon.events._next_id = ribbon.events._next_id + 1
    return ribbon.events._next_id
end

function ribbon.events.on(event_type, fn)
    assert_type(event_type, "string", "event_type")
    assert_type(fn, "function", "handler")

    local list = ribbon.events._handlers[event_type] or {}
    local id = next_handler_id()
    table.insert(list, { fn = fn, id = id })
    ribbon.events._handlers[event_type] = list

    return {
        remove = function()
            local handlers = ribbon.events._handlers[event_type]
            if not handlers then return end

            for i, h in ipairs(handlers) do
                if h.id == id then
                    table.remove(handlers, i)
                    return
                end
            end
        end
    }
end

function ribbon.events.emit(event_type, data)
    assert_type(event_type, "string", "event_type")

    local handlers = ribbon.events._handlers[event_type]
    if not handlers then return end

    for _, h in ipairs(handlers) do
        local ok, err = pcall(h.fn, data or {})
        if not ok then
            ribbon.log.error(
                ("event handler error [%s]: %s"):format(event_type, tostring(err))
            )
        end
    end
end

-- ribbon.ui

ribbon.ui = {}

function ribbon.ui.px(n)
    assert_type(n, "number", "px value")
    return { type = "length", value = math.floor(n) }
end

function ribbon.ui.percent(n)
    assert_type(n, "number", "percent value")
    if n < 0 or n > 100 then
        error(("ribbon.ui.percent: value must be 0–100, got %d"):format(n), 2)
    end
    return { type = "percent", value = math.floor(n) }
end

function ribbon.ui.fill(n)
    return { type = "fill", value = math.floor(n or 1) }
end

function ribbon.ui.min(n)
    assert_type(n, "number", "min value")
    return { type = "min", value = math.floor(n) }
end

function ribbon.ui.max(n)
    assert_type(n, "number", "max value")
    return { type = "max", value = math.floor(n) }
end

function ribbon.ui.ratio(a, b)
    assert_type(a, "number", "ratio a")
    assert_type(b, "number", "ratio b")
    if b == 0 then
        error("ribbon.ui.ratio: b must not be zero", 2)
    end
    return { type = "ratio", a = math.floor(a), b = math.floor(b) }
end

--- creates a layout node.
---
--- opts = {
---     id          = string (optional, for get_node lookup),
---     direction   = "horizontal" | "vertical"  (default: "horizontal"),
---     constraint  = ribbon.ui.px(n) | .percent(n) | .fill(n) | etc.
---                   (default: ribbon.ui.fill(1)),
---     z_index     = number (default: 0, higher draws on top),
---     children    = { node, ... } (optional),
--- }
function ribbon.ui.create_node(opts)
    opts             = opts or {}

    local direction  = opts.direction or "horizontal"
    local constraint = opts.constraint or ribbon.ui.fill(1)
    local z_index    = opts.z_index or 0

    assert_type(direction, "string", "direction")
    if direction ~= "horizontal" and direction ~= "vertical" then
        error(("ribbon.ui.create_node: direction must be 'horizontal' or 'vertical', got '%s'"):format(direction), 2)
    end
    assert_type(constraint, "table", "constraint")

    local id = _rust.layout_add_node(direction, constraint)
    if not id then
        error("ribbon.ui.create_node: rust returned nil id — this is a bug", 2)
    end

    local node = {
        _id      = id,
        _z_index = z_index,
    }

    -- register with optional string id for later lookup.
    if opts.id then
        assert_type(opts.id, "string", "node id")
        if ribbon._nodes[opts.id] then
            ribbon.log.warn(
                ("ribbon.ui.create_node: node id '%s' already exists, overwriting"):format(opts.id)
            )
        end
        ribbon._nodes[opts.id] = node
    end

    -- also register by numeric id.
    ribbon._nodes[id] = node

    --- appends a child node.
    function node:add_child(child)
        assert_not_nil(child, "child")
        assert_type(child._id, "number", "child._id")
        local ok, err = pcall(_rust.layout_add_child, self._id, child._id)
        if not ok then
            ribbon.log.error(("node:add_child failed: %s"):format(tostring(err)))
        end
    end

    --- removes a child node.
    function node:remove_child(child)
        assert_not_nil(child, "child")
        assert_type(child._id, "number", "child._id")
        local ok, err = pcall(_rust.layout_remove_child, self._id, child._id)
        if not ok then
            ribbon.log.error(("node:remove_child failed: %s"):format(tostring(err)))
        end
    end

    --- updates this node's constraint.
    function node:set_constraint(c)
        assert_type(c, "table", "constraint")
        local ok, err = pcall(_rust.layout_set_constraint, self._id, c)
        if not ok then
            ribbon.log.error(("node:set_constraint failed: %s"):format(tostring(err)))
        end
    end

    --- updates this node's direction.
    function node:set_direction(d)
        assert_type(d, "string", "direction")
        if d ~= "horizontal" and d ~= "vertical" then
            ribbon.log.error(
                ("node:set_direction: expected 'horizontal' or 'vertical', got '%s'"):format(d)
            )
            return
        end
        local ok, err = pcall(_rust.layout_set_direction, self._id, d)
        if not ok then
            ribbon.log.error(("node:set_direction failed: %s"):format(tostring(err)))
        end
    end

    --- registers a draw callback for this node.
    --- multiple callbacks can be registered; they run in z_index order.
    --- returns a handle: { remove = fn }
    function node:on_draw(fn, z)
        assert_type(fn, "function", "on_draw callback")
        z = z or self._z_index

        local list = ribbon._draw_cbs[self._id] or {}
        local entry_id = next_handler_id()
        table.insert(list, { fn = fn, z = z, id = entry_id })
        -- keep sorted by z_index so lower z draws first (underneath).
        table.sort(list, function(a, b) return a.z < b.z end)
        ribbon._draw_cbs[self._id] = list

        return {
            remove = function()
                local cbs = ribbon._draw_cbs[self._id]
                if not cbs then return end
                for i, cb in ipairs(cbs) do
                    if cb.id == entry_id then
                        table.remove(cbs, i)
                        return
                    end
                end
            end
        }
    end

    --- marks the node as needing a redraw next frame.
    --- currently a no-op (all nodes redraw each frame in tui mode),
    --- kept in the api for forward compatibility with dirty tracking.
    function node:invalidate()
        -- no-op for now.
    end

    if opts.children then
        assert_type(opts.children, "table", "children")
        for i, child in ipairs(opts.children) do
            if type(child) ~= "table" or type(child._id) ~= "number" then
                error(("ribbon.ui.create_node: children[%d] is not a valid node"):format(i), 2)
            end
            node:add_child(child)
        end
    end

    return node
end

--- marks a node as the layout root.
function ribbon.ui.set_root(node)
    assert_not_nil(node, "node")
    assert_type(node._id, "number", "node._id")
    local ok, err = pcall(_rust.layout_set_root, node._id)
    if not ok then
        error(("ribbon.ui.set_root failed: %s"):format(tostring(err)), 2)
    end
end

--- returns a previously registered node by its string id.
--- returns nil if not found — callers should handle this.
function ribbon.ui.get_node(id)
    assert_type(id, "string", "node id")
    return ribbon._nodes[id] -- nil if not found, caller checks.
end

--- draws text within a node's draw context.
---
--- opts = {
---     text      = string,
---     x         = number (relative to node, default 0),
---     y         = number (relative to node, default 0),
---     fg        = "#rrggbb" (default "#ffffff"),
---     bg        = "#rrggbb" (optional),
---     bold      = boolean  (default false),
---     italic    = boolean  (default false),
---     max_width = number   (default: node width),
--- }
function ribbon.ui.draw_text(ctx, opts)
    assert_not_nil(ctx, "ctx")
    assert_not_nil(opts, "opts")
    if not opts.text then
        ribbon.log.warn("ribbon.ui.draw_text: 'text' field is missing, skipping")
        return
    end
    table.insert(ribbon._frame_cmds, {
        type      = "text",
        x         = ctx.x + (opts.x or 0),
        y         = ctx.y + (opts.y or 0),
        max_width = opts.max_width or ctx.width,
        content   = tostring(opts.text),
        fg        = opts.fg or "#ffffff",
        bg        = opts.bg,
        bold      = opts.bold or false,
        italic    = opts.italic or false,
    })
end

--- fills a rectangular area with a colored block.
---
--- opts = {
---     bg     = "#rrggbb",
---     fg     = "#rrggbb" (optional, for border color),
---     border = boolean   (default false),
---     x, y, width, height all default to ctx dimensions.
--- }
function ribbon.ui.draw_block(ctx, opts)
    assert_not_nil(ctx, "ctx")
    assert_not_nil(opts, "opts")
    table.insert(ribbon._frame_cmds, {
        type   = "block",
        x      = ctx.x + (opts.x or 0),
        y      = ctx.y + (opts.y or 0),
        width  = opts.width or ctx.width,
        height = opts.height or ctx.height,
        fg     = opts.fg or "#ffffff",
        bg     = opts.bg or "#000000",
        border = opts.border or false,
    })
end

--- clears the entire screen with a background color.
function ribbon.ui.draw_clear(bg_hex)
    assert_type(bg_hex, "string", "bg_hex")
    table.insert(ribbon._frame_cmds, { type = "clear", bg = bg_hex })
end

-- ribbon.modes

ribbon.modes = {}
ribbon.modes._current = "normal"

--- returns the current mode name.
function ribbon.modes.current()
    return ribbon.modes._current
end

--- switches to a new mode and emits "mode.change".
function ribbon.modes.set(name)
    assert_type(name, "string", "mode name")
    if name == ribbon.modes._current then return end
    local prev = ribbon.modes._current
    ribbon.modes._current = name
    ribbon.events.emit("mode.change", { mode = name, prev = prev })
end

-- ribbon.keymap
-- a two-level map: mode -> key_sequence -> handler.
-- the input engine (runtime/default/input.lua) drives execution.

ribbon.keymap = {}
ribbon.keymap._map = {} -- mode -> { key_sequence -> fn }

--- binds a key sequence to a function in a given mode.
---
--- keymap.set("normal", "gg",        function() ... end)
--- keymap.set("insert", "<esc>",     function() ... end)
--- keymap.set("normal", "<leader>w", function() ... end)
function ribbon.keymap.set(mode, keys, fn)
    assert_type(mode, "string", "mode")
    assert_type(keys, "string", "keys")
    assert_type(fn, "function", "handler")

    ribbon.keymap._map[mode] = ribbon.keymap._map[mode] or {}
    ribbon.keymap._map[mode][keys] = fn
end

function ribbon.keymap.del(mode, keys)
    assert_type(mode, "string", "mode")
    assert_type(keys, "string", "keys")
    if ribbon.keymap._map[mode] then
        ribbon.keymap._map[mode][keys] = nil
    end
end

--- returns true if `keys` exactly matches a binding in `mode`.
function ribbon.keymap.has_exact(mode, keys)
    local m = ribbon.keymap._map[mode]
    return m ~= nil and m[keys] ~= nil
end

--- returns true if `keys` is a prefix of any binding in `mode`.
function ribbon.keymap.has_prefix(mode, keys)
    local m = ribbon.keymap._map[mode]
    if not m then return false end
    for seq, _ in pairs(m) do
        if seq ~= keys and seq:sub(1, #keys) == keys then
            return true
        end
    end
    return false
end

--- executes the handler for `keys` in `mode`.
--- logs a warning if no handler is found.
function ribbon.keymap.execute(mode, keys)
    local m = ribbon.keymap._map[mode]
    if not m then
        ribbon.log.warn(("keymap.execute: no bindings for mode '%s'"):format(mode))
        return
    end
    local fn = m[keys]
    if not fn then
        ribbon.log.warn(("keymap.execute: no binding for '%s' in mode '%s'"):format(keys, mode))
        return
    end
    local ok, err = pcall(fn)
    if not ok then
        ribbon.log.error(
            ("keymap handler error [%s in %s]: %s"):format(keys, mode, tostring(err))
        )
    end
end

--- ribbon.theme

ribbon.theme = {}
ribbon.theme._tokens = {}

--- sets one or more theme tokens.
--- theme.set({ background = "#1a1819", accent = "#e5a4b4" })
function ribbon.theme.set(tokens)
    assert_type(tokens, "table", "tokens")
    for k, v in pairs(tokens) do
        ribbon.theme._tokens[k] = v
    end
end

--- returns a token value, or fallback if not found.
--- theme.get("accent") -> "#e5a4b4"
function ribbon.theme.get(key, fallback)
    assert_type(key, "string", "key")
    local v = ribbon.theme._tokens[key]
    if v == nil then
        if fallback ~= nil then return fallback end
        ribbon.log.warn(("ribbon.theme.get: token '%s' not found"):format(key))
        return "#ff00ff" -- hot pink. intentionally ugly so missing tokens are obvious.
    end
    return v
end

-- ribbon.cursor
--
-- all cursor state lives here in lua. rust knows nothing about cursors.
-- the only thing rust receives is `DrawCommand::SetCursor` — one per frame —
-- telling the terminal where to blink. every other cursor concept (multi-cursor,
-- selection, visual mode highlight) is expressed through normal draw commands.
--
-- cursor table shape:
--   { line = number, col = number, anchor = {line, col} | nil }
-- `anchor` is set during selection. nil means no active selection.

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

--- tells the terminal where to blink the physical cursor.
--- call this from your editor node's on_draw, once per frame, for the primary cursor.
--- all other cursor visuals (block highlight, selection shading) are draw_text calls.
function ribbon.ui.set_cursor(x, y)
    table.insert(ribbon._frame_cmds, {
        type = "cursor",
        x    = math.floor(x),
        y    = math.floor(y),
    })
end

-- ribbon.buffer
--
-- buffer management. lua keeps a registry of open buffers (metadata, path,
-- modified flag). rust stores the actual rope — a persistent, utf-8 aware
-- data structure that makes cheap insertions and deletions anywhere.
--
-- 1-based line and column numbers are the public contract.
-- the bridge converts to 0-based before calling rust so callers never think about it.

ribbon.buffer = {}
ribbon.buffer._buffers = {}  -- id -> { path, name, modified }
ribbon.buffer._current = nil -- id of the focused buffer

--- opens a file and returns its buffer id.
--- emits "buffer.open" with { id, path }.
function ribbon.buffer.open(path)
    assert_type(path, "string", "path")
    local ok, id = pcall(_rust.buffer_open, path)
    if not ok then
        ribbon.log.error(("ribbon.buffer.open failed: %s"):format(tostring(id)))
        return nil
    end
    local name = path:match("([^/\\]+)$") or path
    ribbon.buffer._buffers[id] = { path = path, name = name, modified = false }
    ribbon.events.emit("buffer.open", { id = id, path = path })
    return id
end

--- creates an empty unnamed buffer and returns its id.
function ribbon.buffer.new()
    local id = _rust.buffer_new()
    ribbon.buffer._buffers[id] = { path = nil, name = "[No Name]", modified = false }
    ribbon.events.emit("buffer.new", { id = id })
    return id
end

--- closes a buffer. does not prompt for unsaved changes — callers must check.
function ribbon.buffer.close(id)
    assert_type(id, "number", "buffer id")
    _rust.buffer_close(id)
    ribbon.buffer._buffers[id] = nil
    if ribbon.buffer._current == id then
        ribbon.buffer._current = nil
    end
    ribbon.events.emit("buffer.close", { id = id })
end

--- returns the id of the currently focused buffer, or nil.
function ribbon.buffer.current()
    return ribbon.buffer._current
end

--- focuses a buffer. emits "buffer.switch".
function ribbon.buffer.set_current(id)
    local prev = ribbon.buffer._current
    ribbon.buffer._current = id
    ribbon.events.emit("buffer.switch", { id = id, prev = prev })
end

--- returns the number of lines in a buffer.
function ribbon.buffer.line_count(id)
    assert_type(id, "number", "buffer id")
    return _rust.buffer_line_count(id)
end

--- returns a single line by 1-based line number. trailing newline is stripped.
--- returns nil (not error) if line is out of range.
function ribbon.buffer.get_line(id, line)
    assert_type(id, "number", "buffer id")
    assert_type(line, "number", "line")
    local ok, result = pcall(_rust.buffer_get_line, id, line - 1)
    if not ok then return nil end
    return result
end

--- inserts `text` at (line, col) (1-based). marks buffer as modified.
function ribbon.buffer.insert(id, line, col, text)
    assert_type(id, "number", "buffer id")
    assert_type(line, "number", "line")
    assert_type(col, "number", "col")
    assert_type(text, "string", "text")
    local ok, err = pcall(_rust.buffer_insert, id, line - 1, col - 1, text)
    if not ok then
        ribbon.log.error(("buffer.insert failed: %s"):format(tostring(err)))
        return
    end
    if ribbon.buffer._buffers[id] then
        ribbon.buffer._buffers[id].modified = true
    end
end

--- deletes characters from (line, col_start) to (line, col_end) (1-based, inclusive start, exclusive end).
function ribbon.buffer.delete(id, line, col_start, col_end)
    assert_type(id, "number", "buffer id")
    assert_type(line, "number", "line")
    assert_type(col_start, "number", "col_start")
    assert_type(col_end, "number", "col_end")
    local ok, err = pcall(_rust.buffer_delete, id, line - 1, col_start - 1, col_end - 1)
    if not ok then
        ribbon.log.error(("buffer.delete failed: %s"):format(tostring(err)))
        return
    end
    if ribbon.buffer._buffers[id] then
        ribbon.buffer._buffers[id].modified = true
    end
end

--- returns the file path associated with a buffer, or nil for unnamed buffers.
function ribbon.buffer.path(id)
    assert_type(id, "number", "buffer id")
    return _rust.buffer_path(id)
end

--- returns the display name for a buffer (filename or "[No Name]").
function ribbon.buffer.name(id)
    local meta = ribbon.buffer._buffers[id]
    return meta and meta.name or "[No Name]"
end

--- returns true if the buffer has unsaved changes.
function ribbon.buffer.is_modified(id)
    local meta = ribbon.buffer._buffers[id]
    return meta and meta.modified or false
end

--- saves the buffer to its current path, or to `path` if given.
--- marks buffer as unmodified on success.
function ribbon.buffer.save(id, path)
    assert_type(id, "number", "buffer id")
    local ok, err = pcall(_rust.buffer_save, id, path)
    if not ok then
        ribbon.log.error(("buffer.save failed: %s"):format(tostring(err)))
        return false
    end
    -- update path metadata if saving to a new location
    if path and ribbon.buffer._buffers[id] then
        ribbon.buffer._buffers[id].path = path
        ribbon.buffer._buffers[id].name = path:match("([^/\\]+)$") or path
    end
    if ribbon.buffer._buffers[id] then
        ribbon.buffer._buffers[id].modified = false
    end
    ribbon.events.emit("buffer.save", { id = id })
    return true
end

-- ribbon.config
-- plugin configuration system.
-- plugins declare their schema; users call .setup() to override defaults.

ribbon.config          = {}
ribbon.config._schemas = {} -- plugin_name -> schema
ribbon.config._values  = {} -- plugin_name -> resolved values

--- declares a configuration schema for a plugin.
---
--- ribbon.plugin.declare("my-plugin", {
---     width = { type = "number", default = 240 },
---     enabled = { type = "boolean", default = true },
---     label = { type = "string", default = "hi" }
--- })

function ribbon.config.declare(plugin_name, schema)
    assert_type(plugin_name, "string", "plugin_name")
    assert_type(schema, "table", "schema")
    ribbon.config._schemas[plugin_name] = schema

    local values = {}
    for key, spec in pairs(schema) do
        values[key] = spec.default
    end

    if ribbon.config._values[plugin_name] then
        for k, v in pairs(ribbon.config._values[plugin_name]) do
            values[k] = v
        end
    end
    ribbon.config._values[plugin_name] = values
end

--- returns the resolved config table for a plugin.
--- returns an empty table if the plugin has not declared a schema.
function ribbon.config.get(plugin_name)
    assert_type(plugin_name, "string", "plugin_name")
    return ribbon.config._values[plugin_name] or {}
end

--- sets config values for a plugin, validating against the schema.
--- this is what require("my-plugin").setup({...}) calls internally.
function ribbon.config.set(plugin_name, overrides)
    assert_type(plugin_name, "string", "plugin_name")
    assert_type(overrides, "table", "overrides")

    local schema = ribbon.config._schemas[plugin_name]
    local values = ribbon.config._values[plugin_name] or {}

    for key, val in pairs(overrides) do
        if schema then
            local spec = schema[key]
            if not spec then
                ribbon.log.warn(
                    ("ribbon.config.set [%s]: unknown key '%s', ignoring"):format(plugin_name, key)
                )
            elseif type(val) ~= spec.type then
                ribbon.log.error(
                    ("ribbon.config.set [%s]: '%s' must be a %s, got %s"):format(
                        plugin_name, key, spec.type, type(val)
                    )
                )
            else
                values[key] = val
            end
        else
            -- no schema yet, store anyway.
            values[key] = val
        end
    end

    ribbon.config._values[plugin_name] = values
end

-- ribbon.plugin
--
-- plugin lifecycle management.
-- plugins create a plugin object, register load/unload hooks,
-- and return it. ribbon calls on_load when the plugin is required,
-- and on_unload when it is explicitly unloaded.

ribbon.plugin = {}
ribbon.plugin._registry = {} -- name -> plugin object

--- creates a new plugin handle.
---
--- local p = ribbon.plugin.new("my-plugin")
--- p.on_load(function() ... end)
--- p.on_unload(function() ... end)
--- return p
function ribbon.plugin.new(name)
    assert_type(name, "string", "plugin name")

    if ribbon.plugin._registry[name] then
        ribbon.log.warn(("ribbon.plugin.new: plugin '%s' already registered"):format(name))
    end

    local p = {
        _name          = name,
        _loaded        = false,
        _load_fn       = nil,
        _unload_fn     = nil,
        _event_handles = {}, -- collected so on_unload can clean up automatically.
    }

    --- registers the load callback.
    function p.on_load(fn)
        assert_type(fn, "function", "on_load callback")
        p._load_fn = fn
    end

    --- registers the unload callback.
    function p.on_unload(fn)
        assert_type(fn, "function", "on_unload callback")
        p._unload_fn = fn
    end

    --- wraps ribbon.events.on so handles are tracked for auto-cleanup.
    function p.on_event(event_type, fn)
        local handle = ribbon.events.on(event_type, fn)
        table.insert(p._event_handles, handle)
        return handle
    end

    --- sets config overrides for this plugin.
    --- sugar for ribbon.config.set(name, opts).
    function p.setup(opts)
        ribbon.config.set(p._name, opts or {})
        if p._loaded and p._load_fn then
            local ok, err = pcall(p._load_fn)
            if not ok then
                ribbon.log.error(
                    ("plugin '%s' reload error: %s"):format(p._name, tostring(err))
                )
            end
        end
    end

    --- called by ribbon when the plugin module is first required.
    function p._do_load()
        if p._loaded then return end
        if p._load_fn then
            local ok, err = pcall(p._load_fn)
            if not ok then
                ribbon.log.error(
                    ("plugin '%s' load error: %s"):format(p._name, tostring(err))
                )
                return
            end
        end
        p._loaded = true
        ribbon.log.info(("plugin '%s' loaded"):format(p._name))
    end

    --- unloads the plugin: calls on_unload, removes all tracked event handlers.
    function p._do_unload()
        if not p._loaded then return end
        -- remove tracked event handlers automatically.
        for _, handle in ipairs(p._event_handles) do
            handle.remove()
        end
        p._event_handles = {}
        if p._unload_fn then
            local ok, err = pcall(p._unload_fn)
            if not ok then
                ribbon.log.error(
                    ("plugin '%s' unload error: %s"):format(p._name, tostring(err))
                )
            end
        end
        p._loaded = false
        ribbon.log.info(("plugin '%s' unloaded"):format(p._name))
    end

    ribbon.plugin._registry[name] = p

    -- auto-load immediately (plugins are loaded when required).
    p._do_load()

    return p
end

--- unloads a plugin by name.
function ribbon.plugin.unload(name)
    assert_type(name, "string", "plugin name")
    local p = ribbon.plugin._registry[name]
    if not p then
        ribbon.log.warn(("ribbon.plugin.unload: plugin '%s' not found"):format(name))
        return
    end
    p._do_unload()
end

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

_G.ribbon = ribbon
