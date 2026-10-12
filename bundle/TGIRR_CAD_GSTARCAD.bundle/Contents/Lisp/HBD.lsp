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

;; Dinh nghia tuong thich cho AutoLISP (tranh loi tren mot so nen tang khong co san stringp)
(if (null stringp)
  (defun stringp (x) (= (type x) 'STR)))

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


;; Kiem tra phan mem CAD hien hanh (an toan tuyet doi voi AutoLISP)
(defun HBD:cad-product-str (/ prod prog sProd sProg)
  (setq prod (getvar "PRODUCT")
        prog (getvar "PROGRAM"))
  (setq sProd (if (and prod (= (type prod) 'STR)) prod "")
        sProg (if (and prog (= (type prog) 'STR)) prog ""))
  (strcase (strcat sProd " " sProg)))

(defun HBD:is-gstarcad (/ s)
  (setq s (HBD:cad-product-str))
  (if (or (vl-string-search "GSTARCAD" s)
          (vl-string-search "GCAD"     s))
    T nil))

(defun HBD:is-zwcad (/ s)
  (setq s (HBD:cad-product-str))
  (if (or (vl-string-search "ZWCAD" s)
          (vl-string-search "ZCAD"  s))
    T nil))

(defun HBD:is-autocad (/ s)
  (setq s (HBD:cad-product-str))
  (if (and (vl-string-search "AUTOCAD" s)
           (not (HBD:is-gstarcad))
           (not (HBD:is-zwcad)))
    T nil))

;; Ham truy xuat va thiet lap bien he thong an toan tren moi CAD (tranh loi bien khong ho tro tren GstarCAD/ZWCAD)
(defun HBD:getvar-safe (varName / val)
  (setq val (vl-catch-all-apply 'getvar (list varName)))
  (if (vl-catch-all-error-p val) nil val))

(defun HBD:setvar-safe (varName val / res)
  (if (and varName val)
    (progn
      (setq res (vl-catch-all-apply 'setvar (list varName val)))
      (if (vl-catch-all-error-p res) nil val))
    nil))

;; Ham tao hoac dam bao Layer ton tai voi mau va kieu net chuan
(defun HBD:ensure-layer (layer-name color ltype / lay-tbl)
  (if (not (tblsearch "LAYER" layer-name))
    (progn
      (HBD:setvar-safe "CMDECHO" 0)
      (command "_.-LAYER"
               "_New" layer-name
               "_Color" (itoa color) layer-name
               "_Ltype" ltype layer-name
               "")
    )
    (progn
      ;; Neu layer da ton tai, dam bao Thaw va Unlock de dat CLAYER khong bi loi tren moi CAD
      (HBD:setvar-safe "CMDECHO" 0)
      (command "_.-LAYER"
               "_Thaw" layer-name
               "_Unlock" layer-name
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
                                     nSeg dStep pts d pt newPl dxf result)
  ;; Do not let a bad/proxy curve call escape to AutoCAD's native layer.  On
  ;; AutoCAD 2023 one malformed SPLINE/ELLIPSE can otherwise terminate acad.exe
  ;; with an access violation instead of returning a VL error.
  (setq obj (vl-catch-all-apply 'vlax-ename->vla-object (list ent)))
  (if (or (vl-catch-all-error-p obj)
          (vl-catch-all-error-p (vl-catch-all-apply 'vlax-curve-getEndParam (list obj))))
    nil
    (progn
      (setq result
        (vl-catch-all-apply
      '(lambda ()
      (setq lay      (cdr (assoc 8 (entget ent)))
            col62    (assoc 62 (entget ent))
            col420   (assoc 420 (entget ent))
            pStart   (vlax-curve-getStartPoint obj)
            pEnd     (vlax-curve-getEndPoint obj)
            isClosed (or (equal (vl-catch-all-apply 'vla-get-Closed (list obj)) :vlax-true)
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
      (if (vl-catch-all-error-p result) nil result))))

;; Chuyen 1 duong cong (SPLINE/ELLIPSE) thanh danh sach diem mau 2D
;; (tao polyline tam roi doc dinh, xoa polyline tam - khong de lai rac)
(defun HBD:curve-to-pts (ent / pl pts)
  (setq pl (HBD:spline-to-polyline ent))
  (if (and pl (entget pl))
    (progn
      (setq pts (HBD:get-poly-pts pl))
      (vl-catch-all-apply 'entdel (list pl))
      pts)
    nil))

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
               (not (vl-catch-all-error-p pEnd))
               pStart pEnd)
        (progn
          (setq dist (distance pStart pEnd))
          ;; Dung sai 0.05m (5cm) ~ hai dau da giap nhau -> an toan de dong kin thanh Polygon
          (if (or (< dist 0.05) (= (vla-get-Closed obj) :vlax-true))
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

      ;; 2. Neu van con Line hoac Arc roi (JOIN khong ghep het) -> dung PEDIT Join an toan
      ;;    Chay tren MOI nen tang (ke ca AutoCAD) de tranh tinh trang "polyline khong noi voi arc".
      ;;    PEDITACCEPT=1 giup bo qua cau hoi Convert Lines/Arcs to Polylines.
      (setq resEnts (HBD:get-new-entities lastBefore))
      (if (or (not resEnts)
              (vl-some '(lambda (e) (member (cdr (assoc 0 (entget e))) '("LINE" "ARC"))) resEnts))
        (progn
          (setq oldPedit (HBD:getvar-safe "PEDITACCEPT"))
          (HBD:setvar-safe "PEDITACCEPT" 1)
          (vl-catch-all-apply
            '(lambda ()
               (command "_.PEDIT" "_M" ss "" "_J" 0.05 "")
               (while (wcmatch (getvar "CMDNAMES") "*PEDIT*")
                 (command ""))))
          ;; Fallback cho GstarCAD neu hoi Convert Lines to Polylines [Y/N] (khi PEDITACCEPT chua ho tro)
          (setq resEnts (HBD:get-new-entities lastBefore))
          (if (or (not resEnts)
                  (vl-some '(lambda (e) (member (cdr (assoc 0 (entget e))) '("LINE" "ARC"))) resEnts))
            (vl-catch-all-apply
              '(lambda ()
                 (command "_.PEDIT" "_M" ss "" "_Y" "_J" 0.05 "")
                 (while (wcmatch (getvar "CMDNAMES") "*PEDIT*")
                   (command "")))))
          (if oldPedit (HBD:setvar-safe "PEDITACCEPT" oldPedit))))

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

;; Trich xuat duong bao Polyline/Line/Arc truc tiep tu du lieu DXF cua doi tuong HATCH
;; Khong goi lenh AutoCAD -> An toan 100%, phong ngua triet de loi Access Violation / Crash tren CAD 2025
(defun HBD:extract-dxf-boundary (hatch-ent / ed cur totalLoops outList pType isPoly hasBulge isClosed
                                            numVerts pts bulges i b pl dxf numEdges eType
                                            pStart pEnd pCenter radius angStart angEnd isCcw eLine eArc
                                            pMajor ratio deg rat per numK numC kList cList vlist
                                            dxf38 dxf210 targetLay
                                            revPts revBlg ePts eBlg sPt ePt midPt sweep sw blg k idx n dir
                                            ax ay bx by t0 tt)
  (setq ed (entget hatch-ent))
  (if (and ed (= (cdr (assoc 0 ed)) "HATCH"))
    (progn
      (setq targetLay (if (and *HBD:target-layer* (/= *HBD:target-layer* "")) *HBD:target-layer* "0"))
      (if (not (tblsearch "LAYER" targetLay))
        (HBD:ensure-layer targetLay 7 "Continuous"))
      (setq dxf38  (assoc 38 ed))
      (setq dxf210 (assoc 210 ed))
      (setq cur (member (assoc 91 ed) ed))
      (if cur
        (progn
          (setq totalLoops (cdr (car cur))
                cur (cdr cur)
                outList '())
          (while (and cur (> totalLoops 0))
            ;; Tim den ma 92 (Boundary path type)
            (while (and cur (/= (caar cur) 92))
              (setq cur (cdr cur)))
            (if cur
              (progn
                (setq pType (cdar cur)
                      cur (cdr cur)
                      ;; Bit 2 (value 2) = Polyline flag theo chuan DXF cua AutoCAD
                      isPoly (/= (logand pType 2) 0))
                (if isPoly
                  ;; --- LOOP DANG POLYLINE ---
                  (progn
                    (setq hasBulge nil isClosed 1 numVerts 0)
                    (while (and cur (not (member (caar cur) '(92 75 97 10))))
                      (cond
                        ((= (caar cur) 72) (setq hasBulge (= (cdar cur) 1)))
                        ((= (caar cur) 73) (setq isClosed (cdar cur)))
                        ((= (caar cur) 93) (setq numVerts (cdar cur))))
                      (setq cur (cdr cur)))
                    (setq pts '() bulges '())
                    (while (and cur (> numVerts 0) (or (= (caar cur) 10) (= (caar cur) 42)))
                      (if (= (caar cur) 10)
                        (progn
                          (setq pts (cons (list (cadar cur) (caddar cur)) pts))
                          (setq numVerts (1- numVerts))
                          (setq cur (cdr cur))
                          (if (and cur (= (caar cur) 42))
                            (progn
                              (setq bulges (cons (cdar cur) bulges))
                              (setq cur (cdr cur)))
                            (setq bulges (cons 0.0 bulges))))
                        (setq cur (cdr cur))))
                    (setq pts (reverse pts)
                          bulges (reverse bulges))
                    (if (>= (length pts) 2)
                      (progn
                        (setq vlist '())
                        (setq i 0)
                        (while (< i (length pts))
                          (setq vlist (cons (cons 10 (nth i pts)) vlist))
                          (setq b (nth i bulges))
                          (if (and b (/= b 0.0))
                            (setq vlist (cons (cons 42 b) vlist)))
                          (setq i (1+ i)))
                        (setq dxf
                          (append
                            (list
                              '(0 . "LWPOLYLINE")
                              '(100 . "AcDbEntity")
                              (cons 8 targetLay)
                              '(100 . "AcDbPolyline")
                              (cons 90 (length pts))
                              (cons 70 (if (/= isClosed 0) 1 0)))
                            (if dxf38  (list dxf38)  nil)
                            (if dxf210 (list dxf210) nil)
                            (reverse vlist)))
                        (setq pl (entmakex dxf))
                        (if (not pl)
                          (progn
                            (setq dxf (subst '(8 . "0") (assoc 8 dxf) dxf))
                            (setq pl (entmakex dxf))))
                        (if pl (setq outList (cons pl outList))))))
                  ;; --- LOOP DANG EDGES (LINE, CIRCULAR ARC, ...) ---
                  (progn
                    (setq numEdges 0)
                    (while (and cur (not (member (caar cur) '(92 75 97 72))))
                      (if (= (caar cur) 93) (setq numEdges (cdar cur)))
                      (setq cur (cdr cur)))
                    ;; revPts / revBlg: dinh va bulge cua segment bat dau tai dinh do (luu dang dao)
                    (setq revPts '() revBlg '())
                    (while (and cur (> numEdges 0) (= (caar cur) 72))
                      (setq eType (cdar cur)
                            cur (cdr cur)
                            ePts nil
                            eBlg nil)
                      (cond
                        ;; Line edge
                        ((= eType 1)
                         (setq pStart nil pEnd nil)
                         (if (and cur (= (caar cur) 10)) (setq pStart (cdar cur) cur (cdr cur)))
                         (if (and cur (= (caar cur) 11)) (setq pEnd   (cdar cur) cur (cdr cur)))
                         (if (and pStart pEnd)
                           (progn
                             (setq ePts (list (list (car pStart) (cadr pStart))
                                              (list (car pEnd)   (cadr pEnd))))
                             (setq eBlg (list 0.0 0.0)))))
                        ;; Circular Arc edge -> tinh bulge chinh xac (cung tron nam trong polyline)
                        ((= eType 2)
                         (setq pCenter nil radius nil angStart nil angEnd nil isCcw 1)
                         (if (and cur (= (caar cur) 10)) (setq pCenter (cdar cur) cur (cdr cur)))
                         (if (and cur (= (caar cur) 40)) (setq radius  (cdar cur) cur (cdr cur)))
                         (if (and cur (= (caar cur) 50)) (setq angStart (cdar cur) cur (cdr cur)))
                         (if (and cur (= (caar cur) 51)) (setq angEnd   (cdar cur) cur (cdr cur)))
                         (if (and cur (= (caar cur) 73)) (setq isCcw    (cdar cur) cur (cdr cur)))
                         (if (and pCenter radius (> radius 0.0) angStart angEnd)
                           (progn
                             ;; Goc quet CCW tu dau den cuoi (luon duong), theo co huong 73
                             (setq sweep (if (= isCcw 0) (- angStart angEnd) (- angEnd angStart)))
                             (setq sw (rem sweep (* 2.0 pi)))
                             (if (< sw 0) (setq sw (+ sw (* 2.0 pi))))
                             (if (equal sw 0.0 1e-9) (setq sw (* 2.0 pi)))
                             (setq sPt (polar (list (car pCenter) (cadr pCenter)) angStart radius)
                                   ePt (polar (list (car pCenter) (cadr pCenter)) angEnd   radius))
                             (if (< (- (* 2.0 pi) sw) 1e-6)
                               ;; Gan nhu TRON VONG -> tach thanh 2 nua cung (bulge = 1)
                               (progn
                                 (setq midPt (polar (list (car pCenter) (cadr pCenter))
                                                    (+ angStart pi) radius))
                                 (setq ePts (list (list (car sPt)  (cadr sPt))
                                                  (list (car midPt) (cadr midPt))))
                                 (setq eBlg (list 1.0 1.0)))
                               ;; Cung thong thuong -> 1 segment voi bulge = tan(sweep/4)
                               (progn
                                 ;; AutoLISP khong co ham tan -> dung CVPL:tan neu co, khong thi sin/cos
                                 (setq blg (if (not (vl-catch-all-error-p
                                                      (vl-catch-all-apply 'symbol-function (list 'CVPL:tan))))
                                             (CVPL:tan (/ sw 4.0))
                                             (/ (sin (/ sw 4.0)) (cos (/ sw 4.0)))))
                                 (if (null blg) (setq blg 0.0))
                                 (if (= isCcw 0) (setq blg (- blg)))
                                 (setq ePts (list (list (car sPt) (cadr sPt))
                                                  (list (car ePt) (cadr ePt))))
                                 (setq eBlg (list blg 0.0)))))))
                        ;; Elliptic Arc edge -> sample thanh nhieu dinh (polyline mo phong ellipse)
                        ((= eType 3)
                         (setq pCenter nil pMajor nil ratio nil angStart nil angEnd nil isCcw 1)
                         (if (and cur (= (caar cur) 10)) (setq pCenter (cdar cur) cur (cdr cur)))
                         (if (and cur (= (caar cur) 11)) (setq pMajor  (cdar cur) cur (cdr cur)))
                         (if (and cur (= (caar cur) 40)) (setq ratio   (cdar cur) cur (cdr cur)))
                         (if (and cur (= (caar cur) 50)) (setq angStart (cdar cur) cur (cdr cur)))
                         (if (and cur (= (caar cur) 51)) (setq angEnd   (cdar cur) cur (cdr cur)))
                         (if (and cur (= (caar cur) 73)) (setq isCcw    (cdar cur) cur (cdr cur)))
                         (if (and pCenter pMajor ratio angStart angEnd)
                           (progn
                             (setq sweep (if (= isCcw 0) (- angStart angEnd) (- angEnd angStart)))
                             (setq sw (rem sweep (* 2.0 pi)))
                             (if (< sw 0) (setq sw (+ sw (* 2.0 pi))))
                             (if (equal sw 0.0 1e-9) (setq sw (* 2.0 pi)))
                             (setq dir (if (= isCcw 0) -1.0 1.0))
                             (setq ax (car pMajor) ay (cadr pMajor)
                                   bx (* (- 0.0 ay) ratio)
                                   by (* ax ratio))
                             (setq n (max 8 (min 256 (fix (1+ (/ sw (/ pi 18.0)))))))
                             (setq ePts '() idx 0)
                             (while (<= idx n)
                               (setq tt (+ angStart (* dir sw (/ (float idx) n))))
                               (setq ePts
                                 (cons (list (+ (car pCenter) (* ax (cos tt)) (* bx (sin tt)))
                                             (+ (cadr pCenter) (* ay (cos tt)) (* by (sin tt))))
                                       ePts))
                               (setq idx (1+ idx)))
                             (setq ePts (reverse ePts))
                             (setq eBlg (mapcar '(lambda (x) 0.0) ePts)))))
                        ;; Spline edge -> tao Spline tam roi sample thanh cac dinh
                        ((= eType 4)
                         (setq deg nil rat 0 per 0 numK 0 numC 0 kList '() cList '())
                         (while (and cur (not (member (caar cur) '(72 92 75 97 10 40))))
                           (cond
                             ((= (caar cur) 94) (setq deg (cdar cur)))
                             ((= (caar cur) 73) (setq rat (cdar cur)))
                             ((= (caar cur) 74) (setq per (cdar cur)))
                             ((= (caar cur) 95) (setq numK (cdar cur)))
                             ((= (caar cur) 96) (setq numC (cdar cur))))
                           (setq cur (cdr cur)))
                         (while (and cur (= (caar cur) 40) (> numK 0))
                           (setq kList (cons (cons 40 (cdar cur)) kList)
                                 numK (1- numK)
                                 cur (cdr cur)))
                         (while (and cur (= (caar cur) 10) (> numC 0))
                           (setq cList (cons (cons 10 (cdar cur)) cList)
                                 numC (1- numC)
                                 cur (cdr cur)))
                         (if (and deg (> (length cList) 0))
                           (progn
                             (setq eArc
                               (entmakex
                                 (append
                                   (list
                                     '(0 . "SPLINE")
                                     '(100 . "AcDbEntity")
                                     (cons 8 targetLay)
                                     '(100 . "AcDbSpline")
                                     (cons 70 (+ 1 8 (* 2 per) (* 4 rat)))
                                     (cons 71 (if deg deg 3))
                                     (cons 72 (length kList))
                                     (cons 73 (length cList)))
                                   (reverse kList)
                                   (reverse cList))))
                             (if eArc
                               (progn
                                 (setq ePts (HBD:curve-to-pts eArc))
                                 (if ePts
                                   (setq eBlg (mapcar '(lambda (x) 0.0) ePts))
                                   (vl-catch-all-apply 'entdel (list eArc))))))))
                        ;; Bo qua edge chua ho tro
                        (T
                         (while (and cur (not (member (caar cur) '(72 92 75 97))))
                           (setq cur (cdr cur))))
                      )
                      ;; Noi cac dinh cua edge nay vao danh sach (chong trung dinh dau/cuoi)
                      (setq k 0)
                      (foreach p ePts
                        (setq b (nth k eBlg))
                        (if (not b) (setq b 0.0))
                        (if (and revPts (< (distance p (car revPts)) 1e-4))
                          (if (= k 0)
                            (setq revBlg (cons b (cdr revBlg))))
                          (progn
                            (setq revPts (cons p revPts))
                            (setq revBlg (cons b revBlg))))
                        (setq k (1+ k)))
                      (setq numEdges (1- numEdges)))
                    ;; Tao LWPOLYLINE khep kin tu danh sach dinh (co bulge cho cung tron)
                    (setq pts (reverse revPts)
                          bulges (reverse revBlg))
                    (if (and (> (length pts) 2)
                             (< (distance (car pts) (last pts)) 1e-4))
                      (progn
                        (setq pts (reverse (cdr (reverse pts))))
                        (setq bulges (reverse (cdr (reverse bulges))))))
                    (if (>= (length pts) 2)
                      (progn
                        (setq vlist '() idx 0)
                        (foreach p pts
                          (setq vlist (cons (cons 10 p) vlist))
                          (setq b (nth idx bulges))
                          (if (and b (/= b 0.0))
                            (setq vlist (cons (cons 42 b) vlist)))
                          (setq idx (1+ idx)))
                        (setq dxf
                          (append
                            (list
                              '(0 . "LWPOLYLINE")
                              '(100 . "AcDbEntity")
                              (cons 8 targetLay)
                              '(100 . "AcDbPolyline")
                              (cons 90 (length pts))
                              '(70 . 1))
                            (if dxf38  (list dxf38)  nil)
                            (if dxf210 (list dxf210) nil)
                            (reverse vlist)))
                        (setq pl (entmakex dxf))
                        (if (not pl)
                          (progn
                            (setq dxf (subst '(8 . "0") (assoc 8 dxf) dxf))
                            (setq pl (entmakex dxf))))
                        (if pl (setq outList (cons pl outList)))))
                    ;; Bo qua phan con lai cua loop
                    (while (and cur (not (member (caar cur) '(92 75 97))))
                      (setq cur (cdr cur))))))
              (setq totalLoops (1- totalLoops))))
          ;; NEU KHONG DOC HET SO LOOP -> DU LIEU DXF BI TRUNCATE (VOI HATCH QUA LON / ENTGET BI GIOI HAN)
          ;; -> XOA CAC MANH DA TAO VA TRA VE NIL DE CHAY FALLBACK HATCHGENERATEBOUNDARY
          (if (> totalLoops 0)
            (progn
              (foreach e outList (if e (vl-catch-all-apply 'entdel (list e))))
              (setq outList nil)))
          outList)))))

(defun HBD:generate-boundary-single (hatch-ent / lastEnt created hatchLay layRec layLocked loose polys joined resList ss)
  (if (not (and hatch-ent (entget hatch-ent)
                (= (cdr (assoc 0 (entget hatch-ent))) "HATCH")))
    nil
    (progn
      (setq lastEnt (entlast))
      (setq ss (HBD:ename-to-ss hatch-ent))

      ;; 1. Kiem tra va mo khoa tam thoi Layer cua Hatch neu bi khoa
      (setq hatchLay (cdr (assoc 8 (entget hatch-ent))))
      (setq layRec (if hatchLay (tblsearch "LAYER" hatchLay)))
      (setq layLocked (and layRec (= (logand (cdr (assoc 70 layRec)) 4) 4)))
      (if layLocked
        (vl-catch-all-apply
          '(lambda ()
             (HBD:setvar-safe "CMDECHO" 0)
             (command "_.-LAYER" "_Unlock" hatchLay ""))))

      ;; 2. PHUONG PHAP 1: Trich xuat boundary truc tiep tu du lieu DXF cua Hatch
      ;; Doc du lieu entity truc tiep, KHONG dung lenh command nao
      ;; -> Khong bi phu thuoc phien ban CAD, triet tieu hoan toan loi Fatal Error / Access Violation (0x002a)
      (setq created (HBD:extract-dxf-boundary hatch-ent))

      ;; 3. PHUONG PHAP 2 (FALLBACK TREN GSTARCAD / ZWCAD):
      ;; Tren ZWCAD / GstarCAD, lenh goc HATCHGENERATEBOUNDARY rat on dinh
      (if (and (not created) (not (HBD:is-autocad)))
        (progn
          (vl-catch-all-apply
            '(lambda ()
               (vl-cmdf "_.HATCHGENERATEBOUNDARY" ss "")
               (while (wcmatch (getvar "CMDNAMES") "*HATCH*")
                 (command ""))))
          (setq created (HBD:get-new-entities lastEnt))))

      ;; 4. PHUONG PHAP 3 (FALLBACK TREN AUTOCAD):
      ;; Chi khi DXF khong doc duoc moi thu qua _.-HATCHEDIT (kem Enter "" de ket thuc lenh)
      (if (and (not created) (HBD:is-autocad))
        (progn
          (vl-catch-all-apply
            '(lambda ()
               (command "_.-HATCHEDIT" hatch-ent "_B" "_P" "_N" "")
               (while (wcmatch (getvar "CMDNAMES") "*HATCH*")
                 (command ""))))
          (setq created (HBD:get-new-entities lastEnt))))

      ;; Khoi phuc trang thai khoa layer neu truoc do bi khoa
      (if layLocked
        (vl-catch-all-apply
          '(lambda ()
             (HBD:setvar-safe "CMDECHO" 0)
             (command "_.-LAYER" "_Lock" hatchLay ""))))

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
          ;; Neu van chua co Polyline nao -> thu lai bang join toan bo entity con song sot
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
        nil))))

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
      (setq oldDelobj (HBD:getvar-safe "DELOBJ"))
      (HBD:setvar-safe "DELOBJ" 0)

      ;; 1. Tao Region cho nhom nay
      (vl-catch-all-apply
        '(lambda ()
           (command "_.REGION" ssPoly "")
           (while (wcmatch (getvar "CMDNAMES") "*REGION*")
             (command ""))))

      (if oldDelobj (HBD:setvar-safe "DELOBJ" oldDelobj))

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

;; Lay danh sach toa do dinh cua 1 polyline de kiem tra hinh hoc (ho tro ca LWPOLYLINE va POLYLINE cu)
(defun HBD:get-poly-pts (ent / ed pts eSub edSub)
  (if (and ent (setq ed (entget ent)))
    (cond
      ((= (cdr (assoc 0 ed)) "LWPOLYLINE")
       (setq pts '())
       (foreach x ed
         (if (= (car x) 10)
           (setq pts (cons (list (cadr x) (caddr x)) pts))))
       (reverse pts))
      ((= (cdr (assoc 0 ed)) "POLYLINE")
       (setq pts '() eSub (entnext ent))
       (while (and eSub (setq edSub (entget eSub)) (/= (cdr (assoc 0 edSub)) "SEQEND"))
         (if (= (cdr (assoc 0 edSub)) "VERTEX")
           (setq pts (cons (list (cadr (assoc 10 edSub)) (caddr (assoc 10 edSub))) pts)))
         (setq eSub (entnext eSub)))
       (reverse pts))
      (T nil))
    nil))

;; Kiem tra diem nam trong polygon (ray-casting an toan voi moi loai toa do va kich thuoc tap diem)
(defun HBD:pt-in-poly (pt poly / x y inside j i pi pj xi yi xj yj)
  (if (and pt (listp pt) poly (listp poly) (>= (length poly) 3))
    (progn
      (setq x (car pt) y (cadr pt) inside nil j (1- (length poly)) i 0)
      (while (< i (length poly))
        (setq pi (nth i poly) pj (nth j poly)
              xi (car pi) yi (cadr pi)
              xj (car pj) yj (cadr pj))
        (if (and xi yi xj yj (/= (> yi y) (> yj y))
                 (< x (+ xi (/ (* (- xj xi) (- y yi)) (- yj yi)))))
          (setq inside (not inside)))
        (setq j i i (1+ i)))
      inside)
    nil))

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
               (setq ptB (vl-catch-all-apply 'vlax-curve-getStartPoint (list (vlax-ename->vla-object eB))))
               (if (and (not (vl-catch-all-error-p ptB))
                        ptB
                        (>= (length ptsA) 3)
                        (HBD:pt-in-poly ptB ptsA))
                 (progn
                   (if (entget eB) (vl-catch-all-apply 'entdel (list eB)))
                   T) ; la lo dao cua pA -> xoa khoi ban ve va khoi danh sach
                 nil))
            sorted)))
      (reverse outList))))

;;; ==========================================================================
;;; LENH HBD: Ve duong bao Boundary cho Hatch co
;;; ==========================================================================
;;; LENH HBD: Ve duong bao Boundary cho Hatch co
;;; ==========================================================================
(defun c:HBD (/ oldCmdecho oldOsmode oldClayer oldHp *error* doc undoStarted entInitial
                ssSel preSel selRes optKey hEntClick opt entMau edMau patMau layMau colInfoMau
                ssMau sampleList s matched
                ssCandidates idx cand edC bbMau bbC sameNear loop
                hatchList totalHatches totalBounds i hEnt
                createdEnts allCreated finalBounds e bEnt)

  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq oldCmdecho (HBD:getvar-safe "CMDECHO"))
  (setq oldOsmode  (HBD:getvar-safe "OSMODE"))
  (setq oldClayer  (HBD:getvar-safe "CLAYER"))
  (setq oldHp      (HBD:getvar-safe "HPQUICKPREVIEW"))
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
        (if doc (vl-catch-all-apply 'vla-EndUndoMark (list doc)))))
    (if oldCmdecho (HBD:setvar-safe "CMDECHO" oldCmdecho))
    (if oldOsmode  (HBD:setvar-safe "OSMODE"  oldOsmode))
    (if oldClayer  (HBD:setvar-safe "CLAYER"  oldClayer))
    (if oldHp      (HBD:setvar-safe "HPQUICKPREVIEW" oldHp))
    (if (and msg (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*BREAK*")))
      (prompt (strcat "\nTGIRR HBD Lỗi: " msg)))
    (princ))

  (HBD:setvar-safe "CMDECHO" 0)

  ;; Kiem tra PICKFIRST (doi tuong da chon truoc khi go lenh)
  (setq preSel (ssget "_I" '((0 . "HATCH"))))

  (if preSel
    (progn
      (setq ssSel preSel)
      (sssetfirst nil nil))
    (progn
      ;; Menu lua chon linh hoat: Click truc tiep 1 Hatch, nhap Option M/T/J/D/L, hoac an Enter de quet chon
      (setq loop T)
      (while loop
        (initget 128 "M T J D L m t j d l")
        (setq selRes
          (entsel
            (strcat
              "\n[HBD] Click chọn 1 Hatch hoặc [Mẫu(M) / Tất cả(T) / Hợp nhất("
              (if *HBD:union-bounds* "Bật" "Tắt")
              "-J) / Đảo("
              (if *HBD:outer-only* "Chỉ ngoài" "Cả đảo")
              "-D) / Layer(L)] <Enter để quét chọn>: ")))

        (setq optKey (if (= (type selRes) 'STR) (strcase (vl-string-trim " " selRes)) nil))
        (cond
          ;; 1. Nguoi dung click chuot truc tiep vao 1 Hatch
          ((and selRes (listp selRes))
            (setq hEntClick (car selRes))
            (if (and hEntClick (entget hEntClick) (= (cdr (assoc 0 (entget hEntClick))) "HATCH"))
              (progn
                (setq ssSel (HBD:ename-to-ss hEntClick))
                (setq loop nil))
              (prompt "\nĐối tượng click chọn không phải là HATCH. Vui lòng click lại hoặc ấn Enter để quét chọn.")))

          ;; 2. An Enter (selRes = nil) -> Quet chon binh thuong
          ((null selRes)
            (prompt "\nQuét chọn các Hatch cỏ cần tạo đường bao: ")
            (setq ssSel (ssget '((0 . "HATCH"))))
            (setq loop nil))

          ;; 3. Tuy chon J: Bat/tat hop nhat
          ((= optKey "J")
            (setq *HBD:union-bounds* (not *HBD:union-bounds*))
            (prompt
              (strcat
                "\n-> Hợp nhất Boundary giáp ranh: "
                (if *HBD:union-bounds*
                  "[BẬT - Tự động UNION các mảng giáp nhau thành 1 đường bao duy nhất]"
                  "[TẮT - Giữ nguyên các đường bao độc lập]"))))

          ;; 4. Tuy chon D: Dao che do chi lay duong bao ngoai hay giu ca dao
          ((= optKey "D")
            (setq *HBD:outer-only* (not *HBD:outer-only*))
            (prompt
              (strcat
                "\n-> Chế độ đường bao: "
                (if *HBD:outer-only*
                  "[CHỈ LẤY BAO NGOÀI - bỏ các lỗ đảo bên trong]"
                  "[LẤY TẤT CẢ - giữ cả bao ngoài và lỗ đảo bên trong]"))))

          ;; 5. Tuy chon L: Thay doi Layer dich
          ((= optKey "L")
            (setq opt
              (getstring
                (strcat "\nNhập tên Layer đích <" *HBD:target-layer* ">: ")))
            (if (and opt (/= (vl-string-trim " " opt) ""))
              (setq *HBD:target-layer* (strcase (vl-string-trim " " opt))))
            (prompt (strcat "\n-> Layer đích: " *HBD:target-layer*)))

          ;; 6. Tuy chon M: Chon theo hatch mau (Layer, Pattern va Mau sac)
          ;;    Cho phep CLICK 1 hatch hoac QUET CHON (window/crossing) NHIEU hatch mau.
          ;;    Dung ssget thay cho entsel vi entsel KHONG ho tro quet chon nhieu doi tuong.
          ((= optKey "M")
            (prompt "\nChọn Hatch mẫu (click 1 cái hoặc quét chọn NHIỀU mẫu): ")
            (setq ssMau (ssget '((0 . "HATCH"))))
            (if ssMau
              (progn
                ;; Thu thap thong tin tat ca hatch mau: (ent lay pat colInfo bb)
                (setq sampleList '()
                      idx 0)
                (while (< idx (sslength ssMau))
                  (setq entMau (ssname ssMau idx)
                        edMau  (entget entMau))
                  (setq sampleList
                    (cons (list entMau
                                (cdr (assoc 8 edMau))
                                (cdr (assoc 2 edMau))
                                (HBD:get-color-info entMau)
                                (HBD:get-bbox entMau))
                          sampleList))
                  (setq idx (1+ idx)))
                (setq sampleList (reverse sampleList))
                (prompt
                  (strcat "\nĐã chọn " (itoa (length sampleList))
                          " Hatch mẫu. Quét chọn vùng tìm Hatch cỏ theo mẫu (Enter để tìm toàn bộ bản vẽ): "))
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

                (setq ssSel (ssadd))
                ;; Luon giu lai tat ca hatch mau da chon
                (foreach s sampleList
                  (if (and (car s) (entget (car s)))
                    (ssadd (car s) ssSel)))

                (if ssCandidates
                  (progn
                    (setq idx 0)
                    (while (< idx (sslength ssCandidates))
                      (setq cand (ssname ssCandidates idx)
                            edC  (entget cand)
                            layC (cdr (assoc 8 edC))
                            patC (cdr (assoc 2 edC))
                            colC (HBD:get-color-info cand)
                            bbC  (HBD:get-bbox cand)
                            matched nil)
                      ;; So khop voi BAT KY hatch mau nao da chon
                      (foreach s sampleList
                        (if (not matched)
                          (progn
                            (setq layMau     (cadr s)
                                  patMau     (caddr s)
                                  colInfoMau (cadddr s)
                                  bbMau      (nth 4 s)
                                  sameLay (= (strcase layC) (strcase layMau))
                                  samePat (HBD:pattern-match-p patC patMau)
                                  sameCol (HBD:colors-match-p colC colInfoMau)
                                  sameNear (and sameCol bbMau bbC
                                                 (HBD:bbox-overlap-p bbMau bbC))
                                  isGenericLay (or (= (strcase layMau) "0")
                                                   (= (strcase layMau) "DEFPOINTS")
                                                   (= (strcase layMau) "HATCH")))
                            (if (or
                                  (and sameCol samePat)
                                  sameNear
                                  (and sameLay (not isGenericLay) samePat)
                                  (and sameLay (not isGenericLay) sameCol))
                              (setq matched T)))))
                      (if matched (ssadd cand ssSel))
                      (setq idx (1+ idx)))))

                (prompt
                  (strcat "\nTGIRR [HBD]: Đã chọn " (itoa (sslength ssSel))
                          " Hatch phù hợp với " (itoa (length sampleList)) " mẫu."))
                (setq loop nil))
              (prompt "\nChưa chọn Hatch mẫu nào.")))

          ;; 7. Tuy chon T: Chon tat ca Hatch trong khong gian hien hanh
          ((= optKey "T")
            (prompt "\nĐang tìm tất cả Hatch trong Model/Layout hiện hành...")
            (setq ssSel
              (ssget "_X"
                (list
                  '(0 . "HATCH")
                  (cons 410 (getvar "CTAB")))))
            (setq loop nil))

          ;; 8. Bat ky gia tri nao khac (nhap chu hoac click vung trong do bit 128)
          (T
            (prompt "\nQuét chọn các Hatch cỏ cần tạo đường bao: ")
            (setq ssSel (ssget '((0 . "HATCH"))))
            (setq loop nil))))))

  ;; Kiem tra ket qua tap chon
  (if (or (not ssSel) (= (sslength ssSel) 0))
    (progn
      (prompt "\nKhông có đối tượng HATCH nào được chọn.")
      (if oldCmdecho (HBD:setvar-safe "CMDECHO" oldCmdecho))
      (princ))
    (progn
      ;; Dam bao layer dich ton tai va tam dat lam CLAYER
      (HBD:ensure-layer *HBD:target-layer* 7 "Continuous")
      (HBD:setvar-safe "CLAYER" *HBD:target-layer*)
      (if oldHp (HBD:setvar-safe "HPQUICKPREVIEW" 0))

      ;; Bat dau danh dau Undo
      (if doc (vl-catch-all-apply 'vla-StartUndoMark (list doc)))
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
      (if doc (vl-catch-all-apply 'vla-EndUndoMark (list doc)))
      (setq undoStarted nil)

      (if oldClayer  (HBD:setvar-safe "CLAYER"  oldClayer))
      (if oldHp      (HBD:setvar-safe "HPQUICKPREVIEW" oldHp))
      (if oldCmdecho (HBD:setvar-safe "CMDECHO" oldCmdecho))
      (if oldOsmode  (HBD:setvar-safe "OSMODE"  oldOsmode))

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
(defun c:JH (/ oldCmdecho oldOsmode oldClayer oldHp doc undoStarted entInitial
               ssSel hatchList firstEnt edFirst patName patScale patAngle patLayer patColor
               allBounds created finalBounds polySS hEnt bEnt e hScale hAngle newHatch)

  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq oldCmdecho (HBD:getvar-safe "CMDECHO"))
  (setq oldOsmode  (HBD:getvar-safe "OSMODE"))
  (setq oldClayer  (HBD:getvar-safe "CLAYER"))
  (setq oldHp      (HBD:getvar-safe "HPQUICKPREVIEW"))
  (setq undoStarted nil)
  (setq entInitial  nil)

  (defun *error* (msg)
    (if undoStarted
      (progn
        (if entInitial
          (foreach e (HBD:get-new-entities entInitial)
            (if (and (entget e) (member (cdr (assoc 0 (entget e))) '("REGION" "SPLINE")))
              (vl-catch-all-apply 'entdel (list e)))))
        (if doc (vl-catch-all-apply 'vla-EndUndoMark (list doc)))))
    (if oldCmdecho (HBD:setvar-safe "CMDECHO" oldCmdecho))
    (if oldOsmode  (HBD:setvar-safe "OSMODE"  oldOsmode))
    (if oldClayer  (HBD:setvar-safe "CLAYER"  oldClayer))
    (if oldHp      (HBD:setvar-safe "HPQUICKPREVIEW" oldHp))
    (if (and msg (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*BREAK*")))
      (prompt (strcat "\nTGIRR JH Lỗi: " msg)))
    (princ))

  (HBD:setvar-safe "CMDECHO" 0)

  ;; Kiem tra Pickfirst hoac quet chon
  (setq ssSel (ssget "_I" '((0 . "HATCH"))))
  (if (not ssSel)
    (progn
      (prompt "\nTGIRR [JH]: Quét chọn các đối tượng Hatch cỏ cần gộp làm 1: ")
      (setq ssSel (ssget '((0 . "HATCH"))))))

  (if (or (not ssSel) (< (sslength ssSel) 2))
    (progn
      (prompt "\nCần chọn ít nhất 2 đối tượng HATCH để gộp làm 1.")
      (if oldCmdecho (HBD:setvar-safe "CMDECHO" oldCmdecho))
      (princ))
    (progn
      (if doc (vl-catch-all-apply 'vla-StartUndoMark (list doc)))
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
          (if doc (vl-catch-all-apply 'vla-EndUndoMark (list doc)))
          (setq undoStarted nil)
          (if oldClayer  (HBD:setvar-safe "CLAYER"  oldClayer))
          (if oldHp      (HBD:setvar-safe "HPQUICKPREVIEW" oldHp))
          (if oldCmdecho (HBD:setvar-safe "CMDECHO" oldCmdecho))
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
          (HBD:setvar-safe "CLAYER" patLayer)
          (setq polySS (ssadd))
          (foreach bEnt finalBounds
            (if (and bEnt (entget bEnt)) (ssadd bEnt polySS)))

          (if (= (strcase patName) "SOLID")
            (if (not (vl-cmdf "_.-HATCH" "_P" "SOLID" "_S" polySS "" ""))
              (command "_.-HATCH" "_P" "SOLID" "_S" polySS "" ""))
            (progn
              (setq hScale (if (and patScale (> patScale 0)) patScale 1.0)
                    hAngle (if patAngle patAngle 0.0))
              (if (not (vl-cmdf "_.-HATCH" "_P" patName hScale hAngle "_S" polySS "" ""))
                (command "_.-HATCH" "_P" patName hScale hAngle "_S" polySS "" ""))))

          ;; Giu nguyen mau sac cu neu khong phai ByLayer
          (if (and patColor (/= patColor 256))
            (vl-catch-all-apply
              '(lambda ()
                 (setq newHatch (entlast))
                 (if (and newHatch (entget newHatch))
                   (vla-put-Color (vlax-ename->vla-object newHatch) patColor)))))

          ;; Quet don toan bo Region/Spline rac tao ra trong qua trinh gop
          (if entInitial
            (foreach e (HBD:get-new-entities entInitial)
              (if (and (entget e)
                       (member (cdr (assoc 0 (entget e))) '("REGION" "SPLINE")))
                (vl-catch-all-apply 'entdel (list e)))))

          (if doc (vl-catch-all-apply 'vla-EndUndoMark (list doc)))
          (setq undoStarted nil)

          (if oldClayer  (HBD:setvar-safe "CLAYER"  oldClayer))
          (if oldHp      (HBD:setvar-safe "HPQUICKPREVIEW" oldHp))
          (if oldCmdecho (HBD:setvar-safe "CMDECHO" oldCmdecho))
          (if oldOsmode  (HBD:setvar-safe "OSMODE"  oldOsmode))

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
  (setq oldCmdecho (HBD:getvar-safe "CMDECHO"))
  (HBD:setvar-safe "CMDECHO" 0)

  (prompt "\n[SP2PL] Quét chọn các đối tượng SPLINE / REGION cần chuyển đổi sang Polyline: ")
  (setq ss (ssget '((0 . "SPLINE,REGION,ELLIPSE"))))
  (if (not ss)
    (prompt "\nKhông có đối tượng SPLINE hoặc REGION nào được chọn.")
    (progn
      (if doc (vl-catch-all-apply 'vla-StartUndoMark (list doc)))
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
      (if doc (vl-catch-all-apply 'vla-EndUndoMark (list doc)))
      (prompt (strcat "\nTGIRR [SP2PL]: Đã chuyển đổi thành công " (itoa count) " đối tượng sang LWPOLYLINE khép kín."))))
  (if oldCmdecho (HBD:setvar-safe "CMDECHO" oldCmdecho))
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
