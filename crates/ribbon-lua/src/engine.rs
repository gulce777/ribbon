//!  the single entry point for all lua interaction.

use std::{
    path::Path,
    sync::{Arc, Mutex},
};

use mlua::prelude::*;
use ribbon_core::{
    Result, RibbonError,
    color::Color,
    event::Event,
    id::NodeId,
    layout::{Constraint, Direction, NodeStyle},
};
use ribbon_tui::{DrawCommand, LayoutEngine};

#[derive(Debug, Default, Clone)]
pub struct CursorState {
    /// current line, 1-based.
    pub line: usize,
    /// current column, 1-based.
    pub col: usize,
}

pub struct LuaEngine {
    lua: Lua,
    #[allow(dead_code)]
    layout: Arc<Mutex<LayoutEngine>>,
    pub cursor: Arc<Mutex<CursorState>>,
}

impl LuaEngine {
    /// creates the lua vm and registers the `ribbon._rust.*` api.
    pub fn new() -> Result<Self> {
        let lua = Lua::new();
        let layout = Arc::new(Mutex::new(LayoutEngine::new()));
        let cursor = Arc::new(Mutex::new(CursorState::default()));
        register_rust_api(&lua, Arc::clone(&layout), Arc::clone(&cursor))?;
        Ok(Self {
            lua,
            layout,
            cursor,
        })
    }

    /// loads `{path}/core/init.lua` then all `{path}/default/*.lua` files in order.
    pub fn load_runtime(&self, runtime_path: &Path) -> Result<()> {
        let core = runtime_path.join("core").join("init.lua");
        let src = std::fs::read_to_string(&core).map_err(RibbonError::Io)?;
        self.lua
            .load(&src)
            .set_name("core/init.lua")
            .exec()
            .map_err(|e| RibbonError::Script(e.to_string()))?;

        let default_dir = runtime_path.join("default");
        if default_dir.is_dir() {
            let mut entries: Vec<_> = std::fs::read_dir(&default_dir)
                .map_err(RibbonError::Io)?
                .filter_map(|e| e.ok())
                .filter(|e| e.path().extension().and_then(|s| s.to_str()) == Some("lua"))
                .collect();
            entries.sort_by_key(|e| e.file_name());
            for entry in entries {
                let name = entry.file_name().to_string_lossy().to_string();
                let src = std::fs::read_to_string(entry.path()).map_err(RibbonError::Io)?;
                self.lua
                    .load(&src)
                    .set_name(&name)
                    .exec()
                    .map_err(|e| RibbonError::Script(format!("{}: {}", name, e)))?;
            }
        }
        Ok(())
    }

    pub fn load_user_config(&self, config_path: &Path) -> Result<()> {
        let init = config_path.join("init.lua");
        if init.exists() {
            self.exec_file(&init)?;
        }
        Ok(())
    }

    /// calls `ribbon._collect_frame(cols, rows)` in lua and converts the
    /// returned table of command tables into a `Vec<DrawCommand>`.
    pub fn collect_frame(&self, cols: u16, rows: u16) -> Result<Vec<DrawCommand>> {
        let ribbon: LuaTable = self
            .lua
            .globals()
            .get("ribbon")
            .map_err(|e| RibbonError::Script(e.to_string()))?;

        let collect: LuaFunction = ribbon
            .get("_collect_frame")
            .map_err(|e| RibbonError::Script(e.to_string()))?;

        let table: LuaTable = collect
            .call((cols, rows))
            .map_err(|e| RibbonError::Script(format!("_collect_frame: {}", e)))?;

        let mut commands = Vec::new();
        for item in table.sequence_values::<LuaTable>() {
            if let Ok(t) = item {
                if let Some(cmd) = lua_table_to_draw_command(&t) {
                    commands.push(cmd);
                }
            }
        }
        Ok(commands)
    }

    /// dispatches a normalized ribbon event into lua.
    /// returns `true` if lua has called `ribbon.quit()`.
    pub fn dispatch_event(&self, event: &Event) -> Result<bool> {
        let ribbon: LuaTable = self
            .lua
            .globals()
            .get("ribbon")
            .map_err(|e| RibbonError::Script(e.to_string()))?;

        let dispatch: LuaFunction = match ribbon.get("_dispatch") {
            Ok(f) => f,
            Err(_) => return Ok(false),
        };

        let event_table = event_to_lua_table(&self.lua, event)?;
        dispatch
            .call::<()>(event_table)
            .map_err(|e| RibbonError::Script(format!("_dispatch: {}", e)))?;

        let quit: bool = ribbon.get("_quit").unwrap_or(false);
        Ok(quit)
    }

