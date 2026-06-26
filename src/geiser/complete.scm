(define-library (geiser complete)
  (export geiser-completions)
  (import (scheme write)
          (kawa base)
          (geiser classpath))
  (begin
    ;; Use integer char codes to avoid Kawa 3.1.1 #\: bug.
    (define COLON (as int 58))
    (define DOT   (as int 46))

    (define (str-index ch str :: String) :: int
      (invoke str 'indexOf ch))

    (define (str-last-index ch str :: String) :: int
      (invoke str 'lastIndexOf ch))

    (define (str-starts-with? s :: String prefix :: String) :: boolean
      (invoke s 'startsWith prefix))

    (define (java-interop-prefix? prefix)
      (let ((s (->string prefix)))
        (or (>= (str-index COLON s) 0)
            (>= (str-index DOT s) 0))))

    (define (complete-java-members prefix)
      (let* ((s (->string prefix))
             (colon-pos (str-last-index COLON s)))
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
                      ((>= i (java.lang.reflect.Array:getLength methods)))
                    (let* ((m :: java.lang.reflect.Method
                              (java.lang.reflect.Array:get methods i))
                           (name :: String (m:getName)))
                      (when (str-starts-with? name member-prefix)
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
                      ((>= i (java.lang.reflect.Array:getLength fields)))
                    (let* ((f :: java.lang.reflect.Field
                              (java.lang.reflect.Array:get fields i))
                           (name :: String (f:getName)))
                      (when (str-starts-with? name member-prefix)
                        (set! candidates (cons name candidates)))))
                  candidates))))))

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
                  (when (str-starts-with? sym s)
                    (set! candidates (cons sym candidates))))
                (loop)))))
        (java.util.Collections:sort candidates)
        candidates))

    (define (geiser-completions prefix)
      (if (java-interop-prefix? prefix)
          (complete-java-members prefix)
          (append (complete-symbols prefix)
                  (complete-classes prefix)))))
    )
