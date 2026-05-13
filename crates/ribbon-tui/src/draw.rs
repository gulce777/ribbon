//! the draw command list — the contract between lua and the terminal.
//!
//! lua builds a `Vec<DrawCommand>` each frame. rust consumes it and
//! renders exactly what lua asked for using ratatui primitives.

use ribbon_core::color::Color;

/// a single drawing instruction produced by lua and consumed by the renderer.
#[derive(Debug, Clone)]
pub enum DrawCommand {
    Clear(Color),

    Block {
        x: u16,
        y: u16,
        width: u16,
        height: u16,
        fg: Color,
        bg: Color,
        border: bool,
    },

    Text {
        x: u16,
        y: u16,
        max_width: u16,
        content: String,
        fg: Color,
        bg: Option<Color>,
        bold: bool,
        italic: bool,
    },
}