    fn exec_file(&self, path: &Path) -> Result<()> {
        let name = path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("unknown")
            .to_string();
        let src = std::fs::read_to_string(path).map_err(RibbonError::Io)?;
        self.lua
            .load(&src)
            .set_name(&name)
            .exec()
            .map_err(|e| RibbonError::Script(format!("{}: {}", name, e)))
    }
}

fn register_rust_api(
    lua: &Lua,
    layout: Arc<Mutex<LayoutEngine>>,
    cursor: Arc<Mutex<CursorState>>,
) -> Result<()> {
    let rust_table = lua
        .create_table()
        .map_err(|e| RibbonError::Script(e.to_string()))?;

    // layout_add_node(direction, constraint_table) -> id
    {
        let l = Arc::clone(&layout);
        let f = lua
            .create_function(move |_, (dir, ct): (String, LuaTable)| {
                let constraint = parse_constraint(&ct)?;
                let direction = parse_direction(&dir);
                let mut layout = l.lock().unwrap();
                let id = layout.add_node(NodeStyle {
                    direction,
                    constraint,
                });
                Ok(id.inner())
            })
            .map_err(|e| RibbonError::Script(e.to_string()))?;
        rust_table
            .set("layout_add_node", f)
            .map_err(|e| RibbonError::Script(e.to_string()))?;
    }

    // layout_set_children(parent_id, {child_id, ...})
    {
        let l = Arc::clone(&layout);
        let f = lua
            .create_function(move |_, (pid, ids): (usize, LuaTable)| {
                let mut layout = l.lock().unwrap();
                let children: Vec<NodeId> = ids
                    .sequence_values::<usize>()
                    .filter_map(|v| v.ok())
                    .map(NodeId::new)
                    .collect();
                layout
                    .set_children(NodeId::new(pid), children)
                    .map_err(|e| LuaError::RuntimeError(e.to_string()))?;
                Ok(())
            })
            .map_err(|e| RibbonError::Script(e.to_string()))?;
        rust_table
            .set("layout_set_children", f)
            .map_err(|e| RibbonError::Script(e.to_string()))?;
    }

    // layout_add_child(parent_id, child_id)
    {
        let l = Arc::clone(&layout);
        let f = lua
            .create_function(move |_, (pid, cid): (usize, usize)| {
                l.lock()
                    .unwrap()
                    .add_child(NodeId::new(pid), NodeId::new(cid))
                    .map_err(|e| LuaError::RuntimeError(e.to_string()))
            })
            .map_err(|e| RibbonError::Script(e.to_string()))?;
        rust_table
            .set("layout_add_child", f)
            .map_err(|e| RibbonError::Script(e.to_string()))?;
    }

    // layout_remove_child
    {
        let l = Arc::clone(&layout);
        let f = lua
            .create_function(move |_, (pid, cid): (usize, usize)| {
                l.lock()
                    .unwrap()
                    .remove_child(NodeId::new(pid), NodeId::new(cid))
                    .map_err(|e| LuaError::RuntimeError(e.to_string()))
            })
            .map_err(|e| RibbonError::Script(e.to_string()))?;
        rust_table
            .set("layout_remove_child", f)
            .map_err(|e| RibbonError::Script(e.to_string()))?;
    }

    // layout_set_root(id)
    {
        let l = Arc::clone(&layout);
        let f = lua
            .create_function(move |_, id: usize| {
                l.lock().unwrap().set_root(NodeId::new(id));
                Ok(())
            })
            .map_err(|e| RibbonError::Script(e.to_string()))?;
        rust_table
            .set("layout_set_root", f)
            .map_err(|e| RibbonError::Script(e.to_string()))?;
    }

    // layout_set_constraint(id, constraint_table)
    {
        let l = Arc::clone(&layout);
        let f = lua
            .create_function(move |_, (id, ct): (usize, LuaTable)| {
                let constraint = parse_constraint(&ct)?;
                l.lock()
                    .unwrap()
                    .set_constraint(NodeId::new(id), constraint)
                    .map_err(|e| LuaError::RuntimeError(e.to_string()))
            })
            .map_err(|e| RibbonError::Script(e.to_string()))?;
        rust_table
            .set("layout_set_constraint", f)
            .map_err(|e| RibbonError::Script(e.to_string()))?;
    }

    // layout_set_direction(id, direction)
    {
        let l = Arc::clone(&layout);
        let f = lua
            .create_function(move |_, (id, dir): (usize, String)| {
                let direction = parse_direction(&dir);
                l.lock()
                    .unwrap()
                    .set_direction(NodeId::new(id), direction)
                    .map_err(|e| LuaError::RuntimeError(e.to_string()))
            })
            .map_err(|e| RibbonError::Script(e.to_string()))?;
        rust_table
            .set("layout_set_direction", f)
            .map_err(|e| RibbonError::Script(e.to_string()))?;
    }

    // layout_compute(cols, rows)
    {
        let l = Arc::clone(&layout);
        let f = lua
            .create_function(move |_, (cols, rows): (u16, u16)| {
                l.lock()
                    .unwrap()
                    .compute(cols, rows)
                    .map_err(|e| LuaError::RuntimeError(e.to_string()))
            })
            .map_err(|e| RibbonError::Script(e.to_string()))?;
        rust_table
            .set("layout_compute", f)
            .map_err(|e| RibbonError::Script(e.to_string()))?;
    }

    // layout_get(id) -> {x, y, width, height}
    {
        let l = Arc::clone(&layout);
        let f = lua
            .create_function(move |lua, id: usize| {
                let layout = l.lock().unwrap();
                let (x, y, w, h) = layout
                    .get_layout(NodeId::new(id))
                    .map_err(|e| LuaError::RuntimeError(e.to_string()))?;
                let t = lua.create_table()?;
                t.set("x", x)?;
                t.set("y", y)?;
                t.set("width", w)?;
                t.set("height", h)?;
                Ok(t)
            })
            .map_err(|e| RibbonError::Script(e.to_string()))?;
        rust_table
            .set("layout_get", f)
            .map_err(|e| RibbonError::Script(e.to_string()))?;
    }

    // cursor_line() -> number
    {
        let c = Arc::clone(&cursor);
        let f = lua
            .create_function(move |_, ()| Ok(c.lock().unwrap().line))
            .map_err(|e| RibbonError::Script(e.to_string()))?;
        rust_table
            .set("cursor_line", f)
            .map_err(|e| RibbonError::Script(e.to_string()))?;
    }

    // ── cursor_col() → number ──────────────────────────────────────────────
    {
        let c = Arc::clone(&cursor);
        let f = lua
            .create_function(move |_, ()| Ok(c.lock().unwrap().col))
            .map_err(|e| RibbonError::Script(e.to_string()))?;
        rust_table
            .set("cursor_col", f)
            .map_err(|e| RibbonError::Script(e.to_string()))?;
    }

    // log(level, msg)
    {
        let f = lua
            .create_function(|_, (level, msg): (String, String)| {
                match level.as_str() {
                    "warn" => eprintln!("[ribbon][warn]  {}", msg),
                    "error" => eprintln!("[ribbon][error] {}", msg),
                    _ => eprintln!("[ribbon][info]  {}", msg),
                }
                Ok(())
            })
            .map_err(|e| RibbonError::Script(e.to_string()))?;
        rust_table
            .set("log", f)
            .map_err(|e| RibbonError::Script(e.to_string()))?;
    }

    lua.globals()
        .set("_ribbon_rust", rust_table)
        .map_err(|e| RibbonError::Script(e.to_string()))?;

    Ok(())
}

