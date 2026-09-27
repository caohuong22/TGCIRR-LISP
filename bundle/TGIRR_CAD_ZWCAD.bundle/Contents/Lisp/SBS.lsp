;;; =============================================================
;;; TGIRR CAD LISP - BO CONG CU LOC VA CHON DOI TUONG THEO MAU
;;; 1. SBS : Chon doi tuong cung loai/mau trong Polyline bound (hoac toan ban ve neu khong chon bound)
;;; 2. SBSE: Chon doi tuong trung khop chinh xac theo mau (Text, Block, Hatch, Dim...)
;;; 3. SCH / SH: Chon nhanh tat ca Hatch cung Mau sac va Pattern theo mau (khong can bound)
;;; =============================================================
(vl-load-com)

;; Ham lay thong tin mau thuc te (ho tro ACI, TrueColor 420, ByLayer)
(defun tgirr:get-color (ent / ed col62 col420 lay layEnt layCol layCol420)
  (setq ed (entget ent))
  (setq col62  (cdr (assoc 62 ed)))
  (setq col420 (cdr (assoc 420 ed)))
  (setq lay    (cdr (assoc 8 ed)))
  (cond
    ;; Neu doi tuong co TrueColor truc tiep (DXF 420)
    (col420 (list 420 col420 (if col62 col62 256)))
    ;; Neu doi tuong co mau ACI truc tiep (DXF 62 khac 256 va khac 0)
    ((and col62 (/= col62 256) (/= col62 0)) (list 62 col62))
    ;; Neu la ByLayer: tra cuu tu Layer Table
    (T
     (if (and lay (setq layEnt (tblsearch "LAYER" lay)))
       (progn
         (setq layCol420 (cdr (assoc 420 layEnt)))
         (setq layCol    (cdr (assoc 62 layEnt)))
         (setq layCol    (abs (if layCol layCol 7)))
         (if layCol420
           (list 420 layCol420 layCol)
           (list 62 layCol)))
       (list 62 7)))))

;; So sanh 2 mau sac co tuong dong khong (ho tro TrueColor vs TrueColor, ACI vs ACI, TrueColor vs ACI)
(defun tgirr:colors-match-p (c1 c2 / t1 v1 t2 v2 aci1 aci2 r1 g1 b1 r2 g2 b2)
  (if (and c1 c2)
    (progn
      (setq t1 (car c1) v1 (cadr c1)
            t2 (car c2) v2 (cadr c2))
      (cond
        ;; TH1: Cung la TrueColor 420
        ((and (= t1 420) (= t2 420))
         (setq r1 (lsh (logand v1 16711680) -16)
               g1 (lsh (logand v1 65280) -8)
               b1 (logand v1 255)
               r2 (lsh (logand v2 16711680) -16)
               g2 (lsh (logand v2 65280) -8)
               b2 (logand v2 255))
         ;; Cho phep dung sai mau RGB nho (khoang cach <= 15)
         (and (<= (abs (- r1 r2)) 15)
              (<= (abs (- g1 g2)) 15)
              (<= (abs (- b1 b2)) 15)))

        ;; TH2: Cung la ACI 62
        ((and (= t1 62) (= t2 62))
         (= v1 v2))

        ;; TH3: 1 ben TrueColor 420, 1 ben ACI 62: so sanh ACI tuong duong (caddr)
        ((and (= t1 420) (= t2 62))
         (setq aci1 (caddr c1))
         (and aci1 (= aci1 v2)))

        ((and (= t1 62) (= t2 420))
         (setq aci2 (caddr c2))
         (and aci2 (= v1 aci2)))

        (T nil)))
    nil))

;; Dinh dang chuoi mo ta mau sac
(defun tgirr:format-color-str (colInfo / typ val)
  (setq typ (car colInfo) val (cadr colInfo))
  (cond
    ((= typ 420)
     (strcat "RGB (" (itoa (lsh (logand val 16711680) -16)) ","
                     (itoa (lsh (logand val 65280) -8)) ","
                     (itoa (logand val 255)) ")"))
    ((= typ 62)
     (strcat "Color " (itoa val)))
    (T "ByLayer")))

