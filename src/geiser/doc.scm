(define-library (geiser doc)
  (export geiser-autodoc geiser-object-signature)
  (import (scheme write)
          (kawa base))
  (begin
    ;; Extract argument names from a Kawa procedure.
    (define (procedure-signature proc :: gnu.mapping.Procedure)
      (guard (exn (else #f))
        (let* ((name (invoke (invoke proc 'getName) 'toString))
               (params #f)
               (param-count 0))
          ;; getParameters may not exist; safe fallback.
          (guard (exn2 (else (set! param-count 0)))
            (let ((p (invoke proc 'getParameters)))
              (if (eq? p #!null)
                  (set! param-count 0)
                  (set! param-count (invoke p 'length)))))
          (let ((param-names '()))
            (do ((i :: int 0 (+ i 1)))
                ((>= i param-count))
              (set! param-names
                    (cons (string-append "arg" (number->string i))
                          param-names)))
            (list name (reverse param-names))))))

    ;; Resolve a symbol and get its signature.
    (define (resolve-signature id)
      (guard (exn (else #f))
        (let* ((env (interaction-environment))
               (loc (env:getLocation id)))
          (if (eq? loc #!null)
              (java-signature id)
              (let ((val (loc:get)))
                (cond ((gnu.mapping.Procedure? val)
                       (procedure-signature val))
                      (else (list id '()))))))))

    ;; Try to resolve as Java class members.
    (define (java-signature id)
      ;; Try Class.forName first.
      (guard (exn (else #f))
        (let* ((cls :: java.lang.Class (java.lang.Class:forName id))
               (methods :: java.lang.reflect.Method[] (cls:getMethods))
               (constructors :: java.lang.reflect.Constructor[]
                             (cls:getConstructors))
               (sigs '()))
          ;; Collect method signatures.
          (do ((i :: int 0 (+ i 1)))
              ((>= i (java.lang.reflect.Array:getLength methods)))
            (let* ((m :: java.lang.reflect.Method
                      (java.lang.reflect.Array:get methods i))
                   (m-name :: String (m:getName))
                   (params (map (lambda (p :: java.lang.Class)
                                  (p:getSimpleName))
                                (vector->list (m:getParameterTypes)))))
              (set! sigs (cons (list m-name params) sigs))))
          ;; Also collect constructor signatures.
          (do ((i :: int 0 (+ i 1)))
              ((>= i (java.lang.reflect.Array:getLength constructors)))
            (let* ((c :: java.lang.reflect.Constructor
                      (java.lang.reflect.Array:get constructors i))
                   (params (map (lambda (p :: java.lang.Class)
                                  (p:getSimpleName))
                                (vector->list (c:getParameterTypes)))))
              (set! sigs (cons (list id params) sigs))))
          (reverse sigs))))

    (define (geiser-autodoc ids)
      (let ((results '()))
        (for-each
         (lambda (id)
           (let ((sig (resolve-signature
                       (if (symbol? id)
                           (symbol->string id)
                           id))))
             (when sig (set! results (cons sig results)))))
         (if (list? ids) ids (list ids)))
        (reverse results)))

    (define (geiser-object-signature name)
      (let ((sig (resolve-signature name)))
        (if sig (list sig) '())))))
