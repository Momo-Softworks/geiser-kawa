# geiser-kawa — Current State Map

Source: `/home/swilley/Projects/geiser-kawa`, upstream `gitlab.com/emacs-geiser/kawa`,
last commit `5896b19` (2021-09-20, "fix: avoid exception when autodoc is asked for non-symbols").
Investigated 2026-06-23. No files modified.

The project has two halves:
- **`geiser-kawa`** — the Elisp package in `elisp/*.el` (the Geiser backend).
- **`kawa-geiser`** — a Maven/Java project in `src/main/java/kawageiser/**` that, when `(require <kawageiser.Geiser>)`
  is run inside a Kawa REPL, installs `geiser:*` procedures into the Kawa environment. It is built into a
  fat jar that bundles Kawa itself plus the helper library `kawa-devutil`.

---

## 1. Elisp module map (`elisp/*.el`)

### `geiser-kawa.el` — main package; defines the Geiser implementation.
- `Package-Requires: ((emacs "26.1") (geiser "0.16"))`, Version `0.0.1` (geiser-kawa.el:10,12).
- Requires geiser internals: `geiser-base geiser-custom geiser-syntax geiser-log geiser-connection
  geiser-eval geiser-edit geiser` (lines 21–28) plus all `geiser-kawa-*` sub-modules (34–39).
- **`geiser-kawa--geiser-procedure (proc &rest args)`** (45) — the `marshall-procedure`. Maps Geiser ops to Kawa code:
  - `eval`/`compile` → `(geiser:eval (interaction-environment) %S)` (53)
  - `load-file`/`compile-file` → `(geiser:load-file %s)` (57)
  - `no-values` → `(geiser:no-values)` (59)
  - default → `(geiser:%s %s)` (63) — this is how `autodoc`, `completions`, `module-completions`,
    `macroexpand` reach the Java side.
- `geiser-kawa--symbol-begin (module)` (72) — copied from geiser-chibi/guile; `find-symbol-begin` method.
- `geiser-kawa--import-command` (82) → `(import %s)`; `geiser-kawa--exit-command` (86) → `(exit 0)`.
- `geiser-kawa--display-error (_module key msg)` (100) — `display-error` method; calls `geiser-edit--buttonize-files` (108).
- `geiser-kawa--enter-debugger` (97) — stub ("TODO.").
- **`define-geiser-implementation kawa`** (114–137). Methods registered:
  - `unsupported-procedures` = find-file, symbol-location, module-location, symbol-documentation,
    module-exports, callers, callees, generic-methods (115–122)
  - `binary geiser-kawa--binary`, `arglist geiser-kawa-arglist`, `version-command geiser-kawa--version-command`,
    `repl-startup geiser-kawa--repl-startup`, `prompt-regexp geiser-kawa--prompt-regexp`,
    `debugger-prompt-regexp nil`, `marshall-procedure geiser-kawa--geiser-procedure`,
    `exit-command`, `import-command`, `find-symbol-begin`, `display-error`,
    `case-sensitive nil`, `external-help geiser-kawa-manual--look-up`.
- `geiser-impl--add-to-alist 'regexp "\\.scm\\'" 'kawa t` and `.sld` (144–145).
- **`geiser-kawa-run-kawa`** (149, interactive) — wrapper over `run-geiser`/`run-kawa`: if the fat jar exists,
  `(run-geiser 'kawa)`; else prompts to build it via `geiser-kawa-deps-mvnw-package--and-run-kawa`.

### `geiser-kawa-globals.el` — global vars/defcustoms; required by all sub-modules to avoid circular deps.
- `geiser-kawa-elisp-dir` (22), `geiser-kawa-dir` (28) — directory discovery, adapted from geiser.el.
- `custom-add-load` for `geiser-kawa` and `geiser` (35–36).
- **Autoloads** `run-kawa`/`switch-to-kawa` (40,43) and `(add-to-list 'geiser-active-implementations 'kawa)` (47).
- Defcustoms: `geiser-kawa-binary "kawa"` (56, via `geiser-custom--defcustom`),
  **`geiser-kawa-deps-jar-path`** (61) default
  `<dir>/target/kawa-geiser-0.1-SNAPSHOT-jar-with-dependencies.jar`,
  `geiser-kawa-use-included-kawa nil` (69).
