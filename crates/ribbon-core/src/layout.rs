//! layout definitions.
//!
//! this module provides the building blocks for describing ui layout.
//! constraints are expressed in cell units (columns / rows), which map
//! directly to ratatui's layout system in `ribbon-tui`.

/// the direction in which children are laid out.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum Direction {
    /// children are arranged left to right (columns).
    #[default]
    Horizontal,
    /// children are arranged top to bottom (rows).
    Vertical,
}

/// a sizing constraint for a layout node.
/// mirrors ratatui's `Constraint` so translation is zero-cost.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Constraint {
    /// an exact number of cells.
    Length(u16),
    /// a percentage of the parent's available space (0–100).
    Percentage(u16),
    /// fill remaining space, weighted by the given value.
    /// equivalent to css `flex-grow`.
    Fill(u16),
    /// a minimum number of cells; the node may grow larger.
    Min(u16),
    /// a maximum number of cells; the node may shrink smaller.
    Max(u16),
    /// a ratio of the parent's available space.
    /// `Ratio(1, 3)` means "take one third".
    Ratio(u32, u32),
}

impl Default for Constraint {
    fn default() -> Self {
        Self::Fill(1)
    }
}

/// the structural description of a ui node.
/// lua builds this; rust resolves it to pixel-precise cell rects.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct NodeStyle {
    /// how children of this node are arranged.
    pub direction: Direction,
    /// how this node sizes itself within its parent.
    pub constraint: Constraint,
}

impl NodeStyle {
    /// a node that fills all available space. useful for the root or editor panels.
    pub fn fill() -> Self {
        Self {
            direction: Direction::Horizontal,
            constraint: Constraint::Fill(1),
        }
    }

    /// a node with a fixed cell width or height.
    pub fn length(cells: u16) -> Self {
        Self {
            constraint: Constraint::Length(cells),
            ..Default::default()
        }
    }

    /// a node that takes a percentage of its parent.
    pub fn percent(pct: u16) -> Self {
        Self {
            constraint: Constraint::Percentage(pct),
            ..Default::default()
        }
    }

    /// a node that takes a ratio of its parent.
    pub fn ratio(a: u32, b: u32) -> Self {
        Self {
            constraint: Constraint::Ratio(a, b),
            ..Default::default()
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fill_helper() {
        let s = NodeStyle::fill();
        assert_eq!(s.constraint, Constraint::Fill(1));
        assert_eq!(s.direction, Direction::Horizontal);
    }

    #[test]
    fn length_helper() {
        let s = NodeStyle::length(40);
        assert_eq!(s.constraint, Constraint::Length(40));
    }

    #[test]
    fn ratio_helper() {
        let s = NodeStyle::ratio(1, 3);
        assert_eq!(s.constraint, Constraint::Ratio(1, 3));
    }
}
