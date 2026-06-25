;;; geiser-kawa-connect.el --- Connect Geiser to external Kawa REPL -*- lexical-binding: t -*-

;; Author: Samuel Willet
;; Version: 0.1
;; Package-Requires: ((emacs "24.4") (geiser "0.26"))
;; Keywords: languages, scheme, kawa, geiser

;;; Commentary:
;;
;; Connect Geiser to an already-running Kawa TCP REPL (port 4243 standalone,
;; 4242 in-game).  The command also associates the current buffer with the
;; REPL so that completions and eval work immediately.

;;; Code:

(require 'geiser)

;;;###autoload
(defun geiser-kawa-connect (&optional host port)
  "Connect to a running Kawa REPL on HOST and PORT.
Associates the current buffer with the REPL for completions and eval."
  (interactive
   (list (read-string "Kawa host (default localhost): " nil nil "localhost")
         (read-number "Kawa port: ")))
  (require 'geiser-kawa)
  (geiser-connect 'kawa (or host "localhost") port)
  ;; Associate the current buffer with the new REPL.
  (when (derived-mode-p 'scheme-mode)
    (setq geiser-impl--implementation 'kawa)
    (require 'geiser-repl)
    (geiser-repl--switch-to-buffer 'kawa)
    (geiser-repl--switch-to-buffer 'kawa)))

(provide 'geiser-kawa-connect)

;;; geiser-kawa-connect.el ends here
