;;; ydcv.el --- Interface for ydcv

;; Filename: ydcv.el
;; Description: Interface for ydcv (YouDao console version).
;; Author: Linjun Zheng <zhenglj89@gmail.com>
;; Maintainer: Linjun Zheng <zhenglj89@gmail.com>
;; Copyright (C) 2015, Linjun Zheng, all rights reserved.
;; Created: 2015-06-19
;; Version: 1.0
;; Keywords: startdict, ydcv
;;
;; Features that might be required by this library:
;;
;; `outline' `cl'
;;

;;; This file is NOT part of GNU Emacs

;;; License
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.

;;; Commentary:
;;
;; Interface for ydcv.py (YouDao console version).
;;
;; Translate word by ydcv (console version of Stardict), and display
;; translation use showtip or buffer.
;;
;; Below are commands you can use:
;;
;; `ydcv-search-pointer'
;; Search around word and display with buffer.
;; `ydcv-search-pointer+'
;; Search around word and display with `showtip'.
;; `ydcv-search-input'
;; Search input word and display with buffer.
;; `ydcv-search-input+'
;; Search input word and display with `showtip'.
;;
;; Tips:
;;
;; If current mark is active, ydcv commands will translate
;; region string, otherwise translate word around point.
;;

;;; Installation:
;;
;; To use this extension, you have to install Stardict and ydcv
;; If you use Debian, it's simply, just:
;;
;;      sudo aptitude install stardict ydcv -y
;;
;; And make sure have install `popup.el',
;; this extension depend it.
;; You can install get it from:
;; http://www.emacswiki.org/cgi-bin/emacs/popup.el
;;
;; Put ydcv.el to your load-path.
;; The load-path is usually ~/elisp/.
;; It's set in your ~/.emacs like this:
;; (add-to-list 'load-path (expand-file-name "~/elisp"))
;;
;; And the following to your ~/.emacs startup file.
;;
;; (require 'ydcv)
;;

;;; Customize:
;;
;; `ydcv-buffer-name'
;; The name of ydcv buffer.
;;
;; `ydcv-dictionary-simple-list'
;; The dictionary list for simple describe.
;;
;; `ydcv-dictionary-complete-list'
;; The dictionary list for complete describe.
;;
;; All of the above can customize by:
;;      M-x customize-group RET ydcv RET
;;

;;; Change log:
;;
;; 2009/04/04
;;      * Fix the bug of `ydcv-search-pointer'.
;;      * Fix doc.
;;        Thanks "Santiago Mejia" report those problems.
;;
;; 2009/04/02
;;      * Remove unnecessary information from transform result.
;;
;; 2009/03/04
;;      * Refactory code.
;;      * Search region or word around point.
;;      * Fix doc.
;;
;; 2009/02/05
;;      * Fix doc.
;;
;; 2008/06/01
;;      * First released.
;;

;;; Acknowledgements:
;;
;;      pluskid@gmail.com   (Zhang ChiYuan)     for ydcv-mode.el
;;

;;; TODO
;;
;;
;;

;;; Require
(require 'outline)
(eval-when-compile
  (require 'cl))
(require 'popup)

;;; Code:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Customize ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defgroup ydcv nil
  "Interface for ydcv (StartDict console version)."
  :group 'edit)

(defcustom ydcv-buffer-name "*YDCV*"
  "The name of the buffer of ydcv."
  :type 'string
  :group 'ydcv)

(defcustom ydcv-py-directory ""
  "The name of the buffer of ydcv."
  :type 'string
  :group 'ydcv)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Variable ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defvar ydcv-previous-window-configuration nil
  "Window configuration before switching to ydcv buffer.")

(defvar ydcv-current-translate-object nil
  "The search object.")

(defvar ydcv-filter-string "^对不起，没有发现和.*\n"
  "The filter string that ydcv output.")

(defvar ydcv-fail-notify-string "没有发现解释\n用更多的词典查询试试"
  "This string is for notify user when search fail.")

(defvar ydcv-mode-font-lock-keywords    ;keyword for buffer display
  '(
    ;; Dictionary name
    ("^-->\\(.*\\)\n-" . (1 font-lock-type-face))
    ;; Search word
    ("^-->\\(.*\\)[ \t\n]*" . (1 font-lock-function-name-face))
    ;; Serial number
    ("\\(^[0-9] \\|[0-9]+:\\|[0-9]+\\.\\)" . (1 font-lock-constant-face))
    ;; Type name
    ("^<<\\([^>]*\\)>>$" . (1 font-lock-comment-face))
    ;; Phonetic symbol
    ("^\\/\\([^>]*\\)\\/$" . (1 font-lock-string-face))
    ("^\\[\\([^]]*\\)\\]$" . (1 font-lock-string-face))
    )
  "Expressions to highlight in `ydcv-mode'.")

