;;; TGIRR CAD - ZWCAD loader
;;; Nap cac lenh LISP va DLL .NET cho ZWCAD.
;;;
;;; Thu muc goc duoc xac dinh theo thu tu uu tien:
;;;   1. Bien global *TGIRR:ZW-DIR* (neu da set)
;;;   2. Bien moi truong TGIRR_CAD_DIR_Z (dat bang lenh TGIRRSETDIR)
;;;   3. Thu muc chua TGIRR.Zwcad.dll (findfile theo search path)
;;;   4. Fallback: ROAMABLEROOTPREFIX
;;;
;;; Cac file .lsp duoc tim trong nhieu vi tri (flat, \Lisp, \Windows va
;;; sibling \Lisp) nen chay duoc ca khi copy nguyen cau truc bundle
;;; (Contents\Lisp + Contents\Windows) lan copy det vao cung mot thu muc.
(vl-load-com)

(defun TGIRR:ZW-DIR (/ current)
  (cond
    (*TGIRR:ZW-DIR*)
    ((getenv "TGIRR_CAD_DIR_Z"))
    (t
      (setq current (findfile "TGIRR.Zwcad.dll"))
      (if current
        (vl-filename-directory current)
        (getvar "ROAMABLEROOTPREFIX")))))

;; Tra ve danh sach thu muc ung vien (khong trung lap).
(defun TGIRR:ZW-CANDIDATES (/ base lst)
  (setq base (TGIRR:ZW-DIR))
  (setq lst (list base))
  (if base
    (progn
      (setq lst (cons (strcat base "\\Lisp") lst))
      (setq lst (cons (strcat base "\\Windows") lst))
      ;; Neu base ket thuc boi \Windows thi them sibling \Lisp
      (if (= (strcase (substr base (- (strlen base) 7) 8)) "\\WINDOWS")
        (setq lst (cons (strcat (vl-filename-directory base) "\\Lisp") lst)))
      ;; Neu base ket thuc boi \Lisp thi them sibling \Windows
      (if (= (strcase (substr base (- (strlen base) 4) 5)) "\\LISP")
        (setq lst (cons (strcat (vl-filename-directory base) "\\Windows") lst)))))
  (reverse lst))

;; Tim file trong cac thu muc ung vien; tra ve path day du hoac nil.
(defun TGIRR:ZW-FIND (name / p dirs)
  (setq dirs (TGIRR:ZW-CANDIDATES))
  (setq p nil)
  (foreach d dirs
    (if (and (not p) d (findfile (strcat d "\\" name)))
      (setq p (findfile (strcat d "\\" name)))))
  p)

(defun TGIRR:ZW-LOAD-FILE (name / path result)
  (setq path (TGIRR:ZW-FIND name))
  (if path
    (progn
      (setq result (vl-catch-all-apply 'load (list path)))
      (if (vl-catch-all-error-p result)
        (prompt (strcat "\nTGIRR ZWCAD: Khong nap duoc " name " - " (vl-catch-all-error-message result)))
        (prompt (strcat "\nTGIRR ZWCAD: Da nap " path))))
    (prompt (strcat "\nTGIRR ZWCAD: Khong tim thay " name))))

(defun TGIRR:ZW-NETLOAD (name / path result)
  (setq path (TGIRR:ZW-FIND name))
  (if path
    (progn
      (setq result (vl-catch-all-apply 'command (list "_NETLOAD" path)))
      (if (vl-catch-all-error-p result)
        (prompt (strcat "\nTGIRR ZWCAD: NETLOAD loi " name " - " (vl-catch-all-error-message result)))
        (prompt (strcat "\nTGIRR ZWCAD: NETLOAD ok " path))))
    (prompt (strcat "\nTGIRR ZWCAD: Khong tim thay DLL " name))))

(defun c:TGIRRLOAD (/ dir)
  (setq TGIRR:ZW-DIR (TGIRR:ZW-DIR))
  (if (not TGIRR:ZW-DIR)
    (progn
      (prompt "\nTGIRR ZWCAD: chua biet thu muc. Go TGIRRSETDIR de chon file TGIRR.Zwcad.dll truoc.")
      (princ))
    (progn
      ;; Nap cac lenh AutoLISP
      (TGIRR:ZW-LOAD-FILE "SBS.lsp")
      (TGIRR:ZW-LOAD-FILE "TL.lsp")
      (TGIRR:ZW-LOAD-FILE "TGL.lsp")
      (TGIRR:ZW-LOAD-FILE "TGN.lsp")
      ;; Nap plugin .NET (CPLUS, VDNG, TNET)
      (TGIRR:ZW-NETLOAD "TGIRR.Zwcad.dll")
      (prompt (strcat "\nTGIRR CAD cho ZWCAD: thu muc goc " TGIRR:ZW-DIR))
      (princ))))

(defun c:TGIRRSETDIR (/ f d)
  (setq f (getfiled "Chon file TGIRR.Zwcad.dll de xac dinh thu muc" "" "dll" 0))
  (if f
    (progn
      (setq d (vl-filename-directory f))
      (setenv "TGIRR_CAD_DIR_Z" d)
      (setq *TGIRR:ZW-DIR* d)
      (prompt (strcat "\nTGIRR ZWCAD: da dat thu muc = " d "\n  Go TGIRRLOAD de nap day du.")))
    (prompt "\nTGIRR ZWCAD: huy chon thu muc."))
  (princ))

(prompt "\nTGIRR ZWCAD: Go TGIRRSETDIR de chi thu muc (1 lan), roi TGIRRLOAD de nap lenh.")
(princ)