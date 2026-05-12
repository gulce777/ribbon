//! layout definitions and flexbox constraints.
//!
//! this module acts as the bridge between lua's ui system and
//! rust's taffy layout engine. core doesn't calculate the pixels,
//! it only holds the rules.

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Dimension {
    /// the layout engine calculates the size automatically.
    Auto,
    /// an exact physical or logical pixel value.
    Px(f32),
    /// a percentage of the parent node's size (0.0 to 100.0).
    Percent(f32),
}

impl Default for Dimension {
    #[inline]
    fn default() -> Self {
        Self::Auto
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum FlexDirection {
    #[default]
    Row,
    Column,
    RowReverse,
    ColumnReverse,
}

/// defines how items are aligned along the main axis.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum JustifyContent {
    #[default]
    Start,
    End,
    Center,
    SpaceBetween,
    SpaceAround,
    SpaceEvenly,
}

/// defines how items are aligned along the cross axis.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum AlignItems {
    #[default]
    Stretch,
    Start,
    End,
    Center,
}

/// represents the four edges of a box, used for padding and margins.
#[derive(Debug, Clone, Copy, PartialEq, Default)]
pub struct Edges<T> {
    pub top: T,
    pub right: T,
    pub bottom: T,
    pub left: T,
}

impl<T: Clone> Edges<T> {
    /// creates an edge struct where all sides share the same value.
    #[inline]
    pub fn all(value: T) -> Self {
        Self {
            top: value.clone(),
            right: value.clone(),
            bottom: value.clone(),
            left: value,
        }
    }

    /// creates an edge struct with explicit values for each side.
    #[inline]
    pub fn new(top: T, right: T, bottom: T, left: T) -> Self {
        Self {
            top,
            right,
            bottom,
            left,
        }
    }
}

/// the structural constraints of a ui node.
/// lua builds this struct, and rust translates it into taffy nodes.
#[derive(Debug, Clone, PartialEq)]
pub struct NodeStyle {
    pub width: Dimension,
    pub height: Dimension,
    pub min_width: Dimension,
    pub min_height: Dimension,
    pub max_width: Dimension,
    pub max_height: Dimension,

    pub flex_direction: FlexDirection,
    pub justify_content: JustifyContent,
    pub align_items: AlignItems,
    pub flex_grow: f32,
    pub flex_shrink: f32,

    pub padding: Edges<Dimension>,
    pub margin: Edges<Dimension>,
}

impl Default for NodeStyle {
    fn default() -> Self {
        Self {
            width: Dimension::Auto,
            height: Dimension::Auto,
            min_width: Dimension::Auto,
            min_height: Dimension::Auto,
            max_width: Dimension::Auto,
            max_height: Dimension::Auto,

            flex_direction: FlexDirection::Row,
            justify_content: JustifyContent::Start,
            align_items: AlignItems::Stretch,

            flex_grow: 0.0,
            flex_shrink: 1.0,

            padding: Edges::all(Dimension::Auto),
            margin: Edges::all(Dimension::Auto),
        }
    }
}

impl NodeStyle {
    #[inline]
    pub fn fill() -> Self {
        Self {
            width: Dimension::Percent(100.0),
            height: Dimension::Percent(100.0),
            flex_grow: 1.0,
            ..Default::default()
        }
    }
}

#[cfg(test)]
mod layout_tests {
    use super::*;

    #[test]
    fn edge_all_creation() {
        let padding = Edges::all(Dimension::Px(8.0));
        assert_eq!(padding.top, Dimension::Px(8.0));
        assert_eq!(padding.left, Dimension::Px(8.0));
    }

    #[test]
    fn fill_helper() {
        let style = NodeStyle::fill();
        assert_eq!(style.width, Dimension::Percent(100.0));
        assert_eq!(style.flex_grow, 1.0);
        assert_eq!(style.flex_direction, FlexDirection::Row); // default fallback
    }
}
