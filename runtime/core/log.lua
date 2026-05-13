local ribbon = _G.ribbon
local _rust = _G._rust

ribbon.log = {}

function ribbon.log.info(msg)
    _rust.log("info", tostring(msg))
end

function ribbon.log.warn(msg)
    _rust.log("warn", tostring(msg))
end

function ribbon.log.error(msg)
    _rust.log("error", tostring(msg))
end
