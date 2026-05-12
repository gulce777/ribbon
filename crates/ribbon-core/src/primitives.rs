/// a zero-indexed position in a text buffer.
/// line 0, col 0 is the first character of the first line.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Default)]
pub struct Position {
    pub line: usize,
    pub col: usize,
}

impl Position {
    #[inline]
    pub fn new(line: usize, col: usize) -> Self {
        Self { line, col }
    }

    /// the very beginning of a buffer.
    #[inline]
    pub fn zero() -> Self {
        Self { line: 0, col: 0 }
    }

    /// returns true if this position comes before `other`.
    #[inline]
    pub fn is_before(self, other: Self) -> bool {
        self < other
    }

    /// returns true if this position comes after `other`.
    #[inline]
    pub fn is_after(self, other: Self) -> bool {
        self > other
    }
}

impl std::fmt::Display for Position {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}:{}", self.line + 1, self.col + 1)
    }
}

/// a contiguous range in a text buffer, defined by two positions.
/// `start` is always <= `end`. use `Range::new` to construct, it normalizes order.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Default)]
pub struct Range {
    pub start: Position,
    pub end: Position,
}

impl Range {
    /// creates a range, normalizes so that start <= end.
    #[inline]
    pub fn new(a: Position, b: Position) -> Self {
        if a <= b {
            Self { start: a, end: b }
        } else {
            Self { start: b, end: a }
        }
    }

    /// a zero-length range at a single position (cursor position).
    #[inline]
    pub fn cursor(pos: Position) -> Self {
        Self {
            start: pos,
            end: pos,
        }
    }

    /// returns true if the range spans zero characters.
    #[inline]
    pub fn is_empty(self) -> bool {
        self.start == self.end
    }

    /// returns true if `pos` falls within [start, end).
    #[inline]
    pub fn contains(self, pos: Position) -> bool {
        pos >= self.start && pos < self.end
    }

    /// returns true if this range overlaps with `other`.
    #[inline]
    pub fn overlaps(self, other: Self) -> bool {
        self.start < other.end && other.start < self.end
    }
}

impl std::fmt::Display for Range {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{} -> {}", self.start, self.end)
    }
}

/// a point in 2d space, used for ui coordinates and rendering.
/// coordinats are typically in physical or logical pixels.
#[derive(Debug, Clone, Copy, PartialEq, Default)]
pub struct Point {
    pub x: f32,
    pub y: f32,
}

impl Point {
    /// creates a new point.
    #[inline]
    pub fn new(x: f32, y: f32) -> Self {
        Self { x, y }
    }

    /// returns a point at the origin (0.0, 0.0).
    #[inline]
    pub fn zero() -> Self {
        Self { x: 0.0, y: 0.0 }
    }
}

impl std::fmt::Display for Point {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "({}px, {}px)", self.x, self.y)
    }
}

/// a 2d size, representing width and height.
/// typically used for panel dimensions and layout bounds.
#[derive(Debug, Clone, Copy, PartialEq, Default)]
pub struct Size {
    pub width: f32,
    pub height: f32,
}

impl Size {
    /// creates a new size.
    #[inline]
    pub fn new(width: f32, height: f32) -> Self {
        Self { width, height }
    }

    /// creates a size with zero width and height.
    #[inline]
    pub fn zero() -> Self {
        Self {
            width: 0.0,
            height: 0.0,
        }
    }
}

impl std::fmt::Display for Size {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}x{}", self.width, self.height)
    }
}

/// a 2d rectangle, defined by a position (x, y) and a size (width, height).
/// used for panel boundaries, layout calculation, and collision/hover detection.
#[derive(Debug, Clone, Copy, PartialEq, Default)]
pub struct Rect {
    pub position: Point,
    pub size: Size,
}

impl Rect {
    #[inline]
    pub fn new(position: Point, size: Size) -> Self {
        Self { position, size }
    }

    pub fn from_values(x: f32, y: f32, width: f32, height: f32) -> Self {
        Self {
            position: Point::new(x, y),
            size: Size::new(width, height),
        }
    }

    #[inline]
    pub fn zero() -> Self {
        Self {
            position: Point::zero(),
            size: Size::zero(),
        }
    }

    #[inline]
    pub fn right(self) -> f32 {
        self.position.x + self.size.width as f32
    }

    #[inline]
    pub fn bottom(self) -> f32 {
        self.position.y + self.size.height as f32
    }

    #[inline]
    pub fn contains_point(self, point: Point) -> bool {
        point.x >= self.position.x
            && point.x <= self.position.x + self.size.width
            && point.y >= self.position.y
            && point.y <= self.position.y + self.size.height
    }
}

impl std::fmt::Display for Rect {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "[pos: {}, size: {}]", self.position, self.size)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn position_ordering() {
        let a = Position::new(0, 5);
        let b = Position::new(1, 0);
        assert!(a < b);
        assert!(a.is_before(b));
        assert!(b.is_after(a));
    }

    #[test]
    fn range_normalizes_order() {
        let a = Position::new(2, 0);
        let b = Position::new(0, 5);
        let r = Range::new(a, b);
        assert_eq!(r.start, b);
        assert_eq!(r.end, a);
    }

    #[test]
    fn range_contains() {
        let r = Range::new(Position::new(0, 0), Position::new(0, 10));
        assert!(r.contains(Position::new(0, 5)));
        assert!(!r.contains(Position::new(0, 10))); // end is exclusive
    }

    #[test]
    fn range_overlap() {
        let a = Range::new(Position::new(0, 0), Position::new(0, 10));
        let b = Range::new(Position::new(0, 5), Position::new(0, 15));
        let c = Range::new(Position::new(0, 10), Position::new(0, 20));
        assert!(a.overlaps(b));
        assert!(!a.overlaps(c)); // touching edges don't overlap
    }
}
