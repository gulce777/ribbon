-- plugin lifecycle management.
-- plugins create a plugin object, register load/unload hooks,
-- and return it. ribbon calls on_load when the plugin is required,
-- and on_unload when it is explicitly unloaded.

local ribbon = _G.ribbon

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
