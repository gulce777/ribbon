# contributing to ribbon.

first of all, thank you for wanting to help build ribbon.

this project follows a very strict aesthetic. minimal, quiet and readable. to keep the
repository looking clean, please follow these simple guidelines.

### 1. the golden rule: all lowercase.

just like the design of the editor itself, our repository is entirely lowercase.
- commit messages must be lowercase.
- pull request titles must be lowercase.
- file names must be lowercase (if possible).

### 2. commit messages.

we do not use strict conventional commits (like `feat:` or `chore:`). instead, we use
simple, plaing english verbs followed by a colon.

please use one of these verbs:
- `add:` (for new features or files)
- `fix:` (for bug fixes)
- `update:` (for refactoring or improvements)
- `clean:` (for removing dead code or unused files)
- `docs:` (for readme or comment changes)

**using scopes (optional but helpful):**

if your change only affects a specific part of the editor, you can add a scope in parantheses.

**good commit examples:**
- `add(theme): pastel color palette`
- `fix: crash when opening large files`
- `clean: removed old rendering engine`

**bad commit examples (will be rejected):**
- `Fixed crash`
- `feat: Added theme`

### 3. opening a pull request.

when you open a pr, keep the description short and to the point.

### 4. code style.

- for rust: run `cargo fmt` before committing.
- for lua: keep the code clean, use soft indents (spaces, not tabs).
