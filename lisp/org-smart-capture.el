;;; org-smart-capture --- Capture Gnus messages as tasks, with context

;; Copyright (C) 2011 John Wiegley

;; Author: John Wiegley <jwiegley@gmail.com>
;; Created: 16 Sep 2011
;; Version: 1.0
;; Keywords: gnus message org capture task todo context
;; X-URL: https://github.com/jwiegley/dot-emacs

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 2, or (at
;; your option) any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;; I use: (define-key global-map [(meta ?m)] 'org-smart-capture)

(require 'gnus-sum)

(defgroup org-smart-capture nil
  "Capture Gnus messages as tasks, with context"
  :group 'org)

(defcustom org-smart-capture-use-lastname nil
  "If non-nil, include last names in smart captures."
  :type 'boolean
  :group 'org-smart-capture)

(defvar org-subject-transforms
  '(("\\`\\(Re\\|Fwd\\): "                          . "")
    ("\\`{ledger} "                                 . "")
    ("(#[0-9]+)\\'"                                 . "")
    ("\\`\\[Bug \\([0-9]+\\)\\] New:"               . "[[bug:\\1][#\\1]]")
    ("\\`\\[.*? - [A-Za-z]+ #\\([0-9]+\\)\\] (New)" . "[[redmine:\\1][#\\1]]")))

(defun convert-dates ()
  (interactive)
  (while (re-search-forward ":Date:\\s-*\\(.+\\)" nil t)
    (let ((date-sent (match-string 1)))
      (goto-char (match-beginning 1))
      (delete-region (match-beginning 1) (match-end 1))
      (insert ?\[ (time-to-org-timestamp
                   (apply 'encode-time
                          (parse-time-string date-sent)) t t)
              ?\]))))

(defun org-smart-capture-article (&optional article)
  (let* ((article (or article (gnus-summary-article-number)))
         (data (gnus-data-find-list article))
         (ghead (gnus-data-header (car data)))
         (message-id (mail-header-message-id ghead))
         (raw-subject (mail-header-subject ghead))
         (subject (and raw-subject (rfc2047-decode-string raw-subject)))
         (date-sent (mail-header-date ghead))
         (from (mail-header-from ghead))
         (from (if from (rfc2047-decode-string from) "unknown"))
         (name (car (ignore-errors
                      (mail-extract-address-components from))))
         fname lname)

    (when (stringp name)
      ;; Guess first name and last name:
      (cond ((string-match
              "\\`\\(\\w\\|[-.]\\)+ \\(\\w\\|[-.]\\)+\\'" name)
             (setq fname (nth 0 (split-string name "[ \t]+"))
                   lname (nth 1 (split-string name "[ \t]+"))))
            ((string-match
              "\\`\\(\\w\\|[-.]\\)+, \\(\\w\\|[-.]\\)+\\'" name)
             (setq fname (nth 1 (split-string name "[ \t,]+"))
                   lname (nth 0 (split-string name "[ \t,]+"))))
            ((string-match "\\`\\(\\w\\|[-.]\\)+\\'" name)
             (setq fname name
                   lname ""))
            ((string-match "\\`\\(\\w+?\\) " name)
             (setq fname (match-string 1 name)
                   lname ""))))

    (org-capture nil "t")

    (when (stringp fname)
      (insert ?\( fname)
      (if (and org-smart-capture-use-lastname (stringp lname))
          (insert ?  lname))
      (insert ?\) ? ))

    (if subject
        (let ((new-subject subject))
          (dolist (transform org-subject-transforms)
            (setq new-subject
                  (replace-regexp-in-string (car transform)
                                            (cdr transform) new-subject)))
          (save-excursion
            (insert new-subject))))

    (let ((body (and (eq major-mode 'gnus-article-mode)
                     (region-active-p)
                     (buffer-substring-no-properties (region-beginning)
                                                     (region-end)))))
      (when body
        (flet ((trim-string (str)
                            (replace-regexp-in-string
                             "\\(\\`[[:space:]\n]*\\|[[:space:]\n]*\\'\\)" ""
                             str)))
          (save-excursion
            (forward-line 2)
            (dolist (line (split-string (trim-string body) "\n"))
              (insert "   " line ?\n))))))

    (org-set-property "Date"
                      (or date-sent
                          (time-to-org-timestamp
                           (apply 'encode-time
                                  (parse-time-string date-sent)) t t)))
    (org-set-property "Message"
                      (format "[[message://%s][%s]]"
                              (substring message-id 1 -1)
                              (subst-char-in-string
                               ?\[ ?\{ (subst-char-in-string
                                        ?\] ?\} subject))))
    (org-set-property "Author" from)

    (org-capture-finalize)
    (message "Captured: (%s) %s" fname subject)))

;;;###autoload
(defun org-smart-capture (&optional arg)
  (interactive "P")
  (if (not (memq major-mode '(gnus-summary-mode gnus-article-mode)))
      (org-capture nil "t")

    (cond ((eq major-mode 'gnus-article-mode)
           (org-smart-capture-article)
           (with-current-buffer gnus-summary-buffer
             (gnus-summary-mark-as-read
              nil (unless (string= (buffer-name) "*Summary INBOX*")
                    gnus-dormant-mark))))

          ((eq major-mode 'gnus-summary-mode)
           (save-excursion
             (dolist (article (gnus-summary-work-articles arg))
               (gnus-summary-remove-process-mark article)
               (gnus-summary-mark-as-read
                article (unless (string= (buffer-name gnus-summary-buffer)
                                         "*Summary INBOX*")
                          gnus-dormant-mark))
               (save-excursion
                 (org-smart-capture-article article))))
           (gnus-summary-position-point)
           (gnus-set-mode-line 'summary)))))

(provide 'org-smart-capture)

;;; org-smart-capture.el ends here