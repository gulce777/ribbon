//! the system of the editor.
//!
//! this module defines every action that can wake the editor up from its idle state.
//! we do not leak `winit` or os-specific types here. everything is normalized into
//! pure data that the lua userland can consume.

use crate::primitives::{Point, Size};
use std::path::PathBuf;

/// represents the state of keyboard modifiers during an event.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub struct Modifiers {
    pub ctrl: bool,
    pub alt: bool,
    pub shift: bool,
    pub logo: bool, // cmd on mac, win key on windows
}

impl Modifiers {
    /// returns true if no modifiers are currently pressed.
    #[inline]
    pub fn is_empty(self) -> bool {
        !self.ctrl && !self.alt && !self.shift && !self.logo
    }
}

/// the unified event enum.
#[derive(Debug, Clone, PartialEq)]
pub enum Event {
    /// a normalized keypress.
    /// rust translates raw hardware keys into simple strings like "j", "<c-w>", or "<esc>".
    /// lua takes this string and runs it through the chord engine.
    KeyPress(String),

    /// the window was resized.
    /// taffy needs to recalculate the layout and lua needs to redraw the panels.
    Resize(Size),

    /// the mouse moved to a new local coordinate.
    MouseMove(Point),

    /// a mouse button was pressed.
    /// `button` is typically 1 (left), 2 (right), or 3 (middle).
    MouseClick {
        button: u8,
        position: Point,
        modifiers: Modifiers,
    },

    /// a mouse button was released.
    MouseRelease {
        button: u8,
        position: Point,
        modifiers: Modifiers,
    },

    /// the scroll wheel or trackpad was used.
    Scroll {
        delta_x: f32,
        delta_y: f32,
        modifiers: Modifiers,
    },

    /// a scheduled timer finished.
    /// this is the backbone of lua's asynchronous chord timeout mechanism
    Timeout(usize),

    /// a file was physically dragged and dropped into the editor window.
    FileDrop(PathBuf),

    /// the editor gained or lost os-level focus.
    /// useful for auto-saving or dimming the interface.
    FocusGained,
    FocusLost,

    /// an explicit command to shut down the editor.
    Quit,
}
