
(in-package :cl-waffe2/vm.generic-tensor)

;; cache.lisp is used to reuse the result of **call-with-view** in compling time, which consists larger part of generated code, and most reusable part.

;; =======================================================================
;; Goal: `3 Layers MLP's compiling time of forward and backward` << `5sec`.

;; Compiling time with cache.lisp is approximated as:
;; ```
;; O((the number of kernel types used in nodes))
;; ```
;; while without cache.lisp:
;; ```
;; O((the number of operation))
;; ```
;; =======================================================================

;; the number of kernel types used in nodes <-> compiling time of kernels in *kernel-storeroom*

;; **This Parameter isn't used anymore?**
(defparameter *cache-directory* "~/.cache/cl-waffe2/")

;; The file cache.lisp provides an optimized kernel compiler for acceptor.lisp

;;
;; (defnode (SinNode ...) ) is named as [SinNode-CPUTensor-2D]
;; being defined as like:
;; (defun Sinnode-CpuTensor-2D (...)
;;    (optimize ...)
;;    (lambda (..) ...))
;; We store such like functions to reduce compile-time.
;;

;; 1. Create a LUT to store generated and reusable s-expression.
;; ==================================================================
;; A template form of compiled cl-waffe2 programs:
;; (labels ((SinNode-CPUTensor-3D () ;; Storeroom of compiled kernels used
;;             ...
;;           )
;;          (SinNode-CPUTensor-2D ()
;;             ...
;;           ))
;;
;; (forward/backward networks continues) <- Place SinNode-CPUTensor-3D for example.
;; )
;; ==================================================================

;; What I want to do?: the compiling time of (!sin (!sin (!sin x))) and (!sin x) should be approximately the same, because they're working on the same code ignoring indicating pointer.

(defvar *kernel-storeroom* nil "An storeroom to record all kernels used in compiling time.") ;; Corresponds to: (labels ((SinNode-... )) ... )

;; An unit of compiled funciton.
(defstruct Compiled-Kernel
  (name nil :type symbol)            ;; SinNode-CPUTENSOR
  (body nil :type list)              ;; (named-lambda ... () ...)
  (cache-p nil :type boolean)
  (args nil :type list)
  (view-route nil :type list)) ;; 2D 3D Flatten ...

;; the maximum length of symbol-name used in CL shoule be 512? i dont remember ...
;; 展開されたS式と一致するか調べるべきか？
;; LUTを作成することで生まれる制約は、define-implに課す制約と同値だと思うが

(defun make-kernel-name (tensor reductable-p-map)
  "The naming rule of kernel functions is following:

[NodeName] - [Backend-Name] - [TensorViewName1] - [TensorViewName2] ...

where TensorViewNameN is:

[4D -> 3D -> 2D -> ... -> end-name]

end-name = [Flatten] or 1D

For Example:

(!sin (randn `(100 100))) -> `SinNode-LispTensor-Flatten`

(!sin (!view (randn `(100 100) `(1 -1) t)))
-> `SinNode-LispTensor-2D->Flatten`

TensorViewNameN depicts the path call-with-view traced.
"
  (flet ((template (&optional dim)
	   (if dim
	       (symb ;; {->(DIM)-BackendName[Dype]}
		'{
		(intern (format nil "->(~a)-" dim))
		(class-name (class-of tensor))
		'[
		(intern (symbol-name (dtype tensor)))
		']
		'})
	       (symb ;; {BackendName[Dtype]}
		'{
		(class-name (class-of tensor))
		'[
		(intern (symbol-name (dtype tensor)))
		']
		'}))))

    (when (scalar-p tensor)
      (return-from make-kernel-name (template)))

    (let ((name-list))
      (loop named trace-loop
	    for dim downfrom (1- (length (shape tensor))) to 0
	    if (nth dim reductable-p-map)
	      do (push (template 'flatten) name-list)
		 (return-from trace-loop)
	    else
	      do (push (template dim) name-list))
      ;; call-with-view traces following
      ;; n-1 n-2 ... 2 1 0th dim.
      (apply #'symb (reverse name-list)))))

(defun kernel-name (compiled-kernel)

  ;; 1. compute reductable-p
  ;; 2.
  ;; TODO: call-with-view generates the name.
  ;; LUTableなものは、展開式にcall-with-viewが含まれているもの
  ;; forwardの展開中にcall-with-viewが呼び出される
  ;; -> *call-with-view-traced*にたどった経路を保存する
  ;; -> そこからカーネル名を生成
  ;; -> 

  (symb
   (compiled-kernel-name compiled-kernel)
   '-
   (apply
    #'symb
    (map 'list #'(lambda (x) (make-kernel-name x (compiled-kernel-view-route compiled-kernel))) (compiled-kernel-args compiled-kernel)))))
;; &rest kernel-name

(defun place-cached-kernels (body)
  "
Reading *kernel-storeroom*, the function expands the form below.
(progn
;; [LUT PLACE]
(defun SinNode-CPUTensor-3D ()
    ...)

(defun SinNode-CPUTensor-2D ()
    ...)

...

;; Forward/Backward Process continues...
)"
  ;; Expand *kernel-storeroom*

  `(labels ((,@(loop for kernel in *kernel-storeroom*
		     if kernel
		       collect nil)))
     ,@body))

(defmacro call-kernel (kernel-function &rest inputs)
  "A replacement of (funcall fw-compiled)"
  `(funcall ,@(compiled-kernel-body kernel-function) ,@inputs))



