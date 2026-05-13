//! the lua bridge for ribbon.
//!
//! `LuaEngine` embeds a Lua 5.4 VM and exposes rust's capabilities
//! through the `ribbon._rust.*` table. the lua userland calls these
//! functions to drive layout, rendering, and events.

pub mod engine;

pub use engine::LuaEngine;
