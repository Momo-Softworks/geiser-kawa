(define-library (geiser emacs)
  (export geiser-eval
          geiser-load-file
          geiser-no-values
          geiser-completions
          geiser-module-completions
          geiser-autodoc
          geiser-object-signature
          geiser-macroexpand
          geiser-module-exports
          geiser-symbol-location
          geiser-module-location)
  (import (scheme base)
          (geiser eval)
          (geiser complete)
          (geiser classpath)
          (geiser doc)
          (geiser modules)
          (geiser macro)
          (geiser location)))
