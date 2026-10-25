;;; ==========================================================================
;;; TGIRR CAD LISP - LENH TGIRRBAR
;;; Bat thanh cong cu icon native (***TOOLBARS trong TGIRR_CAD.mnu).
;;;
;;; - Tu them thu muc chua .mnu + icon BMP vao Support File Search Path.
;;; - Tu MENULOAD menu TGIRR neu chua nap (khong nap lai neu da co).
;;; - Bat toolbar "TGIRR CAD" (-TOOLBAR ... _Show).
;;;
;;; Tuong thich: AutoCAD, ZWCAD, GstarCAD
;;; ==========================================================================

(vl-load-com)

;; Thu muc chua TGIRR_CAD.mnu + icon BMP
(defun tgirr:bar-dir (/ dirs f d out)
  (setq dirs '())
  ;; 1. Da nam trong Support File Search Path (hoac load bang duong dan day du)
  (foreach name '("TGIRR_CAD.mnu" "TGIRRLoader.lsp" "TGIRRLoaderG.lsp"
                  "TGIRRLoaderZ.lsp" "DOITEXT.lsp" "TGIRRBAR.lsp")
    (if (setq f (findfile name))
      (setq dirs (cons (vl-filename-directory f) dirs))))
  ;; 2. Thu muc loader da luu lai khi chay TGIRRLOAD (thu muc goc va \Lisp)
  (foreach v (list TGIRR:LISP-DIR *TGIRR:G-ROOT* *TGIRR:ZW-ROOT*)
    (if (and v (= (type v) 'STR) (> (strlen v) 0))
      (setq dirs (cons (strcat v "\\Lisp") (cons v dirs)))))
  (setq out nil)
  (foreach d dirs
    (if (and (not out) d (= (type d) 'STR)
             (findfile (strcat d "\\TGIRR_CAD.mnu")))
      (setq out d)))
  out)

;; Tach chuoi theo 1 ky tu ngan cach
(defun tgirr:bar-split (str sep / pos out)
  (setq out '())
  (while (setq pos (vl-string-search sep str))
    (setq out (append out (list (substr str 1 pos)))
          str (substr str (+ pos 1 (strlen sep)))))
  (append out (list str)))

;; Them 1 thu muc vao Support File Search Path (bien ACAD) neu chua co
(defun tgirr:bar-add-path (dir / acad found)
  (if (and dir (= (type dir) 'STR) (> (strlen dir) 0))
    (progn
      (setq acad (getenv "ACAD"))
      (if (null acad) (setq acad ""))
      (foreach p (vl-remove "" (mapcar 'strcase (tgirr:bar-split acad ";")))
        (if (= p (strcase dir)) (setq found T)))
      (if (not found)
        (setenv "ACAD" (if (= acad "") dir (strcat acad ";" dir)))))))

(defun tgirr:bar-menu-loaded-p (/ grp)
  (vl-catch-all-apply '(lambda () (setq grp (menugroup "TGIRR"))))
  (if (and grp (= (type grp) 'STR)) grp nil))

(defun c:TGIRRBAR (/ dir mnu grp res)

  (prompt "\n===========================================================")
  (prompt "\n[TGIRR] TGIRRBAR - BẬT THANH CÔNG CỤ ICON NATIVE")
  (prompt "\n===========================================================")

  (setq dir (tgirr:bar-dir))
  (cond
    ((null dir)
      (prompt "\n[TGIRRBAR] Không tìm thấy thư mục chứa TGIRR_CAD.mnu.")
      (prompt "\n[TGIRRBAR] Hãy copy TGIRR_CAD.mnu + các file .bmp vào một thư mục trong Support File Search Path."))

    (t
      (setq mnu (strcat dir "\\TGIRR_CAD.mnu"))
      (tgirr:bar-add-path dir)

      (setq grp (tgirr:bar-menu-loaded-p))
      (if (not grp)
        (progn
          (setq res (vl-catch-all-apply '(lambda () (command "_.MENULOAD" mnu))))
          (if (vl-catch-all-error-p res)
            (prompt (strcat "\n[TGIRRBAR] Nạp menu lỗi: " (vl-catch-all-error-message res)))
            (setq grp (tgirr:bar-menu-loaded-p)))))

      (cond
        ((not grp)
          (prompt "\n[TGIRRBAR] Chưa nạp được menu TGIRR_CAD.mnu.")
          (prompt (strcat "\n[TGIRRBAR] Gõ MENULOAD và chọn: " mnu)))

        (t
          (setq res (vl-catch-all-apply
                      '(lambda () (command "_.-TOOLBAR" "TB_TGIRR" "_Show"))))
          (if (vl-catch-all-error-p res)
            (progn
              (prompt "\n[TGIRRBAR] Đã nạp menu nhưng chưa bật được toolbar.")
              (prompt "\n[TGIRRBAR] Gõ TOOLBAR, chọn thanh 'TGIRR CAD' rồi bấm Show."))
            (prompt "\n[TGIRRBAR] Đã bật thanh công cụ TGIRR CAD (icon native)."))))
    )
  )
  (princ)
)

;; Alias ngan gon
(defun c:TGIRRTB () (c:TGIRRBAR))

(prompt "\nTGIRR CAD LISP: Đã nạp lệnh TGIRRBAR (thanh công cụ icon native).")
(princ)
