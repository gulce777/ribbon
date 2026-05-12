<div align="center">
    <img src="logo.svg" alt="ribbon logo" width="100%"/>
    <br/> <br/>
    <a href="license">
        <img src="https://img.shields.io/badge/license-unlicense-e5a4b4?style=flat-square&labelColor=1a1819&logo=unlicense&logoColor=e5a4b4" alt="license">
    </a>
    <a href="https://www.rust-lang.org/">
        <img src="https://img.shields.io/badge/core-rust-e5a4b4?style=flat-square&labelColor=1a1819&logo=rust&logoColor=e5a4b4" alt="rust">
    </a>
    <a href="https://www.lua.org/">
        <img src="https://img.shields.io/badge/scripting-lua-e5a4b4?style=flat-square&labelColor=1a1819&logo=lua&logoColor=e5a4b4" alt="lua">
    </a>
    <a href="">
        <img src="https://img.shields.io/badge/made%20with-%E2%99%A5-e5a4b4?style=flat-square&labelColor=1a1819" alt="made with love!">
    </a>
</div>

---

ribbon is a boutique code editor.

### features.
- **gpu rendering:** powered by [`wgpu`](https://wgpu.rs/).
- **scriptable:** the entire interface and editor logic are written in [lua](https://lua.org/).
- **quiet design:** built with a minimal visual footprint.

### architecture.

there is a very strict split in the architecture:

1. **the rust core:** does the boring stuff. memory management, drawing pixels on the screen and reading files.
2. **the lua userland:** does the fun stuff. keybinds, ui layout and custom commands. you have full control over this part.

### customizing.

customizing ribbon is straightforward. if you want to change something, you just write lua.

### contributing.

contributions are welcome. whether it is optimizing the rust core or designing a new theme, feel free to open an
[issue](https://github.com/gulce777/ribbon/issues) or a [pull request](https://github.com/gulce777/ribbon/pulls).

### license.

[unlicense](license). it belongs to you now.
