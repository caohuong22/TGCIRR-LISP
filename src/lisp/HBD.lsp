;;; ==========================================================================
;;; TGIRR CAD LISP - LENH HBD / BH / TGBOUND va LENH JH / MH / JOINHATCH
;;; 1. HBD: Ve duong bao (Boundary Polyline) xung quanh cac doi tuong HATCH co.
;;;         Co tuy chon [J] Hop nhat cac boundary giap nhau lam 1 (MAC DINH TAT
;;;         de giu nguyen 100% net duong bao goc, tranh bien dang khi UNION).
;;;         Co tuy chon [M] Loc theo Hatch mau (trung Pattern va Mau sac).
;;;         Co tuy chon [D] Loc lo dao (chi lay bao ngoai).
;;; 2. JH : Gop cac doi tuong Hatch phan manh giap nhau thanh 1 Hatch duy nhat
;;;         va tao 1 duong bao chung duy nhat tren Layer chuan TG-BOUND.
;;; 3. SP2PL / REG2PL: Chuyen doi nhanh moi SPLINE va REGION thanh LWPOLYLINE.
;;; Ho tro AutoCAD, ZWCAD va GstarCAD
;;; ==========================================================================
(vl-load-com)

;; Bien toan cuc ghi nho thiet lap giua cac lan goi lenh
(if (not *HBD:target-layer*) (setq *HBD:target-layer* "TG-BOUND"))
(if (not *HBD:outer-only*)   (setq *HBD:outer-only* nil))   ; nil = giu tat ca (ca dao); T = chi lay bao ngoai
;; MAC DINH TAT hop nhat (UNION): giu nguyen 100% duong bao cua tung Hatch,
;; tranh thuat toan Region Union lam bien dang/mat net khi ranh giap phuc tap.
;; Nguoi dung co the bat lai bang tuy chon [J] trong lenh HBD khi can.
(if (not *HBD:union-bounds-initialized*)
  (progn
    (setq *HBD:union-bounds-initialized* T)
    (if (not *HBD:union-bounds*) (setq *HBD:union-bounds* nil))))


;; Ham tao hoac dam bao Layer ton tai voi mau va kieu net chuan
(defun HBD:ensure-layer (layer-name color ltype / lay-tbl)
  (if (not (tblsearch "LAYER" layer-name))
    (progn
      (setvar "CMDECHO" 0)
      (command "_.-LAYER"
               "_New" layer-name
               "_Color" (itoa color) layer-name
               "_Ltype" ltype layer-name
               "")
    )
  )
  layer-name
)

;; Chuyen doi ename thanh selection set 1 doi tuong
(defun HBD:ename-to-ss (ent / ss)
  (setq ss (ssadd))
  (if ent (ssadd ent ss))
  ss
)

;; Thu thap tat ca doi tuong sinh ra sau mot entity moc (last-ent)
(defun HBD:get-new-entities (last-ent / ent lst)
  (setq lst nil)
  (if last-ent
    (while (setq ent (entnext last-ent))
      (setq lst (cons ent lst))
      (setq last-ent ent)
    )
    (progn
      (setq ent (entnext))
      (while ent
        (setq lst (cons ent lst))
        (setq ent (entnext ent))
      )
    )
  )
  (reverse lst)
)