;; So sanh 2 ten Hatch Pattern (chuan hoa khong phan biet hoa thuong, bo dau * va _ o dau)
(defun tgirr:match-hatch-pattern (p1 p2 / s1 s2)
  (setq s1 (if (and p1 (/= p1 "")) (vl-string-trim " *_" (strcase p1)) "SOLID")
        s2 (if (and p2 (/= p2 "")) (vl-string-trim " *_" (strcase p2)) "SOLID"))
  (or (= s1 s2)
      (wcmatch s1 (strcat "*" s2 "*"))
      (wcmatch s2 (strcat "*" s1 "*"))))

;;; -------------------------------------------------------------
;;; LENH SBS: SELECT BY SAMPLE
;;; -------------------------------------------------------------
(defun c:SBS (/ entBound entMau edMau typ pts ssAll ssNew i e ed eType
                mauType mauLayer mauColorInfo mauLtype mauName
                get-poly-points point-in-poly text-in-poly-p mostly-inside-p)

  (vl-load-com)

  ;; Ham lay dinh cua polyline
  (defun get-poly-points (ent / ed pts en)
    (setq ed (entget ent))
    (cond
      ((= (cdr (assoc 0 ed)) "LWPOLYLINE")
        (setq pts '())
        (foreach x ed
          (if (= (car x) 10)
            (setq pts (append pts (list (cdr x))))))
        pts)

      ((= (cdr (assoc 0 ed)) "POLYLINE")
        (setq pts '())
        (setq en (entnext ent))
        (while (/= (cdr (assoc 0 (entget en))) "SEQEND")
          (if (= (cdr (assoc 0 (entget en))) "VERTEX")
            (setq pts (append pts (list (cdr (assoc 10 (entget en)))))))
          (setq en (entnext en)))
        pts)

      (T nil)))

  ;; Kiem tra mot diem co nam trong polygon hay khong (ray casting)
  (defun point-in-poly (pt poly / x y inside j i pi pj xi yi xj yj)
    (setq x (car pt) y (cadr pt) inside nil
          j (1- (length poly)) i 0)
    (while (< i (length poly))
      (setq pi (nth i poly) pj (nth j poly)
            xi (car pi) yi (cadr pi)
            xj (car pj) yj (cadr pj))
      (if (and (/= (> yi y) (> yj y))
               (< x (+ xi (/ (* (- xj xi) (- y yi)) (- yj yi)))))
        (setq inside (not inside)))
      (setq j i i (1+ i)))
    inside)

  ;; Kiem tra rieng cho TEXT va MTEXT: dung diem chen va tam chu thuc te, tranh o trong rong (Width) cua MTEXT
  (defun text-in-poly-p (ent poly / ed typ obj ins pmin pmax mn mx cx cy actW actH att dx dy)
    (setq ed  (entget ent)
          typ (cdr (assoc 0 ed))
          obj (vlax-ename->vla-object ent))
    (cond
      ((= typ "TEXT")
       (setq ins (if (and (= (cdr (assoc 72 ed)) 0) (= (cdr (assoc 73 ed)) 0))
                   (cdr (assoc 10 ed))
                   (cdr (assoc 11 ed))))
       (if (not (vl-catch-all-error-p (vl-catch-all-apply 'vla-GetBoundingBox (list obj 'pmin 'pmax))))
         (progn
           (setq mn (vlax-safearray->list pmin)
                 mx (vlax-safearray->list pmax)
                 cx (/ (+ (car mn) (car mx)) 2.0)
                 cy (/ (+ (cadr mn) (cadr mx)) 2.0))
           (or (point-in-poly (list (car ins) (cadr ins)) poly)
               (point-in-poly (list cx cy) poly)))
         (point-in-poly (list (car ins) (cadr ins)) poly)))

      ((= typ "MTEXT")
       (setq ins (cdr (assoc 10 ed)))
       (setq actW (if (vlax-property-available-p obj 'ActualWidth) (vla-get-ActualWidth obj) 0.0)
             actH (if (vlax-property-available-p obj 'ActualHeight) (vla-get-ActualHeight obj) 0.0)
             att  (cdr (assoc 71 ed)))
       (if (null att) (setq att 1))
       (setq dx (cond ((vl-position att '(1 4 7)) (/ actW 2.0))
                      ((vl-position att '(3 6 9)) (- (/ actW 2.0)))
                      (t 0.0))
             dy (cond ((vl-position att '(1 2 3)) (- (/ actH 2.0)))
                      ((vl-position att '(7 8 9)) (/ actH 2.0))
                      (t 0.0))
             cx (+ (car ins) dx)
             cy (+ (cadr ins) dy))
       (or (point-in-poly (list (car ins) (cadr ins)) poly)
           (point-in-poly (list cx cy) poly)))

      (T nil)))

  ;; Lay 9 diem mau tren bounding box; chap nhan neu >= 5 diem nam trong bound.
  (defun mostly-inside-p (ent poly / obj pmin pmax mn mx x1 x2 xm y1 y2 ym samples count result typ)
    (setq typ (cdr (assoc 0 (entget ent))))
    (if (vl-position typ '("TEXT" "MTEXT"))
      (text-in-poly-p ent poly)
      (progn
        (setq obj (vlax-ename->vla-object ent)
              result (vl-catch-all-apply 'vla-GetBoundingBox (list obj 'pmin 'pmax)))
        (if (vl-catch-all-error-p result)
          nil
          (progn
            (setq mn (vlax-safearray->list pmin)
                  mx (vlax-safearray->list pmax)
                  x1 (car mn) y1 (cadr mn)
                  x2 (car mx) y2 (cadr mx)
                  xm (/ (+ x1 x2) 2.0) ym (/ (+ y1 y2) 2.0)
                  samples (list
                    (list x1 y1) (list xm y1) (list x2 y1)
                    (list x1 ym) (list xm ym) (list x2 ym)
                    (list x1 y2) (list xm y2) (list x2 y2))
                  count 0)
            (foreach p samples
              (if (point-in-poly p poly) (setq count (1+ count))))
            (>= count 5))))))

  ;; 1. Chon boundary (hoac Enter de chon khong can bound)
  (prompt "\n[SBS] Chọn vùng bound bằng Polyline kín (Enter để lọc không cần bound): ")
  (setq entBound (car (entsel)))

  (setq pts nil)
  (if entBound
    (progn
      (setq pts (get-poly-points entBound))
      (if (not pts)
        (prompt "\n[SBS] Vùng chọn không phải là Polyline kín. Chuyển sang lọc không cần bound."))))

  ;; 2. Chon doi tuong mau
  (prompt "\n[SBS] Chọn 1 đối tượng mẫu để lọc cùng thuộc tính: ")
  (setq entMau (car (entsel)))

  (if (not entMau)
    (prompt "\n[SBS] Chưa chọn đối tượng mẫu.")
    (progn
      ;; Lay thuoc tinh doi tuong mau
      (setq edMau        (entget entMau))
      (setq mauType      (cdr (assoc 0 edMau)))
      (setq mauLayer     (cdr (assoc 8 edMau)))
      (setq mauLtype     (cdr (assoc 6 edMau)))
      (setq mauName      (cdr (assoc 2 edMau)))
      (setq mauColorInfo (tgirr:get-color entMau))

      ;; 3. Thu thap doi tuong ung vien
      (if pts
        (setq ssAll (ssget "_CP" pts))
        (progn
          (prompt "\n[SBS] Quét chọn vùng lọc theo mẫu (Enter để lọc toàn bộ bản vẽ): ")
          (setq ssAll (ssget))
          (if (not ssAll)
            (setq ssAll (ssget "_X" (list (cons 410 (getvar "CTAB"))))))))

      (if ssAll
        (progn
          (setq ssNew (ssadd))
          (setq i 0)

          (while (< i (sslength ssAll))
            (setq e  (ssname ssAll i))
            (setq ed (entget e))
            (setq eType (cdr (assoc 0 ed)))

            (if
              (and
                (/= e entBound)
                (= eType mauType)
                (= (cdr (assoc 8 ed)) mauLayer)

                ;; So sanh mau sac thuc te (ACI, TrueColor, ByLayer)
                (equal (tgirr:get-color e) mauColorInfo)

                ;; So sanh linetype
                (= (cdr (assoc 6 ed)) mauLtype)

                ;; Neu co bound thi kiem tra nam trong bound
                (if pts (mostly-inside-p e pts) T)

                ;; Neu la Block thi so sanh ten block
                (if (= mauType "INSERT")
                  (= (cdr (assoc 2 ed)) mauName)
                  T)

                ;; Neu la Hatch thi so sanh pattern
                (if (= mauType "HATCH")
                  (tgirr:match-hatch-pattern (cdr (assoc 2 ed)) mauName)
                  T))
              (ssadd e ssNew))

            (setq i (1+ i)))

          (if (> (sslength ssNew) 0)
            (progn
              (sssetfirst nil ssNew)
              (prompt
                (strcat
                  "\n[SBS] Đã chọn "
                  (itoa (sslength ssNew))
                  " đối tượng cùng thuộc tính"
                  (if pts " nằm trong bound." " trên bản vẽ."))))
            (prompt "\n[SBS] Không tìm thấy đối tượng nào cùng thuộc tính.")))
        (prompt "\n[SBS] Không có đối tượng nào được tìm thấy."))))

  (princ)
)

;;; -------------------------------------------------------------
;;; TGIRR CAD LISP - LENH SBSE (SELECT BY SAMPLE EXACT)
;;; Loc doi tuong giong mau chinh xac (TEXT/MTEXT trung noi dung, INSERT trung EffectiveName)
;;; Co the loc trong Polyline bound hoac Enter de loc khong can bound
;;; -------------------------------------------------------------

;; Ham lam sach noi dung MTEXT de so sanh
(defun tgirr:clean-text (str / pos end)
  (if (and str (= (type str) 'STR))
    (progn
      (while (setq pos (vl-string-search "\\P" str))
        (setq str (strcat (substr str 1 pos) " " (substr str (+ pos 3)))))
      (while (setq pos (vl-string-search "\\p" str))
        (setq str (strcat (substr str 1 pos) " " (substr str (+ pos 3)))))
      (while (setq pos (vl-string-search "\\" str))
        (setq end (vl-string-search ";" str pos))
        (if end
          (setq str (strcat (substr str 1 pos) (substr str (+ end 2))))
          (setq str (strcat (substr str 1 pos) (substr str (+ pos 2))))))
      (while (setq pos (vl-string-search "{" str))
        (setq str (strcat (substr str 1 pos) (substr str (+ pos 2)))))
      (while (setq pos (vl-string-search "}" str))
        (setq str (strcat (substr str 1 pos) (substr str (+ pos 2)))))
      (vl-string-trim " \t\r\n" str))
    ""))

;; Ham lay text string cua TEXT hoac MTEXT
(defun tgirr:get-text (ent / obj txt)
  (setq obj (vlax-ename->vla-object ent))
  (setq txt (vl-catch-all-apply 'vlax-get-property (list obj 'TextString)))
  (if (vl-catch-all-error-p txt)
    (cdr (assoc 1 (entget ent)))
    txt))

;; Ham lay ten block (ho tro Dynamic Block EffectiveName)
(defun tgirr:get-block-name (ent / obj name)
  (setq obj (vlax-ename->vla-object ent))
  (if (and (vlax-property-available-p obj 'EffectiveName)
           (setq name (vl-catch-all-apply 'vlax-get-property (list obj 'EffectiveName)))
           (not (vl-catch-all-error-p name)))
    name
    (cdr (assoc 2 (entget ent)))))

(defun c:SBSE (/ entBound entMau edMau mauType mauLayer mauColorInfo mauLtype mauName
                 mauText mauCleanText mauBlock pts ssAll ssNew i e ed eType matchExact
                 get-poly-pts pt-in-poly text-in-poly-p mostly-in-p eTxt)
  (vl-load-com)

  ;; Ham lay dinh polyline
  (defun get-poly-pts (ent / ed pts en)
    (setq ed (entget ent))
    (cond
      ((= (cdr (assoc 0 ed)) "LWPOLYLINE")
        (setq pts '())
        (foreach x ed
          (if (= (car x) 10) (setq pts (append pts (list (cdr x))))))
        pts)
      ((= (cdr (assoc 0 ed)) "POLYLINE")
        (setq pts '() en (entnext ent))
        (while (/= (cdr (assoc 0 (entget en))) "SEQEND")
          (if (= (cdr (assoc 0 (entget en))) "VERTEX")
            (setq pts (append pts (list (cdr (assoc 10 (entget en)))))))
          (setq en (entnext en)))
        pts)
      (T nil)))

  ;; Ray-casting kiem tra diem trong polygon
  (defun pt-in-poly (pt poly / x y inside j i pi pj xi yi xj yj)
    (setq x (car pt) y (cadr pt) inside nil j (1- (length poly)) i 0)
    (while (< i (length poly))
      (setq pi (nth i poly) pj (nth j poly)
            xi (car pi) yi (cadr pi)
            xj (car pj) yj (cadr pj))
      (if (and (/= (> yi y) (> yj y))
               (< x (+ xi (/ (* (- xj xi) (- y yi)) (- yj yi)))))
        (setq inside (not inside)))
      (setq j i i (1+ i)))
    inside)

  ;; Kiem tra rieng cho TEXT va MTEXT
  (defun text-in-poly-p (ent poly / ed typ obj ins pmin pmax mn mx cx cy actW actH att dx dy)
    (setq ed  (entget ent)
          typ (cdr (assoc 0 ed))
          obj (vlax-ename->vla-object ent))
    (cond
      ((= typ "TEXT")
       (setq ins (if (and (= (cdr (assoc 72 ed)) 0) (= (cdr (assoc 73 ed)) 0))
                   (cdr (assoc 10 ed))
                   (cdr (assoc 11 ed))))
       (if (not (vl-catch-all-error-p (vl-catch-all-apply 'vla-GetBoundingBox (list obj 'pmin 'pmax))))
         (progn
           (setq mn (vlax-safearray->list pmin)
                 mx (vlax-safearray->list pmax)
                 cx (/ (+ (car mn) (car mx)) 2.0)
                 cy (/ (+ (cadr mn) (cadr mx)) 2.0))
           (or (pt-in-poly (list (car ins) (cadr ins)) poly)
               (pt-in-poly (list cx cy) poly)))
         (pt-in-poly (list (car ins) (cadr ins)) poly)))

      ((= typ "MTEXT")
       (setq ins (cdr (assoc 10 ed)))
       (setq actW (if (vlax-property-available-p obj 'ActualWidth) (vla-get-ActualWidth obj) 0.0)
             actH (if (vlax-property-available-p obj 'ActualHeight) (vla-get-ActualHeight obj) 0.0)
             att  (cdr (assoc 71 ed)))
       (if (null att) (setq att 1))
       (setq dx (cond ((vl-position att '(1 4 7)) (/ actW 2.0))
                      ((vl-position att '(3 6 9)) (- (/ actW 2.0)))
                      (t 0.0))
             dy (cond ((vl-position att '(1 2 3)) (- (/ actH 2.0)))
                      ((vl-position att '(7 8 9)) (/ actH 2.0))
                      (t 0.0))
             cx (+ (car ins) dx)
             cy (+ (cadr ins) dy))
       (or (pt-in-poly (list (car ins) (cadr ins)) poly)
           (pt-in-poly (list cx cy) poly)))

      (T nil)))

  ;; Lay 9 diem tren bounding box; chap nhan neu >= 5 diem nam trong bound.
  (defun mostly-in-p (ent poly / obj pmin pmax mn mx x1 x2 xm y1 y2 ym samples count result typ)
    (setq typ (cdr (assoc 0 (entget ent))))
    (if (vl-position typ '("TEXT" "MTEXT"))
      (text-in-poly-p ent poly)
      (progn
        (setq obj (vlax-ename->vla-object ent)
              result (vl-catch-all-apply 'vla-GetBoundingBox (list obj 'pmin 'pmax)))
        (if (vl-catch-all-error-p result)
          nil
          (progn
            (setq mn (vlax-safearray->list pmin)
                  mx (vlax-safearray->list pmax)
                  x1 (car mn) y1 (cadr mn)
                  x2 (car mx) y2 (cadr mx)
                  xm (/ (+ x1 x2) 2.0) ym (/ (+ y1 y2) 2.0)
                  samples (list
                    (list x1 y1) (list xm y1) (list x2 y1)
                    (list x1 ym) (list xm ym) (list x2 ym)
                    (list x1 y2) (list xm y2) (list x2 y2))
                  count 0)
            (foreach p samples
              (if (pt-in-poly p poly) (setq count (1+ count))))
            (>= count 5))))))

  ;; 1. Chon boundary (hoac Enter de chon khong can bound)
  (prompt "\n[SBSE] Chọn vùng bound bằng Polyline kín (Enter để lọc không cần bound): ")
  (setq entBound (car (entsel)))
  (setq pts nil)
  (if entBound
    (progn
      (setq pts (get-poly-pts entBound))
      (if (not pts)
        (prompt "\n[SBSE] Vùng chọn không phải là Polyline kín. Chuyển sang lọc không cần bound."))))

  ;; 2. Chon doi tuong mau
  (prompt "\n[SBSE] Chọn 1 đối tượng mẫu để lọc CHÍNH XÁC (trùng nội dung text / block / hatch): ")
  (setq entMau (car (entsel)))
  (if (not entMau)
    (prompt "\n[SBSE] Chưa chọn đối tượng mẫu.")
    (progn
      ;; 3. Lay thuoc tinh doi tuong mau
      (setq edMau        (entget entMau))
      (setq mauType      (cdr (assoc 0 edMau)))
      (setq mauLayer     (cdr (assoc 8 edMau)))
      (setq mauLtype     (cdr (assoc 6 edMau)))
      (setq mauName      (cdr (assoc 2 edMau)))
      (setq mauColorInfo (tgirr:get-color entMau))

      ;; Neu mau la TEXT / MTEXT -> trich xuat noi dung chu
      (if (vl-position mauType '("TEXT" "MTEXT"))
        (progn
          (setq mauText (tgirr:get-text entMau))
          (setq mauCleanText (tgirr:clean-text mauText))))

      ;; Neu mau la INSERT (Block) -> lay ten chuan (Dynamic Block)
      (if (= mauType "INSERT")
        (setq mauBlock (tgirr:get-block-name entMau)))

      ;; 4. Thu thap doi tuong
      (if pts
        (setq ssAll (ssget "_CP" pts))
        (progn
          (prompt "\n[SBSE] Quét chọn vùng lọc theo mẫu (Enter để lọc toàn bộ bản vẽ): ")
          (setq ssAll (ssget))
          (if (not ssAll)
            (setq ssAll (ssget "_X" (list (cons 410 (getvar "CTAB"))))))))

      (if ssAll
        (progn
          (setq ssNew (ssadd))
          (setq i 0)

          (while (< i (sslength ssAll))
            (setq e  (ssname ssAll i))
            (setq ed (entget e))
            (setq eType (cdr (assoc 0 ed)))

            (if
              (and
                (/= e entBound)
                (= (cdr (assoc 8 ed)) mauLayer)
                (equal (tgirr:get-color e) mauColorInfo)
                (= (cdr (assoc 6 ed)) mauLtype)
                (if pts (mostly-in-p e pts) T))
              (progn
                (setq matchExact nil)

                (cond
                  ;; TH1: Mau la TEXT hoac MTEXT -> bat buoc trung noi dung chu
                  ((vl-position mauType '("TEXT" "MTEXT"))
                   (if (vl-position eType '("TEXT" "MTEXT"))
                     (progn
                       (setq eTxt (tgirr:get-text e))
                       (if (or (= mauText eTxt)
                               (= mauCleanText (tgirr:clean-text eTxt)))
                         (setq matchExact T)))))

                  ;; TH2: Mau la Block (INSERT) -> trung ten block
                  ((= mauType "INSERT")
                   (if (= eType "INSERT")
                     (if (= mauBlock (tgirr:get-block-name e))
                       (setq matchExact T))))

                  ;; TH3: Mau la HATCH -> trung pattern, scale va goc xoay
                  ((= mauType "HATCH")
                   (if (= eType "HATCH")
                     (if (and (tgirr:match-hatch-pattern (cdr (assoc 2 ed)) (cdr (assoc 2 edMau)))
                              (equal (cdr (assoc 41 ed)) (cdr (assoc 41 edMau)) 1e-4)
                              (equal (cdr (assoc 52 ed)) (cdr (assoc 52 edMau)) 1e-4))
                       (setq matchExact T))))

                  ;; TH4: Mau la CIRCLE hoac ARC -> trung ban kinh
                  ((vl-position mauType '("CIRCLE" "ARC"))
                   (if (= eType mauType)
                     (if (equal (cdr (assoc 40 ed)) (cdr (assoc 40 edMau)) 1e-4)
                       (setq matchExact T))))

                  ;; TH5: Mau la DIMENSION -> trung DimStyle
                  ((= mauType "DIMENSION")
                   (if (= eType "DIMENSION")
                     (if (= (cdr (assoc 3 ed)) (cdr (assoc 3 edMau)))
                       (setq matchExact T))))

                  ;; Mac dinh (LINE, LWPOLYLINE, SPLINE...): cung loai doi tuong
                  (T
                   (if (= eType mauType)
                     (setq matchExact T))))

                (if matchExact (ssadd e ssNew))))

            (setq i (1+ i)))

          (if (> (sslength ssNew) 0)
            (progn
              (sssetfirst nil ssNew)
              (prompt
                (strcat
                  "\n[SBSE] Đã chọn "
                  (itoa (sslength ssNew))
                  " đối tượng trùng khớp chính xác"
                  (if pts " trong bound." " trên bản vẽ."))))
            (prompt "\n[SBSE] Không tìm thấy đối tượng nào trùng khớp chính xác.")))
        (prompt "\n[SBSE] Không tìm thấy đối tượng nào."))))
  (princ)
)

;;; -------------------------------------------------------------
;;; TGIRR CAD LISP - LENH SCH / SH (SELECT COLOR HATCH)
;;; Chon nhanh tat ca cac Hatch co cung Mau sac va Pattern theo mau
;;; Hoan toan khong can duong Bound bao quanh!
;;; -------------------------------------------------------------
(defun c:SCH (/ entMau edMau patMau layMau colInfo ssCandidates ssSel idx cand edC layC patC colC)
  (prompt "\n[SCH] Chọn 1 đối tượng HATCH làm mẫu: ")
  (setq entMau (car (entsel)))
  (if (and entMau (= (cdr (assoc 0 (entget entMau))) "HATCH"))
    (progn
      (setq edMau   (entget entMau)
            patMau  (cdr (assoc 2 edMau))
            layMau  (cdr (assoc 8 edMau))
            colInfo (tgirr:get-color entMau))
      (prompt
        (strcat "\n[SCH] Mẫu: Layer = \"" layMau
                "\", Pattern = \"" (if (and patMau (/= patMau "")) patMau "SOLID")
                "\", Màu = " (tgirr:format-color-str colInfo)))
      (prompt "\n[SCH] Quét chọn vùng lọc Hatch (Enter để chọn toàn bộ bản vẽ): ")
      (setq ssCandidates (ssget '((0 . "HATCH"))))
      (if (not ssCandidates)
        (progn
          (prompt "\n[SCH] Đang tìm tất cả Hatch trong không gian hiện hành...")
          (setq ssCandidates
            (ssget "_X"
              (list
                '(0 . "HATCH")
                (cons 410 (getvar "CTAB")))))
          (if (not ssCandidates)
            (setq ssCandidates (ssget "_X" '((0 . "HATCH")))))))
      (if ssCandidates
        (progn
          (setq ssSel (ssadd))
          (setq idx 0)
          (while (< idx (sslength ssCandidates))
            (setq cand (ssname ssCandidates idx)
                  edC  (entget cand)
                  layC (cdr (assoc 8 edC))
                  patC (cdr (assoc 2 edC))
                  colC (tgirr:get-color cand))

            ;; Tieu chi so khop thong minh va linh hoat:
            ;; 1. Cung Layer chuyen dung (khong phai layer chung 0/DEFPOINTS)
            ;; 2. Cung Mau sac thuc te va cung kieu Pattern
            ;; 3. Cung Layer va cung Pattern (ke ca tren layer chung)
            (setq sameLay (= (strcase layC) (strcase layMau))
                  samePat (tgirr:match-hatch-pattern patC patMau)
                  sameCol (tgirr:colors-match-p colC colInfo)
                  isGenericLay (or (= (strcase layMau) "0")
                                   (= (strcase layMau) "DEFPOINTS")
                                   (= (strcase layMau) "HATCH")))

            (if (or
                  (and sameLay (not isGenericLay))
                  (and sameCol samePat)
                  (and sameLay samePat))
              (ssadd cand ssSel))
            (setq idx (1+ idx)))
          (if (> (sslength ssSel) 0)
            (progn
              (sssetfirst nil ssSel)
              (prompt
                (strcat "\n[SCH] Đã chọn " (itoa (sslength ssSel)) " Hatch phù hợp theo mẫu (Layer: \"" layMau "\", Màu: " (tgirr:format-color-str colInfo) ").")))
            (prompt "\n[SCH] Không tìm thấy Hatch nào phù hợp với mẫu.")))
        (prompt "\n[SCH] Không tìm thấy đối tượng Hatch nào.")))
    (prompt "\n[SCH] Đối tượng được chọn không phải là HATCH."))
  (princ)
)

(defun c:SH () (c:SCH))

(prompt "\nTGIRR: Đã nạp lệnh SBS, SBSE và SCH/SH (chọn Hatch theo màu mẫu).")
(princ)
