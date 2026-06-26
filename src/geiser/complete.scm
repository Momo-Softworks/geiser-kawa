(define-library (geiser complete)
  (export geiser-completions)
  (import (scheme write)
          (kawa base))
  (begin
    (define (java-interop-prefix? prefix)
      (or (string-contains prefix ":")
          (string-contains prefix ".")))

    ;; Complete Java class members (methods, fields) via reflection.
    (define (complete-java-members prefix)
      (let ((colon-pos (string-index-right prefix #\:)))
        (if (not colon-pos)
            '()
            (let ((class-name (substring prefix 0 colon-pos))
                  (member-prefix (substring prefix (+ colon-pos 1)
                                           (string-length prefix))))
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
                      (when (string-prefix? member-prefix name)
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
                      (when (string-prefix? member-prefix name)
                        (set! candidates (cons name candidates)))))
                  candidates))))))

    ;; Try to resolve a Java class by prefix.
    (define (complete-classes prefix)
      (let ((candidates '()))
        ;; Common Java/Minecraft packages
        (for-each
         (lambda (pkg)
           (let ((full (string-append pkg prefix)))
             (guard (exn (else #f))
               (java.lang.Class:forName full)
               (set! candidates (cons full candidates)))))
         '("java.lang." "java.util." "java.io."
           "cpw.mods.fml.common."
           "cpw.mods.fml.common.registry."
           "net.minecraft.init."
           "net.minecraft.block."
           "net.minecraft.item."))
        (java.util.Collections:sort candidates)
        candidates))

    ;; Complete Scheme symbols.
    (define (complete-symbols prefix)
      (let* ((env (interaction-environment))
             (candidates '()))
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
      (if (java-interop-prefix? prefix)
          (complete-java-members prefix)
          (append (complete-symbols prefix)
                  (complete-classes prefix))))))