;; Tinh dien tich cua 1 duong cong (VLA hoac Curve)
(defun HBD:get-area (ent / obj area)
  (setq obj (vlax-ename->vla-object ent))
  (setq area (vl-catch-all-apply 'vlax-curve-getArea (list obj)))
  (if (vl-catch-all-error-p area) 0.0 area)
)

;; Lay thong tin mau thuc te cua doi tuong (ho tro ACI 62, TrueColor 420, ByLayer tu Layer)
(defun HBD:get-color-info (ent / ed col62 col420 lay layEnt layCol layCol420)
  (setq ed (entget ent))
  (setq col62  (cdr (assoc 62 ed)))
  (setq col420 (cdr (assoc 420 ed)))
  (setq lay    (cdr (assoc 8 ed)))
  (cond
    ;; Neu doi tuong co TrueColor truc tiep (DXF 420)
    (col420
     (list 420 col420 (if (and col62 (/= col62 0) (/= col62 256)) col62 nil)))
    ;; Neu doi tuong co mau ACI truc tiep (DXF 62, khac 256 va khac 0)
    ((and col62 (/= col62 256) (/= col62 0))
     (list 62 col62))
    ;; ByBlock (DXF 62 = 0): mau hien thi theo Block chua no, KHONG duoc lay mau Layer
    ((and col62 (= col62 0))
     (list 0 0))
    ;; Neu la ByLayer (hoac khong co 62): tra cuu tu Layer Table
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

;; Doi mau ACI (1-255) sang RGB that su bang doi tuong AcCmColor (ho tro AutoCAD/ZWCAD/GstarCAD)
(defun HBD:get-cmcolor-obj (/ obj pid)
  (if (not *HBD:cmcolor-tried*)
    (progn
      (setq *HBD:cmcolor-tried* T)
      (foreach pid '("AutoCAD.AcCmColor.1" "ZWCAD.AcCmColor.1" "GstarCAD.AcCmColor.1" "AcCmColor")
        (if (not *HBD:cmcolor-obj*)
          (progn
            (setq obj (vl-catch-all-apply 'vlax-create-object (list pid)))
            (if (not (vl-catch-all-error-p obj))
              (setq *HBD:cmcolor-obj* obj)))))))
  *HBD:cmcolor-obj*)

(defun HBD:aci-to-rgb (aci / obj r g b)
  (setq obj (HBD:get-cmcolor-obj))
  (if (and obj (numberp aci) (>= aci 1) (<= aci 255))
    (progn
      (vl-catch-all-apply 'vla-put-ColorIndex (list obj aci))
      (setq r (vl-catch-all-apply 'vla-get-Red   (list obj))
            g (vl-catch-all-apply 'vla-get-Green (list obj))
            b (vl-catch-all-apply 'vla-get-Blue  (list obj)))
      (if (or (vl-catch-all-error-p r) (vl-catch-all-error-p g) (vl-catch-all-error-p b))
        nil
        (list r g b)))
    nil))

;; Trich xuat RGB tu thong tin mau (tra ve (r g b) hoac nil neu khong qui doi duoc)
(defun HBD:colorinfo-rgb (c / typ val)
  (if c
    (progn
      (setq typ (car c) val (cadr c))
      (cond
        ((= typ 420)
         (list (lsh (logand val 16711680) -16)
               (lsh (logand val 65280) -8)
               (logand val 255)))
        ((= typ 62) (HBD:aci-to-rgb val))
        (T nil)))
    nil))

;; So sanh 2 mau sac co tuong dong khong
;; - Giong nhau chinh xac (cung loai + cung gia tri) -> khop
;; - Neu khong, qui doi ca 2 ve RGB that su de so sanh (dung sai nho 5/255)
;;   => TrueColor va ACI cung mau hien thi se khop dung, khong con so sanh doan mo
(defun HBD:colors-match-p (c1 c2 / rgb1 rgb2)
  (cond
    ((or (not c1) (not c2)) nil)
    ((and (= (car c1) (car c2)) (= (cadr c1) (cadr c2))) T)
    (T
     (setq rgb1 (HBD:colorinfo-rgb c1)
           rgb2 (HBD:colorinfo-rgb c2))
     (and rgb1 rgb2
          (<= (abs (- (car rgb1)    (car rgb2)))    5)
          (<= (abs (- (cadr rgb1)   (cadr rgb2)))   5)
          (<= (abs (- (caddr rgb1)  (caddr rgb2)))  5)))))

;; Dinh dang chuoi mo ta mau sac cho thong bao nguoi dung
(defun HBD:format-color-str (colInfo / typ val rgb)
  (setq typ (car colInfo) val (cadr colInfo))
  (cond
    ((= typ 0) "ByBlock")
    ((= typ 420)
     (strcat "RGB (" (itoa (lsh (logand val 16711680) -16)) ","
                     (itoa (lsh (logand val 65280) -8)) ","
                     (itoa (logand val 255)) ")"))
    ((= typ 62)
     (setq rgb (HBD:aci-to-rgb val))
     (if rgb
       (strcat "Color " (itoa val) " (RGB " (itoa (car rgb)) "," (itoa (cadr rgb)) "," (itoa (caddr rgb)) ")")
       (strcat "Color " (itoa val))))
    (T "ByLayer")))

;; So sanh 2 ten Hatch Pattern: KHOP CHINH XAC (chuan hoa hoa/thuong, dau cach, * va _)
;; Khong con dung so khop chua dung (containment) de tranh AR-CONC nham lan AR-CONCR...
(defun HBD:pattern-match-p (p1 p2 / s1 s2)
  (setq s1 (if (and p1 (/= p1 "")) (vl-string-trim " *_" (strcase p1)) "SOLID")
        s2 (if (and p2 (/= p2 "")) (vl-string-trim " *_" (strcase p2)) "SOLID"))
  (= s1 s2))

;;; ==========================================================================
;;; BO HAM CHUYEN DOI SPLINE VA REGION SANG LWPOLYLINE CHUAN
;;; ==========================================================================

;; Chuyen doi 1 SPLINE (hoac ELLIPSE) thanh LWPOLYLINE khep kin bang vlax-curve
(defun HBD:spline-to-polyline (ent / obj lay col62 col420 isClosed pStart pEnd totalLen
                                     nSeg dStep pts d pt newPl dxf)
  (setq obj (vlax-ename->vla-object ent))
  (if (vl-catch-all-error-p (vl-catch-all-apply 'vlax-curve-getEndParam (list obj)))
    nil
    (progn
      (setq lay      (cdr (assoc 8 (entget ent)))
            col62    (assoc 62 (entget ent))
            col420   (assoc 420 (entget ent))
            pStart   (vlax-curve-getStartPoint obj)
            pEnd     (vlax-curve-getEndPoint obj)
            isClosed (or (= (vla-get-Closed obj) :vlax-true)
                         (vlax-curve-isClosed obj)
                         (< (distance pStart pEnd) 0.05))
            totalLen (vlax-curve-getDistAtParam obj (vlax-curve-getEndParam obj)))
      (if (and totalLen (> totalLen 1e-4))
        (progn
          ;; Lay mau diem doc theo duong cong (buoc nhay ~0.05m, toi thieu 32 diem, toi da 1500 diem
          ;; -> tang do min so voi truoc (0.08m/300 diem) de khong lam "mat net" cac duong cong dai)
          (setq nSeg (max 32 (min 1500 (fix (/ totalLen 0.05)))))
          (setq dStep (/ totalLen (float nSeg)))
          (setq pts '() d 0.0)
          (while (< d totalLen)
            (setq pt (vlax-curve-getPointAtDist obj d))
            (if pt (setq pts (cons (list (car pt) (cadr pt)) pts)))
            (setq d (+ d dStep)))
          (if (not isClosed)
            (setq pts (cons (list (car pEnd) (cadr pEnd)) pts)))
          (setq pts (reverse pts))

          ;; Tao LWPOLYLINE moi theo chuan DXF (Group 8 o AcDbEntity)
          (setq dxf (list
                      '(0 . "LWPOLYLINE")
                      '(100 . "AcDbEntity")
                      (cons 8 (if (and lay (/= lay "")) lay "0"))
                      '(100 . "AcDbPolyline")
                      (cons 90 (length pts))
                      (cons 70 (if isClosed 1 0))))
          (if col62  (setq dxf (append dxf (list col62))))
          (if col420 (setq dxf (append dxf (list col420))))
          (foreach p pts
            (setq dxf (append dxf (list (cons 10 p)))))
          (setq newPl (entmakex dxf))
          (if newPl
            (progn
              (vl-catch-all-apply 'entdel (list ent))
              newPl)
            ent))
        ent))))

;; Dong polyline mot cach AN TOAN: chi dat Closed khi 2 dau da trung/khap gan nhau.
;; Neu duong bao con ho (dau-cuoi lech qua dung sai) -> GIU NGUYEN, KHONG noi tat
;; (viec noi tat khi ep Closed se lam "mat net" cac canh that cua duong bao).
(defun HBD:safe-close (ent / obj pStart pEnd dist)
  (if (and ent (entget ent)
           (member (cdr (assoc 0 (entget ent))) '("LWPOLYLINE" "POLYLINE")))
    (progn
      (setq obj (vlax-ename->vla-object ent))
      (setq pStart (vl-catch-all-apply 'vlax-curve-getStartPoint (list obj)))
      (setq pEnd   (vl-catch-all-apply 'vlax-curve-getEndPoint   (list obj)))
      (if (and (not (vl-catch-all-error-p pStart))
               (not (vl-catch-all-error-p pEnd)))
        (progn
          (setq dist (distance pStart pEnd))
          ;; Dung sai 1e-4 ~ da trung nhau -> an toan de dong kin
          (if (or (< dist 1e-4) (= (vla-get-Closed obj) :vlax-true))
            (vl-catch-all-apply 'vla-put-Closed (list obj :vlax-true))))))
  ent))

;; Chuyen doi 1 tap hop Selection Set thanh danh sach entity
(defun HBD:ss-to-list (ss / lst i)
  (setq lst '())
  (if ss
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (setq lst (cons (ssname ss i) lst))
        (setq i (1+ i)))
      (reverse lst)))
  lst)

;; Explode an toan 1 Region thanh cac duong bien (Line, Arc, Spline, Ellipse)
(defun HBD:explode-region (regEnt / lastBefore curEnts ss)
  (setq lastBefore (entlast))
  ;; Thu 1: truyen ename truc tiep cho EXPLODE
  (vl-catch-all-apply
    '(lambda ()
       (command "_.EXPLODE" regEnt)
       (while (wcmatch (getvar "CMDNAMES") "*EXPLODE*")
         (command ""))))
  (setq curEnts (HBD:get-new-entities lastBefore))
  ;; Thu 2: Neu chua no duoc (regEnt van con nguyen va khong co entity moi), dung ss
  (if (and (not curEnts) regEnt (entget regEnt))
    (vl-catch-all-apply
      '(lambda ()
         (setq ss (ssadd regEnt))
         (command "_.EXPLODE" ss "")
         (while (wcmatch (getvar "CMDNAMES") "*EXPLODE*")
           (command "")))))
  (setq curEnts (HBD:get-new-entities lastBefore))
  ;; Chi xoa Region goc khi explode DA sinh ra duong bien moi.
  ;; Neu explode that bai ma van xoa -> mat trang bound (loi "mat net")
  (if (and curEnts regEnt (entget regEnt))
    (vl-catch-all-apply 'entdel (list regEnt)))
  curEnts
)

;; Gop cac manh roi (Line, Arc, LWPolyline) thanh LWPOLYLINE khep kin
(defun HBD:join-pieces-to-polylines (ss / lastBefore oldPedit resEnts outPolys pl)
  (if (and ss (> (sslength ss) 0))
    (progn
      (setq lastBefore (entlast))
      ;; 1. Thu _.JOIN (nhanh nhat tren modern CAD)
      (vl-catch-all-apply
        '(lambda ()
           (command "_.JOIN" ss "")
           (while (wcmatch (getvar "CMDNAMES") "*JOIN*")
             (command ""))))

      ;; 2. Neu van con Line hoac Arc roi, dung PEDIT Join
      (setq resEnts (HBD:get-new-entities lastBefore))
      (if (or (not resEnts)
              (vl-some '(lambda (e) (member (cdr (assoc 0 (entget e))) '("LINE" "ARC"))) resEnts))
        (progn
          (setq oldPedit (getvar "PEDITACCEPT"))
          (vl-catch-all-apply 'setvar (list "PEDITACCEPT" 1))
          (vl-catch-all-apply
            '(lambda ()
               (command "_.PEDIT" "_M" ss "" "_J" 0.05 "")
               (while (wcmatch (getvar "CMDNAMES") "*PEDIT*")
                 (command ""))))
          (if oldPedit (vl-catch-all-apply 'setvar (list "PEDITACCEPT" oldPedit)))

          ;; Fallback voi chuoi "_Y" neu CAD yeu cau xac nhan Convert Lines to Polylines
          (setq resEnts (HBD:get-new-entities lastBefore))
          (if (or (not resEnts)
                  (vl-some '(lambda (e) (member (cdr (assoc 0 (entget e))) '("LINE" "ARC"))) resEnts))
            (vl-catch-all-apply
              '(lambda ()
                 (command "_.PEDIT" "_M" ss "" "_Y" "_J" 0.05 "")
                 (while (wcmatch (getvar "CMDNAMES") "*PEDIT*")
                   (command "")))))))

      ;; 3. Thu thap cac entity tao ra va dam bao Closed
      ;;    Luu y: mot so CAD sua doi entity tai cho (JOIN/PEDIT giu nguyen ename)
      ;;    -> phai gom ca cac entity con song sot trong ss goc, tranh mat net
      (setq resEnts (HBD:get-new-entities lastBefore))
      (setq resEnts
        (append resEnts
          (vl-remove-if-not
            '(lambda (e)
               (and e (entget e)
                    (member (cdr (assoc 0 (entget e))) '("LWPOLYLINE" "POLYLINE" "SPLINE" "ELLIPSE"))))
            (HBD:ss-to-list ss))))
      (if (not resEnts)
        (setq resEnts (vl-remove-if-not 'entget (HBD:ss-to-list ss))))

      (setq outPolys '())
      (foreach re resEnts
        (if (and re (entget re))
          (cond
            ((member (cdr (assoc 0 (entget re))) '("LWPOLYLINE" "POLYLINE"))
             (HBD:safe-close re)
             (setq outPolys (cons re outPolys)))
            ((member (cdr (assoc 0 (entget re))) '("SPLINE" "ELLIPSE"))
             (setq pl (HBD:spline-to-polyline re))
             (if (and pl (entget pl))
               (progn
                 (HBD:safe-close pl)
                 (setq outPolys (cons pl outPolys)))))
            (T nil))))
      (reverse outPolys))
    nil)
)

;; Chuyen doi 1 REGION thanh danh sach LWPOLYLINE khep kin
;; Tuyet doi khong bao gio tra ve Region
(defun HBD:region-to-polyline (regEnt / curEnts ssJoin ep pl out)
  (if (and regEnt (entget regEnt) (= (cdr (assoc 0 (entget regEnt))) "REGION"))
    (progn
      ;; 1. Explode region thanh cac bien
      (setq curEnts (HBD:explode-region regEnt))
      (if (not curEnts)
        nil
        (progn
          ;; 2. Convert Spline / Ellipse sang Polyline
          (setq ssJoin (ssadd))
          (foreach ep curEnts
            (if (and ep (entget ep))
              (cond
                ((member (cdr (assoc 0 (entget ep))) '("SPLINE" "ELLIPSE"))
                 (setq pl (HBD:spline-to-polyline ep))
                 (if (and pl (entget pl)) (ssadd pl ssJoin)))
                ((= (cdr (assoc 0 (entget ep))) "REGION")
                 (setq pl (HBD:region-to-polyline ep))
                 (if pl (foreach p pl (if (and p (entget p)) (ssadd p ssJoin)))))
                (T
                 (ssadd ep ssJoin)))))
          ;; 3. Join tat ca cac manh lai thanh LWPOLYLINE
          (setq out (HBD:join-pieces-to-polylines ssJoin))
          out)))
    nil)
)

;; Dam bao tat ca doi tuong deu tro thanh LWPOLYLINE khep kin (khong con REGION hoac SPLINE)
(defun HBD:clean-all-to-polylines (entList / cleanList res)
  (setq cleanList '())
  (foreach e entList
    (if (and e (entget e))
      (cond
        ((= (cdr (assoc 0 (entget e))) "LWPOLYLINE")
         (HBD:safe-close e)
         (setq cleanList (cons e cleanList)))
        ((= (cdr (assoc 0 (entget e))) "POLYLINE")
         (HBD:safe-close e)
         (setq cleanList (cons e cleanList)))
        ((member (cdr (assoc 0 (entget e))) '("SPLINE" "ELLIPSE"))
         (setq res (HBD:spline-to-polyline e))
         (if res
           (progn
             (HBD:safe-close res)
             (setq cleanList (cons res cleanList)))))
        ((= (cdr (assoc 0 (entget e))) "REGION")
         (setq res (HBD:region-to-polyline e))
         (if res
           (setq cleanList (append (reverse res) cleanList))))
        (T nil))))
  (reverse cleanList))

;;; ==========================================================================
;;; TAO VA HOP NHAT BOUNDARY HATCH
;;; ==========================================================================

;; Tao boundary cho 1 hatch va lap tuc convert sach se thanh LWPOLYLINE
;; Luu y: HATCHGENERATEBOUNDARY co the sinh ra LINE/ARC roi (khi bien goc cua
;; hatch khong phai polyline). Phai JOIN chung lai thanh Polyline, neu khong
;; se bi "khong joint" va lot lưới loc chi giu LWPOLYLINE/POLYLINE o c:HBD.
(defun HBD:list-to-ss (entList / ss)
  (setq ss (ssadd))
  (foreach e entList
    (if (and e (entget e)) (ssadd e ss)))
  ss)

(defun HBD:generate-boundary-single (hatch-ent / ss ok lastEnt created loose polys joined resList)
  (setq lastEnt (entlast))
  (setq ss (HBD:ename-to-ss hatch-ent))
  ;; Thu lenh HATCHGENERATEBOUNDARY (co tren AutoCAD 2011+, ZWCAD, GstarCAD)
  (setq ok (vl-cmdf "_.HATCHGENERATEBOUNDARY" ss ""))
  (if (not ok)
    ;; Fallback qua -HATCHEDIT
    (setq ok (vl-cmdf "_.-HATCHEDIT" hatch-ent "_B" "_P" "_N")))
  (setq created (HBD:get-new-entities lastEnt))
  (if created
    (progn
      ;; Phan loai: manh roi (LINE/ARC/SPLINE/ELLIPSE) vs duong bao co san
      (setq loose
        (vl-remove-if-not
          '(lambda (e)
             (and (entget e)
                  (member (cdr (assoc 0 (entget e))) '("LINE" "ARC" "SPLINE" "ELLIPSE"))))
          created))
      (setq polys
        (vl-remove-if-not
          '(lambda (e)
             (and (entget e)
                  (member (cdr (assoc 0 (entget e))) '("LWPOLYLINE" "POLYLINE" "REGION"))))
          created))
      ;; JOIN cac manh roi thanh (cac) Polyline kep kin
      (setq joined '())
      (if loose
        (setq joined (HBD:join-pieces-to-polylines (HBD:list-to-ss loose))))
      ;; Don dep manh roi con sot lai sau JOIN (tranh rac tren ban ve)
      (foreach e loose
        (if (and e (entget e)
                 (member (cdr (assoc 0 (entget e))) '("LINE" "ARC")))
          (vl-catch-all-apply 'entdel (list e))))
      (setq resList (HBD:clean-all-to-polylines (append polys joined)))
      ;; Neu van chua co Polyline nao (join that bai) -> thu lai bang PEDIT join
      ;; toan bo entity con song sot
      (if (and (not resList) created)
        (setq resList
          (HBD:join-pieces-to-polylines
            (HBD:list-to-ss
              (vl-remove-if-not
                '(lambda (e)
                   (and e (entget e)
                        (member (cdr (assoc 0 (entget e)))
                                '("LINE" "ARC" "SPLINE" "ELLIPSE" "LWPOLYLINE" "POLYLINE"))))
                created)))))
      resList)
    nil))

;; Lay Bounding Box cua 1 entity
(defun HBD:get-bbox (ent / obj pmin pmax)
  (setq obj (vlax-ename->vla-object ent))
  (if (not (vl-catch-all-error-p (vl-catch-all-apply 'vla-GetBoundingBox (list obj 'pmin 'pmax))))
    (list (vlax-safearray->list pmin) (vlax-safearray->list pmax))
    nil))

;; Kiem tra 2 Bounding Box co giao/cham nhau khong (voi sai so fuzz = 0.05m)
(defun HBD:bbox-overlap-p (bb1 bb2 / fuzz mn1 mx1 mn2 mx2)
  (if (and bb1 bb2)
    (progn
      (setq fuzz 0.05
            mn1 (car bb1)  mx1 (cadr bb1)
            mn2 (car bb2)  mx2 (cadr bb2))
      (and (<= (- (car mn1) fuzz) (car mx2))
           (>= (+ (car mx1) fuzz) (car mn2))
           (<= (- (cadr mn1) fuzz) (cadr mx2))
           (>= (+ (cadr mx1) fuzz) (cadr mn2))))
    nil))

;; Phan cum danh sach ((ent bbox) ...) thanh: (list singles clusters)
(defun HBD:cluster-bounding-boxes (itemList / singles clusters remaining item curCluster changed newRemaining other)
  (setq singles '() clusters '() remaining itemList)
  (while remaining
    (setq item       (car remaining)
          remaining  (cdr remaining)
          curCluster (list item)
          changed    T)
    ;; Loang cum tim cac doi tuong cham nhau
    (while changed
      (setq changed nil
            newRemaining '())
      (foreach other remaining
        (if (vl-some '(lambda (c) (HBD:bbox-overlap-p (cadr c) (cadr other))) curCluster)
          (setq curCluster (cons other curCluster)
                changed T)
          (setq newRemaining (cons other newRemaining))))
      (setq remaining (reverse newRemaining)))

    (if (= (length curCluster) 1)
      (setq singles (cons (caar curCluster) singles))
      (setq clusters (cons (mapcar 'car curCluster) clusters))))
  (list (reverse singles) (reverse clusters)))

;; Hop nhat 1 nhom nho cac Polyline cham/chong lan nhau
(defun HBD:union-single-cluster (polyList / cleanIn oldDelobj entBeforeUnion ssPoly createdRegs regList
                                            ssUnion survivingNew remRegs finalPolys r resExp e)
  (setq cleanIn (HBD:clean-all-to-polylines polyList))
  (if (or (not cleanIn) (<= (length cleanIn) 1))
    cleanIn
    (progn
      (setq entBeforeUnion (entlast))
      (setq ssPoly (ssadd))
      (foreach p cleanIn
        (if (and p (entget p)) (ssadd p ssPoly)))

      ;; Dat DELOBJ = 0 tam thoi de bao ve polyline ban dau
      (setq oldDelobj (getvar "DELOBJ"))
      (vl-catch-all-apply 'setvar (list "DELOBJ" 0))

      ;; 1. Tao Region cho nhom nay
      (vl-catch-all-apply
        '(lambda ()
           (command "_.REGION" ssPoly "")
           (while (wcmatch (getvar "CMDNAMES") "*REGION*")
             (command ""))))

      (if oldDelobj (vl-catch-all-apply 'setvar (list "DELOBJ" oldDelobj)))

      (setq createdRegs (HBD:get-new-entities entBeforeUnion))
      (setq regList
        (vl-remove-if-not
          '(lambda (e) (and (entget e) (= (cdr (assoc 0 (entget e))) "REGION")))
          createdRegs))

      (if (< (length regList) 2)
        ;; Khong tao duoc du 2 region -> xoa cac region tam va giu nguyen cac polyline ban dau
        (progn
          (foreach r regList (if (entget r) (vl-catch-all-apply 'entdel (list r))))
          cleanIn)
        (progn
          ;; 2. Union cac region trong cum nay
          (setq ssUnion (ssadd))
          (foreach r regList (ssadd r ssUnion))
          (vl-catch-all-apply
            '(lambda ()
               (command "_.UNION" ssUnion "")
               (while (wcmatch (getvar "CMDNAMES") "*UNION*")
                 (command ""))))

          (setq survivingNew (HBD:get-new-entities entBeforeUnion))
          (setq remRegs
            (vl-remove-if-not
              '(lambda (e) (and (entget e) (= (cdr (assoc 0 (entget e))) "REGION")))
              survivingNew))

          ;; 3. Convert cac Region thanh LWPOLYLINE
          (setq finalPolys '())
          (foreach r remRegs
            (setq resExp (HBD:region-to-polyline r))
            (if resExp
              (setq finalPolys (append finalPolys resExp))))

          ;; 4. Don dep tat ca Region/Spline rac tao ra trong qua trinh union cum nay
          (foreach e (HBD:get-new-entities entBeforeUnion)
            (if (and (entget e) (member (cdr (assoc 0 (entget e))) '("REGION" "SPLINE")))
              (vl-catch-all-apply 'entdel (list e))))

          (if (> (length finalPolys) 0)
            (progn
              ;; Union thanh cong -> xoa cac polyline ban dau trong cum nay
              (foreach p cleanIn
                (if (and p (entget p)) (vl-catch-all-apply 'entdel (list p))))
              (HBD:clean-all-to-polylines finalPolys))
            ;; Union that bai -> GIU NGUYEN CAC POLYLINE BAN DAU TRONG CUM
            cleanIn))))))

;; Hop nhat cac Polyline giap nhau hoac chong lan thanh cac Polyline chung duy nhat (Region Union)
;; Su dung thuat toan phan cum thong minh (Clustering):
;; - Cac duong bao khong cham nhau -> GIU NGUYEN 100%, KHONG DUNG REGION
;; - Chi nhung duong bao thuc su tiep xuc/chong lan moi duoc gop trong cum nho
;; Bao dam 100% dau ra chi gom LWPOLYLINE khep kin, tuyet doi khong con REGION va khong bi mat bound
(defun HBD:union-polylines (polyList / cleanIn entBBoxes validItems clustered singles clusters
                                      resList c resC)
  (setq cleanIn (HBD:clean-all-to-polylines polyList))
  (if (or (not cleanIn) (<= (length cleanIn) 1))
    cleanIn
    (progn
      ;; Lay Bounding Box cho tung Polyline
      (setq entBBoxes
        (mapcar '(lambda (e) (list e (HBD:get-bbox e))) cleanIn))
      ;; Loai bo cac entity khong tinh duoc bbox (neu co)
      (setq validItems
        (vl-remove-if '(lambda (x) (null (cadr x))) entBBoxes))

      ;; Phan cum: cum don le va cum cham nhau
      (setq clustered (HBD:cluster-bounding-boxes validItems))
      (setq singles   (car clustered)
            clusters  (cadr clustered))

      ;; 1. Cac duong bao doc lap (khong cham ai) -> GIU NGUYEN 100%, KHONG DUNG REGION
      (setq resList singles)

      ;; 2. Cac cum co tiep xuc / chong lan -> chi union trong tung cum nho
      (foreach c clusters
        (setq resC (HBD:union-single-cluster c))
        (if resC
          (setq resList (append resList resC))
          (setq resList (append resList c))))

      ;; Dam bao toan bo ket qua deu la closed LWPolyline
      (HBD:clean-all-to-polylines resList))))

;;; ==========================================================================
;;; THUAT TOAN LOC LO DAO (OUTER-ONLY)
;;; ==========================================================================

;; Lay danh sach toa do dinh cua 1 polyline de kiem tra hinh hoc
(defun HBD:get-poly-pts (ent / ed pts)
  (setq ed (entget ent) pts '())
  (foreach x ed
    (if (= (car x) 10)
      (setq pts (cons (list (cadr x) (caddr x)) pts))))
  (reverse pts))

;; Kiem tra diem nam trong polygon (ray-casting)
(defun HBD:pt-in-poly (pt poly / x y inside j i pi pj xi yi xj yj)
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

;; Loc chi lay bao ngoai: chi xoa cac lo dao nam ben trong cac duong bao khac,
;; bao toan 100% cac tham co/bon cay doc lap khac tren ban ve
(defun HBD:filter-outer-only (polyList / areaList sorted outList pA ptsA)
  (if (or (not polyList) (<= (length polyList) 1))
    polyList
    (progn
      ;; Tinh dien tich va ghep cap (ent . area)
      (setq areaList
        (mapcar '(lambda (e) (cons e (HBD:get-area e))) polyList))
      ;; Sap xep giam dan theo dien tich
      (setq sorted
        (vl-sort areaList '(lambda (a b) (> (cdr a) (cdr b)))))

      (setq outList '())
      (while sorted
        (setq pA (caar sorted)
              ptsA (HBD:get-poly-pts pA)
              sorted (cdr sorted))
        (setq outList (cons pA outList))

        ;; Duyet cac phan tu nho hon con lai trong sorted de kiem tra xem co phai lo dao cua pA khong
        (setq sorted
          (vl-remove-if
            '(lambda (item / eB ptB)
               (setq eB (car item))
               (setq ptB (vlax-curve-getStartPoint (vlax-ename->vla-object eB)))
               (if (HBD:pt-in-poly ptB ptsA)
                 (progn
                   (if (entget eB) (entdel eB))
                   T) ; la lo dao cua pA -> xoa khoi ban ve va khoi danh sach
                 nil))
            sorted)))
      (reverse outList))))

;;; ==========================================================================
;;; LENH HBD: Ve duong bao Boundary cho Hatch co
;;; ==========================================================================
(defun c:HBD (/ oldCmdecho oldOsmode *error* doc undoStarted entInitial
                ssSel preSel opt entMau edMau patMau layMau colInfoMau
                ssCandidates idx cand edC
                hatchList totalHatches totalBounds i hEnt
                createdEnts allCreated finalBounds e bEnt)

  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq oldCmdecho (getvar "CMDECHO"))
  (setq oldOsmode   (getvar "OSMODE"))
  (setq undoStarted nil)
  (setq entInitial  nil)

  ;; Ham xu ly khi co loi hoac nguoi dung huy lenh (ESC)
  (defun *error* (msg)
    (if undoStarted
      (progn
        ;; Quet don sach se bat ky Region hoac Spline rac nao truoc khi ket thuc
        (if entInitial
          (foreach e (HBD:get-new-entities entInitial)
            (if (and (entget e) (member (cdr (assoc 0 (entget e))) '("REGION" "SPLINE")))
              (vl-catch-all-apply 'entdel (list e)))))
        (vl-catch-all-apply 'vla-EndUndoMark (list doc))))
    (if oldCmdecho (setvar "CMDECHO" oldCmdecho))
    (if oldOsmode (setvar "OSMODE"  oldOsmode))
    (if (and msg (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*BREAK*")))
      (prompt (strcat "\nTGIRR HBD Lỗi: " msg)))
    (princ))

  (setvar "CMDECHO" 0)

  ;; Kiem tra PICKFIRST (doi tuong da chon truoc khi go lenh)
  (setq preSel (ssget "_I" '((0 . "HATCH"))))

  (if preSel
    (progn
      (setq ssSel preSel)
      (sssetfirst nil nil))
    (progn
      ;; Hien thi menu lua chon
      (initget "M T J D L")
      (setq opt
        (getkword
          (strcat
            "\n[HBD] Chọn Hatch cỏ hoặc [Mẫu(M) / Tất cả(T) / Hợp nhất("
            (if *HBD:union-bounds* "Bật" "Tắt")
            "-J) / Đảo("
            (if *HBD:outer-only* "Chỉ ngoài" "Cả đảo")
            "-D) / Layer(L)]: ")))

      (cond
        ;; Tuy chon M: Chon theo hatch mau (Layer, Pattern va Mau sac)
        ((= opt "M")
          (prompt "\nChọn 1 đối tượng HATCH cỏ làm mẫu: ")
          (setq entMau (car (entsel)))
          (if (and entMau (= (cdr (assoc 0 (entget entMau))) "HATCH"))
            (progn
              (setq edMau      (entget entMau)
                    patMau     (cdr (assoc 2 edMau))
                    layMau     (cdr (assoc 8 edMau))
                    colInfoMau (HBD:get-color-info entMau))
              (prompt
                (strcat "\nMẫu đã chọn: Layer = \"" layMau
                        "\", Pattern = \"" (if (and patMau (/= patMau "")) patMau "SOLID")
                        "\", Màu = " (HBD:format-color-str colInfoMau)))
              (prompt "\nQuét chọn vùng tìm Hatch cỏ theo mẫu (Enter để tìm toàn bộ bản vẽ): ")
              (setq ssCandidates (ssget '((0 . "HATCH"))))
              (if (not ssCandidates)
                (progn
                  (prompt "\nĐang tìm kiếm tất cả Hatch theo mẫu trong Model/Layout...")
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
                          colC (HBD:get-color-info cand))

                    ;; Tieu chi khop CHAT CHE hon de tranh chon nham:
                    ;; 1. Cung Mau sac + cung Pattern (chac chan nhat, bat ke Layer)
                    ;; 2. Cung Layer chuyen dung (khong phai layer chung) + cung Pattern
                    ;; 3. Cung Layer chuyen dung + cung Mau sac
                    ;; -> Da bo dieu kien "chi can cung Layer la nhan" vi gay chon nham
                    ;;    cac hatch khac mau / khac pattern nam tren cung Layer
                    (setq sameLay (= (strcase layC) (strcase layMau))
                          samePat (HBD:pattern-match-p patC patMau)
                          sameCol (HBD:colors-match-p colC colInfoMau)
                          isGenericLay (or (= (strcase layMau) "0")
                                           (= (strcase layMau) "DEFPOINTS")
                                           (= (strcase layMau) "HATCH")))

                    (if (or
                          (and sameCol samePat)
                          (and sameLay (not isGenericLay) samePat)
                          (and sameLay (not isGenericLay) sameCol))
                      (ssadd cand ssSel))

                    (setq idx (1+ idx)))

                  (prompt
                    (strcat "\nTGIRR [HBD]: Đã tìm thấy "
                            (itoa (sslength ssSel))
                            " Hatch phù hợp với mẫu (Layer: \"" layMau
                            "\", Màu: " (HBD:format-color-str colInfoMau) ").")))
                (setq ssSel nil)))
            (prompt "\nĐối tượng được chọn không phải là HATCH.")))

        ;; Tuy chon T: Chon tat ca Hatch trong khong gian hien hanh
        ((= opt "T")
          (prompt "\nĐang tìm tất cả Hatch trong Model/Layout hiện hành...")
          (setq ssSel
            (ssget "_X"
              (list
                '(0 . "HATCH")
                (cons 410 (getvar "CTAB"))))))

        ;; Tuy chon J: Bat/tat che do tu dong hop nhat cac duong bao giap nhau lam 1
        ((= opt "J")
          (setq *HBD:union-bounds* (not *HBD:union-bounds*))
          (prompt
            (strcat
              "\nChế độ hợp nhất Boundary giáp nhau: "
              (if *HBD:union-bounds*
                "[BẬT - Tự động hợp nhất (UNION) các mảng giáp nhau thành 1 đường bao duy nhất]"
                "[TẮT - Để nguyên các đường bao độc lập]")))
          (prompt "\nQuét chọn các Hatch cần tạo đường bao: ")
          (setq ssSel (ssget '((0 . "HATCH")))))

        ;; Tuy chon D: Dao che do chi lay duong bao ngoai hay giu ca dao
        ((= opt "D")
          (setq *HBD:outer-only* (not *HBD:outer-only*))
          (prompt
            (strcat
              "\nChế độ đường bao hiện tại: "
              (if *HBD:outer-only*
                "[CHỈ LẤY BAO NGOÀI - bỏ các lỗ đảo bên trong, giữ các mảng độc lập]"
                "[LẤY TẤT CẢ - giữ cả bao ngoài và lỗ đảo bên trong]")))
          (prompt "\nQuét chọn các Hatch cần tạo đường bao: ")
          (setq ssSel (ssget '((0 . "HATCH")))))

        ;; Tuy chon L: Thay doi Layer dich
        ((= opt "L")
          (setq opt
            (getstring
              (strcat "\nNhập tên Layer đích <" *HBD:target-layer* ">: ")))
          (if (and opt (/= opt ""))
            (setq *HBD:target-layer* (strcase opt)))
          (prompt (strcat "\nLayer đích: " *HBD:target-layer*))
          (prompt "\nQuét chọn các Hatch cần tạo đường bao: ")
          (setq ssSel (ssget '((0 . "HATCH")))))

        ;; Mac dinh: Quet chon truc tiep
        (T
          (prompt "\nQuét chọn các Hatch cỏ cần tạo đường bao: ")
          (setq ssSel (ssget '((0 . "HATCH"))))))))

  ;; Kiem tra ket qua tap chon
  (if (or (not ssSel) (= (sslength ssSel) 0))
    (progn
      (prompt "\nKhông có đối tượng HATCH nào được chọn.")
      (setvar "CMDECHO" oldCmdecho)
      (princ))
    (progn
      ;; Dam bao layer dich ton tai
      (HBD:ensure-layer *HBD:target-layer* 7 "Continuous")

      ;; Bat dau danh dau Undo
      (vla-StartUndoMark doc)
      (setq undoStarted T)
      (setq entInitial (entlast))

      ;; Chuyen tap chon thanh danh sach ename
      (setq hatchList '())
      (setq i 0)
      (while (< i (sslength ssSel))
        (setq hatchList (cons (ssname ssSel i) hatchList))
        (setq i (1+ i)))
      (setq hatchList (reverse hatchList))
      (setq totalHatches (length hatchList))

      ;; Duyet qua tung Hatch de tao Boundary va convert ngay thanh LWPolyline
      (setq allCreated '())
      (foreach hEnt hatchList
        (setq createdEnts (HBD:generate-boundary-single hEnt))
        (if createdEnts
          (setq allCreated (append allCreated createdEnts))))

      ;; Neu nguoi dung bat hop nhat (UNION) va co nhieu hon 1 duong bao
      (if (and *HBD:union-bounds* (> (length allCreated) 1))
        (setq finalBounds (HBD:union-polylines allCreated))
        (setq finalBounds (HBD:clean-all-to-polylines allCreated)))

      ;; Neu chon Outer-only (chi loai bo lo dao khoet ben trong, giu nguyen cac mang co doc lap)
      (if (and *HBD:outer-only* (> (length finalBounds) 1))
        (setq finalBounds (HBD:filter-outer-only finalBounds)))

      ;; Gan Layer dich va mau ByLayer cho cac duong bao sinh ra
      ;; Chi giu 100% LWPOLYLINE / POLYLINE khep kin
      (setq finalBounds (HBD:clean-all-to-polylines finalBounds))
      (setq finalBounds
        (vl-remove-if-not
          '(lambda (e)
             (and (entget e)
                  (member (cdr (assoc 0 (entget e))) '("LWPOLYLINE" "POLYLINE"))))
          finalBounds))

      (setq totalBounds 0)
      (foreach bEnt finalBounds
        (if (and bEnt (entget bEnt))
          (progn
            (setq totalBounds (1+ totalBounds))
            (vl-catch-all-apply
              '(lambda ()
                 (vla-put-Layer (vlax-ename->vla-object bEnt) *HBD:target-layer*)
                 (vla-put-Color (vlax-ename->vla-object bEnt) 256) ; ByLayer
                 (HBD:safe-close bEnt))))))

      ;; Quet don toan bo thuc the tao ra trong suot qua trinh HBD:
      ;; Neu co bat ky REGION hoac SPLINE nao sot lai -> XOA SACH SE
      (if entInitial
        (foreach e (HBD:get-new-entities entInitial)
          (if (and (entget e)
                   (member (cdr (assoc 0 (entget e))) '("REGION" "SPLINE")))
            (vl-catch-all-apply 'entdel (list e)))))

      ;; Ket thuc Undo
      (vla-EndUndoMark doc)
      (setq undoStarted nil)

      (setvar "CMDECHO" oldCmdecho)
      (setvar "OSMODE"  oldOsmode)

      ;; Thong bao ket qua
      (prompt
        (strcat
          "\n======================================================="
          "\nTGIRR [HBD]: Hoàn tất tạo đường bao Polyline cho Hatch!"
          "\n- Số lượng Hatch đã xử lý  : " (itoa totalHatches)
          "\n- Số đường bao Polyline tạo: " (itoa totalBounds)
          "\n- Layer đích               : " *HBD:target-layer*
          "\n- Hợp nhất giáp ranh       : " (if *HBD:union-bounds* "Có (UNION)" "Không")
          "\n- Chế độ bao               : " (if *HBD:outer-only* "Chỉ lấy bao ngoài (bỏ lỗ đảo)" "Giữ cả bao ngoài và đảo")
          "\n- Định dạng kết quả        : 100% LWPOLYLINE (không còn Region/Spline)"
          "\n======================================================="))
      (princ))))

;;; ==========================================================================
;;; LENH JH (JOIN HATCH): Gop cac Hatch phan manh giap nhau thanh 1 Hatch duy nhat
;;; va tao 1 duong bao chung duy nhat tren Layer TG-BOUND
;;; ==========================================================================
(defun c:JH (/ oldCmdecho oldOsmode doc undoStarted entInitial
               ssSel hatchList firstEnt edFirst patName patScale patAngle patLayer patColor
               allBounds created finalBounds polySS hEnt bEnt e)

  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq oldCmdecho (getvar "CMDECHO"))
  (setq oldOsmode   (getvar "OSMODE"))
  (setq undoStarted nil)
  (setq entInitial  nil)

  (defun *error* (msg)
    (if undoStarted
      (progn
        (if entInitial
          (foreach e (HBD:get-new-entities entInitial)
            (if (and (entget e) (member (cdr (assoc 0 (entget e))) '("REGION" "SPLINE")))
              (vl-catch-all-apply 'entdel (list e)))))
        (vl-catch-all-apply 'vla-EndUndoMark (list doc))))
    (if oldCmdecho (setvar "CMDECHO" oldCmdecho))
    (if oldOsmode (setvar "OSMODE"  oldOsmode))
    (if (and msg (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*BREAK*")))
      (prompt (strcat "\nTGIRR JH Lỗi: " msg)))
    (princ))

  (setvar "CMDECHO" 0)

  ;; Kiem tra Pickfirst hoac quet chon
  (setq ssSel (ssget "_I" '((0 . "HATCH"))))
  (if (not ssSel)
    (progn
      (prompt "\nTGIRR [JH]: Quét chọn các đối tượng Hatch cỏ cần gộp làm 1: ")
      (setq ssSel (ssget '((0 . "HATCH"))))))

  (if (or (not ssSel) (< (sslength ssSel) 2))
    (progn
      (prompt "\nCần chọn ít nhất 2 đối tượng HATCH để gộp làm 1.")
      (setvar "CMDECHO" oldCmdecho)
      (princ))
    (progn
      (vla-StartUndoMark doc)
      (setq undoStarted T)
      (setq entInitial (entlast))

      ;; Lay thong tin mau cua Hatch dau tien lam goc
      (setq firstEnt (ssname ssSel 0)
            edFirst  (entget firstEnt)
            patName  (cdr (assoc 2 edFirst))
            patScale (cdr (assoc 41 edFirst))
            patAngle (if (assoc 52 edFirst) (/ (* (cdr (assoc 52 edFirst)) 180.0) pi) 0.0)
            patLayer (cdr (assoc 8 edFirst))
            patColor (cdr (assoc 62 edFirst)))

      (setq hatchList '())
      (setq i 0)
      (while (< i (sslength ssSel))
        (setq hatchList (cons (ssname ssSel i) hatchList))
        (setq i (1+ i)))
      (setq hatchList (reverse hatchList))

      ;; 1. Sinh boundary cho tung Hatch (sach se 100% la Polyline)
      (setq allBounds '())
      (foreach hEnt hatchList
        (setq created (HBD:generate-boundary-single hEnt))
        (if created (setq allBounds (append allBounds created))))

      (if (or (not allBounds) (= (length allBounds) 0))
        (progn
          (prompt "\nKhông sinh được boundary cho các Hatch đã chọn.")
          (vla-EndUndoMark doc)
          (setvar "CMDECHO" oldCmdecho)
          (princ))
        (progn
          ;; 2. Hop nhat cac boundary giap nhau thanh 1 duong bao Polyline chung duy nhat
          (setq finalBounds (HBD:union-polylines allBounds))
          (setq finalBounds (HBD:clean-all-to-polylines finalBounds))
          (setq finalBounds
            (vl-remove-if-not
              '(lambda (e)
                 (and (entget e)
                      (member (cdr (assoc 0 (entget e))) '("LWPOLYLINE" "POLYLINE"))))
              finalBounds))

          ;; 3. Dam bao duong bao thuoc Layer TG-BOUND
          (HBD:ensure-layer *HBD:target-layer* 7 "Continuous")
          (foreach bEnt finalBounds
            (if (and bEnt (entget bEnt))
              (vl-catch-all-apply
                '(lambda ()
                   (vla-put-Layer (vlax-ename->vla-object bEnt) *HBD:target-layer*)
                   (vla-put-Color (vlax-ename->vla-object bEnt) 256)
                   (HBD:safe-close bEnt)))))

          ;; 4. Xoa cac doi tuong Hatch phan manh cu
          (foreach hEnt hatchList
            (if (entget hEnt) (entdel hEnt)))

          ;; 5. Tao 1 doi tuong Hatch moi duy nhat theo duong bao hop nhat
          (setvar "CLAYER" patLayer)
          (setq polySS (ssadd))
          (foreach bEnt finalBounds
            (if (and bEnt (entget bEnt)) (ssadd bEnt polySS)))

          (if (= (strcase patName) "SOLID")
            (vl-cmdf "_.-HATCH" "_P" "SOLID" "_S" polySS "" "")
            (if (and patScale (> patScale 0))
              (vl-cmdf "_.-HATCH" "_P" patName patScale patAngle "_S" polySS "" "")
              (vl-cmdf "_.-HATCH" "_P" patName "_S" polySS "" "")))

          ;; Quet don toan bo Region/Spline rac tao ra trong qua trinh gop
          (if entInitial
            (foreach e (HBD:get-new-entities entInitial)
              (if (and (entget e)
                       (member (cdr (assoc 0 (entget e))) '("REGION" "SPLINE")))
                (vl-catch-all-apply 'entdel (list e)))))

          (vla-EndUndoMark doc)
          (setq undoStarted nil)

          (setvar "CMDECHO" oldCmdecho)
          (setvar "OSMODE"  oldOsmode)

          (prompt
            (strcat
              "\n======================================================="
              "\nTGIRR [JH]: Đã gộp thành công " (itoa (length hatchList)) " Hatch thành 1!"
              "\n- Pattern       : " patName
              "\n- Layer Hatch   : " patLayer
              "\n- Đường bao hợp : " (itoa (length finalBounds)) " Polyline trên Layer '" *HBD:target-layer* "'"
              "\n======================================================="))
          (princ))))))

;;; ==========================================================================
;;; LENH SP2PL / REG2PL / C2PL: Chuyen doi nhanh SPLINE va REGION sang LWPOLYLINE
;;; ==========================================================================
(defun c:SP2PL (/ oldCmdecho doc undoStarted ss i ent eType res count)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq oldCmdecho (getvar "CMDECHO"))
  (setvar "CMDECHO" 0)

  (prompt "\n[SP2PL] Quét chọn các đối tượng SPLINE / REGION cần chuyển đổi sang Polyline: ")
  (setq ss (ssget '((0 . "SPLINE,REGION,ELLIPSE"))))
  (if (not ss)
    (prompt "\nKhông có đối tượng SPLINE hoặc REGION nào được chọn.")
    (progn
      (vla-StartUndoMark doc)
      (setq undoStarted T)
      (setq count 0)
      (setq i 0)
      (while (< i (sslength ss))
        (setq ent (ssname ss i))
        (if (and ent (entget ent))
          (progn
            (setq eType (cdr (assoc 0 (entget ent))))
            (cond
              ((member eType '("SPLINE" "ELLIPSE"))
               (setq res (HBD:spline-to-polyline ent))
               (if res (setq count (1+ count))))
              ((= eType "REGION")
               (setq res (HBD:region-to-polyline ent))
               (if res (setq count (+ count (length res))))))))
        (setq i (1+ i)))
      (vla-EndUndoMark doc)
      (prompt (strcat "\nTGIRR [SP2PL]: Đã chuyển đổi thành công " (itoa count) " đối tượng sang LWPOLYLINE khép kín."))))
  (setvar "CMDECHO" oldCmdecho)
  (princ))

;; Cac lenh tat
(defun c:BH () (c:HBD))
(defun c:TGBOUND () (c:HBD))
(defun c:MH () (c:JH))
(defun c:JOINHATCH () (c:JH))
(defun c:REG2PL () (c:SP2PL))
(defun c:C2PL ()   (c:SP2PL))

(prompt "\nTGIRR CAD LISP: Đã nạp lệnh HBD (Bound hatch), JH (Gộp hatch) và SP2PL (Convert Spline/Region sang Polyline).")
(princ)
