;;; geiser-kawa-java-location-jump-test.el --- live jump-to-def specs -*- lexical-binding:t -*-

;; Copyright (C) 2024 Momo Softworks

;; SPDX-License-Identifier: BSD-3-Clause

;;; Commentary:
;; Live-REPL spec for the backend half of jump-to-definition: starting the
;; included-Kawa REPL like the main suite, `--matches-at-point' for
;; "(java.lang.String:format)" must resolve the owning class to
;; java/lang/String.java and return a real source line for the "format"
;; overloads.  (Visiting the file is exercised without a REPL in
;; geiser-kawa-java-location-test.el.)

;;; Code:

(require 'buttercup)
(require 'cl-lib)
(require 'geiser)
(require 'geiser-mode)
(require 'geiser-kawa)
(require 'geiser-kawa-java-location)

(describe "geiser-kawa-java-location--matches-at-point"

  (before-all
   (geiser-kawa-deps-mvnw-package geiser-kawa-dir)
   (while compilation-in-progress
     (sleep-for 0 250))
   (setq geiser-kawa-use-included-kawa t)
   (switch-to-buffer "*gkjl-jump-test*")
   (geiser-impl--set-buffer-implementation 'kawa)
   (run-kawa)
   (geiser-mode))

  (it "resolves java.lang.String:format to String.java with real lines"
      (switch-to-buffer "*gkjl-jump-test*")
      (delete-region (point-min) (point-max))
      (geiser-impl--set-buffer-implementation 'kawa)
      (insert "(java.lang.String:format)")
      ;; point right after "format", before the closing paren
      (goto-char (1- (point-max)))
      (let ((matches (geiser-kawa-java-location--matches-at-point)))
        (expect matches :not :to-be nil)
        ;; every match points at String's source file
        (expect (cadr (assoc "source-resource" (car matches)))
                :to-equal "java/lang/String.java")
        ;; at least one is the `format' member, with a positive line number
        (let ((fmt (cl-find-if
                    (lambda (m) (equal (cadr (assoc "member" m)) "format"))
                    matches)))
          (expect fmt :not :to-be nil)
          (expect (> (cadr (assoc "line" fmt)) 0) :to-be t)))))

(provide 'geiser-kawa-java-location-jump-test)

;;; geiser-kawa-java-location-jump-test.el ends here
