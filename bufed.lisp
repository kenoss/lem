;; -*- Mode: LISP; Package: LEM -*-

(in-package :lem)

(export '(bolp
          eolp
          bobp
          eobp
          insert-char
          insert-lines
          insert-string
          insert-newline
          delete-char
          set-charpos
          beginning-of-buffer
          end-of-buffer
          beginning-of-line
          end-of-line
          goto-line
          goto-position
          forward-line
          next-char
          prev-char
          mark-set
          exchange-point-mark
          following-char
          preceding-char
          char-after
          char-before
          replace-char
          blank-line-p
          erase-buffer
          delete-while-whitespaces
          skip-chars-forward
          skip-chars-backward
          back-to-indentation))

(defun head-line-p ()
  (<= (current-linum) 1))

(defun tail-line-p ()
  (<= (buffer-nlines (current-buffer))
      (current-linum)))

(defun bolp ()
  (zerop (current-charpos)))

(defun eolp ()
  (= (current-charpos)
     (buffer-line-length
      (current-buffer)
      (current-linum))))

(defun bobp ()
  (and (head-line-p) (bolp)))

(defun eobp ()
  (and (tail-line-p) (eolp)))

(defun insert-char (c n)
  (dotimes (_ n t)
    (when (buffer-insert-char
           (current-buffer)
           (current-linum)
           (current-charpos)
           c)
      (next-char 1))))

(defun insert-lines (lines)
  (do ((rest lines (cdr rest)))
      ((null rest))
    (buffer-insert-line
     (current-buffer)
     (current-linum)
     (current-charpos)
     (car rest))
    (next-char (length (car rest)))
    (when (cdr rest)
      (insert-newline 1))))

