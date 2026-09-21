;;; TGIRR CAD LISP - LENH SBS DA DUOC CUNG CAP
(vl-load-com)

(defun c:SBS (/ entBound entMau edBound edMau typ pts ssAll ssNew i e ed
                mauType mauLayer mauColor mauLtype mauName)

  (vl-load-com)

  ;; Ham lay dinh cua polyline
  (defun get-poly-points (ent / ed pts en)
    (setq ed (entget ent))
    (cond
      ((= (cdr (assoc 0 ed)) "LWPOLYLINE")
        (setq pts '())
        (foreach x ed
          (if (= (car x) 10)
            (setq pts (append pts (list (cdr x))))
          )
        )
        pts
      )

      ((= (cdr (assoc 0 ed)) "POLYLINE")
        (setq pts '())
        (setq en (entnext ent))
        (while (/= (cdr (assoc 0 (entget en))) "SEQEND")
          (if (= (cdr (assoc 0 (entget en))) "VERTEX")
            (setq pts (append pts (list (cdr (assoc 10 (entget en))))))
          )
          (setq en (entnext en))
        )
        pts
      )

      (T nil)
    )
  )

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
        (setq inside (not inside))
      )
      (setq j i i (1+ i))
    )
    inside
  )

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
  ;; TEXT/MTEXT dung ham kiem tra theo chu thuc te de tranh o trong (Width)
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

  ;; Chon boundary
  (prompt "\nChon vung bound bang Polyline kin: ")
  (setq entBound (car (entsel)))

  (if (not entBound)
    (progn
      (prompt "\nChua chon boundary.")
      (princ)
      (exit)
    )
  )

  (setq pts (get-poly-points entBound))

  (if (not pts)
    (progn
      (prompt "\nBoundary phai la Polyline kin hoac Rectangle ve bang Polyline.")
      (princ)
      (exit)
    )
  )

  ;; Chon doi tuong mau
  (prompt "\nChon 1 doi tuong mau de loc cung thuoc tinh: ")
  (setq entMau (car (entsel)))

  (if (not entMau)
    (progn
      (prompt "\nChua chon doi tuong mau.")
      (princ)
      (exit)
    )
  )

  ;; Lay thuoc tinh doi tuong mau
  (setq edMau    (entget entMau))
  (setq mauType  (cdr (assoc 0 edMau)))
  (setq mauLayer (cdr (assoc 8 edMau)))
  (setq mauColor (cdr (assoc 62 edMau)))
  (setq mauLtype (cdr (assoc 6 edMau)))
  (setq mauName  (cdr (assoc 2 edMau))) ; ten block / style / hatch pattern neu co

  ;; Lay ca doi tuong nam trong va cat qua boundary.
  ;; Sau do chi giu doi tuong co phan lon hinh hoc nam trong bound.
  (setq ssAll (ssget "_CP" pts))

  (if ssAll
    (progn
      (setq ssNew (ssadd))
      (setq i 0)

      (while (< i (sslength ssAll))
        (setq e  (ssname ssAll i))
        (setq ed (entget e))

        ;; Loc cung thuoc tinh:
        ;; - cung loai doi tuong
        ;; - cung layer
        ;; - cung color neu co
        ;; - cung linetype neu co
        ;; - neu la block thi cung ten block
        (if
          (and
            (/= e entBound)
            (= (cdr (assoc 0 ed)) mauType)
            (= (cdr (assoc 8 ed)) mauLayer)

            ;; Neu mau co color rieng thi so sanh color
            ;; Neu khong co color 62, tuc ByLayer, thi cung ByLayer
            (= (cdr (assoc 62 ed)) mauColor)

            ;; Neu mau co linetype rieng thi so sanh linetype
            (= (cdr (assoc 6 ed)) mauLtype)

            ;; Doi tuong duoc phep de len boundary nhung phai nam phan lon trong bound
            (mostly-inside-p e pts)

            ;; Neu la INSERT/block thi so sanh ten block
            (if (= mauType "INSERT")
              (= (cdr (assoc 2 ed)) mauName)
              T
            )
          )
          (ssadd e ssNew)
        )

        (setq i (1+ i))
      )

      (if (> (sslength ssNew) 0)
        (progn
          (sssetfirst nil ssNew)
          (prompt
            (strcat
              "\nDa select "
              (itoa (sslength ssNew))
              " doi tuong cung thuoc tinh, nam phan lon trong bound."
            )
          )
        )
        (prompt "\nKhong tim thay doi tuong nao cung thuoc tinh trong bound.")
      )
    )
    (prompt "\nKhong co doi tuong nao trong bound.")
  )

  (princ)
)

;;; -------------------------------------------------------------
;;; TGIRR CAD LISP - LENH SBSE (SELECT BY SAMPLE EXACT)
;;; Loc doi tuong nam phan lon trong polyline kin, giong mau chinh xac
;;; dac biet TEXT / MTEXT bat buoc trung noi dung chu, INSERT trung EffectiveName
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

