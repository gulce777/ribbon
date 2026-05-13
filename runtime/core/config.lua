-- plugin configuration system.
-- plugins declare their schema; users call .setup() to override defaults.

local ribbon           = _G.ribbon

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
