# overview.

ribbon is a code editor where everything is defined in lua. not "configurable through a
settings file". actually written in lua, from scratch, by you. the rust core just draws
what lua tells it to draw.

## the core idea.

most editors make decisions for you. they have statusline, they have a tab bar, they have
opinions about what `j` does. you can override these things, but underneath, the decisions
are still there, baked into the binary.

the rust core knows how to open a window, draw pixels and read files. that's genuinely it. no
keybind is hardcoded, no panel is built in. the concept of "statusline" does not exist at the
rust level, it's just a rectangle that some lua file drew at the bottom of the screen and
decided to call a statusline.

you can delete that lua file and ribbon *won't complain*. it'll just stop drawing that rectangle.

this is more radical than it sounds. every opinion lives in lua, which means every opinion is yours
to change.

## what ships with ribbon?

ribbon comes with a `runtime/` directory. inside it:

```
runtime/
├── core/       <- ribbon's api guarantees. do not modify.
└── default/    <- reference implementations. modify freely.
```

`core/` is the api contract. the primitives here are guaranteed to work in every version of ribbon.
plugins depend on this layer.

`default/` is a starting point. these files show how to build common editor features using the core api.
they are not special. a user who deletes `statusline.lua` loses the statusline. ribbon does not care.
a user who rewrites it gets exactly the statusline they want.

## load order.

1. `runtime/core/init.lua`
2. `runtime/default/*.lua`
3. `~/.config/ribbon/init.lua`

each layer can override

## in practice.

if you just install ribbon and open it, it works. you get a clean editor with vim-style keybinds and
minimal statusline. nothing overwhelming.

if you want to change something small (remap a key, tweak a color), you write a few lines in your
`init.lua`. done.

if you want to tear the whole thing down and rebuild it your way, you can do that too. some people will.
ribbon is ready for it.

## a few things ribbon believes in.

**lua makes the decisions and rust executes them.** anything with an opinion attached belongs in lua.

**there is no magic.** the "statusline" is a rectangle, the "file tree" is a panel, ribbon doesn't give them
special treatment. lua drew them, and lua can undraw them.

**explicit is better.** `ui.px(200)` says what it means. `200` doesn't.

**quiet defaults.** the default config is minimal on purpose. it gets out of your way.

## where to go next?

- [architecture.md](architecture.md) - the rust/lua split in detail
