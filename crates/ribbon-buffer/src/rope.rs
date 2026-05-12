use ribbon_core::buffer::{BufferApi, TextEdit};
use ribbon_core::id::BufferId;
use ribbon_core::{Position, Range, Result, RibbonError};
use ropey::Rope;

/// a text buffer backed by a rope data structure.
pub struct RopeBuffer {
    id: BufferId,
    rope: Rope,
}

impl RopeBuffer {
    pub fn new(id: BufferId, text: &str) -> Self {
        Self {
            id,
            rope: Rope::from_str(text),
        }
    }

    pub fn empty(id: BufferId) -> Self {
        Self {
            id,
            rope: Rope::new(),
        }
    }

    /// helper function. translates our 2d `Position` into ropey's
    /// 1d absolute character index. this prevents utf-8 panics
    /// because ropey counts unicode characters, not raw bytes.
    fn pos_to_char_idx(&self, pos: Position) -> Result<usize> {
        let line_idx = pos.line;

        if line_idx >= self.rope.len_lines() {
            return Err(RibbonError::OutOfBounds {
                line: pos.line,
                col: pos.col,
            });
        }

        let line_start_char = self.rope.line_to_char(line_idx);
        let line = self.rope.line(line_idx);

        if pos.col > line.len_chars() {
            return Err(RibbonError::OutOfBounds {
                line: pos.line,
                col: pos.col,
            });
        }

        Ok(line_start_char + pos.col)
    }
}

impl BufferApi for RopeBuffer {
    fn id(&self) -> BufferId {
        self.id
    }

    fn line_count(&self) -> usize {
        self.rope.len_lines()
    }

    fn byte_count(&self) -> usize {
        self.rope.len_bytes()
    }

    fn get_line(&self, line_index: usize) -> Result<String> {
        if line_index >= self.rope.len_lines() {
            return Err(RibbonError::OutOfBounds {
                line: line_index,
                col: 0,
            });
        }

        Ok(self.rope.line(line_index).to_string())
    }

    fn get_text(&self, range: Range) -> Result<String> {
        let start_idx = self.pos_to_char_idx(range.start)?;
        let end_idx = self.pos_to_char_idx(range.end)?;

        if start_idx > end_idx {
            return Err(RibbonError::Internal(
                "invalid range for get_text: start > end".to_string(),
            ));
        }

        Ok(self.rope.slice(start_idx..end_idx).to_string())
    }

    fn apply_edit(&mut self, edit: TextEdit) -> Result<()> {
        let start_idx = self.pos_to_char_idx(edit.range.start)?;
        let end_idx = self.pos_to_char_idx(edit.range.end)?;

        // ropey is smart. if we give it a range to remove and it's empty (start == end),
        // it just does nothing. same for insert with an empty string.
        // so this cleanly handles insertions, deletions and replacements.
        self.rope.remove(start_idx..end_idx);
        self.rope.insert(start_idx, &edit.new_text);

        Ok(())
    }
}
