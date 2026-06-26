(define-library (geiser macro)
  (export geiser-macroexpand)
  (import (scheme write)
          (kawa base))
  (begin

    ;; Expand a Scheme macro form without evaluating it.
    (define (geiser-macroexpand form . rest)
      (guard (exn (else "ERROR"))
        (let* ((env (interaction-environment))
               (expr (if (string? form)
                         (read (open-input-string form))
                         form))
               ;; In Kawa 3.1.1, macroexpand is accessed via interaction env.
               (expander (gnu.mapping.Environment:get 'macroexpand env))
               (expanded (if (gnu.mapping.Procedure? expander)
                             (expander expr)
                             expr)))
          ;; Return expanded form as its written representation.
          (call-with-output-string (lambda () (write expanded))))))))
