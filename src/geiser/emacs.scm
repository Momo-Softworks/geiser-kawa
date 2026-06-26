(define-library (geiser emacs)
  (export geiser-eval
          geiser-load-file
          geiser-no-values
          geiser-completions
          geiser-completion-annotation
          geiser-module-completions
          geiser-autodoc
          geiser-object-signature
          geiser-macroexpand
          geiser-module-exports
          geiser-symbol-location
          geiser-module-location
          ;; Cache management
          geiser-refresh-class-cache
          geiser-class-cache-stats
          ;; Re-export string-util for testing
          ->string str-index str-last-index str-starts-with?
          java-interop-prefix? COLON DOT
          ;; Re-export complete internals for testing
          complete-java-members complete-symbols complete-classes
          ;; Re-export classpath internals for testing
          ensure-class-cache *class-cache*
          scan-dir scan-zip
          ;; Re-export location internals for testing
          source-roots)
  (import (scheme base)
          (geiser eval)
          (geiser string-util)
          (geiser complete)
          (geiser classpath)
          (geiser doc)
          (geiser modules)
          (geiser macro)
          (geiser location)))
