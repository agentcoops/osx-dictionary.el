;;; osx-dictionary.el --- Interface for OSX Dictionary.app  -*- coding: utf-8-unix; -*-

;; Copyright (C) 2014-2015 by Chunyang Xu

;; Author: Chunyang Xu <xuchunyang56@gmail.com>
;; URL: https://github.com/xuchunyang/osx-dictionary.el
;; Package-Requires: ((cl-lib "0.5") (chinese-word-at-point "0.1"))
;; Version: 0.1
;; keywords: dictionary

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; Interface for OSX Dictionary.app
;;
;; Translation word by Dictionary.app, and display result using buffer.
;;
;; Below are commands you can use:
;; `osx-dictionary-search-input'
;; Search input word and display result with buffer
;; `osx-dictionary-search-pointer'
;; Search word around and display result with buffer
;;
;; Tips:
;;
;; If current mark is active, osx-dictionary commands will translate
;; region string, otherwise translate word around point.
;;

;;; Installation:
;;
;; `This package is available on Melpa.
;;

;;; Code:
(require 'cl-lib)
(require 'chinese-word-at-point)

(defgroup osx-dictionary nil
  "Mac OS X Dictionary.app interface for Emacs"
  :group 'leim)

(defcustom osx-dictionary-use-chinese-text-segmentation nil
  "Set to t to enable Chinese text segmentation.

A external Chinese text segmentation tool is required, refer to
URL `https://github.com/xuchunyang/chinese-word-at-point.el'
for more info."
  :group 'osx-dictionary
  :type 'boolean)

(defconst osx-dictionary-cli "osx-dictionary"
  "The name of executable file compiled from \"osx-dictionary.m\".")

(defconst osx-dictionary-buffer-name "*osx-dictionary*")

(defconst osx-dictionary--load-dir (file-name-as-directory (file-name-directory
                                                            load-file-name)))

(defvar osx-dictionary-mode-header-line
  '(
    (:propertize "i" face mode-line-buffer-id)
    ": Search Word"
    "    "
    (:propertize "o" face mode-line-buffer-id)
    ": Open in Dictionary.app"
    "    "
    (:propertize "y|c" face mode-line-buffer-id)
    ": Open in Youdao or Cambridge site"
    "    "
    (:propertize "q" face mode-line-buffer-id)
    ": Quit")
  "Header-line used on the `osx-dictionary-mode'.")

(defvar osx-dictionary-mode-font-lock-Keywords
  '(
    ;; Word class
    ("noun\\|adjective\\|det\\|verb\\|adverb\\|abbreviation\\|preposition\\|suffix\\|prefix\\|conjunction\\|symb" . font-lock-type-face)
    ;; Serial number
    ("^[0-9]+" . font-lock-builtin-face)
    ;; Dictionary comment
    ("DERIVATIVES\\|ORIGIN\\|PHRASES" . font-lock-comment-face))
  "Keywords to highlight in `osx-dictionary-mode'.")

