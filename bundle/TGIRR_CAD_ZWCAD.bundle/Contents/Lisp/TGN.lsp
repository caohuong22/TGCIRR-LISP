;;; TGIRR CAD LISP - TGN: Đánh số đối tượng và vùng tưới
(vl-load-com)

(if (not *TGN:start*) (setq *TGN:start* 1))
(if (not *TGN:step*) (setq *TGN:step* 1))
(if (not *TGN:width*) (setq *TGN:width* 8.0))
(if (not *TGN:height*) (setq *TGN:height* 8.0))
(if (not *TGN:text-height*) (setq *TGN:text-height* 3.0))
(if (not *TGN:mode*) (setq *TGN:mode* "objects"))
(if (not *TGN:order*) (setq *TGN:order* "pick"))

(defun TGN:parse-int (value / parsed)
  (setq parsed (distof value 2))
  (if (and parsed (= parsed (fix parsed))) (fix parsed) nil))

(defun TGN:parse-positive (value / parsed)
  (setq parsed (distof value 2))
  (if (and parsed (> parsed 0.0)) parsed nil))

(defun TGN:write-temp-dialog (/ path stream lines line)
  (setq path (strcat (getvar "TEMPPREFIX") "TGIRR_TGN.dcl")
        lines
        '("tgn_settings : dialog {"
          "  label = \"TGIRR - Đánh số đối tượng / vùng tưới\";"
          "  : boxed_radio_column {"
          "    label = \"Phạm vi đánh số\";"
          "    : radio_button { key = \"mode_objects\"; label = \"Đối tượng được chọn\"; }"
          "    : radio_button { key = \"mode_regions\"; label = \"Vùng tưới (Polyline kín / Circle)\"; }"
          "  }"
          "  : row {"
          "    : boxed_column {"
          "      label = \"Quy luật số\";"
          "      : edit_box { key = \"start\"; label = \"Số bắt đầu:\"; edit_width = 12; }"
          "      : edit_box { key = \"step\"; label = \"Bước nhảy:\"; edit_width = 12; }"
          "    }"
          "    : boxed_column {"
          "      label = \"Kích thước nhãn\";"
          "      : edit_box { key = \"width\"; label = \"Độ rộng khung:\"; edit_width = 12; }"
          "      : edit_box { key = \"height\"; label = \"Chiều cao khung:\"; edit_width = 12; }"
          "      : edit_box { key = \"text_height\"; label = \"Chiều cao chữ:\"; edit_width = 12; }"
          "    }"
          "  }"
          "  : boxed_column {"
          "    label = \"Thứ tự đánh số\";"
          "    : popup_list {"
          "      key = \"order\"; width = 45; value = \"0\";"
          "      list = \"Theo thứ tự chọn\\nTrái sang phải, trên xuống dưới\\nTrên xuống dưới, trái sang phải\\nTheo đường dẫn Polyline\";"
          "    }"
          "  }"
          "  : text { label = \"Có thể quét chọn nhiều đối tượng. Khung là hình tròn khi độ rộng bằng chiều cao.\"; }"
          "  : text { key = \"error\"; label = \"\"; fixed_width = true; width = 75; }"
          "  spacer; ok_cancel;"
          "}"))
  (setq stream (open path "w"))
  (if stream
    (progn
      (foreach line lines (write-line line stream))
      (close stream)
      path)
    nil))

(defun TGN:dialog-path (/ source adjacent)
  (cond
    ((findfile "TGN.dcl"))
    ((and (setq source (findfile "TGN.lsp"))
          (setq adjacent (strcat (vl-filename-directory source) "\\TGN.dcl"))
          (findfile adjacent))
     adjacent)
    (T (TGN:write-temp-dialog))))

(defun TGN:show-dialog (/ path dcl-id result start step width height text-height)
  (setq path (TGN:dialog-path))
  (if (or (not path) (not (findfile path)))
    (progn (alert "Không tìm thấy tệp TGN.dcl.") nil)
    (progn
      (setq dcl-id (load_dialog path))
      (if (or (< dcl-id 0) (not (new_dialog "tgn_settings" dcl-id)))
        (progn
          (if (>= dcl-id 0) (unload_dialog dcl-id))
          (alert "Không mở được hộp thoại TGN.") nil)
        (progn
          (set_tile "mode_objects" (if (= *TGN:mode* "objects") "1" "0"))
          (set_tile "mode_regions" (if (= *TGN:mode* "regions") "1" "0"))
          (set_tile "start" (itoa *TGN:start*))
          (set_tile "step" (itoa *TGN:step*))
          (set_tile "width" (rtos *TGN:width* 2 3))
          (set_tile "height" (rtos *TGN:height* 2 3))
          (set_tile "text_height" (rtos *TGN:text-height* 2 3))
          (set_tile "order" (cond ((= *TGN:order* "x") "1") ((= *TGN:order* "y") "2") ((= *TGN:order* "path") "3") (T "0")))
          (action_tile "accept"
            "(setq start (TGN:parse-int (get_tile \"start\")) step (TGN:parse-int (get_tile \"step\")) width (TGN:parse-positive (get_tile \"width\")) height (TGN:parse-positive (get_tile \"height\")) text-height (TGN:parse-positive (get_tile \"text_height\"))) (if (and start step (/= step 0) width height text-height) (progn (setq *TGN:start* start *TGN:step* step *TGN:width* width *TGN:height* height *TGN:text-height* text-height *TGN:mode* (if (= (get_tile \"mode_regions\") \"1\") \"regions\" \"objects\") *TGN:order* (nth (atoi (get_tile \"order\")) '(\"pick\" \"x\" \"y\" \"path\")) result T) (done_dialog 1)) (set_tile \"error\" \"Nhập số hợp lệ; kích thước > 0 và bước nhảy khác 0.\"))")
          (action_tile "cancel" "(setq result nil) (done_dialog 0)")
          (start_dialog)
          (unload_dialog dcl-id)
          result)))))

