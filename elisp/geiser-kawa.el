;;; geiser-kawa.el --- Kawa scheme support for Geiser -*- lexical-binding:t -*-

;; SPDX-License-Identifier: BSD-3-Clause
;; Version: 1.0.0

;;; Commentary:
;; A modern, pure-Scheme backend for Kawa in Geiser.
;; Defers introspection, evaluation, and completion directly
;; to Kawa Scheme instead of relying on a Java middleware layer.
;; Scheme sources live in src/geiser/ and are loaded via -Dkawa.import.path.

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
  (require 'cl-lib)
  (require 'subr-x))

;;; Customization

(defgroup geiser-kawa nil
  "Customization for Geiser's Kawa flavour."
  :group 'geiser)

(geiser-custom--defcustom geiser-kawa-binary "kawa"
  "Name to use to call the Kawa executable when starting a REPL."
  :type '(choice string (repeat string)))

(geiser-custom--defcustom geiser-kawa-classpath nil
  "A list of paths to JAR files or directories added to Kawa's JVM classpath.
When set, the Kawa REPL is started via `env CLASSPATH=... kawa ...'
because the Guix Kawa launcher (and some others) do not accept a
`--classpath' flag.  The CLASSPATH environment variable is always
honoured by the JVM itself.

Only needed for plain `M-x run-kawa'.  For Minecraft/Forge
development the recommended workflow is:

  ./gradlew kawaRepl
  M-x geiser-kawa-connect

and the Gradle plugin will assemble the correct classpath
automatically."
  :type '(repeat file))

;;; REPL binary and parameters

(defun geiser-kawa--binary ()
  "Return the executable used to start Kawa.
When `geiser-kawa-classpath' is set, use `env' so the JVM
classpath can be supplied through CLASSPATH.  The Kawa launcher
shipped by Guix/Kawa 3.1.1 does not accept a `--classpath' flag."
  (if geiser-kawa-classpath
      "env"
    (if (listp geiser-kawa-binary)
        (car geiser-kawa-binary)
      geiser-kawa-binary)))

(defun geiser-kawa--default-scheme-dir ()
  "Return the default directory containing Kawa-side Geiser modules.
Support both the installed Guix/ELPA layout, where `src' is next
 to `geiser-kawa.el', and the development checkout layout, where
 this file lives under `elisp/' and `src' is one directory up."
  (let* ((base (file-name-directory (or load-file-name buffer-file-name)))
         (installed (expand-file-name "src" base))
         (checkout (expand-file-name "../src" base)))
    (if (file-exists-p (expand-file-name "geiser/emacs.scm" installed))
        installed
      checkout)))

(defvar geiser-kawa-scheme-dir
  (geiser-kawa--default-scheme-dir)
  "Directory where the Kawa scheme geiser modules are installed.")

(defun geiser-kawa--parameters ()
  "Return a list with all parameters needed to start Kawa."
  (let* ((cp-string (when geiser-kawa-classpath
                      (mapconcat #'expand-file-name geiser-kawa-classpath
                                 path-separator)))
         (kawa-command (if (listp geiser-kawa-binary)
                           geiser-kawa-binary
                         (list geiser-kawa-binary))))
    `(,@(when cp-string
          (list (concat "CLASSPATH=" cp-string)))
      ,@(if cp-string
            kawa-command
          (and (listp geiser-kawa-binary) (cdr geiser-kawa-binary)))
      ,(concat "-Dkawa.import.path=" geiser-kawa-scheme-dir)
      "-e" "(import (geiser emacs))"
      "-s")))

(defconst geiser-kawa--prompt-regexp "^#|kawa:[0-9]+|# ")

;;; Evaluation support

(defun geiser-kawa--geiser-procedure (proc &rest args)
  "Transform PROC in string for a scheme procedure using ARGS."
  (cl-case proc
    ((eval compile)
     ;; Use %S (not '%s) so the form is sent as a string, not quoted.
     ;; Quoting prevents function calls like (geiser-completions ...)
     ;; from being evaluated — they become literal lists.
     (format "(geiser-eval %s %S)"
             (or (car args) "#f")
             (mapconcat #'identity (cdr args) " ")))
    ((load-file compile-file)
     (format "(geiser-load-file \"%s\")" (car args)))
    ((no-values) "(geiser-no-values)")
    ((refresh-class-cache) "(geiser-refresh-class-cache)")
    ((class-cache-stats) "(geiser-class-cache-stats)")
    (t
     ;; Args are already Schemified by geiser-eval--scheme-str (%S).
     ;; Use %s (not %S) to avoid double-quoting.
     (let ((form (mapconcat #'identity args " ")))
       (format "(geiser-%s %s)" proc form)))))

;;; Modules and environments

(defconst geiser-kawa--library-re
  "(\\(?:define-\\)?library[[:blank:]\n]+\\(([^)]+)\\)"
  "Regular expression matching an R7RS library declaration.")

(defconst geiser-kawa--module-name-re
  "(module-name[[:blank:]\n]+\\([^()[:blank:]\n]+\\)"
  "Regular expression matching a Kawa `module-name' declaration.")

(defconst geiser-kawa--guess-re
  (format "\\(%s\\|%s\\|#! *.+\\(/\\| \\)kawa\\( *\\\\\\)?\\)"
          geiser-kawa--library-re
          geiser-kawa--module-name-re)
  "Regular expression used to recognize Kawa Scheme buffers.")

(defun geiser-kawa--read-module-string (module)
  "Read MODULE as a Scheme module expression."
  (condition-case nil
      (car (geiser-syntax--read-from-string module))
    (error :f)))

(defun geiser-kawa--get-module (&optional module)
  "Find current buffer's module using MODULE as a hint."
  (cond ((null module)
         (save-excursion
           (geiser-syntax--pop-to-top)
           (cond ((or (re-search-backward geiser-kawa--library-re nil t)
                      (re-search-forward geiser-kawa--library-re nil t))
                  (geiser-kawa--get-module (match-string-no-properties 1)))
                 ((or (re-search-backward geiser-kawa--module-name-re nil t)
                      (re-search-forward geiser-kawa--module-name-re nil t))
                  (match-string-no-properties 1))
                 (t :f))))
        ((listp module) module)
        ((stringp module)
         (if (string-prefix-p "(" module)
             (geiser-kawa--read-module-string module)
           module))
        (t :f)))

(defun geiser-kawa--format-module (module)
  "Return MODULE formatted for Kawa import/enter commands."
  (let ((module (geiser-kawa--get-module module)))
    (cond ((or (null module) (eq module :f)) nil)
          ((listp module) (format "%s" module))
          ((stringp module) module)
          (t (format "%s" module)))))

(defun geiser-kawa--import-command (module)
  "Return command used to import MODULEs."
  (when-let ((module (geiser-kawa--format-module module)))
    (format "(import %s)" module)))

(defun geiser-kawa--exit-command ()
  "Command to send to exit from Kawa REPL."
  "(exit 0)")

(defun geiser-kawa--symbol-begin (module)
  "Find beginning of symbol in the context of MODULE."
  (if module
      (max (save-excursion (beginning-of-line) (point))
           (save-excursion (skip-syntax-backward "^(>") (1- (point))))
    (save-excursion (skip-syntax-backward "^'-()>") (point))))

;;; Buffer detection and syntax

(defun geiser-kawa--guess ()
  "Ascertain whether the current buffer contains Kawa Scheme code."
  (save-excursion
    (goto-char (point-min))
    (re-search-forward geiser-kawa--guess-re nil t)))

(defconst geiser-kawa--builtin-keywords
  '("as"
    "define-alias"
    "define-class"
    "define-constant"
    "define-early-constant"
    "define-enum"
    "define-member-alias"
    "define-namespace"
    "define-private"
    "define-simple-class"
    "define-syntax-case"
    "define-variable"
    "fluid-let"
    "format"
    "future"
    "instance?"
    "invoke"
    "invoke-special"
    "invoke-static"
    "lambda"
    "module-compile-options"
    "module-export"
    "module-extends"
    "module-implements"
    "module-name"
    "object"
    "primitive-throw"
    "runnable"
    "setter"
    "synchronized"
    "this")
  "Kawa-specific keywords for font locking.")

(defun geiser-kawa--keywords ()
  "Return Kawa-specific Scheme keywords."
  (append
   (geiser-syntax--simple-keywords geiser-kawa--builtin-keywords)
   `(("(\\(module-name\\)[[:blank:]\n]+\\([^()[:blank:]\n]+\\)"
      (1 font-lock-keyword-face)
      (2 font-lock-type-face nil t))
     ("(\\(define-library\\)[[:blank:]\n]+(\\([^)]+\\))"
      (1 font-lock-keyword-face)
      (2 font-lock-type-face nil t)))))

(geiser-syntax--scheme-indent
 (define-simple-class 1)
 (fluid-let 1)
 (future 0)
 (invoke-special 2)
 (invoke-static 1)
 (module-compile-options 0)
 (object 1)
 (synchronized 1))

;;; Completion annotations

(defvar-local geiser-kawa--completion-annotation-cache nil
  "Cache mapping completion candidates to Kawa annotation strings.")

(defun geiser-kawa--completion-annotation (candidate)
  "Return a Corfu/CAPF annotation for completion CANDIDATE."
  (when (eq geiser-impl--implementation 'kawa)
    (unless (hash-table-p geiser-kawa--completion-annotation-cache)
      (setq geiser-kawa--completion-annotation-cache
            (make-hash-table :test 'equal)))
    (or (gethash candidate geiser-kawa--completion-annotation-cache)
        (let ((annotation
               (ignore-errors
                 (geiser-eval--send/result
                  `(:eval (:ge completion-annotation ,candidate))))))
          (setq annotation (and (stringp annotation) annotation))
          (puthash candidate annotation geiser-kawa--completion-annotation-cache)
          annotation))))

