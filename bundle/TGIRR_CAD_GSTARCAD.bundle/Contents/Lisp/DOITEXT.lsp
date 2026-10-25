;;; ==========================================================================
;;; TGIRR CAD LISP - LENH DOITEXT / M2T (MTEXT TO TEXT & LIST CONVERTER)
;;;
;;; Tinh nang:
;;;   1. Gom danh sach (List):
;;;      - Quet chon nhieu MText (hoac Text), tu dong tach cac dong noi dung.
;;;      - Sap xep thu tu tu tren xuong duoi (Y giam dan, X tang dan).
;;;      - Cho phep pick diem chen moi hoac giu vi tri tren cung lam goc.
;;;      - Cho phep nhap hoac do khoang cach dong (mac dinh 1.5 * textHeight).
;;;      - Tao danh sach cot TEXT thang hang deu dan, dep mat.
;;;   2. Tai cho (In-place):
;;;      - Chuyen tung MText thanh cac doi tuong TEXT tai dung vi tri, goc xoay,
;;;        layer, text style, chieu cao va mau sac tren ban ve.
;;;   3. Tuy chon xoa MText goc sau khi chuyen doi.
;;;
;;; Tuong thich: AutoCAD, ZWCAD, GstarCAD
;;; ==========================================================================

(vl-load-com)

