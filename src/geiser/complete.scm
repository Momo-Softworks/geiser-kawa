(define-library (geiser complete)
  (export geiser-completions
          geiser-completion-annotation
          ;; Exported for testing:
          complete-java-members
          complete-symbols
          complete-classes)
  (import (scheme write)
          (kawa base)
          (geiser string-util)
          (geiser classpath))
  (begin
    (define *completion-annotation-cache* (java.util.HashMap:new))

    (define (cache-annotation! candidate annotation)
      (invoke *completion-annotation-cache* 'put candidate annotation)
      candidate)

    (define (cached-annotation candidate)
      (let ((value (invoke *completion-annotation-cache* 'get candidate)))
        (and (not (eq? value #!null)) value)))

    ;; Try to resolve a potentially unqualified class name.
    ;; Strategy:
    ;;   1. Try the name as-is (fully qualified).
    ;;   2. Try common JVM package prefixes (java.lang, java.util, java.io).
    ;;   3. Search the class cache for simple-name (unqualified) matches.
    ;;      - One match: use it.
    ;;      - Multiple matches: prefer the shortest fully-qualified name
    ;;        (closest to the default package).
    (define (resolve-class name)
      (define (try-load full)
        (guard (exn (else #f))
          (java.lang.Class:forName full)
          full))
      (let ((s (->string name)))
        ;; 1. Try fully qualified.
        (or (try-load s)
            ;; 2. Fast common JVM packages.
            (let ((fast-pkgs '("java.lang." "java.util." "java.io.")))
              (let loop ((pkgs fast-pkgs))
                (and (not (null? pkgs))
                     (or (try-load (string-append (car pkgs) s))
                         (loop (cdr pkgs))))))
            ;; 3. Search class cache for unqualified matches.
            (let ((simple (let ((dot (invoke s 'lastIndexOf ".")))
                            (if (> dot -1)
                                (invoke s 'substring (+ dot 1))
                                s))))
              (ensure-class-cache)
              (let collect ((classes *class-cache*) (matches '()))
                (cond ((null? classes)
                       ;; Prefer shortest qualified name.
                       (and (not (null? matches))
                            (let ((best (car matches)))
                              (let choose ((rest (cdr matches)) (best best))
                                (if (null? rest)
                                    (try-load best)
                                    (choose (cdr rest)
                                            (if (< (invoke (->string (car rest))
                                                           'length)
                                                   (invoke (->string best)
                                                           'length))
                                                (car rest)
                                                best)))))))
                      (else
                       (let* ((candidate (->string (car classes)))
                              (dot (invoke candidate 'lastIndexOf "."))
                              (cand-simple (if (> dot -1)
                                               (invoke candidate 'substring (+ dot 1))
                                               candidate)))
                         (collect (cdr classes)
                                  (if (invoke cand-simple 'equals simple)
                                      (cons candidate matches)
                                      matches))))))))))

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
                        (let* ((candidate
                                (string-append raw-class ":" name "("
                                               (string-join
                                                (map (lambda (p :: java.lang.Class)
                                                       (invoke p 'getSimpleName))
                                                     (vector->list
                                                      (invoke m 'getParameterTypes)))
                                                ", ")
                                               ")"))
                               (annotation
                                (if (java.lang.reflect.Modifier:isStatic
                                     (invoke m 'getModifiers))
                                    " static method"
                                    " method")))
                          (set! candidates
                                (cons (cache-annotation! candidate annotation)
                                      candidates))))))
                  (do ((i :: int 0 (+ i 1)))
                      ((>= i (java.lang.reflect.Array:getLength fields)))
                    (let* ((f :: java.lang.reflect.Field
                              (java.lang.reflect.Array:get fields i))
                           (name :: String (invoke f 'getName)))
                      (when (str-starts-with? name member-prefix)
                        (let* ((candidate (string-append raw-class ":" name))
                               (annotation
                                (if (java.lang.reflect.Modifier:isStatic
                                     (invoke f 'getModifiers))
                                    " static field"
                                    " field")))
                          (set! candidates
                                (cons (cache-annotation! candidate annotation)
                                      candidates))))))
                  candidates))))))

    (define (strip-member-signature member)
      (let* ((s (->string member))
             (paren (invoke s 'indexOf (as int 40))))
        (if (< paren 0)
            s
            (invoke s 'substring 0 paren))))

    (define (java-member-annotation class-name member-name)
      (guard (exn (else #f))
        (let* ((cls :: java.lang.Class (java.lang.Class:forName class-name))
               (member (strip-member-signature member-name))
               (methods :: java.lang.reflect.Method[] (invoke cls 'getMethods))
               (fields :: java.lang.reflect.Field[] (invoke cls 'getFields)))
          (let method-loop ((i :: int 0))
            (if (< i (java.lang.reflect.Array:getLength methods))
                (let* ((m :: java.lang.reflect.Method
                          (java.lang.reflect.Array:get methods i))
                       (name :: String (invoke m 'getName)))
                  (if (invoke name 'equals member)
                      (if (java.lang.reflect.Modifier:isStatic
                           (invoke m 'getModifiers))
                          " static method"
                          " method")
                      (method-loop (+ i 1))))
                (let field-loop ((j :: int 0))
                  (if (< j (java.lang.reflect.Array:getLength fields))
                      (let* ((f :: java.lang.reflect.Field
                                (java.lang.reflect.Array:get fields j))
                             (name :: String (invoke f 'getName)))
                        (if (invoke name 'equals member)
                            (if (java.lang.reflect.Modifier:isStatic
                                 (invoke f 'getModifiers))
                                " static field"
                                " field")
                            (field-loop (+ j 1))))
                      #f)))))))

    (define (known-class-candidate? name)
      (ensure-class-cache)
      (let ((s (->string name)))
        (let loop ((classes *class-cache*))
          (and (not (null? classes))
               (let* ((candidate (->string (car classes)))
                      (dot (invoke candidate 'lastIndexOf "."))
                      (simple (if (> dot -1)
                                  (invoke candidate 'substring (+ dot 1))
                                  candidate)))
                 (or (invoke candidate 'equals s)
                     (invoke simple 'equals s)
                     (loop (cdr classes))))))))

    (define (geiser-completion-annotation candidate)
      (let* ((s (->string candidate))
             (colon-pos (str-last-index COLON s)))
        (or (cached-annotation s)
            (if (>= colon-pos 0)
                (let* ((raw-class (invoke s 'substring 0 colon-pos))
                       (class-name (or (resolve-class raw-class) raw-class))
                       (member-name (invoke s 'substring (+ colon-pos 1)
                                            (invoke s 'length))))
                  (or (java-member-annotation class-name member-name) " member"))
                (or (guard (exn (else #f))
                      (let ((class-name (or (resolve-class s) s)))
                        (java.lang.Class:forName class-name)
                        " class"))
                    (and (known-class-candidate? s) " class")
                    "")))))

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

    (define (java-member-prefix? prefix)
      (>= (str-index COLON (->string prefix)) 0))

    (define (geiser-completions prefix)
      ;; Only Class:member syntax should use Java member completion.
      ;; Package/class prefixes such as net. or cpw.mods must continue
      ;; through classpath class completion.
      (if (java-member-prefix? prefix)
          (complete-java-members prefix)
          (append (complete-symbols prefix)
                  (complete-classes prefix))))
    ))
