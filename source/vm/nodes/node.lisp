
(in-package :cl-waffe2/vm.nodes)

(defclass AbstractNode ()
  ((function-node
    :initarg
    :function-node
    :reader abstractnode-node
    :type function) ;; [x y] [y z] -> [z x]
   (variables :initform nil :reader node-variables :writer set-variables :type list)
   (passed-at-least-once :initform nil :accessor node-passed-p :type boolean))
  (:documentation "The class AbstractNode is a fundamental object of describing computation nodes in cl-waffe.

AbstractNode must possess following:
   1. 遷移図
   2. Slots (for passing forward/backward)
   3. Variables (for building computation nodes)
   4. with-facet (facet ... ノードの様相)

backendのforward/backwardはAbstractNodeを継承して、定義する
"))

;; TODO: Under here.
(defmethod test-and-forward-shape ((node AbstractNode) &rest previous-shape)
  ""
  (funcall (abstractnode-node node) previous-shape))

(defun describe-problems (error-node detected-errors)
  ;; Enhancement:
  ;; Restart-Case
  ;; [Fix-Definition-And-Step]
  ;; [Replace-Shape-And-Step]
  ;; More Details:
  ;; Displays [pre-|post-]computation node
  ;;
  (shaping-error
   "Couldn't step forward because of shape-error.
At: ~a
Here's a list of reports.

1. ~a

~a
~a"
   error-node
   (car detected-errors)
   (if (cdr detected-errors)
       "Also, these reports could be helpful for you (calculated ignoring the first errors.)"
       "")
   (with-output-to-string (out)
     (loop for err in (cdr detected-errors)
	   for n upfrom 2
	   do (format out "~%~%~a. ~a" n err)))))

(defun make-grad-gensym ()
  (intern (symbol-name (gensym "Chain")) "KEYWORD"))

;; Forward:  f(input-state) -> output-state
;; Backward: g(output-state) -> input-state

(defgeneric forward  (node &rest inputs))
(defgeneric backward (node dy))

;; we can optimize or pruning the computation node
(defmethod forward :around ((node AbstractNode) &rest inputs)
  ;; Update Computation Nodes

  (let* ((transition-function (abstractnode-node node))
	 (input-states (loop for i in inputs collect (shape i))))
    
    ;; Input-State -> Output-State
    (multiple-value-bind (out-state detected-errors) (funcall transition-function input-states)
      
      (when detected-errors
	;; Enhancement
	;; CALL-VIEW-AND-CONTINUE
	(describe-problems node detected-errors))

      ;; TODO: When Dynamic-Mode
      ;; Call (construct-forward) and eval it here.
      
      ;; Forward:  Input-State  -> Output-State
      ;; Backward: Output-State -> Input-State

      ;; Forward:
      ;; [30 10] + [30 10] -> [10 10] -> [5 5]
      ;; Memo: Sharing Allocated memory between f and b
      ;; can be realised with self ...
      ;; recompute grad
      (let* ((forward-form (call-next-method))
	     (backward-forms
	       (map 'list
		    #'(lambda (shape
			       &aux (dy (make-input shape nil
						    :dtype (dtype (car inputs))
						    :order (order (car inputs)))))
				 (unless *no-grad* (cons dy (backward node dy))))
		    out-state))
	     (next-tensor
	       (loop for shape in out-state
		     for nth-arg upfrom 0
		     collect (let* ((next-tensor
				      (make-input shape nil
						  :dtype (dtype (car inputs))
						  :order (order (car inputs))))
				    (bw (nth nth-arg backward-forms))
				    (state (make-statecontainer
					    :backward-input-variable (car bw)
					    :forward-out-form forward-form
					    :backward-out-form (cdr bw)
					    :forward-n-out (length out-state)
					    :backward-n-out (length input-states))))
			       (setf (tensor-out-n next-tensor)     nth-arg)
			       (setf (tensor-state next-tensor)     state)
			       (setf (tensor-backward next-tensor)  node)
			       (setf (tensor-variables next-tensor) inputs)
			       next-tensor))))
	(apply #'values next-tensor)))))

(defmethod forward ((node AbstractNode) &rest inputs)
  (declare (ignore inputs))
  ;; Describe More Errors.
  (error "Couldn't step forward because ~a forward is undefined.

Make sure that the node has been initialised using the constructor automatically generated by the defnode macro.

(DO NOT USE make-instance for defnode) but use:

(~a &rest inputs).

In cl-waffe, AbstractNode (i.e.: nodes defined by defnode itself), doesn't have a definition of forward and backward.
Use the define-impl macro to give definitions for the node and forward them.
"
	 node
	 (class-name (class-of node))))

(defmethod backward :around ((node AbstractNode) dy)
  (unless *no-grad*
    (let ((out (multiple-value-list (call-next-method))))
      ;; update or lazy-evaluate
      out)))

(defmethod backward ((node AbstractNode) dy)
  (error "Couldn't step backward because ~a backward is undefined." node))

