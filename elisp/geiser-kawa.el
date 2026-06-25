;;; geiser-kawa.el --- Kawa scheme support for Geiser -*- lexical-binding:t -*-

;; Copyright (C) 2018 Mathieu Lirzin <mthl@gnu.org>
;; Copyright (C) 2019-2020 spellcard199 <spellcard199@protonmail.com>
;; Copyright (C) 2025 Momo Softworks

;; Author: spellcard199 <spellcard199@protonmail.com>
;; Maintainer: Momo Softworks
;; Keywords: languages, kawa, scheme, geiser
;; Homepage: https://github.com/Momo-Softworks/geiser-kawa
;; Package-Requires: ((emacs "27.1") (geiser "0.26"))
;; SPDX-License-Identifier: BSD-3-Clause
;; Version: 0.2.0

;;; Commentary:
;; geiser-kawa extends Geiser to support the Kawa Scheme implementation.
;; Follows the same pattern as geiser-guile: one file, activate-and-go.
;;
;; Two ways to start a REPL:
;;   M-x run-kawa              — local Kawa REPL (needs java/kawa on PATH)
;;   M-x geiser-kawa-connect   — connect to an already-running TCP REPL
;;                                 (e.g. make repl on port 4243)
;;
;; The Kawa REPL must have the geiser protocol procedures loaded.
;; The included jar (kawa-geiser) provides them; it's loaded at startup
;; via the --arglist (require <kawageiser.Geiser>).

;;; Code:

