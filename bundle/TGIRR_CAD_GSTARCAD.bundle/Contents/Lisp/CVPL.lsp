;;; ==========================================================================
;;; TGIRR CAD LISP - LENH CVPL / CVP (convert + xoa nguon) va CVPLG / CV2PL (giu nguon)
;;; Chuyen doi: LINE, ARC, CIRCLE, ELLIPSE, SPLINE, POLYLINE (2D/3D kieu cu),
;;;              REGION  ->  LWPOLYLINE
;;; - ARC / CIRCLE duoc chuyen CHINH XAC bang bulge (khong roi rac hoa).
;;; - ELLIPSE / SPLINE duoc roi rac hoa theo so diem mau (mac dinh 128).
;;; - POLYLINE kieu cu (2D/3D) duoc doc dinh + bulge va dung lai thanh LWPOLYLINE.
;;; - REGION dung ham HBD:region-to-polyline neu HBD.lsp da nap (luon nap qua loader).
;;; - Bao toan Layer / Mau / Kieu net / Net ve / Linetype scale cua doi tuong nguon.
;;; - Ho tro UNDO 1 buoc (undo mark).
;;; ==========================================================================
(vl-load-com)

(if (not *CVPL:samples*) (setq *CVPL:samples* 128))

;;; Kiem tra 1 ham (symbol) co ton tai khong (de dung ham cua HBD.lsp neu co)
(defun CVPL:has (sym)
  (not (vl-catch-all-error-p (vl-catch-all-apply 'symbol-function (list sym)))))

;;; --------------------------------------------------------------------------
;;; Dung LWPOLYLINE tu danh sach dinh ((x y) ...) + danh sach bulge
;;; --------------------------------------------------------------------------
(defun CVPL:make-lwpoly (pts bulges closed srcEnt elev / ed data i p)
  (setq ed (entget srcEnt))
  (setq data (list (cons 0 "LWPOLYLINE") (cons 100 "AcDbEntity")))
  (foreach g '(8 6 62 370 48)
    (if (assoc g ed) (setq data (append data (list (assoc g ed))))))
  (setq data (append data (list (cons 100 "AcDbPolyline")
                                (cons 90 (length pts))
                                (cons 70 (if closed 1 0))
                                (cons 43 0.0))))
  (if elev (setq data (append data (list (cons 38 elev)))))
  (setq i 0)
  (foreach p pts
    (setq data (append data (list (cons 10 (list (car p) (cadr p)))
                                  (cons 42 (if (nth i bulges) (nth i bulges) 0.0)))))
    (setq i (1+ i)))
  (entmake data))

;;; --------------------------------------------------------------------------
;;; LINE -> LWPOLYLINE 2 dinh
;;; --------------------------------------------------------------------------
(defun CVPL:line-to-lwp (ent / ed p1 p2)
  (setq ed (entget ent))
  (setq p1 (cdr (assoc 10 ed)) p2 (cdr (assoc 11 ed)))
  (CVPL:make-lwpoly (list (list (car p1) (cadr p1)) (list (car p2) (cadr p2)))
                    '(0.0 0.0) nil ent (cdr (assoc 38 ed))))

;;; --------------------------------------------------------------------------
;;; ARC -> LWPOLYLINE 1 doan bulge (chinh xac)
;;; --------------------------------------------------------------------------
(defun CVPL:arc-to-lwp (ent / ed c r sa ea bulge p1 p2 elev)
  (setq ed (entget ent))
  (setq c (cdr (assoc 10 ed)) r (cdr (assoc 40 ed))
        sa (cdr (assoc 50 ed)) ea (cdr (assoc 51 ed))
        elev (cdr (assoc 38 ed)))
  (if (< ea sa) (setq ea (+ ea (* 2.0 pi))))
  (setq bulge (tan (/ (- ea sa) 4.0)))
  (setq p1 (list (+ (car c) (* r (cos sa))) (+ (cadr c) (* r (sin sa))))
        p2 (list (+ (car c) (* r (cos ea))) (+ (cadr c) (* r (sin ea)))))
  (CVPL:make-lwpoly (list p1 p2) (list bulge 0.0) nil ent elev))

;;; --------------------------------------------------------------------------
;;; CIRCLE -> LWPOLYLINE 4 doan bulge (chinh xac)
;;; --------------------------------------------------------------------------
(defun CVPL:circle-to-lwp (ent / ed c r b p0 p1 p2 p3 elev)
  (setq ed (entget ent))
  (setq c (cdr (assoc 10 ed)) r (cdr (assoc 40 ed)) elev (cdr (assoc 38 ed)))
  (setq b (tan (/ pi 8.0)))
  (setq p0 (list (+ (car c) r) (cadr c))
        p1 (list (car c) (+ (cadr c) r))
        p2 (list (- (car c) r) (cadr c))
        p3 (list (car c) (- (cadr c) r)))
  (CVPL:make-lwpoly (list p0 p1 p2 p3) (list b b b b) T ent elev))

;;; --------------------------------------------------------------------------
;;; ELLIPSE / SPLINE -> roi rac hoa thanh LWPOLYLINE
;;; --------------------------------------------------------------------------
(defun CVPL:sample-to-lwp (ent n / ed u0 u1 pts i u p closed d elev)
  (setq ed (entget ent))
  (setq u0 (vlax-curve-getStartParam ent) u1 (vlax-curve-getEndParam ent))
  (setq closed nil)
  (setq p (vlax-curve-getPointAtParam ent u0))
  (setq d (distance p (vlax-curve-getPointAtParam ent u1)))
  (if (< d 1e-7) (setq closed T))
  (setq pts nil i 0)
  (while (<= i n)
    (setq u (+ u0 (* (- u1 u0) (/ (float i) (float n)))))
    (setq p (vlax-curve-getPointAtParam ent u))
    (setq pts (cons (list (car p) (cadr p)) pts))
    (setq i (1+ i)))
  (setq pts (reverse pts))
  (if closed
    (progn
      ;; `last` trả về danh sách chứa phần tử cuối, không phải chính điểm cuối.
      ;; Lấy `car` để tránh truyền cấu trúc lồng vào `distance` (đặc biệt với
      ;; ELLIPSE/SPLINE khép kín, nơi nhánh này luôn được thực thi).
      (setq d (distance (car pts) (car (last pts))))
      (if (< d 1e-7) (setq pts (reverse (cdr (reverse pts)))))))
  (if (< (length pts) 2)
    nil
    (CVPL:make-lwpoly pts (mapcar '(lambda (x) 0.0) pts) closed ent (cdr (assoc 38 ed)))))

;;; --------------------------------------------------------------------------
;;; POLYLINE kieu cu (2D/3D) -> LWPOLYLINE (doc dinh + bulge qua VERTEX)
;;; --------------------------------------------------------------------------
(defun CVPL:oldpoly-to-lwp (ent / ed v ve pts bulges closed p b elev)
  (setq ed (entget ent))
  (setq closed (= 1 (logand (cdr (assoc 70 ed)) 1)))
  (setq elev (cdr (assoc 30 ed)))
  (setq v (entnext ent) pts nil bulges nil)
  (while (and v (setq ve (entget v)) (= "VERTEX" (cdr (assoc 0 ve))))
    (setq p (cdr (assoc 10 ve)))
    (setq b (cdr (assoc 42 ve)))
    (setq pts (cons (list (car p) (cadr p)) pts))
    (setq bulges (cons (if b b 0.0) bulges))
    (setq v (entnext v)))
  (setq pts (reverse pts) bulges (reverse bulges))
  (if (< (length pts) 2)
    nil
    (CVPL:make-lwpoly pts bulges closed ent elev)))

;;; --------------------------------------------------------------------------
;;; Xu ly 1 doi tuong; tra ve so polyline tao duoc (0 = bo qua)
;;; --------------------------------------------------------------------------
(defun CVPL:convert-one (ent keep / eType res newEnts made)
  (setq eType (cdr (assoc 0 (entget ent))))
  (setq made 0)
  (cond
    ((= eType "LINE")
     (setq res (CVPL:line-to-lwp ent)) (if res (setq made 1)))
    ((= eType "ARC")
     (setq res (CVPL:arc-to-lwp ent)) (if res (setq made 1)))
    ((= eType "CIRCLE")
     (setq res (CVPL:circle-to-lwp ent)) (if res (setq made 1)))
    ((member eType '("ELLIPSE" "SPLINE"))
     (setq res (CVPL:sample-to-lwp ent *CVPL:samples*)) (if res (setq made 1)))
    ((= eType "POLYLINE")
     (setq res (CVPL:oldpoly-to-lwp ent)) (if res (setq made 1)))
    ((= eType "LWPOLYLINE")
     nil) ; da la polyline
    ((= eType "REGION")
     (if (CVPL:has 'HBD:region-to-polyline)
       (progn
         (setq res (HBD:region-to-polyline ent))
         (if res (setq made (length res))))
       (prompt "\nCVPL: Bo qua REGION vi chua nap HBD.lsp."))))
  (if (and (> made 0) (not keep))
    (progn (entdel ent) made)
    made))

;;; --------------------------------------------------------------------------
;;; Than lenh
;;; --------------------------------------------------------------------------
(defun CVPL:run (keep / oldCmdecho doc ss i ent made count skip eType *error*)
  ;; Handler rieng de khong bi handler toan cuc cua lenh khac (HBD/JH/TGN) chen vao
  ;; va nem loi "OSMODE nil" khi bien cua chung chua duoc bind.
  (defun *error* (msg)
    (if oldCmdecho (setvar "CMDECHO" oldCmdecho))
    (if (and msg (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*BREAK*")))
      (prompt (strcat "\nTGIRR CVPL Lỗi: " msg)))
    (princ))
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq oldCmdecho (getvar "CMDECHO"))
  (setvar "CMDECHO" 0)
  (prompt (strcat "\n[CVPL] Quet chon LINE/ARC/CIRCLE/ELLIPSE/SPLINE/POLYLINE/REGION de chuyen sang Polyline"
                  (if keep " (GIU doi tuong nguon): " " (XOA doi tuong nguon): ")))
  (setq ss (ssget "_I" '((0 . "LINE,ARC,CIRCLE,ELLIPSE,SPLINE,POLYLINE,LWPOLYLINE,REGION"))))
  (if (not ss)
    (setq ss (ssget '((0 . "LINE,ARC,CIRCLE,ELLIPSE,SPLINE,POLYLINE,LWPOLYLINE,REGION")))))
  (if (not ss)
    (prompt "\nCVPL: Khong co doi tuong nao duoc chon.")
    (progn
      (vla-StartUndoMark doc)
      (setq count 0 skip 0 i 0)
      (while (< i (sslength ss))
        (setq ent (ssname ss i))
        (if (and ent (entget ent))
          (progn
            (setq eType (cdr (assoc 0 (entget ent))))
            (if (= eType "LWPOLYLINE")
              (setq skip (1+ skip))
              (progn
                (setq made (vl-catch-all-apply 'CVPL:convert-one (list ent keep)))
                (if (vl-catch-all-error-p made)
                  (progn
                    (prompt (strcat "\nCVPL: Lỗi khi chuyển đối tượng " (vl-catch-all-error-message made)))
                    (setq made 0)))
                (if (> made 0)
                  (setq count (+ count made))
                  (setq skip (1+ skip)))))))
        (setq i (1+ i)))
      (vla-EndUndoMark doc)
      (prompt (strcat "\nTGIRR [CVPL]: Da chuyen " (itoa count) " polyline moi"
                      (if keep " (giu nguon)." " , xoa doi tuong nguon.")
                      " Bo qua " (itoa skip) " doi tuong."))))
  (setvar "CMDECHO" oldCmdecho)
  (princ))

;;; Lenh chinh: convert + xoa nguon
(defun c:CVPL () (CVPL:run nil))
(defun c:CVP () (CVPL:run nil))
;;; Lenh giu nguon (chep sang polyline)
(defun c:CVPLG () (CVPL:run T))
(defun c:CV2PL () (CVPL:run T))

(prompt "\nTGIRR CAD LISP: Da nap lenh CVPL (convert sang Polyline, xoa nguon) va CVPLG (giu nguon).")
(princ)
