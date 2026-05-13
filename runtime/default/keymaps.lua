-- runtime/default/keymaps.lua
-- default key bindings loaded on top of input.lua's chord machine.
-- add your own bindings here or in ~/.config/ribbon/init.lua.

-- save current buffer
ribbon.keymap.set("normal", "<c-s>", function()
    local buf = ribbon.buffer.current()
    if buf then ribbon.buffer.save(buf) end
end)

-- open a new empty buffer
ribbon.keymap.set("normal", "<c-n>", function()
    local id = ribbon.buffer.new()
    ribbon.buffer.set_current(id)
    ribbon.cursor.set(1, 1)
end)
