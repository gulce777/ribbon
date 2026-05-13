local ribbon = _G.ribbon

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
