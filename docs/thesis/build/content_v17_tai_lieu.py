"""K7 (v16 -> v17): danh mục tài liệu tham khảo, bổ sung bảng chữ viết tắt.

Chạy theo quy trình ghi ở đầu renumber_citations_v17.py (đánh số lại trích dẫn TRƯỚC, builder SAU).
Danh mục lấy nguyên văn dòng đầu của từng mục trong docs/thesis/references.md (bỏ các dòng Kiểm chứng/Dùng cho),
chỉ đổi nhãn [n] sang số mới; thứ tự và tập mục do renumber_citations_v17.py quyết định.
Các sửa ô của dòng viết tắt đã có (CMAP, BCE, RFM, SROIE, UQ) nằm ở renumber_citations_v17.py (fix-abbr).
"""
import importlib.util
from pathlib import Path

_here = Path(__file__).resolve()
_spec = importlib.util.spec_from_file_location("renumber_citations_v17", _here.with_name("renumber_citations_v17.py"))
_ren = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_ren)

_entries = _ren.parse_references(_here.parents[1] / "references.md")
for _old in _ren.KEPT_OLD:
    assert "*" not in _entries[_old], _old  # builder coi * là chữ nghiêng

REFERENCE_BLOCKS = [("p", f"[{new}] {_entries[old]}") for old, new in sorted(_ren.MAP.items(), key=lambda kv: kv[1])]

SESSION_TAG = None
SECTIONS = {}

HEADING_PLACEHOLDERS = {
    "TÀI LIỆU THAM KHẢO": REFERENCE_BLOCKS,
    # dòng nhắc "[T7.9] Danh mục khởi tạo..." bị xóa (không còn nội dung thay thế)
    "DANH MỤC CÁC KÝ HIỆU VÀ CHỮ VIẾT TẮT": [],
}

# (viết tắt, tiếng Anh, tiếng Việt): từ viết tắt thân bài dùng mà bảng còn thiếu. builder tự chèn theo thứ tự A-Z.
ABBREVIATIONS = [
    ("AJAX", "Asynchronous JavaScript and XML", "Kỹ thuật gửi yêu cầu bất đồng bộ từ trang web, không tải lại cả trang"),
    ("ASCII", "American Standard Code for Information Interchange", "Bảng mã ký tự chuẩn của Hoa Kỳ"),
    ("BIDE", "BI-Directional Extension", "Thuật toán khai phá mẫu tuần tự đóng"),
    ("CDN", "Content Delivery Network", "Mạng phân phối nội dung"),
    ("CM-SPADE", "Co-occurrence MAP SPADE", "SPADE kèm bản đồ đồng xuất hiện"),
    ("CPU", "Central Processing Unit", "Bộ xử lý trung tâm"),
    ("CSRF", "Cross-Site Request Forgery", "Tấn công giả mạo yêu cầu liên trang"),
    ("CUDA", "Compute Unified Device Architecture", "Nền tảng tính toán song song trên GPU của NVIDIA"),
    ("DFS", "Depth-First Search", "Duyệt theo chiều sâu"),
    ("DOI", "Digital Object Identifier", "Mã định danh đối tượng số"),
    ("EXIF", "Exchangeable Image File Format", "Thông tin đi kèm ảnh, như chiều xoay"),
    ("F1", "F1 score", "Độ đo F1, trung bình điều hòa của độ chính xác và độ phủ"),
    ("GB", "Gigabyte", "Đơn vị dung lượng dữ liệu"),
    ("Hmean", "Harmonic mean", "Trung bình điều hòa, độ đo của SROIE, tương đương F1"),
    ("HS256", "HMAC using SHA-256", "Thuật toán ký JWT bằng HMAC và SHA-256"),
    ("HTML", "HyperText Markup Language", "Ngôn ngữ đánh dấu siêu văn bản"),
    ("ID", "Identifier", "Mã định danh"),
    ("IIT-CDIP", "Illinois Institute of Technology Complex Document Information Processing", "Bộ ảnh tài liệu quét tiếng Anh dùng để tiền huấn luyện"),
    ("ISBN", "International Standard Book Number", "Mã số sách tiêu chuẩn quốc tế"),
    ("JOSE", "JSON Object Signing and Encryption", "Bộ chuẩn ký và mã hóa đối tượng JSON"),
    ("JPEG", "Joint Photographic Experts Group", "Định dạng ảnh nén JPEG"),
    ("JVM", "Java Virtual Machine", "Máy ảo Java"),
    ("LTS", "Long-Term Support", "Bản phát hành hỗ trợ dài hạn"),
    ("MB", "Megabyte", "Đơn vị dung lượng dữ liệu"),
    ("MSSV", "–", "Mã số sinh viên"),
    ("NFC", "Normalization Form C", "Dạng chuẩn hóa Unicode NFC (ký tự tổ hợp sẵn)"),
    ("PDF", "Portable Document Format", "Định dạng tài liệu di động"),
    ("PIN", "Personal Identification Number", "Mã số nhận dạng cá nhân"),
    ("PNG", "Portable Network Graphics", "Định dạng ảnh PNG"),
    ("QR", "Quick Response", "Mã phản hồi nhanh"),
    ("RAM", "Random Access Memory", "Bộ nhớ truy cập ngẫu nhiên"),
    ("RGB", "Red, Green, Blue", "Hệ màu đỏ, lục, lam"),
    ("RIVF", "RIVF International Conference on Computing and Communication Technologies", "Hội nghị quốc tế RIVF về công nghệ tính toán và truyền thông"),
    ("SQL", "Structured Query Language", "Ngôn ngữ truy vấn có cấu trúc"),
    ("STT", "–", "Số thứ tự"),
    ("SynthDoG", "Synthetic Document Generator", "Bộ sinh ảnh tài liệu tổng hợp của DONUT"),
    ("TCP", "Transmission Control Protocol", "Giao thức điều khiển truyền vận"),
    ("UDP", "User Datagram Protocol", "Giao thức gói dữ liệu người dùng"),
    ("URI", "Uniform Resource Identifier", "Định danh tài nguyên thống nhất"),
    ("URL", "Uniform Resource Locator", "Địa chỉ tài nguyên thống nhất"),
    ("UTC", "Coordinated Universal Time", "Giờ phối hợp quốc tế"),
    ("XLM-R", "Cross-lingual Language Model RoBERTa", "Mô hình ngôn ngữ đa ngôn ngữ XLM-RoBERTa"),
]
