;;; files-standalone-buffer-test.el --- ERT tests for files-standalone-buffer  -*- lexical-binding: t; -*-

;;; Commentary:

;; Tests for the lightweight files.el buffer/write-region fallback.  Its
;; top-level symbols (`write-region', `point-min', ...) are only
;; `defun'-installed when `files--install-fallback-function-p' allows it,
;; which is unconditional on the standalone reader and a no-op under host
;; Emacs (where the real C builtins stay in place) -- see that predicate's
;; docstring.  So, like the sibling `emacs-buffer-builtins-test.el', these
;; tests call the always-defined helper functions directly
;; (`files--buffer-substring', `files--write-file-text', ...): under host
;; Emacs they transparently delegate to the real current buffer through
;; `files--host-buffer-available-p', so a plain `with-temp-buffer' exercises
;; the same code the standalone reader runs.

;;; Code:

(require 'ert)
(require 'files-standalone-buffer)

;;;; T107 -- START/END order-independence, markers, MUSTBENEW, VISIT

(ert-deftest files-standalone-buffer-test/buffer-substring-order-independent ()
  "Like real `write-region', the smaller of START/END is always the
start of the returned text, whichever argument position it came in."
  (with-temp-buffer
    (insert "0123456789")
    (should (equal (files--buffer-substring 3 7) "2345"))
    (should (equal (files--buffer-substring 7 3) "2345"))))

(ert-deftest files-standalone-buffer-test/buffer-substring-accepts-markers ()
  (with-temp-buffer
    (insert "0123456789")
    (let ((m1 (copy-marker 3))
          (m2 (copy-marker 7)))
      (should (equal (files--buffer-substring m1 m2) "2345"))
      (should (equal (files--buffer-substring m2 m1) "2345"))
      (should (equal (files--buffer-substring 3 m2) "2345")))))

(ert-deftest files-standalone-buffer-test/position-value-passes-integers-through ()
  (should (= (files--position-value 5) 5)))

(ert-deftest files-standalone-buffer-test/write-file-text-mustbenew-signals-when-exists ()
  (let ((path (make-temp-file "files-standalone-buffer-test-")))
    (unwind-protect
        (progn
          (files--write-file-text path "exists" nil nil nil nil)
          (should-error (files--write-file-text path "new" nil nil nil t)
                        :type 'file-already-exists))
      (ignore-errors (delete-file path)))))

(ert-deftest files-standalone-buffer-test/write-file-text-mustbenew-fresh-succeeds ()
  (let ((path (make-temp-file "files-standalone-buffer-test-")))
    (delete-file path)
    (unwind-protect
        (progn
          (files--write-file-text path "fresh" nil nil nil t)
          (should (file-exists-p path))
          (should (equal (with-temp-buffer
                           (insert-file-contents path)
                           (buffer-string))
                         "fresh")))
      (ignore-errors (delete-file path)))))

(ert-deftest files-standalone-buffer-test/write-file-text-visit-marks-buffer-unmodified ()
  (let ((path (make-temp-file "files-standalone-buffer-test-")))
    (unwind-protect
        (with-temp-buffer
          (insert "hi")
          (should (buffer-modified-p))
          (files--write-file-text path (buffer-string) nil t nil nil)
          (should-not (buffer-modified-p)))
      (ignore-errors (delete-file path)))))

(ert-deftest files-standalone-buffer-test/region-text-string-start-ignores-end ()
  (should (equal (files--region-text "literal" 99) "literal")))

(provide 'files-standalone-buffer-test)

;;; files-standalone-buffer-test.el ends here
