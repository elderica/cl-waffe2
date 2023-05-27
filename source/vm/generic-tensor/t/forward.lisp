

(in-package :cl-waffe2/vm.nodes.generic-tensor.test)

(in-suite :test-tensor)


;; Problems: Compile-Speed (add config) (there's no need)
;; (10 a) (10 10) <- a = 10 (DONE)

;; Making Add/Sub/Mul/Div Nodes
;; OpenBLAS/Common Lisp backend.
;; update: construct-forward (InputTensor UI)
;; add:    construct-backward
;; view -> view.
;; ViewNode

(defun test-simple-forward ()
  (with-single-device (LispTensor)
    (let ((out (!add (make-tensor `(10 10))
		     (make-tensor `(10 10)))))
      (funcall (construct-forward out)))))

(defun test-simple-forward-with-view ()
  (with-single-device (LispTensor)
    (let ((out (!add (view (make-tensor `(10 1)) t `(:broadcast 10))
		     (make-tensor `(10 10)))))
      (funcall (construct-forward out)))))

(test test-forward
  (is (test-simple-forward)))

(test forward-with-view-simple-test
  (is (test-simple-forward-with-view)))


;; Still in Concept Stage but illustrates what cl-waffe can do.
(defun test-complicated-network-forward ()
  ;; with-devices ... 使用するTensorの優先順位
  ;; LispTensor <- Common Lispで書かれたカーネル(SIMD化はAVX2まで)
  ;; CPUTensor  <- Accelerated by OpenBLAS
  (with-devices (LispTensor)

    ;; make-input  -> InputTensorを初期化する (Shapeの形状が決定してなくてOK)
    ;; make-tensor -> AbstractTensorを初期化する (Shapeの形状が決定している必要がある + backendに応じてメモリをallocate)
    
    (let* ((train-x (make-input `(batch-size 256) :train-x))
	   (weight  (make-tensor `(100 256) :requires-grad t))
	   (bias    (make-tensor `(1 256)   :requires-grad t)))

      (let ((out (!add (!mul train-x weight) (view bias `(:broadcast 100) t))))
	(multiple-value-bind (forward variables parameters) (construct-forward out)

	  ;; InputTensorに実際の学習データを与える
	  (embody-input (getf variables :train-x) (make-tensor `(100 256)))
	  (print variables)  ;; 変数一覧
	  (print parameters) ;; Optimizerに渡す変数たち
	  (time (funcall forward))
	  (time (funcall forward))
	  )))))

