
(in-package :cl-user)

(defpackage :cl-waffe2/nn
  (:use :cl :cl-waffe2 :cl-waffe2/distributions :cl-waffe2/base-impl :cl-waffe2/vm.nodes :cl-waffe2/vm.generic-tensor :cl-waffe2/threads)

  ;; LinearLayer
  (:export
   #:weight-of
   #:bias-of)
  
  (:export
   #:LinearLayer
   #:Linear-weight
   #:Linear-bias)

  (:export
   #:Conv2D
   #:apply-conv2d
   #:!im2col-cpu

   #:MaxPool2D
   #:AvgPool2D)

  ;; Criterions
  (:export
   #:L1Norm
   #:MSE
   #:cross-entropy-loss
   #:softmax-cross-entropy
   )
  
  (:export
   #:!relu
   #:!sigmoid
   #:!gelu
   #:!softmax))

(in-package :cl-waffe2/nn)

