;;; TGIRRCOMMANDS.lsp - SINH TU DONG tu src/catalog/tools.json (scripts/gen-catalog.ps1).
;;; KHONG sua tay file nay.
;;;
;;; Cac lenh .NET (TL, TGN, TNET, TGL, TGLADD, CPLUS, VDNG, CVPL...) duoc dang ky
;;; duoi ten noi bo TGIRR<CMD> de khong bao gio trung voi LISP cua nguoi dung.
;;; File nay tao lai ten quen thuoc c:<CMD> nhung chi khi lenh con duoc bat trong
;;; TGIRRSETTINGS (xem TGIRR:LOAD-ENABLED-P trong loader).
(vl-load-com)

;; Doc cai dat bat/tat (file nay tu doc duoc, khong phu thuoc loader).
(defun TGIRR:CMDSET-FILE (/ appdata)
  (setq appdata (getenv "APPDATA"))
  (if (and appdata (> (strlen appdata) 0))
    (strcat appdata "\\TGIRR\\load-settings.txt")
    nil))

(defun TGIRR:CMDSET-TOKENS (text / pos out tok)
  (setq out nil)
  (while (and text (setq pos (vl-string-search "," text)))
    (setq tok (substr text 1 pos)
          text (substr text (+ pos 2)))
    (if (> (strlen tok) 0) (setq out (cons tok out))))
  (if (and text (> (strlen text) 0)) (setq out (cons text out)))
  (reverse out))

(defun TGIRR:CMDSET-DISABLED (/ path fh line rest pos)
  (setq path (TGIRR:CMDSET-FILE))
  (setq line nil)
  (if (and path (findfile path) (setq fh (open path "r")))
    (progn
      (setq line (read-line fh))
      (close fh)))
  (setq rest (if (and line (= (substr line 1 2) "v1")) (substr line 3) ""))
  (setq pos (vl-string-search "disabled=" rest))
  (if pos (TGIRR:CMDSET-TOKENS (substr rest (+ pos 10))) nil))

(defun TGIRR:LOAD-ENABLED-P (id)
  (not (member id (TGIRR:CMDSET-DISABLED))))

;; Toan bo lenh TGIRR quan ly duoc (de canh bao khi tat sach).
(setq *TGIRR:ALL-COMMANDS* (list "HBD" "JH" "SP2PL" "CVPL" "SBS" "SBSE" "SCH" "VDNG" "TNET" "TGL" "TGLADD" "TL" "TGN" "CPLUS" "DOITEXT" "DOIMTEXT"))

(defun TGIRR:RUN (command / doc)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (vla-SendCommand doc (strcat command " ")))

;; CVPL -> TGIRRCVPL
(if (TGIRR:LOAD-ENABLED-P "CVPL") (defun c:CVPL () (TGIRR:RUN "TGIRRCVPL")))
(if (TGIRR:LOAD-ENABLED-P "CVPL") (defun c:CVP () (TGIRR:RUN "TGIRRCVP")))
(if (TGIRR:LOAD-ENABLED-P "CVPL") (defun c:CVPLG () (TGIRR:RUN "TGIRRCVPLG")))
(if (TGIRR:LOAD-ENABLED-P "CVPL") (defun c:CV2PL () (TGIRR:RUN "TGIRRCV2PL")))
;; VDNG -> TGIRRVDNG
(if (TGIRR:LOAD-ENABLED-P "VDNG") (defun c:VDNG () (TGIRR:RUN "TGIRRVDNG")))
;; TNET -> TGIRRTNET
(if (TGIRR:LOAD-ENABLED-P "TNET") (defun c:TNET () (TGIRR:RUN "TGIRRTNET")))
;; TGL -> TGIRRTGL
(if (TGIRR:LOAD-ENABLED-P "TGL") (defun c:TGL () (TGIRR:RUN "TGIRRTGL")))
;; TGLADD -> TGIRRTGLADD
(if (TGIRR:LOAD-ENABLED-P "TGLADD") (defun c:TGLADD () (TGIRR:RUN "TGIRRTGLADD")))
;; TL -> TGIRRTL
(if (TGIRR:LOAD-ENABLED-P "TL") (defun c:TL () (TGIRR:RUN "TGIRRTL")))
;; TGN -> TGIRRTGN
(if (TGIRR:LOAD-ENABLED-P "TGN") (defun c:TGN () (TGIRR:RUN "TGIRRTGN")))
;; CPLUS -> TGIRRCPLUS
(if (TGIRR:LOAD-ENABLED-P "CPLUS") (defun c:CPLUS () (TGIRR:RUN "TGIRRCPLUS")))

;; Go cac lenh LISP bi tat (file .lsp da duoc manifest nap truoc file nay).
;; Viet truc tiep tung lenh, khong dung eval/read.
(if (not (TGIRR:LOAD-ENABLED-P "SBS")) (setq C:SBS nil))
(if (not (TGIRR:LOAD-ENABLED-P "SBSE")) (setq C:SBSE nil))
(if (not (TGIRR:LOAD-ENABLED-P "SCH")) (setq C:SCH nil))
(if (not (TGIRR:LOAD-ENABLED-P "HBD")) (setq C:HBD nil))
(if (not (TGIRR:LOAD-ENABLED-P "JH")) (setq C:JH nil))
(if (not (TGIRR:LOAD-ENABLED-P "SP2PL")) (setq C:SP2PL nil))
(if (not (TGIRR:LOAD-ENABLED-P "DOITEXT")) (setq C:DOITEXT nil))
(if (not (TGIRR:LOAD-ENABLED-P "DOIMTEXT")) (setq C:DOIMTEXT nil))
(if (not (TGIRR:LOAD-ENABLED-P "TGIRRBAR")) (setq C:TGIRRBAR nil))

(princ)
