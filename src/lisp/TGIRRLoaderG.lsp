;;; TGIRR CAD - GstarCAD loader
;;; Nap cac lenh LISP va DLL .NET cho GstarCAD.
;;; Thu muc duoc xac dinh theo thu tu uu tien:
;;;   1. Bien global *TGIRR:G-DIR* (neu da set)
;;;   2. Bien moi truong TGIRR_CAD_DIR_G (dat bang lenh TGIRRSETDIR)
;;;   3. Thu muc chua TGIRR.Gscad.dll (findfile theo search path)
;;;   4. Fallback: ROAMABLEROOTPREFIX
(vl-load-com)

(defun TGIRR:G-DIR (/ current)
  (cond
    (*TGIRR:G-DIR*)
    ((getenv "TGIRR_CAD_DIR_G"))
    (t
      (setq current (findfile "TGIRR.Gscad.dll"))
      (if current
        (vl-filename-directory current)
        (getvar "ROAMABLEROOTPREFIX")))))

(defun TGIRR:G-LOAD-FILE (name / path result)
  (setq path (strcat TGIRR:G-DIR "\\" name))
  (if (findfile path)
    (progn
      (setq result (vl-catch-all-apply 'load (list path)))
      (if (vl-catch-all-error-p result)
        (prompt (strcat "\nTGIRR GstarCAD: Khong nap duoc " name " - " (vl-catch-all-error-message result)))
        (prompt (strcat "\nTGIRR GstarCAD: Da nap " name))))
    (prompt (strcat "\nTGIRR GstarCAD: Khong tim thay " path))))

(defun TGIRR:G-NETLOAD (name / path result)
  (setq path (strcat TGIRR:G-DIR "\\" name))
  (if (findfile path)
    (progn
      (setq result (vl-catch-all-apply 'command (list "_NETLOAD" path)))
      (if (vl-catch-all-error-p result)
        (prompt (strcat "\nTGIRR GstarCAD: NETLOAD loi " name " - " (vl-catch-all-error-message result)))
        (prompt (strcat "\nTGIRR GstarCAD: NETLOAD ok " name))))
    (prompt (strcat "\nTGIRR GstarCAD: Khong tim thay DLL " path))))

(defun c:TGIRRLOAD (/ dir)
  (setq TGIRR:G-DIR (TGIRR:G-DIR))
  (if (not TGIRR:G-DIR)
    (progn
      (prompt "\nTGIRR GstarCAD: chua biet thu muc. Go TGIRRSETDIR de chon file TGIRR.Gscad.dll truoc.")
      (princ))
    (progn
      ;; Nap cac lenh AutoLISP
      (TGIRR:G-LOAD-FILE "SBS.lsp")
      (TGIRR:G-LOAD-FILE "TL.lsp")
      (TGIRR:G-LOAD-FILE "TGL.lsp")
      (TGIRR:G-LOAD-FILE "TGN.lsp")
      ;; Nap plugin .NET (CPLUS, VDNG, TNET)
      (TGIRR:G-NETLOAD "TGIRR.Gscad.dll")
      (prompt (strcat "\nTGIRR CAD cho GstarCAD: thu muc " TGIRR:G-DIR))
      (princ))))

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