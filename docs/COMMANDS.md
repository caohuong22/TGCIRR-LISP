# Danh sách lệnh TGIRR CAD LISP

Toàn bộ lệnh **đang hoạt động** của TGIRR. Mỗi lệnh đều có nút trên cả hai bề mặt giao diện:

- **AutoCAD**: tab Ribbon **TGIRR CAD LISP** (`TGIRRRIBBON` để mở/active tab) và/hoặc thanh công cụ icon native `TGIRRBAR`.
- **ZWCAD & GstarCAD**: thanh công cụ icon native **TGIRR CAD** (`TGIRRBAR`) chứa toàn bộ lệnh dưới dạng nút icon, bảng công cụ Palette **TGIRR CAD** (`TGIRRPALETTE`), palette Quick Tools riêng chứa các nút đã ghim ★ (`TGIRRQUICK`), và menu kéo xuống `TGIRR &CAD` (`MENULOAD` file `TGIRR_CAD.mnu`).

Nhập/nhan/tooltip của mọi lệnh khai báo **một lần** trong [`src/catalog/tools.json`](../src/catalog/tools.json); bảng dưới đây, menu và danh muc palette được sinh từ file đó bằng `scripts/gen-catalog.ps1` (chạy `scripts/test-palette.ps1` để bắt lệch).

<!-- BEGIN GENERATED COMMAND TABLE (source: src/catalog/tools.json) -->
| Nhóm (Panel) | Lệnh | Chức năng | Gõ trực tiếp? |
|---|---|---|---|
| RANH GIỚI | HBD | Vẽ đường bao Polyline (Boundary) quanh Hatch cỏ, tự gán Layer `TG-BOUND` | Có (`HBD`, `BH`, `TGBOUND`) |
| RANH GIỚI | JH | Gộp các Hatch phân mảnh giáp nhau thành 1 Hatch duy nhất + 1 Boundary chung | Có (`JH`, `MH`, `JOINHATCH`) |
| RANH GIỚI | SP2PL | Chuyển đổi nhanh các đối tượng Spline và Region thành Polyline khép kín | Có (`SP2PL`, `REG2PL`, `C2PL`) |
| RANH GIỚI | CVPL | Convert LINE, ARC, CIRCLE, ELLIPSE, SPLINE, POLYLINE kiểu cũ, REGION sang LWPOLYLINE (xóa nguồn); `CVPLG` giữ nguồn | Có (`CVPL`, `CVP`, `CVPLG`, `CV2PL`) |
| CHỌN | SBS | Chọn đối tượng giống mẫu nằm phần lớn trong Polyline kín | Có (`SBS`) |
| CHỌN | SBSE | Chọn chính xác theo mẫu trong Polyline kín (bắt buộc trùng nội dung chữ TEXT/MTEXT, tên Block) | Có (`SBSE`) |
| TƯỚI | VDNG | Vẽ dây nhỏ giọt bên trong Boundary kín (tự tạo layer `TG-DRIP`) — chọn hướng dây thủ công, nối zigzag liên tục, ghi chú + thống kê chiều dài | Có (`VDNG`) |
| NÉT VẼ | TNET | Mở hộp thoại tạo/chỉnh sửa nét vẽ có chữ (file LIN); tự đo chiều dài vùng chữ trong CAD để căn chữ cân giữa hai đoạn gạch | Có (`TNET`) |
| LAYER | TGL | Tạo bộ Layer tiêu chuẩn và đặt `TG-DRIP` làm layer hiện hành | Có (`TGL`) |
| ĐO | TL | Cộng tổng chiều dài các đường đã chọn trước | Có (`TL`) |
| ĐÁNH SỐ | TGN | Đánh số đối tượng / vùng tưới bằng nhãn tròn/ellipse | Có (`TGN`) |
| VĂN BẢN | CPLUS | Copy TEXT/MTEXT/Multileader/Attribute/Dimension Override theo số, chữ A–Z hoặc danh sách | Có (`CPLUS`) |
| VĂN BẢN | DOITEXT | Chuyển MText sang Text tại chỗ hoặc gom nhiều MText thành 1 danh sách cột thẳng hàng | Có (`DOITEXT`, `M2T`) |
| VĂN BẢN | DOIMTEXT | Gộp nhiều TEXT thành 1 MTEXT nhiều đoạn, giữ layer/style/màu/chiều cao/góc xoay/điểm bám dính | Có (`DOIMTEXT`, `T2M`, `TEXT2MTEXT`) |
| GIAO DIỆN | TGIRRPALETTE | Bật/tắt bảng công cụ Palette (ZWCAD & GstarCAD) | Có (`TGIRRPALETTE`) |
| GIAO DIỆN | TGIRRQUICK | Bật/tắt palette Quick Tools riêng — chứa các nút đã ghim ★ (ZWCAD & GstarCAD) | Có (`TGIRRQUICK`) |
| GIAO DIỆN | TGIRRBAR | Bật thanh công cụ icon native (toolbar ***TOOLBARS trong TGIRR_CAD.mnu) | Có (`TGIRRBAR`, `TGIRRTB`) |
<!-- END GENERATED COMMAND TABLE -->

