
(in-package :cl-waffe2/backends.cpu)

(defclass CPUTensor (AbstractTensor) nil)

(defmethod initialize-instance :after ((tensor CPUTensor)
				       &rest initargs
				       &key &allow-other-keys)
  ;; if projected-p -> alloc new vec
  (let ((shape (getf initargs :shape))
	(dtype (dtype->lisp-type (getf initargs :dtype)))
	(vec   (getf initargs :vec))
	(facet (getf initargs :facet)))
    (when (eql facet :exist)
      (if vec
	  (setf (tensor-vec tensor) vec)
	  (setf (tensor-vec tensor)
		(make-array
		 (apply #'* shape)
		 :element-type dtype))))))
