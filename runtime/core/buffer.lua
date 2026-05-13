-- buffer management. lua keeps a registry of open buffers (metadata, path,
-- modified flag). rust stores the actual rope — a persistent, utf-8 aware
-- data structure that makes cheap insertions and deletions anywhere.
--
-- 1-based line and column numbers are the public contract.
-- the bridge converts to 0-based before calling rust so callers never think about it.

local ribbon = _G.ribbon
local _rust = _G._rust

ribbon.buffer = {}
ribbon.buffer._buffers = {}  -- id -> { path, name, modified }
ribbon.buffer._current = nil -- id of the focused buffer

--- opens a file and returns its buffer id.
--- emits "buffer.open" with { id, path }.
function ribbon.buffer.open(path)
    assert_type(path, "string", "path")
    local ok, id = pcall(_rust.buffer_open, path)
    if not ok then
        ribbon.log.error(("ribbon.buffer.open failed: %s"):format(tostring(id)))
        return nil
    end
    local name = path:match("([^/\\]+)$") or path
    ribbon.buffer._buffers[id] = { path = path, name = name, modified = false }
    ribbon.events.emit("buffer.open", { id = id, path = path })
    return id
end

--- creates an empty unnamed buffer and returns its id.
function ribbon.buffer.new()
    local id = _rust.buffer_new()
    ribbon.buffer._buffers[id] = { path = nil, name = "[No Name]", modified = false }
    ribbon.events.emit("buffer.new", { id = id })
    return id
end

--- closes a buffer. does not prompt for unsaved changes — callers must check.
function ribbon.buffer.close(id)
    assert_type(id, "number", "buffer id")
    _rust.buffer_close(id)
    ribbon.buffer._buffers[id] = nil
    if ribbon.buffer._current == id then
        ribbon.buffer._current = nil
    end
    ribbon.events.emit("buffer.close", { id = id })
end

--- returns the id of the currently focused buffer, or nil.
function ribbon.buffer.current()
    return ribbon.buffer._current
end

--- focuses a buffer. emits "buffer.switch".
function ribbon.buffer.set_current(id)
    local prev = ribbon.buffer._current
    ribbon.buffer._current = id
    ribbon.events.emit("buffer.switch", { id = id, prev = prev })
end

--- returns the number of lines in a buffer.
function ribbon.buffer.line_count(id)
    assert_type(id, "number", "buffer id")
    return _rust.buffer_line_count(id)
end

--- returns a single line by 1-based line number. trailing newline is stripped.
--- returns nil (not error) if line is out of range.
function ribbon.buffer.get_line(id, line)
    assert_type(id, "number", "buffer id")
    assert_type(line, "number", "line")
    local ok, result = pcall(_rust.buffer_get_line, id, line - 1)
    if not ok then return nil end
    return result
end

--- inserts `text` at (line, col) (1-based). marks buffer as modified.
function ribbon.buffer.insert(id, line, col, text)
    assert_type(id, "number", "buffer id")
    assert_type(line, "number", "line")
    assert_type(col, "number", "col")
    assert_type(text, "string", "text")
    local ok, err = pcall(_rust.buffer_insert, id, line - 1, col - 1, text)
    if not ok then
        ribbon.log.error(("buffer.insert failed: %s"):format(tostring(err)))
        return
    end
    if ribbon.buffer._buffers[id] then
        ribbon.buffer._buffers[id].modified = true
    end
end

--- deletes characters from (line, col_start) to (line, col_end) (1-based, inclusive start, exclusive end).
function ribbon.buffer.delete(id, line, col_start, col_end)
    assert_type(id, "number", "buffer id")
    assert_type(line, "number", "line")
    assert_type(col_start, "number", "col_start")
    assert_type(col_end, "number", "col_end")
    local ok, err = pcall(_rust.buffer_delete, id, line - 1, col_start - 1, col_end - 1)
    if not ok then
        ribbon.log.error(("buffer.delete failed: %s"):format(tostring(err)))
        return
    end
    if ribbon.buffer._buffers[id] then
        ribbon.buffer._buffers[id].modified = true
    end
end

--- returns the file path associated with a buffer, or nil for unnamed buffers.
function ribbon.buffer.path(id)
    assert_type(id, "number", "buffer id")
    return _rust.buffer_path(id)
end

--- returns the display name for a buffer (filename or "[No Name]").
function ribbon.buffer.name(id)
    local meta = ribbon.buffer._buffers[id]
    return meta and meta.name or "[No Name]"
end

--- returns true if the buffer has unsaved changes.
function ribbon.buffer.is_modified(id)
    local meta = ribbon.buffer._buffers[id]
    return meta and meta.modified or false
end

--- saves the buffer to its current path, or to `path` if given.
--- marks buffer as unmodified on success.
function ribbon.buffer.save(id, path)
    assert_type(id, "number", "buffer id")
    local ok, err = pcall(_rust.buffer_save, id, path)
    if not ok then
        ribbon.log.error(("buffer.save failed: %s"):format(tostring(err)))
        return false
    end
    -- update path metadata if saving to a new location
    if path and ribbon.buffer._buffers[id] then
        ribbon.buffer._buffers[id].path = path
        ribbon.buffer._buffers[id].name = path:match("([^/\\]+)$") or path
    end
    if ribbon.buffer._buffers[id] then
        ribbon.buffer._buffers[id].modified = false
    end
    ribbon.events.emit("buffer.save", { id = id })
    return true
end