;;; --------------------------------------------------------------------------
;;; 1. HAM BOC TACH VA LAM SACH CHUOI MTEXT SANG DANH SACH CAC DONG TEXT
;;; --------------------------------------------------------------------------
(defun tgirr:parse-mtext-to-lines (raw / len i ch chNext curLine lines add-line pos stackContent)
  (setq len (if (and raw (= (type raw) 'STR)) (strlen raw) 0)
        i 1
        curLine ""
        lines '())

  ;; Ham them 1 dong vao danh sach (bo dong trong neu can)
  (defun add-line (l / trimmed)
    (setq trimmed (vl-string-trim " \t\r\n" l))
    (if (> (strlen trimmed) 0)
      (setq lines (append lines (list trimmed)))))

  (while (<= i len)
    (setq ch (substr raw i 1))
    (cond
      ;; Gặp ký tự gạch chéo ngược '\' (escape code của MText)
      ((= ch "\\")
        (setq i (1+ i))
        (if (<= i len)
          (progn
            (setq chNext (substr raw i 1))
            (cond
              ;; Ngắt dòng MText: chỉ \P (chữ P hoa). \p (chữ thường) là paragraph properties.
              ((= chNext "P")
                (add-line curLine)
                (setq curLine "")
                (setq i (1+ i)))

              ;; Dấu backslash kép: \\ -> in ra 1 dấu \
              ((= chNext "\\")
                (setq curLine (strcat curLine "\\"))
                (setq i (1+ i)))

              ;; Dấu ngoặc nhọn: \{ và \}
              ((= chNext "{")
                (setq curLine (strcat curLine "{"))
                (setq i (1+ i)))
              ((= chNext "}")
                (setq curLine (strcat curLine "}"))
                (setq i (1+ i)))

              ;; Khoảng trắng cứng (non-breaking space): \~ -> khoảng trắng thường
              ((= chNext "~")
                (setq curLine (strcat curLine " "))
                (setq i (1+ i)))

              ;; Cờ 1 ký tự: gạch chân, gạch trên, gạch ngang (\L, \l, \O, \o, \K, \k, \X, \x)
              ((vl-position (strcase chNext) '("L" "O" "K" "X"))
                (setq i (1+ i)))

              ;; Ký tự Unicode: \U+xxxx (giữ nguyên cho engine TEXT AutoCAD/CAD hiển thị ký hiệu)
              ((and (or (= chNext "U") (= chNext "u"))
                    (<= (+ i 5) len)
                    (= (substr raw (1+ i) 1) "+"))
                (setq curLine (strcat curLine (substr raw (1- i) 7)))
                (setq i (+ i 6)))

              ;; Stacking: \S...; (phân số / chỉ số)
              ((or (= chNext "S") (= chNext "s"))
                (setq i (1+ i) stackContent "")
                (while (and (<= i len) (/= (substr raw i 1) ";"))
                  (setq stackContent (strcat stackContent (substr raw i 1)))
                  (setq i (1+ i)))
                (if (<= i len) (setq i (1+ i))) ; bỏ qua dấu ';'
                ;; Thay ký tự phân cách ^ hoặc # bằng /
                (while (setq pos (vl-string-search "^" stackContent))
                  (setq stackContent (strcat (substr stackContent 1 pos) "/" (substr stackContent (+ pos 2)))))
                (while (setq pos (vl-string-search "#" stackContent))
                  (setq stackContent (strcat (substr stackContent 1 pos) "/" (substr stackContent (+ pos 2)))))
                (setq curLine (strcat curLine stackContent)))

              ;; Các mã định dạng font, màu, cỡ... kết thúc bởi ';': \f, \C, \H, \W, \Q, \A, \T, \p (paragraph)
              ((vl-position (strcase chNext) '("F" "C" "H" "W" "Q" "A" "T" "P"))
                (setq i (1+ i))
                (while (and (<= i len) (/= (substr raw i 1) ";"))
                  (setq i (1+ i)))
                (if (<= i len) (setq i (1+ i))))

              ;; Mặc định bỏ qua ký tự escape không xác định
              (t
                (setq i (1+ i)))
            )
          )
        )
      )

      ;; Bỏ qua ngoặc nhóm định dạng '{' và '}'
      ((or (= ch "{") (= ch "}"))
        (setq i (1+ i)))

      ;; Ký tự xuống dòng đơn '\n' hoặc '\r'
      ((= ch "\n")
        (add-line curLine)
        (setq curLine "")
        (setq i (1+ i)))
      ((= ch "\r")
        (setq i (1+ i)))

      ;; Ký tự văn bản thông thường
      (t
        (setq curLine (strcat curLine ch))
        (setq i (1+ i)))
    )
  )

  (if (> (strlen curLine) 0)
    (add-line curLine))

  lines
)

;;; --------------------------------------------------------------------------
;;; 2. HAM DOC CHUOI RAW VA THUOC TINH CUA DOI TUONG
;;; --------------------------------------------------------------------------

;; Ghep nhom DXF 3 (cac doan dau) va nhom 1 (doan cuoi) thanh noi dung MText day du
(defun tgirr:mtext-raw (ed / raw)
  (setq raw "")
  (foreach item ed
    (if (or (= (car item) 3) (= (car item) 1))
      (setq raw (strcat raw (cdr item)))))
  raw)

;; Goc xoay MText: uu tien ma 50, sau do den vector huong (nhom 11)
(defun tgirr:mtext-rotation (ed / vec)
  (cond
    ((cdr (assoc 50 ed)))
    ((and (setq vec (cdr (assoc 11 ed)))
          (not (equal vec '(0.0 0.0 0.0) 1e-8)))
     (atan (cadr vec) (car vec)))
    (t 0.0)))

;; Tra ve alist thuoc tinh doi tuong; nil neu khong co noi dung chu
(defun tgirr:get-entity-data (ent / ed typ rawStr lines)
  (setq ed  (entget ent)
        typ (cdr (assoc 0 ed)))
  (cond
    ((= typ "MTEXT")
      (setq lines (tgirr:parse-mtext-to-lines (tgirr:mtext-raw ed)))
      (if lines
        (list
          (cons 'ent        ent)
          (cons 'type       typ)
          (cons 'pt         (cdr (assoc 10 ed)))
          (cons 'height     (if (cdr (assoc 40 ed)) (cdr (assoc 40 ed)) (getvar "TEXTSIZE")))
          (cons 'rot        (tgirr:mtext-rotation ed))
          (cons 'layer      (cdr (assoc 8 ed)))
          (cons 'style      (cdr (assoc 7 ed)))
          (cons 'color      (cdr (assoc 62 ed)))
          (cons 'truecolor  (cdr (assoc 420 ed)))
          (cons 'ltype      (cdr (assoc 6 ed)))
          (cons 'lineweight (cdr (assoc 370 ed)))
          (cons 'attach     (if (cdr (assoc 71 ed)) (cdr (assoc 71 ed)) 1))
          (cons 'lines      lines))
        nil))

    ((= typ "TEXT")
      (setq rawStr (cdr (assoc 1 ed)))
      (if (/= (type rawStr) 'STR) (setq rawStr ""))
      (setq rawStr (vl-string-trim " \t\r\n" rawStr))
      (if (> (strlen rawStr) 0)
        (list
          (cons 'ent        ent)
          (cons 'type       typ)
          (cons 'pt         (cdr (assoc 10 ed)))
          (cons 'height     (if (cdr (assoc 40 ed)) (cdr (assoc 40 ed)) (getvar "TEXTSIZE")))
          (cons 'rot        (if (cdr (assoc 50 ed)) (cdr (assoc 50 ed)) 0.0))
          (cons 'layer      (cdr (assoc 8 ed)))
          (cons 'style      (cdr (assoc 7 ed)))
          (cons 'color      (cdr (assoc 62 ed)))
          (cons 'truecolor  (cdr (assoc 420 ed)))
          (cons 'ltype      (cdr (assoc 6 ed)))
          (cons 'lineweight (cdr (assoc 370 ed)))
          (cons 'attach     1)
          (cons 'lines      (list rawStr)))
        nil))

    (t nil)
  )
)

;;; --------------------------------------------------------------------------
;;; 3. HAM TAO DOI TUONG TEXT BANG ENTMAKE
;;; --------------------------------------------------------------------------
;; justH: 0=trai 1=giua 2=phai | justV: 0=baseline 1=duoi 2=giua 3=tren
(defun tgirr:make-text (str pt height rot layer style color tc ltype lw justH justV
                        / dxf)
  (if (and str (> (strlen str) 0))
    (progn
      ;; Layer / text style phai ton tai, neu khong entmake se that bai
      (if (not (and layer (/= layer "") (tblsearch "LAYER" layer)))
        (setq layer (getvar "CLAYER")))
      (if (not (and style (/= style "") (tblsearch "STYLE" style)))
        (setq style (getvar "TEXTSTYLE")))
      (if (or (null height) (<= height 0.0)) (setq height (getvar "TEXTSIZE")))
      (if (or (null height) (<= height 0.0)) (setq height 2.5))
      (setq pt (list (car pt) (cadr pt) (if (caddr pt) (caddr pt) 0.0)))

      ;; Thu tu nhom DXF phai dung chuan: cac ma AcDbEntity nam truoc marker AcDbText
      (setq dxf (list '(0 . "TEXT")
                      '(100 . "AcDbEntity")
                      (cons 8 layer)))
      (if (and ltype (/= ltype "") (tblsearch "LTYPE" ltype))
        (setq dxf (append dxf (list (cons 6 ltype)))))
      (if (and lw (numberp lw) (> lw 0))
        (setq dxf (append dxf (list (cons 370 lw)))))
      (if (and color (numberp color) (> color 0) (< color 256))
        (setq dxf (append dxf (list (cons 62 color)))))
      (if (and tc (numberp tc) (> tc 0))
        (setq dxf (append dxf (list (cons 420 tc)))))

      (setq dxf (append dxf
                  (list '(100 . "AcDbText")
                        (cons 10 pt)
                        (cons 40 height)
                        (cons 1 str)
                        (cons 50 (if rot rot 0.0))
                        (cons 7 style))))
      (if (or (and justH (/= justH 0)) (and justV (/= justV 0)))
        (setq dxf (append dxf (list (cons 72 (if justH justH 0))
                                    (cons 11 pt)
                                    (cons 73 (if justV justV 0))))))

      (if (entmake dxf)
        T
        ;; Du phong: TEXT toi gian (mot so CAD tu choi nhom can le 72/73/11)
        (entmake (list '(0 . "TEXT")
                       (cons 8 layer)
                       (cons 10 pt)
                       (cons 40 height)
                       (cons 1 str)
                       (cons 50 (if rot rot 0.0))
                       (cons 7 style))))
    )
  )
)

;;; --------------------------------------------------------------------------
;;; 3b. SAP XEP DOI TUONG THEO VI TRI (tren -> duoi, trai -> phai)
;;; --------------------------------------------------------------------------
(defun tgirr:before-p (a b hDef / pa pb)
  (setq pa (cdr (assoc 'pt a))
        pb (cdr (assoc 'pt b)))
  (if (> (abs (- (cadr pa) (cadr pb))) (* 0.5 hDef))
    (> (cadr pa) (cadr pb))
    (< (car pa) (car pb))))

;; Chen 1 phan tu vao danh sach da sap xep. Khong dung vl-sort vi vl-sort
;; loai bo cac phan tu trung nhau (chuong trinh se mat doi tuong).
(defun tgirr:insert-item (lst item hDef / out done x)
  (setq out '() done nil)
  (foreach x lst
    (if (and (not done) (tgirr:before-p item x hDef))
      (setq out  (cons x (cons item out))
            done T)
      (setq out (cons x out))))
  (if (not done)
    (setq out (cons item out)))
  (reverse out))

(defun tgirr:sort-items (lst hDef / res)
  (setq res '())
  (foreach item lst
    (setq res (tgirr:insert-item res item hDef)))
  res)

;;; --------------------------------------------------------------------------
;;; 4. XU LY CHUYEN DOI (dung chung cho DOITEXT / M2T)
;;; --------------------------------------------------------------------------
(defun tgirr:doitext-run (itemList / mode delOpt hDef sortedList ptDef ptStart
                          ptPick spDef spInput spacing curX curY curZ
                          countLines countEnt failLines item insPt rot h sp
                          ang k ptLine jh jv layer style color tc ltype lw
                          attach lines)

  ;; 1. Hoi che do chuyen doi: Gom danh sach (List) hay Tai cho (In-place)
  (initget "List In-place L I")
  (setq mode (getkword "\nChọn chế độ chuyển đổi [Gom danh sách (List) / Tại chỗ (In-place)] <List>: "))
  (if (or (null mode) (= mode "L") (= mode "List"))
    (setq mode "List")
    (setq mode "In-place"))

  ;; 2. Hoi tuy chon xoa MText goc
  (initget "Co Khong Yes No C K Y N")
  (setq delOpt (getkword "\nXóa đối tượng gốc sau khi chuyển đổi? [Có / Không] <Có>: "))
  (if (or (null delOpt) (= (strcase delOpt) "CO") (= (strcase delOpt) "C") (= (strcase delOpt) "YES") (= (strcase delOpt) "Y"))
    (setq delOpt "Co")
    (setq delOpt "Khong"))

  (if (= mode "List")
    ;; =====================================================================
    ;; CHE DO 1: GOM DANH SACH (LIST)
    ;; =====================================================================
    (progn
      ;; Chieu cao chuan de lam dung sai so sanh toa do Y
      (setq hDef (cdr (assoc 'height (car itemList))))
      (if (or (null hDef) (<= hDef 0.0)) (setq hDef (getvar "TEXTSIZE")))

      ;; Sap xep tu tren xuong duoi (Y giam dan), cung hang thi tu trai sang phai
      (setq sortedList (tgirr:sort-items itemList hDef))

      ;; Diem chen mac dinh: diem chen cua doi tuong tren cung ben trai
      (setq ptDef (cdr (assoc 'pt (car sortedList))))
      (setq ptPick (getpoint ptDef "\nChọn điểm chèn danh sách TEXT <Điểm gốc trên cùng>: "))
      (setq ptStart (if ptPick ptPick ptDef))

      ;; Khoang cach dong mac dinh = 1.5 * chieu cao chu
      (setq spDef (* 1.5 hDef))
      (setq spInput (getdist ptStart (strcat "\nNhập khoảng cách dòng <" (rtos spDef 2 2) ">: ")))
      (setq spacing (if (and spInput (> spInput 0.0)) spInput spDef))

      ;; Tat bat diem de tranh nhay toa do
      (setvar "OSMODE" 0)

      (setq curX (car ptStart)
            curY (cadr ptStart)
            curZ (if (caddr ptStart) (caddr ptStart) 0.0)
            countLines 0
            failLines  0)

      ;; Tao tung dong TEXT
      (foreach item sortedList
        (setq h     (cdr (assoc 'height item))
              layer (cdr (assoc 'layer item))
              style (cdr (assoc 'style item))
              color (cdr (assoc 'color item))
              tc    (cdr (assoc 'truecolor item))
              ltype (cdr (assoc 'ltype item))
              lw    (cdr (assoc 'lineweight item))
              lines (cdr (assoc 'lines item)))
        (foreach line lines
          (if (tgirr:make-text line (list curX curY curZ) h 0.0
                               layer style color tc ltype lw 0 0)
            (setq countLines (1+ countLines))
            (setq failLines (1+ failLines)))
          (setq curY (- curY spacing))
        )
      )

      ;; Xoa doi tuong goc neu nguoi dung dong y
      (if (= delOpt "Co")
        (foreach item sortedList
          (entdel (cdr (assoc 'ent item)))))

      (prompt
        (strcat "\n[DOITEXT] Hoàn tất! Đã gom "
                (itoa (length sortedList)) " đối tượng thành "
                (itoa countLines) " dòng TEXT danh sách."))
      (if (> failLines 0)
        (prompt (strcat "\n[DOITEXT] Cảnh báo: " (itoa failLines)
                        " dòng không tạo được TEXT (kiểm tra layer/text style).")))
    )

    ;; =======================================================================
    ;; CHE DO 2: CHUYEN DOI TAI CHO (IN-PLACE)
    ;; =======================================================================
    (progn
      (setvar "OSMODE" 0)
      (setq countLines 0
            countEnt   0
            failLines  0)

      (foreach item itemList
        (if (= (cdr (assoc 'type item)) "MTEXT")
          (progn
            (setq insPt  (cdr (assoc 'pt item))
                  h      (cdr (assoc 'height item))
                  rot    (cdr (assoc 'rot item))
                  layer  (cdr (assoc 'layer item))
                  style  (cdr (assoc 'style item))
                  color  (cdr (assoc 'color item))
                  tc     (cdr (assoc 'truecolor item))
                  ltype  (cdr (assoc 'ltype item))
                  lw     (cdr (assoc 'lineweight item))
                  attach (cdr (assoc 'attach item))
                  lines  (cdr (assoc 'lines item)))
            (if (or (null h) (<= h 0.0)) (setq h (getvar "TEXTSIZE")))
            (if (or (null h) (<= h 0.0)) (setq h 2.5))
            (if (or (null rot) (not (numberp rot))) (setq rot 0.0))

            ;; Giu can le tuong ung voi diem bam dinh (ma 71) cua MText
            (setq jh (cond ((member attach '(1 4 7)) 0)
                           ((member attach '(2 5 8)) 1)
                           (t 2))
                  jv (cond ((member attach '(1 2 3)) 3)
                           ((member attach '(4 5 6)) 2)
                           (t 1)))

            (setq sp  (* 1.5 h)
                  ang (- rot (/ pi 2.0)) ; Huong di xuong vuong goc voi goc xoay
                  k   0)
            (foreach line lines
              (setq ptLine (polar insPt ang (* k sp)))
              (if (tgirr:make-text line ptLine h rot layer style color tc ltype lw jh jv)
                (setq countLines (1+ countLines))
                (setq failLines (1+ failLines)))
              (setq k (1+ k))
            )

            (if (= delOpt "Co")
              (entdel (cdr (assoc 'ent item))))
            (setq countEnt (1+ countEnt))
          )
        )
      )

      (prompt
        (strcat "\n[DOITEXT] Hoàn tất! Đã chuyển đổi "
                (itoa countEnt) " MText tại chỗ thành "
                (itoa countLines) " đối tượng TEXT."))
      (if (= countEnt 0)
        (prompt "\n[DOITEXT] Không có MText nào để chuyển (chế độ Tại chỗ chỉ xử lý MTEXT)."))
      (if (> failLines 0)
        (prompt (strcat "\n[DOITEXT] Cảnh báo: " (itoa failLines)
                        " dòng không tạo được TEXT.")))
    )
  )
  (princ)
)

;;; --------------------------------------------------------------------------
;;; 5. LENH CHINH: DOITEXT (ALIAS: M2T, MTEXT2TEXT)
;;; --------------------------------------------------------------------------
(defun c:DOITEXT (/ *error* oldCmd oldOsm oldDim doc ss count i ent data itemList)

  ;; Ham xu ly khi gap loi hoac nguoi dung bam ESC
  (defun *error* (msg)
    (if doc
      (vl-catch-all-apply 'vla-EndUndoMark (list doc)))
    (if oldCmd (setvar "CMDECHO" oldCmd))
    (if oldOsm (setvar "OSMODE" oldOsm))
    (if oldDim (setvar "DIMZIN" oldDim))
    (if (and msg (not (wcmatch (strcase msg t) "*cancel*,*exit*,*huy*")))
      (prompt (strcat "\n[DOITEXT] Thông báo: " msg)))
    (princ)
  )

  (setq oldCmd (getvar "CMDECHO")
        oldOsm (getvar "OSMODE")
        oldDim (getvar "DIMZIN"))
  (setvar "CMDECHO" 0)

  ;; Mo Undo mark (an toan: mot so moi truong khong co ActiveDocument, vd accoreconsole)
  (setq doc (vl-catch-all-apply
              '(lambda () (vla-get-ActiveDocument (vlax-get-acad-object)))))
  (if (or (null doc) (vl-catch-all-error-p doc)) (setq doc nil))
  (if doc (vl-catch-all-apply 'vla-StartUndoMark (list doc)))

  (prompt "\n===========================================================")
  (prompt "\n[TGIRR] DOITEXT - CHUYỂN ĐỔI MTEXT SANG TEXT & GOM DANH SÁCH")
  (prompt "\n===========================================================")

  ;; Chon doi tuong MText / Text
  (setq ss (ssget "_:L" '((0 . "MTEXT,TEXT"))))

  (cond
    ((not ss)
      (prompt "\n[DOITEXT] Không có đối tượng MTEXT hoặc TEXT nào được chọn.")
      (prompt "\n[DOITEXT] Hãy chọn chữ trước rồi chạy lại lệnh, hoặc chạy lệnh rồi quét chọn."))

    (t
      ;; Trich xuat du lieu cac doi tuong duoc chon
      (setq count (sslength ss)
            itemList '()
            i 0)
      (while (< i count)
        (setq ent  (ssname ss i)
              data (tgirr:get-entity-data ent))
        (if data
          (setq itemList (cons data itemList)))
        (setq i (1+ i))
      )

      (cond
        ((null itemList)
          (prompt "\n[DOITEXT] Không tìm thấy nội dung chữ hợp lệ trong tập chọn."))
        (t
          (tgirr:doitext-run itemList)
        )
      )
    )
  )

  ;; Dong Undo mark va khoi phuc bien he thong
  (if doc (vl-catch-all-apply 'vla-EndUndoMark (list doc)))
  (setvar "CMDECHO" oldCmd)
  (setvar "OSMODE" oldOsm)
  (setvar "DIMZIN" oldDim)
  (princ)
)

;;; --------------------------------------------------------------------------
;;; 6. LENH DOIMTEXT / T2M: GOP NHIEU TEXT THANH 1 MTEXT (NHIEU DOAN)
;;; --------------------------------------------------------------------------

;; Escape ky tu dieu khien cua MText de noi dung TEXT hien thi nguyen van
(defun tgirr:escape-mtext (str / i n ch out)
  (setq n (strlen str)
        i 1
        out "")
  (while (<= i n)
    (setq ch (substr str i 1))
    (setq out (strcat out (cond ((= ch "\\") "\\\\")
                                ((= ch "{") "\\{")
                                ((= ch "}") "\\}")
                                (t ch))))
    (setq i (1+ i)))
  out)

;; Tao doi tuong MTEXT nhieu doan; doan ngan cach bang \P trong 'content'
(defun tgirr:make-mtext (content pt height rot layer style color tc ltype lw attach
                         / dxf len idx)
  (if (and content (> (strlen content) 0))
    (progn
      (if (not (and layer (/= layer "") (tblsearch "LAYER" layer)))
        (setq layer (getvar "CLAYER")))
      (if (not (and style (/= style "") (tblsearch "STYLE" style)))
        (setq style (getvar "TEXTSTYLE")))
      (if (or (null height) (<= height 0.0)) (setq height (getvar "TEXTSIZE")))
      (if (or (null height) (<= height 0.0)) (setq height 2.5))
      (setq pt (list (car pt) (cadr pt) (if (caddr pt) (caddr pt) 0.0)))

      (setq dxf (list '(0 . "MTEXT")
                      '(100 . "AcDbEntity")
                      (cons 8 layer)))
      (if (and ltype (/= ltype "") (tblsearch "LTYPE" ltype))
        (setq dxf (append dxf (list (cons 6 ltype)))))
      (if (and lw (numberp lw) (> lw 0))
        (setq dxf (append dxf (list (cons 370 lw)))))
      (if (and color (numberp color) (> color 0) (< color 256))
        (setq dxf (append dxf (list (cons 62 color)))))
      (if (and tc (numberp tc) (> tc 0))
        (setq dxf (append dxf (list (cons 420 tc)))))

      (setq dxf (append dxf
                  (list '(100 . "AcDbMText")
                        (cons 10 pt)
                        (cons 40 height)
                        (cons 41 0.0)                                  ; khong gioi han be rong
                        (cons 71 (if (and attach (>= attach 1) (<= attach 9)) attach 1))
                        (cons 72 1))))

      ;; Noi dung: nhom 3 chua cac doan 250 ky tu, phan cuoi o nhom 1
      (setq len (strlen content)
            idx 1)
      (while (> (- len idx) 249)
        (setq dxf (append dxf (list (cons 3 (substr content idx 250))))
              idx (+ idx 250)))
      (setq dxf (append dxf (list (cons 1 (substr content idx)))))

      (entmake (append dxf (list (cons 7 style)
                                 (cons 50 (if rot rot 0.0))
                                 (cons 73 1)                           ; gian dong: at least
                                 (cons 44 1.0))))
    )
  )
)

(defun c:DOIMTEXT (/ *error* oldCmd oldOsm oldDim doc ss count i ent data items
                     hDef sortedList ptDef ptPick ptStart delOpt content
                     item lines h rot res)

  ;; Ham xu ly khi gap loi hoac nguoi dung bam ESC
  (defun *error* (msg)
    (if doc (vl-catch-all-apply 'vla-EndUndoMark (list doc)))
    (if oldCmd (setvar "CMDECHO" oldCmd))
    (if oldOsm (setvar "OSMODE" oldOsm))
    (if oldDim (setvar "DIMZIN" oldDim))
    (if (and msg (not (wcmatch (strcase msg t) "*cancel*,*exit*,*huy*")))
      (prompt (strcat "\n[DOIMTEXT] Thông báo: " msg)))
    (princ)
  )

  (setq oldCmd (getvar "CMDECHO")
        oldOsm (getvar "OSMODE")
        oldDim (getvar "DIMZIN"))
  (setvar "CMDECHO" 0)

  (setq doc (vl-catch-all-apply
              '(lambda () (vla-get-ActiveDocument (vlax-get-acad-object)))))
  (if (or (null doc) (vl-catch-all-error-p doc)) (setq doc nil))
  (if doc (vl-catch-all-apply 'vla-StartUndoMark (list doc)))

  (prompt "\n===========================================================")
  (prompt "\n[TGIRR] DOIMTEXT - GỘP NHIỀU TEXT THÀNH 1 MTEXT NHIỀU ĐOẠN")
  (prompt "\n===========================================================")

  (setq ss (ssget "_:L" '((0 . "TEXT"))))
  (cond
    ((not ss)
      (prompt "\n[DOIMTEXT] Không có đối tượng TEXT nào được chọn.")
      (prompt "\n[DOIMTEXT] Hãy chọn các dòng TEXT cần gộp rồi chạy lại lệnh."))

    (t
      (setq count (sslength ss)
            items '()
            i 0)
      (while (< i count)
        (setq ent  (ssname ss i)
              data (tgirr:get-entity-data ent))
        (if data (setq items (cons data items)))
        (setq i (1+ i)))

      (cond
        ((null items)
          (prompt "\n[DOIMTEXT] Không đọc được nội dung TEXT nào trong tập chọn."))
        (t
          (setq hDef (cdr (assoc 'height (car items))))
          (if (or (null hDef) (<= hDef 0.0)) (setq hDef (getvar "TEXTSIZE")))
          (setq sortedList (tgirr:sort-items items hDef))

          ;; Diem chen mac dinh: goc tren - trai cua TEXT dau tien
          (setq item (car sortedList)
                h    (cdr (assoc 'height item))
                rot  (cdr (assoc 'rot item)))
          (if (or (null h) (<= h 0.0)) (setq h hDef))
          (if (or (null rot) (not (numberp rot))) (setq rot 0.0))
          (setq ptDef (polar (cdr (assoc 'pt item)) (+ rot (/ pi 2.0)) h))

          (setq ptPick (getpoint ptDef "\nChọn điểm chèn MTEXT <Điểm gốc trên cùng>: "))
          (setq ptStart (if ptPick ptPick ptDef))

          (initget "Co Khong Yes No C K Y N")
          (setq delOpt (getkword "\nXóa các TEXT gốc sau khi gộp? [Có / Không] <Có>: "))
          (if (or (null delOpt) (= (strcase delOpt) "CO") (= (strcase delOpt) "C")
                  (= (strcase delOpt) "YES") (= (strcase delOpt) "Y"))
            (setq delOpt "Co")
            (setq delOpt "Khong"))

          ;; Noi noi dung: moi TEXT la 1 doan, ngan cach bang \P
          (setq content "")
          (foreach item sortedList
            (foreach line (cdr (assoc 'lines item))
              (setq content (strcat content
                                    (if (= content "") "" "\\P")
                                    (tgirr:escape-mtext line)))))

          (setq item (car sortedList)
                res  (tgirr:make-mtext content ptStart h rot
                         (cdr (assoc 'layer item))
                         (cdr (assoc 'style item))
                         (cdr (assoc 'color item))
                         (cdr (assoc 'truecolor item))
                         (cdr (assoc 'ltype item))
                         (cdr (assoc 'lineweight item))
                         1))
          (cond
            (res
              (if (= delOpt "Co")
                (foreach item sortedList
                  (entdel (cdr (assoc 'ent item)))))
              (prompt (strcat "\n[DOIMTEXT] Hoàn tất! Đã gộp " (itoa (length sortedList))
                              " TEXT thành 1 MTEXT " (itoa (length sortedList))
                              " đoạn. Sửa MTEXT để Enter xuống dòng thêm.")))
            (t
              (prompt "\n[DOIMTEXT] Không tạo được MTEXT (kiểm tra layer/text style của bản vẽ).")))
        )
      )
    )
  )

  ;; Dong Undo mark va khoi phuc bien he thong
  (if doc (vl-catch-all-apply 'vla-EndUndoMark (list doc)))
  (setvar "CMDECHO" oldCmd)
  (setvar "OSMODE" oldOsm)
  (setvar "DIMZIN" oldDim)
  (princ)
)

;;; Alias ngan gon cho lenh DOITEXT
(defun c:M2T () (c:DOITEXT))
(defun c:MTEXT2TEXT () (c:DOITEXT))
(defun c:T2M () (c:DOIMTEXT))
(defun c:TEXT2MTEXT () (c:DOIMTEXT))

(prompt "\nTGIRR CAD LISP: Đã nạp lệnh DOITEXT (M2T, MTEXT2TEXT) và DOIMTEXT gộp TEXT thành MTEXT (T2M, TEXT2MTEXT).")
(princ)