(defun geiser-kawa--capf-thing-at-point (orig-fun module &optional predicate)
  "Add Kawa annotations to Geiser CAPF results from ORIG-FUN."
  (let ((result (funcall orig-fun module predicate)))
    (if (and result (eq geiser-impl--implementation 'kawa))
        (append result (list :annotation-function
                             #'geiser-kawa--completion-annotation))
      result)))

(with-eval-after-load 'geiser-capf
  (advice-add 'geiser-capf--thing-at-point
              :around #'geiser-kawa--capf-thing-at-point))

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
  (check-buffer geiser-kawa--guess)
  (keywords geiser-kawa--keywords)
  (case-sensitive t))

(geiser-impl--add-to-alist 'regexp "\\.scm\\'" 'kawa t)
(geiser-impl--add-to-alist 'regexp "\\.sld\\'" 'kawa t)

;;;###autoload
(defun connect-to-kawa ()
  "Start a Kawa REPL connected to a remote process."
  (interactive)
  (geiser-connect 'kawa))

;;;###autoload
(defalias 'geiser-kawa-connect 'connect-to-kawa
  "Connect to a running Kawa REPL.  Alias for `connect-to-kawa'.")

(geiser-activate-implementation 'kawa)

;;;###autoload
(autoload 'run-kawa "geiser-kawa" "Start a Geiser Kawa REPL." t)

;;;###autoload
(autoload 'switch-to-kawa "geiser-kawa"
  "Start a Geiser Kawa REPL, or switch to a running one." t)

;;; Cache management

;;;###autoload
(defun geiser-kawa-refresh-classpath ()
  "Rescan the Kawa REPL classpath and rebuild the class-name cache.
Useful after adding dependencies or rebuilding the project."
  (interactive)
  (let ((result (geiser-eval--send/result
                 '(:eval (:ge refresh-class-cache)))))
    (message "geiser-kawa: class cache refreshed — %s" result)))

;;;###autoload
(defun geiser-kawa-classpath-stats ()
  "Display statistics about the Kawa REPL class-name cache."
  (interactive)
  (let ((result (geiser-eval--send/result
                 '(:eval (:ge class-cache-stats)))))
    (message "geiser-kawa: class cache stats — %s" result)))

(provide 'geiser-kawa)
;;; geiser-kawa.el ends here
