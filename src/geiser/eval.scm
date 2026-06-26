(define-library (geiser eval)
  (export geiser-eval geiser-load-file geiser-no-values)
  (import (scheme eval)
          (scheme write)
          (kawa base))
  (begin
    (define (geiser-no-values)
      (display "((result \"\"))\n"))

    (define (geiser-eval module-name form)
      (let ((env (interaction-environment)))
        (guard
         (exn (else
               (display "((result ")
               (write "ERROR")
               (display ") (output . \"\"))\n")))
         (let* ((in (open-input-string form))
                (expr (read in))
                (val (eval expr env))
                ;; Write value to string port for properly
                ;; quoted result (mirrors geiser-guile).
                (out (open-output-string)))
           (write val out)
           (display "((result ")
           (write (get-output-string out))
           (display ") (output . \"\"))\n")))))

    (define (geiser-load-file filepath)
      (load filepath)
      (geiser-no-values))))
