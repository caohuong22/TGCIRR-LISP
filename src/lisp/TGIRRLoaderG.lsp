;;; TGIRR CAD - GstarCAD loader
;;; Nap cac lenh LISP va DLL .NET cho GstarCAD (tu dong tim thu muc chua loader).
(vl-load-com)

(defun TGIRR:G-DIR (/ current)
  (setq current (findfile "TGIRRLoaderG.lsp"))
  (if current
    (vl-filename-directory current)
    (getvar "ROAMABLEROOTPREFIX")))

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
  ;; Nap cac lenh AutoLISP
  (TGIRR:G-LOAD-FILE "SBS.lsp")
  (TGIRR:G-LOAD-FILE "TL.lsp")
  (TGIRR:G-LOAD-FILE "TGL.lsp")
  (TGIRR:G-LOAD-FILE "TGN.lsp")
  ;; Nap plugin .NET (CPLUS, VDNG, TNET)
  (TGIRR:G-NETLOAD "TGIRR.Gscad.dll")
  (prompt (strcat "\nTGIRR CAD cho GstarCAD: thu muc " TGIRR:G-DIR))
  (princ))

(prompt "\nTGIRR GstarCAD: Go TGIRRLOAD de nap day du lenh (LISP + .NET).")
(princ)