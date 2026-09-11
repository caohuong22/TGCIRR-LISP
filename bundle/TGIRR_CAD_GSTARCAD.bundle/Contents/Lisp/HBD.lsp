;;; ==========================================================================
;;; TGIRR CAD LISP - LENH HBD / BH / TGBOUND va LENH JH / MH / JOINHATCH
;;; 1. HBD: Ve duong bao (Boundary Polyline) xung quanh cac doi tuong HATCH co.
;;;         Co tuy chon [J] Hop nhat cac boundary giap nhau lam 1.
;;; 2. JH : Gop cac doi tuong Hatch phan manh giap nhau thanh 1 Hatch duy nhat
;;;         va tao 1 duong bao chung duy nhat tren Layer chuan TG-BOUND.
;;; Ho tro AutoCAD, ZWCAD va GstarCAD
;;; ==========================================================================
(vl-load-com)

;; Bien toan cuc ghi nho thiet lap giua cac lan goi lenh
(if (not *HBD:target-layer*) (setq *HBD:target-layer* "TG-BOUND"))
(if (not *HBD:outer-only*)   (setq *HBD:outer-only* nil))   ; nil = giu tat ca (ca dao); T = chi lay bao ngoai
(if (not *HBD:union-bounds*) (setq *HBD:union-bounds* T))    ; T = tu dong hop nhat cac boundary giap nhau lam 1

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

;; Tao boundary cho 1 hatch bang phuong phap da nen tang
(defun HBD:generate-boundary-single (hatch-ent / ss ok)
  (setq ss (HBD:ename-to-ss hatch-ent))
  ;; Thu lenh HATCHGENERATEBOUNDARY (co tren AutoCAD 2011+, ZWCAD, GstarCAD)
  (setq ok (vl-cmdf "_.HATCHGENERATEBOUNDARY" ss ""))
  (if (not ok)
    ;; Fallback qua -HATCHEDIT
    (setq ok (vl-cmdf "_.-HATCHEDIT" hatch-ent "_B" "_P" "_N"))
  )
  ok
)

