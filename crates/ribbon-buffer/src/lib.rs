//! the memory of the ribbon editor.
//!
//! this crate implements the `BufferApi` using a highly optimized rote data structure.
//! it is completely unaware of the ui, lua or how the text is drawn. it just holds
//! strings and moves bytes around very, very fast.

pub mod rope;

pub use rope::RopeBuffer;
