(define-library (geiser complete)
  (export geiser-completions)
  (import (scheme write)
          (kawa base)
          (geiser classpath))
  (begin
    (define (->string x) :: String
      (invoke x 'toString))

    (define (java-interop-prefix? prefix)
      (let ((s (->string prefix)))
        (or (>= (invoke s 'indexOf ":") 0)
            (>= (invoke s 'indexOf ".") 0))))

    ;; Complete Java class members (methods, fields) via reflection.
    (define (complete-java-members prefix)
      (let* ((s (->string prefix))
             (colon-pos (invoke s 'lastIndexOf ":")))
        (if (< colon-pos 0)
            '()
            (let ((class-name (invoke s 'substring 0 colon-pos))
                  (member-prefix (invoke s 'substring (+ colon-pos 1)
                                       (invoke s 'length))))
              (guard (exn (else '()))
                (let* ((cls :: java.lang.Class
                            (java.lang.Class:forName class-name))
                       (methods :: java.lang.reflect.Method[]
                                (cls:getMethods))
                       (fields :: java.lang.reflect.Field[]
                               (cls:getFields))
                       (candidates '()))
                  (do ((i :: int 0 (+ i 1)))
                      ((>= i (methods:length)))
                    (let* ((m :: java.lang.reflect.Method (methods i))
                           (name :: String (m:getName)))
                      (when (invoke name 'startsWith member-prefix)
                        (set! candidates
                              (cons (string-append name "("
                                    (string-join
                                     (map (lambda (p :: java.lang.Class)
                                            (p:getSimpleName))
                                          (vector->list
                                           (m:getParameterTypes)))
                                     ", ")
                                    ")")
                                    candidates)))))
                  (do ((i :: int 0 (+ i 1)))
                      ((>= i (fields:length)))
                    (let* ((f :: java.lang.reflect.Field (fields i))
                           (name :: String (f:getName)))
                      (when (invoke name 'startsWith member-prefix)
                        (set! candidates (cons name candidates)))))
                  candidates))))))

    ;; Complete Scheme symbols.
    (define (complete-symbols prefix)
      (let* ((s (->string prefix))
             (env (interaction-environment))
             (candidates '())
             (limit 100))
        (guard (exn (else '()))
          (let ((iter (env:enumerateAllLocations)))
            (let loop ()
              (when (and (iter:hasNext) (< (length candidates) limit))
                (let* ((loc (iter:next))
                       (sym (invoke (invoke loc 'getKeySymbol) 'toString)))
                  (when (invoke sym 'startsWith s)
                    (set! candidates (cons sym candidates))))
                (loop)))))
        (java.util.Collections:sort candidates)
        candidates))

    (define (geiser-completions prefix)
      (if (java-interop-prefix? prefix)
          (complete-java-members prefix)
          (append (complete-symbols prefix)
                  (complete-classes prefix))))))
