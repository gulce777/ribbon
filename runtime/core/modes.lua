local ribbon = _G.ribbon

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
