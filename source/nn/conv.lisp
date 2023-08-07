
(in-package :cl-waffe2/nn)

;; Implement them as sample Codes:
;; TODO: ImageProcessing:       AvgPool/MaxPool/Conv2D
;; TODO: Sequentially Modeling: RNNCell/RNN LSTMCell/LSTM GRUCell/GRU
;; TODO: Transformer Models:    MHA, LayerNorm, Dropout ...
;; TODO: Saving Model Weights
;; TODO: Optimizers: Adam RAdam


(defun maybe-tuple (value name)
  (typecase value
    (number `(,value ,value))
    (list
     (if (= (length value) 2)
	 value
	 (error "Conv2D: ~a should be given as list with length = 2, but got ~a" name value)))
    (t
     (error "Conv2D: ~a should be given as fixnum or list(with length=2), but got ~a" name value))))

(defmodel (Conv2D (self in-channels out-channels kernel-size
			&key
			(stride 1)
			(padding 0)
			(dilation 1)
			(groups 1)
			(bias t)
			&aux
			(stride (maybe-tuple stride 'stride))
			(kernel-size (maybe-tuple kernel-size 'kernel-size))
			(padding (maybe-tuple padding 'padding))
			(dilation (maybe-tuple dilation 'dilation)))
	   :documentation "
Applies a 2D convolution over an input signal composed of several input planes.


### Inputs

`in-channels[fixnum]` `out-channels[fixnum]` the number of channels. For example, if the input image is RGB, `in-channels=3`.

`kernel-size[list (kernel-x kernel-y)]` controls the size of kernel (e.g.: `'(3 3)`).

`padding[fixnum or list]` controls the amount of padding applies to the coming input. pads in X and Y direction when an integer value is entered. set a list of `(pad-x pad-y)` and pads in each direction.

`stride[fixnum or list]` controls the stride for cross-correlation. As with `padding`, this parameter can be applied for each x/y axis.

`dilation[fixnum or list]` controls the connections between inputs and outputs. in_channels and out_channels must both be divisible by groups. (currently not working, please set 1.)

`bias[boolean]` Set t to use bias.

### Parameters

Let k be `(/ groups (* in-channels (apply #'* kernel-size)))`.


`weight` is a trainable parameter of `(out-channels, in-channels / groups, kernel-size[0] kernel-size[1])` sampled from `U(-sqrt(k), sqrt(k))` distribution, and can be accessed with `weight-of`.

`bias` is a trainable parameter of `(out-channels)` sampled from `U(-sqrt(k), sqrt(k))` distribution, and can be accessed with `bias-of`.

Note: When `Conv2D` is initialised, the output is displayed as -1. This is because the calculation of the output is complicated and has been omitted. Once call is invoked, the output is recorded.
"
	   :slots ((weight :accessor weight-of)
		   (bias   :accessor bias-of)
		   (stride   :initarg :stride)
		   (padding  :initarg :padding)
		   (dilation :initarg :dilation)
		   (groups   :initarg :groups)
		   (kernel-size :initarg :kernel-size))
	   ;; Memo: C_in H_in W_in ... should be determined before computing.
	   :where (Input[N C_in H_in W_in] -> Output[N C_out H_out W_out]
			   where
			   C_in  = in-channels
			   C_out = out-channels
			   ;; H_out = floor(((H_in + 2 * padding[0] - dilation[0] * (kernel_size[0] - 1) - 1) / stride[0]) + 1)
			   H_out = (if (numberp H_in) ;; If H_in is a symbol, return -1 (=undetermined, later determined.)
				       (floor (+ 1 (/ (+ H_in (* 2 (car padding)) (* (- (car dilation)) (- (car kernel-size) 1)) -1)
						      (car stride))))
				       -1)
			   ;; W_out = floor(((W_in + 2 * padding[1] - dilation[1] * (kernel_size[1] - 1) - 1) / stride[1]) + 1)
			   W_out = (if (numberp W_in)
				       (floor (+ 1 (/ (+ W_in (* 2 (second padding)) (* (- (second dilation)) (- (second kernel-size) 1)) -1)
						      (second stride))))
				       -1))
	   :on-call-> apply-conv2d)
		       
  (assert (typep kernel-size 'list)
	  nil
	  "Conv2D: Assertion Failed because kernel-size should be given as list. but got: ~a" kernel-size)
  (let ((k (/ groups (* in-channels (apply #'* kernel-size)))))    
    (setf (weight-of self)
	  ;; Weights are (out-channels, in-channels / groups, kernel-size[0], kernel-size[1]) tensor
	  ;; which sampled from U(-sqrt(k), sqrt(k)) dist.
	  (uniform-random
	   `(,out-channels ,(/ in-channels groups) ,(car kernel-size) ,(second kernel-size))
	   (- (sqrt k))
	   (sqrt k)
	   :requires-grad t)
	  (bias-of self)
	  (when bias
	    ;; Biases are (out-channels) tensor which sampled from U(-sqrt(k), sqrt(k))
	    (uniform-random `(,out-channels) (- (sqrt k)) (sqrt k) :requires-grad t)))))


;; The implementation is messy because we tried so many different ways to implement it.
;; [TODO] Refactor conv2d for future impls of Conv3D, ConvND.
(defmethod apply-conv2d ((self Conv2D) input)
  (with-slots ((stride stride) (padding padding) (dilation dilation) (weight weight) (bias bias) (groups groups) (kernel-size kernel-size)) self
    (multiple-value-bind (in-channels h-in w-in) (apply #'values (last (shape input) 3))
      (multiple-value-bind (C-out icg k-h k-w) (apply #'values (shape weight))
	(declare (ignore icg))
	(let* ((~     (butlast (shape input) 3))
	       (p-y (mod
		     (-
		      (second stride)
		      (mod
		       (+ h-in (* 2 (second padding))
			  (- (* (second dilation) (- k-h 1))))
		       (second stride)))
		     (second stride))) ;; (sY - (iH + pY * 2 - (kH - 1) * dY) % sY) % sY
	       (p-x (mod
		     (-
		      (car stride)
		      (mod
		       (+ w-in (* 2 (car padding))
			  (- (* (car dilation) (- k-w 1))))
		       (car stride)))
		     (car stride))) ;; (sX - (iW + pX * 2 - (kW - 1) * dX) % sX) % sX
	       (h-out (floor (+ 1 (/ (+ h-in (* 2 (car padding)) (* (- (car dilation)) (- k-h 1)) -1)
				     (car stride)))))
	       (w-out (floor (+ 1 (/ (+ w-in (* 2 (second padding)) (* (- (second dilation)) (- k-w 1)) -1)
				     (second stride)))))
	       (input (padding input
			       (if ~ ;; If batched
				   `(,@(loop for i in ~ collect t)
				     t
				     (,(second padding)
				      ,(+ (second padding) p-y))
				     (,(car padding)
				      ,(+  (car padding)    p-x)))
				   `(t
				     (,(second padding)
				      ,(+ (second padding) p-y))
				     (,(car padding)
				      ,(+ (car padding) p-x)))))))

	  ;; out(N_i, C_out_j) = bias + Σcross-correlation(weight(C_out_j, k), input(N_i, k)) where k = 0 ... C_in - 1
	  ;; Input =  (~ C_in H-in+pY W-in+pX)
	  ;; Weight = (C_out (/ C_in groups) kernel_size[0] kernel_size[1])

	  ;; Conv2D(Input[0], Weight[0]) (C_in=1 -> C_out=8) (Channel)
	  ;; Input[1]とWeight[1]
	  ;;        ..
	  ;; (8 H-out W-out)

	  ;; Conv(X, W)
	  ;; X ... (~ 1 H_in W_in)
	  ;; Y ... (C_out groups=1 kernel_size_x kenel_size_y)
	  ;;

	  
	  ;; Input (~ C_in H-in W-in)
	  ;;
	  ;;            v kernel_n
	  ;; -> (~ C_in ~ 1 k-h k-w)  Reshape
	  ;;
	  ;;              v broadcast
	  ;; -> (~ C_in ~ 1 k-h k-w)  |
	  ;;    (~ C_in ~ 1 k-h k-w)  | broadcast for C_in
	  ;;            ...           |

	  ;; im2col + gemm

	  ;; weight (C_out (/ C_in groups) kx ky)
	  
	  ;; col = im2col(input) ;; (N * h-out w-out, C * kx * ky)
	  
	  (let* ((col   (!im2col-cpu input (car ~) in-channels k-h k-w h-out w-out (car stride) (second stride)))
		 (col-w (!reshape weight t c-out))
		 (out   (!matmul col col-w))
		 (out   (if bias
			    (!add out (%transform bias[i] -> [~ i]))
			    out)))

	    ;; 3 2 1 0 N h-out w-out C_out
	    ;; 3 0 2 1 N C-out h-out w-out
	    ;; (N h-out w-out c-out) -> (N c-out h-out w-out)
	    (!permute (!reshape out (car ~) h-out w-out C-out) 3 0 2 1)))))))

