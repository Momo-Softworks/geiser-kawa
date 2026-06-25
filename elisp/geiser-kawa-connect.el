;;; geiser-kawa-connect.el --- Connect Geiser to external Kawa REPL -*- lexical-binding: t -*-

;; Author: Samuel Willet
;; Version: 0.1
;; Package-Requires: ((emacs "24.4") (geiser "0.26"))
;; Keywords: languages, scheme, kawa, geiser
;; URL: https://example.com/geiser-kawa

;;; Commentary:
;;
;; This module provides a simple command `geiser-kawa-connect' that
;; connects Geiser to an already-running Kawa REPL listening on a TCP
;; socket.  It is intended for use with the KawaCraft in-game REPL
;; (client port 4243, server port 4242).  The command prompts for a
;; host (default \"localhost\") and a port number, then invokes
;; `geiser-connect' with the `kawa' implementation.
;;
;; Note: The external Kawa REPL does not have the `geiser:*' helper
;; procedures loaded, so some Geiser features such as Java-aware
;; completion or autodoc may be unavailable.

;;; Code:

(require 'geiser)

;;;###autoload
(defun geiser-kawa-connect (&optional host port)
  "Connect to a running Kawa REPL on HOST and PORT.
HOST defaults to \"localhost\".  The command reads HOST and PORT
interactively, then calls `geiser-connect' with the `kawa' implementation.

If you are using the KawaCraft in-game REPL, the typical ports are
client: 4243 and server: 4242."
  (interactive
   (list (read-string "Kawa host (default localhost): " nil nil "localhost")
         (read-number "Kawa port: ")))
  (require 'geiser-kawa)
  (geiser-connect 'kawa (or host "localhost") port))

(provide 'geiser-kawa-connect)

;;; geiser-kawa-connect.el ends here
