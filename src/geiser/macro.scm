(define-library (geiser macro)
  (export geiser-macroexpand)
  (import (scheme write)
          (kawa base))
  (begin

    ;; Expand a Scheme macro form without evaluating it.
    (define (geiser-macroexpand form . rest)
      (guard (exn (else (display "((result \"\" (output . \"ERROR\")))\n")))
        (let* ((env (interaction-environment))
               (expr (if (string? form)
                         (read (open-input-string form))
                         form))
               (expanded (gnu.mapping.Procedure:apply
                          (gnu.mapping.Environment:get 'macroexpand env)
                          expr)))
          (display "((result \"")
          (display (call-with-output-string (lambda () (write expanded))))
          (display "\"))\n"))))))
