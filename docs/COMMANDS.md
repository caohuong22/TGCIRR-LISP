# Danh sách lệnh TGIRR CAD LISP

Dưới đây là toàn bộ lệnh **hiện đang hoạt động** trong tab Ribbon **TGIRR CAD LISP**. Mỗi lệnh đều có nút trên Ribbon; các lệnh đánh dấu "Có" cũng có thể gõ trực tiếp từ dòng lệnh AutoCAD.

| Nhóm (Panel) | Lệnh | Chức năng | Gõ trực tiếp? |
|---|---|---|---|
| CHỌN | SBS | Chọn đối tượng giống mẫu nằm phần lớn trong Polyline kín | Có (`SBS`) |
| ĐO | TL | Cộng tổng chiều dài các đường đã chọn trước | Có (`TL`) |
| VĂN BẢN | CPLUS | Copy TEXT/MTEXT/Multileader/Attribute/Dimension Override theo số, chữ A–Z hoặc danh sách | Có (`CPLUS`) |
| ĐÁNH SỐ | TGN | Đánh số đối tượng / vùng tưới bằng nhãn tròn/ellipse | Có (`TGN`) |
| LAYER | TGL | Tạo bộ Layer tiêu chuẩn và đặt `TG-DRIP` làm layer hiện hành | Có (`TGL`) |
| TƯỚI | VDNG | Vẽ dây nhỏ giọt bên trong Boundary kín (tự tạo layer `TG-DRIP`) | Có (`VDNG`) |
| NÉT VẼ | TNET | Mở hộp thoại tạo/chỉnh sửa nét vẽ có chữ (file LIN) | Có (`TNET`) |

## Ghi chú

- **SBS, TL, TGN, TGL** được viết bằng AutoLISP; **CPLUS, VDNG, TNET** được viết bằng .NET (plugin Ribbon).
- Nút Ribbon cho `TNET` đi qua lệnh `TNET` nên có thể gõ trực tiếp từ dòng lệnh.
- Các lệnh Lisp có thể nạp độc lập bằng `APPLOAD` file `TGIRRLoader.lsp` (tự nạp các file Lisp cùng thư mục).

Mỗi nút Ribbon có tooltip tiếng Việt chi tiết. Hãy thử trên bản vẽ sao lưu và dùng `UNDO` sau mỗi thao tác trong lần kiểm tra đầu tiên.