(require 'geiser-base)
(require 'geiser-custom)
(require 'geiser-syntax)
(require 'geiser-log)
(require 'geiser-connection)
(require 'geiser-eval)
(require 'geiser-edit)
(require 'geiser-repl)
(require 'geiser)
(require 'geiser-impl)
(require 'compile)
(require 'info-look)
(require 'cl-lib)

;; ── Customization ──────────────────────────────────────────────────────

(defgroup geiser-kawa nil
  "Customization for Geiser's Kawa Scheme flavour."
  :group 'geiser)

(geiser-custom--defcustom geiser-kawa-binary "kawa"
  "Name to use to call the Kawa Scheme executable when starting a REPL."
  :type '(choice string (repeat string))
  :group 'geiser-kawa)

;; Package directory (for resolving the fat jar path)
(defconst geiser-kawa-elisp-dir
  (file-name-directory (or load-file-name (buffer-file-name)))
  "Directory containing geiser-kawa's Elisp files.")

(defconst geiser-kawa-dir
  (if (string-suffix-p "elisp/" geiser-kawa-elisp-dir)
      (expand-file-name "../" geiser-kawa-elisp-dir)
    geiser-kawa-elisp-dir)
  "Directory where geiser-kawa is located.")

(defcustom geiser-kawa-deps-jar-path
  (expand-file-name
   "./target/kawa-geiser-0.1-SNAPSHOT-jar-with-dependencies.jar"
   geiser-kawa-dir)
  "Path to the kawa-geiser fat jar."
  :type 'string
  :group 'geiser-kawa)

(defcustom geiser-kawa-use-included-kawa nil
  "Use the Kawa bundled in the geiser-kawa fat jar instead of `kawa' binary."
  :type 'boolean
  :group 'geiser-kawa)

;; Register with customize system
(custom-add-load 'geiser-kawa (symbol-name 'geiser-kawa))
(custom-add-load 'geiser      (symbol-name 'geiser-kawa))

;; ── Prompt ─────────────────────────────────────────────────────────────

(defconst geiser-kawa--prompt-regexp "#|kawa:[0-9]+|# "
  "Regexp matching the Kawa REPL prompt.")

;; ── Binary & arglist ──────────────────────────────────────────────────

(defun geiser-kawa--binary ()
  "Return the binary to call to start Kawa."
  (if geiser-kawa-use-included-kawa
      "java"
    (if (listp geiser-kawa-binary)
        (car geiser-kawa-binary)
      geiser-kawa-binary)))

(defun geiser-kawa--arglist ()
  "Return arguments to pass to Kawa at startup.
Loads the geiser protocol procedures via (require <kawageiser.Geiser>)."
  `("console:use-jline=no"
    "--console"
    "-e" "(require <kawageiser.Geiser>)"
    "--"))

;; ── Classpath helpers ──────────────────────────────────────────────────

(defun geiser-kawa--extra-classpath ()
  "Return extra classpath entries for the Kawa REPL.
Includes the kawa-geiser fat jar and any jars from
`geiser-kawa-extra-classpath'."
  (delq nil
        (append (when (file-exists-p geiser-kawa-deps-jar-path)
                  (list geiser-kawa-deps-jar-path))
                (when (boundp 'geiser-kawa-extra-classpath)
                  geiser-kawa-extra-classpath))))

(defun geiser-kawa--java-arglist ()
  "Return java invocation arguments when using the included Kawa."
  (let ((cp (string-join (geiser-kawa--extra-classpath)
                          path-separator)))
    `(,(concat "-cp" cp)
      "kawa.repl"
      ,@(geiser-kawa--arglist))))

;; ── Version ────────────────────────────────────────────────────────────

(defun geiser-kawa--version-command (_binary)
  "Return a scheme form that yields the version string."
  "(system-reactive-string \"kawa\")")

;; ── Geiser protocol ────────────────────────────────────────────────────

(defun geiser-kawa--geiser-procedure (proc &rest args)
  "Geiser's marshall-procedure: format a geiser protocol call for Kawa.
PROC is the procedure name.  ARGS are the arguments."
  (cl-case proc
    ((eval compile)
     (format "(geiser:eval (interaction-environment) %S)" (cadr args)))
    ((load-file compile-file)
     (format "(geiser:load-file %s)" (car args)))
    ((no-values) "(geiser:no-values)")
    (t (let ((form (mapconcat #'identity args " ")))
         (format "(geiser:%s %s)" proc form)))))

(defun geiser-kawa--symbol-begin (module)
  "Find the start of the symbol at point for completion.
MODULE is non-nil when completing a module name."
  (if module
      (max (save-excursion (beginning-of-line) (point))
           (save-excursion (skip-syntax-backward "^(>") (1- (point))))
    (save-excursion (skip-syntax-backward "^'-()>") (point))))

(defun geiser-kawa--import-command (module)
  "Return command to import MODULE."
  (format "(import %s)" module))

(defun geiser-kawa--exit-command ()
  "Command to exit the Kawa REPL."
  "(exit 0)")

(defun geiser-kawa--display-error (_module key msg)
  "Display an error from the REPL.
KEY is the error type, MSG is the message."
  (when (stringp msg)
    (save-current-buffer   ;; prevent background buffer from stealing focus
      (save-excursion (insert msg)))
    (geiser-edit--buttonize-files))
  (and (not key) (not (zerop (length msg))) msg))

(defun geiser-kawa--repl-startup (_remote)
  "Called after the REPL has been initialized.
REMOTE is non-nil for remote (TCP) connections."
  nil)

;; ── Implementation definition ──────────────────────────────────────────

(define-geiser-implementation kawa
  (unsupported-procedures '(find-file
                            module-location
                            symbol-location
                            symbol-documentation
                            module-exports
                            callers callees
                            generic-methods))
  (binary geiser-kawa--binary)
  (repl-startup geiser-kawa--repl-startup)
  (prompt-regexp geiser-kawa--prompt-regexp)
  (debugger-prompt-regexp nil)
  (marshall-procedure geiser-kawa--geiser-procedure)
  (exit-command geiser-kawa--exit-command)
  (import-command geiser-kawa--import-command)
  (find-symbol-begin geiser-kawa--symbol-begin)
  (display-error geiser-kawa--display-error)
  (version-command geiser-kawa--version-command)
  (case-sensitive nil))

(geiser-activate-implementation 'kawa)

;; ── run-kawa override ──────────────────────────────────────────────────

;;;###autoload
(autoload 'run-kawa "geiser-kawa" "Start a Geiser Kawa Scheme REPL." t)

;;;###autoload
(autoload 'switch-to-kawa "geiser-kawa"
  "Start a Geiser Kawa Scheme REPL, or switch to a running one." t)

(defun geiser-kawa-run-kawa ()
  "Start a Kawa REPL.  If the deps jar is missing, prompt to build it."
  (interactive)
  (if (file-exists-p geiser-kawa-deps-jar-path)
      (geiser 'kawa)
    (when (y-or-n-p
           (concat "geiser-kawa depends on additional java libraries. "
                   "Do you want to download and compile them now?"))
      (let ((default-directory geiser-kawa-dir)
            (buf (compile "./mvnw package")))
        (when buf
          (switch-to-buffer-other-window buf)
          (goto-char (point-max))
          (message "After the build finishes, run M-x run-kawa again."))))))

;; ── Optional modules ───────────────────────────────────────────────────
;; Loaded eagerly so hooks register before buffers open.
(require 'geiser-kawa-connect nil t)
(require 'geiser-kawa-java-location nil t)
(require 'geiser-kawa-devutil-complete nil t)

(provide 'geiser-kawa)

;;; geiser-kawa.el ends here
