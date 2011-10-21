;;; init.el --- Where all the magic begins

(if (featurep 'aquamacs)
    (load "~/.emacs.d/init-aquamacs")

  (load "~/.emacs.d/load-path")

 ;; ;; This file loads Org-mode and then loads the rest of our Emacs
 ;; ;; initialization from Emacs lisp embedded in literate Org-mode files.
 ;;
 ;; (require 'org)
 ;; (require 'ob-tangle)
 ;;
 ;; ;; load up all literate org-mode files in this directory
 ;; (mapc #'org-babel-load-file
 ;;       (directory-files user-emacs-directory t "\\.org$"))

 (load "~/.emacs.d/emacs"))

;;; init.el ends here