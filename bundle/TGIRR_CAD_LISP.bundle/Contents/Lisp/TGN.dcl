tgn_settings : dialog {
  label = "TGIRR - Đánh số đối tượng / vùng tưới";
  : boxed_radio_column {
    label = "Phạm vi đánh số";
    : radio_button { key = "mode_objects"; label = "Đối tượng được chọn"; }
    : radio_button { key = "mode_regions"; label = "Vùng tưới (Polyline kín / Circle)"; }
  }
  : row {
    : boxed_column {
      label = "Quy luật số";
      : edit_box { key = "start"; label = "Số bắt đầu:"; edit_width = 12; }
      : edit_box { key = "step"; label = "Bước nhảy:"; edit_width = 12; }
    }
    : boxed_column {
      label = "Kích thước nhãn";
      : edit_box { key = "width"; label = "Độ rộng khung:"; edit_width = 12; }
      : edit_box { key = "height"; label = "Chiều cao khung:"; edit_width = 12; }
      : edit_box { key = "text_height"; label = "Chiều cao chữ:"; edit_width = 12; }
    }
  }
  : boxed_column {
    label = "Thứ tự đánh số";
    : popup_list {
      key = "order";
      width = 45;
      value = "0";
      list = "Theo thứ tự chọn\nTrái sang phải, trên xuống dưới\nTrên xuống dưới, trái sang phải\nTheo đường dẫn Polyline";
    }
  }
  : text { key = "hint"; label = "Có thể quét chọn nhiều đối tượng. Khung là hình tròn khi độ rộng bằng chiều cao."; }
  : text { key = "error"; label = ""; fixed_width = true; width = 75; }
  spacer;
  ok_cancel;
}
