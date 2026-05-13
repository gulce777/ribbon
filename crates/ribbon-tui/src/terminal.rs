//! terminal initialization and teardown.
//!
//! `Terminal` wraps ratatui's `Terminal<CrosstermBackend<Stdout>>` and handles
//! raw mode + alternate screen on construction, restoring the terminal in `Drop`
//! so a panic never leaves the user's shell corrupted.

use std::io::{self, Stdout};

use crossterm::{
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{backend::CrosstermBackend, Terminal as RatatuiTerminal};
use ribbon_core::{RibbonError, Result};

pub struct Terminal {
    pub inner: RatatuiTerminal<CrosstermBackend<Stdout>>,
}

impl Terminal {
    /// enters raw mode + alternate screen and creates the ratatui terminal.
    pub fn new() -> Result<Self> {
        enable_raw_mode().map_err(RibbonError::Io)?;
        let mut stdout = io::stdout();
        execute!(stdout, EnterAlternateScreen).map_err(RibbonError::Io)?;
        let backend = CrosstermBackend::new(io::stdout());
        let inner = RatatuiTerminal::new(backend).map_err(RibbonError::Io)?;
        Ok(Self { inner })
    }

    /// returns the current terminal size in (cols, rows).
    pub fn size(&self) -> Result<(u16, u16)> {
        let s = self.inner.size().map_err(RibbonError::Io)?;
        Ok((s.width, s.height))
    }
}

impl Drop for Terminal {
    fn drop(&mut self) {
        let _ = disable_raw_mode();
        let _ = execute!(self.inner.backend_mut(), LeaveAlternateScreen);
    }
}
