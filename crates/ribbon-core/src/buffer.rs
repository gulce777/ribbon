//! text buffer contracts and editing primitives.
//!
//! this module does not store any text. it defines the `BufferApi` trait:
//! a contract that the actual rope-backed memory engine (`ribbon-buffer`)
//! must implement. by keeping the interface here, the lua bridge and the
//! render engine can interact with text without carrying about how it's stored in memory.

use crate::error::Result;
use crate::id::BufferId;
use crate::primitives::{Position, Range};

/// represents an atomic change to a text buffer.
/// this is intentionally designed to be 1:1 compatible with the language server protocol (lsp).
///
/// - to insert text: provide an empty range (`start == end`).
/// - to delete text: provide an empty `new_text` string.
/// - to replace text: provide both a range and a replacement string.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TextEdit {
    pub range: Range,
    pub new_text: String,
}

impl TextEdit {
    /// creates a new edit operation.
    #[inline]
    pub fn new(range: Range, new_text: String) -> Self {
        Self { range, new_text }
    }

    /// helper to create a pure insertion.
    #[inline]
    pub fn insert(pos: Position, text: String) -> Self {
        Self {
            range: Range::cursor(pos),
            new_text: text,
        }
    }

    /// helper to create a pure deletion.
    #[inline]
    pub fn delete(range: Range) -> Self {
        Self {
            range,
            new_text: String::new(),
        }
    }
}

/// the universal contract for any text buffer in ribbon.
/// it must be `Send + Sync` so that background threads (like an lsp client or a file saver)
/// can read the buffer while the ui thread continues to render.
pub trait BufferApi: Send + Sync {
    /// returns the unique identifier of this buffer.
    fn id(&self) -> BufferId;

    /// returns the total number of lines in the buffer.
    /// even an empty file has at least 1 line.
    fn line_count(&self) -> usize;

    /// returns the total length of the buffer in bytes.
    fn byte_count(&self) -> usize;

    /// retrieves a specific line as a string.
    /// fails with `OutOfBounds` if the line index is greater than or equal to `line_count`.
    fn get_line(&self, line_index: usize) -> Result<String>;

    /// retrieves the exact text spanning the given range.
    /// fails if the range exceeds the buffer limits.
    fn get_text(&self, range: Range) -> Result<String>;

    /// applies a single atomic edit to the buffer.
    /// this operation should automatically update the internal rope and any undo history.
    fn apply_edit(&mut self, edit: TextEdit) -> Result<()>;

    /// applies multiple edits in a single atomic transaction.
    /// crucial for features like multi-cursor editing or complex formatters.
    fn apply_edits(&mut self, edits: Vec<TextEdit>) -> Result<()> {
        for edit in edits {
            self.apply_edit(edit)?;
        }
        Ok(())
    }

    /// inserts text directly at the specified position.
    /// this is a wrapper around `apply_edit`.
    fn insert_text(&mut self, pos: Position, text: &str) -> Result<()> {
        self.apply_edit(TextEdit::insert(pos, text.to_string()))
    }

    /// deletes the text within the specified range.
    /// this is a wrapper around `apply_edit`.
    fn delete_range(&mut self, range: Range) -> Result<()> {
        self.apply_edit(TextEdit::delete(range))
    }
}
