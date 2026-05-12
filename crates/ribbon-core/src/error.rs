use thiserror::Error;

/// the single, unified error type for the entire ribbon editor.
#[derive(Error, Debug)]
pub enum RibbonError {
    /// raised when attempting to access a buffer that doesn't exist or was closed.
    #[error("buffer not found: {0}")]
    BufferNotFound(usize),

    /// raised when a cursor or edit operation targets a position outside the text.
    #[error("position out of bounds: line {line}, col {col}")]
    OutOfBounds { line: usize, col: usize },

    /// standard file system and stream errors.
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),

    /// raised when the lua userland does something unexpected.
    /// stored as a string so core doesn't need a direct dependency on mlua.
    #[error("script error: {0}")]
    Script(String),

    /// raised when the layout engine fails to resolve a node or slot.
    #[error("layout error: {0}")]
    Layout(String),

    /// raised when wgpu fails to acquire a surface or draw a frame.
    #[error("render error: {0}")]
    Render(String),

    /// a generic fallback for unexpected core failures.
    #[error("internal error: {0}")]
    Internal(String),
}

pub type Result<T> = std::result::Result<T, RibbonError>;
