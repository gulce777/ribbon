use std::time::Duration;

use ribbon_core::{color::Color, event::Event};
use ribbon_tui::{DrawCommand, Renderer};

fn main() -> ribbon_core::Result<()> {
    let mut renderer = Renderer::new()?;

    loop {
        let (cols, rows) = renderer.size()?;
        let commands = build_frame(cols, rows);
        renderer.draw_frame(&commands)?;

        if let Some(event) = renderer.next_event(Duration::from_millis(16))? {
            match event {
                Event::Quit => break,
                Event::KeyPress(ref k) if k == "<c-c>" || k == "<c-q>" => break,
                Event::Resize(size) => {
                    let _ = size;
                }
                _ => {}
            }
        }
    }

    Ok(())
}

/// temporary test frame.
fn build_frame(cols: u16, rows: u16) -> Vec<DrawCommand> {
    let bg         = Color::from_hex("#1A1819").unwrap();
    let sidebar_bg = Color::from_hex("#111010").unwrap();
    let label_pink = Color::from_hex("#E5A4B4").unwrap();
    let label_dim  = Color::rgba(0.55, 0.52, 0.53, 1.0);

    let sidebar_w: u16 = 20; // cells

    vec![
        // background
        DrawCommand::Clear(bg),

        // sidebar panel
        DrawCommand::Block {
            x: 0, y: 0,
            width: sidebar_w, height: rows,
            fg: label_dim, bg: sidebar_bg,
            border: false,
        },

        // sidebar label
        DrawCommand::Text {
            x: 2, y: 1,
            max_width: sidebar_w.saturating_sub(4),
            content: "files".into(),
            fg: label_dim, bg: Some(sidebar_bg),
            bold: false, italic: false,
        },

        // editor label
        DrawCommand::Text {
            x: sidebar_w + 2, y: 1,
            max_width: cols.saturating_sub(sidebar_w + 4),
            content: "ribbon.".into(),
            fg: label_pink, bg: None,
            bold: true, italic: false,
        },
    ]
}
