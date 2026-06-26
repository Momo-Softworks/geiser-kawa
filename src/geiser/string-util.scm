(define-library (geiser string-util)
  (export ->string str-index str-last-index str-starts-with?
           java-interop-prefix? COLON DOT)
  (import (kawa base))
  (begin
    (define COLON (as int 58))
    (define DOT   (as int 46))

    (define (->string x) :: String
      (java.lang.String:new (invoke x 'toString)))

    (define (str-index ch str :: String) :: int
      (invoke str 'indexOf ch))

    (define (str-last-index ch str :: String) :: int
      (invoke str 'lastIndexOf ch))

    (define (str-starts-with? s :: String prefix :: String) :: boolean
      (invoke s 'startsWith prefix))

    (define (java-interop-prefix? prefix)
      (let ((s (->string prefix)))
        (or (>= (str-index COLON s) 0)
            (>= (str-index DOT s) 0))))))