(defun TGN:ensure-layer (/ doc layers layer)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object))
        layers (vla-get-Layers doc)
        layer (vl-catch-all-apply 'vla-Item (list layers "TG-number")))
  (if (vl-catch-all-error-p layer)
    (setq layer (vla-Add layers "TG-number")))
  (vla-put-Color layer 7)
  (if (vlax-property-available-p layer 'Linetype T)
    (vla-put-Linetype layer "Continuous"))
  layer)

(defun TGN:closed-region-p (entity / data kind flags)
  (setq data (entget entity) kind (cdr (assoc 0 data)))
  (cond
    ((= kind "CIRCLE") T)
    ((member kind '("LWPOLYLINE" "POLYLINE"))
     (setq flags (cdr (assoc 70 data)))
     (= 1 (logand 1 (if flags flags 0))))
    (T nil)))

(defun TGN:center (entity / object minimum maximum result mn mx)
  (setq object (vlax-ename->vla-object entity)
        result (vl-catch-all-apply 'vla-GetBoundingBox (list object 'minimum 'maximum)))
  (if (vl-catch-all-error-p result)
    nil
    (progn
      (setq mn (vlax-safearray->list minimum)
            mx (vlax-safearray->list maximum))
      (list (/ (+ (car mn) (car mx)) 2.0)
            (/ (+ (cadr mn) (cadr mx)) 2.0)
            (/ (+ (if (caddr mn) (caddr mn) 0.0)
                  (if (caddr mx) (caddr mx) 0.0)) 2.0)))))

(defun TGN:pick-in-order ()
  ;; ssget hỗ trợ chọn từng đối tượng lẫn quét cửa sổ; thứ tự trong selection set
  ;; được giữ lại khi người dùng chọn thủ công từng đối tượng.
  (TGN:selection-set))

(defun TGN:selection-set (/ set index entity selected skipped)
  (prompt (if (= *TGN:mode* "regions")
            "\nChọn các Polyline kín/Circle đại diện vùng tưới: "
            "\nChọn hoặc quét chọn các đối tượng cần đánh số: "))
  (setq set (ssget) selected '() skipped 0)
  (if set
    (progn
      (setq index 0)
      (while (< index (sslength set))
        (setq entity (ssname set index))
        (if (and (= *TGN:mode* "regions") (not (TGN:closed-region-p entity)))
          (setq skipped (1+ skipped))
          (setq selected (cons entity selected)))
        (setq index (1+ index)))
      (if (> skipped 0)
        (prompt (strcat "\nTGN: Bỏ qua " (itoa skipped) " đối tượng không phải vùng kín.")))
      (reverse selected))))

(defun TGN:item (entity / center)
  (if (setq center (TGN:center entity)) (list entity center) nil))

(defun TGN:sort-x (left right / a b tolerance)
  (setq a (cadr left) b (cadr right) tolerance 1e-8)
  (if (> (abs (- (cadr a) (cadr b))) tolerance)
    (> (cadr a) (cadr b))
    (< (car a) (car b))))

(defun TGN:sort-y (left right / a b tolerance)
  (setq a (cadr left) b (cadr right) tolerance 1e-8)
  (if (> (abs (- (car a) (car b))) tolerance)
    (< (car a) (car b))
    (> (cadr a) (cadr b))))

(defun TGN:path-polyline-p (entity / kind)
  (and entity
       (setq kind (cdr (assoc 0 (entget entity))))
       (member kind '("LWPOLYLINE" "POLYLINE"))))

(defun TGN:select-path (/ picked path point closest start-distance end-distance closed)
  (setq path nil)
  (while (not path)
    (setq picked (entsel "\nChọn Polyline làm đường dẫn <Esc để hủy>: "))
    (cond
      ((not picked) (setq path 'cancelled))
      ((TGN:path-polyline-p (car picked)) (setq path (car picked)))
      (T (prompt "\nTGN: Đường dẫn phải là Polyline."))))
  (if (= path 'cancelled)
    nil
    (progn
      (setq end-distance
        (vlax-curve-getDistAtParam path (vlax-curve-getEndParam path))
        closed (TGN:closed-region-p path))
      (initget 128)
      (setq point (getpoint "\nChọn điểm bắt đầu trên đường dẫn <Enter/Space = từ đầu Polyline>: "))
      (if (= (type point) 'LIST)
        (progn
          (setq closest (vlax-curve-getClosestPointTo path (trans point 1 0))
                start-distance (vlax-curve-getDistAtPoint path closest)))
        (setq start-distance 0.0))
      (list path start-distance end-distance closed))))

(defun TGN:path-distance (center path-data / path start-distance total-distance closest distance)
  (setq path (car path-data)
        start-distance (cadr path-data)
        total-distance (caddr path-data)
        closest (vlax-curve-getClosestPointTo path center)
        distance (vlax-curve-getDistAtPoint path closest))
  (if (>= distance start-distance)
    (- distance start-distance)
    (+ (- total-distance start-distance) distance)))

(defun TGN:sort-path (left right)
  (< (caddr left) (caddr right)))

(defun TGN:prepare-items (entities path-data / items item distance)
  (setq items '())
  (foreach entity entities
    (if (setq item (TGN:item entity))
      (progn
        (if path-data
          (progn
            (setq distance (TGN:path-distance (cadr item) path-data)
                  item (append item (list distance)))))
        (setq items (cons item items)))))
  (setq items (reverse items))
  (cond
    ((= *TGN:order* "x") (vl-sort items 'TGN:sort-x))
    ((= *TGN:order* "y") (vl-sort items 'TGN:sort-y))
    ((= *TGN:order* "path") (vl-sort items 'TGN:sort-path))
    (T items)))

(defun TGN:make-ellipse (center width height / major ratio)
  (if (>= width height)
    (setq major (list (/ width 2.0) 0.0 0.0) ratio (/ height width))
    (setq major (list 0.0 (/ height 2.0) 0.0) ratio (/ width height)))
  (entmakex
    (list '(0 . "ELLIPSE") '(100 . "AcDbEntity") '(8 . "TG-number")
          '(62 . 256) '(100 . "AcDbEllipse") (cons 10 center)
          (cons 11 major) (cons 40 ratio) '(41 . 0.0) (cons 42 (* 2.0 pi)))))

(defun TGN:make-text (center label height)
  (entmakex
    (list '(0 . "TEXT") '(100 . "AcDbEntity") '(8 . "TG-number")
          '(62 . 256) '(100 . "AcDbText") (cons 10 center) (cons 11 center)
          (cons 40 height) (cons 1 label) (cons 7 (getvar "TEXTSTYLE"))
          '(50 . 0.0) '(72 . 1) '(73 . 2))))

(defun c:TGN (/ *error* old-cmdecho old-osmode undo-open entities path-data items item number made)
  (vl-load-com)
  (setq old-cmdecho (getvar "CMDECHO") old-osmode (getvar "OSMODE") undo-open nil)
  (defun *error* (message)
    (if undo-open (command-s "_.UNDO" "_End"))
    (setvar "CMDECHO" old-cmdecho)
    (setvar "OSMODE" old-osmode)
    (if (and message (not (wcmatch (strcase message) "*CANCEL*,*QUIT*,*BREAK*")))
      (prompt (strcat "\nLỗi TGN: " message)))
    (princ))
  (if (TGN:show-dialog)
    (progn
      (setq entities (if (= *TGN:order* "pick") (TGN:pick-in-order) (TGN:selection-set)))
      (if (and entities (= *TGN:order* "path"))
        (setq path-data (TGN:select-path)))
      (if (and entities (or (/= *TGN:order* "path") path-data))
        (progn
          (setq items (TGN:prepare-items entities path-data))
          (if items
            (progn
              (setvar "CMDECHO" 0)
              (setvar "OSMODE" 0)
              (command-s "_.UNDO" "_Begin")
              (setq undo-open T)
              (TGN:ensure-layer)
              (setq number *TGN:start* made 0)
              (foreach item items
                (TGN:make-ellipse (cadr item) *TGN:width* *TGN:height*)
                (TGN:make-text (cadr item) (itoa number) *TGN:text-height*)
                (setq number (+ number *TGN:step*) made (1+ made)))
              (command-s "_.UNDO" "_End")
              (setq undo-open nil)
              (prompt (strcat "\nTGN: Đã đánh số " (itoa made) " đối tượng trên layer TG-number.")))
            (prompt "\nTGN: Không lấy được tâm của đối tượng đã chọn.")))
        (prompt "\nTGN: Không có đối tượng hợp lệ được chọn."))))
  (setvar "CMDECHO" old-cmdecho)
  (setvar "OSMODE" old-osmode)
  (princ))

(prompt "\nTGIRR: Đã nạp lệnh TGN - đánh số đối tượng/vùng tưới.")
(princ)
