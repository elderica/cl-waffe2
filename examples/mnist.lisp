(in-package :cl-user)

(defpackage :mnist-example
  (:use
   :cl
   :cl-waffe2
   :cl-waffe2/nn
   :cl-waffe2/distributions
   :cl-waffe2/base-impl
   :cl-waffe2/vm.generic-tensor
   :cl-waffe2/vm.nodes))

(in-package :mnist-example)

;; Things to add:
;; !matmul !t !t backward tests
;; defoptimizer/deftrainer
;; Numpy tensor loadder
;; Training MLP

;; To ADD:
;; call->
;; sequence
;; deftrainer

;; TO ADD:
;; (call-> x layer1 layer2 layer3)
;; (x = (sequence (LinearLayer1 (LinearLayer2 ...

;; ugly...
;; call -> Node

;; one more ugly part: defmodel

#|
(defmodel (MLP-Model (self)
	   :slots ((layer1 :initarg :layer1 :accessor mlp-layer1)
		   (layer2 :initarg :layer2 :accessor mlp-layer2)
		   (layer3 :initarg :layer3 :accessor mlp-layer3))
	   :initargs (:layer1 (LinearLayer 784 512)
		      :layer2 (LinearLayer 512 256)
		      :layer3 (LinearLayer 256 10))
	   :on-call-> ((self x)
		       (call-> x
			       (slot-value self 'layer1)
			       (asnode #'!tanh)
			       (slot-value self 'layer2)
			       (asnode #'!tanh)
			       (slot-value self 'layer3)
			       (asnode #'!softmax)))))
|#

(defsequence MLP-Sequence (in-features hidden-dim out-features
			   &key (activation #'!relu))
	     "Three Layers MLP Model"
	     (LinearLayer in-features hidden-dim)
	     (asnode activation)
	     (LinearLayer hidden-dim hidden-dim)
	     (asnode activation)
	     (LinearLayer hidden-dim out-features))

;; TODO
;; 1. TO FIX: forward with batch-size (save-for-backward) (OK)
;; 2. TODO: criterion.lisp
;; 3. TODO: cl-waffe2/nn
;; 4. TODO: defoptimizer
;; 5. TODO: Documentations, Slides.


(deftrainer (MLPTrainer (self in-class out-class
			      &key (hidden-size 256))
	     :model     (MLP-Sequence in-class hidden-size out-class)
	     :optimizer (cl-waffe2/optimizers:SGD :lr 1e-3)
	     :build ((self)
		     (let ((out (!mean (softmax-cross-entropy
					(call
					 (model self)
					 (make-input `(batch-size ,in-class)  :X))
					(make-input `(batch-size  ,out-class) :Y)))))
		       out))
	     :minimize! ((self out)
			 (zero-grads! (model self))
			 (forward out)
			 (backward out)
			 (optimize!   (model self)))
	     :step-train ((self x y)
			  (set-input (model self) :X x)
			  (set-input (model self) :Y y))
	     :predict ((self x)
		       (call (model self) x))))


(defun build-mlp-test (&key
			 (x (make-input `(batch-size 784) :X))
			 (y (make-input `(batch-size 10)  :Y)))
  (let* ((model (MLP-Sequence 784 256 10))
	 (pred  (call model x))
	 (out (!mean (cl-waffe2/nn::softmax-cross-entropy pred y)))
	 (compiled-model (build out)))
    compiled-model))

(defun test-model ()
  (let ((compiled-model (build-mlp-test)))
    (set-input compiled-model :X (randn `(100 784)))
    (set-input compiled-model :Y (randn `(100 10)))
    (forward compiled-model)
    (time (forward compiled-model))
    (time (backward compiled-model))))

