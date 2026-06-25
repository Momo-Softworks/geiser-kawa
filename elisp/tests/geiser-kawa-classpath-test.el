;;; geiser-kawa-classpath-test.el --- tests for extra classpath -*- lexical-binding: t -*-

;; Copyright (C) 2024

;; SPDX-License-Identifier: BSD-3-Clause

;;; Commentary:
;; Tests for `geiser-kawa-extra-classpath' integration.  No running REPL is
;; needed: `geiser-kawa-arglist--make-classpath' is a pure function of its
;; bound variables.  It returns the single path-separator-joined string that
;; `geiser-kawa-arglist--make-classpath-arg' formats into -Djava.class.path.

;;; Code:

(require 'buttercup)
(require 'geiser-kawa-arglist)

(describe "geiser-kawa-extra-classpath"
  (it "returns a string (not a list) so the -Djava.class.path arg is well-formed"
    (let ((geiser-kawa-extra-classpath '("/tmp/a.jar")))
      (expect (stringp (geiser-kawa-arglist--make-classpath)) :to-be t)))
  (it "appends extra entries to the classpath when set"
    (let ((geiser-kawa-extra-classpath '("/tmp/a.jar")))
      (expect (geiser-kawa-arglist--make-classpath) :to-match "/tmp/a\\.jar")))
  (it "leaves the classpath unchanged when nil"
    (let ((geiser-kawa-extra-classpath nil))
      (expect (geiser-kawa-arglist--make-classpath) :not :to-match "/tmp/a\\.jar"))))

(provide 'geiser-kawa-classpath-test)

;;; geiser-kawa-classpath-test.el ends here
