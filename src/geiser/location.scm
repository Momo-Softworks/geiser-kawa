(define-library (geiser location)
  (export geiser-symbol-location geiser-module-location)
  (import (scheme write)
          (kawa base))
  (begin
    ;; Find the decompiled Minecraft source root under build/rfg/.
    (define (find-minecraft-src-root)
      (let* ((cp (java.lang.System:getProperty "java.class.path"))
             (sep (java.lang.System:getProperty "path.separator")))
        (and cp
             (let ((parts (invoke (invoke cp 'toString) 'split sep)))
               (let loop ((i :: int 0))
                 (if (>= i (java.lang.reflect.Array:getLength parts))
                     #f
                     (let* ((entry :: String
                                    (java.lang.reflect.Array:get parts i))
                            (src (string-append
                                  (invoke entry 'replaceAll
                                          "/[^/]+\\.jar$" "")
                                  "/rfg/minecraft-src/java")))
                       (if (invoke (java.io.File src) 'isDirectory)
                           src
                           (loop (+ i 1))))))))))

    ;; Return (file line col) for a symbol, or #f.
    (define (geiser-symbol-location symbol)
      ;; Convert symbol to string if needed.
      (let ((name (cond ((symbol? symbol) (symbol->string symbol))
                        ((string? symbol) symbol)
                        (else #f))))
        (and name
             ;; Try to find as a Java class.
             (guard (exn (else #f))
               (let* ((cls :: java.lang.Class
                           (java.lang.Class:forName name))
                      (src-root (find-minecraft-src-root)))
                 (and src-root
                      (let* ((rel (invoke (invoke name 'toString)
                                         'replace "." "/"))
                             (path (string-append src-root "/" rel ".java"))
                             (f (java.io.File path)))
                        (and (invoke f 'exists)
                             (list path 1 0)))))))))

    ;; Return (file) for a module, or #f.
    (define (geiser-module-location module-spec)
      #f)))