- **`geiser-kawa--arglist`** (77) — REPL startup args:
  `("console:use-jline=no" "--console" "-e" "(require <kawageiser.Geiser>)" "--")`.
- **`geiser-kawa--prompt-regexp`** (90) = `"#|kawa:[0-9]+|# "`.

### `geiser-kawa-arglist.el` — classpath/binary/version/repl-startup methods.
- `geiser-kawa--binary` (20) — returns "java" if `use-included-kawa`, else the `kawa` binary.
- `geiser-kawa-arglist--make-classpath` (35) — builds classpath: if a real `kawa` binary is found and has a
  sibling `../lib/`, adds `kawa.jar servlet.jar domterm.jar jline.jar` + the fat jar; else just the fat jar.
- `geiser-kawa-arglist--make-classpath-arg` (74) → `-Djava.class.path=%s`.
- **`geiser-kawa-arglist`** (79) — the full `arglist` method (classpath arg + optional `kawa.repl` + `geiser-kawa--arglist`).
- `geiser-kawa--version-command` (91) — runs `--version`, parses `"Kawa 3.1.1"`.
- `geiser-kawa--repl-startup` (110) — no-op.

### `geiser-kawa-deps.el` — manages building the Java fat jar via `mvnw package`.
- `geiser-kawa-deps-mvnw-package (&optional dir)` (25, interactive) — runs `./mvnw package` (or `mvnw.cmd package`
  on Windows) from `geiser-kawa-dir` via `compile`.
- `geiser-kawa-deps--run-kawa--compile-hook` (47) — one-shot `compilation-finish-functions` hook that calls
  `(run-geiser 'kawa)` once the jar exists.
- `geiser-kawa-deps-mvnw-package--and-run-kawa` (63).

### `geiser-kawa-util.el` — eval helpers used by the devutil/ext-help seams.
- `geiser-kawa-util--eval (sexp-or-str)` (20) — wraps in `(geiser:eval (interaction-environment) %S)` and calls
  `geiser-eval--send/wait`.
- `geiser-kawa-util--retort-result (ret)` (54) — bypasses geiser's bounded reader using `read-from-string` on
  `(cadr (assoc 'result ret))` (for results longer than `geiser-eval--retort-result` allows).
- `geiser-kawa-util--eval-get-result (sexp-or-str &optional retort-result)` (64) — signals `peculiar-error` on
  Kawa error using `geiser-eval--retort-output`.
- `geiser-kawa-util--repl-point-after-prompt` (90), `geiser-kawa-util--point-is-at-toplevel-p` (99) — uses
  `geiser-repl-buffer-name`, `geiser-kawa--prompt-regexp`, `geiser-syntax--pop-to-top`.

### `geiser-kawa-devutil-complete.el` — Java-aware completion via kawa-devutil (separate from geiser's capf).
- `geiser-kawa-devutil-complete-add-missing-parentheses` (24) defvar.
- `geiser-kawa-devutil-complete--get-data (code-str cursor-index)` (29) — sends
  `(geiser:eval (interaction-environment) "(geiser:kawa-devutil-complete <code> <idx>)")` via
  `geiser-eval--send/wait`; reads with `geiser-kawa-util--retort-result`.
- `--user-choice-classmembers` (58), `--user-choice-symbols-plus-packagemembers` (86),
  `--user-choice-dispatch` (128) — render `completing-read` UIs over the returned alist
  (keys: completion-type, before-cursor, owner-class, modifiers, names, symbol-names, package-members, …).
- `--code-point-from-toplevel` (145) — computes region+cursor-index (handles REPL vs buffer, toplevel vs sexp).
- **`geiser-kawa-devutil-complete-at-point`** (191, interactive) — the user command for Java completion.
- `--exprtree (code-str cursor-index)` (218) → `(geiser:kawa-devutil-complete-expr-tree …)`.
- **`geiser-kawa-devutil-complete-expree-at-point`** (237, interactive) — debug: show the completion expr-tree.