## Nguồn giao diện duy nhất (dành cho lập trình viên)

Tên nút, tooltip, nhóm, thứ tự mục menu và các dòng trong bảng trên **chỉ khai báo một lần**
trong [`src/catalog/tools.json`](../src/catalog/tools.json). Sửa file đó rồi chạy:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/gen-catalog.ps1   # sinh menu + ToolCatalog + bang lenh
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/port-zwcad.ps1     # dong bo ban port ZWCAD
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/port-gscad.ps1     # dong bo ban port GstarCAD
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-palette.ps1   # kiem tra lech + chay test
```

Dầu ra của `gen-catalog.ps1` (không sửa tay):

| File sinh ra | Dùng cho |
|---|---|
| `src/menu/TGIRR_CAD.mnu` (+ 2 bundle) | menu kéo xuống ZWCAD/GstarCAD |
| `src/shared/ToolCatalog.generated.cs` (+ 2 bản port, 1 bản link vào Ribbon) | palette, Quick Tools, nút + tooltip Ribbon |
| bảng giữa 2 marker `GENERATED COMMAND TABLE` trong tài liệu này | tài liệu lệnh |

Mã nguồn palette thật nằm ở `src/shared/` (`PaletteCommands.cs`, `PaletteContent.cs`, `PaletteState.cs`);
`src/zwcad/` và `src/gscad/` là bản port tự động (thay namespace + tên host), nên **không sửa trực tiếp**
hai file `Palette*.cs` trong đó. `scripts/port-verify.ps1` và `tests/Palette.Regression` sẽ báo lỗi nếu
bản port hoặc menu/tài liệu bị lệch khỏi nguồn.

## Chi tiết lệnh VDNG (Rải dây nhỏ giọt trong Boundary)
- **Lệnh gọi**: `VDNG`.
- **Mục đích**: Rải các đường dây nhỏ giọt song song bên trong một hoặc nhiều Boundary kín (`LWPOLYLINE` hoặc `CIRCLE`), tất cả đặt trên Layer chuẩn `TG-DRIP` (màu 34, tự tạo nếu chưa có).
- **Tham số trong hộp thoại**:
  - **Khoảng lùi từ biên**: offset một đường bao phía trong (giữ lại trên bản vẽ để nối các đầu dây). Mặc định 0.1m.
  - **Khoảng cách giữa dây**: bước rải song song. Mặc định 0.33m.
  - **Đơn vị nhập**: tự động theo `INSUNITS` của bản vẽ hoặc chọn tay mm/cm/m.
- **Tùy chọn**:
  - **Chọn hướng dây trên bản vẽ (2 điểm)**: mặc định hướng dây lấy theo **trục dài của Boundary** (hàng dây thẳng chạy song song chiều dài ô); nếu tick chọn, sau khi bấm `RẢI DÂY` lệnh quay lại bản vẽ để chỉ 2 điểm xác định hướng rải (góc hiển thị trong hộp thoại khi mở lại). Hướng được **ghi nhớ giữa các lần chạy**; bấm nút **"XÓA HƯỚNG ĐÃ CHỌN"** để xóa hướng cũ khi sang ô/bồn khác có hướng khác (nút chỉ bật khi đang có hướng đã chọn).
  - **Offset từ cạnh chuẩn**: tick chọn rồi bấm `RẢI DÂY`, lệnh yêu cầu **pick 1 điểm trên cạnh của Boundary**:
    - Pick vào **cạnh thẳng** (kể cả cạnh nằm chéo/xiên): hướng dây lấy theo cạnh đó và các hàng dây **offset song song xuất phát từ chính cạnh chuẩn** với bước = khoảng cách dây, cắt gọn trong vùng lùi.
    - Pick vào **cung (cạnh cong)**: dây **bám cong song song theo cung** — mỗi hàng là một cung đồng tâm với cạnh chuẩn, cách nhau đúng khoảng cách dây, hai đầu được kéo dài cắt gọn vào biên vùng. Chế độ này tự tắt zigzag (dây cong vốn đã liên tục).
    - Nếu điểm pick không gần cạnh thẳng/cung nào — hoặc **bấm `Esc`/chuột phải để bỏ qua bước pick** — lệnh tự quay về hướng tự động (trục dài của Boundary) và báo trên command line, **không thoát lệnh**.
  - **Nối dây liên tục kiểu zigzag**: gom toàn bộ các đoạn dây của mỗi Boundary thành **1 Polyline duy nhất** đi kiểu "rắn bò" (hàng chẵn đi xuôi, hàng lẻ đi ngược, cuối hàng này nối thẳng sang đầu hàng kế) — đúng cách thả một cuộn dây thực tế, dễ đo tổng mét dây. Tắt thì mỗi hàng là các đoạn rời.
  - **Ghi chú thông số + tổng chiều dài dây**: mỗi vùng rải có **1 ghi chú TEXT nằm gọn bên trong bound** của vùng đó — canh giữa hàng dây dài nhất, xoay theo hướng dây, chiều cao chữ tự giới hạn theo khoảng cách dây để không tràn ra ngoài; nội dung ghi khoảng cách dây và chiều dài dây của vùng. Đồng thời in **tổng chiều dài toàn bộ** ra command line phục vụ bóc khối lượng.
- **Luôn rải hàng thẳng trong biên (mặc định)**: ô thẳng, ô chéo hay biên lượn sóng bất kỳ đều được rải bằng **các hàng dây THẲNG offset song song** (từ cạnh chuẩn do người dùng pick, hoặc theo hướng tự động = trục dài của Boundary), bước = khoảng cách dây, hai đầu cắt gọn trong vùng lùi. Lệnh **KHÔNG tự offset cả biên vào trong**. Chế độ **bám cong** kích hoạt khi người dùng chủ động **pick vào một cạnh cung** làm cạnh chuẩn, **hoặc TỰ ĐỘNG** với ô dải dài hẹp có biên cong (tỉ lệ dài/rộng ≥ 5): khi đó mỗi hàng là một cung đồng tâm song song cạnh dài nhất của biên, kéo dài cắt gọn vào biên vùng — dây lướt mượt theo độ cong của ô, không còn bị cắt chéo ở hai đầu ô hẹp. Số vùng bám cong được báo ở dòng tổng kết.
- **Hướng tự động = trục dài của Boundary**: hướng mặc định (không tick chọn hướng) được suy ra bằng **phân tích phương sai các điểm rời rạc hoá toàn biên** nên ô dài hẹp — kể cả khi biên vẽ bằng nhiều cạnh thẳng ngắn hoặc cung (ô cong, dải bám tuyến) — vẫn ra hàng dây thẳng chạy **song song chiều dài ô**, không bị nhặt theo một cạnh ngắn nào. Boundary không có cạnh thẳng (`CIRCLE`, bồn oval/bầu dục vẽ toàn cung hoặc bulge) cũng dùng chung cơ chế này: oval ra dây chạy dọc trục dài; hình tròn/gần tròn thì giữ hướng ngang như trước.
- **Xử lý thông minh**: Boundary hở ≥ 3 đỉnh được **tự đóng kín**; `CIRCLE` được tự quy về Polyline; biên có cung tròn (kể cả biên offset bo góc) được rời rạc hóa rồi rải bằng thuật toán scanline thuần túy (có 29 test hồi quy trong `tests/VDNG.Regression`).
- **Chẩn đoán**: nếu không tạo được dây nào, command line in cảnh báo kèm 3 nguyên nhân thường gặp (khoảng cách dây quá lớn so với bound, khoảng lùi quá lớn, sai đơn vị nhập).
- **Hoàn tác**: toàn bộ đối tượng tạo ra nằm trong 1 transaction → `UNDO` 1 bước.

## Chi tiết lệnh DOITEXT (Chuyển MText sang Text & Gom danh sách)

- **Lệnh gọi**: `DOITEXT`, `M2T` hoặc `MTEXT2TEXT`.
- **Mục đích**:
  1. Chuyển đổi các đối tượng `MTEXT` thành `TEXT` thông thường, bóc tách và làm sạch toàn bộ các mã định dạng nội bộ AutoCAD (`\f...;`, `\C...;`, `\H...;`, `\W...;`, `\p...;` paragraph, ngoặc `{...}`...), chuyển phân số/chỉ số `\S1^2;` về dạng `1/2`, bảo toàn ký hiệu Unicode/Symbol (`\U+xxxx`, `%%c`, `%%d`, `%%p`). Chỉ `\P` (chữ P hoa) mới được hiểu là xuống dòng — `\p` (chữ thường) là paragraph properties nên được bỏ, không sinh dòng rác.
  2. Hỗ trợ 2 chế độ linh hoạt:
     - **Gom danh sách (`List`)**: Quét chọn nhiều MText (hoặc cả Text), tự động sắp xếp theo thứ tự tọa độ từ trên xuống dưới (và từ trái sang phải), cho phép pick điểm chèn mới (hoặc bấm Enter để lấy điểm trên cùng làm gốc), nhập khoảng cách dòng (mặc định = 1.5 * chiều cao chữ). Tạo thành 1 cột danh sách các dòng Text thẳng hàng, đều đặn.
     - **Tại chỗ (`In-place`)**: Tách từng MText thành các dòng TEXT tại đúng vị trí, góc quay, layer, style, màu sắc (kể cả TrueColor), linetype, lineweight của MText gốc trên bản vẽ. Giữ đúng can le theo điểm bám dính của MText (mã 71: Top/Middle/Bottom × Left/Center/Right → TEXT 72/73 + điểm canh 11) nên chữ không bị xô lệch như khi đặt mặc định trái–baseline.
  3. Tùy chọn xóa hoặc giữ đối tượng MText gốc.
  4. Hỗ trợ `UNDO` 1 bước duy nhất.
  5. Tạo TEXT bằng `entmake` với thứ tự nhóm DXF chuẩn; nếu layer/text style của MText gốc không còn trong bản vẽ thì tự quay về layer hiện hành / text style hiện hành, và có đường dự phòng khi CAD từ chối nhóm can le. Số dòng tạo lỗi (nếu có) được báo ở dòng kết luận để kiểm tra.

## Chi tiết lệnh DOIMTEXT (Gộp nhiều Text thành 1 MText nhiều đoạn)

- **Lệnh gọi**: `DOIMTEXT`, `T2M` hoặc `TEXT2MTEXT`.
- **Mục đích**: Chiều ngược của `DOITEXT` — gộp các dòng `TEXT` đã chọn thành **một `MTEXT` nhiều đoạn** (mỗi TEXT là 1 đoạn, ngăn cách bằng `\P`) để có thể chèn thêm đoạn và `Enter` xuống dòng ngay trong cùng một đối tượng.
- **Cách chạy**:
  1. Chọn trước các `TEXT` cần gộp (hoặc chạy lệnh rồi quét chọn).
  2. Sắp xếp tự động từ trên xuống dưới, cùng hàng thì trái sang phải.
  3. Pick điểm chèn MTEXT — mặc định là **góc trên–trái của TEXT đầu tiên** (bấm `Enter` để nhận).
  4. Chọn xóa hoặc giữ các `TEXT` gốc.
- **Bảo toàn**: layer, text style, màu (kể cả TrueColor), linetype, lineweight, chiều cao chữ, góc xoay của TEXT đầu tiên; điểm bám dính của MTEXT là Top-Left.
- **Ký tự đặc biệt**: `\`, `{`, `}` trong nội dung TEXT được escape (`\\`, `\{`, `\}`) để MTEXT hiển thị nguyên văn.
- **Nội dung dài**: tự chia nội dung thành nhiều nhóm DXF 3 (250 ký tự) + nhóm 1, nên không bị giới hạn 255 ký tự.
- **Hoàn tác**: 1 bước `UNDO`.

## Chi tiết lệnh HBD (Vẽ đường bao cho Hatch cỏ)

- **Lệnh gọi**: `HBD`, `BH` hoặc `TGBOUND`.
- **Mục đích**: Tự động sinh đường bao Polyline khép kín cho các mảng Hatch cỏ (hoặc bất kỳ mảng Hatch nào), tự động gán vào Layer tiêu chuẩn `TG-BOUND` (màu 7, nét Continuous) để làm ranh giới rải dây nhỏ giọt (`VDNG`) hoặc bố trí béc tưới.
- **Đặc biệt (100% LWPOLYLINE)**: Tự động chuyển đổi toàn bộ các nét biên cong phức tạp kiểu `SPLINE` hoặc `REGION` thành `LWPOLYLINE` khép kín mượt mà, không bao giờ để lại nét Region hay Spline rác trên bản vẽ.
- **Cung tròn nằm liền trong Polyline (bulge)**: Với biên dạng Hatch cấu thành từ các đoạn `LINE`/`ARC`, lệnh **dựng trực tiếp một LWPOLYLINE khép kín kèm `bulge` cho từng cung tròn** — cung tròn nằm liền mạch trong polyline, **không còn tạo `LINE`/`ARC` rời rồi phải `JOIN`** (khắc phục tình trạng polyline không nối được với cung, nhất là trên AutoCAD khi lệnh `JOIN` không ghép cung vào polyline). Cung elip được rời rạc hóa, cung tròn được giữ chính xác bằng `bulge`.
- **Các chế độ chọn**:
  - **Chọn trước (PICKFIRST)**: Chọn trước các Hatch rồi gõ `HBD`, lệnh xử lý ngay lập tức.
  - **Quét chọn thông thường**: Quét chọn vùng, bộ lọc tự động nhận diện đúng các đối tượng HATCH.
  - **Tùy chọn `M` (Mẫu)**: Click 1 Hatch hoặc **quét chọn (window/crossing) nhiều Hatch mẫu** (dùng `ssget` nên quét chọn được nhiều đối tượng). Lệnh đọc Pattern, Layer và **Màu sắc thực tế (ACI, TrueColor, ByLayer)** của (các) mẫu, sau đó lọc các Hatch khớp với **bất kỳ mẫu nào** theo tiêu chí **chặt chẽ**: (1) cùng Màu + cùng Pattern, hoặc (2/3) cùng Layer chuyên dụng + cùng Pattern hoặc cùng Màu. Màu được quy đổi về RGB thật để so sánh (TrueColor và ACI cùng màu hiển thị vẫn khớp chính xác); Pattern phải trùng tên chính xác (không còn so khớp "chứa" gây nhầm lẫn như `AR-CONC` với `AR-CONCR`).
  - **Tùy chọn `T` (Tất cả)**: Tự động tìm toàn bộ Hatch trong Model Space.
  - **Tùy chọn `J` (Hợp nhất)**: Bật/tắt chế độ tự động hợp nhất (UNION) các đường bao giáp nhau hoặc chồng lấn thành 1 đường bao lớn duy nhất, tự triệt tiêu các vách ngăn ranh giới ở giữa. **Mặc định TẮT** — mỗi Hatch giữ nguyên 100% đường bao gốc (không biến dạng, không mất nét); chỉ bật khi thực sự cần gộp ranh giáp. Ngoài ra các đường bao chỉ được "đóng kín" khi điểm đầu–cuối trùng nhau; đường hở được giữ nguyên thay vì nối tắt làm méo nét.
  - **Tùy chọn `D` (Đảo)**: Chuyển đổi giữa chế độ *Chỉ lấy đường bao ngoài* (tự động loại bỏ các lỗ khoét/đảo nhỏ bên trong nhưng bảo tồn 100% các thảm cỏ độc lập) hoặc *Lấy tất cả đường bao*.
  - **Tùy chọn `L` (Layer)**: Đổi layer đích theo ý muốn (mặc định: `TG-BOUND`).
- **Hoàn tác**: Hỗ trợ `UNDO` 1 bước duy nhất cho toàn bộ đối tượng vừa tạo.

## Chi tiết lệnh SP2PL (Chuyển Spline / Region sang Polyline)

- **Lệnh gọi**: `SP2PL`, `REG2PL` hoặc `C2PL`.
- **Mục đích**: Quét chọn bất kỳ đối tượng `SPLINE`, `REGION`, `ELLIPSE` có sẵn trên bản vẽ (hoặc do các lệnh cũ sinh ra), tự động rời rạc hóa và chuyển đổi thành `LWPOLYLINE` khép kín chuẩn trên đúng Layer và Màu sắc của đối tượng gốc.

## Chi tiết lệnh CVPL (Convert mọi loại đường sang Polyline)

- **Lệnh gọi**: `CVPL` hoặc `CVP` (convert + **xóa đối tượng nguồn**); `CVPLG` hoặc `CV2PL` (**giữ nguyên đối tượng nguồn**, chỉ tạo thêm polyline).
- **Mục đích**: Chuyển đổi hàng loạt các đối tượng dạng đường/cong sau thành `LWPOLYLINE`:
  - `LINE` → polyline 2 đỉnh.
  - `ARC` → polyline 1 đoạn **chính xác tuyệt đối** bằng bulge (không rời rạc hóa).
  - `CIRCLE` → polyline khép kín 4 đoạn bulge chính xác.
  - `ELLIPSE`, `SPLINE` → rời rạc hóa 128 điểm mẫu (biến `*CVPL:samples*` chỉnh được), tự nhận khép kín nếu điểm đầu–cuối trùng.
  - `POLYLINE` kiểu cũ (2D/3D, entity `POLYLINE` + `VERTEX`) → dựng lại thành `LWPOLYLINE` giữ nguyên đỉnh + bulge + trạng thái khép kín.
  - `REGION` → dùng thuật toán union/explode của `HBD.lsp` (tự nạp kèm qua loader).
- **Bảo toàn thuộc tính**: Layer, màu (ACI/ByLayer), kiểu nét (linetype), linetype scale, nét vẽ (lineweight) và elevation của đối tượng nguồn.
- **Chọn đối tượng**: hỗ trợ chọn trước (PICKFIRST) hoặc quét chọn; đối tượng đã là `LWPOLYLINE` được tự bỏ qua và đếm vào mục "bỏ qua".
- **Hoàn tác**: toàn bộ thao tác nằm trong 1 undo mark → `UNDO` 1 bước.
- **Khác biệt với SP2PL**: `SP2PL` chỉ nhận SPLINE/REGION/ELLIPSE và luôn giữ nguồn; `CVPL` nhận đủ LINE/ARC/CIRCLE/POLYLINE cũ và mặc định xóa nguồn cho gọn bản vẽ.

## Chi tiết lệnh JH (Gộp Hatch phân mảnh thành 1)

- **Lệnh gọi**: `JH`, `MH` hoặc `JOINHATCH`.
- **Mục đích**: Khi một thảm cỏ lớn bị chia cắt/phân mảnh thành nhiều Hatch con giáp ranh nhau:
  1. Quét chọn các Hatch cần gộp (hoặc chọn trước).
  2. Lisp tự động sinh boundary và dùng giải thuật **Region Union** để triệt tiêu toàn bộ các đường ranh giới tiếp giáp bên trong.
  3. Tạo 1 đối tượng **HATCH mới duy nhất** liền mạch bao trọn khu vực (giữ nguyên Pattern, Scale, Layer của mảng cỏ).
  4. Tạo 1 **đường bao Boundary Polyline chung duy nhất** đặt trên layer `TG-BOUND`.
  5. Xóa các Hatch con phân mảnh cũ, giúp bản vẽ gọn gàng, nhẹ và liền mạch.
- **Hoàn tác**: Hỗ trợ `UNDO` 1 bước duy nhất.

## Chi tiết lệnh TNET (Tạo nét vẽ có chữ)

- **Lệnh gọi**: `TNET`.
- **Mục đích**: Mở hộp thoại thiết kế nét vẽ có chữ (file LIN), xem trước trực tiếp và nạp thẳng vào bản vẽ.
- **Tự căn chữ cân đối**: hộp thoại **tự đo chiều dài vùng chữ ngay trong CAD** (dùng DBText tạm với đúng Text Style + tỷ lệ chữ, đo `GeometricExtents` trong transaction không commit nên không để lại đối tượng, không bẩn undo). Theo đúng ngữ nghĩa file LIN, phần tử chữ **không chiếm chiều dài chu kỳ** — khoảng trống dành cho chữ nằm trong "khoảng trống sau chữ", nên:
  - Chữ cân giữa hai đoạn gạch khi **khoảng sau = khoảng trước + chiều dài vùng chữ**.
  - Checkbox **"Tự căn chữ cân giữa hai đoạn gạch"** tự đặt khoảng sau theo công thức trên mỗi khi gõ chữ/đổi thông số.
  - Nút **"Áp dụng khoảng cách đẹp"** căn theo chiều dài chữ đo được và in lại phép tính để kiểm tra.
  - Nếu khoảng sau nhỏ hơn mức cần thiết, dòng gợi ý in **CẢNH BÁO gạch sẽ đè lên chữ**; khi nạp một nét có sẵn bị lệch, hộp thoại tự căn lại khoảng sau.
- **Xem trước**: 3 chu kỳ nét mô phỏng đúng ngữ nghĩa LIN (chữ không chiếm chỗ chu kỳ) nên nếu thông số sai sẽ thấy ngay hiện tượng gạch đè chữ ngay trong hộp thoại.
- **Chế độ lưu**: tạo nét mới/phiên bản `_V2` hoặc cập nhật định nghĩa gốc trong file LIN; tùy chọn chuyển đối tượng dùng nét cũ sang nét mới (toàn bản vẽ hoặc chỉ đối tượng đang chọn).

## Chi tiết lệnh TGIRRBAR (Thanh công cụ icon native)

- **Lệnh gọi**: `TGIRRBAR` hoặc `TGIRRTB`.
- **Mục đích**: bật **thanh công cụ native của CAD** (không phải palette WPF) chứa toàn bộ lệnh dưới dạng nút icon — dock trái/phải/trên được, kéo thả tự do, đổi được icon nhỏ/lớn bằng chuột phải, vị trí được CAD tự nhớ trong workspace.
- **Cơ chế**: section `***TOOLBARS` trong [src/menu/TGIRR_CAD.mnu](../src/menu/TGIRR_CAD.mnu) — mỗi lệnh là một `_Button("Nhãn", "TAG.bmp", "TAG_L.bmp")`, tooltip lấy từ `***HELPSTRINGS` (dùng chung ID với menu kéo xuống).
- **Lệnh tự làm 3 việc**:
  1. Thêm thư mục chứa `.mnu` + icon BMP vào **Support File Search Path** (biến `ACAD`) nếu chưa có — nhờ vậy CAD tìm được ảnh nút.
  2. `MENULOAD` file `TGIRR_CAD.mnu` nếu menu group `TGIRR` chưa nạp (đã nạp thì bỏ qua, không nạp trùng).
  3. Bật thanh công cụ `TB_TGIRR` (`-TOOLBAR ... _Show`).
- **Tìm thư mục**: ưu tiên thư mục đã có trong Support Path; nếu không, dùng thư mục gốc mà loader đã lưu (`TGIRR:LISP-DIR`, `*TGIRR:G-ROOT*`, `*TGIRR:ZW-ROOT*`) và thư mục `\Lisp` của nó.
- **Icon**: sinh tự động bằng `scripts/gen-icons.ps1` → `src/menu/icons/<TAG>.bmp` (16×16) và `<TAG>_L.bmp` (32×32); nền tối, viền + chữ màu theo nhóm lệnh (Cyan/Green/Amber). Thêm/bớt lệnh chỉ cần sửa `tools.json` rồi chạy `gen-icons.ps1` + `gen-catalog.ps1`.
- **Nếu CAD không bật được toolbar** (một số bản chặn `-TOOLBAR`): lệnh in hướng dẫn gõ `TOOLBAR`, chọn thanh **TGIRR CAD** rồi bấm *Show*.

## Ghi chú về nền tảng
 
- **AutoCAD:** Toàn bộ công cụ hiển thị trên thanh Ribbon (tab **TGIRR CAD LISP**).
- **ZWCAD & GstarCAD:** **KHÔNG DÙNG RIBBON** (do không hỗ trợ API Ribbon như AutoCAD). Thay vào đó, toàn bộ công cụ được hiển thị trên bảng công cụ neo **`TGIRRPALETTE`** (dockable WPF Palette — tự nhớ vị trí/kích thước/trạng thái neo giữa các phiên CAD, lưu ở `%APPDATA%\TGIRR\palette-state.txt`) và menu kéo xuống `TGIRR_CAD.mnu`. Mỗi nút có sao ☆/★ để **ghim vào palette "TGIRR QUICK TOOLS" RIÊNG** (dockable độc lập, bật/tắt bằng `TGIRRQUICK`; danh sách ghim lưu ở `%APPDATA%\TGIRR\quick-tools.txt`, vị trí/kích thước/dock lưu ở `quick-palette-state.txt`).
- **SBS, HBD, JH, TL, TGN, TGL, CVPL** được viết bằng AutoLISP; **CPLUS, VDNG, TNET** được viết bằng .NET.
- Các lệnh Lisp có thể nạp tự động qua loader tương ứng:
  - AutoCAD: `TGIRRLoader.lsp`
  - ZWCAD: `TGIRRLoaderZ.lsp` (gõ `TGIRRLOAD`)
  - GstarCAD: `TGIRRLoaderG.lsp` (gõ `TGIRRLOAD`)

Mỗi nút trên Ribbon / Palette đều có tooltip tiếng Việt chi tiết hướng dẫn cách sử dụng và cú pháp lệnh.


### Thêm Layer vào kho bằng TGLADD

Gõ TGLADD, nhập tên Layer, mã màu ACI và tên linetype. Mẫu được lưu theo tài khoản Windows và tự áp dụng mỗi lần chạy TGL; nếu linetype chưa được nạp, Layer vẫn được lưu và sẽ gán nét sau khi nạp file LIN.
