//! the terminal rendering layer for ribbon.
//!
//! public api:
//! - [`Renderer`]    — create once, call `draw_frame` each frame.
//! - [`DrawCommand`] — the typed drawing instructions lua produces.
//! - [`LayoutEngine`]— ratatui-backed constraint layout.
//! - [`next_event`]  — blocking/polling crossterm → ribbon event bridge.

pub mod draw;
pub mod event;
pub mod layout;
pub mod renderer;
pub mod terminal;

pub use draw::DrawCommand;
pub use layout::LayoutEngine;
pub use renderer::Renderer;