(defvar ydcv-mode-map                   ;key map
  (let ((map (make-sparse-keymap)))
    ;; Ydcv command.
    (define-key map "q" 'ydcv-quit)
    (define-key map "j" 'ydcv-next-line)
    (define-key map "k" 'ydcv-prev-line)
    (define-key map "J" 'ydcv-scroll-up-one-line)
    (define-key map "K" 'ydcv-scroll-down-one-line)
    (define-key map "d" 'ydcv-next-dictionary)
    (define-key map "f" 'ydcv-previous-dictionary)
    (define-key map "i" 'ydcv-search-input)
    (define-key map ";" 'ydcv-search-input+)
    (define-key map "p" 'ydcv-search-pointer)
    (define-key map "y" 'ydcv-search-pointer+)
    ;; Isearch.
    (define-key map "S" 'isearch-forward-regexp)
    (define-key map "R" 'isearch-backward-regexp)
    (define-key map "s" 'isearch-forward)
    (define-key map "r" 'isearch-backward)
    ;; Hideshow.
    (define-key map "a" 'show-all)
    (define-key map "A" 'hide-body)
    (define-key map "v" 'show-entry)
    (define-key map "V" 'hide-entry)
    ;; Misc.
    (define-key map "e" 'scroll-down)
    (define-key map " " 'scroll-up)
    (define-key map "l" 'forward-char)
    (define-key map "h" 'backward-char)
    (define-key map "?" 'describe-mode)
    map)
  "Keymap for `ydcv-mode'.")

(define-derived-mode ydcv-mode nil "ydcv"
  "Major mode to look up word through ydcv.
\\{ydcv-mode-map}
Turning on Text mode runs the normal hook `ydcv-mode-hook'."
  (setq font-lock-defaults '(ydcv-mode-font-lock-keywords))
  (setq buffer-read-only t)
  (set (make-local-variable 'outline-regexp) "^-->.*\n-->"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Interactive Functions ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun ydcv-search-pointer (&optional word)
  "Get current WORD.
And display complete translations in other buffer."
  (interactive)
  ;; Display details translate result.
  (ydcv-search-detail (or word (ydcv-region-or-word))))

(defun ydcv-search-pointer+ ()
  "Translate current point word.
And show information use tooltip.
But this function use a simple dictionary list."
  (interactive)
  ;; Display simple translate result.
  (ydcv-search-simple))

(defun ydcv-search-input (&optional word)
  "Translate current input WORD.
And show information in other buffer."
  (interactive)
  ;; Display details translate result.
  (ydcv-search-detail (or word (ydcv-prompt-input))))

(defun ydcv-search-input+ (&optional word)
  "Translate current point WORD.
And show information use tooltip."
  (interactive)
  ;; Display simple translate result.
  (ydcvp-search-simple (or word (ydcv-prompt-input)))
  ;; I set this delay for fast finger.
  (sit-for 0.5))

(defun ydcv-quit ()
  "Bury ydcv buffer and restore the previous window configuration."
  (interactive)
  (if (window-configuration-p ydcv-previous-window-configuration)
      (progn
        (set-window-configuration ydcv-previous-window-configuration)
        (setq ydcv-previous-window-configuration nil)
        (bury-buffer (ydcv-get-buffer)))
    (bury-buffer)))

(defun ydcv-next-dictionary ()
  "Jump to next dictionary."
  (interactive)
  (show-all)
  (if (search-forward-regexp "^-->.*\n-" nil t) ;don't show error when search failed
      (progn
        (call-interactively 'previous-line)
        (recenter 0))
    (message "Have reach last dictionary.")))

(defun ydcv-previous-dictionary ()
  "Jump to previous dictionary."
  (interactive)
  (show-all)
  (if (search-backward-regexp "^-->.*\n-" nil t) ;don't show error when search failed
      (progn
        (forward-char 1)
        (recenter 0))                   ;adjust position
    (message "Have reach first dictionary.")))

(defun ydcv-scroll-up-one-line ()
  "Scroll up one line."
  (interactive)
  (scroll-up 1))

(defun ydcv-scroll-down-one-line ()
  "Scroll down one line."
  (interactive)
  (scroll-down 1))

(defun ydcv-next-line (arg)
  "Next ARG line and show item."
  (interactive "P")
  (ignore-errors
    (call-interactively 'next-line arg)
    (save-excursion
      (beginning-of-line nil)
      (when (looking-at outline-regexp)
        (show-entry)))))

(defun ydcv-prev-line (arg)
  "Previous ARG line."
  (interactive "P")
  (ignore-errors
    (call-interactively 'previous-line arg)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Utilities Functions ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun ydcv-search-detail (&optional word)
  "Search WORD through the `command-line' tool ydcv.
The result will be displayed in buffer named with
`ydcv-buffer-name' with `ydcv-mode'."
  (message "Search...")
  (with-current-buffer (get-buffer-create ydcv-buffer-name)
    (setq buffer-read-only nil)
    (erase-buffer)
    (let* ((process
            ;; (start-process
            ;;  "ydcv" ydcv-buffer-name "ydcv"
            ;;  (ydcv-search-with-dictionary word ydcv-dictionary-complete-list))
            (apply 'start-process
                   (append `("ydcv" ,ydcv-buffer-name)
                           ;; (list (format "/usr/bin/python %sydcv.py" default-directory))
                           (list (format "%sydcv.py" default-directory))
                           (ydcv-search-args word ydcv-dictionary-complete-list))
                   )))
      (set-process-sentinel
       process
       (lambda (process signal)
         (when (memq (process-status process) '(exit signal))
           (unless (eq (current-buffer) (ydcv-get-buffer))
             (ydcv-goto-ydcv))
           (ydcv-mode-reinit)))))))

(defun ydcv-search-args (word dict-list)
  (append (apply 'append (mapcar (lambda (d) `("-u" ,d)) dict-list))
          (list "-n" word)))

(defun ydcv-search-simple (&optional word)
  "Search WORD simple translate result."
  (popup-tip
   (ydcv-search-with-dictionary word ydcv-dictionary-simple-list)))

(defun ydcv-search-with-dictionary (word dictionary-list)
  "Search some WORD with dictionary list.
Argument DICTIONARY-LIST the word that need transform."
  ;; Get translate object.
  (or word (setq word (ydcv-region-or-word)))
  ;; Record current translate object.
  (setq ydcv-current-translate-object word)

  (mapconcat (lambda (dict)
               (concat "-u \"" dict "\""))
             dictionary-list " ")
  ;; Return translate result.
  (let (cmd)
    (ydcv-filter
     (mapconcat
      (lambda (dict)
        ;; (setq cmd (format "python %sydcv.py -n -u \"%s\" \"%s\"" default-directory dict word))
        (setq cmd (format "%sydcv.py -u \"%s\" \"%s\"" default-directory dict word))
	(shell-command-to-string cmd))
      dictionary-list "\n")
     )))

(defun ydcv-filter (ydcv-string)
  "This function is for filter ydcv output string,.
Argument YDCV-STRING the search string from ydcv."
  (setq ydcv-string (replace-regexp-in-string ydcv-filter-string "" ydcv-string))
  (if (equal ydcv-string "")
      ydcv-fail-notify-string
    (with-temp-buffer
      (insert ydcv-string)
      (goto-char (point-min))
      ;; (kill-line 1)                     ;remove unnecessary information.
      (buffer-string))))

(defun ydcv-goto-ydcv ()
  "Switch to ydcv buffer in other window."
  (setq ydcv-previous-window-configuration (current-window-configuration))
  (let* ((buffer (ydcv-get-buffer))
         (window (get-buffer-window buffer)))
    (if (null window)
        (switch-to-buffer-other-window buffer)
      (select-window window))))

(defun ydcv-get-buffer ()
  "Get the ydcv buffer.  Create one if there's none."
  (let ((buffer (get-buffer-create ydcv-buffer-name)))
    (with-current-buffer buffer
      (unless (eq major-mode 'ydcv-mode)
        (ydcv-mode)))
    buffer))

(defun ydcv-mode-reinit ()
  "Re-initialize buffer.
Hide all entry but the first one and goto
the beginning of the buffer."
  (ignore-errors
    (setq buffer-read-only t)
    (goto-char (point-min))
    (ydcv-next-dictionary)
    (show-all)
    (message "Have search finished with `%s'." ydcv-current-translate-object)))

(defun ydcv-prompt-input ()
  "Prompt input object for translate."
  (read-string (format "Word (%s): " (or (ydcv-region-or-word) ""))
               nil nil
               (ydcv-region-or-word)))

(defun ydcv-region-or-word ()
  "Return region or word around point.
If `mark-active' on, return region string.
Otherwise return word around point."
  (if mark-active
      (buffer-substring-no-properties (region-beginning)
                                      (region-end))
    (thing-at-point 'word)))


;; -------------------------------------------------
;; self define
;; -------------------------------------------------

(defun ydcv-search-word (word dictionary-list)
  "Search some WORD with dictionary list.
Argument DICTIONARY-LIST the word that need transform."
  ;; Get translate object.
  (or word (setq word (ydcv-region-or-word)))
  ;; Record current translate object.
  (setq ydcv-current-translate-object word)

  (with-current-buffer (get-buffer-create ydcv-buffer-name)
    (switch-to-buffer-other-window ydcv-buffer-name)
    (setq buffer-read-only nil)
    (erase-buffer)

    ;; Return translate result.
    (let (cmd)
      (insert
       (ydcv-filter
        (mapconcat
         (lambda (dict)
           (setq cmd (format "%sydcv.py -u \"%s\" \"%s\"" ydcv-el-directory dict word))
           (shell-command-to-string cmd))
         dictionary-list "\n"))))
    (unless (eq (current-buffer) (ydcv-get-buffer))
      (ydcv-goto-ydcv))
    (ydcv-mode-reinit)
    (other-window 1)
    ))


(defun ydcv-search-input (&optional word)
  "Translate current input WORD.
And show information in other buffer."
  (interactive)
  ;; Display details translate result.
  (ydcv-search-word (or word (ydcv-prompt-input)) ydcv-dictionary-simple-list))

;; (setq ydcv-dictionary-complete-list '(""))
;; (ydcv-search-word "cat" ydcv-dictionary-simple-list)
;; ;; TODO
;; (ydcv-search-input "hello")
;; (ydcv-search-detail "hello")



(provide 'ydcv)

;;; ydcv.el ends here
