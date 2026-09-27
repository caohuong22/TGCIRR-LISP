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
              ;; Ngắt dòng MText: \P hoặc \p
              ((or (= chNext "P") (= chNext "p"))
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

              ;; Các mã định dạng font, màu, cỡ kết thúc bởi ';': \f, \F, \C, \c, \H, \h, \W, \w, \Q, \q, \A, \a, \T, \t
              ((vl-position (strcase chNext) '("F" "C" "H" "W" "Q" "A" "T"))
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
(defun tgirr:get-entity-data (ent / ed typ rawStr lines insPt height rot layer style color)
  (setq ed  (entget ent)
        typ (cdr (assoc 0 ed)))
  (cond
    ((= typ "MTEXT")
      ;; Ghep toan bo nhom DXF 3 va nhom 1 thanh chuoi MText day du
      (setq rawStr "")
      (foreach item ed
        (if (or (= (car item) 3) (= (car item) 1))
          (setq rawStr (strcat rawStr (cdr item)))))
      (setq lines  (tgirr:parse-mtext-to-lines rawStr)
            insPt  (cdr (assoc 10 ed))
            height (cond ((cdr (assoc 40 ed))) ((getvar "TEXTSIZE")))
            rot    (cond ((cdr (assoc 50 ed))) (0.0))
            layer  (cdr (assoc 8 ed))
            style  (cdr (assoc 7 ed))
            color  (cdr (assoc 62 ed)))
      (if lines
        (list ent typ insPt height rot layer style color lines)
        nil))

    ((= typ "TEXT")
      (setq rawStr (cdr (assoc 1 ed))
            insPt  (cdr (assoc 10 ed))
            height (cond ((cdr (assoc 40 ed))) ((getvar "TEXTSIZE")))
            rot    (cond ((cdr (assoc 50 ed))) (0.0))
            layer  (cdr (assoc 8 ed))
            style  (cdr (assoc 7 ed))
            color  (cdr (assoc 62 ed)))
      (if (and rawStr (> (strlen (vl-string-trim " \t\r\n" rawStr)) 0))
        (list ent typ insPt height rot layer style color (list (vl-string-trim " \t\r\n" rawStr)))
        nil))

    (t nil)
  )
)

;;; --------------------------------------------------------------------------
;;; 3. HAM TAO DOI TUONG TEXT BANG ENTMAKE
;;; --------------------------------------------------------------------------
(defun tgirr:make-text (str pt height rot layer style color / dxf)
  (if (and str (> (strlen str) 0))
    (progn
      (setq dxf
        (list
          '(0 . "TEXT")
          '(100 . "AcDbEntity")
          (cons 8 (if (and layer (/= layer "")) layer (getvar "CLAYER")))
          '(100 . "AcDbText")
          (cons 10 pt)
          (cons 40 (if (and height (> height 0.0)) height (getvar "TEXTSIZE")))
          (cons 1 str)
          (cons 50 (if rot rot 0.0))
          (cons 7 (if (and style (/= style "")) style (getvar "TEXTSTYLE")))
        )
      )
      ;; Them ma mau neu co override (1-255)
      (if (and color (numberp color) (> color 0) (< color 256))
        (setq dxf (append dxf (list (cons 62 color)))))
      (entmake dxf)
    )
  )
)

;;; --------------------------------------------------------------------------
;;; 4. LENH CHINH: DOITEXT (ALIAS: M2T, MTEXT2TEXT)
;;; --------------------------------------------------------------------------
(defun c:DOITEXT (/ *error* oldCmd oldOsm oldDim doc ss count i ent data
                    itemList sortedList mode ptDef ptStart ptPick hDef spDef
                    spInput spacing curX curY curZ countLines delOpt
                    insPt rot h sp ang)

  ;; Ham xu ly khi gap loi hoac nguoi dung bam ESC
  (defun *error* (msg)
    (if (and doc (vlax-read-enabled-p doc))
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

  ;; Mo Undo mark
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (vla-StartUndoMark doc)

  (prompt "\n===========================================================")
  (prompt "\n[TGIRR] DOITEXT - CHUYỂN ĐỔI MTEXT SANG TEXT & GOM DANH SÁCH")
  (prompt "\n===========================================================")

  ;; Chon doi tuong MText / Text
  (setq ss (ssget "_:L" '((0 . "MTEXT,TEXT"))))
  (if (not ss)
    (progn
      (prompt "\n[DOITEXT] Không có đối tượng MTEXT hoặc TEXT nào được chọn.")
      (vla-EndUndoMark doc)
      (setvar "CMDECHO" oldCmd)
      (setvar "OSMODE" oldOsm)
      (setvar "DIMZIN" oldDim)
      (princ)
      (exit)
    )
  )

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

  (if (null itemList)
    (progn
      (prompt "\n[DOITEXT] Không tìm thấy nội dung chữ hợp lệ trong tập chọn.")
      (vla-EndUndoMark doc)
      (setvar "CMDECHO" oldCmd)
      (setvar "OSMODE" oldOsm)
      (setvar "DIMZIN" oldDim)
      (princ)
      (exit)
    )
  )

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

  ;; =========================================================================
  ;; CHE DO 1: GOM DANH SACH (LIST)
  ;; =========================================================================
  (if (= mode "List")
    (progn
      ;; Chieu cao chuan de lam dung sai so sanh toa do Y
      (setq hDef (nth 3 (car itemList)))
      (if (or (null hDef) (<= hDef 0.0)) (setq hDef (getvar "TEXTSIZE")))

      ;; Sap xep danh sach doi tuong theo thu tu tu tren xuong duoi (Y giam dan),
      ;; neu Y ngang nhau (trong pham vi 0.5 * hDef) thi tu trai sang phai (X tang dan).
      (setq sortedList
        (vl-sort itemList
          '(lambda (a b / ptA ptB yA yB xA xB tol)
             (setq tol (* 0.5 hDef)
                   ptA (nth 2 a)
                   ptB (nth 2 b)
                   xA  (car ptA)
                   yA  (cadr ptA)
                   xB  (car ptB)
                   yB  (cadr ptB))
             (if (> (abs (- yA yB)) tol)
               (> yA yB) ; Y o tren xep truoc
               (< xA xB) ; X ben trai xep truoc
             )
           )
        )
      )

      ;; Diem chen mac dinh: diem chen cua doi tuong tren cung ben trai
      (setq ptDef (nth 2 (car sortedList)))
      (setq ptPick (getpoint ptDef "\nChọn điểm chèn danh sách TEXT <Điểm gốc trên cùng>: "))
      (if ptPick
        (setq ptStart ptPick)
        (setq ptStart ptDef))

      ;; Khoang cach dong mac dinh = 1.5 * chieu cao chu
      (setq spDef (* 1.5 hDef))
      (setq spInput (getdist ptStart (strcat "\nNhập khoảng cách dòng <" (rtos spDef 2 2) ">: ")))
      (if (and spInput (> spInput 0.0))
        (setq spacing spInput)
        (setq spacing spDef))

      ;; Tat bat diem de tranh nhay toa do
      (setvar "OSMODE" 0)

      (setq curX (car ptStart)
            curY (cadr ptStart)
            curZ (caddr ptStart)
            countLines 0)

      ;; Tao tung dong TEXT
      (foreach item sortedList
        (setq h     (nth 3 item)
              layer (nth 5 item)
              style (nth 6 item)
              color (nth 7 item)
              lines (nth 8 item))
        (foreach line lines
          (tgirr:make-text line (list curX curY curZ) h 0.0 layer style color)
          (setq curY (- curY spacing))
          (setq countLines (1+ countLines))
        )
      )

      ;; Xoa doi tuong goc neu nguoi dung dong y
      (if (= delOpt "Co")
        (foreach item sortedList
          (entdel (nth 0 item))))

      (prompt
        (strcat "\n[DOITEXT] Hoàn tất! Đã gom "
                (itoa (length sortedList)) " đối tượng thành "
                (itoa countLines) " dòng TEXT danh sách thành công."))
    )

    ;; =======================================================================
    ;; CHE DO 2: CHUYEN DOI TAI CHO (IN-PLACE)
    ;; =======================================================================
    (progn
      (setvar "OSMODE" 0)
      (setq countLines 0
            countEnt   0)

      (foreach item itemList
        (if (= (nth 1 item) "MTEXT")
          (progn
            (setq insPt (nth 2 item)
                  h     (nth 3 item)
                  rot   (nth 4 item)
                  layer (nth 5 item)
                  style (nth 6 item)
                  color (nth 7 item)
                  lines (nth 8 item))

            (setq sp  (* 1.5 h)
                  ang (- rot (/ pi 2.0))) ; Huong di xuong vuong goc voi goc xoay

            (setq k 0)
            (foreach line lines
              (setq ptLine (polar insPt ang (* k sp)))
              (tgirr:make-text line ptLine h rot layer style color)
              (setq k (1+ k))
              (setq countLines (1+ countLines))
            )

            (if (= delOpt "Co")
              (entdel (nth 0 item)))
            (setq countEnt (1+ countEnt))
          )
        )
      )

      (prompt
        (strcat "\n[DOITEXT] Hoàn tất! Đã chuyển đổi "
                (itoa countEnt) " MText tại chỗ thành "
                (itoa countLines) " đối tượng TEXT."))
    )
  )

  ;; Dong Undo mark va khoi phuc bien he thong
  (vla-EndUndoMark doc)
  (setvar "CMDECHO" oldCmd)
  (setvar "OSMODE" oldOsm)
  (setvar "DIMZIN" oldDim)
  (princ)
)

;;; Alias ngan gon cho lenh DOITEXT
(defun c:M2T () (c:DOITEXT))
(defun c:MTEXT2TEXT () (c:DOITEXT))

(prompt "\nTGIRR CAD LISP: Đã nạp lệnh DOITEXT (lệnh tắt: M2T, MTEXT2TEXT).")
(princ)
