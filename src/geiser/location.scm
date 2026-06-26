(define-library (geiser location)
  (export geiser-symbol-location geiser-module-location)
  (import (scheme write)
          (kawa base))
  (begin
    ;; Return (file line col) for a symbol, or #f.
    (define (geiser-symbol-location symbol)
      ;; Kawa/Java: symbol locations not directly available without
      ;; source indexing.  Return #f so geiser shows a clear message.
      #f)

    ;; Return (file) for a module, or #f.
    (define (geiser-module-location module-spec)
      ;; Module spec comes as (:module "name") from geiser.
      (let ((name (if (pair? module-spec)
                      (cadr module-spec)
                      module-spec)))
        (guard (exn (else #f))
          (let* ((env (interaction-environment))
                 (loc (env:getLocation name)))
            (if (eq? loc #!null)
                #f
                ;; Try to get the source file from the module info.
                #f)))))))
