;;; TGIRR CAD - GstarCAD loader
;;; Nap cac lenh LISP va DLL .NET cho GstarCAD.
;;;
;;; Thu muc goc duoc xac dinh theo thu tu uu tien:
;;;   1. Bien global *TGIRR:G-ROOT* (dat bang lenh TGIRRSETDIR)
;;;   2. Bien moi truong TGIRR_CAD_DIR_G (dat bang lenh TGIRRSETDIR)
;;;   3. Thu muc chua TGIRR.Gscad.dll (findfile theo search path)
;;;   4. Thu muc chua chinh file loader nay (TGIRRLoaderG.lsp)
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
(defun TGIRR:G-DIR (/ dll loader)
  (cond
    (*TGIRR:G-ROOT*)
    ((getenv "TGIRR_CAD_DIR_G"))
    ((setq dll (TGIRR:FINDFILE-SAFE "TGIRR.Gscad.dll"))
     (vl-filename-directory dll))
    ((setq loader (TGIRR:FINDFILE-SAFE "TGIRRLoaderG.lsp"))
     (vl-filename-directory loader))
    (t nil)))

;; Danh sach thu muc ung vien - chi cac thu muc TON TAI, dang chuan hoa (khong \ cuoi).
(defun TGIRR:G-CANDIDATES (/ base parent lst d)
  (setq base (TGIRR:TRIM-SLASH (TGIRR:G-DIR)))
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
(defun TGIRR:G-FIND (name / result)
  (setq result nil)
  (foreach d (TGIRR:G-CANDIDATES)
    (if (and (not result) d)
      (setq result (TGIRR:FINDFILE-SAFE (strcat d "\\" name)))))
  result)

(defun TGIRR:G-LOAD-FILE (name / path result)
  (setq path (TGIRR:G-FIND name))
  (if path
    (progn
      (setq result (vl-catch-all-apply 'load (list path)))
      (if (vl-catch-all-error-p result)
        (prompt (strcat "\nTGIRR GstarCAD: LOAD loi " name " - " (vl-catch-all-error-message result)))
        (prompt (strcat "\nTGIRR GstarCAD: Da nap " path))))
    (prompt (strcat "\nTGIRR GstarCAD: Khong tim thay " name))))

(defun TGIRR:G-NETLOAD (name / path result)
  (setq path (TGIRR:G-FIND name))
  (if path
    (progn
      (setq result (vl-catch-all-apply 'command (list "_NETLOAD" path)))
      (if (vl-catch-all-error-p result)
        (prompt (strcat "\nTGIRR GstarCAD: NETLOAD loi " name " - " (vl-catch-all-error-message result)))
        (prompt (strcat "\nTGIRR GstarCAD: NETLOAD ok " path))))
    (prompt (strcat "\nTGIRR GstarCAD: Khong tim thay DLL " name))))

(defun c:TGIRRLOAD (/ root)
  (setq root (TGIRR:G-DIR))
  (setq *TGIRR:G-ROOT* root)
  (if (not root)
    (progn
      (prompt "\nTGIRR GstarCAD: chua biet thu muc. Go TGIRRSETDIR de chon file TGIRR.Gscad.dll truoc.")
      (princ))
    (progn
      ;; Nap cac lenh AutoLISP
      (TGIRR:G-LOAD-FILE "SBS.lsp")
      (TGIRR:G-LOAD-FILE "TL.lsp")
      (TGIRR:G-LOAD-FILE "TGL.lsp")
      (TGIRR:G-LOAD-FILE "TGN.lsp")
      ;; Nap plugin .NET (CPLUS, VDNG, TNET, TGIRRPALETTE)
      (TGIRR:G-NETLOAD "TGIRR.Gscad.dll")
      ;; Mo palette cong cu (neu lenh da duoc nap tu DLL)
      (if (vl-catch-all-error-p (vl-catch-all-apply 'command (list "_TGIRRPALETTE")))
        (prompt "\nTGIRR GstarCAD: go TGIRRPALETTE de mo bang cong cu.")
        (prompt "\nTGIRR GstarCAD: da mo bang cong cu TGIRR (go TGIRRPALETTE de bat/tat)."))
      (prompt (strcat "\nTGIRR CAD cho GstarCAD: thu muc goc " root))
      (princ))))

(defun c:TGIRRSETDIR (/ f d)
  (setq f (getfiled "Chon file TGIRR.Gscad.dll de xac dinh thu muc" "" "dll" 0))
  (if f
    (progn
      (setq d (vl-filename-directory f))
      (setenv "TGIRR_CAD_DIR_G" d)
      (setq *TGIRR:G-ROOT* d)
      (prompt (strcat "\nTGIRR GstarCAD: da dat thu muc = " d "\n  Go TGIRRLOAD de nap day du.")))
    (prompt "\nTGIRR GstarCAD: huy chon thu muc."))
  (princ))

(prompt "\nTGIRR GstarCAD: Go TGIRRSETDIR de chi thu muc (1 lan), roi TGIRRLOAD de nap lenh.")
(princ)

(defun c:TGIRRSETDIR (/ f d)
  (setq f (getfiled "Chon file TGIRR.Gscad.dll de xac dinh thu muc" "" "dll" 0))
  (if f
    (progn
      (setq d (vl-filename-directory f))
      (setenv "TGIRR_CAD_DIR_G" d)
      (setq *TGIRR:G-DIR* d)
      (prompt (strcat "\nTGIRR GstarCAD: da dat thu muc = " d "\n  Go TGIRRLOAD de nap day du.")))
    (prompt "\nTGIRR GstarCAD: huy chon thu muc."))
  (princ))

(prompt "\nTGIRR GstarCAD: Go TGIRRSETDIR de chi thu muc (1 lan), roi TGIRRLOAD de nap lenh.")
(princ)