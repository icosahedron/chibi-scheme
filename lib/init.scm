;; init.scm -- R5RS library procedures
;; Copyright (c) 2009-2011 Alex Shinn.  All rights reserved.
;; BSD-style license: http://synthcode.com/license.txt

;; provide c[ad]{2,4}r

(define (caar x) (car (car x)))
(define (cadr x) (car (cdr x)))
(define (cdar x) (cdr (car x)))
(define (cddr x) (cdr (cdr x)))
(define (caaar x) (car (car (car x))))
(define (caadr x) (car (car (cdr x))))
(define (cadar x) (car (cdr (car x))))
(define (caddr x) (car (cdr (cdr x))))
(define (cdaar x) (cdr (car (car x))))
(define (cdadr x) (cdr (car (cdr x))))
(define (cddar x) (cdr (cdr (car x))))
(define (cdddr x) (cdr (cdr (cdr x))))
(define (caaaar x) (car (car (car (car x)))))
(define (caaadr x) (car (car (car (cdr x)))))
(define (caadar x) (car (car (cdr (car x)))))
(define (caaddr x) (car (car (cdr (cdr x)))))
(define (cadaar x) (car (cdr (car (car x)))))
(define (cadadr x) (car (cdr (car (cdr x)))))
(define (caddar x) (car (cdr (cdr (car x)))))
(define (cadddr x) (car (cdr (cdr (cdr x)))))
(define (cdaaar x) (cdr (car (car (car x)))))
(define (cdaadr x) (cdr (car (car (cdr x)))))
(define (cdadar x) (cdr (car (cdr (car x)))))
(define (cdaddr x) (cdr (car (cdr (cdr x)))))
(define (cddaar x) (cdr (cdr (car (car x)))))
(define (cddadr x) (cdr (cdr (car (cdr x)))))
(define (cdddar x) (cdr (cdr (cdr (car x)))))
(define (cddddr x) (cdr (cdr (cdr (cdr x)))))

;; basic utils

