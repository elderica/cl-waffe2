
(in-package :cl-waffe2/backends.cpu)

;; argmax/argmin/matmul

(declaim (ftype (function (boolean) (signed-byte 8)) trans->c))
(defun trans->c (transpose-specifier)
  (declare (optimize (safety 0)))
  (if transpose-specifier
      (the (signed-byte 8) (char-code #\T))
      (the (signed-byte 8) (char-code #\N))))

;; TODO: 2D Gemm
;; TODO: 1D Gemm -> Dot Product
;; TODO: Fix it.
(defun expand-gemm-form (a b out &key trans-a? trans-b?)
  "[M N] @ [N K] -> [M K]"
  (let ((dtype (dtype out)))
    (case dtype
      (:float
       ;; TODO: Check If The Tensor is continuous on memory.
       (call-with-view
	#'(lambda (a-view b-view c-view)
	    ;; a-view = [A.views[n-1], A.views[n]]
	    `(blas-sgemm
	      ,(trans->c trans-a?)
	      ,(trans->c trans-b?)
	      ,(size-of a-view 0)
	      ,(size-of a-view 1)
	      ,(size-of b-view 1)
	      1.0 ;; alpha
	      (tensor-ptr ,a :offset ,(offset-of a-view 0)) ;; a
	      ,(stride-of a-view 0) ;; LDA
	      (tensor-ptr ,b :offset ,(offset-of b-view 0)) ;; B
	      ,(stride-of b-view 0) ;; LDB
	      0.0 ;; beta
	      (tensor-ptr ,out :offset ,(offset-of c-view 0))
	      ,(stride-of c-view 0)))
	`(,a ,b ,out)
	:at-least-dim 2))
      (:double
       )
      (T
       (error "The dtype ~a isn't supported yet(TODO)." dtype)))))

(define-impl (MatMulNode :device CPUTensor)
	     :save-for-backward (t t nil)
	     :forward
	     ((self a b out)
	      (let ((trans-a (trans-a? self))
		    (trans-b (trans-b? self)))
		`(,@(expand-gemm-form a b out :trans-a? trans-a :trans-b? trans-b)
		  ,out)))
	     :backward
	     ((self dout da db do)
	      (values
	       (!matmul dout db :transpose-y (not (trans-b? self)))
	       (!matmul da dout :transpose-x (not (trans-a? self)))
	       do)))

