
(in-package :cl-user)

(defpackage :mnist-example
  (:use
   :cl
   :numpy-file-format
   :cl-waffe2
   :cl-waffe2/vm.generic-tensor
   :cl-waffe2/vm.nodes
   :cl-waffe2/base-impl
   :cl-waffe2/distributions
   :cl-waffe2/nn
   :cl-waffe2/optimizers))

(in-package :mnist-example)


