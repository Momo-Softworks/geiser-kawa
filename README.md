# geiser-kawa — Geiser backend for Kawa Scheme

Pure-Scheme backend for [Geiser](https://github.com/emacsmirror/geiser)
supporting the [Kawa](https://www.gnu.org/software/kawa/) Scheme
implementation on the JVM.

## Quick start

### Plain Kawa project

```elisp
;; In Emacs, with geiser-kawa on your load-path:
M-x run-kawa
```

Then in any `.scm` buffer:

- `TAB` — completion (Scheme symbols + Java classes)
- `M-.` — jump to source definition
- `C-c C-r` — eval region
- `String:val TAB` — Java member completion
- `java.lang. TAB` — classpath package completion

### Minecraft Forge project (GTNH / RFG)

```bash
cd your-mod-project
./gradlew kawaRepl       # start with full Minecraft classpath
```

Then in Emacs:

```text
M-x geiser-kawa-connect
# port: 4243
```

Everything works: `cpw`, `GameRegistry`, `net.minecraft`, `net.minecraftforge`,
Java members, `M-.` into RFG-generated sources.

For help at any time:

```bash
./gradlew kawaDoctor
```

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
| `location.scm` | `M-.` source location |
| `string-util.scm` | String utilities (avoids Kawa 3.1.1 char-literal bugs) |

## How it works

### Classpath completion

At REPL startup, `geiser-kawa` scans every `.jar` and classes directory
on the JVM classpath, building a cache of fully-qualified class names.

- `java.lang.` → classes in `java.lang`
- `GameR` → `GameRegistry` (unqualified match via class cache)
- `cpw` → `cpw.mods.fml...` (package prefix)
- `net.minecraft.block.` → block classes

### Java member completion

- `String:val TAB` → `valueOf(...)` methods on `java.lang.String`
- `String:length() TAB` → `length()` method
- `Integer:MAX TAB` → `MAX_VALUE` field

Annotations distinguish:

- `class` — Java class
- `method` — instance method
- `static method` — static method
- `field` — instance field
- `static field` — static field

### Source lookup (`M-.`)

`geiser-kawa` resolves source files via:

1. **System property** `kawa.source.path` — a colon-separated list of
   source-root directories (set automatically by `kawa-forge-gradle`).
2. **Fallback** — derived from classpath entries under `build/`, looking
   for `src/main/java`, `src`, etc.

### Cache management

```
M-x geiser-kawa-refresh-classpath   → rescan classpath
M-x geiser-kawa-classpath-stats     → show cache statistics
```

Useful after adding dependencies or rebuilding while the REPL is running.

## Completions with Corfu

If you use [Corfu](https://github.com/minad/corfu) for completion:

```elisp
(setq corfu-auto t)
```

Geiser provides CAPF metadata, and `geiser-kawa` annotates every
completion candidate with its Java kind (`class`, `method`, etc.).

## Guix

Packaged for GNU Guix at `~/.config/guix/modules/packages/geiser-kawa.scm`.

```bash
guix build -L ~/.config/guix/modules geiser-kawa
```

The package includes both the Emacs Lisp code and the Kawa Scheme modules.

## Testing

```bash
# Backend tests (no Emacs required)
kawa -Dkawa.import.path=src -f tests/test.scm

# Integration test (starts a real REPL)
bash tests/integration.sh
```

## Emacs

Requires `geiser-kawa.el` on `load-path`.  With Guix, `geiser-kawa` is
a propagated input of the home configuration.

- `M-x run-kawa` → start a Kawa REPL
- `M-x geiser-kawa-connect` → connect to a running REPL (port 4242/4243)
- In `.scm` buffers: `TAB` completions, `C-c C-r` eval region, `M-.` go-to-definition

### Customization

```elisp
;; Add JARs or class directories to the REPL classpath
(setq geiser-kawa-classpath
      '("/path/to/extra.jar" "/path/to/classes/"))
```

For Minecraft Forge projects the recommended workflow is:

```bash
./gradlew kawaRepl
M-x geiser-kawa-connect
```

The Gradle plugin assembles the correct classpath automatically and
passes source roots for `M-.`.

## Troubleshooting

### Completions are empty or incomplete

Check that the Kawa process has the classes you expect on its classpath:

```bash
./gradlew kawaClasspathReport
```

Or from Emacs:

```
M-x geiser-kawa-classpath-stats
```

### `net.` completions disappear after typing dot

Fixed in v0.2.0.  Update to latest.

### `cpw` or `GameRegistry` not visible

Your REPL may not have the Minecraft Forge/MCP classes on its classpath.
Use `./gradlew kawaRepl` (not plain `M-x run-kawa`) for Minecraft Forge
projects.

### `M-.` says "Can't find"

If using `kawa-forge-gradle` ≥ 0.2.0, source roots are passed automatically
via `-Dkawa.source.path`.  Run `./gradlew kawaDoctor` to verify.

For plain Kawa projects, ensure the source root is on the classpath or
set manually:

```bash
kawa -Dkawa.source.path=/path/to/src ...
```

### Java toolchain errors from Gradle

```text
Cannot find a Java installation matching languageVersion=17, vendor=Azul Zulu
```

This is a Gradle/GTNH toolchain issue, not a geiser-kawa one.  Ensure you have
a compatible JDK installed or configure the toolchain in your build.

### Annotations show "member" instead of "method" / "field"

This is a fallback when `geiser-kawa` cannot reflect on the class at
annotation time.  The most common cause is that the class exists on
the classpath but one of its dependencies is missing at runtime.
The completion itself still works; only the annotation is generic.

### Corfu not showing annotations

Ensure `geiser-impl--implementation` is `kawa` (check with `C-h v`).
The annotation function only activates for the Kawa implementation.
