(define-library (geiser doc)
  (export geiser-autodoc geiser-object-signature)
  (import (scheme write)
          (kawa base))
  (begin
    ;; Extract argument names and types from a procedure or macro.
    (define (procedure-signature proc)
      (guard (exn (else #f))
        (let* ((p :: gnu.mapping.Procedure proc)
               (name-obj (invoke p 'getName)))
          (if name-obj
              (let* ((name (invoke name-obj 'toString))
                     (params-obj (invoke p 'getParameters))
                     (param-count (if (eq? params-obj #!null)
                                      0
                                      (invoke params-obj 'length)))
                     (param-names '()))
                (do ((i :: int 0 (+ i 1)))
                    ((>= i param-count))
                  (set! param-names
                        (cons (string-append "arg"
                                             (number->string i))
                              param-names)))
                (list name (reverse param-names)))
              #f))))

    ;; Resolve a symbol and get its signature.
    (define (resolve-signature id)
      (guard (exn (else #f))
        (let* ((env (interaction-environment))
               (loc (env:getLocation id)))
          (if (eq? loc #!null)
              (java-signature id)
              (let ((val (loc:get)))
                (if (gnu.mapping.Procedure? val)
                    (procedure-signature val)
                    (list id '())))))))

    ;; Try to resolve as Java method signature.
    (define (java-signature id)
      (let ((colon-pos (string-index-right id #\:)))
        (if colon-pos
            (guard (exn (else #f))
              (let* ((class-name (substring id 0 colon-pos))
                     (member-name (substring id (+ colon-pos 1)
                                            (string-length id)))
                     (cls :: java.lang.Class
                          (java.lang.Class:forName class-name))
                     (methods :: java.lang.reflect.Method[]
                              (cls:getMethods))
                     (sigs '()))
                (do ((i :: int 0 (+ i 1)))
                    ((>= i (methods:length)))
                  (let* ((m :: java.lang.reflect.Method (methods i))
                         (m-name :: String (m:getName)))
                    (when (string=? member-name m-name)
                      (set! sigs
                            (cons (list member-name
                                        (map (lambda (p :: java.lang.Class)
                                               (p:getSimpleName))
                                             (vector->list
                                              (m:getParameterTypes))))
                                  sigs)))))
                (if (pair? sigs) (car sigs) #f)))
            #f)))

    (define (geiser-autodoc ids)
      (let ((results '()))
        (for-each
         (lambda (id)
           (let ((sig (resolve-signature (if (symbol? id)
                                             (symbol->string id)
                                             id))))
             (when sig (set! results (cons sig results)))))
         (if (list? ids) ids (list ids)))
        (reverse results)))

    (define (geiser-object-signature name)
      (let ((sig (resolve-signature name)))
        (if sig (list sig) '())))))