(define (procedure? x) (if (closure? x) #t (opcode? x)))

(define (list . args) args)

(define (list-tail ls k)
  (if (eq? k 0)
      ls
      (list-tail (cdr ls) (- k 1))))

(define (list-ref ls k) (car (list-tail ls k)))

(define (append-helper ls res)
  (if (null? ls)
      res
      (append-helper (cdr ls) (append2 (car ls) res))))

(define (append . o)
  (if (null? o)
      '()
      ((lambda (lol)
         (append-helper (cdr lol) (car lol)))
       (reverse o))))

(define (apply proc . args)
  (if (null? args)
      (proc)
      ((lambda (lol)
         (apply1 proc (append2 (reverse (cdr lol)) (car lol))))
       (reverse args))))

(define (eval x . o)
  ((compile x (if (pair? o) (car o) (interaction-environment)))))

;; map with a fast-path for single lists

(define (map proc ls . lol)
  (define (map1 proc ls res)
    (if (pair? ls)
        (map1 proc (cdr ls) (cons (proc (car ls)) res))
        (reverse res)))
  (define (mapn proc lol res)
    (if (pair? (car lol))
        (mapn proc
              (map1 cdr lol '())
              (cons (apply1 proc (map1 car lol '())) res))
        (reverse res)))
  (if (null? lol)
      (map1 proc ls '())
      (mapn proc (cons ls lol) '())))

(define (for-each f ls . lol)
  (define (for1 f ls) (if (pair? ls) (begin (f (car ls)) (for1 f (cdr ls)))))
  (if (null? lol) (for1 f ls) (begin (apply map f ls lol) (if #f #f))))

(define (any pred ls)
  (if (pair? ls) (if (pred (car ls)) (car ls) (any pred (cdr ls))) #f))

(define (every pred ls)
  (if (pair? ls) (if (pred (car ls)) (every pred (cdr ls)) #f) #t))

(define (delq x ls)
  (if (pair? ls)
      (if (eq? x (car ls)) (delq x (cdr ls)) (cons (car ls) (delq x (cdr ls))))
      '()))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; syntax

(define sc-macro-transformer
  (lambda (f)
    (lambda (expr use-env mac-env)
      (make-syntactic-closure mac-env '() (f expr use-env)))))

(define rsc-macro-transformer
  (lambda (f)
    (lambda (expr use-env mac-env)
      (f expr mac-env))))

(define er-macro-transformer
  (lambda (f)
    (lambda (expr use-env mac-env)
      ((lambda (rename compare) (f expr rename compare))
       ((lambda (renames)
          (lambda (identifier)
            ((lambda (cell)
               (if cell
                   (cdr cell)
                   ((lambda (name)
                      (set! renames (cons (cons identifier name) renames))
                      name)
                    (make-syntactic-closure mac-env '() identifier))))
             (assq identifier renames))))
        '())
       (lambda (x y) (identifier=? use-env x use-env y))))))

(define-syntax cond
  (er-macro-transformer
   (lambda (expr rename compare)
     (if (null? (cdr expr))
         #f
         ((lambda (cl)
            (if (compare (rename 'else) (car cl))
                (if (pair? (cddr expr))
                    (error "non-final else in cond" expr)
                    (cons (rename 'begin) (cdr cl)))
                (if (if (null? (cdr cl)) #t (compare (rename '=>) (cadr cl)))
                    (list (list (rename 'lambda) (list (rename 'tmp))
                                (list (rename 'if) (rename 'tmp)
                                      (if (null? (cdr cl))
                                          (rename 'tmp)
                                          (list (caddr cl) (rename 'tmp)))
                                      (cons (rename 'cond) (cddr expr))))
                          (car cl))
                    (list (rename 'if)
                          (car cl)
                          (cons (rename 'begin) (cdr cl))
                          (cons (rename 'cond) (cddr expr))))))
          (cadr expr))))))

(define-syntax or
  (er-macro-transformer
   (lambda (expr rename compare)
     (cond ((null? (cdr expr)) #f)
           ((null? (cddr expr)) (cadr expr))
           (else
            (list (rename 'let) (list (list (rename 'tmp) (cadr expr)))
                  (list (rename 'if) (rename 'tmp)
                        (rename 'tmp)
                        (cons (rename 'or) (cddr expr)))))))))

(define-syntax and
  (er-macro-transformer
   (lambda (expr rename compare)
     (cond ((null? (cdr expr)))
           ((null? (cddr expr)) (cadr expr))
           (else (list (rename 'if) (cadr expr)
                       (cons (rename 'and) (cddr expr))
                       #f))))))

(define-syntax quasiquote
  (er-macro-transformer
   (lambda (expr rename compare)
     (define (qq x d)
       (cond
        ((pair? x)
         (cond
          ((compare (rename 'unquote) (car x))
           (if (<= d 0)
               (cadr x)
               (list (rename 'list) (list (rename 'quote) 'unquote)
                     (qq (cadr x) (- d 1)))))
          ((compare (rename 'unquote-splicing) (car x))
           (if (<= d 0)
               (list (rename 'cons) (qq (car x) d) (qq (cdr x) d))
               (list (rename 'list) (list (rename 'quote) 'unquote-splicing)
                     (qq (cadr x) (- d 1)))))
          ((compare (rename 'quasiquote) (car x))
           (list (rename 'list) (list (rename 'quote) 'quasiquote)
                 (qq (cadr x) (+ d 1))))
          ((and (<= d 0) (pair? (car x)) (compare (rename 'unquote-splicing) (caar x)))
           (if (null? (cdr x))
               (cadar x)
               (list (rename 'append) (cadar x) (qq (cdr x) d))))
          (else
           (list (rename 'cons) (qq (car x) d) (qq (cdr x) d)))))
        ((vector? x) (list (rename 'list->vector) (qq (vector->list x) d)))
        ((if (symbol? x) #t (null? x)) (list (rename 'quote) x))
        (else x)))
     (qq (cadr expr) 0))))

(define-syntax letrec
  (er-macro-transformer
   (lambda (expr rename compare)
     ((lambda (defs)
        `((,(rename 'lambda) () ,@defs ,@(cddr expr))))
      (map (lambda (x) (cons (rename 'define) x)) (cadr expr))))))

(define-syntax let
  (er-macro-transformer
   (lambda (expr rename compare)
     (if (null? (cdr expr)) (error "empty let" expr))
     (if (null? (cddr expr)) (error "no let body" expr))
     ((lambda (bindings)
        (if (list? bindings) #f (error "bad let bindings"))
        (if (every (lambda (x)
                     (if (pair? x) (if (pair? (cdr x)) (null? (cddr x)) #f) #f))
                   bindings)
            ((lambda (vars vals)
               (if (identifier? (cadr expr))
                   `((,(rename 'lambda) ,vars
                      (,(rename 'letrec) ((,(cadr expr)
                                           (,(rename 'lambda) ,vars
                                            ,@(cdddr expr))))
                       (,(cadr expr) ,@vars)))
                     ,@vals)
                   `((,(rename 'lambda) ,vars ,@(cddr expr)) ,@vals)))
             (map car bindings)
             (map cadr bindings))
            (error "bad let syntax" expr)))
      (if (identifier? (cadr expr)) (caddr expr) (cadr expr))))))

(define-syntax let*
  (er-macro-transformer
   (lambda (expr rename compare)
     (if (null? (cdr expr)) (error "empty let*" expr))
     (if (null? (cddr expr)) (error "no let* body" expr))
     (if (null? (cadr expr))
         `(,(rename 'let) () ,@(cddr expr))
         (if (if (list? (cadr expr))
                 (every
                  (lambda (x)
                    (if (pair? x) (if (pair? (cdr x)) (null? (cddr x)) #f) #f))
                  (cadr expr))
                 #f)
             `(,(rename 'let) (,(caadr expr))
               (,(rename 'let*) ,(cdadr expr) ,@(cddr expr)))
             (error "bad let* syntax"))))))

(define-syntax case
  (er-macro-transformer
   (lambda (expr rename compare)
     (define (clause ls)
       (cond
        ((null? ls) #f)
        ((compare (rename 'else) (caar ls))
         `(,(rename 'begin) ,@(cdar ls)))
        (else
         (if (and (pair? (caar ls)) (null? (cdaar ls)))
             `(,(rename 'if) (,(rename 'eqv?) ,(rename 'tmp) ',(caaar ls))
               (,(rename 'begin) ,@(cdar ls))
               ,(clause (cdr ls)))
             `(,(rename 'if) (,(rename 'memv) ,(rename 'tmp) ',(caar ls))
               (,(rename 'begin) ,@(cdar ls))
               ,(clause (cdr ls)))))))
     `(let ((,(rename 'tmp) ,(cadr expr)))
        ,(clause (cddr expr))))))

(define-syntax do
  (er-macro-transformer
   (lambda (expr rename compare)
     (let* ((body
             `(,(rename 'begin)
               ,@(cdddr expr)
               (,(rename 'lp)
                ,@(map (lambda (x) (if (pair? (cddr x)) (caddr x) (car x)))
                       (cadr expr)))))
            (check (caddr expr))
            (wrap
             (if (null? (cdr check))
                 `(,(rename 'let) ((,(rename 'tmp) ,(car check)))
                   (,(rename 'if) ,(rename 'tmp)
                    ,(rename 'tmp)
                    ,body))
                 `(,(rename 'if) ,(car check)
                   (,(rename 'begin) ,@(cdr check))
                   ,body))))
       `(,(rename 'let) ,(rename 'lp)
         ,(map (lambda (x) (list (car x) (cadr x))) (cadr expr))
         ,wrap)))))

(define-syntax delay
  (er-macro-transformer
   (lambda (expr rename compare)
     `(,(rename 'make-promise) (,(rename 'lambda) () ,(cadr expr))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; exceptions

(define (error msg . args)
  (raise (make-exception 'user msg args #f #f)))

(define (with-exception-handler handler thunk)
  (letrec ((orig-handler (current-exception-handler))
           (self (lambda (exn)
                   (current-exception-handler orig-handler)
                   (handler exn))))
    (current-exception-handler self)
    (let ((res (thunk)))
      (current-exception-handler orig-handler)
      res)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; library functions

;; booleans

(define (not x) (if x #f #t))
(define (boolean? x) (if (eq? x #t) #t (eq? x #f)))

;; char utils

(define (char-alphabetic? ch) (<= 65 (char->integer (char-upcase ch)) 90))
(define (char-numeric? ch) (<= 48 (char->integer ch) 57))
(define (char-whitespace? ch)
  (if (eq? ch #\space)
      #t
      (if (eq? ch #\tab) #t (if (eq? ch #\newline) #t (eq? ch #\return)))))
(define (char-upper-case? ch) (<= 65 (char->integer ch) 90))
(define (char-lower-case? ch) (<= 97 (char->integer ch) 122))

(define (char=? a b) (= (char->integer a) (char->integer b)))
(define (char<? a b) (< (char->integer a) (char->integer b)))
(define (char>? a b) (> (char->integer a) (char->integer b)))
(define (char<=? a b) (<= (char->integer a) (char->integer b)))
(define (char>=? a b) (>= (char->integer a) (char->integer b)))

(define (char-ci=? a b)
  (= (char->integer (char-downcase a)) (char->integer (char-downcase b))))
(define (char-ci<? a b)
  (< (char->integer (char-downcase a)) (char->integer (char-downcase b))))
(define (char-ci>? a b)
  (> (char->integer (char-downcase a)) (char->integer (char-downcase b))))
(define (char-ci<=? a b)
  (<= (char->integer (char-downcase a)) (char->integer (char-downcase b))))
(define (char-ci>=? a b)
  (>= (char->integer (char-downcase a)) (char->integer (char-downcase b))))

;; string utils

(define (symbol->string sym)
  (call-with-output-string (lambda (out) (write sym out))))

(define (list->string ls)
  (let ((str (make-string (length ls) #\space)))
    (let lp ((ls ls) (i 0))
      (if (pair? ls)
          (begin
            (string-set! str i (car ls))
            (lp (cdr ls) (+ i 1)))))
    str))

(define (string->list str)
  (let lp ((i (- (string-length str) 1)) (res '()))
    (if (< i 0) res (lp (- i 1) (cons (string-ref str i) res)))))

(define (string-fill! str ch)
  (let lp ((i (- (string-length str) 1)))
    (if (>= i 0) (begin (string-set! str i ch) (lp (- i 1))))))

(define (string . args) (list->string args))
(define (string-append . args) (string-concatenate args))
(define (string-copy s) (substring s 0 (string-length s)))

(define (string=? s1 s2) (eq? (string-cmp s1 s2 #f) 0))
(define (string<? s1 s2) (< (string-cmp s1 s2 #f) 0))
(define (string<=? s1 s2) (<= (string-cmp s1 s2 #f) 0))
(define (string>? s1 s2) (> (string-cmp s1 s2 #f) 0))
(define (string>=? s1 s2) (>= (string-cmp s1 s2 #f) 0))

(define (string-ci=? s1 s2) (eq? (string-cmp s1 s2 #t) 0))
(define (string-ci<? s1 s2) (< (string-cmp s1 s2 #t) 0))
(define (string-ci<=? s1 s2) (<= (string-cmp s1 s2 #t) 0))
(define (string-ci>? s1 s2) (> (string-cmp s1 s2 #t) 0))
(define (string-ci>=? s1 s2) (>= (string-cmp s1 s2 #t) 0))

;; list utils

(define (eqv? a b) (if (eq? a b) #t (and (flonum? a) (flonum? b) (= a b))))

(define (member obj ls . o)
  (let ((eq (if (pair? o) (car o) equal?)))
    (let lp ((ls ls))
      (and (pair? ls) (if (eq obj (car ls)) ls (lp (cdr ls)))))))

(define memv member)

(define (assoc obj ls)
  (if (null? ls)
      #f
      (if (equal? obj (caar ls))
          (car ls)
          (assoc obj (cdr ls)))))

(define assv assoc)

;; math utils

(define (number? x) (if (fixnum? x) #t (if (bignum? x) #t (flonum? x))))
(define complex? number?)
(define rational? number?)
(define real? number?)
(define (exact? x) (if (fixnum? x) #t (bignum? x)))
(define inexact? flonum?)
(define (integer? x)
  (if (fixnum? x) #t (if (bignum? x) #t (and (flonum? x) (= x (truncate x))))))

(define (zero? x) (= x 0))
(define (positive? x) (> x 0))
(define (negative? x) (< x 0))
(define (even? n) (= (remainder n 2) 0))
(define (odd? n) (= (remainder n 2) 1))

(define (abs x) (if (< x 0) (- x) x))

(define (numerator x)
  (if (integer? x) x (numerator (* x 10))))
(define (denominator x)
  (if (exact? x)
      1
      (let lp ((x x) (r 1.0)) (if (integer? x) r (lp (* x 10) (* r 10))))))

(define (modulo a b)
  (let ((res (remainder a b)))
    (if (< b 0)
        (if (<= res 0) res (+ res b))
        (if (>= res 0) res (+ res b)))))

(define (gcd a b)
  (if (= b 0)
      (abs a)
      (gcd b (remainder a b))))

(define (lcm a b)
  (abs (quotient (* a b) (gcd a b))))

(define (max x . rest)
  (let lp ((hi x) (ls rest))
    (if (null? ls)
        hi
        (lp (if (> (car ls) hi) (car ls) hi) (cdr ls)))))

(define (min x . rest)
  (let lp ((lo x) (ls rest))
    (if (null? ls)
        lo
        (lp (if (< (car ls) lo) (car ls) lo) (cdr ls)))))

(define (real-part z) z)
(define (imag-part z) 0.0)
(define magnitude abs)
(define (angle z) (if (< z 0) 3.141592653589793 0))

(define (atan x . o) (if (null? o) (atan1 x) (atan1 (/ x (car o)))))

(define (digit-char n)
  (if (<= n 9)
      (integer->char (+ n (char->integer #\0)))
      (integer->char (+ (- n 10) (char->integer #\A)))))
(define (digit-value ch)
  (if (char-numeric? ch)
      (- (char->integer ch) (char->integer #\0))
      (and (<= 65 (char->integer (char-upcase ch)) 70)
           (- (char->integer (char-upcase ch)) 55))))

(define (number->string num . o)
  (if (if (null? o) #t (eq? 10 (car o)))
      (call-with-output-string (lambda (out) (write num out)))
      (let lp ((n (abs num)) (d (car o)) (res '()))
        (if (> n 0)
            (lp (quotient n d) d (cons (digit-char (remainder n d)) res))
            (if (null? res)
                "0"
                (list->string (if (negative? num) (cons #\- res) res)))))))

;; vector utils

(define (list->vector ls)
  (let ((vec (make-vector (length ls) #f)))
    (let lp ((ls ls) (i 0))
      (if (pair? ls)
          (begin
            (vector-set! vec i (car ls))
            (lp (cdr ls) (+ i 1)))))
    vec))

(define (vector->list vec)
  (let lp ((i (- (vector-length vec) 1)) (res '()))
    (if (< i 0) res (lp (- i 1) (cons (vector-ref vec i) res)))))

(define (vector-fill! str ch)
  (let lp ((i (- (vector-length str) 1)))
    (if (>= i 0) (begin (vector-set! str i ch) (lp (- i 1))))))

(define (vector . args) (list->vector args))

;; I/O utils

(define (port? x) (or (input-port? x) (output-port? x)))

(define (char-ready? . o)
  (not (eof-object? (peek-char (if (pair? o) (car o) (current-input-port))))))

(define (call-with-input-string str proc)
  (let* ((in (open-input-string str))
         (res (proc in)))
    (close-input-port in)
    res))

(define (call-with-output-string proc)
  (let ((out (open-output-string)))
    (proc out)
    (let ((res (get-output-string out)))
      (close-output-port out)
      res)))

(define (call-with-input-file file proc)
  (let* ((in (open-input-file file))
         (res (proc in)))
    (close-input-port in)
    res))

(define (call-with-output-file file proc)
  (let* ((out (open-output-file file))
         (res (proc out)))
    (close-output-port out)
    res))

(define (with-input-from-file file thunk)
  (let ((old-in (current-input-port))
        (tmp-in (open-input-file file)))
    (current-input-port tmp-in)
    (let ((res (thunk)))
      (current-input-port old-in)
      res)))

(define (with-output-to-file file thunk)
  (let ((old-out (current-output-port))
        (tmp-out (open-output-file file)))
    (current-output-port tmp-out)
    (let ((res (thunk)))
      (current-output-port old-out)
      res)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; values

(define *values-tag* (list 'values))

(define (values . ls)
  (if (and (pair? ls) (null? (cdr ls)))
      (car ls)
      (cons *values-tag* ls)))

(define (call-with-values producer consumer)
  (let ((res (producer)))
    (if (and (pair? res) (eq? *values-tag* (car res)))
        (apply consumer (cdr res))
        (consumer res))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; dynamic-wind

(define *dk* (list #f))

(define (dynamic-wind before thunk after)
  (let ((dk *dk*))
    (set-dk! (cons (cons before after) dk))
    (let ((res (thunk))) (set-dk! dk) res)))

(define (set-dk! dk)
  (if (not (eq? dk *dk*))
      (begin
        (set-dk! (cdr dk))
        (let ((before (car (car dk))) (dk dk))
          (set-car! *dk* (cons (cdr (car dk)) before))
          (set-cdr! *dk* dk)
          (set-car! dk #f)
          (set-cdr! dk '())
          (set! *dk* dk)
          (before)))))

(define (call-with-current-continuation proc)
  (let ((dk *dk*))
    (%call/cc (lambda (k) (proc (lambda (x) (set-dk! dk) (k x)))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; syntax-rules

(define-syntax syntax-rules
  (er-macro-transformer
   (lambda (expr rename compare)
     (let ((ellipse-specified? (identifier? (cadr expr)))
           (count 0)
           (_er-macro-transformer (rename 'er-macro-transformer))
           (_lambda (rename 'lambda))      (_let (rename 'let))
           (_begin (rename 'begin))        (_if (rename 'if))
           (_and (rename 'and))            (_or (rename 'or))
           (_eq? (rename 'eq?))            (_equal? (rename 'equal?))
           (_car (rename 'car))            (_cdr (rename 'cdr))
           (_cons (rename 'cons))          (_pair? (rename 'pair?))
           (_null? (rename 'null?))        (_expr (rename 'expr))
           (_rename (rename 'rename))      (_compare (rename 'compare))
           (_quote (rename 'syntax-quote)) (_apply (rename 'apply))
           (_append (rename 'append))      (_map (rename 'map))
           (_vector? (rename 'vector?))    (_list? (rename 'list?))
           (_len (rename'len))             (_length (rename 'length))
           (_- (rename '-))   (_>= (rename '>=))   (_error (rename 'error))
           (_ls (rename 'ls)) (_res (rename 'res)) (_i (rename 'i))
           (_reverse (rename 'reverse))    (_vector->list (rename 'vector->list))
           (_list->vector (rename 'list->vector)))
       (define ellipse (rename (if ellipse-specified? (cadr expr) '...)))
       (define lits (if ellipse-specified? (caddr expr) (cadr expr)))
       (define forms (if ellipse-specified? (cdddr expr) (cddr expr)))
       (define (next-symbol s)
         (set! count (+ count 1))
         (rename (string->symbol (string-append s (number->string count)))))
       (define (expand-pattern pat tmpl)
         (let lp ((p (cdr pat))
                  (x (list _cdr _expr))
                  (dim 0)
                  (vars '())
                  (k (lambda (vars)
                       (or (expand-template tmpl vars)
                           (list _begin #f)))))
           (let ((v (next-symbol "v.")))
             (list
              _let (list (list v x))
              (cond
               ((identifier? p)
                (if (any (lambda (l) (compare p l)) lits)
                    (list _and (list _compare v (list _quote p)) (k vars))
                    (list _let (list (list p v)) (k (cons (cons p dim) vars)))))
               ((ellipse? p)
                (cond
                 ((not (null? (cddr p)))
                  (cond
                   ((any (lambda (x) (and (identifier? x) (compare x ellipse)))
                         (cddr p))
                    (error "multiple ellipses" p))
                   (else
                    (let ((len (length (cdr (cdr p))))
                          (_lp (next-symbol "lp.")))
                      `(,_let ((,_len (,_length ,v)))
                         (,_and (,_>= ,_len ,len)
                                (,_let ,_lp ((,_ls ,v)
                                             (,_i (,_- ,_len ,len))
                                             (,_res (,_quote ())))
                                  (,_if (,_>= 0 ,_i)
                                      ,(lp `(,@(cdr (cdr p)) ,(car p) ,(car (cdr p)))
                                           `(,_append ,_ls (,_reverse ,_res))
                                           dim
                                           vars
                                           k)
                                      (,_lp (,_cdr ,_ls)
                                            (,_- ,_i 1)
                                            (,_cons (,_car ,_ls) ,_res))))))))))
                 ((identifier? (car p))
                  (list _and (list _list? v)
                        (list _let (list (list (car p) v))
                              (k (cons (cons (car p) (+ 1 dim)) vars)))))
                 (else
                  (let* ((w (next-symbol "w."))
                         (_lp (next-symbol "lp."))
                         (new-vars (all-vars (car p) (+ dim 1)))
                         (ls-vars (map (lambda (x)
                                         (next-symbol
                                          (string-append
                                           (symbol->string
                                            (identifier->symbol (car x)))
                                           "-ls")))
                                       new-vars))
                         (once
                          (lp (car p) (list _car w) (+ dim 1) '()
                              (lambda (_)
                                (cons
                                 _lp
                                 (cons
                                  (list _cdr w)
                                  (map (lambda (x l)
                                         (list _cons (car x) l))
                                       new-vars
                                       ls-vars)))))))
                    (list
                     _let
                     _lp (cons (list w v)
                               (map (lambda (x) (list x (list _quote '()))) ls-vars))
                     (list _if (list _null? w)
                           (list _let (map (lambda (x l)
                                             (list (car x) (list _reverse l)))
                                           new-vars
                                           ls-vars)
                                 (k (append new-vars vars)))
                           (list _and (list _pair? w) once)))))))
               ((pair? p)
                (list _and (list _pair? v)
                      (lp (car p)
                          (list _car v)
                          dim
                          vars
                          (lambda (vars)
                            (lp (cdr p) (list _cdr v) dim vars k)))))
               ((vector? p)
                (list _and
                      (list _vector? v)
                      (lp (vector->list p) (list _vector->list v) dim vars k)))
               ((null? p) (list _and (list _null? v) (k vars)))
               (else (list _and (list _equal? v p) (k vars))))))))
       (define (ellipse-escape? x) (and (pair? x) (compare ellipse (car x))))
       (define (ellipse? x)
         (and (pair? x) (pair? (cdr x)) (compare ellipse (cadr x))))
       (define (ellipse-depth x)
         (if (ellipse? x)
             (+ 1 (ellipse-depth (cdr x)))
             0))
       (define (ellipse-tail x)
         (if (ellipse? x)
             (ellipse-tail (cdr x))
             (cdr x)))
       (define (all-vars x dim)
         (let lp ((x x) (dim dim) (vars '()))
           (cond ((identifier? x)
                  (if (any (lambda (lit) (compare x lit)) lits)
                      vars
                      (cons (cons x dim) vars)))
                 ((ellipse? x) (lp (car x) (+ dim 1) vars))
                 ((pair? x) (lp (car x) dim (lp (cdr x) dim vars)))
                 ((vector? x) (lp (vector->list x) dim vars))
                 (else vars))))
       (define (free-vars x vars dim)
         (let lp ((x x) (free '()))
           (cond
            ((identifier? x)
             (if (and (not (memq x free))
                      (cond ((assq x vars) => (lambda (cell) (>= (cdr cell) dim)))
                            (else #f)))
                 (cons x free)
                 free))
            ((pair? x) (lp (car x) (lp (cdr x) free)))
            ((vector? x) (lp (vector->list x) free))
            (else free))))
       (define (expand-template tmpl vars)
         (let lp ((t tmpl) (dim 0))
           (cond
            ((identifier? t)
             (cond
              ((any (lambda (v) (compare t (car v))) vars)
               => (lambda (cell)
                    (if (<= (cdr cell) dim)
                        t
                        (error "too few ...'s"))))
              (else
               (list _rename (list _quote t)))))
            ((pair? t)
             (cond
              ((ellipse-escape? t)
               (list _quote
                     (if (pair? (cdr t))
                         (if (pair? (cddr t)) (cddr t) (cadr t))
                         (cdr t))))
              ((ellipse? t)
               (let* ((depth (ellipse-depth t))
                      (ell-dim (+ dim depth))
                      (ell-vars (free-vars (car t) vars ell-dim)))
                 (if (null? ell-vars)
                     (error "too many ...'s")
                     (let* ((once (lp (car t) ell-dim))
                            (nest (if (and (null? (cdr ell-vars))
                                           (identifier? once)
                                           (eq? once (car vars)))
                                      once ;; shortcut
                                      (cons _map
                                            (cons (list _lambda ell-vars once)
                                                  ell-vars))))
                            (many (do ((d depth (- d 1))
                                       (many nest
                                             (list _apply _append many)))
                                      ((= d 1) many))))
                       (if (null? (ellipse-tail t))
                           many ;; shortcut
                           (list _append many (lp (ellipse-tail t) dim)))))))
              (else (list _cons (lp (car t) dim) (lp (cdr t) dim)))))
            ((vector? t) (list _list->vector (lp (vector->list t) dim)))
            ((null? t) (list _quote '()))
            (else t))))
       (list
        _er-macro-transformer
        (list _lambda (list _expr _rename _compare)
              (cons
               _or
               (append
                (map
                 (lambda (clause) (expand-pattern (car clause) (cadr clause)))
                 forms)
                (list (list _error "no expansion for"
                            (list (rename 'strip-syntactic-closures) _expr)))))))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; modules

(define *config-env* #f)

(define-syntax import
  (er-macro-transformer
   (lambda (expr rename compare)
     (let lp ((ls (cdr expr)) (res '()))
       (cond
        ((null? ls)
         (cons 'begin (reverse res)))
        (else
         (let ((mod+imps (eval `(resolve-import ',(car ls)) *config-env*)))
           (if (pair? mod+imps)
               (lp (cdr ls)
                   (cons `(%env-copy!
                           #f
                           (vector-ref
                            (eval '(load-module ',(car mod+imps)) *config-env*)
                            1)
                           ',(cdr mod+imps)
                           #f)
                         res))
               (error "couldn't find module" (car ls))))))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SRFI-0

(define-syntax cond-expand
  (er-macro-transformer
   (lambda (expr rename compare)
     (define (check x)
       (if (pair? x)
           (case (car x)
             ((and) (every check (cdr x)))
             ((or) (any check (cdr x)))
             ((not) (not (check (cadr x))))
             (else (error "cond-expand: bad feature" x)))
           (memq (identifier->symbol x) *features*)))
     (let expand ((ls (cdr expr)))
       (cond ((null? ls) (error "cond-expand: no expansions" expr))
             ((not (pair? (car ls))) (error "cond-expand: bad clause" (car ls)))
             ((eq? 'else (identifier->symbol (caar ls)))
              (if (pair? (cdr ls))
                  (error "cond-expand: else in non-final position")
                  `(,(rename 'begin) ,@(cdar ls))))
             ((check (caar ls)) `(,(rename 'begin) ,@(cdar ls)))
             (else (expand (cdr ls))))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; promises

(cond-expand
 (auto-force
  (define (force x) x))
 (else
  (define (make-promise thunk)
   (lambda ()
     (let ((computed? #f) (result #f))
       (if (not computed?)
           (begin
             (set! result (thunk))
             (set! computed? #t)))
       result)))
  (define (force x) (if (procedure? x) (x) x))))
