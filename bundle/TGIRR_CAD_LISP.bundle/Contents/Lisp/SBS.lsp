;;; =============================================================
;;; TGIRR CAD LISP - BO CONG CU LOC VA CHON DOI TUONG THEO MAU
;;; 1. SBS       : Chon doi tuong cung loai/mau trong Polyline bound (hoac toan ban ve neu khong chon bound)
;;; 2. SBSE / SBE / SE: Chon doi tuong trung khop chinh xac theo mau (Text, Block, Hatch, Dim...)
;;; 3. SCH / SH  : Chon nhanh tat ca Hatch cung Mau sac va Pattern theo mau (khong can bound)
;;; Ho tro 100% tuong thich: AutoCAD, ZWCAD, GstarCAD
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
    (col420 (list 420 col420 (if col62 (abs col62) 256)))
    ;; Neu doi tuong co mau ACI truc tiep (DXF 62 khac 256 va khac 0)
    ((and col62 (/= col62 256) (/= col62 0)) (list 62 (abs col62)))
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

;; Chuyen doi ma mau ACI (1-9) sang RGB tuong duong
(defun tgirr:aci->rgb (aci)
  (cond
    ((= aci 1) '(255 0 0))       ; Red
    ((= aci 2) '(255 255 0))     ; Yellow
    ((= aci 3) '(0 255 0))       ; Green
    ((= aci 4) '(0 255 255))     ; Cyan
    ((= aci 5) '(0 0 255))       ; Blue
    ((= aci 6) '(255 0 255))     ; Magenta
    ((or (= aci 7) (= aci 0) (= aci 256)) '(255 255 255)) ; White/Black
    ((= aci 8) '(128 128 128))   ; Dark Gray
    ((= aci 9) '(192 192 192))   ; Light Gray
    (T nil)))

;; So sanh 2 mau sac co tuong dong khong (ho tro TrueColor vs TrueColor, ACI vs ACI, TrueColor vs ACI)
(defun tgirr:colors-match-p (c1 c2 / t1 v1 t2 v2 aci1 aci2 rgb1 rgb2 r1 g1 b1 r2 g2 b2)
  (if (and c1 c2)
    (progn
      (setq t1 (car c1) v1 (cadr c1)
            t2 (car c2) v2 (cadr c2))
      (cond
        ;; TH1: Ca 2 cung la TrueColor 420
        ((and (= t1 420) (= t2 420))
         (setq r1 (lsh (logand v1 16711680) -16)
               g1 (lsh (logand v1 65280) -8)
               b1 (logand v1 255)
               r2 (lsh (logand v2 16711680) -16)
               g2 (lsh (logand v2 65280) -8)
               b2 (logand v2 255))
         (and (<= (abs (- r1 r2)) 20)
              (<= (abs (- g1 g2)) 20)
              (<= (abs (- b1 b2)) 20)))

        ;; TH2: Ca 2 cung la ACI 62
        ((and (= t1 62) (= t2 62))
         (= v1 v2))

        ;; TH3: 1 ben TrueColor 420, 1 ben ACI 62
        ((and (= t1 420) (= t2 62))
         (setq aci1 (caddr c1))
         (if (and aci1 (= aci1 v2) (/= aci1 256))
           T
           (progn
             (setq rgb2 (tgirr:aci->rgb v2))
             (if rgb2
               (progn
                 (setq r1 (lsh (logand v1 16711680) -16)
                       g1 (lsh (logand v1 65280) -8)
                       b1 (logand v1 255)
                       r2 (car rgb2) g2 (cadr rgb2) b2 (caddr rgb2))
                 (and (<= (abs (- r1 r2)) 30)
                      (<= (abs (- g1 g2)) 30)
                      (<= (abs (- b1 b2)) 30)))
               nil))))

        ((and (= t1 62) (= t2 420))
         (setq aci2 (caddr c2))
         (if (and aci2 (= v1 aci2) (/= aci2 256))
           T
           (progn
             (setq rgb1 (tgirr:aci->rgb v1))
             (if rgb1
               (progn
                 (setq r2 (lsh (logand v2 16711680) -16)
                       g2 (lsh (logand v2 65280) -8)
                       b2 (logand v2 255)
                       r1 (car rgb1) g1 (cadr rgb1) b1 (caddr rgb1))
                 (and (<= (abs (- r1 r2)) 30)
                      (<= (abs (- g1 g2)) 30)
                      (<= (abs (- b1 b2)) 30)))
               nil))))

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

;; Ham lay kieu duong net thuc te (ByLayer tra cuu tu Layer Table)
(defun tgirr:get-effective-ltype (ent / ed lt lay layEnt)
  (setq ed (entget ent))
  (setq lt (cdr (assoc 6 ed)))
  (if (or (null lt) (= (strcase lt) "BYLAYER"))
    (progn
      (setq lay (cdr (assoc 8 ed)))
      (if (and lay (setq layEnt (tblsearch "LAYER" lay)))
        (setq lt (cdr (assoc 6 layEnt)))
        (setq lt "CONTINUOUS"))
      (if (or (null lt) (= lt "")) (setq lt "CONTINUOUS"))
      (strcase lt))
    (strcase lt)))

;; So sanh 2 ten Hatch Pattern (chuan hoa khong phan biet hoa thuong, bo dau * va _ o dau)
(defun tgirr:match-hatch-pattern (p1 p2 / s1 s2)
  (setq s1 (if (and p1 (/= p1 "")) (vl-string-trim " *_" (strcase p1)) "SOLID")
        s2 (if (and p2 (/= p2 "")) (vl-string-trim " *_" (strcase p2)) "SOLID"))
  (or (= s1 s2)
      (wcmatch s1 (strcat "*" s2 "*"))
      (wcmatch s2 (strcat "*" s1 "*"))))

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

;; Ham lay noi dung chu cua TEXT hoac MTEXT (ho tro pure DXF fallback cho GstarCAD)
(defun tgirr:get-text (ent / ed typ txt str)
  (setq ed (entget ent))
  (setq typ (cdr (assoc 0 ed)))
  (if (= typ "TEXT")
    (cdr (assoc 1 ed))
    (progn
      ;; Thu qua ActiveX TextString truoc
      (setq txt (vl-catch-all-apply
                  '(lambda (/ obj)
                     (setq obj (vlax-ename->vla-object ent))
                     (if (vlax-property-available-p obj 'TextString)
                       (vla-get-textstring obj)
                       nil))))
      (if (or (vl-catch-all-error-p txt) (null txt) (= txt ""))
        ;; Fallback pure DXF ghep chuoi nhom 3 va 1
        (progn
          (setq str "")
          (foreach x ed
            (if (or (= (car x) 3) (= (car x) 1))
              (setq str (strcat str (cdr x)))))
          str)
        txt))))

;; Ham lay ten block (ho tro Dynamic Block EffectiveName ca ActiveX lan pure DXF)
(defun tgirr:get-block-name (ent / ed bname name blkRec xdict dict origName)
  (setq ed (entget ent))
  (setq bname (cdr (assoc 2 ed)))
  ;; 1. Thu qua ActiveX EffectiveName
  (setq name
    (vl-catch-all-apply
      '(lambda (/ obj)
         (setq obj (vlax-ename->vla-object ent))
         (if (vlax-property-available-p obj 'EffectiveName)
           (vla-get-effectivename obj)
           nil))))
  (if (or (vl-catch-all-error-p name) (null name) (= name ""))
    (setq name bname))
  ;; 2. Neu van la anonymous block (*U...), thu tim ten goc qua Block Table Record
  (if (and name (wcmatch (strcase name) "`*U*"))
    (if (and (setq blkRec (tblsearch "BLOCK" bname))
             (setq xdict (cdr (assoc 360 blkRec)))
             (setq dict (dictsearch xdict "ACAD_ENHANCEDBLOCK")))
      (if (setq origName (cdr (assoc 300 dict)))
        (setq name origName))))
  (if name name bname))

;; Ham lay danh sach dinh 2D cua vung boundary (ho tro LWPOLYLINE, POLYLINE, CIRCLE, ELLIPSE, SPLINE)
(defun tgirr:get-poly-points (ent / ed typ pts en cen rad ang maj ratio a b rot ex ey rx ry p1 pLast pt)
  (setq ed (entget ent))
  (setq typ (cdr (assoc 0 ed)))
  (setq pts '())
  (cond
    ((= typ "LWPOLYLINE")
     (foreach x ed
       (if (= (car x) 10)
         (setq pts (cons (list (cadr x) (caddr x)) pts))))
     (setq pts (reverse pts)))

    ((= typ "POLYLINE")
     (setq en (entnext ent))
     (while (and en (/= (cdr (assoc 0 (entget en))) "SEQEND"))
       (if (= (cdr (assoc 0 (entget en))) "VERTEX")
         (progn
           (setq pt (cdr (assoc 10 (entget en))))
           (setq pts (cons (list (car pt) (cadr pt)) pts))))
       (setq en (entnext en)))
     (setq pts (reverse pts)))

    ((= typ "CIRCLE")
     (setq cen (cdr (assoc 10 ed))
           rad (cdr (assoc 40 ed))
           ang 0.0)
     (repeat 36
       (setq pts (cons (list (+ (car cen) (* rad (cos ang)))
                             (+ (cadr cen) (* rad (sin ang))))
                       pts)
             ang (+ ang (/ (* 2.0 pi) 36.0))))
     (setq pts (reverse pts)))

    ((= typ "ELLIPSE")
     (setq cen   (cdr (assoc 10 ed))
           maj   (cdr (assoc 11 ed))
           ratio (cdr (assoc 40 ed))
           ang   0.0)
     (if (and cen maj ratio)
       (progn
         (setq a   (sqrt (+ (* (car maj) (car maj)) (* (cadr maj) (cadr maj))))
               b   (* a ratio)
               rot (atan (cadr maj) (car maj)))
         (repeat 36
           (setq ex (* a (cos ang))
                 ey (* b (sin ang))
                 rx (+ (* ex (cos rot)) (- (* ey (sin rot))))
                 ry (+ (* ex (sin rot)) (* ey (cos rot))))
           (setq pts (cons (list (+ (car cen) rx) (+ (cadr cen) ry)) pts)
                 ang (+ ang (/ (* 2.0 pi) 36.0))))
         (setq pts (reverse pts)))))

    ((= typ "SPLINE")
     (foreach x ed
       (if (vl-position (car x) '(10 11))
         (setq pts (cons (list (cadr x) (caddr x)) pts))))
     (setq pts (reverse pts)))

    (T nil))

  ;; Loai bo dinh cuoi bi trung voi dinh dau
  (if (and pts (> (length pts) 2))
    (progn
      (setq p1 (car pts) pLast (last pts))
      (if (< (distance p1 pLast) 1e-4)
        (setq pts (reverse (cdr (reverse pts)))))))
  pts)

;; Tinh bounding box hinh chu nhat cua tap diem (minX minY maxX maxY)
(defun tgirr:pts-bounding-box (pts / minX minY maxX maxY p x y)
  (if pts
    (progn
      (setq p (car pts) minX (car p) maxX (car p) minY (cadr p) maxY (cadr p))
      (foreach pt (cdr pts)
        (setq x (car pt) y (cadr pt))
        (if (< x minX) (setq minX x))
        (if (> x maxX) (setq maxX x))
        (if (< y minY) (setq minY y))
        (if (> y maxY) (setq maxY y)))
      (list minX minY maxX maxY))
    nil))

;; Kiem tra mot diem co nam trong polygon hay khong (ray casting)
(defun tgirr:point-in-poly (pt poly / x y inside j i pi pj xi yi xj yj)
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

;; Kiem tra nhanh bounding box truoc khi goi ray casting
(defun tgirr:point-in-poly-fast (pt poly pBox / px py)
  (if (and pt poly)
    (progn
      (setq px (car pt) py (cadr pt))
      (if pBox
        (if (and (>= px (car pBox))
                 (<= px (caddr pBox))
                 (>= py (cadr pBox))
                 (<= py (cadddr pBox)))
          (tgirr:point-in-poly pt poly)
          nil)
        (tgirr:point-in-poly pt poly)))
    nil))

;; Kiem tra doi tuong co nam trong polygon poly hay khong (thuan DXF, an toan tuyet doi)
(defun tgirr:entity-in-poly-p (ent poly pBox / ed typ ins p1 p2 cen rad ptsList pt in en x mn mx cx cy pmin pmax)
  (setq ed (entget ent))
  (setq typ (cdr (assoc 0 ed)))
  (cond
    ;; 1. BLOCK (INSERT) - kiem tra diem chen
    ((= typ "INSERT")
     (setq ins (cdr (assoc 10 ed)))
     (and ins (tgirr:point-in-poly-fast (list (car ins) (cadr ins)) poly pBox)))

    ;; 2. TEXT - kiem tra diem chen hoac can le
    ((= typ "TEXT")
     (setq ins (if (and (= (cdr (assoc 72 ed)) 0) (= (cdr (assoc 73 ed)) 0))
                 (cdr (assoc 10 ed))
                 (cdr (assoc 11 ed))))
     (if (null ins) (setq ins (cdr (assoc 10 ed))))
     (and ins (tgirr:point-in-poly-fast (list (car ins) (cadr ins)) poly pBox)))

    ;; 3. MTEXT - kiem tra diem chen
    ((= typ "MTEXT")
     (setq ins (cdr (assoc 10 ed)))
     (and ins (tgirr:point-in-poly-fast (list (car ins) (cadr ins)) poly pBox)))

    ;; 4. POINT - kiem tra diem
    ((= typ "POINT")
     (setq ins (cdr (assoc 10 ed)))
     (and ins (tgirr:point-in-poly-fast (list (car ins) (cadr ins)) poly pBox)))

    ;; 5. CIRCLE - kiem tra tam
    ((= typ "CIRCLE")
     (setq cen (cdr (assoc 10 ed)))
     (and cen (tgirr:point-in-poly-fast (list (car cen) (cadr cen)) poly pBox)))

    ;; 6. ARC - kiem tra tam hoac diem bat dau / ket thuc
    ((= typ "ARC")
     (setq cen (cdr (assoc 10 ed))
           rad (cdr (assoc 40 ed)))
     (if (and cen rad)
       (or (tgirr:point-in-poly-fast (list (car cen) (cadr cen)) poly pBox)
           (tgirr:point-in-poly-fast (polar (list (car cen) (cadr cen)) (cdr (assoc 50 ed)) rad) poly pBox)
           (tgirr:point-in-poly-fast (polar (list (car cen) (cadr cen)) (cdr (assoc 51 ed)) rad) poly pBox))
       nil))

    ;; 7. LINE - kiem tra diem dau, diem cuoi hoac trung diem
    ((= typ "LINE")
     (setq p1 (cdr (assoc 10 ed))
           p2 (cdr (assoc 11 ed)))
     (if (and p1 p2)
       (or (tgirr:point-in-poly-fast (list (car p1) (cadr p1)) poly pBox)
           (tgirr:point-in-poly-fast (list (car p2) (cadr p2)) poly pBox)
           (tgirr:point-in-poly-fast (list (/ (+ (car p1) (car p2)) 2.0)
                                           (/ (+ (cadr p1) (cadr p2)) 2.0)) poly pBox))
       nil))

    ;; 8. LWPOLYLINE - bat ky dinh nao nam trong bound
    ((= typ "LWPOLYLINE")
     (setq ptsList '() in nil)
     (foreach x ed
       (if (= (car x) 10)
         (setq ptsList (cons (list (cadr x) (caddr x)) ptsList))))
     (foreach pt ptsList
       (if (and (not in) (tgirr:point-in-poly-fast pt poly pBox))
         (setq in T)))
     in)

    ;; 9. POLYLINE (2D/3D heavy)
    ((= typ "POLYLINE")
     (setq en (entnext ent) in nil)
     (while (and en (/= (cdr (assoc 0 (entget en))) "SEQEND"))
       (if (= (cdr (assoc 0 (entget en))) "VERTEX")
         (progn
           (setq pt (cdr (assoc 10 (entget en))))
           (if (and (not in) (tgirr:point-in-poly-fast (list (car pt) (cadr pt)) poly pBox))
             (setq in T))))
       (setq en (entnext en)))
     in)

    ;; 10. HATCH
    ((= typ "HATCH")
     (setq in nil)
     (foreach x ed
       (if (and (not in) (= (car x) 10))
         (if (tgirr:point-in-poly-fast (list (cadr x) (caddr x)) poly pBox)
           (setq in T))))
     (if (not in)
       (progn
         (setq pmin nil pmax nil)
         (vl-catch-all-apply
           '(lambda (/ obj)
              (setq obj (vlax-ename->vla-object ent))
              (vla-getboundingbox obj 'pmin 'pmax)))
         (if (and pmin pmax)
           (progn
             (setq mn (vlax-safearray->list pmin)
                   mx (vlax-safearray->list pmax)
                   cx (/ (+ (car mn) (car mx)) 2.0)
                   cy (/ (+ (cadr mn) (cadr mx)) 2.0))
             (setq in (tgirr:point-in-poly-fast (list cx cy) poly pBox))))))
     in)

    ;; 11. MAC DINH (DIMENSION, LEADER, SOLID, ...)
    (T
     (setq in nil)
     (foreach x ed
       (if (and (not in) (vl-position (car x) '(10 11 12 13 14)))
         (if (tgirr:point-in-poly-fast (list (cadr x) (caddr x)) poly pBox)
           (setq in T))))
     (if (not in)
       (progn
         (setq pmin nil pmax nil)
         (vl-catch-all-apply
           '(lambda (/ obj)
              (setq obj (vlax-ename->vla-object ent))
              (vla-getboundingbox obj 'pmin 'pmax)))
         (if (and pmin pmax)
           (progn
             (setq mn (vlax-safearray->list pmin)
                   mx (vlax-safearray->list pmax)
                   cx (/ (+ (car mn) (car mx)) 2.0)
                   cy (/ (+ (cadr mn) (cadr mx)) 2.0))
             (setq in (tgirr:point-in-poly-fast (list cx cy) poly pBox))))))
     in)))

;;; -------------------------------------------------------------
;;; LENH SBS: SELECT BY SAMPLE
;;; Chon doi tuong cung loai/mau trong Polyline bound (hoac toan ban ve)
;;; -------------------------------------------------------------
(defun c:SBS (/ entBound pts pBox entMau edMau mauType mauLayer mauColorInfo mauLtype
                mauBlockName mauHatchPat ssCandidates ssNew i e ed eType matchOk)
  (vl-load-com)

  ;; 1. Chon boundary (hoac Enter de chon khong can bound)
  (prompt "\n[SBS] Chọn vùng bound (Polyline kín/Circle/Rectangle) hoặc Enter để lọc không bound: ")
  (setq entBound (car (entsel)))
  (setq pts nil pBox nil)
  (if entBound
    (progn
      (setq pts (tgirr:get-poly-points entBound))
      (if (and pts (> (length pts) 2))
        (setq pBox (tgirr:pts-bounding-box pts))
        (progn
          (prompt "\n[SBS] Đối tượng chọn không tạo được đường bao kín. Chuyển sang lọc không bound.")
          (setq pts nil pBox nil entBound nil)))))

  ;; 2. Chon doi tuong mau
  (prompt "\n[SBS] Chọn 1 đối tượng mẫu để lọc cùng thuộc tính: ")
  (setq entMau (car (entsel)))
  (if (not entMau)
    (prompt "\n[SBS] Chưa chọn đối tượng mẫu. Lệnh kết thúc.")
    (progn
      ;; Lay thuoc tinh doi tuong mau
      (setq edMau        (entget entMau))
      (setq mauType      (cdr (assoc 0 edMau)))
      (setq mauLayer     (cdr (assoc 8 edMau)))
      (setq mauColorInfo (tgirr:get-color entMau))
      (setq mauLtype     (tgirr:get-effective-ltype entMau))
      (setq mauBlockName (if (= mauType "INSERT") (tgirr:get-block-name entMau) nil))
      (setq mauHatchPat  (if (= mauType "HATCH") (cdr (assoc 2 edMau)) nil))

      ;; 3. Thu thap doi tuong ung vien
      (if pts
        (progn
          ;; Khi co bound: lay tat ca doi tuong cung Type va Layer trong khong gian hien hanh
          (setq ssCandidates
            (ssget "_X" (list (cons 410 (getvar "CTAB"))
                              (cons 0 mauType)
                              (cons 8 mauLayer))))
          (if (not ssCandidates)
            (setq ssCandidates (ssget "_X" (list (cons 0 mauType) (cons 8 mauLayer))))))
        (progn
          ;; Khi khong co bound: cho phep quet vung hoac Enter de loc toan ban ve
          (prompt "\n[SBS] Quét chọn vùng lọc theo mẫu (Enter để lọc toàn bộ bản vẽ): ")
          (setq ssCandidates (ssget (list (cons 0 mauType) (cons 8 mauLayer))))
          (if (not ssCandidates)
            (setq ssCandidates
              (ssget "_X" (list (cons 410 (getvar "CTAB"))
                                (cons 0 mauType)
                                (cons 8 mauLayer)))))
          (if (not ssCandidates)
            (setq ssCandidates (ssget "_X" (list (cons 0 mauType) (cons 8 mauLayer)))))))

      (if ssCandidates
        (progn
          (setq ssNew (ssadd))
          (setq i 0)
          (while (< i (sslength ssCandidates))
            (setq e (ssname ssCandidates i))
            (if (/= e entBound)
              (progn
                (setq ed (entget e))
                (setq eType (cdr (assoc 0 ed)))

                ;; Kiem tra cac tieu chi
                (setq matchOk
                  (and
                    (= eType mauType)
                    (= (strcase (cdr (assoc 8 ed))) (strcase mauLayer))
                    (tgirr:colors-match-p (tgirr:get-color e) mauColorInfo)
                    (= (tgirr:get-effective-ltype e) mauLtype)
                    (if (= mauType "INSERT")
                      (= (strcase (tgirr:get-block-name e)) (strcase mauBlockName))
                      T)
                    (if (= mauType "HATCH")
                      (tgirr:match-hatch-pattern (cdr (assoc 2 ed)) mauHatchPat)
                      T)
                    (if pts
                      (tgirr:entity-in-poly-p e pts pBox)
                      T)))

                (if matchOk (ssadd e ssNew))))
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
        (prompt "\n[SBS] Không tìm thấy đối tượng nào phù hợp loại và layer mẫu."))))
  (princ)
)

;;; -------------------------------------------------------------
;;; TGIRR CAD LISP - LENH SBSE / SBE / SE (SELECT BY SAMPLE EXACT)
;;; Loc doi tuong giong mau chinh xac (TEXT/MTEXT trung chu, INSERT trung EffectiveName...)
;;; Co the loc trong Polyline bound hoac Enter de loc khong can bound
;;; -------------------------------------------------------------
(defun c:SBSE (/ entBound pts pBox entMau edMau mauType mauLayer mauColorInfo mauLtype
                 mauText mauCleanText mauBlock mauHatchPat mauHatchScale mauHatchAngle
                 mauRadius mauDimStyle filterType ssCandidates ssNew i e ed eType
                 matchExact eTxt)
  (vl-load-com)

  ;; 1. Chon boundary (hoac Enter de chon khong can bound)
  (prompt "\n[SBSE] Chọn vùng bound (Polyline kín/Circle/Rectangle) hoặc Enter để lọc không bound: ")
  (setq entBound (car (entsel)))
  (setq pts nil pBox nil)
  (if entBound
    (progn
      (setq pts (tgirr:get-poly-points entBound))
      (if (and pts (> (length pts) 2))
        (setq pBox (tgirr:pts-bounding-box pts))
        (progn
          (prompt "\n[SBSE] Đối tượng chọn không tạo được đường bao kín. Chuyển sang lọc không bound.")
          (setq pts nil pBox nil entBound nil)))))

  ;; 2. Chon doi tuong mau
  (prompt "\n[SBSE] Chọn 1 đối tượng mẫu để lọc CHÍNH XÁC (trùng nội dung text / block / hatch): ")
  (setq entMau (car (entsel)))
  (if (not entMau)
    (prompt "\n[SBSE] Chưa chọn đối tượng mẫu. Lệnh kết thúc.")
    (progn
      ;; 3. Lay thuoc tinh doi tuong mau
      (setq edMau        (entget entMau))
      (setq mauType      (cdr (assoc 0 edMau)))
      (setq mauLayer     (cdr (assoc 8 edMau)))
      (setq mauColorInfo (tgirr:get-color entMau))
      (setq mauLtype     (tgirr:get-effective-ltype entMau))

      ;; Neu mau la TEXT / MTEXT -> trich xuat noi dung chu
      (if (vl-position mauType '("TEXT" "MTEXT"))
        (progn
          (setq mauText (tgirr:get-text entMau))
          (setq mauCleanText (tgirr:clean-text mauText))))

      ;; Neu mau la INSERT (Block) -> lay ten chuan (Dynamic Block)
      (if (= mauType "INSERT")
        (setq mauBlock (tgirr:get-block-name entMau)))

      ;; Neu mau la HATCH -> lay pattern, scale, goc xoay
      (if (= mauType "HATCH")
        (setq mauHatchPat   (cdr (assoc 2 edMau))
              mauHatchScale (cdr (assoc 41 edMau))
              mauHatchAngle (cdr (assoc 52 edMau))))

      ;; Neu mau la CIRCLE / ARC -> lay ban kinh
      (if (vl-position mauType '("CIRCLE" "ARC"))
        (setq mauRadius (cdr (assoc 40 edMau))))

      ;; Neu mau la DIMENSION -> lay DimStyle
      (if (= mauType "DIMENSION")
        (setq mauDimStyle (cdr (assoc 3 edMau))))

      ;; Loai loc: neu la TEXT/MTEXT thi loc chung "*TEXT"
      (setq filterType (if (vl-position mauType '("TEXT" "MTEXT")) "*TEXT" mauType))

      ;; 4. Thu thap doi tuong ung vien
      (if pts
        (progn
          (setq ssCandidates
            (ssget "_X" (list (cons 410 (getvar "CTAB"))
                              (cons 0 filterType)
                              (cons 8 mauLayer))))
          (if (not ssCandidates)
            (setq ssCandidates (ssget "_X" (list (cons 0 filterType) (cons 8 mauLayer))))))
        (progn
          (prompt "\n[SBSE] Quét chọn vùng lọc theo mẫu (Enter để lọc toàn bộ bản vẽ): ")
          (setq ssCandidates (ssget (list (cons 0 filterType) (cons 8 mauLayer))))
          (if (not ssCandidates)
            (setq ssCandidates
              (ssget "_X" (list (cons 410 (getvar "CTAB"))
                                (cons 0 filterType)
                                (cons 8 mauLayer)))))
          (if (not ssCandidates)
            (setq ssCandidates (ssget "_X" (list (cons 0 filterType) (cons 8 mauLayer)))))))

      (if ssCandidates
        (progn
          (setq ssNew (ssadd))
          (setq i 0)
          (while (< i (sslength ssCandidates))
            (setq e (ssname ssCandidates i))
            (if (/= e entBound)
              (progn
                (setq ed (entget e))
                (setq eType (cdr (assoc 0 ed)))

                (if
                  (and
                    (= (strcase (cdr (assoc 8 ed))) (strcase mauLayer))
                    (tgirr:colors-match-p (tgirr:get-color e) mauColorInfo)
                    (= (tgirr:get-effective-ltype e) mauLtype)
                    (if pts (tgirr:entity-in-poly-p e pts pBox) T))
                  (progn
                    (setq matchExact nil)

                    (cond
                      ;; TH1: TEXT hoac MTEXT -> trung noi dung chu
                      ((vl-position mauType '("TEXT" "MTEXT"))
                       (if (vl-position eType '("TEXT" "MTEXT"))
                         (progn
                           (setq eTxt (tgirr:get-text e))
                           (if (or (= mauText eTxt)
                                   (= mauCleanText (tgirr:clean-text eTxt))
                                   (= (strcase (tgirr:clean-text mauText)) (strcase (tgirr:clean-text eTxt))))
                             (setq matchExact T)))))

                      ;; TH2: Mau la Block (INSERT) -> trung ten block (ho tro Dynamic Block)
                      ((= mauType "INSERT")
                       (if (= eType "INSERT")
                         (if (= (strcase mauBlock) (strcase (tgirr:get-block-name e)))
                           (setq matchExact T))))

                      ;; TH3: Mau la HATCH -> trung pattern, scale va goc xoay
                      ((= mauType "HATCH")
                       (if (= eType "HATCH")
                         (if (and (tgirr:match-hatch-pattern (cdr (assoc 2 ed)) mauHatchPat)
                                  (or (null mauHatchScale) (null (cdr (assoc 41 ed)))
                                      (equal (cdr (assoc 41 ed)) mauHatchScale 1e-4))
                                  (or (null mauHatchAngle) (null (cdr (assoc 52 ed)))
                                      (equal (cdr (assoc 52 ed)) mauHatchAngle 1e-4)))
                           (setq matchExact T))))

                      ;; TH4: Mau la CIRCLE hoac ARC -> trung ban kinh
                      ((vl-position mauType '("CIRCLE" "ARC"))
                       (if (= eType mauType)
                         (if (equal (cdr (assoc 40 ed)) mauRadius 1e-4)
                           (setq matchExact T))))

                      ;; TH5: Mau la DIMENSION -> trung DimStyle
                      ((= mauType "DIMENSION")
                       (if (= eType "DIMENSION")
                         (if (= (strcase (cdr (assoc 3 ed))) (strcase mauDimStyle))
                           (setq matchExact T))))

                      ;; Mac dinh (LINE, LWPOLYLINE, SPLINE...): cung loai doi tuong
                      (T
                       (if (= eType mauType)
                         (setq matchExact T))))

                    (if matchExact (ssadd e ssNew))))))
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
        (prompt "\n[SBSE] Không tìm thấy đối tượng nào phù hợp loại và layer mẫu."))))
  (princ)
)

;; Dinh nghia cac lenh tat cho SBSE: SBE va SE
(defun c:SBE () (c:SBSE))
(defun c:SE  () (c:SBSE))

;;; -------------------------------------------------------------
;;; TGIRR CAD LISP - LENH SCH / SH (SELECT COLOR HATCH)
;;; Chon nhanh tat ca cac Hatch co cung Mau sac va Pattern theo mau
;;; Hoan toan khong can duong Bound bao quanh!
;;; -------------------------------------------------------------
(defun c:SCH (/ entMau edMau patMau layMau colInfo ssCandidates ssSel idx cand edC layC patC colC
                sameLay samePat sameCol isGenericLay)
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

(prompt "\nTGIRR: Đã nạp lệnh SBS, SBSE / SBE / SE và SCH / SH.")
(princ)
