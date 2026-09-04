;;; emacs-load.el --- Standalone load/load-file override  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 zawatton + Claude

;; This file is part of nelisp-emacs.

;;; Commentary:

;; Provenance: copied from
;; /home/madblack-21/Cowork/Notes/dev/nelisp/lisp/nelisp-stdlib-misc.el
;; lines 495-580.  Keep this file in sync with that donor block.
;;
;; Local delta: keep the override standalone-only in this repository, and
;; preserve absolute-path `load' when `locate-library' does not resolve it.

;;; Code:

(when (or (fboundp 'rdf)
          (fboundp 'nelisp--eval-source-string)
          (not (boundp 'emacs-version))
          (not (stringp emacs-version)))
  (defvar load-garbage-collect-interval 64
    "Number of forms between opportunistic `garbage-collect' calls in `load'.
Nil or 0 disables the periodic collection.  The standalone reader uses a
flat arena, so large source files must not keep every already-read
top-level form reachable until the end of the load.")

  (defun nelisp--load-skip-space-and-comments (source pos)
    "Return first non-whitespace/comment position in SOURCE at or after POS."
    (let ((len (length source))
          (done nil))
      (while (and (< pos len) (not done))
        (let ((c (aref source pos)))
          (cond
           ((or (= c ?\s) (= c ?\t) (= c ?\n) (= c ?\r) (= c ?\f))
            (setq pos (+ pos 1)))
           ((= c ?\;)
            (while (and (< pos len) (not (= (aref source pos) ?\n)))
              (setq pos (+ pos 1))))
           (t
            (setq done t)))))
      pos))

  (defun nelisp--load-eval-source-incremental (source)
    "Read and eval SOURCE top-level forms one at a time.
Return the value of the last form.  This deliberately avoids
`nelisp--read-all-from-string', which materializes the whole AST and can
overflow the standalone arena on upstream-sized package files."
    (let ((pos 0)
          (len (length source))
          (last nil)
          (count 0))
      (while (progn
               (setq pos (nelisp--load-skip-space-and-comments source pos))
               (< pos len))
        (let ((res (read-from-string source pos)))
          (when (or (not (consp res)) (<= (cdr res) pos))
            (signal 'end-of-file (list "load reader made no progress" pos)))
          (setq last (eval (car res)))
          (setq pos (cdr res))
          (setq count (+ count 1))
          (when (and load-garbage-collect-interval
                     (> load-garbage-collect-interval 0)
                     (= (% count load-garbage-collect-interval) 0)
                     (fboundp 'garbage-collect))
            (garbage-collect))))
      last))

  ;; NOTE (2026-07-12): a retry-with-rewrite fallback (rewriting top-level
  ;; `defalias' to `nelisp--defalias-late' on load failure) was attempted
  ;; here and REVERTED: wrapping the fast loader in `condition-case'
  ;; mis-captures its internal non-local exits on this substrate (known
  ;; condition-case/throw defect), silently turning successful by-name
  ;; loads into zero-form no-ops.  Any future retry design must not wrap
  ;; `nelisp--eval-source-string' in a handler.
  (defvar nelisp--load-rewrite-wrapper-heads
    '(progn prog1 prog2 when unless if while eval-when-compile
      eval-and-compile with-no-warnings with-suppressed-warnings
      condition-case let let*)
    "Wrapper heads whose nested forms are eligible for load-time rewrites.")

  (defun nelisp--load-rewrite-defalias-form (nelisp--load-rw-form)
    "Rewrite top-level DEFALIAS forms in FORM for standalone load retry.
Only descend through `nelisp--load-rewrite-wrapper-heads'.  Quoted data
subtrees are left untouched."
    (if (consp nelisp--load-rw-form)
        (let ((nelisp--load-rw-head (car nelisp--load-rw-form)))
          (cond
           ((memq nelisp--load-rw-head '(quote function))
            nelisp--load-rw-form)
           ((eq nelisp--load-rw-head 'defalias)
            (setcar nelisp--load-rw-form 'nelisp--defalias-late)
            nelisp--load-rw-form)
           ((memq nelisp--load-rw-head nelisp--load-rewrite-wrapper-heads)
            (let ((nelisp--load-rw-tail (cdr nelisp--load-rw-form))
                  (nelisp--load-rw-node nil))
              (while (consp nelisp--load-rw-tail)
                (setq nelisp--load-rw-node (car nelisp--load-rw-tail))
                (when (consp nelisp--load-rw-node)
                  (setcar nelisp--load-rw-tail
                          (nelisp--load-rewrite-defalias-form
                           nelisp--load-rw-node)))
                (setq nelisp--load-rw-tail (cdr nelisp--load-rw-tail))))
            nelisp--load-rw-form)
           (t nelisp--load-rw-form)))
      nelisp--load-rw-form))

  (defun nelisp--load-eval-source-rewriting (source)
    "Retry loader for SOURCE with top-level `defalias' rewritten late.
This interpreted fallback is intentionally slow and is a future native
optimization candidate; keep the normal load path on the fast reader."
    (let ((nelisp--load-rw-pos 0)
          (nelisp--load-rw-len (length source))
          (nelisp--load-rw-last nil)
          (nelisp--load-rw-count 0)
          (nelisp--load-rw-read nil))
      (while (progn
               (setq nelisp--load-rw-pos
                     (nelisp--load-skip-space-and-comments
                      source nelisp--load-rw-pos))
               (< nelisp--load-rw-pos nelisp--load-rw-len))
        (setq nelisp--load-rw-read
              (read-from-string source nelisp--load-rw-pos))
        (when (or (not (consp nelisp--load-rw-read))
                  (<= (cdr nelisp--load-rw-read) nelisp--load-rw-pos))
            (signal 'end-of-file
                    (list "rewrite load reader made no progress"
                          nelisp--load-rw-pos)))
        (setq nelisp--load-rw-last
              (eval
               (nelisp--load-rewrite-defalias-form
                (car nelisp--load-rw-read))))
        (setq nelisp--load-rw-pos (cdr nelisp--load-rw-read))
        (setq nelisp--load-rw-count (+ nelisp--load-rw-count 1))
        (when (and load-garbage-collect-interval
                   (> load-garbage-collect-interval 0)
                   (= (% nelisp--load-rw-count
                         load-garbage-collect-interval)
                      0)
                   (fboundp 'garbage-collect))
          (garbage-collect)))
      nelisp--load-rw-last))

  (defun emacs-load--regular-file-p (resolved)
    "Return non-nil when RESOLVED names an existing non-directory file."
    (if (fboundp 'nelisp--syscall-stat)
        (eq (nelisp--syscall-stat resolved) 'file)
      (and (file-exists-p resolved)
           (not (file-directory-p resolved)))))

  (defun nelisp--load-resolved-file (resolved noerror)
    "Load exact absolute RESOLVED path, honoring NOERROR for open failures."
    (cond
     ((not (emacs-load--regular-file-p resolved))
      (if noerror nil
        (signal 'file-error (list "Cannot open load file" resolved))))
     (t
      (let ((source (nelisp--syscall-read-file resolved)))
        (cond
         ((null source)
          (if noerror nil
            (signal 'file-error (list "read error" resolved))))
         (t
          (let* ((parent (or (file-name-directory resolved) "./"))
                 (prior-lfn (and (boundp 'load-file-name) load-file-name))
                 (prior-dd (and (boundp 'default-directory) default-directory))
                 (loader (if (fboundp 'nelisp--eval-source-string)
                             #'nelisp--eval-source-string
                           #'nelisp--load-eval-source-incremental)))
            (setq load-file-name resolved)
            (setq default-directory parent)
            (unwind-protect
                (progn
                  (funcall loader source)
                  t)
              (setq load-file-name prior-lfn)
              (setq default-directory prior-dd)))))))))

  (defun load (file &optional noerror _nomessage _nosuffix _must-suffix)
    "Resolve FILE through `load-path' and execute it."
    (let* ((absolute-p
            (and (stringp file)
                 (> (length file) 0)
                 (or (and (fboundp 'file-name-absolute-p)
                          (file-name-absolute-p file))
                     (= (aref file 0) ?/))))
           (resolved (locate-library file)))
      (cond
       (resolved
        (nelisp--load-resolved-file resolved noerror))
       (absolute-p
        (nelisp--load-resolved-file (expand-file-name file) noerror))
       (noerror nil)
       (t
        (signal 'file-error (list "Cannot open load file" file))))))

  (defun load-file (file)
    "Execute exactly FILE after absolute-name expansion.
Unlike `load', this never searches `load-path' or adds a suffix."
    (let ((resolved (expand-file-name file)))
      (nelisp--load-resolved-file resolved nil))))

(provide 'emacs-load)

;;; emacs-load.el ends here