### `geiser-kawa-devutil-exprtree.el` — view Kawa's compiler Expression tree (debug aid).
- Buffer `*kawa exprtree*` (18); `--view` (21, uses View-mode), `--for (code-str)` (33) →
  `(geiser:kawa-devutil-expr-tree-formatted <code>)`, `--view-for` (38).
- **`geiser-kawa-devutil-exprtree-region (beg end)`** (44, interactive), **`geiser-kawa-devutil-exprtree-last-sexp`** (53, interactive).
- NOTE: file header docstring says `geiser-kawa-devutil-complete.el` (line 1) — wrong filename in header (cosmetic bug).

### `geiser-kawa-ext-help.el` — `external-help` method: Kawa manual lookup (.epub via eww / .info via Info).
- Defcustom `geiser-kawa-manual-path` (28) default `<kawa>/../doc/kawa-manual.epub`.
- `geiser-kawa-manual--epub-unzip-to-tmpdir` (40) — sets buffer impl, sends
  `(geiser:manual-epub-unzip-to-tmp-dir %S)` via `geiser-eval--send/result`.
- `geiser-kawa-manual--epub-search` (64) — unzips epub through Kawa, opens `OEBPS/Overall-Index.xhtml` in eww,
  caches it in `geiser-kawa-manual--epub-cached-overall-index`.
- `geiser-kawa-manual--info-search` (104) — Info-mode "Overall Index" search.
- **`geiser-kawa-manual--look-up (id _mod)`** (126) — the `external-help` dispatcher (epub vs info by extension).

### Geiser API symbols used (the bitrot surface — exact identifiers)
Functions/macros: `define-geiser-implementation`, `geiser-impl--add-to-alist`, `run-geiser`,
`geiser-eval--send/wait`, `geiser-eval--send/result`, `geiser-eval--retort-result`,
`geiser-eval--retort-output`, `geiser-repl-buffer-name`, `geiser-syntax--pop-to-top`,
`geiser-impl--set-buffer-implementation`, `geiser-edit--buttonize-files`, `geiser-custom--defcustom`,
`geiser-completion--complete` (tests only).
Variables: `geiser-active-implementations`.
Autoloaded user cmds it relies on existing: `run-kawa`, `switch-to-kawa` (generated by the macro).

---

## 2. The Elisp ↔ Java "devutil" seam (CRITICAL)

Loaded via the REPL startup arg `-e "(require <kawageiser.Geiser>)"` (geiser-kawa-globals.el:84).
`kawageiser.Geiser.run()` (Geiser.java:18) installs a `procMap` (Geiser.java:34–46) of `geiser:NAME` →
`"ClassName:staticMethod"` and binds each via `lang.defineFunction` (Geiser.java:61–86). The full registry:

| Kawa procedure | Java landing (`Class:method`) | Source file |
|---|---|---|
| `geiser:eval` | `kawageiser.GeiserEval:evalStr` | GeiserEval.java:33 |
| `geiser:autodoc` | `kawageiser.GeiserAutodoc:autodoc` | GeiserAutodoc.java:62 |
| `geiser:completions` | `kawageiser.GeiserCompleteSymbol:getCompletions` | GeiserCompleteSymbol.java:19 |
| `geiser:module-completions` | `kawageiser.GeiserCompleteModule:completeModule` | GeiserCompleteModule.java:18 |
| `geiser:load-file` | `kawageiser.GeiserLoadFile:loadFile` | GeiserLoadFile.java |
| `geiser:no-values` | `kawageiser.GeiserNoValues:noValues` | GeiserNoValues.java |
| `geiser:macroexpand` | `kawageiser.GeiserMacroexpand:expand` | GeiserMacroexpand.java:15 |
| `geiser:kawa-devutil-complete` | `kawageiser.kawadevutil.Complete:completeJava` | Complete.java:37 |
| `geiser:kawa-devutil-complete-expr-tree` | `kawageiser.kawadevutil.Complete:getExprTreeFormatted` | Complete.java:262 |
| `geiser:kawa-devutil-expr-tree-formatted` | `kawageiser.kawadevutil.ExprTree:getExprTreeFormatted` | ExprTree.java:28 |
| `geiser:manual-epub-unzip-to-tmp-dir` | `kawageiser.docutil.ManualEpubUnzipToTmpDir:unzipToTmpDir` | ManualEpubUnzipToTmpDir.java:15 |

