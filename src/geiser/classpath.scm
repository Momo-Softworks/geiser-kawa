(define-library (geiser classpath)
  (export ensure-class-cache complete-classes *class-cache*
          geiser-refresh-class-cache geiser-class-cache-stats
          scan-dir scan-zip)
  (import (kawa base)
          (geiser string-util))
  (begin
    (define *class-cache* #f)
    (define *class-cache-stats* '())

    (define (ensure-class-cache)
      (when (not *class-cache*)
        (let ((names '())
              (jar-count 0)
              (dir-count 0))
          (let* ((cp (java.lang.System:getProperty "java.class.path"))
                 (sep (java.lang.System:getProperty "path.separator")))
            (when cp
              (let ((entries (->string cp)))
                (let ((parts (invoke entries 'split sep)))
                  (do ((i :: int 0 (+ i 1)))
                      ((>= i (java.lang.reflect.Array:getLength parts)))
                    (let ((entry :: String
                                 (java.lang.reflect.Array:get parts i)))
                      (guard (exn (else #f))
                        (let ((f :: java.io.File (java.io.File entry)))
                          (if (invoke f 'isDirectory)
                              (begin
                                (set! dir-count (+ dir-count 1))
                                (set! names (scan-dir f "" names)))
                              (if (invoke entry 'endsWith ".jar")
                                  (begin
                                    (set! jar-count (+ jar-count 1))
                                    (set! names (scan-zip entry names)))
                                  (set! names names)))))))))))
          (set! *class-cache* names)
          (set! *class-cache-stats*
                (list (cons "class-count" (length names))
                      (cons "jars-scanned" jar-count)
                      (cons "dirs-scanned" dir-count))))))

    (define (geiser-refresh-class-cache)
      "Rescan the classpath and rebuild the class name cache.
Returns an alist with updated stats."
      (set! *class-cache* #f)
      (set! *class-cache-stats* '())
      (ensure-class-cache)
      *class-cache-stats*)

    (define (geiser-class-cache-stats)
      "Return an alist describing the current class cache state.
Keys: class-count, jars-scanned, dirs-scanned."
      (ensure-class-cache)
      *class-cache-stats*)

    (define (scan-dir dir :: java.io.File rel :: String names)
      (let ((files :: java.io.File[] (invoke dir 'listFiles)))
        (if files
            (let loop ((i :: int 0) (acc names))
              (if (>= i (java.lang.reflect.Array:getLength files))
                  acc
                  (let* ((f :: java.io.File
                            (java.lang.reflect.Array:get files i))
                         (nm :: String (->string (invoke f 'getName))))
                    (if (invoke f 'isDirectory)
                        (loop (+ i 1)
                              (scan-dir f
                                        (if (= (invoke rel 'length) 0)
                                            nm
                                            (->string (string-append rel "/" nm)))
                                        acc))
                        (if (invoke nm 'endsWith ".class")
                            (let* ((no-ext :: String
                                           (invoke nm 'substring 0
                                                   (- (invoke nm 'length) 6)))
                                   (cls :: String
                                        (if (= (invoke rel 'length) 0)
                                            no-ext
                                            (let ((raw (->string
                                                        (string-append rel "." no-ext))))
                                              (->string
                                               (string-join
                                                (invoke raw 'split "/") "."))))))
                              (loop (+ i 1) (cons cls acc)))
                            (loop (+ i 1) acc))))))
            names)))

    (define (scan-zip path :: String names)
      (guard (exn (else names))
        (let* ((jf :: java.util.jar.JarFile
                   (java.util.jar.JarFile path))
               (entries (invoke jf 'entries)))
          (let loop ((acc names))
            (if (invoke entries 'hasMoreElements)
                (let* ((je :: java.util.jar.JarEntry
                           (invoke entries 'nextElement))
                       (nm :: String (->string (invoke je 'getName))))
                  (if (and (invoke nm 'endsWith ".class")
                           (not (invoke nm 'contains "$")))
                      (let* ((no-ext :: String
                                     (invoke nm 'substring 0
                                             (- (invoke nm 'length) 6)))
                             (cls :: String
                                  (->string
                                   (string-join
                                    (invoke no-ext 'split "/") "."))))
                        (loop (cons cls acc)))
                      (loop acc)))
                (begin (invoke jf 'close) acc))))))

    (define (take-n xs n)
      (if (or (<= n 0) (null? xs))
          '()
          (cons (car xs) (take-n (cdr xs) (- n 1)))))

    (define (complete-classes prefix)
      (ensure-class-cache)
      (let ((candidates '()) (limit 1000))
        (for-each
         (lambda (name)
           (let ((sname (->string name)))
             (when (invoke sname 'startsWith prefix)
               (set! candidates (cons name candidates)))
             ;; Also match unqualified name (after last dot).
             (let ((dot (invoke sname 'lastIndexOf ".")))
               (when (and (> dot -1)
                          (invoke sname 'substring (+ dot 1))
                          (invoke
                           (invoke sname 'substring (+ dot 1))
                           'startsWith prefix))
                 (set! candidates
                       (cons (invoke sname 'substring (+ dot 1))
                             candidates))))))
         *class-cache*)
        (java.util.Collections:sort candidates)
        ;; Deduplicate manually (Kawa 3.1.1 has no delete-duplicates).
        (let dedup ((in candidates) (out '()))
          (if (null? in)
              (take-n (reverse out) limit)
              (dedup (cdr in)
                     (if (and (pair? out) (string=? (car in) (car out)))
                         out
                         (cons (car in) out)))))))))
