//! top-level renderer — the single entry point for all terminal drawing.
//!
//! `Renderer` owns the terminal handle and the layout engine.
//! callers only need `draw_frame(&[DrawCommand])` each iteration.

use std::time::Duration;

use ratatui::{
    Frame,
    layout::{Position, Rect},
    style::{Color as RColor, Modifier, Style},
    text::Span,
    widgets::{Block, Borders, Paragraph},
};
use ribbon_core::{Result, color::Color, event::Event};

use crate::{draw::DrawCommand, event::next_event, layout::LayoutEngine, terminal::Terminal};

pub struct Renderer {
    pub terminal: Terminal,
    pub layout: LayoutEngine,
}

impl Renderer {
    pub fn new() -> Result<Self> {
        Ok(Self {
            terminal: Terminal::new()?,
            layout: LayoutEngine::new(),
        })
    }

    /// current terminal size as `(cols, rows)`.
    pub fn size(&self) -> Result<(u16, u16)> {
        self.terminal.size()
    }

    /// draws a complete frame from a list of `DrawCommand`s.
    ///
    /// commands are processed in order:
    /// - `Clear` sets the background (last one wins).
    /// - `Block` and `Text` are drawn in sequence — later commands appear on top.
    pub fn draw_frame(&mut self, commands: &[DrawCommand]) -> Result<()> {
        let commands = commands.to_vec();
        self.terminal
            .inner
            .draw(|frame| render(frame, &commands))
            .map_err(ribbon_core::RibbonError::Io)?;
        Ok(())
    }

    /// polls for the next event.
    /// returns `None` if the timeout elapsed with no event.
    pub fn next_event(&self, timeout: Duration) -> Result<Option<Event>> {
        next_event(timeout)
    }
}

fn render(frame: &mut Frame, commands: &[DrawCommand]) {
    let mut cursor: Option<(u16, u16)> = None;

    for cmd in commands {
        match cmd {
            DrawCommand::Clear(c) => {
                let style = Style::default().bg(to_rcolor(c));
                let block = Block::default().style(style);
                frame.render_widget(block, frame.area());
            }

            DrawCommand::Block {
                x,
                y,
                width,
                height,
                fg,
                bg,
                border,
            } => {
                let area = Rect::new(*x, *y, *width, *height);
                let mut block =
                    Block::default().style(Style::default().fg(to_rcolor(fg)).bg(to_rcolor(bg)));
                if *border {
                    block = block.borders(Borders::ALL);
                }
                frame.render_widget(block, area);
            }

            DrawCommand::Text {
                x,
                y,
                max_width,
                content,
                fg,
                bg,
                bold,
                italic,
            } => {
                let area = Rect::new(*x, *y, *max_width, 1);
                let mut style = Style::default().fg(to_rcolor(fg));
                if let Some(bg_color) = bg {
                    style = style.bg(to_rcolor(bg_color));
                }
                if *bold {
                    style = style.add_modifier(Modifier::BOLD);
                }
                if *italic {
                    style = style.add_modifier(Modifier::ITALIC);
                }
                let para = Paragraph::new(Span::styled(content.as_str(), style));
                frame.render_widget(para, area);
            }
            DrawCommand::SetCursor { x, y } => {
                cursor = Some((*x, *y));
            }
        }
    }

    if let Some((x, y)) = cursor {
        frame.set_cursor_position(Position::new(x, y));
    }
}

#[inline]
fn to_rcolor(c: &Color) -> RColor {
    RColor::Rgb(
        (c.r * 255.0) as u8,
        (c.g * 255.0) as u8,
        (c.b * 255.0) as u8,
    )
}
