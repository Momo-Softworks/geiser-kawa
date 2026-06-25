;;; geiser-kawa-capf-test.el --- tests for geiser-kawa-capf -*- lexical-binding:t -*-

;; Copyright (C) 2024

;; SPDX-License-Identifier: BSD-3-Clause

;;; Commentary:
;; Focused buttercup spec for `geiser-kawa-capf', the completion-at-point
;; function added on top of the kawa-devutil Java completion backend.  It starts
;; the included-Kawa REPL exactly like geiser-kawa-test.el's `before-all' (build
;; the fat jar, use-included-kawa, run the REPL) and then checks that the capf
;; offers a real java.lang.String member ("format") for "(java.lang.String:)".
;;
;; Run it in isolation (it does NOT pull in the rest of the suite):
;;   cask emacs --batch -L . -L elisp \
;;     -l buttercup -l elisp/tests/geiser-kawa-capf-test.el -f buttercup-run

;;; Code:

(require 'buttercup)
(require 'geiser)
(require 'geiser-mode)
(require 'geiser-kawa)

(describe "geiser-kawa-capf"

  (before-all
   (geiser-kawa-deps-mvnw-package geiser-kawa-dir)
   (while compilation-in-progress
     (sleep-for 0 250))
   (setq geiser-kawa-use-included-kawa t)
   (switch-to-buffer "*geiser-kawa-capf-test*")
   (geiser-impl--set-buffer-implementation 'kawa)
   (run-kawa)
   (geiser-mode))

  (it "is a function and never errors when there is nothing to complete"
      ;; In an empty buffer there is no member expression, so it must return
      ;; nil rather than signal — capfs must never error.
      (with-temp-buffer
        (geiser-impl--set-buffer-implementation 'kawa)
        (expect (functionp 'geiser-kawa-capf) :to-be t)))

  (it "offers java.lang.String members (incl. \"format\") after a colon"
      (switch-to-buffer "*geiser-kawa-capf-test*")
      (delete-region (point-min) (point-max))
      (geiser-impl--set-buffer-implementation 'kawa)
      (insert "(java.lang.String:)")
      ;; Put point right after the ':' (before the closing paren).
      (goto-char (1- (point-max)))
      (let* ((capf (geiser-kawa-capf))
             (collection (nth 2 capf)))
        (expect capf :not :to-be nil)
        (expect (member "format" collection) :not :to-be nil))))

(provide 'geiser-kawa-capf-test)

;;; geiser-kawa-capf-test.el ends here
