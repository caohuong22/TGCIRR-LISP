# Danh sách lệnh TGIRR CAD LISP

Dưới đây là toàn bộ lệnh **hiện đang hoạt động** trong tab Ribbon **TGIRR CAD LISP**. Mỗi lệnh đều có nút trên Ribbon; các lệnh đánh dấu "Có" cũng có thể gõ trực tiếp từ dòng lệnh AutoCAD.

| Nhóm (Panel) | Lệnh | Chức năng | Gõ trực tiếp? |
|---|---|---|---|
| CHỌN | SBS | Chọn đối tượng giống mẫu nằm phần lớn trong Polyline kín | Có (`SBS`) |
| RANH GIỚI | HBD | Vẽ đường bao Polyline (Boundary) quanh Hatch cỏ, tự gán Layer `TG-BOUND` | Có (`HBD`, `BH`, `TGBOUND`) |
| RANH GIỚI | JH | Gộp các Hatch phân mảnh giáp nhau thành 1 Hatch duy nhất + 1 Boundary chung | Có (`JH`, `MH`, `JOINHATCH`) |
| ĐO | TL | Cộng tổng chiều dài các đường đã chọn trước | Có (`TL`) |
| VĂN BẢN | CPLUS | Copy TEXT/MTEXT/Multileader/Attribute/Dimension Override theo số, chữ A–Z hoặc danh sách | Có (`CPLUS`) |
| ĐÁNH SỐ | TGN | Đánh số đối tượng / vùng tưới bằng nhãn tròn/ellipse | Có (`TGN`) |
| LAYER | TGL | Tạo bộ Layer tiêu chuẩn và đặt `TG-DRIP` làm layer hiện hành | Có (`TGL`) |
| TƯỚI | VDNG | Vẽ dây nhỏ giọt bên trong Boundary kín (tự tạo layer `TG-DRIP`) | Có (`VDNG`) |
| NÉT VẼ | TNET | Mở hộp thoại tạo/chỉnh sửa nét vẽ có chữ (file LIN) | Có (`TNET`) |

## Chi tiết lệnh HBD (Vẽ đường bao cho Hatch cỏ)

- **Lệnh gọi**: `HBD`, `BH` hoặc `TGBOUND`.
- **Mục đích**: Tự động sinh đường bao Polyline khép kín cho các mảng Hatch cỏ (hoặc bất kỳ mảng Hatch nào), tự động gán vào Layer tiêu chuẩn `TG-BOUND` (màu 7, nét Continuous) để làm ranh giới rải dây nhỏ giọt (`VDNG`) hoặc bố trí béc tưới.
- **Các chế độ chọn**:
  - **Chọn trước (PICKFIRST)**: Chọn trước các Hatch rồi gõ `HBD`, lệnh xử lý ngay lập tức.
  - **Quét chọn thông thường**: Quét chọn vùng, bộ lọc tự động nhận diện đúng các đối tượng HATCH.
  - **Tùy chọn `M` (Mẫu)**: Chọn 1 Hatch cỏ mẫu, lệnh đọc Pattern và Layer của mẫu, sau đó cho phép quét chọn nhanh các mảng cỏ cùng loại mà không sợ chọn nhầm các hatch khác (như gạch lát, đường dạo...).
  - **Tùy chọn `T` (Tất cả)**: Tự động tìm toàn bộ Hatch trong Model Space.
  - **Tùy chọn `J` (Hợp nhất)**: Bật/tắt chế độ tự động hợp nhất (UNION) các đường bao giáp nhau hoặc chồng lấn thành 1 đường bao lớn duy nhất, tự triệt tiêu các vách ngăn ranh giới ở giữa.
  - **Tùy chọn `D` (Đảo)**: Chuyển đổi giữa chế độ *Chỉ lấy đường bao ngoài lớn nhất* (tự động loại bỏ các lỗ khoét/đảo nhỏ bên trong) hoặc *Lấy tất cả đường bao*.
  - **Tùy chọn `L` (Layer)**: Đổi layer đích theo ý muốn (mặc định: `TG-BOUND`).
- **Hoàn tác**: Hỗ trợ `UNDO` 1 bước duy nhất cho toàn bộ đối tượng vừa tạo.

## Chi tiết lệnh JH (Gộp Hatch phân mảnh thành 1)

- **Lệnh gọi**: `JH`, `MH` hoặc `JOINHATCH`.
- **Mục đích**: Khi một thảm cỏ lớn bị chia cắt/phân mảnh thành nhiều Hatch con giáp ranh nhau:
  1. Quét chọn các Hatch cần gộp (hoặc chọn trước).
  2. Lisp tự động sinh boundary và dùng giải thuật **Region Union** để triệt tiêu toàn bộ các đường ranh giới tiếp giáp bên trong.
  3. Tạo 1 đối tượng **HATCH mới duy nhất** liền mạch bao trọn khu vực (giữ nguyên Pattern, Scale, Layer của mảng cỏ).
  4. Tạo 1 **đường bao Boundary Polyline chung duy nhất** đặt trên layer `TG-BOUND`.
  5. Xóa các Hatch con phân mảnh cũ, giúp bản vẽ gọn gàng, nhẹ và liền mạch.
- **Hoàn tác**: Hỗ trợ `UNDO` 1 bước duy nhất.

## Ghi chú

- **SBS, HBD, JH, TL, TGN, TGL** được viết bằng AutoLISP; **CPLUS, VDNG, TNET** được viết bằng .NET (plugin Ribbon).
- Nút Ribbon cho `TNET` đi qua lệnh `TNET` nên có thể gõ trực tiếp từ dòng lệnh.
- Các lệnh Lisp có thể nạp độc lập bằng `APPLOAD` file `TGIRRLoader.lsp` (tự nạp các file Lisp cùng thư mục).

Mỗi nút Ribbon có tooltip tiếng Việt chi tiết. Hãy thử trên bản vẽ sao lưu và dùng `UNDO` sau mỗi thao tác trong lần kiểm tra đầu tiên.
