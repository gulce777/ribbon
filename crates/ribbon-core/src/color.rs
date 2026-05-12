//! color representations.
//!
//! this module handles the translation of colors from human-readable
//! formats (like hex codes) into the normalized `[f32; 4]` array required
//! by wgpu for rendering.

use crate::error::{Result, RibbonError};

/// an rgba color, represented by four `f32` values ranging from 0.0 to 1.0.
/// this is the exact format required by wgpu shaders.
#[derive(Debug, Clone, Copy, PartialEq, Default)]
pub struct Color {
    pub r: f32,
    pub g: f32,
    pub b: f32,
    pub a: f32,
}

impl Color {
    /// creates a new color with an explicit alpha channel.
    #[inline]
    pub fn rgba(r: f32, g: f32, b: f32, a: f32) -> Self {
        Self { r, g, b, a }
    }

    /// creates a new color, fully opaque (alpha = 1.0).
    #[inline]
    pub fn rgb(r: f32, g: f32, b: f32) -> Self {
        Self { r, g, b, a: 1.0 }
    }

    /// converts the color into an array for direct injection into a wgpu uniform buffer.
    #[inline]
    pub fn to_array(self) -> [f32; 4] {
        [self.r, self.g, self.b, self.a]
    }

    /// parses a standard hex string (e.g., "#E5A4B4" or "#1A1819").
    /// assumes the alpha channel is fully opaque if not provided.
    pub fn from_hex(hex: &str) -> Result<Self> {
        let hex = hex.trim_start_matches('#');
        let len = hex.len();

        if len != 6 && len != 8 {
            return Err(RibbonError::Internal(format!(
                "invalid hex color length: '{}'",
                hex
            )));
        }

        let r = u8::from_str_radix(&hex[0..2], 16)
            .map_err(|_| RibbonError::Internal(format!("invalid red channel in '{}'", hex)))?
            as f32
            / 255.0;
        let g = u8::from_str_radix(&hex[2..4], 16)
            .map_err(|_| RibbonError::Internal(format!("invalid green channel in '{}'", hex)))?
            as f32
            / 255.0;
        let b = u8::from_str_radix(&hex[4..6], 16)
            .map_err(|_| RibbonError::Internal(format!("invalid blue channel in '{}'", hex)))?
            as f32
            / 255.0;

        let a = if len == 8 {
            u8::from_str_radix(&hex[6..8], 16)
                .map_err(|_| RibbonError::Internal(format!("invalid alpha channel in '{}'", hex)))?
                as f32
                / 255.0
        } else {
            1.0
        };

        Ok(Self { r, g, b, a })
    }
}

// predefined colors.
impl Color {
    /// a pure white color, primarily for fallback rendering.
    #[inline]
    pub fn white() -> Self {
        Self::rgb(1.0, 1.0, 1.0)
    }

    /// a pure black color.
    #[inline]
    pub fn black() -> Self {
        Self::rgb(0.0, 0.0, 0.0)
    }

    /// a completely transparent color.
    #[inline]
    pub fn transparent() -> Self {
        Self::rgba(0.0, 0.0, 0.0, 0.0)
    }
}

impl std::fmt::Display for Color {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "rgba({:.2}, {:.2}, {:.2}, {:.2})",
            self.r, self.g, self.b, self.a
        )
    }
}

#[cfg(test)]
mod color_tests {
    use super::*;

    #[test]
    fn hex_parsing() {
        let pink = Color::from_hex("#E5A4B4").unwrap();
        assert!((pink.r - 0.898).abs() < 0.01);
        assert!((pink.g - 0.643).abs() < 0.01);
        assert!((pink.b - 0.705).abs() < 0.01);
        assert_eq!(pink.a, 1.0);
    }

    #[test]
    fn hex_parsing_with_alpha() {
        let translucent_black = Color::from_hex("#00000080").unwrap();
        assert_eq!(translucent_black.r, 0.0);
        assert_eq!(translucent_black.g, 0.0);
        assert_eq!(translucent_black.b, 0.0);
        assert!((translucent_black.a - 0.5019).abs() < 0.01);
    }

    #[test]
    fn invalid_hex() {
        assert!(Color::from_hex("#E5A").is_err());
        assert!(Color::from_hex("#ZZZZZZ").is_err());
    }

    #[test]
    fn to_array() {
        let white = Color::rgb(1.0, 1.0, 1.0);
        assert_eq!(white.to_array(), [1.0, 1.0, 1.0, 1.0]);
    }
}