;; Hop nhat cac Polyline giap nhau hoac chong lan thanh 1 Polyline chung duy nhat (Region Union)
(defun HBD:union-polylines (polyList / oldEnt ssPoly newEnts regList ssUnion
                                      remRegs finalPolys beforeExp expEnts ssExp
                                      resPieces re oldPedit)
  (if (or (not polyList) (<= (length polyList) 1))
    polyList
    (progn
      ;; 1. Chuyen cac Polyline thanh Region (AutoCAD tu dong xoa cac polyline nguon khi tao region thanh cong)
      (setq oldEnt (entlast))
      (setq ssPoly (ssadd))
      (foreach p polyList
        (if (and p (entget p)) (ssadd p ssPoly))
      )
      (vl-cmdf "_.REGION" ssPoly "")
      (setq newEnts (HBD:get-new-entities oldEnt))
      (setq regList (vl-remove-if-not '(lambda (e) (= (cdr (assoc 0 (entget e))) "REGION")) newEnts))

      (if (< (length regList) 2)
        ;; Neu khong tao duoc it nhat 2 region thi tra ve danh sach ban dau
        polyList
        (progn
          ;; 2. Union tat ca cac Region lai voi nhau
          (setq ssUnion (ssadd))
          (foreach r regList (ssadd r ssUnion))
          (vl-cmdf "_.UNION" ssUnion "")

          ;; 3. Tim cac Region con song sau lenh UNION
          (setq remRegs (vl-remove-if-not 'entget regList))
          (setq finalPolys '())
          (setq oldPedit (getvar "PEDITACCEPT"))
          (setvar "PEDITACCEPT" 1)

          ;; 4. Explode tung Region va Join lai thanh LWPOLYLINE
          (foreach r remRegs
            (setq beforeExp (entlast))
            (vl-cmdf "_.EXPLODE" r)
            (setq expEnts (HBD:get-new-entities beforeExp))
            (if expEnts
              (progn
                (setq ssExp (ssadd))
                (foreach ep expEnts (if (entget ep) (ssadd ep ssExp)))
                ;; Thu lenh JOIN truoc
                (if (not (vl-cmdf "_.JOIN" ssExp ""))
                  (vl-cmdf "_.PEDIT" "_M" ssExp "" "_J" 0.001 "")
                )
                ;; Lay cac LWPOLYLINE / POLYLINE moi tao thanh
                (setq resPieces (HBD:get-new-entities beforeExp))
                (foreach re resPieces
                  (if (and (entget re)
                           (member (cdr (assoc 0 (entget re))) '("LWPOLYLINE" "POLYLINE")))
                    (setq finalPolys (cons re finalPolys))
                  )
                )
              )
            )
          )
          (setvar "PEDITACCEPT" oldPedit)

          (if (> (length finalPolys) 0)
            (reverse finalPolys)
            polyList
          )
        )
      )
    )
  )
)

;;; ==========================================================================
;;; LENH HBD: Ve duong bao Boundary cho Hatch co
;;; ==========================================================================
(defun c:HBD (/ oldCmdecho oldOsmode *error* doc undoStarted
                ssSel preSel opt entMau edMau patMau layMau
                hatchList totalHatches totalBounds i hEnt
                entBefore createdEnts allCreated finalBounds
                maxEnt maxArea curArea)

  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq oldCmdecho (getvar "CMDECHO"))
  (setq oldOsmode   (getvar "OSMODE"))
  (setq undoStarted nil)

  ;; Ham xu ly khi co loi hoac nguoi dung huy lenh (ESC)
  (defun *error* (msg)
    (if undoStarted
      (vl-catch-all-apply 'vla-EndUndoMark (list doc))
    )
    (setvar "CMDECHO" oldCmdecho)
    (setvar "OSMODE"  oldOsmode)
    (if (and msg (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*BREAK*")))
      (prompt (strcat "\nTGIRR HBD Loi: " msg))
    )
    (princ)
  )

  (setvar "CMDECHO" 0)

  ;; Kiem tra PICKFIRST (doi tuong da chon truoc khi go lenh)
  (setq preSel (ssget "_I" '((0 . "HATCH"))))

  (if preSel
    (progn
      (setq ssSel preSel)
      (sssetfirst nil nil)
    )
    (progn
      ;; Hien thi menu lua chon
      (initget "M T J D L")
      (setq opt
        (getkword
          (strcat
            "\n[HBD] Chon Hatch co hoac [Mau(M) / Tat ca(T) / Hop nhat("
            (if *HBD:union-bounds* "Bat" "Tat")
            "-J) / Dao("
            (if *HBD:outer-only* "Chi ngoai" "Ca dao")
            "-D) / Layer(L)]: "
          )
        )
      )

      (cond
        ;; Tuy chon M: Chon theo hatch mau
        ((= opt "M")
          (prompt "\nChon 1 doi tuong HATCH co lam mau: ")
          (setq entMau (car (entsel)))
          (if (and entMau (= (cdr (assoc 0 (entget entMau))) "HATCH"))
            (progn
              (setq edMau  (entget entMau)
                    patMau (cdr (assoc 2 edMau))
                    layMau (cdr (assoc 8 edMau)))
              (prompt
                (strcat "\nMau da chon: Pattern = \"" patMau "\", Layer = \"" layMau "\"")
              )
              (prompt "\nQuet chon pham vi tim Hatch co theo mau (nhan Enter de lay toan bo ban ve): ")
              (setq ssSel (ssget (list '(0 . "HATCH") (cons 2 patMau) (cons 8 layMau))))
              (if (not ssSel)
                (progn
                  (prompt "\nDang tim kiem tat ca Hatch co theo mau trong ban ve...")
                  (setq ssSel
                    (ssget "_X"
                      (list
                        '(0 . "HATCH")
                        (cons 2 patMau)
                        (cons 8 layMau)
                        (cons 410 (getvar "CTAB"))
                      )
                    )
                  )
                )
              )
            )
            (prompt "\nDoi tuong duoc chon khong phai la HATCH.")
          )
        )

        ;; Tuy chon T: Chon tat ca Hatch trong khong gian hien hanh
        ((= opt "T")
          (prompt "\nDang tim tat ca Hatch trong Model/Layout hien hanh...")
          (setq ssSel
            (ssget "_X"
              (list
                '(0 . "HATCH")
                (cons 410 (getvar "CTAB"))
              )
            )
          )
        )

        ;; Tuy chon J: Bat/tat che do tu dong hop nhat cac duong bao giap nhau lam 1
        ((= opt "J")
          (setq *HBD:union-bounds* (not *HBD:union-bounds*))
          (prompt
            (strcat
              "\nChe do hop nhat Boundary giap nhau: "
              (if *HBD:union-bounds*
                "[BAT - Tu dong hop nhat (UNION) cac mảng giap nhau thanh 1 duong bao duy nhat]"
                "[TAT - De nguyen cac duong bao doc lap]"
              )
            )
          )
          (prompt "\nQuet chon cac Hatch can tao duong bao: ")
          (setq ssSel (ssget '((0 . "HATCH"))))
        )

        ;; Tuy chon D: Dao che do chi lay duong bao ngoai hay giu ca dao
        ((= opt "D")
          (setq *HBD:outer-only* (not *HBD:outer-only*))
          (prompt
            (strcat
              "\nChe do duong bao hien tai: "
              (if *HBD:outer-only*
                "[CHI LAY BAO NGOAI - bo cac lo dao ben trong]"
                "[LAY TAT CA - giu ca bao ngoai va lo dao ben trong]"
              )
            )
          )
          (prompt "\nQuet chon cac Hatch can tao duong bao: ")
          (setq ssSel (ssget '((0 . "HATCH"))))
        )

        ;; Tuy chon L: Thay doi Layer dich
        ((= opt "L")
          (setq opt
            (getstring
              (strcat "\nNhap ten Layer dich <" *HBD:target-layer* ">: ")
            )
          )
          (if (and opt (/= opt ""))
            (setq *HBD:target-layer* (strcase opt))
          )
          (prompt (strcat "\nLayer dich: " *HBD:target-layer*))
          (prompt "\nQuet chon cac Hatch can tao duong bao: ")
          (setq ssSel (ssget '((0 . "HATCH"))))
        )

        ;; Mac dinh: Quet chon truc tiep
        (T
          (prompt "\nQuet chon cac Hatch co can tao duong bao: ")
          (setq ssSel (ssget '((0 . "HATCH"))))
        )
      )
    )
  )

  ;; Kiem tra ket qua tap chon
  (if (or (not ssSel) (= (sslength ssSel) 0))
    (progn
      (prompt "\nKhong co doi tuong HATCH nao duoc chon.")
      (setvar "CMDECHO" oldCmdecho)
      (princ)
    )
    (progn
      ;; Dam bao layer dich ton tai
      (HBD:ensure-layer *HBD:target-layer* 7 "Continuous")

      ;; Bat dau danh dau Undo
      (vla-StartUndoMark doc)
      (setq undoStarted T)

      ;; Chuyen tap chon thanh danh sach ename
      (setq hatchList '())
      (setq i 0)
      (while (< i (sslength ssSel))
        (setq hatchList (cons (ssname ssSel i) hatchList))
        (setq i (1+ i))
      )
      (setq hatchList (reverse hatchList))
      (setq totalHatches (length hatchList))

      ;; Duyet qua tung Hatch de tao Boundary
      (setq allCreated '())
      (foreach hEnt hatchList
        (setq entBefore (entlast))
        (HBD:generate-boundary-single hEnt)
        (setq createdEnts (HBD:get-new-entities entBefore))
        (if createdEnts
          (setq allCreated (append allCreated createdEnts))
        )
      )

      ;; Neu nguoi dung bat hop nhat (UNION) va co nhieu hon 1 duong bao
      (if (and *HBD:union-bounds* (> (length allCreated) 1))
        (setq finalBounds (HBD:union-polylines allCreated))
        (setq finalBounds allCreated)
      )

      ;; Neu chon Outer-only (chi lay bao ngoai lon nhat trong tung cum)
      (if (and *HBD:outer-only* (> (length finalBounds) 1))
        (progn
          (setq maxEnt  (car finalBounds)
                maxArea (HBD:get-area maxEnt))
          (foreach e (cdr finalBounds)
            (setq curArea (HBD:get-area e))
            (if (> curArea maxArea)
              (progn
                (if (entget maxEnt) (entdel maxEnt))
                (setq maxEnt  e
                      maxArea curArea)
              )
              (if (entget e) (entdel e))
            )
          )
          (setq finalBounds (list maxEnt))
        )
      )

      ;; Gan Layer dich va mau ByLayer cho cac duong bao sinh ra
      (setq totalBounds 0)
      (foreach bEnt finalBounds
        (if (entget bEnt)
          (progn
            (setq totalBounds (1+ totalBounds))
            (vl-catch-all-apply
              '(lambda ()
                 (vla-put-Layer (vlax-ename->vla-object bEnt) *HBD:target-layer*)
                 (vla-put-Color (vlax-ename->vla-object bEnt) 256) ; ByLayer
                 (if (vlax-property-available-p (vlax-ename->vla-object bEnt) 'Closed T)
                   (vla-put-Closed (vlax-ename->vla-object bEnt) :vlax-true)
                 )
               )
            )
          )
        )
      )

      ;; Ket thuc Undo
      (vla-EndUndoMark doc)
      (setq undoStarted nil)

      (setvar "CMDECHO" oldCmdecho)
      (setvar "OSMODE"  oldOsmode)

      ;; Thong bao ket qua
      (prompt
        (strcat
          "\n======================================================="
          "\nTGIRR [HBD]: Hoan tat tao duong bao Hatch!"
          "\n- So luong Hatch da xu ly  : " (itoa totalHatches)
          "\n- So duong bao Polyline tao: " (itoa totalBounds)
          "\n- Layer dich               : " *HBD:target-layer*
          "\n- Hop nhat giap ranh       : " (if *HBD:union-bounds* "Co (UNION)" "Khong")
          "\n- Che do bao               : " (if *HBD:outer-only* "Chi lay bao ngoai" "Giu ca bao ngoai va dao")
          "\n======================================================="
        )
      )
      (princ)
    )
  )
)

;;; ==========================================================================
;;; LENH JH (JOIN HATCH): Gop cac Hatch phan manh giap nhau thanh 1 Hatch duy nhat
;;; va tao 1 duong bao chung duy nhat tren Layer TG-BOUND
;;; ==========================================================================
(defun c:JH (/ oldCmdecho oldOsmode oldPedit doc undoStarted
               ssSel hatchList firstEnt edFirst patName patScale patAngle patLayer patColor
               allBounds entBefore created finalBounds polySS hEnt bEnt)

  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq oldCmdecho (getvar "CMDECHO"))
  (setq oldOsmode   (getvar "OSMODE"))
  (setq oldPedit    (getvar "PEDITACCEPT"))
  (setq undoStarted nil)

  (defun *error* (msg)
    (if undoStarted
      (vl-catch-all-apply 'vla-EndUndoMark (list doc))
    )
    (setvar "CMDECHO" oldCmdecho)
    (setvar "OSMODE"  oldOsmode)
    (setvar "PEDITACCEPT" oldPedit)
    (if (and msg (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*BREAK*")))
      (prompt (strcat "\nTGIRR JH Loi: " msg))
    )
    (princ)
  )

  (setvar "CMDECHO" 0)

  ;; Kiem tra Pickfirst hoac quet chon
  (setq ssSel (ssget "_I" '((0 . "HATCH"))))
  (if (not ssSel)
    (progn
      (prompt "\nTGIRR [JH]: Quet chon cac doi tuong Hatch co can gop lam 1: ")
      (setq ssSel (ssget '((0 . "HATCH"))))
    )
  )

  (if (or (not ssSel) (< (sslength ssSel) 2))
    (progn
      (prompt "\nCan chon it nhat 2 doi tuong HATCH de gop lam 1.")
      (setvar "CMDECHO" oldCmdecho)
      (princ)
    )
    (progn
      (vla-StartUndoMark doc)
      (setq undoStarted T)

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
        (setq i (1+ i))
      )
      (setq hatchList (reverse hatchList))

      ;; 1. Sinh boundary cho tung Hatch
      (setq allBounds '())
      (foreach hEnt hatchList
        (setq entBefore (entlast))
        (HBD:generate-boundary-single hEnt)
        (setq created (HBD:get-new-entities entBefore))
        (if created (setq allBounds (append allBounds created)))
      )

      (if (or (not allBounds) (= (length allBounds) 0))
        (progn
          (prompt "\nKhong sinh duoc boundary cho cac Hatch da chon.")
          (vla-EndUndoMark doc)
          (setvar "CMDECHO" oldCmdecho)
          (princ)
        )
        (progn
          ;; 2. Hop nhat cac boundary giap nhau thanh 1 duong bao Polyline chung duy nhat
          (setq finalBounds (HBD:union-polylines allBounds))

          ;; 3. Dam bao duong bao thuoc Layer TG-BOUND
          (HBD:ensure-layer *HBD:target-layer* 7 "Continuous")
          (foreach bEnt finalBounds
            (if (entget bEnt)
              (vl-catch-all-apply
                '(lambda ()
                   (vla-put-Layer (vlax-ename->vla-object bEnt) *HBD:target-layer*)
                   (vla-put-Color (vlax-ename->vla-object bEnt) 256)
                   (if (vlax-property-available-p (vlax-ename->vla-object bEnt) 'Closed T)
                     (vla-put-Closed (vlax-ename->vla-object bEnt) :vlax-true)
                   )
                 )
              )
            )
          )

          ;; 4. Xoa cac doi tuong Hatch phan manh cu
          (foreach hEnt hatchList
            (if (entget hEnt) (entdel hEnt))
          )

          ;; 5. Tao 1 doi tuong Hatch moi duy nhat theo duong bao hop nhat
          (setvar "CLAYER" patLayer)
          (setq polySS (ssadd))
          (foreach bEnt finalBounds
            (if (entget bEnt) (ssadd bEnt polySS))
          )

          (if (= (strcase patName) "SOLID")
            (vl-cmdf "_.-HATCH" "_P" "SOLID" "_S" polySS "" "")
            (if (and patScale (> patScale 0))
              (vl-cmdf "_.-HATCH" "_P" patName patScale patAngle "_S" polySS "" "")
              (vl-cmdf "_.-HATCH" "_P" patName "_S" polySS "" "")
            )
          )

          (vla-EndUndoMark doc)
          (setq undoStarted nil)

          (setvar "CMDECHO" oldCmdecho)
          (setvar "OSMODE"  oldOsmode)
          (setvar "PEDITACCEPT" oldPedit)

          (prompt
            (strcat
              "\n======================================================="
              "\nTGIRR [JH]: Da gop thanh cong " (itoa (length hatchList)) " Hatch thanh 1!"
              "\n- Pattern       : " patName
              "\n- Layer Hatch   : " patLayer
              "\n- Duong bao hop : " (itoa (length finalBounds)) " Polyline tren Layer '" *HBD:target-layer* "'"
              "\n======================================================="
            )
          )
          (princ)
        )
      )
    )
  )
)

;; Cac lenh tat
(defun c:BH () (c:HBD))
(defun c:TGBOUND () (c:HBD))
(defun c:MH () (c:JH))
(defun c:JOINHATCH () (c:JH))

(prompt "\nTGIRR CAD LISP: Da nap lenh HBD (Ve bound hatch) va lenh JH (Gop hatch lam 1).")
(princ)
