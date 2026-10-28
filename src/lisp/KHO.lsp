;;; ==========================================================================
;;; TGIRR CAD LISP - KHUNG TEN BAN VE
;;;
;;; KHO   : Chen khung ten (A4/A3/A2/A1) vao Layout hien hanh. Khung bao +
;;;         khung ten nam trong mot block (TGIRR_TB_<kho>), goc toa do (0,0)
;;;         nen doi kho chi can chay lai KHO.
;;; TENBV : Dien / dong bo thong tin khung ten. Du lieu duoc luu trong
;;;         dictionary TGIRR_PROJECT cua tung ban ve nen mo lai van con.
;;;
;;; Ho tro AutoCAD, ZWCAD va GstarCAD (chi dung entmake + lenh co ban).
;;; ==========================================================================
(vl-load-com)

;; Mot so nen tang khong co san stringp.
(if (null stringp)
  (defun stringp (x) (= (type x) 'STR)))

;;; ----- Du lieu kho giay ----------------------------------------------------
;;; (ten rong cao le-trai le-phai le-tren le-duoi) - don vi mm tren giay.
;;; Le trai rong de dong gay; A4 dung le nho hon cho vua khung ten.
(if (not *TGIRR:TB-SIZES*)
  (setq *TGIRR:TB-SIZES*
    '(("A4" 297.0 210.0 20.0 5.0 5.0 5.0)
      ("A3" 420.0 297.0 25.0 10.0 10.0 10.0)
      ("A2" 594.0 420.0 25.0 10.0 10.0 10.0)
      ("A1" 841.0 594.0 25.0 10.0 10.0 10.0))))

(if (not *TGIRR:TB-LAYER*)    (setq *TGIRR:TB-LAYER* "TG-KHUNG"))
(if (not *TGIRR:TB-STYLE*)    (setq *TGIRR:TB-STYLE* "TG-TITLE"))
(if (not *TGIRR:TB-DICTNAME*) (setq *TGIRR:TB-DICTNAME* "TGIRR_PROJECT"))
(if (not *TGIRR:TB-SIZE*)     (setq *TGIRR:TB-SIZE* "A3"))

;;; ----- Ham phu -------------------------------------------------------------
(defun TGIRR:TB-GETVAR (name / value)
  (setq value (vl-catch-all-apply 'getvar (list name)))
  (if (vl-catch-all-error-p value) nil value))

(defun TGIRR:TB-SETVAR (name value / result)
  (setq result (vl-catch-all-apply 'setvar (list name value)))
  (if (vl-catch-all-error-p result) nil value))

;; Dam bao layer ton tai, dang bat, khong khoa va khong dong bang.
;; Khong dung vl-catch-all-apply voi COMMAND: AutoCAD bao "bad order function: COMMAND".
(defun TGIRR:TB-ENSURE-LAYER (/ record data flags color)
  (if (not (tblsearch "LAYER" *TGIRR:TB-LAYER*))
    (progn
      (if (not (entmake
            (list '(0 . "LAYER") '(100 . "AcDbSymbolTableRecord") '(100 . "AcDbLayerTableRecord")
                  (cons 2 *TGIRR:TB-LAYER*) '(70 . 0) '(62 . 7) '(6 . "Continuous"))))
        (progn
          (TGIRR:TB-SETVAR "CMDECHO" 0)
          (command "_.-LAYER" "_New" *TGIRR:TB-LAYER* "")))))
  (setq record (tblobjname "LAYER" *TGIRR:TB-LAYER*))
  (if record
    (progn
      (setq data (entget record))
      ;; 70: bit 1 = dong bang, bit 4 = khoa -> xoa ca hai.
      (setq flags (logand (cdr (assoc 70 data)) 65530))
      (setq data (subst (cons 70 flags) (assoc 70 data) data))
      ;; 62 am = layer dang tat -> doi ve so duong.
      (setq color (cdr (assoc 62 data)))
      (if (and color (< color 0))
        (setq data (subst (cons 62 (abs color)) (assoc 62 data) data)))
      (entmod data)))
  (TGIRR:TB-SETVAR "CMDECHO" 0)
  *TGIRR:TB-LAYER*)

(defun TGIRR:TB-ENSURE-STYLE (/ created)
  (if (not (tblsearch "STYLE" *TGIRR:TB-STYLE*))
    (progn
      ;; arial.ttf co du dau tieng Viet; chieu cao 0 = moi TEXT tu dat chieu cao.
      (setq created (entmake
        (list '(0 . "STYLE") '(100 . "AcDbSymbolTableRecord") '(100 . "AcDbTextStyleTableRecord")
              (cons 2 *TGIRR:TB-STYLE*) '(70 . 0) '(40 . 0.0) '(41 . 1.0) '(50 . 0.0)
              '(71 . 0) '(42 . 2.5) '(3 . "arial.ttf") '(4 . ""))))
      (if (not created)
        (progn
          (TGIRR:TB-SETVAR "CMDECHO" 0)
          (command "_.-STYLE" *TGIRR:TB-STYLE* "arial.ttf" "0" "1" "0" "N" "N")))))
  *TGIRR:TB-STYLE*)

(defun TGIRR:TB-TODAY (/ value)
  (setq value (vl-catch-all-apply 'menucmd
                (list "M=$(edtime,$(getvar,date),DD/MM/YYYY)")))
  (if (and (not (vl-catch-all-error-p value)) (= (type value) 'STR))
    value
    ""))

;;; ----- Ve trong dinh nghia block -------------------------------------------
(defun TGIRR:TB-LINE (p1 p2)
  (entmake (list '(0 . "LINE")
                 (cons 8 *TGIRR:TB-LAYER*)
                 (cons 10 p1)
                 (cons 11 p2))))

(defun TGIRR:TB-PLINE (points closed / data)
  ;; AutoCAD 2024+ doi hoi day du marker lop con, neu thieu entmake tra nil
  ;; va cac dinh se roi ra ngoai paper space thay vi nam trong block.
  (setq data (list '(0 . "LWPOLYLINE")
                   '(100 . "AcDbEntity")
                   (cons 8 *TGIRR:TB-LAYER*)
                   '(100 . "AcDbPolyline")
                   (cons 90 (length points))
                   (cons 70 (if closed 1 0))))
  (foreach p points
    (setq data (append data (list (cons 10 p)))))
  (entmake data))

(defun TGIRR:TB-TEXT (point height text width-factor)
  (entmake (list '(0 . "TEXT")
                 (cons 8 *TGIRR:TB-LAYER*)
                 (cons 10 point)
                 (cons 40 height)
                 (cons 1 text)
                 (cons 50 0.0)
                 (cons 7 *TGIRR:TB-STYLE*)
                 (cons 41 width-factor)
                 '(72 . 0)
                 (cons 11 point))))

(defun TGIRR:TB-ATTDEF (point height tag prompt value width-factor)
  (entmake (list '(0 . "ATTDEF")
                 (cons 8 *TGIRR:TB-LAYER*)
                 (cons 10 point)
                 (cons 40 height)
                 (cons 1 value)
                 (cons 50 0.0)
                 (cons 7 *TGIRR:TB-STYLE*)
                 (cons 41 width-factor)
                 '(70 . 0)
                 (cons 3 prompt)
                 (cons 2 tag))))

;; Mot o khung ten: nhan nho phia tren, attribute gia tri phia duoi.
(defun TGIRR:TB-CELL (x y w h label tag value value-height width-factor)
  (TGIRR:TB-TEXT (list (+ x 1.5) (+ y (- h 4.0)) 0.0) 2.0 label 1.0)
  (TGIRR:TB-ATTDEF (list (+ x 1.5) (+ y 3.2) 0.0) value-height tag label value width-factor))

;; Khung ten 180x70 dat tai (x0,y0) = goc trai duoi cua khung ten.
(defun TGIRR:TB-DRAW-TITLE (x0 y0 / x1 y1 col-left i w1)
  (setq x1 (+ x0 180.0)
        y1 (+ y0 70.0))
  (TGIRR:TB-PLINE (list (list x0 y0) (list x1 y0) (list x1 y1) (list x0 y1)) T)

  ;; Cot trai 110 / cot phai 70.
  (setq col-left (+ x0 110.0))
  (TGIRR:TB-LINE (list col-left y0) (list col-left y1))

  ;; 5 hang, moi hang 14mm.
  (setq i 1)
  (while (< i 5)
    (TGIRR:TB-LINE (list x0 (+ y0 (* 14.0 i))) (list x1 (+ y0 (* 14.0 i))))
    (setq i (1+ i)))

  ;; Hang duoi cung ben trai chia 3 o: nguoi ve / kiem tra / chu tri.
  (setq w1 (/ 110.0 3.0))
  (TGIRR:TB-LINE (list (+ x0 w1) y0) (list (+ x0 w1) (+ y0 14.0)))
  (TGIRR:TB-LINE (list (+ x0 w1 w1) y0) (list (+ x0 w1 w1) (+ y0 14.0)))

  ;; Cot trai, tu duoi len.
  (TGIRR:TB-CELL x0 y0 w1 14.0 "NGƯỜI VẼ" "NGUOI_VE" "" 2.8 0.8)
  (TGIRR:TB-CELL (+ x0 w1) y0 w1 14.0 "KIỂM TRA" "NGUOI_KT" "" 2.8 0.8)
  (TGIRR:TB-CELL (+ x0 w1 w1) y0 (- 110.0 w1 w1) 14.0 "CHỦ TRÌ" "CHU_TRI" "" 2.8 0.8)
  (TGIRR:TB-CELL x0 (+ y0 14.0) 110.0 14.0 "TÊN BẢN VẼ" "TEN_BV" "" 3.5 0.9)
  (TGIRR:TB-CELL x0 (+ y0 28.0) 110.0 14.0 "HẠNG MỤC" "HANG_MUC" "" 3.2 0.9)
  (TGIRR:TB-CELL x0 (+ y0 42.0) 110.0 14.0 "CÔNG TRÌNH" "CONG_TRINH" "" 3.2 0.9)
  (TGIRR:TB-CELL x0 (+ y0 56.0) 110.0 14.0 "ĐƠN VỊ THIẾT KẾ" "CONG_TY" "" 3.2 0.9)

  ;; Cot phai, tu duoi len.
  (TGIRR:TB-CELL col-left y0 70.0 14.0 "SỐ TỜ" "SO_TO" "01/01" 3.2 0.9)
  (TGIRR:TB-CELL col-left (+ y0 14.0) 70.0 14.0 "NGÀY" "NGAY" "" 3.2 0.9)
  (TGIRR:TB-CELL col-left (+ y0 28.0) 70.0 14.0 "TỶ LỆ" "TYLE" "1:100" 3.2 0.9)
  (TGIRR:TB-CELL col-left (+ y0 42.0) 70.0 14.0 "SỐ BẢN VẼ" "SO_BV" "" 3.2 0.9)
  (TGIRR:TB-CELL col-left (+ y0 56.0) 70.0 14.0 "PHIÊN BẢN" "PHIEN_BAN" "01" 3.2 0.9))

;; Block rong (do mot lan tao loi truoc day) khong dung lai duoc: chon ten moi.
(defun TGIRR:TB-BLOCK-EMPTY-P (name / record entity data count)
  (setq record (tblobjname "BLOCK" name))
  (if (not record)
    T
    (progn
      (setq entity (entnext record)
            count 0)
      (while (and entity (setq data (entget entity)) (/= "ENDBLK" (cdr (assoc 0 data))))
        (setq count (1+ count)
              entity (entnext entity)))
      (= count 0))))

(defun TGIRR:TB-BLOCK-NAME (base / name i)
  (setq name base
        i 2)
  (while (and (tblsearch "BLOCK" name) (TGIRR:TB-BLOCK-EMPTY-P name))
    (setq name (strcat base "_V" (itoa i))
          i (1+ i)))
  name)

;; Dinh nghia block TGIRR_TB_<kho> = khung bao trong + khung ten.
(defun TGIRR:TB-BLOCK-DEFINE (name size / spec ok)
  (if (tblsearch "BLOCK" name)
    T
    (progn
      (setq spec (assoc size *TGIRR:TB-SIZES*))
      (if (not spec)
        nil
        (progn
          ;; 70 = 2: block co attribute definition. Phai co du marker
          ;; AcDbEntity/AcDbBlockBegin, neu khong AutoCAD 2025 bo qua BLOCK
          ;; va cac entmake sau do roi ra paper space.
          (setq ok (entmake (list '(0 . "BLOCK")
                                  '(100 . "AcDbEntity")
                                  '(8 . "0")
                                  '(100 . "AcDbBlockBegin")
                                  (cons 2 name)
                                  '(70 . 2)
                                  '(10 0.0 0.0 0.0)
                                  (cons 3 name)
                                  '(1 . ""))))
          (if ok
            (progn
              ;; Khung bao trong (le trai/phai/tren/duoi).
              (TGIRR:TB-PLINE
                (list (list (nth 3 spec) (nth 6 spec))
                      (list (- (nth 1 spec) (nth 4 spec)) (nth 6 spec))
                      (list (- (nth 1 spec) (nth 4 spec)) (- (nth 2 spec) (nth 5 spec)))
                      (list (nth 3 spec) (- (nth 2 spec) (nth 5 spec))))
                T)
              ;; Khung ten goc phai duoi cua khung bao.
              (TGIRR:TB-DRAW-TITLE (- (nth 1 spec) (nth 4 spec) 180.0) (nth 6 spec))
              (entmake '((0 . "ENDBLK") (100 . "AcDbEntity") (8 . "0") (100 . "AcDbBlockEnd")))
              ;; Chi bao thanh cong khi block that su ton tai.
              (if (tblsearch "BLOCK" name) T nil))
            nil))))))

;;; ----- Chen block vao Layout ----------------------------------------------
(defun TGIRR:TB-PREPARE (/ answer)
  (if (= 1 (TGIRR:TB-GETVAR "TILEMODE"))
    (progn
      (setq answer (getstring
        "\nKhung tên phải nằm trong Layout (paper space). Chuyển sang layout? [Y/n] <Y>: "))
      (if (or (= answer "") (= (strcase answer) "Y"))
        (progn
          (TGIRR:TB-SETVAR "TILEMODE" 0)
          (TGIRR:TB-SETVAR "CVPORT" 1)
          T)
        nil))
    (progn
      (TGIRR:TB-SETVAR "CVPORT" 1)
      T)))

(defun TGIRR:TB-ASK-SIZE (/ answer)
  (setq answer (getstring (strcat "\nKhổ giấy [A4/A3/A2/A1] <" *TGIRR:TB-SIZE* ">: ")))
  (if (= answer "")
    (setq answer *TGIRR:TB-SIZE*)
    (setq answer (strcase answer)))
  (if (assoc answer *TGIRR:TB-SIZES*)
    (progn (setq *TGIRR:TB-SIZE* answer) answer)
    (progn (prompt "\nKhổ giấy không hợp lệ.") nil)))

(defun TGIRR:TB-INSERTS (all / ss i entity result)
  (setq i 0 result nil)
  (setq ss (ssget "_X" (append (list '(0 . "INSERT") '(2 . "TGIRR_TB_*"))
                               (if all nil (list (cons 410 (TGIRR:TB-GETVAR "CTAB")))))))
  (if ss
    (while (< i (sslength ss))
      (setq result (cons (ssname ss i) result)
            i (1+ i))))
  result)

(defun TGIRR:TB-INSERT (name point / old-clayer old-attreq result entity data)
  (setq old-clayer (TGIRR:TB-GETVAR "CLAYER"))
  (TGIRR:TB-SETVAR "CLAYER" *TGIRR:TB-LAYER*)
  ;; ATTREQ=0: khong hoi gia tri attribute, tao attrib voi gia tri mac dinh.
  (setq old-attreq (TGIRR:TB-GETVAR "ATTREQ"))
  (if old-attreq (TGIRR:TB-SETVAR "ATTREQ" 0))
  (setq result (command "_.-INSERT" name point 1.0 1.0 0.0))
  (if old-attreq (TGIRR:TB-SETVAR "ATTREQ" old-attreq))
  (if old-clayer (TGIRR:TB-SETVAR "CLAYER" old-clayer))
  ;; Chi coi la thanh cong khi entlast dung la block vua chen.
  (setq entity (if (vl-catch-all-error-p result) nil (entlast)))
  (setq data (if entity (entget entity)))
  (if (and data
           (= "INSERT" (cdr (assoc 0 data)))
           (= (strcase name) (strcase (cdr (assoc 2 data)))))
    entity
    nil))

;;; ----- Doc / ghi attribute -------------------------------------------------
(defun TGIRR:TB-VALUES (insert / entity data result)
  (setq entity (entnext insert))
  (while (and entity (setq data (entget entity)) (= "ATTRIB" (cdr (assoc 0 data))))
    (setq result (cons (cons (cdr (assoc 2 data)) (cdr (assoc 1 data))) result))
    (setq entity (entnext entity)))
  result)

(defun TGIRR:TB-ATTR-READ (insert tag / entity data value)
  (setq entity (entnext insert))
  (while (and entity (setq data (entget entity)) (= "ATTRIB" (cdr (assoc 0 data))))
    (if (= tag (cdr (assoc 2 data)))
      (setq value (cdr (assoc 1 data))))
    (setq entity (entnext entity)))
  value)

(defun TGIRR:TB-ATTR-PUT (insert tag value / entity data)
  (setq entity (entnext insert))
  (while (and entity (setq data (entget entity)) (= "ATTRIB" (cdr (assoc 0 data))))
    (if (= tag (cdr (assoc 2 data)))
      (progn
        (entmod (subst (cons 1 value) (assoc 1 data) data))
        (entupd entity)))
    (setq entity (entnext entity))))

;;; ----- Luu thong tin theo tung ban ve -------------------------------------
(defun TGIRR:TB-DICT (create / dictionary)
  (setq dictionary (cdr (assoc -1 (dictsearch (namedobjdict) *TGIRR:TB-DICTNAME*))))
  (if (and (not dictionary) create)
    (progn
      (setq dictionary (entmakex '((0 . "DICTIONARY") (100 . "AcDbDictionary"))))
      (if dictionary
        (dictadd (namedobjdict) *TGIRR:TB-DICTNAME* dictionary))))
  dictionary)

(defun TGIRR:TB-DATA-GET (tag / dictionary record entity data)
  (setq dictionary (TGIRR:TB-DICT nil))
  (if dictionary
    (progn
      (setq record (dictsearch dictionary tag))
      (if record
        (progn
          (setq entity (cdr (assoc -1 record)))
          (setq data (if entity (entget entity)))
          (if data (cdr (assoc 1 data))))))))

(defun TGIRR:TB-DATA-PUT (tag value / dictionary record xrecord)
  (setq dictionary (TGIRR:TB-DICT T))
  (if dictionary
    (progn
      ;; entmod tren XRECORD khong on dinh o moi CAD: go roi them lai.
      (if (dictsearch dictionary tag) (dictremove dictionary tag))
      (setq xrecord (entmakex (list '(0 . "XRECORD") '(100 . "AcDbXrecord") (cons 1 value))))
      (if xrecord (dictadd dictionary tag xrecord))))
  value)

;;; ----- Danh sach truong cua khung ten --------------------------------------
(defun TGIRR:TB-FIELDS ()
  (list
    (list "CONG_TY"     "Đơn vị thiết kế" "")
    (list "CONG_TRINH"  "Công trình"      "")
    (list "HANG_MUC"    "Hạng mục"        "")
    (list "TEN_BV"      "Tên bản vẽ"      "")
    (list "SO_BV"       "Số bản vẽ"       "")
    (list "TYLE"        "Tỷ lệ"           "1:100")
    (list "NGAY"        "Ngày"            "")
    (list "PHIEN_BAN"   "Phiên bản"       "01")
    (list "NGUOI_VE"    "Người vẽ"        "")
    (list "NGUOI_KT"    "Kiểm tra"        "")
    (list "CHU_TRI"     "Chủ trì"         "")
    (list "SO_TO"       "Số tờ"           "01/01")))

(defun TGIRR:TB-ASK (label default / hint answer)
  (setq hint (if (and default (/= default "")) (strcat " <" default ">") ""))
  (setq answer (getstring T (strcat "\n" label hint ": ")))
  (if (= answer "") (if default default "") answer))

;;; ==========================================================================
;;; KHO - chen khung ten
;;;
;;; Uu tien khung mau dong goi TGIRR_TB_A2.dwg (khung TRONG: chi con net
;;; khung/grid, khong logo, khong chu, khong attribute). Kich thuoc da chuan
;;; hoa ve goc (0,0): rong 463.162 x cao 327.489 (do tu file mau).
;;; Khi chen: k = (paperW - 20) / 463.162 (le ngang 10mm), canh giua theo
;;; chieu doc. Nguoi dung tu them text/noi dung vao cac o.
;;; Khong tim thay file mau thi quay ve khung don gian ve bang entmake.
;;; ==========================================================================
(defun TGIRR:TB-ASSET-PATH (/ dirs dir sub candidate path)
  (setq dirs (list
    (if (boundp 'TGIRR:LISP-DIR) TGIRR:LISP-DIR)
    (if (boundp '*TGIRR:ZW-ROOT*) *TGIRR:ZW-ROOT*)
    (if (boundp '*TGIRR:G-ROOT*) *TGIRR:G-ROOT*)))
  (foreach dir dirs
    (if (and (not path) dir (= (type dir) 'STR) (> (strlen dir) 0))
      (foreach sub (list "" "\\Lisp" "\\Contents\\Lisp")
        (if (not path)
          (progn
            (setq candidate (strcat (vl-string-right-trim "\\" dir) sub "\\TGIRR_TB_A2.dwg"))
            (if (findfile candidate) (setq path candidate)))))))
  (if (not path) (setq path (findfile "TGIRR_TB_A2.dwg")))
  path)

(defun TGIRR:TB-INSERT-TEMPLATE (path size / spec k point old-clayer entity data)
  (setq spec (assoc size *TGIRR:TB-SIZES*))
  (if (not spec)
    nil
    (progn
      (setq k (/ (- (nth 1 spec) 20.0) 463.162))
      (setq point (list 10.0
                        (/ (- (nth 2 spec) (* 327.489 k)) 2.0)
                        0.0))
      (setq old-clayer (TGIRR:TB-GETVAR "CLAYER"))
      (TGIRR:TB-SETVAR "CLAYER" *TGIRR:TB-LAYER*)
      (command "_.-INSERT" path point k k 0.0)
      (if old-clayer (TGIRR:TB-SETVAR "CLAYER" old-clayer))
      (setq entity (entlast))
      (setq data (if entity (entget entity)))
      (if (and data
               (= "INSERT" (cdr (assoc 0 data)))
               (= "TGIRR_TB_A2" (strcase (cdr (assoc 2 data)))))
        entity
        nil))))

(defun TGIRR:TB-MEDIA-MATCH (names w h / target n key)
  ;; Uu tien ten media co dung kich thuoc NGANG x DAI (vd 420.00_x_297.00),
  ;; tranh chon nham ban portrait cung kho (297.00_x_420.00).
  (setq key (strcat (rtos w 2 2) "_X_" (rtos h 2 2)))
  (foreach n names
    (if (and (not target) n (= (type n) 'STR)
             (vl-string-search key (vl-string-translate " " "_" (strcase n))))
      (setq target n)))
  target)

;; Dat Page Setup cua Layout: kho giay, vung in = Layout, ty le 1:1.
;; Nho vay Print/Preview dung dung to giay cua khung vua chen.
;; Dung ActiveX va bo qua loi tren cac CAD khong ho tro day du thuoc tinh.
(defun TGIRR:TB-PAGESETUP (size / spec app doc lay names media)
  (setq spec (assoc size *TGIRR:TB-SIZES*))
  (if spec
    (progn
      (setq app (vl-catch-all-apply 'vlax-get-acad-object '()))
      (if (not (vl-catch-all-error-p app))
        (progn
          (setq doc (vl-catch-all-apply 'vla-get-ActiveDocument (list app)))
          (if (not (vl-catch-all-error-p doc))
            (progn
              (setq lay (vl-catch-all-apply 'vla-get-ActiveLayout (list doc)))
              (if (not (vl-catch-all-error-p lay))
                (progn
                  ;; 1 = milimet
                  (vl-catch-all-apply 'vla-put-PaperUnits (list lay 1))
                  (setq names (vl-catch-all-apply 'vla-GetCanonicalMediaNames (list lay)))
                  (if (not (vl-catch-all-error-p names))
                    (progn
                      (setq names (vl-catch-all-apply 'vlax-safearray->list
                                    (list (vlax-variant-value names))))
                      (if (not (vl-catch-all-error-p names))
                        (progn
                          (setq media (TGIRR:TB-MEDIA-MATCH names (nth 1 spec) (nth 2 spec)))
                          (if media
                            (vl-catch-all-apply 'vla-put-CanonicalMediaName (list lay media))
                            (prompt (strcat "\nChưa tìm thấy khổ in " size
                                           " trong máy in hiện tại - hãy chọn khổ trong Page Setup.")))))))
                  ;; 5 = acLayout (in toan bo to giay)
                  (vl-catch-all-apply 'vla-put-PlotType (list lay 5))
                  (vl-catch-all-apply 'vla-put-UseStandardScale (list lay :vlax-true))
                  ;; 16 = acScale1to1
                  (vl-catch-all-apply 'vla-put-StandardScale (list lay 16))
                  (vl-catch-all-apply 'vla-put-PlotRotation (list lay 0))
                  T)))))))))

;; Khung don gian (du phong khi thieu file TGIRR_TB_A2.dwg).
(defun TGIRR:TB-INSERT-SIMPLE (size / name existing replace answer keep point insert)
  (setq name (TGIRR:TB-BLOCK-NAME (strcat "TGIRR_TB_" size)))
  (setq existing (TGIRR:TB-INSERTS nil))
  (setq replace nil
        keep nil)
  (if existing
    (progn
      (setq answer (getstring
        "\nLayout đã có khung tên. Thay thế (giữ thông tin đã điền)? [Y/n] <Y>: "))
      (if (or (= answer "") (= (strcase answer) "Y"))
        (progn
          (setq replace T)
          (setq keep (TGIRR:TB-VALUES (car existing)))
          (foreach entity existing (entdel entity))))))
  (if (or (not existing) replace)
    (progn
      (if (not (TGIRR:TB-BLOCK-DEFINE name size))
        (prompt (strcat "\nKhông tạo được block " name "."))
        (progn
          (setq point (list 0.0 0.0 0.0))
          (setq insert (TGIRR:TB-INSERT name point))
          (if insert
            (progn
              (TGIRR:TB-PAGESETUP size)
              (prompt (strcat "\nĐã đặt khổ in " size
                             ", vùng in Layout, tỷ lệ 1:1, canh giữa.")))
            (prompt (strcat "\nKhông chèn được block " name "."))))))
    (prompt "\nGiữ nguyên khung tên hiện có."))
  (princ))

(defun c:KHO (/ size path existing replace answer insert)
  (if (not (TGIRR:TB-PREPARE))
    (prompt "\nĐã hủy: khung tên chỉ đặt được trong Layout.")
    (progn
      (TGIRR:TB-ENSURE-LAYER)
      (TGIRR:TB-ENSURE-STYLE)
      (setq size (TGIRR:TB-ASK-SIZE))
      (if size
        (progn
          (setq path (TGIRR:TB-ASSET-PATH))
          (if path
            (progn
              (setq existing (TGIRR:TB-INSERTS nil)
                    replace nil)
              (if existing
                (progn
                  (setq answer (getstring
                    "\nLayout đã có khung. Thay thế? (chữ đã sửa sẽ mất) [Y/n] <Y>: "))
                  (if (or (= answer "") (= (strcase answer) "Y"))
                    (progn
                      (setq replace T)
                      (foreach entity existing (entdel entity))))))
              (if (or (not existing) replace)
                (progn
                  (setq insert (TGIRR:TB-INSERT-TEMPLATE path size))
                  (if insert
                    (progn
                      (TGIRR:TB-PAGESETUP size)
                      (prompt (strcat "\nĐã chèn khung trống " size
                                     " và đặt in Layout 1:1. Tự thêm text vào các ô.")))
                    (prompt "\nKhông chèn được khung (kiểm tra TGIRR_TB_A2.dwg).")))
                (prompt "\nGiữ nguyên khung hiện có.")))
            (TGIRR:TB-INSERT-SIMPLE size))))
      (princ))))

;;; ==========================================================================
;;; TENBV - dien / dong bo thong tin khung ten
;;; ==========================================================================
(defun c:TENBV (/ answer all inserts field tag label default current value values count entity has-attr)
  (if (not (TGIRR:TB-PREPARE))
    (prompt "\nĐã hủy.")
    (progn
      (setq answer (getstring "\nÁp dụng cho [T]ất cả layout / [L]ayout hiện tại <L>: "))
      (setq all (= (strcase answer) "T"))
      (setq inserts (TGIRR:TB-INSERTS all))
      (setq has-attr nil)
      (foreach entity inserts
        (if (TGIRR:TB-VALUES entity) (setq has-attr T)))
      (cond
        ((not inserts)
         (prompt "\nChưa có khung tên trên bản vẽ. Gõ KHO để chèn khung tên trước."))
        ((not has-attr)
         (prompt "\nKhung mẫu không có attribute: hãy sửa trực tiếp các dòng chữ trong khung."))
        (T
          (foreach field (TGIRR:TB-FIELDS)
            (setq tag (nth 0 field)
                  label (nth 1 field)
                  default (nth 2 field))
            (setq current (TGIRR:TB-DATA-GET tag))
            (if (not current) (setq current (TGIRR:TB-ATTR-READ (car inserts) tag)))
            (if (not current) (setq current default))
            (if (and (= tag "NGAY") (= current "")) (setq current (TGIRR:TB-TODAY)))
            (setq value (TGIRR:TB-ASK label current))
            (TGIRR:TB-DATA-PUT tag value)
            (setq values (cons (cons tag value) values)))
          (setq count 0)
          (foreach entity inserts
            (foreach pair values
              (TGIRR:TB-ATTR-PUT entity (car pair) (cdr pair)))
            (setq count (1+ count)))
          (prompt (strcat "\nĐã cập nhật " (itoa count) " khung tên."))))
      (princ))))

(prompt "\nTGIRR: Đã nạp KHO (khung tên) và TENBV (điền thông tin bản vẽ).")
(princ)
