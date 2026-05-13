use std::{path::Path, time::Duration};

use ribbon_lua::LuaEngine;
use ribbon_tui::Renderer;

fn main() -> ribbon_core::Result<()> {
    let engine = LuaEngine::new()?;
    engine.load_runtime(Path::new("runtime"))?;

    let mut renderer = Renderer::new()?;

    loop {
        let (cols, rows) = renderer.size()?;

        let commands = engine.collect_frame(cols, rows)?;
        renderer.draw_frame(&commands)?;

        if let Some(event) = renderer.next_event(Duration::from_millis(16))? {
            if engine.dispatch_event(&event)? {
                break;
            }
        }
    }

    Ok(())
}
