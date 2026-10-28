;;; TGIRR master loader - nap cac Lisp cung thu muc voi loader.
;;;
;;; Cau hinh bat/tat nap tung lenh (lenh TGIRRSETTINGS) duoc doc tu
;;; %APPDATA%\TGIRR\load-settings.txt, dinh dang:  v1 disabled=SBS,DOITEXT
;;;
;;; Moi lenh deu co mot form "go" viet san (literal) nen khong can eval/read.
;;; Khong co buoc nao co the lam dung ca qua trinh nap: neu mot lenh bi loi,
;;; vl-catch-all-apply chi bo qua dung lenh do.
(vl-load-com)

;; Thu tu uu tien: (1) thu muc chua chinh loader, (2) bundle AutoCAD trong
;; APPDATA, (3) bundle trong PROGRAMDATA, (4) ROAMABLEROOTPREFIX (cuoi cung).
;; Chu y: phai append theo dung thu tu - cons se dao nguoc va chon sai thu muc.
(defun TGIRR:LOADER-DIR (/ out current d)
  (setq out nil)
  (setq current (findfile "TGIRRLoader.lsp"))
  (if current
    (setq out (append out (list (vl-filename-directory current)))))
  (foreach root (list (getenv "APPDATA") (getenv "PROGRAMDATA"))
    (if (and root (= (type root) 'STR) (> (strlen root) 0))
      (setq out (append out
        (list (strcat root "\\Autodesk\\ApplicationPlugins\\TGIRR_CAD_LISP.bundle\\Contents\\Lisp"))))))
  (setq out (append out (list (getvar "ROAMABLEROOTPREFIX"))))
  (setq d nil)
  (foreach dir out
    (if (and (not d) dir (= (type dir) 'STR) (> (strlen dir) 0) (TGIRR:DIR-EXISTS dir))
      (setq d dir)))
  d)

(defun TGIRR:DIR-EXISTS (dir / r)
  (setq r (vl-catch-all-apply 'vl-file-directory-p (list dir)))
  (and (not (vl-catch-all-error-p r)) r))

(defun TGIRR:SETTINGS-FILE (/ appdata)
  (setq appdata (getenv "APPDATA"))
  (if (and appdata (> (strlen appdata) 0))
    (strcat appdata "\\TGIRR\\load-settings.txt")
    nil))

(defun TGIRR:SETTING-TOKENS (text / pos out tok)
  (setq out nil)
  (while (and text (setq pos (vl-string-search "," text)))
    (setq tok (substr text 1 pos)
          text (substr text (+ pos 2)))
    (if (> (strlen tok) 0) (setq out (cons tok out))))
  (if (and text (> (strlen text) 0)) (setq out (cons text out)))
  (reverse out))

;; Danh sach lenh bi tat (rong = nap tat ca).
(defun TGIRR:DISABLED-LIST (/ path fh line rest pos)
  (setq path (TGIRR:SETTINGS-FILE))
  (setq line nil)
  (if (and path (findfile path) (setq fh (open path "r")))
    (progn
      (setq line (read-line fh))
      (close fh)))
  (setq rest (if (and line (= (substr line 1 2) "v1")) (substr line 3) ""))
  (setq pos (vl-string-search "disabled=" rest))
  (if pos (TGIRR:SETTING-TOKENS (substr rest (+ pos 10))) nil))

;; Tra ve T neu lenh duoc phep nap (mac dinh: bat).
(defun TGIRR:LOAD-ENABLED-P (id / disabled)
  (setq disabled (TGIRR:DISABLED-LIST))
  (not (member id disabled)))

(defun TGIRR:LOAD-FILE (folder name / path result)
  (setq path (strcat folder "\\" name))
  (if (findfile path)
    (progn
      (setq result (vl-catch-all-apply 'load (list path)))
      (if (vl-catch-all-error-p result)
        (prompt (strcat "\nTGIRR: Khong nap duoc " name " - " (vl-catch-all-error-message result)))
        (prompt (strcat "\nTGIRR: Da nap " name))))
    (prompt (strcat "\nTGIRR: Khong tim thay " path))))

;; Nap file neu con it nhat mot lenh bat; sau do go cac lenh da tat.
;; commands: ten lenh trong file. forms: danh sach ("TEN" (setq C:TEN nil)) viet san.
(defun TGIRR:LOAD-GROUP (folder name commands forms / disabled count)
  (setq disabled (TGIRR:DISABLED-LIST))
  (setq count 0)
  (foreach cmd commands
    (if (not (member cmd disabled)) (setq count (1+ count))))
  (if (> count 0)
    (TGIRR:LOAD-FILE folder name)
    (prompt (strcat "\nTGIRR: Bo qua " name " (tat toan bo lenh trong file).")))
  (if (> count 0)
    (foreach pair forms
      (if (member (car pair) disabled)
        (progn
          ;; Khong de mot lenh loi lam dung ca qua trinh nap.
          (vl-catch-all-apply 'eval (list (cadr pair)))
          (prompt (strcat "\nTGIRR: " (car pair) " da tat trong TGIRRSETTINGS.")))))))

;; Canh bao khi nguoi dung lo tat het moi lenh (CAD se "nhu khong chay").
(defun TGIRR:WARN-IF-ALL-OFF (/ disabled total)
  (setq disabled (TGIRR:DISABLED-LIST))
  (setq total (if *TGIRR:ALL-COMMANDS* (length *TGIRR:ALL-COMMANDS*) 0))
  (if (and (> total 0) (>= (length disabled) total))
    (prompt "\nTGIRR: TAT CA lenh dang bi tat trong TGIRRSETTINGS - go TGIRRSETTINGS de bat lai.")))

;; Bao trang thai nap ra dong lenh (dung khi can chan doan).
(defun TGIRR:STATUS (/ disabled total folder atoms)
  (setq disabled (TGIRR:DISABLED-LIST))
  (setq total (if *TGIRR:ALL-COMMANDS* (length *TGIRR:ALL-COMMANDS*) 0))
  (setq folder (if TGIRR:LISP-DIR TGIRR:LISP-DIR "(chua biet)"))
  (setq atoms (vl-catch-all-apply 'atoms-family (list 1)))
  (if (vl-catch-all-error-p atoms) (setq atoms nil))
  (prompt (strcat "\n[TGIRR] Thu muc LISP: " folder))
  (prompt (strcat "\n[TGIRR] So lenh dang tat: " (itoa (length disabled)) "/" (itoa total)))
  (if (> (length disabled) 0)
    (prompt (strcat "\n[TGIRR] Dang tat: " (TGIRR:JOIN disabled ", "))))
  (prompt (strcat "\n[TGIRR] SBS=" (TGIRR:HAS-COMMAND atoms "C:SBS")
                  "  HBD=" (TGIRR:HAS-COMMAND atoms "C:HBD")
                  "  TL=" (TGIRR:HAS-COMMAND atoms "C:TL")))
  (princ))

(defun TGIRR:HAS-COMMAND (atoms name)
  (if (and atoms (member name atoms)) "co" "KHONG"))

(defun TGIRR:JOIN (items sep / out)
  (setq out "")
  (foreach item items
    (setq out (if (= out "") item (strcat out sep item))))
  out)

;; Chay mot bieu thuc va bo qua loi: mot buoc hong khong duoc lam dung ca qua trinh nap.
(defun TGIRR:SAFE (expr / result)
  (setq result (vl-catch-all-apply 'eval (list expr)))
  (if (vl-catch-all-error-p result)
    (prompt (strcat "\nTGIRR: Bo qua mot buoc - " (vl-catch-all-error-message result))))
  result)

;; GO cac lenh da tat. Viet truc tiep tung lenh, khong dung eval/read nen khong
;; the lam dung ca file loader. Cac file .lsp da duoc manifest nap truoc do.
(defun TGIRR:APPLY-SETTINGS (/ disabled)
  (setq disabled (TGIRR:DISABLED-LIST))
  (if (member "SBS" disabled) (setq C:SBS nil))
  (if (member "SBSE" disabled) (setq C:SBSE nil))
  (if (member "SCH" disabled) (setq C:SCH nil))
  (if (member "HBD" disabled) (setq C:HBD nil))
  (if (member "JH" disabled) (setq C:JH nil))
  (if (member "SP2PL" disabled) (setq C:SP2PL nil))
  (if (member "DOITEXT" disabled) (setq C:DOITEXT nil))
  (if (member "DOIMTEXT" disabled) (setq C:DOIMTEXT nil))
  (if (member "KHO" disabled) (setq C:KHO nil))
  (if (member "TENBV" disabled) (setq C:TENBV nil))
  (if (member "TGIRRBAR" disabled) (setq C:TGIRRBAR nil))
  (if (> (length disabled) 0)
    (prompt (strcat "\nTGIRR: Dang tat theo TGIRRSETTINGS: " (TGIRR:JOIN disabled ", "))))
  (princ))

;; Nap lai cac file LISP roi ap dung cai dat bat/tat.
(defun TGIRR:RELOAD (/ folder)
  (setq folder (TGIRR:LOADER-DIR))
  (if folder
    (progn
      (setq TGIRR:LISP-DIR folder)
      (TGIRR:SAFE '(TGIRR:LOAD-FILE TGIRR:LISP-DIR "SBS.lsp"))
      (TGIRR:SAFE '(TGIRR:LOAD-FILE TGIRR:LISP-DIR "HBD.lsp"))
      (TGIRR:SAFE '(TGIRR:LOAD-FILE TGIRR:LISP-DIR "DOITEXT.lsp"))
      (TGIRR:SAFE '(TGIRR:LOAD-FILE TGIRR:LISP-DIR "KHO.lsp"))
      (TGIRR:SAFE '(TGIRR:LOAD-FILE TGIRR:LISP-DIR "TGIRRBAR.lsp"))
      (TGIRR:APPLY-SETTINGS)
      ;; Ten quen thuoc cua cac lenh .NET (TL, TGN, ...) - chi tao khi lenh con bat.
      (TGIRR:SAFE '(TGIRR:LOAD-FILE TGIRR:LISP-DIR "TGIRRCOMMANDS.lsp"))
      (TGIRR:WARN-IF-ALL-OFF)
      (prompt "\nTGIRR: Da nap lai LISP theo cai dat hien tai.")
      (prompt (strcat "\nTGIRR CAD LISP: Thu muc " TGIRR:LISP-DIR)))
    (prompt "\nTGIRR: Khong tim thay thu muc LISP."))
  (princ))

;; Go ten lenh da nap (dung khi muon nhuong ten cho LISP khac ma khong khoi dong lai CAD).
(defun TGIRR:UNDEF (name / result sym)
  (setq result (vl-catch-all-apply 'read (list (strcat "C:" name))))
  (if (vl-catch-all-error-p result)
    nil
    (progn
      (setq sym result)
      (if sym
        (progn
          (vl-catch-all-apply 'eval (list (list 'setq sym nil)))
          t)
        nil))))

(defun TGIRR:DROP (/ disabled count)
  (setq disabled (TGIRR:DISABLED-LIST))
  (setq count 0)
  (foreach name disabled
    (if (TGIRR:UNDEF name) (setq count (1+ count))))
  (prompt (strcat "\nTGIRR: Da go " (itoa count) " lenh dang tat khoi phien hien tai."))
  (princ))

;; Chan doan: liet ke thu muc, so lenh dang tat va trang thai vai lenh tieu bieu.
(defun c:TGIRRSTATUS () (TGIRR:STATUS))
(defun c:TGIRRLOAD () (TGIRR:RELOAD))
(defun c:TGIRRRELOAD () (TGIRR:RELOAD))
(defun c:TGIRRDROP () (TGIRR:DROP))

;; Khi khoi dong: manifest da nap 4 file .lsp, o day chi go cac lenh bi tat
;; va tao ten lenh .NET. Neu loader khong chay, cac lenh LISP van hoat dong.
(TGIRR:SAFE '(progn
  (setq TGIRR:LISP-DIR (TGIRR:LOADER-DIR))
  (TGIRR:APPLY-SETTINGS)
  (TGIRR:LOAD-FILE TGIRR:LISP-DIR "TGIRRCOMMANDS.lsp")
  (TGIRR:WARN-IF-ALL-OFF)))
(prompt "\nTGIRR: Bat/tat nap tung lenh bang TGIRRSETTINGS (trang thai: TGIRRSTATUS).")
(princ)