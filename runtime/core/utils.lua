function assert_type(value, expected, name)
    if type(value) ~= expected then
        error(("ribbon: '%s' must be a %s, got %s"):format(name, expected, type(value)), 3)
    end
end

function assert_not_nil(value, name)
    if value == nil then
        error(("ribbon: '%s' must not be nil"):format(name), 3)
    end
end