fn event_to_lua_table(lua: &Lua, event: &Event) -> Result<LuaTable> {
    let t = lua
        .create_table()
        .map_err(|e| RibbonError::Script(e.to_string()))?;

    macro_rules! set {
        ($k:expr, $v:expr) => {
            t.set($k, $v)
                .map_err(|e| RibbonError::Script(e.to_string()))?
        };
    }

    match event {
        Event::KeyPress(k) => {
            set!("type", "key");
            set!("key", k.as_str());
        }
        Event::Resize(size) => {
            set!("type", "resize");
            set!("width", size.width as i64);
            set!("height", size.height as i64);
        }
        Event::MouseClick {
            button, position, ..
        } => {
            set!("type", "click");
            set!("button", *button as i64);
            set!("x", position.x as i64);
            set!("y", position.y as i64);
        }
        Event::Scroll { delta_y, .. } => {
            set!("type", "scroll");
            set!("delta", *delta_y as f64);
        }
        Event::Quit => {
            set!("type", "quit");
        }
        Event::FocusGained => {
            set!("type", "focus_gained");
        }
        Event::FocusLost => {
            set!("type", "focus_lost");
        }
        _ => {
            set!("type", "unknown");
        }
    }

    Ok(t)
}

fn lua_table_to_draw_command(t: &LuaTable) -> Option<DrawCommand> {
    let cmd_type: String = t.get("type").ok()?;
    match cmd_type.as_str() {
        "clear" => {
            let bg: String = t.get("bg").ok()?;
            Some(DrawCommand::Clear(Color::from_hex(&bg).ok()?))
        }
        "block" => {
            let fg = parse_color(t, "fg")?;
            let bg = parse_color(t, "bg")?;
            Some(DrawCommand::Block {
                x: t.get("x").unwrap_or(0),
                y: t.get("y").unwrap_or(0),
                width: t.get("width").unwrap_or(1),
                height: t.get("height").unwrap_or(1),
                fg,
                bg,
                border: t.get("border").unwrap_or(false),
            })
        }
        "text" => {
            let fg = parse_color(t, "fg").unwrap_or(Color::white());
            let bg = t
                .get::<String>("bg")
                .ok()
                .and_then(|s| Color::from_hex(&s).ok());
            let content: String = t.get("content").unwrap_or_default();
            Some(DrawCommand::Text {
                x: t.get("x").unwrap_or(0),
                y: t.get("y").unwrap_or(0),
                max_width: t.get("max_width").unwrap_or(80),
                content,
                fg,
                bg,
                bold: t.get("bold").unwrap_or(false),
                italic: t.get("italic").unwrap_or(false),
            })
        }
        _ => None,
    }
}

