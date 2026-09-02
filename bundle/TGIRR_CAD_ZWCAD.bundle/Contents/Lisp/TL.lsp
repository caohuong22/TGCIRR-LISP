;;; Free Lisp from cadviet.com - lenh TL
;;; Cach dung: Chon truoc cac doi tuong, sau do go TL hoac bam nut TL.
(vl-load-com)

(defun Length1 (e)
  (vlax-curve-getDistAtParam e (vlax-curve-getEndParam e))
)

(defun C:TL (/ ss L e)
  ;; Lay tap doi tuong da chon truoc (PICKFIRST), chi giu cac loai duong hop le.
  (setq ss
    (ssget "_I"
      (list
        (cons 0 "LINE,ARC,CIRCLE,POLYLINE,LWPOLYLINE,ELLIPSE,SPLINE")
      )
    )
  )

  (if ss
    (progn
      (setq L 0.0)
      (while (setq e (ssname ss 0))
        (setq L (+ L (Length1 e)))
        (ssdel e ss)
      )
      (alert (strcat "Tổng chiều dài = " (rtos L)))
    )
    (alert
      "Chưa chọn đối tượng hợp lệ.\n\nHãy chọn trước Line, Arc, Circle, Polyline, Ellipse hoặc Spline, sau đó bấm TL."
    )
  )
  (princ)
)

(prompt "\nTGIRR: Đã nạp lệnh TL - chọn đối tượng trước, sau đó bấm TL.")
(princ)