(defun insert-string (str)
  (insert-lines (split-string str #\newline)))

(defun insert-newline (&optional (n 1))
  (dotimes (_ n)
    (buffer-insert-newline (current-buffer)
                           (current-linum)
                           (current-charpos)))
  (forward-line n))

(defun delete-char (n &optional killp)
  (when (minusp n)
    (setf n (- n))
    (unless (prev-char n)
      (return-from delete-char nil)))
  (if (eobp)
      nil
      (let ((lines
              (buffer-delete-char (current-buffer)
                                  (current-linum)
                                  (current-charpos)
                                  n)))
        (when killp
          (with-kill ()
            (kill-push lines)))
        t)))

(defun set-charpos (pos)
  (assert (<= 0
              pos
              (buffer-line-length (current-buffer) (current-linum))))
  (setf (current-charpos) pos))

(defun beginning-of-buffer ()
  (point-set (point-min)))

(defun end-of-buffer ()
  (point-set (point-max)))

(defun beginning-of-line ()
  (set-charpos 0)
  t)

(defun end-of-line ()
  (set-charpos (buffer-line-length
                (current-buffer)
                (current-linum)))
  t)

(define-key *global-keymap* (kbd "M-g") 'goto-line)
(define-command goto-line (n) ("nLine to GOTO: ")
  (setf n
        (if (< n 1)
            1
            (min n (buffer-nlines (current-buffer)))))
  (setf (current-linum) n)
  (beginning-of-line)
  t)

(defun goto-position (position)
  (check-type position (integer 1 *))
  (beginning-of-buffer)
  (shift-position position))

(defun forward-line (&optional (n 1))
  (beginning-of-line)
  (if (plusp n)
      (dotimes (_ n t)
        (when (tail-line-p)
          (end-of-line)
          (return))
        (incf (current-linum)))
      (dotimes (_ (- n) t)
        (when (head-line-p)
          (return))
        (decf (current-linum)))))

(defun shift-position (n)
  (cond ((< 0 n)
         (loop
           (when (< n 0)
             (return nil))
           (let* ((length (1+ (buffer-line-length (current-buffer) (current-linum))))
                  (w (- length (current-charpos))))
             (when (< n w)
               (set-charpos (+ n (current-charpos)))
               (return t))
             (decf n w)
             (unless (forward-line 1)
               (return nil)))))
        (t
         (setf n (- n))
         (loop
           (when (< n 0)
             (return nil))
           (when (<= n (current-charpos))
             (set-charpos (- (current-charpos) n))
             (return t))
           (decf n (1+ (current-charpos)))
           (cond ((head-line-p)
                  (beginning-of-line)
                  (return nil))
                 (t
                  (forward-line -1)
                  (end-of-line)))))))

(define-key *global-keymap* (kbd "C-f") 'next-char)
(define-key *global-keymap* (kbd "[right]") 'next-char)
(define-command next-char (&optional (n 1)) ("p")
  (shift-position n))

(define-key *global-keymap* (kbd "C-b") 'prev-char)
(define-key *global-keymap* (kbd "[left]") 'prev-char)
(define-command prev-char (&optional (n 1)) ("p")
  (shift-position (- n)))

(define-key *global-keymap* (kbd "C-@") 'mark-set)
(define-command mark-set () ()
  (let ((buffer (current-buffer)))
    (setf (buffer-mark-p buffer) t)
    (if (buffer-mark-marker)
        (setf (marker-point (buffer-mark-marker buffer))
              (current-point))
        (setf (buffer-mark-marker buffer)
              (make-marker-current-point)))
    (minibuf-print "Mark set")
    t))

(define-key *global-keymap* (kbd "C-x C-x") 'exchange-point-mark)
(define-command exchange-point-mark () ()
  (let ((buffer (current-buffer)))
    (buffer-check-marked buffer)
    (psetf
     (current-linum) (marker-linum (buffer-mark-marker buffer))
     (current-charpos) (marker-charpos (buffer-mark-marker buffer))
     (marker-linum (buffer-mark-marker buffer)) (current-linum)
     (marker-charpos (buffer-mark-marker buffer)) (current-charpos))
    (assert (<= 0 (current-charpos)))
    t))

(defun following-char ()
  (buffer-get-char (current-buffer)
                   (current-linum)
                   (current-charpos)))

(defun preceding-char ()
  (cond
    ((bobp)
     nil)
    ((bolp)
     (buffer-get-char (current-buffer)
                      (1- (current-linum))
                      (buffer-line-length (current-buffer)
                                          (1- (current-linum)))))
    (t
     (buffer-get-char (current-buffer)
                      (current-linum)
                      (1- (current-charpos))))))

(defun char-after (&optional (n 0))
  (if (zerop n)
      (following-char)
      (let ((point (current-point)))
        (if (next-char n)
            (prog1 (following-char)
              (prev-char n))
            (progn
              (point-set point)
              nil)))))

(defun char-before (&optional (n 1))
  (if (= n 1)
      (preceding-char)
      (let ((point (current-point)))
        (if (prev-char (1- n))
            (prog1 (preceding-char)
              (next-char (1- n)))
            (progn
              (point-set point)
              nil)))))

(defun replace-char (c)
  (delete-char 1 nil)
  (buffer-insert-char
   (current-buffer)
   (current-linum)
   (current-charpos)
   c))

(define-command erase-buffer () ()
  (point-set (point-max))
  (buffer-erase (current-buffer))
  t)

(defun delete-while-whitespaces (&optional ignore-newline-p use-kill-ring)
  (let ((n (skip-chars-forward
            (if ignore-newline-p
                '(#\space #\tab)
                '(#\space #\tab #\newline)))))
    (delete-char (- n) use-kill-ring)))

(defun blank-line-p ()
  (let ((string (buffer-line-string (current-buffer) (current-linum)))
        (eof-p (buffer-end-line-p (current-buffer) (current-linum))))
    (when (string= "" (string-trim '(#\space #\tab) string))
      (+ (length string)
         (if eof-p 0 1)))))

(defun skip-chars-aux (pred not-p step-char at-char)
  (flet ((test (pred not-p char)
           (if (if (consp pred)
                   (member char pred)
                   (funcall pred char))
               (not not-p)
               not-p)))
    (let ((count 0))
      (loop
        (unless (test pred not-p (funcall at-char))
          (return count))
        (if (funcall step-char)
            (incf count)
            (return count))))))

(defun skip-chars-forward (pred &optional not-p)
  (skip-chars-aux pred not-p #'next-char #'following-char))

(defun skip-chars-backward (pred &optional not-p)
  (skip-chars-aux pred not-p #'prev-char #'preceding-char))
