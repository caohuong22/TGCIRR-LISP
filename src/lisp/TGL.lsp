;;; TGIRR CAD LISP - TGL: Tao bo Layer tieu chuan
(vl-load-com)

;; Kho Layer tu them: luu trong registry theo nguoi dung, dung chung cho
;; AutoCAD/ZWCAD va khong lam thay doi file Lisp cai dat.
(defun TGL:read-custom (/ raw out p rec)
  (setq raw (vl-registry-read "HKEY_CURRENT_USER\\Software\\TGIRR" "LayerLibrary"))
  (if raw
    (foreach rec (read (strcat "(" raw ")"))
      (if (and (listp rec) (= (length rec) 3)) (setq out (cons rec out)))))
  (reverse out))

(defun TGL:write-custom (items / raw)
  ;; Ten layer/linetype khong dung dau | de tranh lam hong kho.
  (setq raw (apply 'strcat (mapcar '(lambda (x)
    (strcat "(" (vl-prin1-to-string x) ")")) items)))
  (vl-registry-write "HKEY_CURRENT_USER\\Software\\TGIRR" "LayerLibrary" raw))

(defun TGL:ensure (item / name color ltype)
  (setq name (car item) color (cadr item) ltype (caddr item))
  (if (and name (/= name "") (not (tblsearch "LAYER" name)))
    (progn
      (command "_.-LAYER" "_New" name "")
      (if (and color (/= color "")) (command "_.-LAYER" "_Color" color name ""))
      (if (and ltype (/= ltype "") (tblsearch "LTYPE" ltype))
        (command "_.-LAYER" "_Ltype" ltype name ""))
      T)))

(defun c:TGL ( / lstLayer item oldCmdecho *error*)
  (setq oldCmdecho (getvar "CMDECHO"))

  (defun *error* (msg)
    (if oldCmdecho (setvar "CMDECHO" oldCmdecho))
    (if (and msg (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*BREAK*")))
      (prompt (strcat "\nLoi TGL: " msg))
    )
    (princ)
  )

  (setvar "CMDECHO" 0)

  ;; Danh sach cac Layer: ("Ten Layer" "Mau Sac" "Loai Duong Net")
  (setq lstLayer '(
    ("TG-DRIP" "34" "Continuous")
    ("TG-DKT" "2" "Continuous")
    ("TG-MAIN PIPE" "1" "Continuous")
    ("TG-BOUND" "7" "Continuous")
    ("TG-SIG" "7" "Continuous")
    ("TG-TEXT" "7" "Continuous")
    ("TG-FREEZE" "7" "Continuous")
    ("TG-VUNG" "7" "Continuous")
    ("TG-BDK" "7" "Continuous")
    ("TG-PIPE 32" "40" "Continuous")
    ("TG-PIPE 40" "3" "Continuous")
    ("TG-PIPE 50" "6" "Continuous")
    ("TG-PIPE 63" "6" "Continuous")
    ("TG-PIPE 75" "5" "Continuous")
    ("TG-PIPE 90" "5" "Continuous")
    ("TG-SPR" "1" "Continuous")
    ("TG-VALVE" "42" "Continuous")
    ("TG-WIRE" "42" "Continuous")
    ("TG-CUV" "150" "Continuous")
    ("TG-XOE" "42" "Continuous")
    ("TG-XA KHI" "114" "Continuous")
    ("TG-QCV" "7" "Continuous")
    ("TG-LDPE 20" "4" "Continuous")
    ("TG-number" "7" "Continuous")
  ))

  ;; Them cac Layer da luu trong kho nguoi dung.
  (setq lstLayer (append lstLayer (TGL:read-custom)))

  ;; Lap qua tung Layer trong danh sach
  (foreach item lstLayer
    (TGL:ensure item))

  ;; Dat TG-DRIP lam Layer hien hanh
  (command "_.-LAYER" "_Set" "TG-DRIP" "")

  (setvar "CMDECHO" oldCmdecho)
  (prompt "\nĐã tạo xong bộ Layer tiêu chuẩn và chuyển Layer hiện hành về TG-DRIP!")
  (princ)
)

;; Them mot mau Layer vao kho va tao ngay trong ban ve.
(defun c:TGLADD (/ n c lt items item old)
  (setq n (getstring T "\nTen Layer moi: "))
  (if (or (null n) (= n ""))
    (prompt "\nTGLADD: Chua nhap ten Layer.")
    (progn
      (setq c (getstring T "\nMau ACI (1-255, mac dinh 7): "))
      (if (= c "") (setq c "7"))
      (setq lt (getstring T "\nTen linetype (mac dinh Continuous): "))
      (if (= lt "") (setq lt "Continuous"))
      (if (not (tblsearch "LTYPE" lt))
        (prompt (strcat "\nTGLADD: Chua nap linetype '" lt "'. Layer van duoc luu, se gan net khi nap LIN.")))
      (setq item (list n c lt) items (TGL:read-custom))
      (setq old (assoc n items))
      (if old (setq items (vl-remove old items)))
      (TGL:write-custom (cons item items))
      (TGL:ensure item)
      (prompt (strcat "\nTGLADD: Da them vao kho Layer: " n " [mau " c ", net " lt "]."))))
  (princ))

(prompt "\nTGIRR: Đã nạp lệnh TGL/TGLADD - tạo và thêm Layer vào kho.")
(princ)
