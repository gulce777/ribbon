//! crossterm event → ribbon_core::event::Event normalization.
//!
//! ribbon's event system is terminal-agnostic. this module is the only place
//! that knows about crossterm. everything else in the editor sees clean
//! `ribbon_core::event::Event` values.

use std::time::Duration;

use crossterm::event::{
    self, Event as CtEvent, KeyCode, KeyEvent, KeyModifiers, MouseButton, MouseEvent,
    MouseEventKind,
};
use ribbon_core::{
    Result, RibbonError,
    event::{Event, Modifiers},
    primitives::{Point, Size},
};

/// polls for the next crossterm event with a timeout.
/// returns `None` if the timeout elapsed with no event.
pub fn next_event(timeout: Duration) -> Result<Option<Event>> {
    if event::poll(timeout).map_err(RibbonError::Io)? {
        let ct = event::read().map_err(RibbonError::Io)?;
        Ok(crossterm_to_ribbon(ct))
    } else {
        Ok(None)
    }
}

/// converts a raw crossterm event into a normalized ribbon event.
/// returns `None` for event kinds ribbon doesn't model (e.g. paste events).
pub fn crossterm_to_ribbon(ct: CtEvent) -> Option<Event> {
    match ct {
        CtEvent::Key(key) => Some(Event::KeyPress(key_to_string(key))),
        CtEvent::Resize(w, h) => Some(Event::Resize(Size::new(w as f32, h as f32))),
        CtEvent::Mouse(m) => mouse_to_ribbon(m),
        CtEvent::FocusGained => Some(Event::FocusGained),
        CtEvent::FocusLost => Some(Event::FocusLost),
        _ => None,
    }
}

/// converts a crossterm key event into a neovim-style key string.
///
/// examples:
///   - `j`          → `"<char:j>"`
///   - ctrl+w       → `"<c-w>"`
///   - alt+x        → `"<a-x>"`
///   - escape       → `"<esc>"`
///   - f5           → `"<f5>"`
fn key_to_string(key: KeyEvent) -> String {
    let ctrl = key.modifiers.contains(KeyModifiers::CONTROL);
    let alt = key.modifiers.contains(KeyModifiers::ALT);

    match key.code {
        KeyCode::Char(c) => {
            if ctrl {
                format!("<c-{}>", c.to_ascii_lowercase())
            } else if alt {
                format!("<a-{}>", c)
            } else {
                format!("<char:{}>", c)
            }
        }
        KeyCode::Esc => "<esc>".into(),
        KeyCode::Enter => "<enter>".into(),
        KeyCode::Backspace => "<bs>".into(),
        KeyCode::Delete => "<del>".into(),
        KeyCode::Tab => "<tab>".into(),
        KeyCode::BackTab => "<s-tab>".into(),
        KeyCode::Up => "<up>".into(),
        KeyCode::Down => "<down>".into(),
        KeyCode::Left => "<left>".into(),
        KeyCode::Right => "<right>".into(),
        KeyCode::Home => "<home>".into(),
        KeyCode::End => "<end>".into(),
        KeyCode::PageUp => "<pageup>".into(),
        KeyCode::PageDown => "<pagedown>".into(),
        KeyCode::F(n) => format!("<f{}>", n),
        _ => "<unknown>".into(),
    }
}

fn mouse_to_ribbon(m: MouseEvent) -> Option<Event> {
    let pos = Point::new(m.column as f32, m.row as f32);
    let mods = Modifiers {
        ctrl: m.modifiers.contains(KeyModifiers::CONTROL),
        alt: m.modifiers.contains(KeyModifiers::ALT),
        shift: m.modifiers.contains(KeyModifiers::SHIFT),
        logo: false,
    };

    match m.kind {
        MouseEventKind::Moved => Some(Event::MouseMove(pos)),
        MouseEventKind::Down(btn) => Some(Event::MouseClick {
            button: mouse_btn(btn),
            position: pos,
            modifiers: mods,
        }),
        MouseEventKind::Up(btn) => Some(Event::MouseRelease {
            button: mouse_btn(btn),
            position: pos,
            modifiers: mods,
        }),
        MouseEventKind::ScrollUp => Some(Event::Scroll {
            delta_x: 0.0,
            delta_y: -3.0,
            modifiers: mods,
        }),
        MouseEventKind::ScrollDown => Some(Event::Scroll {
            delta_x: 0.0,
            delta_y: 3.0,
            modifiers: mods,
        }),
        _ => None,
    }
}

#[inline]
fn mouse_btn(btn: MouseButton) -> u8 {
    match btn {
        MouseButton::Left => 1,
        MouseButton::Right => 2,
        MouseButton::Middle => 3,
    }
}
