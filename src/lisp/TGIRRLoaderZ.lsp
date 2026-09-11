;;; TGIRR CAD - ZWCAD loader
;;; Nap cac lenh LISP va DLL .NET cho ZWCAD.
;;;
;;; Thu muc goc duoc xac dinh theo thu tu uu tien:
;;;   1. Bien global *TGIRR:ZW-ROOT* (dat bang lenh TGIRRSETDIR)
;;;   2. Bien moi truong TGIRR_CAD_DIR_Z (dat bang lenh TGIRRSETDIR)
;;;   3. Thu muc chua TGIRR.Zwcad.dll (findfile theo search path)
;;;   4. Thu muc chua chinh file loader nay (TGIRRLoaderZ.lsp)
;;;
;;; Loader viet phong thu: moi findfile/load deu nam trong vl-catch-all-apply
;;; va chi dung cac thu muc CO THAT, nen khong the hien loi roi kieu
;;; "undefined function - <duong dan>" khi duong dan khong hop le.
(vl-load-com)

;; Bo ky tu "\" o cuoi duong dan (vi du "C:\...\en-US\").
(defun TGIRR:TRIM-SLASH (dir / n)
  (if (and dir (setq n (strlen dir)) (> n 0) (= (substr dir n 1) "\\"))
    (substr dir 1 (1- n))
    dir))

;; findfile an toan - khong bao loi roi.
(defun TGIRR:FINDFILE-SAFE (file / r)
  (setq r (vl-catch-all-apply 'findfile (list file)))
  (if (vl-catch-all-error-p r) nil r))

;; Kiem tra thu muc co ton tai khong (an toan).
(defun TGIRR:DIR-EXISTS (dir / r)
  (setq r (vl-catch-all-apply 'vl-file-directory-p (list dir)))
  (and (not (vl-catch-all-error-p r)) r))

;; Xac dinh thu muc goc - KHONG dung ROAMABLEROOTPREFIX (de tranh duong dan bi loi).
(defun TGIRR:ZW-DIR (/ dll loader)
  (cond
    (*TGIRR:ZW-ROOT*)
    ((getenv "TGIRR_CAD_DIR_Z"))
    ((setq dll (TGIRR:FINDFILE-SAFE "TGIRR.Zwcad.dll"))
     (vl-filename-directory dll))
    ((setq loader (TGIRR:FINDFILE-SAFE "TGIRRLoaderZ.lsp"))
     (vl-filename-directory loader))
    (t nil)))

;; Danh sach thu muc ung vien - chi cac thu muc TON TAI, dang chuan hoa (khong \ cuoi).
(defun TGIRR:ZW-CANDIDATES (/ base parent lst d)
  (setq base (TGIRR:TRIM-SLASH (TGIRR:ZW-DIR)))
  (setq lst nil)
  (if base
    (progn
      (setq lst (list base))
      (setq parent (TGIRR:TRIM-SLASH (vl-filename-directory base)))
      ;; Lisp + Windows ngay duoi thu muc goc
      (foreach d (list (strcat base "\\Lisp") (strcat base "\\Windows"))
        (if (TGIRR:DIR-EXISTS d)
          (setq lst (cons d lst))))
      ;; Neu goc la \Lisp hoac \Windows thi them thu muc sibling
      (if (and parent (/= (strcase parent) (strcase base)))
        (foreach d (list (strcat parent "\\Lisp") (strcat parent "\\Windows"))
          (if (and (TGIRR:DIR-EXISTS d) (not (member d lst)))
            (setq lst (cons d lst)))))))
  (reverse lst))

;; Tim file trong cac thu muc ung vien; tra ve path day du hoac nil.
(defun TGIRR:ZW-FIND (name / result)
  (setq result nil)
  (foreach d (TGIRR:ZW-CANDIDATES)
    (if (and (not result) d)
      (setq result (TGIRR:FINDFILE-SAFE (strcat d "\\" name)))))
  result)

(defun TGIRR:ZW-LOAD-FILE (name / path result)
  (setq path (TGIRR:ZW-FIND name))
  (if path
    (progn
      (setq result (vl-catch-all-apply 'load (list path)))
      (if (vl-catch-all-error-p result)
        (prompt (strcat "\nTGIRR ZWCAD: LOAD loi " name " - " (vl-catch-all-error-message result)))
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

(defun c:TGIRRLOAD (/ root)
  (setq root (TGIRR:ZW-DIR))
  (setq *TGIRR:ZW-ROOT* root)
  (if (not root)
    (progn
      (prompt "\nTGIRR ZWCAD: chua biet thu muc. Go TGIRRSETDIR de chon file TGIRR.Zwcad.dll truoc.")
      (princ))
    (progn
      ;; Nap cac lenh AutoLISP
      (TGIRR:ZW-LOAD-FILE "SBS.lsp")
      (TGIRR:ZW-LOAD-FILE "TL.lsp")
      (TGIRR:ZW-LOAD-FILE "TGL.lsp")
      (TGIRR:ZW-LOAD-FILE "TGN.lsp")
      (TGIRR:ZW-LOAD-FILE "HBD.lsp")
      ;; Nap plugin .NET (CPLUS, VDNG, TNET, TGIRRPALETTE)
      (TGIRR:ZW-NETLOAD "TGIRR.Zwcad.dll")
      ;; Mo palette cong cu (neu lenh da duoc nap tu DLL)
      (if (vl-catch-all-error-p (vl-catch-all-apply 'command (list "_TGIRRPALETTE")))
        (prompt "\nTGIRR ZWCAD: go TGIRRPALETTE de mo bang cong cu.")
        (prompt "\nTGIRR ZWCAD: da mo bang cong cu TGIRR (go TGIRRPALETTE de bat/tat)."))
      (prompt (strcat "\nTGIRR CAD cho ZWCAD: thu muc goc " root))
      (princ))))

(defun c:TGIRRSETDIR (/ f d)
  (setq f (getfiled "Chon file TGIRR.Zwcad.dll de xac dinh thu muc" "" "dll" 0))
  (if f
    (progn
      (setq d (vl-filename-directory f))
      (setenv "TGIRR_CAD_DIR_Z" d)
      (setq *TGIRR:ZW-ROOT* d)
      (prompt (strcat "\nTGIRR ZWCAD: da dat thu muc = " d "\n  Go TGIRRLOAD de nap day du.")))
    (prompt "\nTGIRR ZWCAD: huy chon thu muc."))
  (princ))

(prompt "\nTGIRR ZWCAD: Go TGIRRSETDIR de chi thu muc (1 lan), roi TGIRRLOAD de nap lenh.")
(princ)

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