;;; geiser-kawa-java-location-test.el --- source-path resolver tests -*- lexical-binding:t -*-

;; Copyright (C) 2024 Momo Softworks

;; SPDX-License-Identifier: BSD-3-Clause

;;; Commentary:
;; No-REPL specs for `geiser-kawa-java-location--resolve-source': it must find a
;; .java both inside a source directory and inside a source archive, and return
;; nil for an unknown resource.  The test archive is built with `jar' (always
;; present in the JDK that runs the suite); extraction uses `unzip'.

;;; Code:

(require 'buttercup)
(require 'cl-lib)
(require 'geiser-kawa-java-location)

(describe "geiser-kawa-java-location--resolve-source"
  :var (root dir-entry jar-entry)

  (before-all
   (setq root (make-temp-file "gkjl" t))
   ;; (1) a plain source directory: <root>/srcdir/a/b/C.java
   (let ((f (expand-file-name "srcdir/a/b/C.java" root)))
     (make-directory (file-name-directory f) t)
     (with-temp-file f (insert "package a.b;\npublic class C {}\n")))
   (setq dir-entry (expand-file-name "srcdir" root))
   ;; (2) a source archive built from <root>/jsrc with `jar'
   (let* ((jdir (expand-file-name "jsrc" root))
          (jf (expand-file-name "x/Y.java" jdir)))
     (make-directory (file-name-directory jf) t)
     (with-temp-file jf (insert "package x;\npublic class Y {}\n"))
     (setq jar-entry (expand-file-name "src.jar" root))
     (call-process "jar" nil nil nil "cf" jar-entry "-C" jdir ".")))

  (it "finds a .java in a source directory"
      (let ((geiser-kawa-source-path (list dir-entry)))
        (let ((hit (geiser-kawa-java-location--resolve-source "a/b/C.java")))
          (expect hit :not :to-be nil)
          (expect (file-exists-p hit) :to-be t))))

  (it "extracts a .java from a source archive"
      (let ((geiser-kawa-source-path (list jar-entry)))
        (let ((hit (geiser-kawa-java-location--resolve-source "x/Y.java")))
          (expect hit :not :to-be nil)
          (expect (file-exists-p hit) :to-be t))))

  (it "returns nil for an unknown resource"
      (let ((geiser-kawa-source-path (list dir-entry)))
        (expect (geiser-kawa-java-location--resolve-source
                 "no/such/Thing.java")
                :to-be nil))))

(provide 'geiser-kawa-java-location-test)

;;; geiser-kawa-java-location-test.el ends here
