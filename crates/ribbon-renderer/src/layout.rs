use ribbon_core::layout::{
    AlignItems as CoreAlign, Dimension as CoreDimension, FlexDirection as CoreFlex,
    JustifyContent as CoreJustify, NodeStyle,
};
use taffy::prelude::*;
use taffy::style::{LengthPercentage, LengthPercentageAuto};

/// a wrapper around taffy's layout engine.
pub struct LayoutEngine {
    pub taffy: TaffyTree,
}

impl LayoutEngine {
    pub fn new() -> Self {
        Self {
            taffy: TaffyTree::new(),
        }
    }

    /// translates our engine-agnostic `NodeStyle` from `ribbon-core`
    /// into taffy's specific `Style` struct
    pub fn translate_style(style: &NodeStyle) -> Style {
        Style {
            display: Display::Flex,

            flex_direction: match style.flex_direction {
                CoreFlex::Row => FlexDirection::Row,
                CoreFlex::Column => FlexDirection::Column,
                CoreFlex::RowReverse => FlexDirection::RowReverse,
                CoreFlex::ColumnReverse => FlexDirection::ColumnReverse,
            },

            justify_content: Some(match style.justify_content {
                CoreJustify::Start => JustifyContent::FlexStart,
                CoreJustify::End => JustifyContent::FlexEnd,
                CoreJustify::Center => JustifyContent::Center,
                CoreJustify::SpaceBetween => JustifyContent::SpaceBetween,
                CoreJustify::SpaceAround => JustifyContent::SpaceAround,
                CoreJustify::SpaceEvenly => JustifyContent::SpaceEvenly,
            }),

            align_items: Some(match style.align_items {
                CoreAlign::Stretch => AlignItems::Stretch,
                CoreAlign::Start => AlignItems::FlexStart,
                CoreAlign::End => AlignItems::FlexEnd,
                CoreAlign::Center => AlignItems::Center,
            }),

            flex_grow: style.flex_grow,
            flex_shrink: style.flex_shrink,

            size: Size {
                width: translate_dim(style.width),
                height: translate_dim(style.height),
            },
            min_size: Size {
                width: translate_dim(style.min_width),
                height: translate_dim(style.min_height),
            },
            max_size: Size {
                width: translate_dim(style.max_width),
                height: translate_dim(style.max_height),
            },

            padding: Rect {
                left: translate_padding(style.padding.left),
                right: translate_padding(style.padding.right),
                top: translate_padding(style.padding.top),
                bottom: translate_padding(style.padding.bottom),
            },
            margin: Rect {
                left: translate_margin(style.margin.left),
                right: translate_margin(style.margin.right),
                top: translate_margin(style.margin.top),
                bottom: translate_margin(style.margin.bottom),
            },

            ..Default::default()
        }
    }
}

#[inline]
fn translate_dim(dim: CoreDimension) -> Dimension {
    match dim {
        CoreDimension::Auto => Dimension::auto(),
        CoreDimension::Px(val) => Dimension::length(val),
        CoreDimension::Percent(val) => Dimension::percent(val / 100.0), // taffy expects 0.0 to 1.0
    }
}

#[inline]
fn translate_padding(dim: CoreDimension) -> LengthPercentage {
    match dim {
        CoreDimension::Px(val) => LengthPercentage::from_length(val),
        CoreDimension::Percent(val) => LengthPercentage::from_percent(val / 100.0),
        CoreDimension::Auto => LengthPercentage::from_length(0.0),
    }
}

#[inline]
fn translate_margin(dim: CoreDimension) -> LengthPercentageAuto {
    match dim {
        CoreDimension::Auto => LengthPercentageAuto::AUTO,
        CoreDimension::Px(val) => LengthPercentageAuto::from_length(val),
        CoreDimension::Percent(val) => LengthPercentageAuto::from_percent(val / 100.0),
    }
}
