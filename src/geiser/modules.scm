(define-library (geiser modules)
  (export geiser-module-completions geiser-module-exports)
  (import (scheme write)
          (kawa base))
  (begin

    ;; List known Kawa modules matching a prefix.
    ;; Kawa resolves modules via the module path; we scan the
    ;; interaction environment for known modules and match prefixes.
    (define (geiser-module-completions prefix)
      (let* ((env (interaction-environment))
             (candidates '()))
        ;; Scan environment locations for module-like names.
        (guard (exn (else '()))
          (let ((iter (env:enumerateAllLocations)))
            (let loop ()
              (when (iter:hasNext)
                (let* ((loc (iter:next))
                       (sym (invoke (invoke loc 'getKeySymbol) 'toString)))
                  ;; Module names typically contain dots.
                  (when (and (string-contains sym ".")
                             (string-prefix? prefix sym))
                    (set! candidates (cons sym candidates))))
                (loop)))))
        (java.util.Collections:sort candidates)
        ;; Return candidates list directly — geiser extracts the return value.
        candidates))

    ;; Return exported symbols for a given module name.
    (define (geiser-module-exports module-name)
      (let ((exports '()))
        (guard (exn (else '()))
          (let* ((env (interaction-environment))
                 (iter (env:enumerateAllLocations)))
            (let loop ()
              (when (iter:hasNext)
                (let* ((loc (iter:next))
                       (sym (invoke (invoke loc 'getKeySymbol) 'toString)))
                  ;; Heuristic: symbols that start with the module prefix
                  ;; are likely exported from it.
                  (when (string-prefix? module-name sym)
                    (let ((bare-name
                           (if (string-prefix? (string-append module-name ".") sym)
                               (substring sym (+ (string-length module-name) 1)
                                         (string-length sym))
                               sym)))
                      (set! exports (cons bare-name exports)))))
                (loop))))
          ;; Return exports list — geiser extracts the return value.
          (java.util.Collections:sort exports)
          exports))))
)
