;;
;; Test object system
;;

;; $Id: object.scm,v 1.26 2003-11-11 23:46:00 shirok Exp $

(use gauche.test)

(test-start "object system")

;;----------------------------------------------------------------
(test-section "class definition")

(define-class <x> () (a b c))
(test* "define-class <x>" '<x> (class-name <x>))
(test* "define-class <x>" 3 (slot-ref <x> 'num-instance-slots))
(test* "define-class <x>" <class> (class-of <x>))
(test* "define-class <x>" '(<x> <object> <top>)
       (map class-name (class-precedence-list <x>)))

(define-class <y> (<x>) (c d e))
(test* "define-class <y>" 5 (slot-ref <y> 'num-instance-slots))
(test* "define-class <y>" <class> (class-of <y>))
(test* "define-class <y>" '(<y> <x> <object> <top>)
       (map class-name (class-precedence-list <y>)))

(define-class <z> (<object>) ())
(test* "define-class <z>" 0 (slot-ref <z> 'num-instance-slots))
(test* "define-class <z>" <class> (class-of <z>))
(test* "define-class <z>" '(<z> <object> <top>)
       (map class-name (class-precedence-list <z>)))

(define-class <w> (<z> <y>) (e f))
(test* "define-class <w>" 6 (slot-ref <w> 'num-instance-slots))
(test* "define-class <w>" <class> (class-of <w>))
(test* "define-class <w>" '(<w> <z> <y> <x> <object> <top>)
       (map class-name (class-precedence-list <w>)))

(define-class <w2> (<y> <z>) (e f))
(test* "define-class <w2>" '(<w2> <y> <x> <z> <object> <top>)
       (map class-name (class-precedence-list <w2>)))

;;----------------------------------------------------------------
(test-section "instancing")

(define x1 (make <x>))
(define x2 (make <x>))

(test* "make <x>" <x> (class-of x1))
(test* "make <x>" <x> (class-of x2))

(slot-set! x1 'a 4)
(slot-set! x1 'b 5)
(slot-set! x1 'c 6)
(slot-set! x2 'a 7)
(slot-set! x2 'b 8)
(slot-set! x2 'c 9)

(test* "slot-ref" '(4 5 6) (map (lambda (slot) (slot-ref x1 slot)) '(a b c)))
(test* "slot-ref" '(7 8 9) (map (lambda (slot) (slot-ref x2 slot)) '(a b c)))

(test* "slot-ref-using-class" '(4 5 6)
       (map (lambda (slot) (slot-ref-using-class <x> x1 slot)) '(a b c)))
(test* "slot-ref-using-class" *test-error*
       (slot-ref-using-class <y> x1 'a))

(test* "slot-ref-using-accessor" '(7 8 9)
       (map (lambda (slot)
              (let ((sa (class-slot-accessor <x> slot)))
                (and sa (slot-ref-using-accessor x2 sa))))
            '(a b c)))
(test* "slot-ref-using-accessor" *test-error*
       (let ((sa (class-slot-accessor <y> slot)))
         (and sa (slot-ref-using-accessor x2 sa))))

(test* "slot-set-using-class!" '(-4 -5 -6)
       (map (lambda (slot)
              (slot-set-using-class! <x> x1 slot
                                     (- (slot-ref x1 slot)))
              (slot-ref x1 slot))
            '(a b c)))
(test* "slot-set-using-class!" *test-error*
       (slot-set-using-class! <y> x1 'a 3))

(test* "slot-set-using-accessor!" '(-7 -8 -9)
       (map (lambda (slot)
              (let ((sa (class-slot-accessor <x> slot)))
                (and sa
                     (slot-set-using-accessor! x2 sa (- (slot-ref x2 slot)))))
              (slot-ref x2 slot))
            '(a b c)))
(test* "slot-ref-using-accessor!" *test-error*
       (let ((sa (class-slot-accessor <y> slot)))
         (and sa (slot-set-using-accessor! x2 sa -1))))

;;----------------------------------------------------------------
(test-section "slot initialization")

(define-class <r> ()
  ((a :init-keyword :a :initform 4)
   (b :init-keyword :b :init-value 5)))

(define r1 (make <r>))
(define r2 (make <r> :a 9))
(define r3 (make <r> :b 100 :a 20))

(define-method slot-values ((obj <r>))
  (map (lambda (s) (slot-ref obj s)) '(a b)))

(test* "make <r>" '(4 5) (slot-values r1))
(test* "make <r> :a" '(9 5) (slot-values r2))
(test* "make <r> :a :b" '(20 100) (slot-values r3))

;;----------------------------------------------------------------
(test-section "slot allocations")

(define-class <s> ()
  ((i :allocation :instance      :init-keyword :i :init-value #\i)
   (c :allocation :class         :init-keyword :c :init-value #\c)
   (s :allocation :each-subclass :init-keyword :s :init-value #\s)
   (v :allocation :virtual       :init-keyword :v
      :slot-ref (lambda (o) (cons (slot-ref o 'i) (slot-ref o 'c)))
      :slot-set! (lambda (o v)
                   (slot-set! o 'i (car v))
                   (slot-set! o 'c (cdr v))))
   ))

(define-method slot-values ((obj <s>))
  (map (lambda (s) (slot-ref obj s)) '(i c s v)))

(define s1 (make <s>))
(define s2 (make <s>))

(test* "make <s>" '(#\i #\c #\s (#\i . #\c)) (slot-values s1))
(test* "slot-set! :instance"
       '((#\I #\c #\s (#\I . #\c)) (#\i #\c #\s (#\i . #\c)))
       (begin
         (slot-set! s1 'i #\I)
         (list (slot-values s1) (slot-values s2))))
(test* "slot-set! :class"
       '((#\I #\C #\s (#\I . #\C)) (#\i #\C #\s (#\i . #\C)))
       (begin
         (slot-set! s1 'c #\C)
         (list (slot-values s1) (slot-values s2))))
(test* "slot-set! :each-subclass"
       '((#\I #\C #\S (#\I . #\C)) (#\i #\C #\S (#\i . #\C)))
       (begin
         (slot-set! s1 's #\S)
         (list (slot-values s1) (slot-values s2))))
(test* "slot-set! :virtual"
       '((i c #\S (i . c)) (#\i c #\S (#\i . c)))
       (begin
         (slot-set! s1 'v '(i . c))
         (list (slot-values s1) (slot-values s2))))

(define-class <ss> (<s>)
  ())

(define s3 (make <ss> :i "i" :c "c" :s "s"))

(test* "make <ss>"
       '(("i" "c" "s" ("i" . "c")) (i "c" #\S (i . "c")))
       (list (slot-values s3) (slot-values s1)))
(test* "slot-set! :class"
       '(("i" "C" "s" ("i" . "C")) (i "C" #\S (i . "C")))
       (begin
         (slot-set! s3 'c "C")
         (list (slot-values s3) (slot-values s1))))
(test* "slot-set! :each-subclass"
       '(("i" "C" "s" ("i" . "C")) (i "C" "S" (i . "C")))
       (begin
         (slot-set! s1 's "S")
         (list (slot-values s3) (slot-values s1))))
(test* "slot-set! :each-subclass"
       '(("i" "C" 5 ("i" . "C")) (i "C" "S" (i . "C")))
       (begin
         (slot-set! s3 's 5)
         (list (slot-values s3) (slot-values s1))))

(define s4 (make <ss> :v '(1 . 0)))

(test* "make <ss> :v"
       '((1 0 5 (1 . 0)) ("i" 0 5 ("i" . 0)))
       (list (slot-values s4) (slot-values s3)))

(test* "class-slot-ref"
       '(0 "S" 0 5)
       (list (class-slot-ref <s> 'c)  (class-slot-ref <s> 's)
             (class-slot-ref <ss> 'c) (class-slot-ref <ss> 's)))
(test* "class-slot-set!"
       '(100 99 100 5)
       (begin
         (class-slot-set! <s> 'c 100)
         (class-slot-set! <s> 's 99)
         (list (class-slot-ref <s> 'c)  (class-slot-ref <s> 's)
               (class-slot-ref <ss> 'c) (class-slot-ref <ss> 's))))
(test* "class-slot-set!"
       '(101 99 101 55)
       (begin
         (class-slot-set! <ss> 'c 101)
         (class-slot-set! <ss> 's 55)
         (list (class-slot-ref <s> 'c)  (class-slot-ref <s> 's)
               (class-slot-ref <ss> 'c) (class-slot-ref <ss> 's))))

;;----------------------------------------------------------------
(test-section "next method")

(define (nm obj) 'fallback)

(define-method nm ((obj <x>))  (list 'x-in (next-method) 'x-out))
(define-method nm ((obj <y>))  (list 'y-in (next-method) 'y-out))
(define-method nm ((obj <z>))  (list 'z-in (next-method) 'z-out))
(define-method nm ((obj <w>))  (list 'w-in (next-method) 'w-out))
(define-method nm ((obj <w2>))  (list 'w2-in (next-method) 'w2-out))

(test* "next method"
       '(y-in (x-in fallback x-out) y-out)
       (nm (make <y>)))
(test* "next-method"
       '(w-in (z-in (y-in (x-in fallback x-out) y-out) z-out) w-out)
       (nm (make <w>)))
(test* "next-method"
       '(w2-in (y-in (x-in (z-in fallback z-out) x-out) y-out) w2-out)
       (nm (make <w2>)))

(define-method nm (obj . a)
  (if (null? a) (list 't*-in (next-method) 't*-out) 't*))
(define-method nm ((obj <y>) a) (list 'y1-in (next-method) 'y1-out))
(define-method nm ((obj <y>) . a) (list 'y*-in (next-method) 'y*-out))

(test* "next-method"
       '(y1-in (y*-in t* y*-out) y1-out)
       (nm (make <y>) 3))
(test* "next-method"
       '(y-in (y*-in (x-in (t*-in fallback t*-out) x-out) y*-out) y-out)
       (nm (make <y>)))

;;----------------------------------------------------------------
(test-section "setter method definition")

(define-method s-get-i ((self <s>)) (slot-ref self 'i))
(define-method (setter s-get-i) ((self <s>) v) (slot-set! self 'i v))
(define-method (setter s-get-i) ((self <ss>) v) (slot-set! self 'i (cons v v)))

(test* "setter of s-get-i(<s>)" '("i" "j")
       (let* ((s (make <s> :i "i"))
              (i (s-get-i s))
              (j (begin (set! (s-get-i s) "j") (s-get-i s))))
         (list i j)))
(test* "setter of s-get-i(<ss>)" '("i" ("j" . "j"))
       (let* ((s (make <ss> :i "i"))
              (i (s-get-i s))
              (j (begin (set! (s-get-i s) "j") (s-get-i s))))
         (list i j)))

;;----------------------------------------------------------------
(test-section "class redefinition")

;; save original <x> and <y> defined above
(define <x>-orig <x>)
(define <y>-orig <y>)
(define <w>-orig <w>)
(define <w2>-orig <w2>)

;; create some more instances
(define y1 (let ((o (make <y>)))
             (for-each (lambda (s v) (slot-set! o s v))
                       '(a b c d e)
                       '(0 1 2 3 4))
             o))
(define y2 (let ((o (make <y>)))
             (for-each (lambda (s v) (slot-set! o s v))
                       '(a b c d e)
                       '(5 6 7 8 9))
             o))
(define w1 (let ((o (make <w>)))
             (for-each (lambda (s v) (slot-set! o s v))
                       '(a b c d e f)
                       '(100 101 102 103 104 105))
             o))
(define w2 (make <w>))

;; set several methods
(define-method redef-test1 ((x <x>)) 'x)
(define-method redef-test1 ((y <y>)) 'y)
(define-method redef-test1 ((w <w>)) 'w)
(define-method redef-test1 ((w2 <w2>)) 'w2)

(define-method redef-test2 ((x <x>) (y <y>)) 'xyz)
(define-method redef-test2 ((z <z>) (w <w>)) 'yw)

(test* "simple redefinition of <x>" #f
       (begin
         (eval '(define-class <x> () (a b c x)) (current-module))
         (eval '(eq? <x> <x>-orig) (current-module))))

(test* "simple redefinition of <x>" '(#t #f #t #f)
       (list (eq? (ref <x>-orig 'redefined) <x>)
             (ref <x> 'redefined)
             (eq? (ref <y>-orig 'redefined) <y>)
             (ref <y> 'redefined)))

(test* "subclass redefinition <y> (links)"
       '(#f #f #f #f #f)
       (list (eq? <y> <y>-orig)
             (not (memq <y> (ref <x> 'direct-subclasses)))
             (not (memq <y>-orig (ref <x>-orig 'direct-subclasses)))
             (not (memq <x> (ref <y> 'direct-supers)))
             (not (memq <x>-orig (ref <y>-orig 'direct-supers)))))

(test* "subclass redefinition <y> (slots)"
       '((a b c) (a b c x) (c d e a b) (c d e a b x))
       (map (lambda (c) (map (lambda (s) (car s)) (class-slots c)))
            (list <x>-orig <x> <y>-orig <y>)))

(test* "subclass redefinition <w> (links)"
       '(#f #f #f #f #f)
       (list (eq? <w> <w>-orig)
             (not (memq <w> (ref <y> 'direct-subclasses)))
             (not (memq <w>-orig (ref <y>-orig 'direct-subclasses)))
             (not (memq <y> (ref <w> 'direct-supers)))
             (not (memq <y>-orig (ref <w>-orig 'direct-supers)))))

(test* "subclass redefinition <w> (slots)"
       '((e f c d a b) (e f c d a b x) (e f c d a b) (e f c d a b x))
       (map (lambda (c) (map (lambda (s) (car s)) (class-slots c)))
            (list <w>-orig <w> <w2>-orig <w2>)))

(test* "subclass redefinition (hierarchy)"
       (list (list <x> <object> <top>)
             (list <y> <x> <object> <top>)
             (list <w> <z> <y> <x> <object> <top>)
             (list <w2> <y> <x> <z> <object> <top>))
       (map class-precedence-list (list <x> <y> <w> <w2>)))

(test* "subclass redefinition (hierarchy, orig)"
       (list (list <x>-orig <object> <top>)
             (list <y>-orig <x>-orig <object> <top>)
             (list <w>-orig <z> <y>-orig <x>-orig <object> <top>)
             (list <w2>-orig <y>-orig <x>-orig <z> <object> <top>))
       (map class-precedence-list
            (list <x>-orig <y>-orig <w>-orig <w2>-orig)))

;; check link consistency between class-direct-methods and method-specializer.x
(define (method-link-check gf class)
  (let loop ((dmeths (class-direct-methods class)))
    (cond ((null? dmeths) #t)
          ((memq (car dmeths) (slot-ref gf 'methods))
           => (lambda (meth)
                (and (memq class (slot-ref meth 'specializers))
                     (loop (cdr dmeths)))))
          (else #f))))

(test* "method link fix"
       '(#t #t #t #t #t #t #t)
       (list (method-link-check redef-test1 <x>)
             (method-link-check redef-test1 <y>)
             (method-link-check redef-test1 <w>)
             (method-link-check redef-test1 <w2>)
             (method-link-check redef-test2 <x>)
             (method-link-check redef-test2 <y>)
             (method-link-check redef-test2 <w>)))

(test* "instance update (x1)" '(#t -4 -5 -6 #f)
       (list (is-a? x1 <x>)
             (slot-ref x1 'a)
             (slot-ref x1 'b)
             (slot-ref x1 'c)
             (slot-bound? x1 'x)))

(test* "instance update (y1)" '(#f 0 1 2 3 4)
       (list (slot-bound? y1 'x)
             (slot-ref y1 'a)
             (slot-ref y1 'b)
             (slot-ref y1 'c)
             (slot-ref y1 'd)
             (slot-ref y1 'e)))

(test* "redefine <x> again" '(a c x)
       (begin
         (eval '(define-class <x> () (a c (x :init-value 3))) (current-module))
         (eval '(map car (class-slots <x>)) (current-module))))

(test* "instance update (x1)" '(1 #f -6 3)
       (begin
         (slot-set! x1 'a 1)
         (list (slot-ref x1 'a)
               (slot-exists? x1 'b)
               (slot-ref x1 'c)
               (slot-ref x1 'x))))

(test* "instance update (x2) - cascade" '(#t -7 #f -9 3)
       (list (is-a? x2 <x>)
             (slot-ref x2 'a)
             (slot-exists? x2 'b)
             (slot-ref x2 'c)
             (slot-ref x2 'x)))

(test* "redefine <y>" '(a e c x)
       (begin
         (eval '(define-class <y> (<x>)
                  ((a :accessor a-of)
                   (e :init-value -200)))
               (current-module))
         (eval '(map car (class-slots <y>)) (current-module))))

(test* "instance update (y2) - cascade"
       '(5 7 9 3)
       (map (lambda (s) (slot-ref y2 s)) '(a c e x)))

(test* "redefine <y> without inheriting <x>" '(a e)
       (begin
         (eval '(define-class <y> ()
                  ((a :init-keyword :a :init-value -30)
                   (e :init-keyword :e :init-value -40)))
               (current-module))
         (eval '(map car (class-slots <y>)) (current-module))))

(test* "link consistency <y> vs <x>" '(#f #f #f)
       (list (memq <y> (ref <x> 'direct-subclasses))
             (memq <y>-orig (ref <x> 'direct-subclasses))
             (memq <x> (ref <y> 'direct-supers))))

(test* "instance update (y1)" '(0 4)
       (map (lambda (s) (slot-ref y1 s)) '(a e)))

(test* "subclass redefinition <w>" '(e f a)
       (map car (class-slots <w>)))

(test* "instance update (w1)" '(#f #t #t 100 104 105)
       (list (is-a? w1 <x>)
             (is-a? w1 <y>)
             (is-a? w1 <z>)
             (slot-ref w1 'a)
             (slot-ref w1 'e)
             (slot-ref w1 'f)))

(test* "instance update (w2)" '(#f #t #t -30 #f #f)
       (list (is-a? w2 <x>)
             (is-a? w2 <y>)
             (is-a? w2 <z>)
             (slot-ref w2 'a)
             (slot-bound? w2 'e)
             (slot-bound? w2 'f)))

(test* "method link fix"
       '(#t #t #t #t #t #t #t)
       (list (method-link-check redef-test1 <x>)
             (method-link-check redef-test1 <y>)
             (method-link-check redef-test1 <w>)
             (method-link-check redef-test1 <w2>)
             (method-link-check redef-test2 <x>)
             (method-link-check redef-test2 <y>)
             (method-link-check redef-test2 <w>)))


;;----------------------------------------------------------------
(test-section "object comparison protocol")

(define-class <cmp> () ((x :init-keyword :x)))

(define-method object-equal? ((x <cmp>) (y <cmp>))
  (equal? (slot-ref x 'x) (slot-ref y 'x)))

(define-method object-compare ((x <cmp>) (y <cmp>))
  (compare (slot-ref x 'x) (slot-ref y 'x)))

(test* "object-equal?" #t
       (equal? (make <cmp> :x 3) (make <cmp> :x 3)))

(test* "object-equal?" #f
       (equal? (make <cmp> :x 3) (make <cmp> :x 2)))

(test* "object-equal?" #t
       (equal? (make <cmp> :x (list 1 2))
               (make <cmp> :x (list 1 2))))

(test* "object-equal?" #f
       (equal? (make <cmp> :x 5) 5))

(test* "object-compare" -1 (compare 0 1))
(test* "object-compare" 0  (compare 0 0))
(test* "object-compare" 1  (compare 1 0))
(test* "object-compare" -1 (compare "abc" "abd"))
(test* "object-compare" 0  (compare "abc" "abc"))
(test* "object-compare" 1  (compare "abd" "abc"))
(test* "object-compare" -1 (compare #\a #\b))
(test* "object-compare" 0  (compare #\a #\a))
(test* "object-compare" 1  (compare #\b #\a))
(test* "object-compare" *test-error* (compare #\b 4))
(test* "object-compare" *test-error* (compare "zzz" 4))
(test* "object-compare" *test-error* (compare 2+i 3+i))
(test* "object-compare" -1 (compare (make <cmp> :x 3) (make <cmp> :x 4)))
(test* "object-compare" 0 (compare (make <cmp> :x 3) (make <cmp> :x 3)))
(test* "object-compare" 1 (compare (make <cmp> :x 4) (make <cmp> :x 3)))

;;----------------------------------------------------------------
(test-section "object hash protocol")

(test* "object-hash" *test-error*
       (hash (make <cmp> :x (list 1 2))))

(define-method object-hash ((obj <cmp>))
  (+ (hash (slot-ref obj 'x)) 1))

(test* "object-hash" (+ (hash (list 1 2)) 1)
       (hash (make <cmp> :x (list 1 2))))
(test* "object-hash" (hash (make <cmp> :x (list 1 2)))
       (hash (make <cmp> :x (list 1 2))))
(test* "object-hash" (+ (hash (vector 'a 'b)) 1)
       (hash (make <cmp> :x '#(a b))))
(test* "object-hash" (+ (hash "ab") 1)
       (hash (make <cmp> :x "ab")))
;; NB: the following test is not necessarily be false theoretically,
;; but we know the two returns different values in our implementation.
(test* "object-hash" #f
       (equal? (hash (make <cmp> :x (cons 1 2)))
               (hash (make <cmp> :x (cons 2 1)))))

(use srfi-1)

(define xht (make-hash-table 'equal?))

(test* "a => 8" 8
       (begin
         (hash-table-put! xht (make <cmp> :x 'a) 8)
         (hash-table-get  xht (make <cmp> :x 'a))))

(test* "b => non" #t
       (hash-table-get  xht (make <cmp> :x 'b) #t))

(test* "b => error" *test-error*
       (hash-table-get  xht (make <cmp> :x 'b)))

(test* "b => \"b\"" "b"
       (begin
         (hash-table-put! xht (make <cmp> :x 'b) "b")
         (hash-table-get  xht (make <cmp> :x 'b))))

(test* "2.0 => #\C" #\C
       (begin
         (hash-table-put! xht (make <cmp> :x 2.0) #\C)
         (hash-table-get  xht (make <cmp> :x 2.0))))

(test* "2.0 => #\c" #\c
       (begin
         (hash-table-put! xht (make <cmp> :x 2.0) #\c)
         (hash-table-get  xht (make <cmp> :x 2.0))))

(test* "87592876592374659237845692374523694756 => 0" 0
       (begin
         (hash-table-put! xht
                          (make <cmp> :x 87592876592374659237845692374523694756) 0)
         (hash-table-get  xht
                          (make <cmp> :x 87592876592374659237845692374523694756))))

(test* "87592876592374659237845692374523694756 => -1" -1
       (begin
         (hash-table-put! xht
                          (make <cmp> :x 87592876592374659237845692374523694756) -1)
         (hash-table-get  xht
                          (make <cmp> :x 87592876592374659237845692374523694756))))

(test* "equal? test" 5
       (begin
         (hash-table-put! xht (make <cmp> :x (string #\d)) 4)
         (hash-table-put! xht (make <cmp> :x (string #\d)) 5)
         (length (hash-table-keys xht))))

(test* "equal? test" 6
       (begin
         (hash-table-put! xht (make <cmp> :x (cons 'a 'b)) 6)
         (hash-table-put! xht (make <cmp> :x (cons 'a 'b)) 7)
         (length (hash-table-keys xht))))

(test* "equal? test" 7
       (begin
         (hash-table-put! xht (make <cmp> :x (vector (cons 'a 'b) 3+3i)) 60)
         (hash-table-put! xht (make <cmp> :x (vector (cons 'a 'b) 3+3i)) 61)
         (length (hash-table-keys xht))))

(test* "hash-table-values" #t
       (lset= equal? (hash-table-values xht) '(8 "b" #\c -1 5 7 61)))

(test* "delete!" #f
       (begin
         (hash-table-delete! xht (make <cmp> :x (vector (cons 'a 'b) 3+3i)))
         (hash-table-get xht (make <cmp> :x (vector (cons 'a 'b) 3+3i)) #f)))

;;----------------------------------------------------------------
(test-section "object-apply protocol")

(define-class <applicable> ()
  ((v :initform (make-vector 5 #f))))

(define-method object-apply ((self <applicable>) (i <integer>))
  (vector-ref (ref self 'v) i))

(define-method (setter object-apply) ((self <applicable>) (i <integer>) v)
  (vector-set! (ref self 'v) i v))

(define-method object-apply ((self <applicable>) (s <symbol>))
  (case s
    ((list)   (vector->list (ref self 'v)))
    ((vector) (ref self 'v))
    (else #f)))

(define applicable (make <applicable>))

(test* "object-apply" #f (applicable 2))
(test* "object-apply" 'a
       (begin (set! (applicable 3) 'a) (applicable 3)))
(test* "object-apply" '(d b c a q)
       (begin
         (for-each (lambda (i v) (set! (applicable i) v))
                   '(2 4 1 0) '(c q b d))
         (map applicable '(0 1 2 3 4))))
(test* "object-apply" '((d b c a q) #(d b c a q))
       (map applicable '(list vector)))

;;----------------------------------------------------------------
(test-section "metaclass")

(define-class <listing-class> (<class>)
  ((classes :allocation :class :init-value '() :accessor classes-of))
  )

(define-method initialize ((class <listing-class>) initargs)
  (next-method)
  (set! (classes-of class) (cons (class-name class) (classes-of class))))

(define-class <xx> ()
  ()
  :metaclass <listing-class>)

(define-class <yy> (<xx>)
  ())

(test* "metaclass" '(<yy> <xx>)
       (class-slot-ref <listing-class> 'classes))

(define-class <auto-accessor-class> (<class>)
  ())

(define-method initialize ((class <auto-accessor-class>) initargs)
  (let ((slots (get-keyword :slots initargs '())))
    (for-each (lambda (slot)
                (unless (get-keyword :accessor (cdr slot) #f)
                  (set-cdr! slot (list* :accessor
                                        (string->symbol
                                         (format #f "~a-of" (car slot)))
                                        (cdr slot)))))
              slots)
    (next-method)))

(define-class <zz> ()
  (a b c)
  :metaclass <auto-accessor-class>)

(test* "metaclass" '(1 2 3)
       (let ((zz (make <zz>)))
         (set! (a-of zz) 1)
         (set! (b-of zz) 2)
         (set! (c-of zz) 3)
         (map (lambda (s) (slot-ref zz s)) '(a b c))))

(define-class <uu> (<zz>)
  (d e f))

(test* "metaclass" '(1 2 3 4 5 6)
       (let ((uu (make <uu>)))
         (set! (a-of uu) 1)
         (set! (b-of uu) 2)
         (set! (c-of uu) 3)
         (set! (d-of uu) 4)
         (set! (e-of uu) 5)
         (set! (f-of uu) 6)
         (map (lambda (s) (slot-ref uu s)) '(a b c d e f))))

(define-class <vv> (<zz> <xx>)
  ())

(test* "metaclass" '(1 2 3)
       (let ((vv (make <vv>)))
         (set! (a-of vv) 1)
         (set! (b-of vv) 2)
         (set! (c-of vv) 3)
         (map (lambda (s) (slot-ref vv s)) '(a b c))))
(test "metaclass" '(<vv> <yy> <xx>)
      (lambda () (class-slot-ref <listing-class> 'classes)))

(define-class <ww> (<uu> <yy>)
  ())

(test* "metaclass" #t
       (eq? (class-of <ww>) (class-of <vv>)))
(test* "metaclass" '(1 2 3 4 5 6)
       (let ((ww (make <ww>)))
         (set! (a-of ww) 1)
         (set! (b-of ww) 2)
         (set! (c-of ww) 3)
         (set! (d-of ww) 4)
         (set! (e-of ww) 5)
         (set! (f-of ww) 6)
         (map (lambda (s) (slot-ref ww s)) '(a b c d e f))))
(test* "metaclass" '(<ww> <vv> <yy> <xx>)
       (class-slot-ref <listing-class> 'classes))

;;----------------------------------------------------------------
(test-section "metaclass w/ slots")

(define-class <docu-meta> (<class>)
  ((sub :accessor sub-of)
   (doc :init-keyword :doc :initform #f)))

(define-method initialize ((self <docu-meta>) initargs)
  (next-method)
  (set! (sub-of self) "sub"))

(define-class <xxx> ()
  (a b c)
  :metaclass <docu-meta>
  :doc "Doc doc")

(test* "class slot in meta" '("Doc doc" "sub")
       (list (slot-ref <xxx> 'doc)
             (slot-ref <xxx> 'sub)))

(define-class <docu-meta-sub> (<docu-meta>)
  ((xtra :init-value 'xtra)))

(define-class <xxx-sub> (<xxx>)
  (x y z)
  :metaclass <docu-meta-sub>)

(test* "class slot in meta (sub)" '(#f "sub" xtra)
       (list (slot-ref <xxx-sub> 'doc)
             (slot-ref <xxx-sub> 'sub)
             (slot-ref <xxx-sub> 'xtra)))

;;----------------------------------------------------------------
(test-section "metaclass/singleton")

(use gauche.singleton)

(define-class <single> ()
  ((foo :init-keyword :foo :initform 4))
  :metaclass <singleton-meta>)

(define single-obj (make <single> :foo 5))

(test* "singleton" #t (eq? single-obj (make <single>)))

(test* "singleton" #t (eq? single-obj (instance-of <single>)))

(test* "singleton" 5 (slot-ref (make <single>) 'foo))

(define-class <single-2> () () :metaclass <singleton-meta>)

(test* "singleton" #f (eq? single-obj (make <single-2>)))

;;----------------------------------------------------------------
(test-section "metaclass/validator")

(use gauche.mop.validator)

(define-class <validator> ()
  ((a :accessor a-of
      :initform 'doo
      :validator (lambda (obj value) (x->string value)))
   (b :accessor b-of
      :initform 99
      :validator (lambda (obj value)
                   (if (integer? value)
                       value
                       (error "integer required for slot b")))))
  :metaclass <validator-meta>)

(define v (make <validator>))

(test* "validator" "doo" (slot-ref v 'a))
(test* "validator" "foo" (begin (slot-set! v 'a 'foo) (slot-ref v 'a)))
(test* "validator" "1234" (begin (set! (a-of v) 1234)  (a-of v)))
(test* "validator" 99 (slot-ref v 'b))
(test* "validator" 55 (begin (slot-set! v 'b 55) (slot-ref v 'b)))

(test* "validator" *test-error* (slot-set! v 'b 3.4))
(test* "validator" *test-error* (set! (b-of v) 3.4))

;;----------------------------------------------------------------
(test-section "metaclass/propagate")

(use gauche.mop.propagate)

(define-class <propagate-x> ()
  ((value :init-keyword :value :init-value 3)))

(define-class <propagate-y> ()
  ((x0 :init-keyword :x0 :init-form (make <propagate-x> :value 0))
   (x1 :init-keyword :x1 :init-form (make <propagate-x> :value 1))
   (value :allocation :propagated :propagate 'x0 :init-keyword :value)
   (vv    :allocation :propagated :propagate '(x1 value)))
  :metaclass <propagate-meta>)

(test* "propagate ref default" '(0 0)
       (let* ((y (make <propagate-y>))
              (x (slot-ref y 'x0)))
         (list (slot-ref y 'value)
               (slot-ref x 'value))))
(test* "propagate ref init" '(3 1)
       (let ((y (make <propagate-y> :x0 (make <propagate-x>))))
         (list (slot-ref y 'value) (slot-ref y 'vv))))
(test* "propagate ref init2" '(99 99)
       (let* ((y (make <propagate-y> :x0 (make <propagate-x>) :value 99))
              (x (slot-ref y 'x0)))
         (list (slot-ref y 'value)
               (slot-ref x 'value))))

(test* "propagate set" '(888 888)
       (let ((y (make <propagate-y>)))
         (set! (slot-ref y 'value) 888)
         (list (slot-ref y 'value) (slot-ref (slot-ref y 'x0) 'value))))

(test* "propagate set" '(999 999)
       (let ((y (make <propagate-y>)))
         (set! (slot-ref y 'vv) 999)
         (list (slot-ref y 'vv) (slot-ref (slot-ref y 'x1) 'value))))

(define-class <propagate-validator-meta> (<validator-meta>
                                          <propagate-meta>)
  ())

(define-class <propagate-validator> ()
  ((x :initform (make <propagate-x>))
   (value :allocation :propagated :propagate 'x
          :validator (lambda (o v) (x->string v)))
   )
  :metaclass <propagate-validator-meta>)

(test* "propagate-validator" "999"
       (let ((y (make <propagate-validator>)))
         (set! (slot-ref y 'value) 999)
         (slot-ref y 'value)))

;;----------------------------------------------------------------
(test-section "metaclass/instance-pool")

(use srfi-1)
(use gauche.mop.instance-pool)

(define-class <pool-meta> (<instance-pool-meta>)
  (a b c))

(define-class <pool-x> (<instance-pool-mixin>) ())
(define-class <pool-y> (<instance-pool-mixin>) () :metaclass <pool-meta>)
(define-class <pool-z> (<pool-x> <pool-y>) ())

(define pool-x1 (make <pool-x>))
(define pool-z1 (make <pool-z>))
(define pool-y1 (make <pool-y>))
(define pool-y2 (make <pool-y>))
(define pool-x2 (make <pool-x>))
(define pool-z2 (make <pool-z>))

(test* "instance-pool (pool)" #t
       (and (memq pool-x1 (instance-pool->list <pool-x>))
            (memq pool-x2 (instance-pool->list <pool-x>))
            (not (memq pool-y1 (instance-pool->list <pool-x>)))
            (not (memq pool-y2 (instance-pool->list <pool-x>)))
            (memq pool-y1 (instance-pool->list <pool-y>))
            (memq pool-y2 (instance-pool->list <pool-y>))
            (not (memq pool-x1 (instance-pool->list <pool-y>)))
            (not (memq pool-x2 (instance-pool->list <pool-y>)))
            (memq pool-z1 (instance-pool->list <pool-x>))
            (memq pool-z1 (instance-pool->list <pool-y>))
            #t
            ))

(test* "instance-pool-find" pool-x1
       (instance-pool-find <pool-x> (cut eq? pool-x1 <>)))

(test* "instance-pool-find" pool-z1
       (instance-pool-find <pool-x> (cut eq? pool-z1 <>)))

(test* "instance-pool-find" pool-y1
       (instance-pool-find <pool-y> (cut eq? pool-y1 <>)))

(test* "instance-pool-find" #f
       (instance-pool-find <pool-x> (cut eq? pool-y2 <>)))

(test* "instance-pool-fold" (list pool-x1 pool-z1 pool-x2 pool-z2)
       (instance-pool-fold <pool-x> cons '())
       (cut lset= eq? <> <>))

(test* "instance-pool-map" (list pool-x1 pool-z1 pool-x2 pool-z2)
       (instance-pool-map <pool-x> identity)
       (cut lset= eq? <> <>))

(test* "instance-pool-for-each" (list pool-x1 pool-z1 pool-x2 pool-z2)
       (let ((r '()))
         (instance-pool-for-each <pool-x> (lambda (p) (push! r p)))
         r)
       (cut lset= eq? <> <>))

(test* "instance-pool-remove!" #f
       (begin
         (instance-pool-remove! <pool-x> (cut eq? pool-z1 <>))
         (instance-pool-find <pool-x> (cut eq? pool-z1 <>))))

(test* "instance-pool-remove!" pool-z1
       (instance-pool-find <pool-y> (cut eq? pool-z1 <>)))

(test* "instance-pool-remove!" #f
       (begin
         (instance-pool-remove! <pool-z> (cut eq? pool-z2 <>))
         (or (instance-pool-find <pool-x> (cut eq? pool-z2 <>))
             (instance-pool-find <pool-y> (cut eq? pool-z2 <>)))))

(test-end)

