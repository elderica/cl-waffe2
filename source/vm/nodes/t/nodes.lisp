
(in-package :cl-waffe2/vm.nodes.test)

(in-suite :test-nodes)

;; After Implementing Tensor

(defnode (Bijective-Function (myself)
	  :where `([x y] [x y] -> [x y])
	  :documentation "Bijective-Function has a one-to-one correspondence."))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defclass MyBackend (AbstractTensor) nil)
  (defclass MyBackend-With-Impl (AbstractTensor) nil))

(define-impl (Bijective-Function :device CPUTensor)
	     :forward ((self x)
		       `(values ,x))
	     :backward ((self dy)
			`(values ,dy)))


(define-impl (Bijective-Function :device MyBackend-With-Impl)
	     :forward ((self x)
		       `(values ,x))
	     :backward ((self dy)
			`(values ,dy)))

(defun test-switch-backend1 ()
  (with-devices (CPUTensor)
    (typep (Bijective-Function) 'CL-WAFFE2/VM.NODES.FACETS-TMP::BIJECTIVE-FUNCTION-CPUTENSOR)))

(defun test-switch-backend2 ()
  (with-devices (MyBackend CPUTensor)
    (typep (Bijective-Function) 'CL-WAFFE2/VM.NODES.FACETS-TMP::BIJECTIVE-FUNCTION-CPUTENSOR)))

(defun test-switch-backend3 ()
  (with-devices (MyBackend-with-impl CPUTensor)
    (typep (Bijective-Function) 'CL-WAFFE2/VM.NODES.FACETS-TMP::BIJECTIVE-FUNCTION-MYBACKEND-WITH-IMPL)))


(test heuristic-backend-test
  (is (test-switch-backend1))
  (is (test-switch-backend2))
  (is (test-switch-backend3)))


