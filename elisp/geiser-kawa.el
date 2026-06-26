;;; geiser-kawa.el --- Kawa scheme support for Geiser -*- lexical-binding:t -*-

;; SPDX-License-Identifier: BSD-3-Clause
;; Version: 1.0.0

;;; Commentary:
;; A modern, pure-Scheme backend for Kawa in Geiser.
;; Defers introspection, evaluation, and completion directly
;; to Kawa Scheme instead of relying on a Java middleware layer.
;; Scheme sources live in src/geiser/ and are loaded via --libdir.

;;; Code:

(require 'geiser-connection)
(require 'geiser-syntax)
(require 'geiser-custom)
(require 'geiser-repl)
(require 'geiser-impl)
(require 'geiser-base)
(require 'geiser-eval)
(require 'geiser-edit)
(require 'geiser-log)
(require 'geiser)

(eval-when-compile
  (require 'cl-lib))

;;; Customization

(defgroup geiser-kawa nil
  "Customization for Geiser's Kawa flavour."
  :group 'geiser)

(geiser-custom--defcustom geiser-kawa-binary "kawa"
  "Name to use to call the Kawa executable when starting a REPL."
  :type '(choice string (repeat string)))

(geiser-custom--defcustom geiser-kawa-classpath nil
  "A list of paths to JAR files or directories added to Kawa's JVM classpath.
Passed via the --classpath flag to the Kawa executable at startup.
Recommended to be set via .dir-locals.el in your project root."
  :type '(repeat file))

;;; REPL binary and parameters

(defun geiser-kawa--binary ()
  "Return the name of the Kawa binary to execute."
  (if (listp geiser-kawa-binary)
      (car geiser-kawa-binary)
    geiser-kawa-binary))

(defvar geiser-kawa-scheme-dir
  (expand-file-name "../src" (file-name-directory load-file-name))
  "Directory where the Kawa scheme geiser modules are installed.")

(defun geiser-kawa--parameters ()
  "Return a list with all parameters needed to start Kawa."
  (let* ((cp-string (when geiser-kawa-classpath
                      (mapconcat #'expand-file-name geiser-kawa-classpath
                                 path-separator)))
         (cp-flags (when cp-string (list "--classpath" cp-string))))
    `(,@(and (listp geiser-kawa-binary) (cdr geiser-kawa-binary))
      "--libdir" ,geiser-kawa-scheme-dir
      ,@cp-flags)))

(defconst geiser-kawa--prompt-regexp "^#|kawa:[0-9]+|# ")

;;; Evaluation support

(defun geiser-kawa--geiser-procedure (proc &rest args)
  "Transform PROC in string for a scheme procedure using ARGS."
  (cl-case proc
    ((eval compile)
     (format "(geiser-eval %s '%s)"
             (or (car args) "#f")
             (mapconcat #'identity (cdr args) " ")))
    ((load-file compile-file)
     (format "(geiser-load-file \"%s\")" (car args)))
    ((no-values) "(geiser-no-values)")
    (t
     (let ((form (mapconcat #'identity args " ")))
       (format "(geiser-%s %s)" proc form)))))

;;; Modules and environments

(defun geiser-kawa--get-module (&optional module)
  "Find current buffer's module using MODULE as a hint."
  (cond ((null module) :f)
        ((listp module) module)
        ((stringp module)
         (condition-case nil
             (car (geiser-syntax--read-from-string module))
           (error :f)))
        (t :f)))

(defun geiser-kawa--import-command (module)
  "Return command used to import MODULEs."
  (format "(import %s)" module))

(defun geiser-kawa--exit-command ()
  "Command to send to exit from Kawa REPL."
  "(exit 0)")

(defun geiser-kawa--symbol-begin (module)
  "Find beginning of symbol in the context of MODULE."
  (if module
      (max (save-excursion (beginning-of-line) (point))
           (save-excursion (skip-syntax-backward "^(>") (1- (point))))
    (save-excursion (skip-syntax-backward "^'-()>") (point))))

;;; Error display

(defun geiser-kawa--display-error (_module key msg)
  "Display error with given message MSG."
  (when (stringp msg)
    (save-current-buffer
      (save-excursion (insert msg)))
    (geiser-edit--buttonize-files))
  (and (not key) (not (zerop (length msg))) msg))

;;; Implementation definition

(define-geiser-implementation kawa
  (binary geiser-kawa--binary)
  (arglist geiser-kawa--parameters)
  (prompt-regexp geiser-kawa--prompt-regexp)
  (marshall-procedure geiser-kawa--geiser-procedure)
  (find-module geiser-kawa--get-module)
  (exit-command geiser-kawa--exit-command)
  (import-command geiser-kawa--import-command)
  (find-symbol-begin geiser-kawa--symbol-begin)
  (display-error geiser-kawa--display-error)
  (case-sensitive nil))

(geiser-impl--add-to-alist 'regexp "\\.scm\\'" 'kawa t)
(geiser-impl--add-to-alist 'regexp "\\.sld\\'" 'kawa t)

;;;###autoload
(defun connect-to-kawa ()
  "Start a Kawa REPL connected to a remote process."
  (interactive)
  (geiser-connect 'kawa))

;;;###autoload
(geiser-activate-implementation 'kawa)

;;;###autoload
(autoload 'run-kawa "geiser-kawa" "Start a Geiser Kawa REPL." t)

;;;###autoload
(autoload 'switch-to-kawa "geiser-kawa"
  "Start a Geiser Kawa REPL, or switch to a running one." t)

(provide 'geiser-kawa)
;;; geiser-kawa.el ends here
