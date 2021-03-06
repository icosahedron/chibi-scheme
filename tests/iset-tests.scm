
(cond-expand
 (modules
  (import (chibi) (chibi iset) (chibi iset optimize) (srfi 1) (chibi test)))
 (else #f))

(test-begin "iset")

(let ((tests
       `((() (+ 99) (u 3 50) (? 99))
         (() (u 1) (u 1000) (u -1000) (u 3) (u -1))
         ((17 29) (u 7 29))
         ((2 3 4) (u 1 2 3 4 5))
         ((1 2 3 4 5) (u 2 3 4))
         ((0) (z #f) (- 0) (z))
         ((0 1 2) (- 1) (- 2) (? 0))
         ((1 2 3 1000 2000) (u 1 4))
         ((1 2 3 1000 1005))
         ((97308 97827 97845 97827))
         ((1 128 127))
         ((129 2 127))
         ((1 -128 -126))
         (() (u: 349 680) (u: 682 685))
         (() (u: 64434 64449) (u: 65020 65021) (u #xFE62))
         (() (u: 716 747) (u: 750 1084))
         )))
  (for-each
   (lambda (tst)
     (let* ((ls (car tst))
            (is (list->iset ls))
            (ls2 (delete-duplicates ls =)))
       ;; initial creation and sanity checks
       (test-assert (lset= equal? ls2 (iset->list is)))
       (test (length ls2) (iset-size is))
       (for-each
        (lambda (x) (test-assert (iset-contains? is x)))
        ls)
       (test (iset-contains? is 42) (member 42 ls))
       ;; additional operations
       (for-each
        (lambda (op)
          (case (car op)
            ((+)
             (iset-adjoin! is (cadr op))
             (test-assert (iset-contains? is (cadr op))))
            ((-)
             (iset-delete! is (cadr op))
             (test-assert (not (iset-contains? is (cadr op)))))
            ((?)
             (test (if (pair? (cddr op)) (car (cddr op)) #t)
                 (iset-contains? is (cadr op))))
            ((d)
             (set! is (iset-difference is (list->iset (cdr op))))
             (for-each (lambda (x) (test-assert (iset-contains? is x))) (cdr op)))
            ((i) (set! is (iset-intersection is (list->iset (cdr op)))))
            ((s) (test (iset-size is) (cadr op)))
            ((u)
             (set! is (iset-union is (list->iset (cdr op))))
             (for-each (lambda (x) (test-assert (iset-contains? is x))) (cdr op)))
            ((u:)
             (set! is (iset-union is (make-iset (cadr op) (car (cddr op)))))
             (for-each (lambda (x) (test-assert (iset-contains? is x))) (cdr op)))
            ((z) (test (iset-empty? is) (if (pair? (cdr op)) (cadr op) #t)))
            (else (error "unknown operation" (car op)))))
        (cdr tst))
       ;; optimization
       (let* ((is2 (iset-optimize is))
              (is3 (iset-balance is))
              (is4 (iset-balance is2)))
         (test-assert (iset= is is2))
         (test-assert (iset= is is3))
         (test-assert (iset= is is4)))))
   tests))

(test-end)
