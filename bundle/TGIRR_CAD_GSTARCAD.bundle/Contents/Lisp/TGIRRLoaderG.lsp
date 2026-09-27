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

;; Xac dinh thu muc goc - ho tro bien moi truong, registry, bundle mac dinh va search path.
(defun TGIRR:G-DIR (/ dll loader reg candidates match)
  (setq reg (vl-registry-read "HKEY_CURRENT_USER\\Software\\TGIRR" "GscadDir"))
  (setq candidates
    (list
      *TGIRR:G-ROOT*
      (getenv "TGIRR_CAD_DIR_G")
      reg
      (if (setq dll (TGIRR:FINDFILE-SAFE "TGIRR.Gscad.dll")) (vl-filename-directory dll))
      (if (setq loader (TGIRR:FINDFILE-SAFE "TGIRRLoaderG.lsp")) (vl-filename-directory loader))
      "D:\\LispCAD\\TGIRR_CAD_GSTARCAD.bundle\\Contents"
      "D:\\LispCAD\\TGIRR_CAD_GSTARCAD.bundle\\Contents\\Windows"
      (strcat (getenv "APPDATA") "\\Gstarsoft\\GstarCAD\\R27\\en-WW\\Support")
      (strcat (getenv "APPDATA") "\\Gstarsoft\\GstarCAD\\R27\\en-US\\Support")
    ))
  (foreach d candidates
    (if (and (not match)
             d
             (or (TGIRR:DIR-EXISTS d)
                 (TGIRR:FINDFILE-SAFE (strcat (TGIRR:TRIM-SLASH d) "\\TGIRR.Gscad.dll"))
                 (TGIRR:FINDFILE-SAFE (strcat (TGIRR:TRIM-SLASH d) "\\Windows\\TGIRR.Gscad.dll"))))
      (setq match (TGIRR:TRIM-SLASH d))))
  match)

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
        (prompt (strcat "\nTGIRR GstarCAD: LOAD lỗi " name " - " (vl-catch-all-error-message result)))
        (prompt (strcat "\nTGIRR GstarCAD: Đã nạp " path))))
    (prompt (strcat "\nTGIRR GstarCAD: Không tìm thấy " name))))

(defun TGIRR:G-NETLOAD (name / path result)
  (setq path (TGIRR:G-FIND name))
  (if path
    (progn
      (setq result (vl-catch-all-apply '(lambda () (command "_NETLOAD" path))))
      (if (vl-catch-all-error-p result)
        (prompt (strcat "\nTGIRR GstarCAD: NETLOAD lỗi " name " - " (vl-catch-all-error-message result)))
        (prompt (strcat "\nTGIRR GstarCAD: NETLOAD ok " path))))
    (prompt (strcat "\nTGIRR GstarCAD: Không tìm thấy DLL " name))))

(defun c:TGIRRLOAD (/ root)
  (setq root (TGIRR:G-DIR))
  (setq *TGIRR:G-ROOT* root)
  (if (not root)
    (progn
      (prompt "\nTGIRR GstarCAD: Chưa biết thư mục. Gõ TGIRRSETDIR để chọn file TGIRR.Gscad.dll trước.")
      (princ))
    (progn
      ;; Luu lai vao registry de lan sau mo CAD tu dong nhan
      (vl-registry-write "HKEY_CURRENT_USER\\Software\\TGIRR" "GscadDir" root)
      (setenv "TGIRR_CAD_DIR_G" root)
      ;; Nap cac lenh AutoLISP
      (TGIRR:G-LOAD-FILE "SBS.lsp")
      (TGIRR:G-LOAD-FILE "TL.lsp")
      (TGIRR:G-LOAD-FILE "TGL.lsp")
      (TGIRR:G-LOAD-FILE "TGN.lsp")
      (TGIRR:G-LOAD-FILE "HBD.lsp")
      (TGIRR:G-LOAD-FILE "CVPL.lsp")
      (TGIRR:G-LOAD-FILE "DOITEXT.lsp")
      ;; Nap plugin .NET (CPLUS, VDNG, TNET, TGIRRPALETTE)
      (TGIRR:G-NETLOAD "TGIRR.Gscad.dll")
      ;; Mo palette cong cu (neu lenh da duoc nap tu DLL)
      (if (vl-catch-all-error-p (vl-catch-all-apply '(lambda () (command "TGIRRPALETTE"))))
        (prompt "\nTGIRR GstarCAD: Gõ TGIRRPALETTE để mở bảng công cụ.")
        (prompt "\nTGIRR GstarCAD: Đã mở bảng công cụ TGIRR (gõ TGIRRPALETTE để bật/tắt)."))
      (prompt (strcat "\nTGIRR CAD cho GstarCAD: Thư mục gốc " root))
      (princ))))

(defun c:TGIRRSETDIR (/ f d)
  (setq f (getfiled "Chọn file TGIRR.Gscad.dll để xác định thư mục" "" "dll" 0))
  (if f
    (progn
      (setq d (vl-filename-directory f))
      (setenv "TGIRR_CAD_DIR_G" d)
      (vl-registry-write "HKEY_CURRENT_USER\\Software\\TGIRR" "GscadDir" d)
      (setq *TGIRR:G-ROOT* d)
      (prompt (strcat "\nTGIRR GstarCAD: Đã đặt thư mục = " d "\n  Đang nạp đầy đủ..."))
      (c:TGIRRLOAD))
    (prompt "\nTGIRR GstarCAD: Hủy chọn thư mục."))
  (princ))

;; Tu dong khoi tao khi mo GstarCAD
(if (TGIRR:G-DIR)
  (c:TGIRRLOAD)
  (prompt "\nTGIRR GstarCAD: Gõ TGIRRSETDIR để chỉ thư mục (1 lần duy nhất)."))
(princ)