(defun c:SBSE (/ entBound entMau edMau mauType mauLayer mauColor mauLtype mauName
                 mauText mauCleanText mauBlock pts ssAll ssNew i e ed eType matchExact
                 get-poly-pts pt-in-poly mostly-in-p eTxt)
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
  ;; TEXT/MTEXT dung ham rieng tranh o trong Width.
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

  ;; 1. Chon boundary
  (prompt "\n[SBSE] Chon vung bound bang Polyline kin: ")
  (setq entBound (car (entsel)))
  (if (not entBound)
    (prompt "\n[SBSE] Chua chon boundary.")
    (progn
      (setq pts (get-poly-pts entBound))
      (if (not pts)
        (prompt "\n[SBSE] Boundary phai la Polyline kin hoac Rectangle ve bang Polyline.")
        (progn
          ;; 2. Chon doi tuong mau
          (prompt "\n[SBSE] Chon 1 doi tuong mau de loc CHINH XAC (trung noi dung text / block): ")
          (setq entMau (car (entsel)))
          (if (not entMau)
            (prompt "\n[SBSE] Chua chon doi tuong mau.")
            (progn
              ;; 3. Lay thuoc tinh doi tuong mau
              (setq edMau    (entget entMau))
              (setq mauType  (cdr (assoc 0 edMau)))
              (setq mauLayer (cdr (assoc 8 edMau)))
              (setq mauColor (cdr (assoc 62 edMau)))
              (setq mauLtype (cdr (assoc 6 edMau)))
              (setq mauName  (cdr (assoc 2 edMau)))

              ;; Neu mau la TEXT / MTEXT -> trich xuat noi dung chu
              (if (vl-position mauType '("TEXT" "MTEXT"))
                (progn
                  (setq mauText (tgirr:get-text entMau))
                  (setq mauCleanText (tgirr:clean-text mauText))))

              ;; Neu mau la INSERT (Block) -> lay ten chuan (Dynamic Block)
              (if (= mauType "INSERT")
                (setq mauBlock (tgirr:get-block-name entMau)))

              ;; 4. Quet doi tuong trong boundary
              (setq ssAll (ssget "_CP" pts))
              (if ssAll
                (progn
                  (setq ssNew (ssadd))
                  (setq i 0)

                  (while (< i (sslength ssAll))
                    (setq e  (ssname ssAll i))
                    (setq ed (entget e))
                    (setq eType (cdr (assoc 0 ed)))

                    ;; Kiem tra cac tieu chi co ban: khac bound, cung layer, cung mau, cung linetype, nam trong bound
                    (if
                      (and
                        (/= e entBound)
                        (= (cdr (assoc 8 ed)) mauLayer)
                        (= (cdr (assoc 62 ed)) mauColor)
                        (= (cdr (assoc 6 ed)) mauLtype)
                        (mostly-in-p e pts))
                      (progn
                        (setq matchExact nil)

                        (cond
                          ;; TH1: Mau la TEXT hoac MTEXT -> bat buoc cung la TEXT/MTEXT va TRUNG NOI DUNG CHU
                          ((vl-position mauType '("TEXT" "MTEXT"))
                           (if (vl-position eType '("TEXT" "MTEXT"))
                             (progn
                               (setq eTxt (tgirr:get-text e))
                               (if (or (= mauText eTxt)
                                       (= mauCleanText (tgirr:clean-text eTxt)))
                                 (setq matchExact T)))))

                          ;; TH2: Mau la Block (INSERT) -> phai trung ten block (ke ca Dynamic Block)
                          ((= mauType "INSERT")
                           (if (= eType "INSERT")
                             (if (= mauBlock (tgirr:get-block-name e))
                               (setq matchExact T))))

                          ;; TH3: Mau la HATCH -> phai trung pattern, scale va goc xoay
                          ((= mauType "HATCH")
                           (if (= eType "HATCH")
                             (if (and (= (cdr (assoc 2 ed)) (cdr (assoc 2 edMau)))
                                      (equal (cdr (assoc 41 ed)) (cdr (assoc 41 edMau)) 1e-4)
                                      (equal (cdr (assoc 52 ed)) (cdr (assoc 52 edMau)) 1e-4))
                               (setq matchExact T))))

                          ;; TH4: Mau la CIRCLE hoac ARC -> phai trung ban kinh
                          ((vl-position mauType '("CIRCLE" "ARC"))
                           (if (= eType mauType)
                             (if (equal (cdr (assoc 40 ed)) (cdr (assoc 40 edMau)) 1e-4)
                               (setq matchExact T))))

                          ;; TH5: Mau la DIMENSION -> phai trung DimStyle
                          ((= mauType "DIMENSION")
                           (if (= eType "DIMENSION")
                             (if (= (cdr (assoc 3 ed)) (cdr (assoc 3 edMau)))
                               (setq matchExact T))))

                          ;; Mac dinh (LINE, LWPOLYLINE, SPLINE,...): phai cung loai doi tuong
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
                          "\n[SBSE] Da chon "
                          (itoa (sslength ssNew))
                          " doi tuong trung khop chinh xac theo mau trong bound.")))
                    (prompt "\n[SBSE] Khong tim thay doi tuong nao trung khop chinh xac trong bound.")))
                (prompt "\n[SBSE] Khong co doi tuong nao trong bound.")))))))))

  (princ)
)

(prompt "\nTGIRR: Da nap lenh SBS va SBSE.")
(princ)
