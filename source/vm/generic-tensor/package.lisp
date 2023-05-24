
(in-package :cl-user)

(defpackage :cl-waffe2/vm.generic-tensor
  (:use :cl)
  (:export
   #:AbstractTensor
   #:CPUTensor

   #:tensor-prev-state
   #:tensor-prev-form
   #:tensor-variables

   )
  (:export
   #:shape
   #:make-tensor
   #:*using-backend*))

(in-package :cl-waffe2/vm.generic-tensor)
