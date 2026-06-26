(define-library (geiser location)
  (export geiser-symbol-location geiser-module-location
          ;; Exported for introspection
          source-roots)
  (import (scheme write)
          (kawa base)
          (geiser string-util)
          (geiser classpath))
  (begin
    (define (jfile-exists? path :: String)
      (invoke (java.io.File path) 'exists))

    (define (jdir? path :: String)
      (invoke (java.io.File path) 'isDirectory))

    (define (jparent path :: String)
      (let ((p (invoke (java.io.File path) 'getParent)))
        (and (not (eq? p #!null)) p)))

    ;; ------------------------------------------------------------------
    ;; Source-root discovery.
    ;; Primary: read `geiser.kawa.source.path` system property
    ;; (colon-separated on Unix, semicolon on Windows).
    ;; Fallback: derive source roots from classpath entries by following
    ;; common conventions (e.g. build/classes → src/main/java).

    (define (system-source-roots)
      "Return source roots from the `kawa.source.path' property
(or the legacy `geiser.kawa.source.path')."
      (let ((prop (or (java.lang.System:getProperty "kawa.source.path")
                      (java.lang.System:getProperty "geiser.kawa.source.path"))))
        (if prop
            (let* ((sep (java.lang.System:getProperty "path.separator"))
                   (parts (invoke (->string prop) 'split sep)))
              (let loop ((i :: int 0) (roots '()))
                (if (>= i (java.lang.reflect.Array:getLength parts))
                    (reverse roots)
                    (let ((root (->string
                                 (java.lang.reflect.Array:get parts i))))
                      (loop (+ i 1)
                            (if (jdir? root)
                                (cons root roots)
                                roots))))))
            '())))

    (define (classpath-entries)
      (let* ((cp (java.lang.System:getProperty "java.class.path"))
             (sep (java.lang.System:getProperty "path.separator")))
        (if cp
            (let ((parts (invoke (->string cp) 'split sep)))
              (let loop ((i :: int 0) (out '()))
                (if (>= i (java.lang.reflect.Array:getLength parts))
                    (reverse out)
                    (loop (+ i 1)
                          (cons (java.lang.reflect.Array:get parts i) out)))))
            '())))

    (define (derived-source-root entry)
      "Try to derive a source root from a classpath entry using
common conventions.  For a classes directory under a build tree,
look for `src/main/java' or `src' at the build root."
      (let* ((s (->string entry))
             (build-dir "/build/"))
        ;; Only applicable to directory entries under a build root.
        (and (jdir? s)
             (let ((build-pos (invoke s 'indexOf build-dir)))
               (and (>= build-pos 0)
                    (let* ((build-root
                            (invoke s 'substring 0
                                    (+ build-pos
                                       (invoke build-dir 'length))))
                           (candidates
                            (list (string-append build-root "../src/main/java")
                                  (string-append build-root "../src/main/kawa")
                                  (string-append build-root "../src")
                                  (string-append build-root "../src/main/scheme"))))
                      (let find ((rest candidates))
                        (and (not (null? rest))
                             (let ((cand (car rest)))
                               (if (jdir? cand)
                                   cand
                                   (find (cdr rest))))))))))))

    (define (fallback-source-roots)
      "Derive source roots from classpath entries using generic heuristics."
      (let loop ((entries (classpath-entries)) (roots '()))
        (if (null? entries)
            roots
            (let ((root (derived-source-root (car entries))))
              (loop (cdr entries)
                    (if (and root (not (member root roots)))
                        (cons root roots)
                        roots))))))

    (define (source-roots)
      "Return all source roots, preferring the explicit system property."
      (let ((explicit (system-source-roots)))
        (if (not (null? explicit))
            explicit
            (fallback-source-roots))))

    ;; ------------------------------------------------------------------
    ;; Source lookup.

    (define (class-name->source-path class-name root)
      (let ((rel (string-join (invoke (->string class-name) 'split "\\.") "/")))
        (string-append root "/" rel ".java")))

    (define (find-java-source class-name)
      (let loop ((roots (source-roots)))
        (if (null? roots)
            #f
            (let ((path (class-name->source-path class-name (car roots))))
              (if (jfile-exists? path)
                  path
                  (loop (cdr roots)))))))

    (define (line-containing path needle)
      (guard (exn (else 1))
        (let ((reader (java.io.BufferedReader:new (java.io.FileReader:new path))))
          (let loop ((line :: int 1))
            (let ((text (invoke reader 'readLine)))
              (cond ((eq? text #!null)
                     (invoke reader 'close)
                     1)
                    ((>= (invoke (->string text) 'indexOf needle) 0)
                     (invoke reader 'close)
                     line)
                    (else (loop (+ line 1)))))))))

    (define (simple-class-name class-name)
      (let* ((s (->string class-name))
             (dot (invoke s 'lastIndexOf ".")))
        (if (> dot -1)
            (invoke s 'substring (+ dot 1))
            s)))

    (define (strip-member name)
      (let* ((s (->string name))
             (colon (str-last-index COLON s)))
        (if (>= colon 0)
            (invoke s 'substring 0 colon)
            s)))

    (define (resolve-class-name name)
      (let* ((raw (strip-member name))
             (s (->string raw)))
        (or (guard (exn (else #f))
              (java.lang.Class:forName s)
              s)
            (begin
              (ensure-class-cache)
              (let loop ((classes *class-cache*) (found #f))
                (cond (found found)
                      ((null? classes) #f)
                      (else
                       (let* ((candidate (->string (car classes)))
                              (simple (simple-class-name candidate)))
                         (loop (cdr classes)
                               (and (or (invoke candidate 'equals s)
                                        (invoke simple 'equals s))
                                    candidate))))))))))

    (define (make-location name file line column)
      (list (cons "name" name)
            (cons "file" file)
            (cons "line" line)
            (cons "column" column)))

    ;; Return a Geiser location alist for a symbol, or #f.
    (define (geiser-symbol-location symbol)
      (let* ((name (cond ((symbol? symbol) (symbol->string symbol))
                         ((string? symbol) symbol)
                         (else #f)))
             (class-name (and name (resolve-class-name name)))
             (path (and class-name (find-java-source class-name))))
        (and path
             (let* ((simple (simple-class-name class-name))
                    (needle (string-append "class " simple))
                    (line (line-containing path needle)))
               (make-location class-name path line 0)))))

    ;; Return a Geiser location alist for a module, or #f.
    (define (geiser-module-location module-spec)
      #f)))
