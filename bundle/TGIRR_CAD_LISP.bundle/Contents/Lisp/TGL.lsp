;;; TGIRR CAD LISP - TGL: Tao bo Layer tieu chuan
(vl-load-com)

(defun c:TGL ( / lstLayer item oldCmdecho *error*)
  (setq oldCmdecho (getvar "CMDECHO"))

  (defun *error* (msg)
    (setvar "CMDECHO" oldCmdecho)
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
  ))

  ;; Lap qua tung Layer trong danh sach
  (foreach item lstLayer
    (if (not (tblsearch "LAYER" (car item)))
      (command "_.-LAYER"
               "_New" (car item)
               "_Color" (cadr item) (car item)
               "_Ltype" (caddr item) (car item)
               "")
    )
  )

  ;; Dat TG-DRIP lam Layer hien hanh
  (command "_.-LAYER" "_Set" "TG-DRIP" "")

  (setvar "CMDECHO" oldCmdecho)
  (prompt "\nĐã tạo xong bộ Layer tiêu chuẩn và chuyển Layer hiện hành về TG-DRIP!")
  (princ)
)

(prompt "\nTGIRR: Đã nạp lệnh TGL - tạo bộ Layer tiêu chuẩn.")
(princ)