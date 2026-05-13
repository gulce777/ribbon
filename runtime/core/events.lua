local ribbon            = _G.ribbon

ribbon.events           = {}
ribbon.events._handlers = {}
ribbon.events._next_id  = 0

function next_handler_id()
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
