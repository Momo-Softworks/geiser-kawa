# geiser-kawa — Geiser backend for Kawa Scheme

Pure-Scheme backend for [Geiser](https://github.com/emacsmirror/geiser)
supporting the [Kawa](https://www.gnu.org/software/kawa/) Scheme
implementation.

## Architecture

All introspection lives in `src/geiser/*.scm` — Scheme modules loaded by
Kawa at REPL startup via `-Dkawa.import.path`.  No Java middleware.

| File | Purpose |
|------|---------|
| `emacs.scm` | Entry point, re-exports all procedures |
| `eval.scm` | Expression evaluation + result formatting |
| `complete.scm` | Scheme symbol + Java member completion |
| `classpath.scm` | Classpath scanning for Java class name completion |
| `doc.scm` | Autodoc / signature extraction |
| `modules.scm` | Module enumeration |
| `macro.scm` | Macro expansion |
| `location.scm` | M-. source location (decompiled Minecraft sources) |
| `string-util.scm` | String utilities (avoids Kawa 3.1.1 char-literal bugs) |

## Guix

Packaged for GNU Guix at `~/.config/guix/modules/packages/geiser-kawa.scm`.

```
guix build -L ~/.config/guix/modules geiser-kawa
```

## Testing

```
kawa -Dkawa.import.path=src -f tests/test.scm
```

22 tests covering eval, completions, classpath scanning, autodoc, and
location.  No Emacs required.

## Emacs

Requires `geiser-kawa.el` on `load-path`.  With Guix, `geiser-kawa` is
a propagated input of the home configuration.

- `M-x run-kawa` → start a Kawa REPL
- `M-x geiser-kawa-connect` → connect to a running REPL (port 4242/4243)
- In `.scm` buffers: `TAB` completions, `C-c C-r` eval region, `M-.` go-to-definition

For Minecraft modding, the [kawa-forge](https://github.com/Momo-Softworks/kawa-forge)
Gradle plugin provides `./gradlew kawaRepl` with full Forge/Minecraft
classpath and geiser-kawa integration.
