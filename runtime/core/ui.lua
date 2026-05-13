local ribbon = _G.ribbon
local _rust = _G._rust

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
