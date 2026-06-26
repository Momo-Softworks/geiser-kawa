(define-library (geiser complete)
  (export geiser-completions
          ;; Exported for testing:
          complete-java-members
          complete-symbols
          complete-classes)
  (import (scheme write)
          (kawa base)
          (geiser string-util)
          (geiser classpath))
  (begin
    ;; Try to resolve a potentially unqualified class name.
    (define (resolve-class name)
      (let ((pkgs '("" "java.lang." "java.util." "java.io."
                    "cpw.mods.fml.common."
                    "cpw.mods.fml.common.registry."
                    "net.minecraft.init."
                    "net.minecraft.block."
                    "net.minecraft.item."
                    "net.minecraft.world."
                    "net.minecraft.entity.")))
        (let loop ((remaining pkgs))
          (if (null? remaining)
              #f
              (guard (exn (else (loop (cdr remaining))))
                (let ((full (string-append (car remaining) name)))
                  (java.lang.Class:forName full)
                  full))))))

    (define (complete-java-members prefix)
      (let* ((s (->string prefix))
             (colon-pos (str-last-index COLON s)))
        (if (< colon-pos 0)
            '()
            (let* ((raw-class (invoke s 'substring 0 colon-pos))
                   (class-name (or (resolve-class raw-class) raw-class))
                   (member-prefix (invoke s 'substring (+ colon-pos 1)
                                        (invoke s 'length))))
              (guard (exn (else '()))
                (let* ((cls :: java.lang.Class
                            (java.lang.Class:forName class-name))
                       (methods :: java.lang.reflect.Method[]
                                (invoke cls 'getMethods))
                       (fields :: java.lang.reflect.Field[]
                               (invoke cls 'getFields))
                       (candidates '()))
                  (do ((i :: int 0 (+ i 1)))
                      ((>= i (java.lang.reflect.Array:getLength methods)))
                    (let* ((m :: java.lang.reflect.Method
                              (java.lang.reflect.Array:get methods i))
                           (name :: String (invoke m 'getName)))
                      (when (str-starts-with? name member-prefix)
                        (set! candidates
                              (cons (string-append raw-class ":" name "("
                                    (string-join
                                     (map (lambda (p :: java.lang.Class)
                                            (invoke p 'getSimpleName))
                                          (vector->list
                                           (invoke m 'getParameterTypes)))
                                     ", ")
                                    ")")
                                    candidates)))))
                  (do ((i :: int 0 (+ i 1)))
                      ((>= i (java.lang.reflect.Array:getLength fields)))
                    (let* ((f :: java.lang.reflect.Field
                              (java.lang.reflect.Array:get fields i))
                           (name :: String (invoke f 'getName)))
                      (when (str-starts-with? name member-prefix)
                        (set! candidates
                              (cons (string-append raw-class ":" name)
                                    candidates)))))
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
                  (complete-classes prefix))))
    ))
