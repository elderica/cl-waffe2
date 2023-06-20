

(in-package :cl-waffe2/base-impl.test)

(in-suite :base-impl-test)

;; Testing APIs provides by cl-waffe2/base-impl

;; !add !sub !mul !div
;; reshape proceed proceeed-backward !view ->scal ->mat

(defmacro lproceed (tensor)
  `(with-devices (cl-waffe2/backends.lisp:LispTensor)
     (proceed ,tensor)))

;; =============================================================
;; Testing general-purpose arithmetic APIs: !add !sub !mul !div.
;; =============================================================

(test test-add-form
  ;; Scalar And Scalar
  (is (= (tensor-vec
	  (lproceed (!add 1.0 1.0)))
	 2.0))
  ;; Scalar And Matrix
  (is (= (vref
	  (lproceed (!add (make-tensor `(10 10) :initial-element 1.0) 1.0))
	  0)
	 2.0))
  ;; Matrix and Scalar
  (is (= (vref
	  (lproceed (!add 1.0 (make-tensor `(10 10) :initial-element 1.0)))
	  0)
	 2.0))

  ;; Matrix and matrix
  (is (= (vref
	  (lproceed (!add (make-tensor `(10 10) :initial-element 1.0) (make-tensor `(10 10) :initial-element 1.0)))
	  0)
	 2.0)))


(test test-sub-form
  ;; Scalar And Scalar
  (is (= (tensor-vec
	  (lproceed (!sub 1.0 1.0)))
	 0.0))
  ;; Scalar And Matrix
  (is (= (vref
	  (lproceed (!sub (make-tensor `(10 10) :initial-element 2.0) 1.0))
	  0)
	 1.0))
  ;; Matrix and Scalar
  (is (= (vref
	  (lproceed (!sub 1.0 (make-tensor `(10 10) :initial-element 2.0)))
	  0)
	 -1.0))

  ;; Matrix and matrix
  (is (= (vref
	  (lproceed (!sub (make-tensor `(10 10) :initial-element 1.0)
			  (make-tensor `(10 10) :initial-element 1.0)))
	  0)
	 0.0)))


(test test-mul-form
  ;; Scalar And Scalar
  (is (= (tensor-vec
	  (lproceed (!mul 1.0 1.0)))
	 1.0))
  ;; Scalar And Matrix
  (is (= (vref
	  (lproceed (!mul (make-tensor `(10 10) :initial-element 2.0) 3.0))
	  0)
	 6.0))
  ;; Matrix and Scalar
  (is (= (vref
	  (lproceed (!mul 1.0 (make-tensor `(10 10) :initial-element 3.0)))
	  0)
	 3.0))

  ;; Matrix and matrix
  (is (= (vref
	  (lproceed (!mul (make-tensor `(10 10) :initial-element 1.0)
			  (make-tensor `(10 10) :initial-element 1.0)))
	  0)
	 1.0)))


(test test-div-form
  ;; Scalar And Scalar
  (is (= (tensor-vec
	  (lproceed (!div 1.0 1.0)))
	 1.0))
  ;; Scalar And Matrix
  (is (= (vref
	  (lproceed (!div (make-tensor `(10 10) :initial-element 6.0) 3.0))
	  0)
	 2.0))
  ;; Matrix and Scalar
  (is (= (vref
	  (lproceed (!div 10.0 (make-tensor `(10 10) :initial-element 2.0)))
	  0)
	 5.0))

  ;; Matrix and matrix
  (is (= (vref
	  (lproceed (!mul (make-tensor `(10 10) :initial-element 1.0)
			  (make-tensor `(10 10) :initial-element 1.0)))
	  0)
	 1.0)))

;; =============================================================
;; Testing !reshape ->scal ->mat !unsqueeze !squeeze
;; =============================================================

;; Note: !view ... testing with !sum !mean

(test reshaping-test
  (is (equal (shape (!reshape (make-tensor `(10 10)) 100))
	     `(100)))
  (is (equal (shape (!reshape (make-tensor `(10 10)) t))
	     `(100))))

(test ->scal-test
  (is (scalar-p (->scal (make-tensor `(1 1))))))

(test ->mat-test
  (is (equal `(1)   (shape (->mat (make-tensor 1.0)))))
  (is (equal `(1 1) (shape (->mat (make-tensor 1.0) :dims 2)))))

;; =============================================================
;; Testing proceed proceed-backward
;; =============================================================

;; =============================================================
;; Testing !flexible, broadcasting
;; =============================================================

(test flexible-test
  (is (!add (make-tensor `(10 10)) (!flexible (make-tensor `(10))))))