(defvar osx-dictionary-mode-map
  (let ((map (make-sparse-keymap)))
    ;; Dictionary command
    (define-key map "q" 'osx-dictionary-quit)
    (define-key map "i" 'osx-dictionary-search-input)
    (define-key map "o" 'osx-dictionary-open-dictionary-app)
    (define-key map "y" 'osx-dictionary-open-youdao)
    (define-key map "c" 'osx-dictionary-open-cambridge)
    ;; Isearch
    (define-key map "S" 'isearch-forward-regexp)
    (define-key map "R" 'isearch-backward-regexp)
    (define-key map "s" 'isearch-forward)
    (define-key map "r" 'isearch-backward)
    ;; Misc.
    (define-key map "DEL" 'scroll-down)
    (define-key map " " 'scroll-up)
    (define-key map "l" 'forward-char)
    (define-key map "h" 'backward-char)
    (define-key map "?" 'describe-mode)
    map)
  "Keymap for `osx-dictionary-mode'.")

(defvar osx-dictionary-previous-window-configuration nil
  "Window configuration before switching to dictionary buffer.")

(defvar osx-dictionary-search-log-file nil
  "The file to which search log should be appended. If nil no logging is done.")

(defvar osx-dictionary-dictionary-choice nil
  "The specific dictionary that should be searched. If nil automatic dictionary is used.")

(define-derived-mode osx-dictionary-mode fundamental-mode "osx-dictionary"
  "Major mode to look up word through dictionary.
\\{dictionary-mode-map}.
Turning on Text mode runs the normal hook `osx-dictionary-mode-hook'."

  (setq header-line-format osx-dictionary-mode-header-line)
  (setq font-lock-defaults '(osx-dictionary-mode-font-lock-Keywords))
  (setq buffer-read-only t))

(defun osx-dictionary-open-dictionary-app ()
  "Open current searched `word' in Dictionary.app."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (shell-command (format "open dict://%s" (thing-at-point 'word t) ))))

(defun osx-dictionary-open-youdao ()
  "Open current searched `word' in http://dict.youdao.com."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (shell-command (format "open http://dict.youdao.com/search\\?q=%s"
                           (thing-at-point 'word t)))))

(defun osx-dictionary-open-cambridge ()
  "Open current searched `word' in http://dictionary.cambridge.org/dictionary/american-english/."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (shell-command
     (format "open http://dictionary.cambridge.org/dictionary/american-english/%s"
             (thing-at-point 'word t)))))

(defun osx-dictionary-quit ()
  "Quit osx-dictionary: reselect previously selected buffer."
  (interactive)
  (if (window-configuration-p osx-dictionary-previous-window-configuration)
      (progn
        (set-window-configuration osx-dictionary-previous-window-configuration)
        (setq osx-dictionary-previous-window-configuration nil)
        (bury-buffer (osx-dictionary--get-buffer)))
    (bury-buffer)))

(defun osx-dictionary--get-buffer ()
  "Get the osx-dictionary buffer.  Create one if there's none."
  (let ((buffer (get-buffer-create osx-dictionary-buffer-name)))
    (with-current-buffer buffer
      (unless (eq major-mode 'osx-dictionary-mode)
        (osx-dictionary-mode)))
    buffer))

(defun osx-dictionary--goto-dictionary ()
  "Switch to osx-dictionary buffer in other window."
  (setq osx-dictionary-previous-window-configuration
        (current-window-configuration))
  (let* ((buffer (osx-dictionary--get-buffer))
         (window (get-buffer-window buffer)))
    (if (null window)
        (switch-to-buffer-other-window buffer)
      (select-window window))))

(defun osx-dictionary--search (word)
  "Search WORD."
  (if (symbol-value 'osx-dictionary-search-log-file)
      (append-to-file
       (concat word "\n") nil
       (symbol-value 'osx-dictionary-search-log-file)))
  (let ((search-string
         (concat
          (osx-dictionary-cli-find-or-recompile)
          " lookup "
          (or (symbol-value 'osx-dictionary-dictionary-choice) "")
          " "
          (shell-quote-argument word))))
    (progn
      (message word)
      (message search-string)
      (shell-command-to-string search-string))))

(defun osx-dictionary--list-dictionaries (word)
  "List the installed dictionaries."
  (shell-command-to-string
   (concat
    (osx-dictionary-cli-find-or-recompile) " dicts")))

(defun osx-dictionary-recompile ()
  "Create or replace the `osx-dictionary-cli' executable using the latest code."
  (interactive)
  (let ((default-directory osx-dictionary--load-dir))
    (shell-command (concat "clang -O3 -framework CoreServices -framework Foundation osx-dictionary.m -o "
                           (shell-quote-argument osx-dictionary-cli)))
    (expand-file-name osx-dictionary-cli)))

(defun osx-dictionary-cli-find-or-recompile ()
  (or
   (executable-find (expand-file-name osx-dictionary-cli osx-dictionary--load-dir))
   (executable-find osx-dictionary-cli)
   (osx-dictionary-recompile)))

;;;###autoload
(defun osx-dictionary-search-input ()
  "Search input word and display result with buffer."
  (interactive)
  (let ((word (osx-dictionary--prompt-input)))
    (if word
        (with-current-buffer (get-buffer-create osx-dictionary-buffer-name)
          (setq buffer-read-only nil)
          (erase-buffer)
          (let ((progress-reporter
                 (make-progress-reporter (format "Searching (%s)..." word)
                                         nil nil)))
            (insert (osx-dictionary--search word))
            (progress-reporter-done progress-reporter))
          (osx-dictionary--goto-dictionary)
          (goto-char (point-min))
          (setq buffer-read-only t))
      (message "Nothing to look up"))))

;;;###autoload
(defun osx-dictionary-search-pointer ()
  "Search word around and display result with buffer."
  (interactive)
  (let ((word (osx-dictionary--region-or-word)))
    (if word
        (with-current-buffer (get-buffer-create osx-dictionary-buffer-name)
          (setq buffer-read-only nil)
          (erase-buffer)
          (let ((progress-reporter
                 (make-progress-reporter (format "Searching (%s)..." word)
                                         nil nil)))
            (message word)
            (insert (osx-dictionary--search word))
            (progress-reporter-done progress-reporter))
          (osx-dictionary--goto-dictionary)
          (goto-char (point-min))
          (setq buffer-read-only t))
      (message "Nothing to look up"))))

(defun osx-dictionary--prompt-input ()
  "Prompt input object for translate."
  (read-string (format "Word (%s): " (or (osx-dictionary--region-or-word) ""))
               nil nil
               (osx-dictionary--region-or-word)))

(defun osx-dictionary--region-or-word ()
  "Return region or word around point.
If `mark-active' on, return region string.
Otherwise return word around point."
  (if mark-active
      (buffer-substring-no-properties (region-beginning)
                                      (region-end))
    (if osx-dictionary-use-chinese-text-segmentation
        (thing-at-point 'chinese-or-other-word t)
      (thing-at-point 'word t))))

(provide 'osx-dictionary)
;;; osx-dictionary.el ends here
