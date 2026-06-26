(define-library (geiser complete)
  (export geiser-completions)
  (import (scheme write)
          (kawa base))
  (begin

    ;; Check if a prefix looks like a Java interop call.
    ;; Patterns: "java.lang.String:"  "obj:"  "ClassName:" 
    (define (java-interop-prefix? prefix)
      (or (string-contains prefix ":")
          (string-contains prefix ".")))

    ;; Complete Java class members using reflection.
    (define (complete-java prefix)
      (let* ((colon-pos (string-index-right prefix #\:))
             (dot-only  (and (not colon-pos) (string-index-right prefix #\.))))
        (if colon-pos
            (let ((class-name (substring prefix 0 colon-pos))
                  (member-prefix (substring prefix (+ colon-pos 1)
                                           (string-length prefix))))
              (guard (exn (else '()))
                (let* ((cls (java.lang.Class:forName class-name))
                       (methods (cls:getMethods))
                       (fields  (cls:getFields))
                       (candidates '()))
                  ;; Collect matching method names (with type signatures)
                  (do ((i 0 (+ i 1)))
                      ((>= i (methods:length)))
                    (let* ((m :: java.lang.reflect.Method (methods i))
                           (name :: gnu.lists.FString (m:getName)))
                      (when (string-prefix? member-prefix name)
                        (set! candidates
                              (cons (string-append name "("
                                    (string-join
                                     (map (lambda (p) (p:getSimpleName))
                                          (vector->list (m:getParameterTypes)))
                                     ", ")
                                    ")")
                                    candidates)))))
                  ;; Collect matching field names
                  (do ((i 0 (+ i 1)))
                      ((>= i (fields:length)))
                    (let* ((f :: java.lang.reflect.Field (fields i))
                           (name :: gnu.lists.FString (f:getName)))
                      (when (string-prefix? member-prefix name)
                        (set! candidates (cons name candidates)))))
                  candidates)))
            ;; No colon — try package/class completion
            (guard (exn (else '()))
              ;; Try as a package name
              (let ((pkg (java.lang.Package:getPackage prefix)))
                (if (not (eq? pkg #!null))
                    '()
                    ;; Try as partial class name — look in common packages
                    (complete-symbols prefix))))))))

    ;; Complete Scheme symbols from the interaction environment.
    (define (complete-symbols prefix)
      (let* ((env (interaction-environment))
             (candidates '()))
        ;; Iterate over known symbols.
        ;; Kawa doesn't have a direct "list all symbols" function,
        ;; so we use the environment's defineLocation enumerator.
        (guard (exn (else '()))
          (let ((iter (env:enumerateAllLocations)))
            (let loop ()
              (when (iter:hasNext)
                (let* ((loc (iter:next))
                       (sym (invoke (invoke loc 'getKeySymbol) 'toString)))
                  (when (string-prefix? prefix sym)
                    (set! candidates (cons sym candidates))))
                (loop)))))
        (java.util.Collections:sort candidates)
        candidates))

    (define (geiser-completions prefix)
      (let ((candidates
             (if (java-interop-prefix? prefix)
                 (complete-java prefix)
                 (complete-symbols prefix))))
        (display (string-append "("
                 (string-join (map (lambda (s) (string-append "\"" s "\""))
                                   candidates)
                              " ")
                 ")\n")))))
