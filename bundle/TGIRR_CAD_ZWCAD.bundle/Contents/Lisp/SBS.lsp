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

  ;; Lay 9 diem mau tren bounding box; chap nhan neu >= 5 diem nam trong bound.
  ;; Day la phep do on dinh de xac dinh doi tuong "nam phan lon trong bound".
  (defun mostly-inside-p (ent poly / obj pmin pmax mn mx x1 x2 xm y1 y2 ym
                              samples count result)
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
          (if (point-in-poly p poly) (setq count (1+ count)))
        )
        (>= count 5)
      )
    )
  )

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

(prompt "\nTGIRR: Da nap lenh SBS.")
(princ)
