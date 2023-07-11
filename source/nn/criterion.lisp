
(in-package :cl-waffe2/nn)

;; TODO: ================================
;; L1
;; BinaryCrossEntropy
;; KLdiv
;; CosineSim (rather than distance.lisp?)

;; MSE
;; SoftMaxCrossEntropy
;; BSE
;; ======================================

(defun L1Norm (x y &key (reduction :mean))
  "
## [function] L1Norm

```
(L1Norm x p &key (:reduction :mean))
```

Returns a tensor that measures L1 Norm between each element in the input `x` and `y`.

```math
l(x, y) = L = {l_1, ..., l_n}^\\intercal, l_n = abs(x_n - y_n)
```

where `N` is a batch-size.

In addition, reading the value of a `:reduction` keyword (one of `:mean` `:sum` `nil`), the result of `L` is reducted. (If nil, reduction is ignored.)
"
  (declare (type AbstractTensor x y)
	   (type (or nil (member :mean :sum))))
  
  (let ((l (!sub x y)))
    (case reduction
      (:sum
       (!sum (!abs l)))
      (:mean
       (!mean (!abs l)))
      (T (!abs l)))))

(defun mse (x y &key (reduction :mean))
  "
## [function] mse
```
(mse x p &key (:reduction :mean))
```
Returns a tensor that measures the MSE error (L2Norm) between each element in the input `x` and `y`.

```math
l(x, y) = L = {l_1, ..., l_n}^\\intercal, l_n = (x_n - y_n)^2
```

where `N` is a batch-size.

In addition, reading the value of a `:reduction` keyword (one of `:mean` `:sum` `nil`), the result of `L` is reducted. (If nil, reduction is ignored.)
"
  (declare (type AbstractTensor x y)
	   (type (or nil (member :mean :sum))))
  
  (let ((l (!sub x y)))
    (case reduction
      (:sum
       (!sum (!mul l l)))
      (:mean
       (!mean (!mul l l)))
      (T (!mul l l)))))


(defmodel (Softmax-Cross-Entropy-Forward (self &key (delta 1e-7) (avoid-overflow t))
	   :slots ((delta :initarg :delta :reader delta)
		   (avoid-overflow :initarg :avoid-overflow :reader avoid-overflow))
	   :where (X[~ length n-dimension] Labels[~ length n-dimension] -> OUT[~ length n-dimension])
	   :on-call-> ((self x labels)
		       (with-slots ((delta delta) (avoid-overflow avoid-overflow)) self
			 (let ((z (!softmax x :avoid-overflow avoid-overflow)))
			   (cross-entropy-loss z labels :delta delta))))))

(defmodel (Softmax-Cross-Entropy-Backward (self &key (avoid-overflow t))
	   :slots ((avoid-overflow :initarg :avoid-overflow :reader avoid-overflow))
	   :where (Dy[~ length n-dimension] X[~ length n-dimension] Labels[~ length n-dimension] Batch-Size[scal] -> X.grad[~ length n-dimension] where scal = 1)
	   :on-call-> ((self dy x labels coeff)
		       (with-slots ((avoid-overflow avoid-overflow)) self
			 (let* ((z  (!sub (!softmax x :avoid-overflow avoid-overflow) labels))
				(dx (!div (!mul dy z) coeff)))
			   (values dx))))))

(define-composite-function (Softmax-Cross-Entropy-Forward)  static-softmax-cross-entropy-forward)
(define-composite-function (Softmax-Cross-Entropy-Backward) static-softmax-cross-entropy-backward)

(define-static-node (Softmax-Cross-Entropy-Node (self &key (delta 1e-7) (avoid-overflow t))
		     :slots ((delta :initarg :delta :reader delta)
			     (avoid-overflow :initarg :avoid-overflow :reader avoid-overflow))
		     :where (X[~ length n-dimension] Labels[~ length n-dimension] -> OUT[~ length n-dimension])
		     :save-for-backward-names (x labels)
		     :forward ((self x labels)
			       (with-setting-save4bw ((x x) (labels labels)) self
				 (static-softmax-cross-entropy-forward x labels)))
		     :backward ((self dout)
				(with-reading-save4bw ((x x) (labels labels)) self
				  (static-softmax-cross-entropy-backward
				   dout
				   x
				   labels 
				   (make-tensor (car (last (shape x) 2) ) :dtype (dtype x)))))))


(defun cross-entropy-loss (x labels &key (delta 1e-7))
  "
## [fucntion] cross-entropy-loss

```lisp
(cross-entropy-loss x labels &key (eps 1e-y))
```

Returns a tensor that measures the Cross-Entropy-Error between each element in the x and labels
(TODO): Label-Smoothing
"

  ;; KLDiv: xlogp
  (!mul -1 (!mean (!mul labels (!loge (!add x delta))))))

(defun softmax-cross-entropy (x labels &key (delta 1e-7))
  "
## [function] softmax-cross-entropy
"

  (call (Softmax-Cross-Entropy-Node) x labels))
