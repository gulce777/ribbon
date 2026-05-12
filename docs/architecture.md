# architecture.

rust handles the heavy lifting and lua handles the logic. there is a hard boundary
between the two: rust doesn't really know what a text editor is, and lua doesn't know
how to allocate memory or talk to the gpu.

## the crate structure.

to keep the codebase clean and prevent tangled dependencies, the rust core is split into
a few specific crates.

- `ribbon-core`: just the basic vocabulary. it holds shared types and standard errors. it does zero actual work.
- `ribbon-buffer`: the memory manager. it uses a rope data structure to hold the text efficiently.
- `ribbon-renderer`: the graphics layer. powered by `wgpu` and `taffy`.
- `ribbon-lua`: the bridge. this uses `mlua` to expose rust's raw functions to the lua environment.
- `ribbon-app`: the entry point. it sets up the window, binds the crates together and starts the event loop.

## the boundary.

calling rust from lua (and vice versa) is fast, but doing it wrong creates bottlenecks. we
keep things fast by making communication declarative.

for example, when you resize the window, lua doesn't sit there calculating the new x and y
coordinates of every panel. lua just says "this panel should take up 20% of the screen."
rust's layout engine does the actual pixel math. rust handles the complex text shaping and
font fallback.

## the frame loop.

ribbon is reactive. it sits completely idle, using almost zero cpu, until an event actually happens.
here is the exact flow when you press a key:

1. **hardware event:** you press `j`. rust catches the operating system event.
2. **forwarding:** rust simply formats this into a string like `"<char:j>"` and passes it to the lua event bus.
3. **resolution:** lua receives it. the keymap engine checks the current mode, it sees you are in normal mode. and `j` is mapped to the `cursor.move_down()` function.
4. **execution:** lua runs that function, which calls the rust api to move the actual cursor in the buffer.
5. **invalidation:** because the cursor moved, lua tells rust to invalidate the main text panel.
6. **render:** control goes back to the rust loop. it sees the invalidation, re-evaluates the layout if necessary and draws the new frame.
