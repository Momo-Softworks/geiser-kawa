(import (geiser emacs))

(define tests-passed 0)
(define tests-failed 0)

(define (any pred lst)
  (and (not (null? lst))
       (or (pred (car lst)) (any pred (cdr lst)))))

(define (assert-equal label expected actual)
  (display (if (equal? expected actual) "PASS" "FAIL"))
  (display " ")
  (display label)
  (if (not (equal? expected actual))
      (begin
        (display " (expected ")
        (write expected)
        (display " got ")
        (write actual)
        (display ")")
        (set! tests-failed (+ tests-failed 1)))
      (set! tests-passed (+ tests-passed 1)))
  (newline))

(define (assert-true label val)
  (assert-equal label #t (if val #t #f)))

(define (assert-approx label expected actual delta)
  (assert-true label (<= (abs (- expected actual)) delta)))

;; ================ string-util ================
(display "--- string-util ---\n")
(assert-equal "str-index colon"
              6 (str-index COLON (->string "foobar:val")))
(assert-equal "str-index dot"
              3 (str-index DOT (->string "foo.bar")))
(assert-equal "str-index not-found"
              -1 (str-index COLON (->string "nocolon")))
(assert-equal "str-last-index"
              11 (str-last-index COLON (->string "a:b:c:d:e:f:val")))
(assert-true  "str-starts-with?"
              (str-starts-with? (->string "foobar") "foo"))
(assert-equal "->string type"
              "java.lang.String"
              (invoke (invoke (->string "hello") 'getClass) 'getName))
(assert-true  "java-interop-prefix? colon"
              (java-interop-prefix? "String:val"))
(assert-true  "java-interop-prefix? dot"
              (java-interop-prefix? "java.lang"))
(assert-equal "java-interop-prefix? none"
              #f (java-interop-prefix? "display"))

;; ================ eval ================
(display "--- eval ---\n")
(let* ((out (open-output-string))
       (saved (current-output-port)))
  ;; geiser-eval writes to stdout via display; we verify its
  ;; format by checking the return value of eval directly.
  (let ((val (eval (read (open-input-string "(+ 1 2)"))
                   (interaction-environment))))
    (assert-equal "eval result" 3 val)))

;; ================ completions: scheme symbols ================
(display "--- completions: scheme symbols ---\n")
(let ((c (complete-symbols "disp")))
  (assert-true "symbols has display" (member "display" c)))

;; ================ completions: Java members ================
(display "--- completions: Java members ---\n")
(let ((c (complete-java-members "java.lang.String:valu")))
  (assert-true "members has valueOf"
               (any (lambda (s) (invoke (->string s) 'contains "valueOf")) c))
  (assert-approx "members count" (length c) 9 5)
  (assert-true "members prefixed with class"
               (str-starts-with? (->string (car c)) "java.lang.String:")))

(let ((c (complete-java-members "java.lang.String:length")))
  (assert-true "members has length()"
               (any (lambda (s) (invoke (->string s) 'contains "length()")) c)))

;; ================ completions: classpath ================
(display "--- completions: classpath ---\n")
(ensure-class-cache)
(assert-true "cache populated" (> (length *class-cache*) 100))
(assert-true "cache has kawa classes"
             (any (lambda (s) (invoke (->string s) 'contains "kawa.")) *class-cache*))
(assert-true "cache has gnu classes"
             (any (lambda (s) (invoke (->string s) 'contains "gnu.")) *class-cache*))

(let ((c (complete-classes "kawa.repl")))
  (assert-true "complete kawa.repl" (> (length c) 0)))

;; ================ geiser-completions (combined) ================
(display "--- geiser-completions ---\n")
(let ((c (geiser-completions "disp")))
  (assert-true "combined has display" (member "display" c)))

(let ((c (geiser-completions "java.lang.String:valu")))
  (assert-true "combined Java member" (> (length c) 0)))

;; ================ autodoc ================
(display "--- autodoc ---\n")
(let ((r (geiser-autodoc (list "display"))))
  (assert-true "autodoc result" (list? r)))

;; ================ location ================
(display "--- location ---\n")
(let ((loc (geiser-symbol-location "java.lang.String")))
  (assert-equal "no source for String" #f loc))

;; ================ geiser protocol simulation ================
(display "--- protocol simulation ---\n")

;; This is exactly what geiser sends for completions:
;; (:eval (:ge completions "prefix")) goes through geiser-eval--eval
;; which calls geiser-eval--form('eval, module, scheme-str(form))
;; The final expression sent to Kawa is:
;; (geiser-eval #f "(geiser-completions \"prefix\")")

(let* ((val (eval (read (open-input-string
                         "(geiser-completions \"java.lang.String:valu\")"))
                  (interaction-environment)))
       (out (open-output-string)))
  (write val out)
  (let ((rs (->string (get-output-string out))))
    (assert-true "protocol: result is list" (>= (invoke rs 'indexOf "(") 0))
    (assert-true "protocol: has valueOf"
                 (>= (invoke rs 'indexOf "valueOf") 0))))

;; ================ summary ================
(newline)
(display "=== ")
(display tests-passed)
(display " passed, ")
(display tests-failed)
(display " failed ===\n")

(if (> tests-failed 0) (exit 1) (exit 0))
