//! the core types for ribbon.
//!
//! this crate doesn't really *do* anything. it just holds the basic
//! shapes and definitions that the rest of the editor uses.

pub mod buffer;
pub mod color;
pub mod error;
pub mod event;
pub mod id;
pub mod layout;
pub mod primitives;

pub use error::{Result, RibbonError};
pub use primitives::{Point, Position, Range, Size};
