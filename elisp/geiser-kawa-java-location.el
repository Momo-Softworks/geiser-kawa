;;; geiser-kawa-java-location.el --- jump to Java source definitions -*- lexical-binding:t -*-

;; Copyright (C) 2024 Momo Softworks

;; SPDX-License-Identifier: BSD-3-Clause

;;; Commentary:
;; Member-precise jump-to-definition for Java symbols in Kawa buffers.
;;
;; The Kawa side (`geiser:java-symbol-location', GeiserJavaLocation.java)
;; resolves the Java member at point to its owning class and the precise source
;; line(s) of every overload of that name (via the compiled class's
;; LineNumberTable, read with `javap -l').  This Elisp side maps the returned
;; "source-resource" (e.g. "net/minecraft/util/MathHelper.java") onto the user's
;; `geiser-kawa-source-path' (source jars / zips / dirs, plus a best-effort JDK
;; src.zip), extracts the file if it lives inside an archive, and visits it at
;; the definition line.  With several overloads you get a `completing-read'
;; chooser keyed by signature, so M-. lands on the exact one.
;;
;; Set the source path per project in .dir-locals.el, e.g. for KawaCraft:
;;   ((scheme-mode . ((geiser-kawa-source-path
;;      . ("build/rfg/mcp_patched_minecraft-sources.jar"
;;         "build/libs/kawacraft-0.1.0-sources.jar")))))

;;; Code:

(require 'cl-lib)
(require 'geiser-kawa-util)
(require 'geiser-kawa-devutil-complete)

(defcustom geiser-kawa-source-path nil
  "Java source locations used to resolve jump-to-definition targets.
Each entry is a string naming either a directory of .java sources, or a
source archive (a .jar/.zip/.srcjar, such as a Maven -sources jar or the
JDK src.zip).  Set it per project from .dir-locals.el so completion's
M-. can open Forge/Minecraft/your-own Java source."
  :type '(repeat string)
  :group 'geiser-kawa
  :safe (lambda (v) (or (null v) (and (listp v) (cl-every #'stringp v)))))

;;;; ---- source resolution (no REPL needed) -------------------------------

(defun geiser-kawa-java-location--jdk-src ()
  "Best-effort path to the JDK src.zip, derived from the `java' binary, or nil."
  (let ((java (executable-find "java")))
    (when java
      (let* ((bindir (file-name-directory (file-truename java)))
             (jdk (file-name-directory (directory-file-name bindir))))
        (cl-find-if #'file-exists-p
                    (list (expand-file-name "src.zip" jdk)
                          (expand-file-name "lib/src.zip" jdk)))))))

(defun geiser-kawa-java-location--cache-dir ()
  "Directory where archive entries are extracted for visiting."
  (let ((dir (expand-file-name "geiser-kawa-java-src"
                               temporary-file-directory)))
    (make-directory dir t)
    dir))

(defun geiser-kawa-java-location--extract-from-archive (archive resource)
  "Extract RESOURCE out of ARCHIVE into the cache; return its path or nil.
RESOURCE is an archive-internal path like \"java/lang/String.java\"."
  (let ((out (expand-file-name resource
                               (geiser-kawa-java-location--cache-dir))))
    (if (file-exists-p out)
        out
      (make-directory (file-name-directory out) t)
      (with-temp-buffer
        (let ((status (call-process "unzip" nil (current-buffer) nil
                                    "-p" archive resource)))
          (when (and (eq status 0) (> (buffer-size) 0))
            (write-region (point-min) (point-max) out nil 'silent)
            out))))))

(defun geiser-kawa-java-location--resolve-in (entry resource)
  "Try to resolve RESOURCE inside a single source-path ENTRY.  Return path or nil."
  (cond
   ((or (null entry) (not (file-exists-p entry))) nil)
   ((file-directory-p entry)
    (let ((f (expand-file-name resource entry)))
      (and (file-exists-p f) f)))
   ((string-match-p "\\.\\(jar\\|zip\\|srcjar\\)\\'" entry)
    (geiser-kawa-java-location--extract-from-archive entry resource))
   (t nil)))

(defun geiser-kawa-java-location--resolve-source (resource)
  "Find RESOURCE on `geiser-kawa-source-path' (then the JDK src.zip).
RESOURCE is like \"net/minecraft/util/MathHelper.java\".  Return an
absolute file path to visit, or nil if not found."
  (let ((paths (append geiser-kawa-source-path
                       (let ((jdk (geiser-kawa-java-location--jdk-src)))
                         (and jdk (list jdk))))))
    (cl-loop for entry in paths
             for hit = (geiser-kawa-java-location--resolve-in entry resource)
             when hit return hit)))

;;;; ---- backend query + the M-. command ----------------------------------

(defun geiser-kawa-java-location--matches-at-point ()
  "Ask Kawa for Java definition matches for the symbol at point.
Return the list of match alists (each with string keys \"member\",
\"signature\", \"source-resource\", \"line\"), possibly empty."
  (let* ((cpd (geiser-kawa-devutil-complete--code-point-from-toplevel))
         (code-str     (cdr (assoc "code-str" cpd)))
         (cursor-index (cdr (assoc "cursor-index" cpd)))
         (data (geiser-kawa-util--eval-get-result
                `(geiser:java-symbol-location ,code-str ,cursor-index)
                t)))
    (cadr (assoc "matches" data))))

(defun geiser-kawa-java-location--choose (matches)
  "Pick one match from MATCHES, prompting with signatures when there is >1."
  (if (= (length matches) 1)
      (car matches)
    (let* ((by-sig (mapcar (lambda (m)
                             (cons (or (cadr (assoc "signature" m))
                                       (cadr (assoc "member" m)))
                                   m))
                           matches))
           (pick (completing-read "Java definition: " by-sig nil t)))
      (cdr (assoc pick by-sig)))))

(defun geiser-kawa-java-location--visit (match)
  "Visit the source file for MATCH at its definition line.
Return the visited file, or nil (with a message) if it cannot be found."
  (let* ((resource (cadr (assoc "source-resource" match)))
         (line     (cadr (assoc "line" match)))
         (file (geiser-kawa-java-location--resolve-source resource)))
    (if (not file)
        (progn
          (message
           "geiser-kawa: %s is not on `geiser-kawa-source-path'" resource)
          nil)
      (find-file file)
      (goto-char (point-min))
      (when (and line (> line 0))
        (forward-line (1- line)))
      file)))

;;;###autoload
(defun geiser-kawa-jump-to-java-definition ()
  "Jump to the Java source definition of the member at point.
Uses the live Kawa REPL to resolve the member's owning class and exact
source line, then opens the file from `geiser-kawa-source-path'.  With
several overloads, prompts for which signature to visit."
  (interactive)
  (let ((matches (geiser-kawa-java-location--matches-at-point)))
    (if (null matches)
        (message "geiser-kawa: no Java definition found at point")
      (geiser-kawa-java-location--visit
       (geiser-kawa-java-location--choose matches)))))

(defun geiser-kawa-java-location-setup ()
  "Bind \\[geiser-kawa-jump-to-java-definition] to \\`M-.' for the kawa impl."
  (when (eq geiser-impl--implementation 'kawa)
    (local-set-key (kbd "M-.") #'geiser-kawa-jump-to-java-definition)))

(add-hook 'geiser-repl-mode-hook #'geiser-kawa-java-location-setup)
(add-hook 'scheme-mode-hook #'geiser-kawa-java-location-setup)

(provide 'geiser-kawa-java-location)

;;; geiser-kawa-java-location.el ends here
