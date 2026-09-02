;;; TGIRR CAD - ZWCAD loader
;;; Nap cac lenh LISP va DLL .NET cho ZWCAD (tu dong tim thu muc chua loader).
(vl-load-com)

(defun TGIRR:ZW-DIR (/ current)
  (setq current (findfile "TGIRRLoaderZ.lsp"))
  (if current
    (vl-filename-directory current)
    (getvar "ROAMABLEROOTPREFIX")))

(defun TGIRR:ZW-LOAD-FILE (name / path result)
  (setq path (strcat TGIRR:ZW-DIR "\\" name))
  (if (findfile path)
    (progn
      (setq result (vl-catch-all-apply 'load (list path)))
      (if (vl-catch-all-error-p result)
        (prompt (strcat "\nTGIRR ZWCAD: Khong nap duoc " name " - " (vl-catch-all-error-message result)))
        (prompt (strcat "\nTGIRR ZWCAD: Da nap " name))))
    (prompt (strcat "\nTGIRR ZWCAD: Khong tim thay " path))))

(defun TGIRR:ZW-NETLOAD (name / path result)
  (setq path (strcat TGIRR:ZW-DIR "\\" name))
  (if (findfile path)
    (progn
      (setq result (vl-catch-all-apply 'command (list "_NETLOAD" path)))
      (if (vl-catch-all-error-p result)
        (prompt (strcat "\nTGIRR ZWCAD: NETLOAD loi " name " - " (vl-catch-all-error-message result)))
        (prompt (strcat "\nTGIRR ZWCAD: NETLOAD ok " name))))
    (prompt (strcat "\nTGIRR ZWCAD: Khong tim thay DLL " path))))

(defun c:TGIRRLOAD (/ dir)
  (setq TGIRR:ZW-DIR (TGIRR:ZW-DIR))
  ;; Nap cac lenh AutoLISP
  (TGIRR:ZW-LOAD-FILE "SBS.lsp")
  (TGIRR:ZW-LOAD-FILE "TL.lsp")
  (TGIRR:ZW-LOAD-FILE "TGL.lsp")
  (TGIRR:ZW-LOAD-FILE "TGN.lsp")
  ;; Nap plugin .NET (CPLUS, VDNG, TNET)
  (TGIRR:ZW-NETLOAD "TGIRR.Zwcad.dll")
  (prompt (strcat "\nTGIRR CAD cho ZWCAD: thu muc " TGIRR:ZW-DIR))
  (princ))

(prompt "\nTGIRR ZWCAD: Go TGIRRLOAD de nap day du lenh (LISP + .NET).")
(princ)