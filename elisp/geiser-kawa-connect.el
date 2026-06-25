;;; geiser-kawa-connect.el --- Connect Geiser to external Kawa REPL -*- lexical-binding: t -*-

;; Author: Samuel Willet
;; Version: 0.1
;; Package-Requires: ((emacs "24.4") (geiser "0.26"))
;; Keywords: languages, scheme, kawa, geiser

;;; Commentary:
;;
;; Connect Geiser to an already-running Kawa TCP REPL (port 4243 standalone,
;; 4242 in-game).  After connecting, use C-c C-z to associate the buffer.

;;; Code:

(require 'geiser)

;;;###autoload
(defun geiser-kawa-connect (&optional host port)
  "Connect to a running Kawa REPL on HOST and PORT.
HOST defaults to \"localhost\".  Use C-c C-z after connecting to
associate the current buffer with the REPL."
  (interactive
   (list (read-string "Kawa host (default localhost): " nil nil "localhost")
         (read-number "Kawa port: ")))
  (require 'geiser-kawa)
  (geiser-connect 'kawa (or host "localhost") port))

(provide 'geiser-kawa-connect)

;;; geiser-kawa-connect.el ends here
