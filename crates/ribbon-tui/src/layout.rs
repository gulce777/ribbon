//! layout engine.
//!
//! `LayoutEngine` stores a tree of nodes. each node has a `NodeStyle`
//! (direction + constraint) and an ordered list of children. after `compute()`
//! runs against the terminal size, `get_layout()` returns each node's
//! exact cell rect.

use std::collections::HashMap;

use ratatui::layout::{Constraint as RConstraint, Direction as RDirection, Layout, Rect};
use ribbon_core::{
    id::NodeId,
    layout::{Constraint, Direction, NodeStyle},
    RibbonError, Result,
};

struct LayoutNode {
    style: NodeStyle,
    children: Vec<NodeId>,
}

pub struct LayoutEngine {
    nodes: HashMap<NodeId, LayoutNode>,
    computed: HashMap<NodeId, Rect>,
    next_id: usize,
    root: Option<NodeId>,
}

impl LayoutEngine {
    pub fn new() -> Self {
        Self {
            nodes: HashMap::new(),
            computed: HashMap::new(),
            next_id: 0,
            root: None,
        }
    }

    fn alloc_id(&mut self) -> NodeId {
        let id = NodeId::new(self.next_id);
        self.next_id += 1;
        id
    }

    /// creates a new layout node and returns its id.
    pub fn add_node(&mut self, style: NodeStyle) -> NodeId {
        let id = self.alloc_id();
        self.nodes.insert(id, LayoutNode { style, children: vec![] });
        id
    }

    /// sets the ordered children of `parent`.
    pub fn set_children(&mut self, parent: NodeId, children: Vec<NodeId>) -> Result<()> {
        let node = self.nodes.get_mut(&parent)
            .ok_or_else(|| RibbonError::Layout(format!("node {} not found", parent)))?;
        node.children = children;
        Ok(())
    }

    /// marks `node` as the root for subsequent `compute()` calls.
    pub fn set_root(&mut self, node: NodeId) {
        self.root = Some(node);
    }

    /// computes the cell rects for the entire tree given the terminal size.
    /// must be called after setting up nodes/children and after every resize.
    pub fn compute(&mut self, cols: u16, rows: u16) -> Result<()> {
        let root = self.root
            .ok_or_else(|| RibbonError::Layout("no root node set".into()))?;
        let area = Rect::new(0, 0, cols, rows);
        self.computed.clear();
        self.resolve(root, area);
        Ok(())
    }

    /// returns the computed `Rect` (in cell units) for `node`.
    pub fn get_layout(&self, node: NodeId) -> Result<(u16, u16, u16, u16)> {
        let r = self.computed.get(&node)
            .ok_or_else(|| RibbonError::Layout(format!("node {} has no computed layout (call compute() first)", node)))?;
        Ok((r.x, r.y, r.width, r.height))
    }

    // --- internal ---

    fn resolve(&mut self, node: NodeId, area: Rect) {
        self.computed.insert(node, area);

        let children: Vec<NodeId> = self.nodes
            .get(&node)
            .map(|n| n.children.clone())
            .unwrap_or_default();

        if children.is_empty() {
            return;
        }

        let direction = self.nodes.get(&node)
            .map(|n| n.style.direction)
            .unwrap_or_default();

        let constraints: Vec<RConstraint> = children.iter()
            .filter_map(|c| self.nodes.get(c))
            .map(|n| to_ratatui_constraint(n.style.constraint))
            .collect();

        let rects = Layout::default()
            .direction(to_ratatui_direction(direction))
            .constraints(constraints)
            .split(area);

        for (child, rect) in children.into_iter().zip(rects.iter()) {
            self.resolve(child, *rect);
        }
    }
}

impl Default for LayoutEngine {
    fn default() -> Self {
        Self::new()
    }
}

#[inline]
fn to_ratatui_constraint(c: Constraint) -> RConstraint {
    match c {
        Constraint::Length(n)     => RConstraint::Length(n),
        Constraint::Percentage(n) => RConstraint::Percentage(n),
        Constraint::Fill(n)       => RConstraint::Fill(n),
        Constraint::Min(n)        => RConstraint::Min(n),
        Constraint::Max(n)        => RConstraint::Max(n),
    }
}

#[inline]
fn to_ratatui_direction(d: Direction) -> RDirection {
    match d {
        Direction::Horizontal => RDirection::Horizontal,
        Direction::Vertical   => RDirection::Vertical,
    }
}
