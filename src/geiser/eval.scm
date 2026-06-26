(define-library (geiser eval)
  (export geiser-eval geiser-load-file geiser-no-values)
  (import (scheme eval)
          (scheme write)
          (kawa base))
  (begin
    (define (geiser-no-values)
      (display "((result \"\"))\n"))

    (define (geiser-eval module-name form)
      ;; For Kawa 3.1.1, always use interaction-environment.
      (let ((env (interaction-environment)))
        (let ((out-str (open-output-string)))
          (let ((result
                 (guard
                  (exn (else
                        (let ((err-str (open-output-string)))
                          (display "ERROR: " err-str)
                          (display exn err-str)
                          (get-output-string err-str))))
                  (let ((val (eval (read (open-input-string form)) env)))
                    (write val out-str)
                    (get-output-string out-str)))))
            (display "((result ")
            (write result)
            (display ") (output . \"")
            ;; Display result, escaping backslashes for Geiser sexp format.
            ;; FIXME: proper backslash/quote escaping for Kawa 3.1.1 FString.
            (display result)
            (display "\"))\n")))))

    (define (geiser-load-file filepath)
      (load filepath)
      (geiser-no-values))))
