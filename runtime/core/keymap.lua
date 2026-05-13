local ribbon = _G.ribbon

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