### The 4 feature entry points the architect asked for
**(a) Completion (Java-aware, geiser-kawa's own):**
- Elisp caller: `geiser-kawa-devutil-complete--get-data` (geiser-kawa-devutil-complete.el:29).
- Kawa expr sent: `(geiser:kawa-devutil-complete <code-str> <cursor-index>)`.
- Lands in: `kawageiser.kawadevutil.Complete.completeJava(IString, IntNum)` (Complete.java:37) →
  `kawadevutil.complete.find.CompletionFindGeneric.find(...)`. (Plain symbol completion via geiser's capf
  instead routes `completions`→`geiser:completions`→`GeiserCompleteSymbol.getCompletions`.)

**(b) Autodoc / arglist:**
- Caller: geiser core, via `geiser-kawa--geiser-procedure` default branch → `(geiser:autodoc <ids>)`
  (geiser-kawa.el:63). (Test exercises it: geiser-kawa-test.el:64–74.)
- Lands in: `kawageiser.GeiserAutodoc.autodoc(LList ids)` (GeiserAutodoc.java:62) → builds
  `AutodocDataForSymId`/`OperatorArgListData` using `kawadevutil.data.ProcDataGeneric`/`ProcDataNonGeneric`/`ParamData`.

**(c) Expression-tree (exprtree, debug):**
- Caller: `geiser-kawa-devutil-exprtree--for` (exprtree.el:33) → `(geiser:kawa-devutil-expr-tree-formatted <code>)`
  → `ExprTree.getExprTreeFormatted` (ExprTree.java:28).
- Also: `geiser-kawa-devutil-complete--exprtree` (complete.el:218) → `(geiser:kawa-devutil-complete-expr-tree …)`
  → `Complete.getExprTreeFormatted` (Complete.java:262). Both use `kawadevutil.exprtree.ExprWrap`/`CursorFinder`.

**(d) Manual / external-help:**
- Caller: `geiser-kawa-manual--epub-unzip-to-tmpdir` (ext-help.el:40) →
  `(geiser:manual-epub-unzip-to-tmp-dir <epub-path>)` → `ManualEpubUnzipToTmpDir.unzipToTmpDir`
  (ManualEpubUnzipToTmpDir.java:15) → `kawadevutil.util.ZipExtractor.unzip`. (The `.info` path is pure Elisp,
  no Java.) The `external-help` geiser method itself is `geiser-kawa-manual--look-up` (ext-help.el:126).

### Java source files & roles
- `Geiser.java` — entry point; registers all `geiser:*` procedures; kicks off a background thread to warm
  kawa-devutil's package cache (`CompletionFindPackageMemberUtil.getChildrenNamesOfRoot`).
- `GeiserEval.java` — eval engine; wraps `kawadevutil.eval.Eval`; formats the geiser protocol
  `((result …)/(error …) (output . …))`.
- `GeiserAutodoc.java` — arglist/autodoc data extraction (required/optional/rest params, types, module path).
- `GeiserCompleteSymbol.java` — plain symbol completion (`geiser:completions`).
- `GeiserCompleteModule.java` — module completion (hacky: iterates env locations).
- `GeiserMacroexpand.java` — `macroexpand` via `gnu.kawa.slib.syntaxutils.expand` (ignores expand-1 vs expand-all).
- `GeiserLoadFile.java`, `GeiserNoValues.java` — load-file and no-values.
- `kawadevutil/Complete.java` — Java/package/class-member completion + completion expr-tree.
- `kawadevutil/ExprTree.java` — raw expr-tree formatting.
- `docutil/ManualEpubUnzipToTmpDir.java` — unzip epub manual to tmp.
- `StartKawaWithGeiserSupport.java` — standalone launcher (telnet server on port 37146, or `--no-server` REPL);
  **not used by the elisp path** (the elisp uses `-Djava.class.path=… kawa.repl -e (require <kawageiser.Geiser>)`).

---

## 3. Build system

### Java fat jar (`pom.xml`)
- groupId `com.gitlab.spellcard199`, artifactId **`kawa-geiser`**, version **`0.1-SNAPSHOT`** (pom.xml:13–15).
- Build: `maven-assembly-plugin` 3.2.0 with `jar-with-dependencies` (pom.xml:20–36) bound to `package`,
  and `maven-compiler-plugin` 3.8.1 with **source/target = 8** (pom.xml:37–45; also
  `maven.compiler.source/target = 1.8`, pom.xml:51–52). **Java 8 assumed.**
- Output jar: `target/kawa-geiser-0.1-SNAPSHOT-jar-with-dependencies.jar` (the default
  `geiser-kawa-deps-jar-path`, globals.el:61).
- **Dependencies (pom.xml:70–86):**
  - `com.gitlab.spellcard199:kawa-devutil:b550f77236c9c10b1598637a9d1b09bbe2be8773` (a pinned **git commit**,
    resolved via **jitpack.io**, pom.xml:55–67). **kawa-devutil transitively pulls in Kawa** (the README says
    "Kawa's master branch"); there is NO direct `kawa` dependency or pinned Kawa version in this pom — Kawa's
    version is whatever that kawa-devutil commit pulled. README §"Supported Kawa versions" says only Kawa > 3.1
    works; version-command parses e.g. `"Kawa 3.1.1"`.
  - `org.testng:testng:7.0.0` (test scope, pom.xml:79–84).
- **Maven wrapper** (`mvnw` / `mvnw.cmd`): pinned Maven **3.6.3**, maven-wrapper **0.5.6**
  (`.mvn/wrapper/maven-wrapper.properties:7-8`). No system Maven required.
- Build command: `./mvnw package` (run from repo root). Elisp triggers it via
  `geiser-kawa-deps-mvnw-package` (deps.el).

### Elisp dependency management (`Cask`)
```
(source gnu)
(source melpa)
(package-file "elisp/geiser-kawa.el")
(files "elisp/*")
(development
 (depends-on "buttercup")
 (depends-on "cask")
 (depends-on "package-lint")
 (depends-on "flycheck")
 (depends-on "flycheck-package")
 (depends-on "flycheck-cask")
 (depends-on "smartparens")
 (depends-on "evil-surround")
 (depends-on "evil-escape")
 (depends-on "aggressive-indent"))
```
Runtime dep (from `Package-Requires`): `geiser >= 0.16`. Cask resolves geiser from MELPA.

### How elisp locates the jar
`geiser-kawa-deps-jar-path` (globals.el:61), computed from `geiser-kawa-dir` (the package install dir).
`geiser-kawa-arglist--make-classpath` adds it to `-Djava.class.path`.

---

## 4. Tests & CI

- **`run-elisp-tests.sh`** = one line: `cask exec buttercup -L .` (runs the buttercup spec under Cask).
- **No `Makefile`** in the repo.
- **`elisp/tests/geiser-kawa-test.el`** — a buttercup `describe "run-kawa"` spec that:
  - `before-all`: runs `geiser-kawa-deps-mvnw-package`, waits for compilation, sets `use-included-kawa t`, `run-kawa`.
  - Specs: jar exists; `run-kawa` process live; `geiser-eval-buffer` of `(display 'foobar)`;
    `geiser:autodoc '(display)`; `macroexpand` of `(when #t …)`; `geiser-completion--complete "dis"`;
    Java completion `--get-data "(java.lang.String:)" 18` → "METHODS"; exprtree specs.
- **`src/test/java/kawageiser/`**:
  - `GeiserTest.java` — evaluates `(geiser:eval (interaction-environment) "(+ 1 1)")`.
  - `GeiserAutodocTest.java` — TestNG: autodoc for `display`, `cdddr`, `java.lang.String:format`, `filepath`, `list`.
- **No CI config found** — no `.gitlab-ci.yml`, `.github/`, or similar. Nothing runs automatically.

---

## 5. Existing feature inventory (feature → implementation)

| Feature | Works? | Implementation |
|---|---|---|
| REPL (run-kawa / switch-to-kawa) | yes | `define-geiser-implementation kawa` + `geiser-kawa--arglist` + jar; `geiser-kawa-run-kawa` wrapper |
| eval / compile | yes | marshall `eval`→`geiser:eval`→`GeiserEval.evalStr` |
| load-file | yes | `geiser:load-file`→`GeiserLoadFile` |
| Symbol completion (geiser capf) | yes | `geiser:completions`→`GeiserCompleteSymbol` |
| Module completion | fragile (README) | `geiser:module-completions`→`GeiserCompleteModule` (hacky) |
| Java member completion | partial/often broken (TODO.org) | `geiser-kawa-devutil-complete-at-point`→`geiser:kawa-devutil-complete`→`Complete.completeJava` |
| Autodoc (scheme + java methods) | yes | `geiser:autodoc`→`GeiserAutodoc` |
| macroexpand | yes (whole-tree only) | `geiser:macroexpand`→`GeiserMacroexpand` |
| Manual lookup (external-help) | yes if `geiser-kawa-manual-path` set | `geiser-kawa-manual--look-up` (epub via eww / info via Info) |
| Expr-tree viewer (debug) | yes | `geiser-kawa-devutil-exprtree-*` / `geiser-kawa-devutil-complete-expree-at-point` |
| jump-to-def / xref / symbol-location | **NOT supported** | declared in `unsupported-procedures` |
| symbol-documentation, module-exports, callers, callees, generic-methods, find-file | **NOT supported** | declared in `unsupported-procedures` |
| find-module | **NOT implemented** | commented-out stub (geiser-kawa.el:66,131) |
| enter-debugger | stub | `geiser-kawa--enter-debugger` returns nothing |

---

## 6. Modernization gap analysis

Installed geiser: **0.32** at
`/gnu/store/2h0ifmgjsd74fxpmgmwq81jg7p0pagzz-emacs-geiser-0.32/share/emacs/site-lisp/geiser-0.32`.
geiser-kawa's declared floor is `geiser "0.16"`.

### Geiser symbol breakages / renames vs 0.32
- **`run-geiser` is OBSOLETE.** In 0.32 it is `(define-obsolete-function-alias 'run-geiser 'geiser "Geiser 0.26")`
  (geiser-repl.el:1110). Still callable but emits warnings. geiser-kawa calls `(run-geiser 'kawa)` in
  geiser-kawa.el:161, deps.el:59, and quickstart.el. The modern call is `(geiser 'kawa)`.
- **`run-kawa` / `switch-to-kawa` are OBSOLETE.** `define-geiser-implementation` in 0.32 still generates them
  but as obsolete aliases for `geiser-kawa` / `geiser-kawa-switch` (geiser-impl.el:226–238). geiser-kawa
  autoloads `run-kawa`/`switch-to-kawa` (globals.el:40,43) and the test/quickstart call `run-kawa` — works with
  warnings, but the canonical names are now `geiser-kawa` / `geiser-kawa-switch`. (Note potential confusion: the
  macro's generated runner is `geiser-<name>`, i.e. `geiser-kawa`, which collides namewise with the package.)
- **`geiser-impl--add-to-alist`** still exists (geiser-impl.el:243) — OK, but 0.32 also offers the public
  `geiser-implementation-extension` helper.
- **Internals still present in 0.32 (no break):** `geiser-eval--send/wait`, `geiser-eval--send/result`,
  `geiser-eval--retort-result`, `geiser-eval--retort-output`, `geiser-repl-buffer-name`,
  `geiser-syntax--pop-to-top`, `geiser-impl--set-buffer-implementation`, `geiser-edit--buttonize-files`,
  `geiser-custom--defcustom`, `geiser-completion--complete`, `geiser-active-implementations`,
  `define-geiser-implementation`. All resolved in the 0.32 tree. Risk: these are private (`--`) and unguaranteed.
- **Completion architecture drift:** geiser 0.27+ moved buffer completion to a capf-based module
  (`geiser-capf.el`, present in 0.32). geiser-kawa's own `geiser-kawa-devutil-complete-at-point` does NOT
  integrate with `completion-at-point-functions`; it is a standalone command that mutates the buffer
  (`kill-word`/`insert`). This won't compose with modern company/corfu completion UX.

### Emacs 30 concerns
- `cl-lib`/`subr-x` usage is fine. `eww-open-file`, `Info-goto-node`, `View-quit` still present.
- `define-obsolete-function-alias` warnings will surface under Emacs 30 + geiser 0.32; nothing is removed yet,
  so the package should still load and run, but expect byte-compile/runtime obsolescence warnings.
- `Package-Requires` floor `geiser "0.16"` is stale; should be raised to match the targeted geiser (≥0.26 for
  the rename era, ideally pin to 0.32 semantics).

### Kawa 3.1.1 / pinned-Kawa concerns
- The pom pins **kawa-devutil at a jitpack git commit** (`b550f772…`) that transitively bundles a Kawa build
  ("Kawa master" per README, circa 2020–2021). It does **not** pin a Kawa release. Risks:
  - **jitpack availability**: the build depends on jitpack.io still building that exact commit of
    `com.gitlab.spellcard199/kawa-devutil`. If jitpack or the GitLab repo is gone, the build cannot resolve.
  - Bundled Kawa is older than current **Kawa 3.1.1**; moving to a clean Kawa 3.1.1 may break kawa-devutil's
    use of formerly-private Kawa internals (`gnu.expr.*`, `gnu.mapping.*`, `gnu.kawa.*`) — autodoc and the
    expr-tree/completion code reach deep into Kawa compiler internals (CompiledProc, LangObjType,
    GnuMappingLocation, ExprWrap, CursorFinder).
- **Java version**: pom targets **Java 8**. Modern JDKs (17/21) build it, but Kawa + reflection-heavy
  kawa-devutil may hit `--illegal-access`/module-system issues on JDK 16+. `java` is not on PATH in this
  environment (could not probe a local JDK).

---

## 7. Author's own TODO / known gaps

### `TODO.org`
- **Bugs:** Java completion "often broken"; autodoc with colon-notation on Java methods misses alternatives;
  many bugs actually live in kawa-devutil (geiser-kawa just wraps it).
- **MELPA:** wants to publish; includes a draft recipe (gitlab fetcher, files: elisp/*.el, pom.xml, .mvn, mvnw*, src).
- **Remote injection:** idea to inject kawa-geiser .class files (base64 over the geiser connection) into a
  running remote Kawa REPL so users needn't depend on kawa-geiser directly.
- **Manual download:** consider auto-downloading/unzipping the Kawa manual from ftp.gnu.org (with sha256 check;
  records sha256 for kawa-3.1.1.zip).

### `Random_notes.org`
- Explored emacs dynamic-module → JNI → Kawa (via emacs-gargoyle) as ~10× faster than sockets; concluded
  sockets are preferable unless passing very large data (emacs GIL prevents java→elisp calls).

### In-code `;; TODO` / `// TODO`
- elisp: `geiser-kawa--find-module` unimplemented (geiser-kawa.el:66,131); `geiser-kawa--enter-debugger` stub (97);
  `geiser-kawa--symbol-begin` "see if it needs improvements" (71).
- `GeiserAutodoc.java`: find the "right" way to get a symbol's module (32, 277, 329, 339); macro autodoc
  unsupported (33, 251); no param names for Java instance methods (34); special-char names like `|a[)|` (36);
  multiple-id autodoc (43).
- `GeiserMacroexpand.java`: can't pass keyword args java→kawa, so expand-1 vs expand-all is ignored (26).
- `GeiserCompleteModule.java`: module listing is "a hack" (40).
- `Complete.java`: symbol-name stringification via toString vs getNames uncertainty (158).
- `Geiser.java`: wants to replace string method-paths with real `PrimProcedure`s to drop Kawa-specific syntax (31).
- `geiser-kawa-devutil-exprtree.el:1`: file header has the wrong filename (`-complete` instead of `-exprtree`).

---

## Build & test invocation (exact)
- Build the fat jar: from repo root, `./mvnw package`
  → produces `target/kawa-geiser-0.1-SNAPSHOT-jar-with-dependencies.jar`. (Requires JDK + network for jitpack.)
- Run elisp tests: `cask install` then `./run-elisp-tests.sh` (= `cask exec buttercup -L .`).
  The buttercup `before-all` itself runs `mvnw package`, so the jar is built as part of the test run.
- Quick manual try (no global config): `cask emacs -Q --load quickstart.el`.
- Standalone Kawa+geiser server (not the elisp path): see `example-mvn-run-geiser.sh`.