fn parse_constraint(t: &LuaTable) -> LuaResult<Constraint> {
    let ctype: String = t
        .get("type")
        .map_err(|_| LuaError::RuntimeError("constraint table must have a 'type' field".into()))?;

    match ctype.as_str() {
        "length" => Ok(Constraint::Length(require_value(t, "length")?)),
        "percent" => Ok(Constraint::Percentage(require_value(t, "percent")?)),
        "fill" => Ok(Constraint::Fill(t.get::<u16>("value").unwrap_or(1))),
        "min" => Ok(Constraint::Min(require_value(t, "min")?)),
        "max" => Ok(Constraint::Max(require_value(t, "max")?)),
        "ratio" => {
            let a: u32 = t.get("a").map_err(|_| {
                LuaError::RuntimeError("ratio constraint requires field 'a'".into())
            })?;
            let b: u32 = t.get("b").map_err(|_| {
                LuaError::RuntimeError("ratio constraint requires field 'b'".into())
            })?;
            if b == 0 {
                return Err(LuaError::RuntimeError(
                    "ratio constraint: 'b' must not be zero".into(),
                ));
            }
            Ok(Constraint::Ratio(a, b))
        }
        other => Err(LuaError::RuntimeError(format!(
            "unknown constraint type: '{}'. expected one of: length, percent, fill, min, max, ratio",
            other
        ))),
    }
}

/// reads `t.value` and wraps a missing-field error with the constraint name.
fn require_value<T: mlua::FromLua>(t: &LuaTable, constraint_name: &str) -> LuaResult<T> {
    t.get("value").map_err(|_| {
        LuaError::RuntimeError(format!(
            "{} constraint requires a 'value' field",
            constraint_name
        ))
    })
}

/// parses a direction string. unknown values fall back to horizontal.
fn parse_direction(s: &str) -> Direction {
    match s {
        "vertical" => Direction::Vertical,
        _ => Direction::Horizontal,
    }
}

#[inline]
fn parse_color(t: &LuaTable, key: &str) -> Option<Color> {
    t.get::<String>(key)
        .ok()
        .and_then(|s| Color::from_hex(&s).ok())
}
