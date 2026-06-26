(define-library (geiser eval)
  (export geiser-eval geiser-load-file geiser-no-values)
  (import (scheme base)
          (scheme eval)
          (scheme write)
          (kawa base))
  (begin
    (define (geiser-no-values)
      (display "((result \"\"))\n"))

    (define (geiser-eval module-name form)
      ;; Resolve the environment: if module-name is #f or not a valid
      ;; module, fall back to interaction-environment.
      (let* ((env (if (and (symbol? module-name)
                           (not (eq? module-name ':f))
                           (not (eq? module-name #!null)))
                      (guard (exn (else (interaction-environment)))
                        (gnu.mapping.Environment:getGlobal
                         (symbol->string module-name)))
                      (interaction-environment)))
             (result #!null)
             (output (open-output-string))
             (output-port (current-output-port))
             (error-port (current-error-port)))
        ;; Capture output and errors produced during evaluation.
        (set-current-output-port! output)
        (set-current-error-port! output)
        (set! result
              (guard (exn (else (string-append "ERROR: "
                                               (exn:getMessage exn))))
                (let ((val (eval (read (open-input-string form)) env)))
                  (write val))))
        ;; Restore original ports.
        (set-current-output-port! output-port)
        (set-current-error-port! error-port)
        ;; Format as Geiser expects: ((result <val>) (output . <captured>))
        (let ((captured (get-output-string output)))
          (display "((result ")
          (display result)
          (display ") (output . \"")
          ;; Escape quotes and backslashes in captured output.
          (display (string-replace captured "\\" "\\\\"))
          (display "\"))\n"))))

    (define (geiser-load-file filepath)
      (load filepath)
      (geiser-no-values))))
