(define-library (geiser emacs)
  (export geiser-eval
          geiser-load-file
          geiser-no-values
          geiser-completions
          geiser-module-completions
          geiser-autodoc
          geiser-object-signature
          geiser-macroexpand
          geiser-module-exports)
  (import (scheme base)
          (geiser eval)
          (geiser complete)
          (geiser doc)
          (geiser modules)
          (geiser macro)))
