
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; MODULE      : form-edit.scm
;; DESCRIPTION : Standard forms for interactive commands
;; COPYRIGHT   : (C) 2007  Joris van der Hoeven
;;
;; This software falls under the GNU general public license and comes WITHOUT
;; ANY WARRANTY WHATSOEVER. See the file $TEXMACS_PATH/LICENSE for details.
;; If you don't have this file, write to the Free Software Foundation, Inc.,
;; 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(texmacs-module (kernel gui gui-form)
  (:use (kernel gui gui-factory)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Typed form entries
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define (default-value-of-type type)
  (cond ((in? type '("string" "password" "file")) "")
	((== type "boolean") #f)
	((== type "integer") 0)
	((== type "floating") 0.0)
	((== type "content") "")
	((== type "tree") (tree ""))
	(else "")))

(tm-define (form->type val type)
  (cond ((in? type '("string" "password" "file")) (tree->string val))
	((== type "boolean") (== (tree->string val) "true"))
	((== type "integer") (string->number (tree->string val)))
	((== type "floating") (string->number (tree->string val)))
	((== type "content") (tree->stree val))
	((== type "tree") val)
	(else val)))

(tm-define (type->form val type)
  (cond ((in? type '("string" "password" "file")) (string->tree val))
	((== type "boolean") (string->tree (if val "true" "false")))
	((== type "integer") (string->tree (number->string val)))
	((== type "floating") (string->tree (number->string val)))
	((== type "content") (stree->tree val))
	((== type "tree") val)
	(else val)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Remembering previous values of form fields
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define (form-load name vars)
  (learned-interactive name))

(tm-define (form-save name vars vals)
  (learn-interactive name (map cons vars vals)))

(tm-define (form-get-proposal var type memo suggest)
  (cond ((and (null? suggest) (nnull? memo) (assoc-ref (car memo) var)) =>
	 identity)
	((with l (assoc-ref suggest var) (and l (nnull? l) (car l))) =>
	 (lambda (x) (tree->stree (type->form x type))))
	(else (tree->stree (type->form (default-value-of-type type) type)))))

(tm-define (build-widget w)
  (:case form)
  (with (cmd proto . body) w
    (with (name . vars) proto
      (with f (lambda (x) (if (string? x) (cons x #f) (cons (car x) (cadr x))))
	(set! vars (map f vars)))
      `(let* ((form-name ,name)
	      (form-vars (map car ',vars))
	      (form-type ',vars)
	      (form-suggest '())
	      (form-memo (form-load form-name form-vars))
	      (form-auto
	       (lambda (var type)
		 (form-get-proposal var type form-memo form-suggest)))
	      (form-done
	       (lambda ()
		 (with form-vals (map widget-ref form-vars)
		   (form-save form-name form-vars form-vals)))))
	 ,(build-widgets body)))))

(tm-define (build-widget w)
  (:case suggestions)
  (with (cmd var l) w
    `(begin
       (set! form-suggest (assoc-set! form-suggest ,var ,l))
       '())))

(tm-define (build-widget w)
  (:case form-previous)
  (build-widget
   '(aspect :circle :blue
      (button "<less>" (noop)))))

(tm-define (build-widget w)
  (:case form-next)
  (build-widget
   '(aspect :circle :blue
      (button "<gtr>" (noop)))))

(tm-define (build-widget w)
  (:case form-cancel)
  (build-widget
   '(button "Cancel" (dismiss))))

(tm-define (build-widget w)
  (:case form-done)
  (with (cmd fun) w
    (build-widget
     `(button "Ok"
	(form-done)
	(let* ((form-vals (map widget-ref form-vars))
	       (form-types (map cdr form-type)))
	  (apply ,fun (map form->type form-vals form-types)))
	(dismiss)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Building widgets for interactive functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(tm-define (make-fraction num den)
  (:argument num "content" "Numerator")
  (:argument den "content" "Denominator")
  (insert `(frac ,num ,den)))

(define (interactive-vars args nr)
  (if (null? args) '()
      (cons (string-append "arg" (number->string nr))
	    (interactive-vars (cdr args) (+ nr 1)))))

(define (interactive-value var type)
  (with val `(widget-ref ,var)
    (cond ((== type "string") `(tree->string ,val))
	  ((== type "password") `(tree->string ,val))
	  ((== type "content") val)
	  (else `(tree->string ,val)))))

(define (interactive-field prompt var type val)
  `(,prompt (field ,var ',val)))

(tm-define (widget-std-fields prompts vars types defaults)
  (:synopsis "Construct a standard widget for input fields of given types")
  (let* ((vals (map (lambda (x) (or (and (nnull? x) (car x)) "")) defaults))
	 (rows (map interactive-field prompts vars types vals)))
    (cons 'table rows)))

(define (numbered-args args nr)
  (if (null? args) '()
      (cons (number->string nr)
	    (numbered-args (cdr args) (+ nr 1)))))

(tm-define (widget-std-ok fun vars* results)
  (:synopsis "Construct an Ok button for applying @fun to the form's @results")
  (with vars (map string->symbol vars*)
    `(button "Ok"
       (let* ,(map list vars results)
	 (dismiss)
	 (learn-interactive ,fun
	   (map cons ,(cons 'list (numbered-args vars 0))
		     ,(cons 'list vars)))
	 (delayed
	   (:idle 1)
	   (,fun ,@vars))))))

(tm-define (widget-std-form fun prompts vars types defaults results)
  (:synopsis "Standard form for a simple function application")
  `(,(widget-std-fields prompts vars types defaults)
    -
    (bar >>>
      (button "Cancel" (dismiss))
      ,(widget-std-ok fun vars results))))

(tm-define (widget-interactive fun . args)
  (lazy-define-force fun)
  (if (null? args) (set! args (compute-interactive-args fun)))
  (let* ((fun-args (build-interactive-args fun args 0))
	 (prompts (map car fun-args))
	 (vars (interactive-vars prompts 1))
	 (types (map cadr fun-args))
	 (defaults (map cddr fun-args))
	 (results (map interactive-value vars types))
	 (widget (widget-std-form fun prompts vars types defaults results)))
    (if (procedure-name fun) (set! fun (procedure-name fun)))
    (if (symbol? fun) (set! fun (symbol->string fun)))
    (if (nstring? fun) (set! fun "Enter function arguments"))
    (eval (widget-armour fun (build-widgets widget)))))
