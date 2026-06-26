(define-library (geiser doc)
  (export geiser-autodoc geiser-object-signature)
  (import (scheme write)
          (kawa base))
  (begin

    ;; Extract argument names and types from a procedure or macro.
    (define (procedure-signature proc)
      (guard (exn (else #f))
        (let ((name (gnu.mapping.Procedure:getName proc)))
          (if name
              (let* ((params (gnu.mapping.Procedure:getParameters proc))
                     (param-count (if (eq? params #!null) 0 (params:length)))
                     (param-names '()))
                ;; Try to get parameter names from the lambda list
                (guard (exn (else (set! param-names '("..."))))
                  (when (> param-count 0)
                    (set! param-names
                          (map (lambda (i) (string-append "arg" (number->string i)))
                               (iota param-count)))))
                (list (gnu.mapping.Symbol:toString name) param-names))
              #f))))

    ;; Resolve a symbol and get its signature.
    (define (resolve-signature id)
      (guard (exn (else #f))
        (let* ((env (interaction-environment))
               (sym (string->symbol id))
               (loc (env:getLocation id)))
          (if (eq? loc #!null)
              ;; Not found in environment — try as Java class member
              (java-signature id)
              (let ((val (loc:get)))
                (if (gnu.mapping.Procedure? val)
                    (procedure-signature val)
                    ;; Just return the name with no args
                    (list id '())))))))

    ;; Try to resolve as Java method signature.
    (define (java-signature id)
      (let ((colon-pos (string-index-right id #\:)))
        (if colon-pos
            (guard (exn (else #f))
              (let* ((class-name (substring id 0 colon-pos))
                     (member-name (substring id (+ colon-pos 1)
                                            (string-length id)))
                     (cls (java.lang.Class:forName class-name))
                     (methods (cls:getMethods))
                     (sigs '()))
                (do ((i 0 (+ i 1)))
                    ((>= i (methods:length)))
                  (let ((m :: java.lang.reflect.Method (methods i)))
                    (when (string=? member-name (m:getName))
                      (set! sigs
                            (cons (list member-name
                                        (map (lambda (p) (p:getSimpleName))
                                             (vector->list (m:getParameterTypes))))
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
        ;; Return results as a list — geiser extracts the return value.
        ;; Format: (("name" ("arg1" "arg2" ...)) ...)
        (reverse results)))

    (define (geiser-object-signature name)
      ;; Return signature as a single-element list.
      (let ((sig (resolve-signature name)))
        (if sig (list sig) '())))))

