# Nội dung phiên T7.4: Chương 4 – Cài đặt hệ thống (4.1–4.10).
# Đối chiếu ngày 26/10/2026 với working tree: core-backend/pom.xml, core-backend/Dockerfile, mobile-app/pubspec.yaml,
# ai-service/{requirements.txt, Dockerfile, .dockerignore, ai_service.py (đã chuyển sang V5), receipt_postprocess.py (T5,
# đã nối vào /donut/scan, test_receipt_postprocess.py)}, docker-compose.yml, deploy/caddy/Caddyfile, .github/workflows/ci.yml,
# ai-service/Version5/{train_model.py, model_config.py, labels.py, relabel_*.py, apply_claude_labels.py, finish_relabel.py,
# find_v3_seen.py, data1/*/metadata.jsonl, relabel/*.csv, v3_seen_test.txt, trainer_state.json, README.md},
# ai-service/donut-v5.ipynb, docs/thesis/v5_results.md, facts.md (số nhãn rỗng trước khi gán nhãn lại).
# Trích dẫn mới: [61] Qwen2.5-VL, [62] Claude vision, [63] Albumentations, [64] SGDR, [65] Mixed precision,
# [66] Gradient checkpointing, [67] Kaggle Notebooks, [68] Python re, [69] Pro Git, [70] Conventional Commits.
import json
from pathlib import Path

ROOT = Path("/home/triphan/Workspace/Deploy_Project")
PNG = str(ROOT / "docs/thesis/diagrams") + "/"
SESSION_TAG = "T7.4"
SRC = "nguồn: nhóm thực hiện"
NGUON = "Nguồn: nhóm thực hiện"


def vn(x, d=4):
    return f"{x:.{d}f}".replace(".", ",")


_STATE = json.loads((ROOT / "ai-service/Version5/trainer_state.json").read_text(encoding="utf-8"))
EVAL_ROWS = [
    [str(e["step"]), vn(e["epoch"], 2), vn(e["eval_field_exact"]), vn(e["eval_seller_exact"]),
     vn(e["eval_address_exact"]), vn(e["eval_timestamp_exact"]), vn(e["eval_total_cost_exact"])]
    for e in _STATE["log_history"] if "eval_field_exact" in e
]
for row in EVAL_ROWS:
    if row[0] == str(_STATE["best_global_step"]):
        row[:] = [f"**{c}**" for c in row]

VERSIONS = [
    ["Core Backend", "Java / Spring Boot", "21 / 3.2.5", "core-backend/pom.xml"],
    ["", "JJWT, springdoc-openapi, Cloudinary", "0.11.5, 2.5.0, 1.36.0", "core-backend/pom.xml"],
    ["", "Testcontainers (kiểm thử)", "1.21.4", "core-backend/pom.xml"],
    ["", "Image build / chạy", "maven:3.9.6-eclipse-temurin-21 / eclipse-temurin:21-jre-jammy", "core-backend/Dockerfile"],
    ["Mobile", "Flutter / Dart (máy phát triển)", "3.47.5 / 3.13.4 (ràng buộc SDK ^3.10.8)", "flutter --version; pubspec.yaml"],
    ["", "dio, flutter_bloc, get_it, sqflite", "^5.7.0, ^8.1.5, ^7.7.0, ^2.3.3+1", "mobile-app/pubspec.yaml"],
    ["", "fl_chart, google_mlkit_document_scanner, image_picker", "^0.68.0, 0.4.1, ^1.2.1", "mobile-app/pubspec.yaml"],
    ["AI Service", "Python (image)", "3.10 (python:3.10-slim)", "ai-service/Dockerfile"],
    ["", "FastAPI, uvicorn, transformers, torch (CPU), pillow, sentencepiece", "không ghim phiên bản", "ai-service/requirements.txt"],
    ["Huấn luyện", "Kaggle Notebook, GPU NVIDIA T4", "–", "ai-service/donut-v5.ipynb"],
    ["", "albumentations, accelerate, pytest", "2.0.8, theo Kaggle, theo Kaggle", "ai-service/donut-v5.ipynb"],
    ["", "Mô hình gốc", "naver-clova-ix/donut-base-finetuned-cord-v2", "Version5/model_config.py"],
    ["Hạ tầng", "PostgreSQL, Redis, MongoDB", "15-alpine, 8.10-alpine, 6.0", "docker-compose.yml"],
    ["", "Caddy (reverse proxy)", "2.8-alpine", "docker-compose.yml"],
    ["", "Docker Engine (máy phát triển), Maven", "29.1.3, 3.9.12", "docker --version; mvn -v"],
    ["Web Admin", "Thymeleaf (theo Spring Boot), Bootstrap, Font Awesome, Chart.js", "–, 5.3.0, 6.4.2, bản mới nhất từ CDN",
     "templates/admin/layout/_layout.html"],
    ["CI/CD", "GitHub Actions (Temurin 21, Flutter stable, Python 3.10)", "–", ".github/workflows/ci.yml"],
]

SECTIONS = {
    # ---------------------------------------------------------------- 4.1
    "GIỚI THIỆU": [
        ("p", "Chương 3 đã chốt kiến trúc, cơ sở dữ liệu, API và mô hình AI ở mức thiết kế. Chương này trình bày cách nhóm "
              "hiện thực các thiết kế đó: môi trường và công cụ phát triển, quy trình thu thập và gán nhãn lại tập ảnh hóa "
              "đơn, cấu hình huấn luyện DONUT phiên bản V5 trên Kaggle, rồi lần lượt phần cài đặt AI Service, Core Backend, "
              "ứng dụng di động, Web Admin và cách đóng gói toàn bộ hệ thống bằng Docker. Số liệu trong chương được lấy từ mã "
              "nguồn, tệp nhãn và nhật ký huấn luyện của nhóm; phần đánh giá mô hình trên tập kiểm thử được trình bày ở "
              "Chương 5."),
    ],
    # ---------------------------------------------------------------- 4.2
    "Môi trường phát triển": [
        ("p", "Hệ thống gồm ba mã nguồn độc lập trong một kho (monorepo): core-backend (Java), mobile-app (Dart) và "
              "ai-service (Python). Mỗi phần có công cụ build riêng: Maven cho Core Backend [31], Flutter SDK cho ứng dụng di "
              "động [33], pip và uvicorn cho AI Service [34]. Việc huấn luyện mô hình không chạy trên máy cá nhân mà trên "
              "Kaggle Notebook có GPU [67], còn các dịch vụ hạ tầng (PostgreSQL, Redis, MongoDB, Caddy) chạy bằng Docker "
              "Compose [38] cả ở máy phát triển lẫn máy chủ. Bảng 4.1 tổng hợp phiên bản các thành phần chính."),
        ("table", "Môi trường, công cụ và phiên bản sử dụng", "4", [1400, 2900, 2404, 1800],
         ["Phân hệ", "Thành phần", "Phiên bản", "Nguồn xác định"], VERSIONS, NGUON),
        ("p", "Hai điểm cần lưu ý. Thứ nhất, requirements.txt của AI Service không ghim phiên bản, nên mỗi lần build image có "
              "thể nhận bản transformers và torch mới hơn bản đã dùng khi kiểm thử; đây là rủi ro tái lập mà nhóm ghi nhận ở "
              "phần hạn chế. Thứ hai, torch được cài từ kho bánh xe chỉ dành cho CPU (tham số --extra-index-url) để image "
              "nhỏ hơn, vì máy chủ triển khai không có GPU."),
        ("y", "[Nhóm] Bổ sung phiên bản thư viện thực tế trên Kaggle (transformers, torch, CUDA) nếu còn log của notebook "
              "donut-v5.ipynb (lệnh pip list hoặc transformers.__version__)."),
    ],
    "Quản lý mã nguồn với Git và GitHub": [
        ("p", "Mã nguồn được quản lý bằng Git [69] trên một kho GitHub với nhánh chính main. Tính đến ngày 26/10/2026, nhánh "
              "main có 55 commit kể từ commit đầu tiên ngày 23/07/2026. Thông điệp commit theo quy ước Conventional Commits "
              "[70]: tiền tố cho biết loại thay đổi và phạm vi trong ngoặc cho biết phân hệ bị ảnh hưởng, ví dụ "
              "fix(backend), feat(mobile), docs(deploy). Trong 55 commit có 22 commit feat, 8 docs, 5 fix, 4 chore và số còn "
              "lại thuộc refactor, test, style, ci, build."),
        ("p", "Tệp .github/workflows/ci.yml định nghĩa quy trình tích hợp liên tục trên GitHub Actions [45]. Mỗi lần đẩy "
              "lên main hoặc mở pull request, ba job chạy song song: backend-ci (Temurin Java 21, lệnh mvn -B clean test), "
              "mobile-ci (Flutter kênh stable, flutter analyze và flutter test) và ai-ci (Python 3.10, pytest test_main.py). "
              "Job deploy chỉ chạy khi đẩy lên main, còn job release-apk chạy khi đẩy tag dạng v*, build APK đã ký và đưa "
              "lên GitHub Release. Chi tiết triển khai được trình bày ở mục 5.4."),
        ("p", "Một số tệp không được đưa vào Git theo chủ ý: trọng số mô hình (*.safetensors, khoảng 806 MB), thư mục ảnh "
              "data1, tệp .env chứa mật khẩu và application.yml. Các tệp này được chép thủ công lên máy chủ hoặc được tạo "
              "từ biến môi trường khi chạy."),
        ("y", "[Nhóm] Lịch sử commit hiện chỉ ghi một tác giả (TriPhan15). Nếu các thành viên khác làm việc trên máy riêng "
              "rồi gửi mã cho người commit, nêu rõ cách phối hợp này để khớp với bảng phân công nhiệm vụ."),
    ],
    # ---------------------------------------------------------------- 4.3
    "Thu thập dữ liệu": [
        ("p", "Tập dữ liệu dùng để huấn luyện có tên data1, gồm 6.351 ảnh hóa đơn bán lẻ tiếng Việt chụp bằng điện thoại, "
              "đã chia sẵn thành ba thư mục train (5.080 ảnh), validation (635 ảnh) và test (636 ảnh), tỉ lệ xấp xỉ "
              "80/10/10. Mỗi thư mục có tệp metadata.jsonl, mỗi dòng ứng với một ảnh, gồm tên tệp và chuỗi ground_truth "
              "chứa bốn trường SELLER, ADDRESS, TIMESTAMP, TOTAL_COST theo định dạng đã thiết kế ở mục 3.9.2. Ảnh có nhiều "
              "loại hóa đơn: siêu thị và cửa hàng tiện lợi (Co.opFood, VinCommerce, Circle K…), quán cà phê, nhà hàng, với "
              "độ dài rất khác nhau."),
        ("p", "Nhóm phân loại một hóa đơn là “dài” khi tỉ lệ chiều cao trên chiều rộng của ảnh lớn hơn 2,2 (hằng số "
              "LONG_RATIO trong Version5/labels.py, có xét chiều xoay EXIF). Tập train có 1.597 ảnh dài, suy ra từ số mẫu "
              "mỗi epoch là 6.677 khi mỗi ảnh dài được lặp hai lần. Hóa đơn dài là nhóm khó nhất: chữ nhỏ hơn sau khi thu ảnh "
              "về kích thước đầu vào cố định, và nhiều dòng số tiền làm mô hình dễ chọn nhầm tổng tiền."),
        ("y", "[Nhóm] Ghi rõ nguồn gốc và giấy phép của tập data1. Tên tệp cũ trong nhãn của V3 có dạng mcocr_*, gợi ý ảnh "
              "lấy từ tập MC-OCR 2021 [22]; xác nhận điều này, và cho biết nhóm có tự chụp thêm ảnh nào không (số lượng theo "
              "từng loại hóa đơn cho Bảng 1.2)."),
    ],
    "Gán nhãn dữ liệu": [
        ("p", "Khi bắt đầu chuẩn bị phiên bản V5, nhóm kiểm tra nhãn gốc và thấy nhãn bị thiếu rất nhiều: ở tập train có "
              "2.757 ảnh thiếu SELLER, 3.822 ảnh thiếu ADDRESS, 2.702 ảnh thiếu TIMESTAMP, 1.530 ảnh thiếu TOTAL_COST, và chỉ "
              "450 trong 5.080 ảnh có đủ cả bốn trường. Phần lớn ô trống không phải do hóa đơn thiếu thông tin mà do nhãn bị "
              "bỏ sót. Nếu huấn luyện trực tiếp, mô hình sẽ học thói quen trả chuỗi rỗng. Vì vậy, nhóm gán nhãn lại toàn bộ "
              "dữ liệu theo quy trình ở Hình 4.1, giữ nguyên nhãn gốc trong ai-service/data1 và ghi nhãn mới vào "
              "ai-service/Version5/data1."),
        ("fig", "Quy trình gán nhãn lại dữ liệu cho DONUT V5", "4", PNG + "ch4_gan_nhan.png", 10.5, SRC, None),
        ("p", "Bước đọc ảnh dùng hai mô hình thị giác – ngôn ngữ (VLM, Vision-Language Model) làm hai “ý kiến” độc lập. "
              "Mô hình thứ nhất là Qwen2.5-VL-7B-Instruct [61], chạy offline trên GPU Kaggle bằng thư viện transformers "
              "(relabel_qwen.py); mô hình này đã đọc hết tập test, validation và một phần tập train. Mô hình thứ hai là "
              "Claude [62], đọc ảnh theo từng lô và ghi kết quả vào các tệp relabel_cache/<split>.claude*.jsonl. Cả hai nhận "
              "cùng một lời nhắc (prompt) do relabel_common.build_prompt() tạo ra: chép nguyên văn tên cửa hàng và địa chỉ, "
              "chép ngày giờ đúng như in, chỉ lấy số tiền cuối cùng khách phải trả với dấu phân cách như in, để chuỗi rỗng khi "
              "hóa đơn không có thông tin, không đoán; lời nhắc kèm bốn ví dụ nhãn đầy đủ lấy từ chính tập dữ liệu. Câu trả "
              "lời được kiểm tra bằng mô hình Pydantic ReceiptFields [60], bắt buộc đủ bốn khóa, nên một câu trả lời sai khóa "
              "bị coi là lỗi chứ không bị hiểu thành bốn trường rỗng. Mọi câu trả lời được lưu vào bộ đệm, nên vòng lặp có thể "
              "dừng khi hết hạn mức gọi API rồi chạy tiếp ở phiên sau mà không đọc lại ảnh đã xong."),
        ("p", "Kết quả đọc được gộp vào nhãn bằng apply_claude_labels.py và finish_relabel.py (chạy lại nhiều lần vẫn cho cùng "
              "kết quả). Trường được đọc chắc chắn được ghi thẳng và coi như đã duyệt; trường mô hình tự đánh dấu là không "
              "chắc, hoặc hai nguồn cho giá trị khác nhau, được đưa vào công cụ dòng lệnh review_labels.py để người duyệt chọn "
              "giá trị đúng, đánh dấu hóa đơn không có thông tin đó, hoặc giữ nhãn cũ. finish_relabel.py còn áp một số quy ước "
              "thống nhất cách viết, ví dụ cùng một chuỗi cửa hàng phải có cùng một tên, và chuyển ngày viết bằng chữ về dạng "
              "số. Bảng 4.2 so sánh số ô trống trước và sau khi gán nhãn lại."),
        ("table", "Số nhãn rỗng trước và sau khi gán nhãn lại", "4", [1500, 1400, 1400, 1400, 1404, 1400],
         ["Tập", "SELLER rỗng", "ADDRESS rỗng", "TIMESTAMP rỗng", "TOTAL_COST rỗng", "Đủ 4 trường"],
         [["train (5.080)", "2.757 → 749", "3.822 → 1.104", "2.702 → 593", "1.530 → 53", "450 → 3.463"],
          ["validation (635)", "344 → 116", "480 → 162", "345 → 71", "197 → 8", "49 → 403"],
          ["test (636)", "348 → 104", "479 → 129", "320 → 69", "189 → 5", "59 → 443"]],
         "Nguồn: nhóm thực hiện, đếm từ ai-service/data1 (trước) và ai-service/Version5/data1 (sau) ngày 26/10/2026"),
        ("p", "Ngoài việc điền ô trống, quá trình này còn sửa các giá trị đã có nhưng sai: các tệp relabel/<split>.claude_changes.csv "
              "ghi lại 819 thay đổi ở tập train, 227 ở validation và 239 ở test, phần lớn ở SELLER, ADDRESS và TIMESTAMP "
              "(lỗi chính tả tên cửa hàng, thiếu dấu, sai giờ)."),
        ("y", "[Nhóm] Ghi số trường nhóm đã duyệt tay bằng review_labels.py và ai trong nhóm tham gia duyệt, để mô tả đầy "
              "đủ bước kiểm tra của con người."),
    ],
    "Chuẩn hóa và chia tập dữ liệu": [
        ("p", "Sau khi gán nhãn lại, mỗi ô còn trống mà chưa ai kiểm tra được ghi tên vào danh sách unverified_fields của dòng "
              "đó trong metadata.jsonl. Khi dựng chuỗi đích, hàm build_target() trong Version5/model_config.py thay token của "
              "các trường này bằng giá trị −100 (IGNORE_INDEX), nghĩa là bỏ qua khi tính hàm mất mát: mô hình không bị phạt "
              "nếu đọc ra một giá trị mà nhãn có thể đã bỏ sót. Trường rỗng đã được xác nhận là hóa đơn không có thông tin thì "
              "vẫn được tính loss, để mô hình học cách không bịa giá trị. Văn bản được chuẩn hóa Unicode NFC, gộp khoảng "
              "trắng; nhãn dài hơn 768 token bị báo lỗi thay vì cắt mất thẻ đóng (LabelTooLongError)."),
        ("p", "Cách chia train/validation/test giữ nguyên ba thư mục của data1 để có thể so sánh công bằng với V3 trên cùng "
              "một tập test. Tập validation 635 ảnh chỉ dùng để chọn checkpoint; vì mỗi lần đánh giá phải cho mô hình sinh "
              "chuỗi thật, train_model.py lấy ngẫu nhiên 150 ảnh validation với seed 42 (hàm val_subset) để giới hạn thời "
              "gian. Tập test 636 ảnh không tham gia huấn luyện hay chọn mô hình. Riêng V3 có thể đã gặp một số ảnh test khi "
              "huấn luyện, vì nhãn train cũ của V3 khác với bản chia hiện tại. find_v3_seen.py tìm những ảnh test có địa chỉ "
              "(dài hơn 15 ký tự, đã chuẩn hóa) trùng với một địa chỉ trong nhãn train cũ của V3 và ghi 21 ảnh vào "
              "v3_seen_test.txt; Chương 5 báo cáo kết quả cả khi có và khi bỏ 21 ảnh này. Bảng 4.3 tóm tắt ba tập."),
        ("table", "Ba tập dữ liệu dùng cho DONUT V5", "4", [1700, 1300, 2700, 2804],
         ["Tập", "Số ảnh", "Dòng có trường chưa kiểm tra", "Vai trò"],
         [["train", "5.080", "1.044 (1.385 trường)", "Huấn luyện; 1.597 ảnh dài được lặp 2 lần, 6.677 mẫu mỗi epoch, có tăng cường ảnh"],
          ["validation", "635", "165", "Chọn checkpoint, dùng 150 ảnh lấy ngẫu nhiên (seed 42)"],
          ["test", "636", "127", "Chỉ dùng để đánh giá ở Chương 5; 21 ảnh trong v3_seen_test.txt được báo cáo riêng"]],
         NGUON),
        ("p", "Ảnh train được tăng cường ngẫu nhiên bằng thư viện Albumentations [63] (hàm build_augment): xoay tối đa 10 độ "
              "với nền trắng, đổi độ sáng và độ tương phản, làm mờ Gauss và mờ chuyển động (mô phỏng rung tay khi chụp), nén "
              "JPEG chất lượng 40–90 (mô phỏng ảnh gửi qua ứng dụng nhắn tin) và thêm nhiễu Gauss, mỗi phép có xác suất từ 0,3 "
              "đến 0,5. Ảnh validation và test không bị tăng cường."),
    ],
    # ---------------------------------------------------------------- 4.4
    "Môi trường huấn luyện trên Kaggle": [
        ("p", "Mô hình được huấn luyện trên Kaggle Notebook [67] với GPU NVIDIA T4, bật Internet để tải mô hình gốc từ "
              "Hugging Face. Notebook donut-v5.ipynb nhận ba dataset đầu vào: Version5 (mã nguồn và nhãn đã sửa, vài MB), data1 "
              "(ảnh) và thư mục trọng số V3 để so sánh. Trước khi tốn giờ GPU, notebook chạy toàn bộ kiểm thử pytest của thư "
              "mục Version5/tests (58 hàm kiểm thử trong 11 tệp) và dừng nếu có lỗi."),
        ("p", "Một lần chạy thử 20 bước (biến môi trường DONUT_DRY_RUN_STEPS) đo được bộ nhớ GPU tối đa 7,9 GB, 10,0 giây "
              "mỗi bước, tức khoảng 2,3 giờ mỗi epoch và 18,5 giờ cho 8 epoch. Thời gian này dài hơn một phiên Kaggle, nên "
              "train_model.py được viết để chạy tiếp: hàm find_resume_checkpoint() tìm checkpoint có số bước lớn nhất trong "
              "thư mục làm việc và trong output của phiên trước (được thêm vào làm dữ liệu đầu vào), chép sang thư mục ghi "
              "được rồi gọi trainer.train(resume_from_checkpoint=…). Phiên cuối chạy tiếp từ checkpoint-4000."),
    ],
    "Cấu hình và siêu tham số": [
        ("p", "Mô hình gốc là naver-clova-ix/donut-base-finetuned-cord-v2 [5], [40], gồm bộ mã hóa Swin Transformer [8] và bộ "
              "giải mã kiểu BART [9] bốn lớp. Trước khi huấn luyện, hàm setup_model_and_processor() mở rộng tokenizer theo "
              "thiết kế ở mục 3.9.1: tìm các ký tự trong nhãn train không có piece riêng trong từ vựng Unigram của "
              "SentencePiece [12] và thêm 65 ký tự tiếng Việt thẳng vào từ vựng (không dùng added token, để tránh lỗi tách "
              "“Dươ ng” của V3), rồi thêm 10 thẻ trường làm token đặc biệt: <s_seller>, </s_seller> và cặp thẻ mở, đóng của "
              "seller_name, address, timestamp, total_cost. Lớp embedding của bộ giải mã được nới ra theo số token mới "
              "(từ vựng còn 57.655 token); hàng của 65 ký tự mới được gán bằng vector trung bình của từ vựng gốc. Sau đó "
              "chương trình encode rồi decode lại mọi nhãn train và chỉ cho huấn luyện khi ít nhất 99% nhãn tái tạo đúng; kết "
              "quả thực tế là 100,00%. Bảng 4.4 liệt kê các siêu tham số còn lại."),
        ("table", "Cấu hình và siêu tham số huấn luyện DONUT V5", "4", [3000, 2300, 3204],
         ["Tham số", "Giá trị", "Ghi chú"],
         [["Kích thước ảnh vào (cao × rộng)", "1920 × 1440", "V3 dùng 1280 × 960; do_align_long_axis bật"],
          ["Độ dài chuỗi tối đa", "768 token", "MAX_LENGTH, dùng cả khi sinh chuỗi"],
          ["Batch / tích lũy gradient", "1 / 8", "Batch hiệu dụng 8 ảnh mỗi bước"],
          ["Learning rate, lịch", "3e-5, cosine [64]", "300 bước khởi động (warmup)"],
          ["Bộ tối ưu", "AdamW [15]", "Mặc định của Seq2SeqTrainer [13]"],
          ["Số epoch tối đa", "8 (6.680 bước)", "Dừng sớm khi không cải thiện"],
          ["Độ chính xác số", "fp16 hỗn hợp [65]", "Giảm bộ nhớ và tăng tốc trên T4"],
          ["Gradient checkpointing", "Bật [66]", "Đổi thêm tính toán lấy bộ nhớ"],
          ["Đánh giá / lưu checkpoint", "Mỗi 400 bước", "Giữ 3 checkpoint gần nhất"],
          ["Chọn mô hình", "eval_field_exact cao nhất", "load_best_model_at_end"],
          ["Dừng sớm", "patience = 4 lần đánh giá", "EarlyStoppingCallback"],
          ["Lặp ảnh dài", "2 lần", "LONG_REPEAT"],
          ["Seed", "42", "Dùng cho Trainer và tập validation con"]], NGUON),
        ("p", "Điểm khác quan trọng nhất so với V3 là tiêu chí chọn checkpoint. V3 chọn theo loss trên validation, trong khi "
              "loss thấp chưa chắc đọc đúng. V5 dùng lớp ScoringTrainer ghi đè evaluate(): ở mỗi lần đánh giá, mô hình sinh "
              "chuỗi thật cho 150 ảnh validation, chuỗi được tách thành bốn trường và so với nhãn. field_exact là tỉ lệ trường "
              "khớp hoàn toàn trên tổng số trường có nhãn khác rỗng (hai giá trị tiền được coi là khớp khi bằng nhau về số), "
              "kèm tỉ lệ khớp của từng trường. Định nghĩa chi tiết của các độ đo được trình bày ở mục 5.2.1. ScoringTrainer "
              "cũng đặt model_accepts_loss_kwargs = False để Trainer tự chia loss cho số bước tích lũy gradient, vì mô hình "
              "VisionEncoderDecoder trả về loss trung bình thông thường."),
    ],
    "Quá trình huấn luyện": [
        ("p", "Nhật ký huấn luyện trong trainer_state.json ghi loss mỗi 20 bước và kết quả đánh giá mỗi 400 bước. Hình 4.2 cho "
              "thấy loss giảm nhanh trong epoch đầu, từ 11,85 ở bước 20 xuống dưới 0,2 trước bước 700, sau đó giảm chậm và "
              "dao động trong khoảng 0,012–0,047 ở các bước cuối. Trục tung dùng thang logarit để thấy rõ cả hai giai đoạn."),
        ("fig", "Loss huấn luyện của DONUT V5 theo bước", "4", PNG + "ch4_loss_v5.png", 16.0,
         "nguồn: nhóm thực hiện, vẽ từ ai-service/Version5/trainer_state.json", None),
        ("p", "Hình 4.3 và Bảng 4.5 trình bày field_exact trên 150 ảnh validation sau mỗi 400 bước. Độ đo tăng từ 0,7480 ở "
              "bước 400 lên 0,9055 ở bước 800 rồi tăng chậm, đạt cao nhất 0,9350 ở bước 3200 (epoch 3,83). Sau đó field_exact "
              "dao động trong khoảng 0,92–0,93 mà không vượt được giá trị này; sau bốn lần đánh giá liên tiếp không cải "
              "thiện trong phiên cuối (bước 4400 đến 5600), EarlyStoppingCallback dừng huấn luyện ở bước 5600 (epoch 6,71) "
              "thay vì chạy đủ 6.680 bước. Nhờ load_best_model_at_end, mô hình được lưu vào donut_result là checkpoint ở "
              "bước 3200."),
        ("fig", "field_exact trên tập validation theo bước huấn luyện", "4", PNG + "ch4_val_field_exact_v5.png", 16.0,
         "nguồn: nhóm thực hiện, vẽ từ ai-service/Version5/trainer_state.json", None),
        ("table", "Kết quả đánh giá trên 150 ảnh validation ở từng checkpoint", "4", [900, 900, 1500, 1300, 1300, 1300, 1304],
         ["Bước", "Epoch", "field_exact", "seller", "address", "timestamp", "total_cost"], EVAL_ROWS,
         "Nguồn: nhóm thực hiện, trích từ log_history trong ai-service/Version5/trainer_state.json (dòng in đậm: checkpoint được chọn)"),
        ("p", "Ở checkpoint được chọn, tổng tiền là trường dễ nhất, còn địa chỉ là trường khó nhất vì dài và có nhiều cách viết "
              "tắt. Thời gian chạy của phiên cuối (1.600 bước, từ bước 4000 đến 5600) là 18.010 giây, khoảng 11,3 giây mỗi "
              "bước, gần với ước tính khi chạy thử; với 5.600 bước, tổng thời gian GPU ước tính khoảng 16–17 giờ, chia thành "
              "nhiều phiên Kaggle. Kết quả trên 636 ảnh test và so sánh với V3 được trình bày ở Chương 5."),
    ],
    # ---------------------------------------------------------------- 4.5
    "API suy luận": [
        ("p", "AI Service là một ứng dụng FastAPI [34] trong tệp ai-service/ai_service.py, chạy bằng uvicorn ở cổng 8000. Khi "
              "khởi động, dịch vụ nạp processor và mô hình V5 từ thư mục Version5/donut_result một lần duy nhất (tokenizer đã mở "
              "rộng được lưu cùng trọng số), chọn CUDA nếu có, nếu không thì chạy trên CPU, và dừng ngay nếu không tìm thấy "
              "trọng số. Bảng 4.6 liệt kê các endpoint."),
        ("table", "Các endpoint của AI Service", "4", [1100, 2000, 3104, 2300],
         ["Phương thức", "Đường dẫn", "Chức năng", "Truy cập qua Caddy"],
         [["GET", "/health", "Kiểm tra dịch vụ còn sống (healthcheck của Docker)", "/ai/health, công khai"],
          ["POST", "/donut/scan", "Nhận ảnh multipart, trả JSON bốn trường của hóa đơn", "/ai/donut/scan, cần JWT"],
          ["POST", "/spade/analyze", "Tìm chuỗi chi tiêu phổ biến bằng SPADE [48]", "/ai/spade/analyze, cần JWT"],
          ["POST", "/spade/recommend", "Gợi ý cắt giảm chi tiêu theo mục tiêu tiết kiệm", "/ai/spade/recommend, cần JWT"],
          ["POST", "/admin/segment", "Phân khúc RFM theo luật cho Web Admin [49]", "Không mở ra ngoài, Core Backend gọi nội bộ"]],
         NGUON),
        ("p", "Endpoint /donut/scan đọc tệp ảnh, trả mã 400 nếu tệp rỗng hoặc không mở được, xoay ảnh theo thẻ EXIF bằng "
              "ImageOps.exif_transpose() (ảnh chụp từ camera Android thường bị xoay) và chuyển về RGB. Processor thu ảnh về "
              "1920 × 1440, đúng kích thước khi huấn luyện. Bộ giải mã nhận token mở đầu <s_seller> làm prompt và sinh tham lam "
              "(greedy) tối đa 768 token. Chuỗi kết quả được bỏ token kết thúc, token đệm rồi chuyển thành JSON bằng "
              "processor.token2json() [40]; khi chuỗi không chuyển được sang JSON, dịch vụ giữ chuỗi gốc trong khóa raw_text. "
              "Cuối cùng, kết quả đi qua mô-đun hậu xử lý ở mục 4.5.2: các khóa cũ được giữ nguyên, total_cost_number lấy từ "
              "số tiền đã chuẩn hóa, và khóa mới normalized chứa kết quả chuẩn hóa kèm cờ hợp lệ của từng trường. Các tham số đầu vào của "
              "/spade/* được khai báo bằng mô hình Pydantic (SpadeRequest, RecommendRequest) [60]."),
        ("p", "Một hạn chế của bản cài đặt hiện tại: /donut/scan được khai báo async def nhưng gọi model.generate() trực tiếp. "
              "Suy luận là tác vụ nặng về CPU nên trong lúc một hóa đơn đang được đọc, vòng lặp sự kiện của uvicorn không phục "
              "vụ được yêu cầu khác. Cách khắc phục là khai báo hàm thường (def) để FastAPI chạy nó trong thread pool [34], "
              "hoặc tách suy luận sang tiến trình riêng."),
    ],
    "Hậu xử lý bằng Regex": [
        ("p", "Mô-đun ai-service/receipt_postprocess.py hiện thực thiết kế ở mục 3.9.3. Mô-đun chỉ dùng thư viện chuẩn re "
              "[68], unicodedata, datetime và Pydantic [60], không nạp mô hình, nên được kiểm thử độc lập với ai_service.py. "
              "Đầu vào là từ điển bốn trường theo tên thẻ của V5 (enum ReceiptField: seller_name, address, timestamp, "
              "total_cost); hàm fields_from_sequence() lấy nội dung từng thẻ từ chuỗi DONUT bằng biểu thức khớp không tham "
              "lam. Hàm normalize_receipt() trả về mô hình NormalizedReceipt: mỗi trường giữ giá trị thô (raw), giá trị đã "
              "chuẩn hóa (value) và cờ valid, kèm danh sách invalid_fields để ứng dụng biết trường nào cần người dùng kiểm "
              "tra. Bảng 4.7 tóm tắt các quy tắc."),
        ("table", "Các quy tắc hậu xử lý trong receipt_postprocess.py", "4", [1800, 4300, 2404],
         ["Trường", "Quy tắc chuẩn hóa", "Điều kiện valid"],
         [["Mọi trường", "Chuẩn hóa Unicode NFC, gộp khoảng trắng. Nếu chuỗi lẫn thẻ của trường khác (rò thẻ), giữ phần "
                         "sau thẻ mở cuối cùng của chính trường đó, không có thì giữ phần trước thẻ đầu tiên", "Không có rò thẻ"],
          ["SELLER, ADDRESS", "Bỏ ký tự rác (ngoài chữ, số và dấu câu thông dụng), bỏ dấu câu lặp, bỏ khoảng trắng trước "
                              "dấu phẩy, thêm khoảng trắng sau dấu phẩy, bỏ dấu câu ở hai đầu; chuỗi toàn chữ thường được viết "
                              "hoa đầu từ. Riêng địa chỉ: tách viết tắt “P.Linh Tây”, “TP.Hồ Chí Minh” thành “P. Linh Tây”, "
                              "“TP. Hồ Chí Minh”",
           "Tên ≥ 2 chữ cái, ≤ 100 ký tự; địa chỉ ≥ 3 chữ cái, ≤ 250 ký tự"],
          ["TIMESTAMP", "Gộp khoảng trắng quanh / : . giữa các chữ số. Nhận ngày dạng dd/MM/yyyy, dd-MM-yy, yyyy-MM-dd, "
                        "“10 tháng 02 năm 2023”, “Jan 14, 22”, “09 Jan 2023”; ưu tiên thứ tự ngày/tháng/năm, chỉ đổi sang "
                        "tháng/ngày khi tháng > 12; giờ dạng HH:mm[:ss], HHhmm, có AM/PM hoặc SA/CH. Kết quả iso dạng "
                        "yyyy-MM-ddTHH:mm:ss, hoặc yyyy-MM-dd khi thiếu giờ",
           "Có ngày tồn tại, năm từ 2000 đến năm hiện tại + 1"],
          ["TOTAL_COST", "Nhận số có nhóm nghìn bằng dấu chấm, dấu phẩy hoặc khoảng trắng (30,200.00; 1.011.780; 105 000). "
                         "Một hoặc hai chữ số sau dấu cuối là phần lẻ và bị bỏ. Lấy số đứng ngay sau từ khóa ưu tiên cao "
                         "nhất (“tổng thanh toán”, “cần thanh toán”, “khách phải trả”, …, “total”, “tổng”); không có từ khóa "
                         "thì lấy số cuối cùng",
           "Từ 100 đến 1.000.000.000 đồng"]],
         NGUON),
        ("p", "Trong ai_service.py, hàm _raw_fields() lấy bốn trường thô từ JSON của token2json() (hoặc từ chuỗi DONUT khi "
              "không chuyển được sang JSON), normalize_receipt() chuẩn hóa chúng và kết quả model_dump() được gắn vào khóa "
              "normalized của phản hồi /donut/scan; các khóa cũ không đổi nên phiên bản ứng dụng cũ vẫn chạy. Trên màn hình "
              "ReviewFormPage, các trường tên cửa hàng, tổng tiền và ngày giờ nằm trong invalid_fields được viền màu báo lỗi "
              "cho tới khi người dùng sửa. Tệp test_receipt_postprocess.py có 15 hàm kiểm thử pytest, sinh 63 trường hợp nhờ "
              "tham số hóa."),
        ("p", "So với cách cũ lấy số lớn nhất trong chuỗi tổng tiền, quy tắc từ khóa tránh được trường hợp hóa đơn in số tiền "
              "khách đưa lớn hơn tổng tiền. Ngày giờ được chuẩn hóa về ISO 8601 ngay ở AI Service, nên Core Backend và ứng dụng "
              "không phải đoán định dạng. Các cờ valid cho phép ứng dụng tô sáng trường cần người dùng xem lại trên màn hình "
              "đối soát."),
        ("p", "Để đo tác dụng của mô-đun, nhóm chạy lại phép so sánh trên tệp compare_test.csv (dự đoán của V5 trên 636 ảnh "
              "test, 2.237 trường có nhãn), áp cùng hàm chuẩn hóa cho cả nhãn và dự đoán rồi so khớp bằng fields_match. Bảng "
              "4.8 cho thấy số trường khớp hoàn toàn tăng thêm 23 và không trường nào đang đúng bị làm sai. ADDRESS và "
              "TIMESTAMP được lợi nhiều nhất, đúng với nhận xét rằng lỗi của hai trường này chủ yếu là sai lệch nhỏ về dấu "
              "câu, khoảng trắng và định dạng; SELLER không đổi."),
        ("table", "Số trường khớp hoàn toàn trên tập test trước và sau hậu xử lý", "4", [1900, 2300, 2300, 2004],
         ["Trường", "Trước hậu xử lý", "Sau hậu xử lý", "Chênh lệch"],
         [["SELLER", "468/532 (87,97%)", "468/532 (87,97%)", "0"],
          ["ADDRESS", "405/507 (79,88%)", "415/507 (81,85%)", "+10"],
          ["TIMESTAMP", "527/567 (92,95%)", "539/567 (95,06%)", "+12"],
          ["TOTAL_COST", "613/631 (97,15%)", "614/631 (97,31%)", "+1"],
          ["Tất cả", "2.013/2.237 (89,99%)", "2.036/2.237 (91,01%)", "+23"]],
         "Nguồn: nhóm thực hiện, tính từ ai-service/Version5/compare_test.csv"),
        ("p", "Cờ valid bắt được 23 trong 201 trường vẫn còn sai sau hậu xử lý và gắn nhầm cờ cho 4 trong 2.036 trường đúng. "
              "Như vậy cờ ít khi làm phiền người dùng, nhưng phần lớn lỗi còn lại (giá trị đúng định dạng mà sai nội dung) "
              "không thể phát hiện bằng luật, nên màn hình đối soát vẫn là bước bắt buộc. Đánh giá đầy đủ của mô hình được "
              "trình bày ở Chương 5."),
    ],
    # ---------------------------------------------------------------- 4.6
    "Xác thực, phân quyền và quản lý tài khoản": [
        ("p", "Core Backend là ứng dụng Spring Boot 3.2.5 [31] gồm 213 tệp Java trong gói vn.edu.huit.finance.core, chia theo "
              "các gói Config, Controller, Dto, Entity, Exception, Repository, Security, Service và Util. Controller chỉ kiểm "
              "tra dữ liệu vào bằng @Valid rồi gọi Service; mọi phản hồi được bọc trong ApiResponse<T> (code, message, data), "
              "lỗi nghiệp vụ được ném thành ngoại lệ riêng (ví dụ InsufficientBalanceException, BudgetNotFoundException) và "
              "GlobalExceptionHandler chuyển thành mã HTTP tương ứng."),
        ("p", "SecurityConfig khai báo hai chuỗi bộ lọc của Spring Security [32]. Chuỗi thứ nhất (@Order(1)) phục vụ /admin/** "
              "bằng form đăng nhập và phiên làm việc cho Web Admin. Chuỗi thứ hai (@Order(2)) phục vụ /api/** ở chế độ "
              "STATELESS: JwtAuthFilter đọc token Bearer, JwtUtil kiểm tra chữ ký, hạn dùng, loại token trong header JOSE typ "
              "(ACCESS hoặc REFRESH) và credentialsVersion [28]. Access token sống 15 phút, refresh token sống 30 ngày. Khi "
              "người dùng đổi hoặc đặt lại mật khẩu, credentialsVersion tăng trong cùng một câu lệnh UPDATE với mật khẩu, nên "
              "mọi token cũ bị từ chối; khi đăng xuất, TokenBlacklistService ghi token vào bảng revoked_tokens. Mã người dùng "
              "hiện tại luôn được lấy từ SecurityContext qua CurrentUserProvider, không bao giờ từ tham số do client gửi."),
        ("p", "AuthService xử lý đăng ký, đăng nhập, làm mới phiên và khôi phục mật khẩu. Mật khẩu mới phải qua ràng buộc "
              "@StrongPassword (8–72 ký tự, có chữ và số) và được băm bằng BCrypt. LoginAttemptService khóa đăng nhập 15 phút "
              "sau 5 lần sai, đếm riêng theo email và theo địa chỉ IP. Mã OTP đặt lại mật khẩu có 6 chữ số, sống 5 phút, được "
              "lưu trong Redis [36] qua RedisPasswordResetOtpStore; việc kiểm tra và xóa mã chạy trong một script Lua nên "
              "không thể dùng một mã hai lần. Đăng nhập bằng Google và Facebook được SocialAuthService xác minh trực tiếp với "
              "máy chủ của nhà cung cấp (endpoint tokeninfo của Google, Graph API của Facebook) trước khi cấp JWT của hệ thống."),
    ],
    "Quản lý giao dịch và đồng bộ dữ liệu": [
        ("p", "TransactionService là nơi duy nhất ghi giao dịch và số dư ví (User.walletBalance). Mọi thao tác thêm, sửa, xóa "
              "chạy trong một @Transactional và khóa dòng users bằng PESSIMISTIC_WRITE (hàm lockWallet) trước khi đọc số dư, "
              "nên hai yêu cầu đồng thời không ghi đè số dư của nhau. Hàm moveWallet() cộng hoặc trừ phần chênh lệch và ném "
              "InsufficientBalanceException (HTTP 400) khi một khoản chi, hoặc việc xóa một khoản thu, làm số dư âm. Sau khi "
              "lưu, dịch vụ gọi BudgetAlertService, phát StatisticsChangedEvent để xóa cache thống kê và ghi nhật ký kiểm "
              "toán qua AuditLogService."),
        ("p", "Đồng bộ ngoại tuyến dựa trên trường clientId. Ứng dụng sinh một UUID v4 cho mỗi giao dịch trước khi gửi; nếu "
              "mạng lỗi, giao dịch nằm trong hàng đợi SQLite và được gửi lại sau với đúng clientId đó. Ở máy chủ, sau khi khóa "
              "ví, hàm create() tìm giao dịch cũ bằng findByUserIdAndClientId(); nếu đã có, máy chủ trả lại giao dịch gốc thay "
              "vì tạo bản thứ hai. Ràng buộc duy nhất (user_id, client_id) trong CSDL là lớp bảo vệ cuối cùng. Nhờ vậy, việc "
              "gửi lại bao nhiêu lần cũng chỉ tạo một giao dịch và chỉ trừ ví một lần (tính lũy đẳng, idempotency)."),
    ],
    "Quản lý ngân sách và cảnh báo": [
        ("p", "BudgetController cung cấp các thao tác thêm, sửa, xóa và xem tiến độ ngân sách theo tuần hoặc tháng, mỗi ngân "
              "sách gắn với một danh mục chi tiêu. BudgetService kiểm tra trùng theo ràng buộc duy nhất (user_id, "
              "category_key, period_type, start_date) và ném DuplicateBudgetException khi người dùng tạo hai ngân sách cho "
              "cùng danh mục và cùng kỳ."),
        ("p", "Cảnh báo được tính ngay trong giao dịch ghi chi tiêu. BudgetAlertService.notifyAfterCreate() và "
              "notifyAfterUpdate() tính tổng chi của kỳ, rồi hàm highestReached() so sánh spent × 100 với limit × ngưỡng (80 "
              "cho BUDGET_WARNING, 100 cho BUDGET_EXCEEDED) để tránh sai số làm tròn của phép chia. Mỗi mức chỉ sinh một thông "
              "báo trong một kỳ: nếu thông báo cùng mức đã tồn tại thì không tạo nữa, nên người dùng không bị gửi lặp khi "
              "tiếp tục chi. Thông báo được NotificationService lưu vào bảng notifications và ứng dụng đọc qua "
              "/api/notifications."),
    ],
    "Thống kê và bộ nhớ đệm": [
        ("p", "Các truy vấn thống kê (trang chủ của người dùng, cửa hàng hay mua, tổng quan và top người chi tiêu của Web "
              "Admin) được đánh dấu @Cacheable và đệm trong Redis bằng Spring Cache theo thiết kế ở mục 3.4.2. TTL được cấu "
              "hình trong redis-cache.properties: 45 giây cho trang chủ và tổng quan quản trị, 60 giây cho các thống kê còn "
              "lại, trừ ngẫu nhiên tối đa 10% để các khóa không hết hạn cùng lúc. Khi có giao dịch thay đổi, "
              "StatisticsChangedEvent được xử lý ở pha AFTER_COMMIT để chỉ xóa khóa sau khi dữ liệu đã thật sự được ghi. "
              "FallbackCacheErrorHandler bỏ qua lỗi Redis và đọc thẳng PostgreSQL, nên Redis ngừng hoạt động chỉ làm chậm "
              "thống kê chứ không làm hỏng chức năng."),
    ],
    "Xử lý và đối soát hóa đơn": [
        ("p", "Khi ứng dụng gửi giao dịch kèm kết quả quét (rawReceiptData) và đường dẫn ảnh, TransactionService gọi "
              "ReceiptProcessingService.attachReceipt() trong cùng giao dịch CSDL. OcrService.extract() là nơi duy nhất đọc "
              "câu trả lời của AI và áp các quy tắc ở Bảng 3.30; câu trả lời thô được lưu nguyên vào bảng "
              "receipt_processing_attempts, mỗi lần đọc một dòng và không bao giờ bị ghi đè. Trạng thái hóa đơn chỉ được đổi "
              "qua Receipt.moveTo() hoặc Receipt.failWith(), có khóa lạc quan (cột version), nên hai thao tác đồng thời trên "
              "cùng hóa đơn trả về 409 qua ReceiptConflictException."),
        ("p", "Sau khi giao dịch được commit, sự kiện OcrProcessedEvent được xử lý bất đồng bộ trên luồng mongoAsyncExecutor để "
              "ghi nhật ký AI vào MongoDB [37]; lỗi ở bước này không làm hỏng giao dịch đã lưu. Quản trị viên duyệt hoặc từ "
              "chối hóa đơn trên Web Admin; TransactionService.approveReceipt() đối soát số tiền và điều chỉnh ví dưới cùng cơ "
              "chế khóa ví như mục 4.6.2."),
    ],
    # ---------------------------------------------------------------- 4.7
    "Tổ chức mã nguồn": [
        ("p", "Ứng dụng di động viết bằng Flutter [33] và Dart [46], gồm 79 tệp .dart trong thư mục lib. Màn hình gọi dữ liệu "
              "qua AppRepository (giao dịch, ngân sách, ví, hàng đợi ngoại tuyến) và RemoteApiHelper (mọi lời gọi HTTP bằng "
              "dio). Cài đặt giao diện và ngôn ngữ dùng Cubit của flutter_bloc, đăng ký phụ thuộc bằng get_it. Bảng 4.9 mô "
              "tả các thư mục chính."),
        ("table", "Cấu trúc thư mục mã nguồn ứng dụng di động", "4", [2600, 5904],
         ["Thư mục", "Nội dung"],
         [["lib/config", "AppConfig: địa chỉ API và AI, đọc từ --dart-define API_BASE, ML_BASE"],
          ["lib/core", "Theme (AppTheme, ColorScheme sáng/tối), hằng số danh mục, tiện ích tiền tệ và ngày giờ"],
          ["lib/cubits, lib/di", "ThemeCubit, LanguageCubit; injection_container.dart đăng ký phụ thuộc bằng get_it"],
          ["lib/l10n", "Tệp ARB tiếng Việt và tiếng Anh (517 khóa) và lớp AppLocalizations sinh tự động"],
          ["lib/models", "TransactionModel, BudgetModel, ReceiptModel, AppNotification, SyncStatus…"],
          ["lib/repositories", "AppRepository, SettingsRepository"],
          ["lib/services", "RemoteApiHelper, SessionService, SqfliteHelper (SQLite phiên bản 7), LanguageInterceptor"],
          ["lib/screens", "Màn hình theo chức năng: auth, dashboard, ledger, budget, ai, receipt_scanner, notifications, "
                          "profile, payment, linked"],
          ["lib/widgets", "Thành phần dùng chung: hộp thoại AppDialog, thẻ, biểu đồ"]], NGUON),
        ("p", "RemoteApiHelper dùng hai đối tượng Dio: một cho Core Backend và một cho AI Service (qua đường dẫn /ai của "
              "Caddy). Bộ chặn (interceptor) gắn access token vào mọi yêu cầu; khi nhận 401, nó gọi /api/auth/refresh đúng "
              "một lần (các yêu cầu khác cùng lúc chờ chung kết quả) rồi gửi lại yêu cầu ban đầu. Lỗi mạng và lỗi máy chủ "
              "được chuyển thành thông báo dễ hiểu bằng UserFacingError và hiện trong AppDialog."),
    ],
    "Các chức năng chính": [
        ("p", "Ghi chép thu chi: AddTransactionPage và EditTransactionPage gửi giao dịch qua AppRepository.createTransaction(). "
              "Hàm này sinh clientId, ghi bản chờ vào SQLite trước, rồi mới gọi API; kết quả trả về là một SyncStatus (đã "
              "đồng bộ, chưa gửi được, bị từ chối). Các giao dịch chưa gửi được hiển thị nhãn trạng thái trong LedgerPage và "
              "được resendUnsyncedTransactions() gửi lại khi ứng dụng khởi động, khi quay lại từ nền, hoặc khi người dùng kéo "
              "để làm mới."),
        ("p", "Ngân sách và biểu đồ: BudgetScreen hiển thị thanh tiến độ và cảnh báo 80%/100%; DashboardPage và AITabPage vẽ "
              "biểu đồ chi tiêu bằng fl_chart và gọi /ai/spade/analyze để hiển thị báo cáo thói quen chi tiêu theo khoảng thời "
              "gian người dùng chọn."),
        ("p", "Quét hóa đơn: người dùng chụp bằng trình quét tài liệu của Google ML Kit [59] (tự cắt viền, nắn phối cảnh) "
              "hoặc chọn ảnh từ thư viện bằng image_picker. Ảnh được gửi tới /ai/donut/scan; ReviewFormPage điền sẵn tên cửa "
              "hàng, địa chỉ, ngày giờ và tổng tiền để người dùng sửa. Ngày giờ quét được thử khớp với một danh sách định dạng; "
              "không khớp thì lấy thời điểm hiện tại và hiện ghi chú nhắc người dùng kiểm tra. Ảnh chỉ được tải lên Cloudinary "
              "khi người dùng bấm lưu; nếu tải ảnh thất bại, ứng dụng hỏi có lưu giao dịch không kèm ảnh hay không. Giao dịch "
              "từ hóa đơn đi qua cùng đường lưu có clientId và hàng đợi như giao dịch nhập tay."),
        ("y", "[Nhóm] Có thể chèn 2–3 ảnh chụp màn hình minh họa luồng quét hóa đơn (camera → đối soát → lưu) nếu Chương 3 "
              "chưa dùng các ảnh này."),
    ],
    "Đa ngôn ngữ và giao diện sáng/tối": [
        ("p", "Toàn bộ chuỗi giao diện nằm trong hai tệp lib/l10n/app_vi.arb và app_en.arb với 517 khóa; lệnh flutter gen-l10n "
              "sinh lớp AppLocalizations để màn hình gọi context.loc.<khóa>. Số tiền được định dạng theo ngôn ngữ bằng "
              "NumberFormat của gói intl (tiếng Việt “1.000.000 đ”, tiếng Anh “1,000,000 đ”). LanguageInterceptor gắn header "
              "Accept-Language vào mọi yêu cầu; vì Core Backend hiện chỉ trả thông báo tiếng Việt, khi chọn tiếng Anh ứng dụng "
              "hiển thị thông báo của chính ứng dụng theo mã HTTP."),
        ("p", "Giao diện sáng, tối hoặc theo hệ thống được ThemeCubit quản lý; các màn hình lấy màu từ ColorScheme của "
              "Material 3 [57] thay vì mã màu cố định. Lựa chọn ngôn ngữ và giao diện được SettingsRepository lưu bằng "
              "shared_preferences (khóa app_language, app_theme) và đọc lại khi khởi động."),
    ],
    # ---------------------------------------------------------------- 4.8
    "CÀI ĐẶT WEB ADMIN": [
        ("p", "Web Admin được render ở phía máy chủ bằng Thymeleaf [55] ngay trong Core Backend, không phải một dự án riêng. "
              "AdminController (tiền tố /admin) trả về các trang trong templates/admin: dashboard, users, categories, "
              "receipts, subscriptions, reviews, auditlog và backup, dùng chung bố cục layout/_layout.html với Bootstrap 5.3 "
              "[56], Font Awesome và Chart.js [58] nạp từ CDN. Các thao tác thêm, sửa, xóa trên trang được gửi bằng fetch tới "
              "các endpoint /admin/ajax/** và nhận JSON; duyệt hoặc từ chối hóa đơn dùng POST /admin/receipts/approve/{id} và "
              "/admin/receipts/reject/{id}."),
        ("p", "Trang dashboard vẽ biểu đồ từ AdminStatisticsService (có cache Redis) và nút chạy phân khúc RFM gọi /admin/segment "
              "của AI Service. Trang auditlog đọc nhật ký từ AuditLogQueryService, lọc theo hành động, kết quả, thời gian và cho "
              "phép gỡ khóa đăng nhập. Trang backup gọi BackupService chạy pg_dump với ba kiểu FULL, SCHEMA_ONLY và DATA_ONLY "
              "(enum BackupType). Mọi trang /admin/** yêu cầu vai trò ADMIN theo chuỗi bộ lọc thứ nhất ở mục 4.6.1."),
    ],
    # ---------------------------------------------------------------- 4.9
    "ĐÓNG GÓI HỆ THỐNG BẰNG DOCKER": [
        ("p", "Toàn bộ phía máy chủ được mô tả trong một tệp docker-compose.yml [38] gồm sáu dịch vụ trên mạng nội bộ "
              "finance-network (Bảng 4.10). Chỉ Caddy mở cổng 80 và 443 ra ngoài; PostgreSQL và MongoDB chỉ nghe trên "
              "127.0.0.1 để quản trị qua đường hầm SSH, còn Core Backend và AI Service chỉ khai báo expose trong mạng nội bộ."),
        ("table", "Các dịch vụ trong docker-compose.yml", "4", [1700, 2300, 1200, 3304],
         ["Dịch vụ", "Image", "Giới hạn RAM", "Ghi chú"],
         [["proxy", "caddy:2.8-alpine", "128 MB", "Cổng 80/443, tự cấp chứng chỉ HTTPS, cấu hình deploy/caddy/Caddyfile"],
          ["db", "postgres:15-alpine", "–", "CSDL finance_db, volume postgres_data, healthcheck pg_isready"],
          ["redis", "redis:8.10-alpine", "192 MB", "Bắt buộc mật khẩu, allkeys-lru, tắt lưu đĩa, vô hiệu KEYS/FLUSHALL/FLUSHDB"],
          ["mongodb", "mongo:6.0", "512 MB", "Nhật ký AI, WiredTiger cache 0,25 GB; Core Backend vẫn chạy khi Mongo chưa sẵn sàng"],
          ["core-api", "Build từ core-backend/Dockerfile", "512 MB", "Chờ db, redis, AI Service healthy; healthcheck /actuator/health"],
          ["data-mining-api", "Build từ ai-service/Dockerfile", "1 GB", "AI Service cổng 8000, healthcheck /health"]],
         NGUON),
        ("p", "Image của Core Backend được build hai tầng: tầng maven:3.9.6-eclipse-temurin-21 tải thư viện và đóng gói "
              "finance-api.jar, tầng chạy eclipse-temurin:21-jre-jammy chỉ chứa JRE, đặt múi giờ Asia/Ho_Chi_Minh, chạy bằng "
              "người dùng không phải root và dùng tini làm tiến trình số 1; JVM được giới hạn 75% bộ nhớ của container. Image "
              "của AI Service dựa trên python:3.10-slim; tệp .dockerignore loại bỏ ảnh data1, notebook, thư mục Version3 và "
              "toàn bộ Version5 trừ Version5/donut_result, nên image chỉ chứa trọng số V5 đang phục vụ."),
        ("p", "Caddy [52] là cửa vào duy nhất. Đường dẫn /ai/* được bỏ tiền tố rồi chuyển tới AI Service: /ai/health công khai, "
              "còn /ai/donut/* và /ai/spade/* phải qua forward_auth, tức Caddy gọi GET /api/auth/check của Core Backend "
              "với header Authorization của yêu cầu và chỉ chuyển tiếp khi nhận 204. Các đường dẫn /actuator/* (trừ "
              "/actuator/health) trả 404 để không lộ thông tin nội bộ; mọi đường dẫn còn lại đi tới Core Backend. Mật khẩu "
              "CSDL, Redis, MongoDB, JWT_SECRET và khóa thanh toán được nạp từ tệp .env; cú pháp ${BIẾN:?} làm docker compose "
              "dừng ngay nếu thiếu biến bắt buộc. Mỗi container giới hạn nhật ký 3 tệp × 10 MB."),
        ("p", "Hai rủi ro còn lại: giới hạn 1 GB cho AI Service khá sát khi mô hình V5 (tệp trọng số khoảng 806 MB) chạy trên "
              "CPU với ảnh 1920 × 1440, và trọng số không nằm trong Git nên phải chép thủ công lên máy chủ trước khi build. "
              "Kết quả triển khai thực tế được trình bày ở Chương 5."),
        ("y", "[Nhóm] Sau khi triển khai, ghi bộ nhớ thực tế của container data-mining-api khi quét một hóa đơn (lệnh docker "
              "stats) để xác nhận hoặc điều chỉnh giới hạn 1 GB."),
    ],
    # ---------------------------------------------------------------- 4.10
    "KẾT CHƯƠNG": [
        ("p", "Chương 4 đã trình bày phần cài đặt của hệ thống. Tập data1 gồm 6.351 ảnh được gán nhãn lại bằng hai mô hình "
              "VLM kết hợp người duyệt, nâng số ảnh train có đủ bốn trường từ 450 lên 3.463, các ô chưa kiểm tra được che khi "
              "tính loss. DONUT V5 được huấn luyện trên Kaggle với ảnh 1920 × 1440, tokenizer mở rộng 65 ký tự tiếng Việt và "
              "10 thẻ trường (tái tạo đúng 100% nhãn), chọn checkpoint theo độ chính xác đọc thật; checkpoint tốt nhất đạt "
              "field_exact 0,9350 trên validation ở bước 3200. AI Service phục vụ mô hình qua FastAPI và có mô-đun hậu xử lý "
              "Regex cho bốn trường, nâng tỉ lệ trường khớp hoàn toàn trên tập test từ 89,99% lên 91,01%; Core Backend hiện thực xác thực JWT có thu hồi token, ghi giao dịch có khóa ví và lũy "
              "đẳng theo clientId, cảnh báo ngân sách chống gửi lặp và cache thống kê trên Redis; ứng dụng di động hỗ trợ "
              "ngoại tuyến, song ngữ và giao diện sáng/tối; Web Admin được render bằng Thymeleaf. Toàn bộ phía máy chủ được "
              "đóng gói thành sáu container sau một reverse proxy Caddy."),
        ("p", "Phần cài đặt vẫn còn những hạn chế đã nêu: thư viện Python chưa ghim phiên bản, /donut/scan chặn vòng lặp sự kiện "
              "khi suy luận, giới hạn bộ nhớ của AI Service chưa được đo trên máy chủ, và cờ valid của mô-đun hậu xử lý chỉ "
              "phát hiện được một phần nhỏ lỗi còn lại. Chương 5 đánh giá mô hình trên tập test, kiểm thử chức năng, API, hiệu năng và trình "
              "bày kết quả triển khai."),
    ],
}

ABBREVIATIONS = [
    ("APK", "Android Package Kit", "Gói cài đặt ứng dụng Android"),
    ("ARB", "Application Resource Bundle", "Tệp tài nguyên chuỗi đa ngôn ngữ của Flutter"),
    ("FP16", "16-bit Floating Point", "Số thực dấu phẩy động 16 bit"),
    ("ISO", "International Organization for Standardization", "Tổ chức Tiêu chuẩn hóa Quốc tế"),
    ("JRE", "Java Runtime Environment", "Môi trường chạy Java"),
    ("SDK", "Software Development Kit", "Bộ công cụ phát triển phần mềm"),
    ("VLM", "Vision-Language Model", "Mô hình thị giác – ngôn ngữ"),
]

PARA_REPLACE = [
    ("[Nhóm] Mô-đun receipt_postprocess.py chưa được cài đặt",
     ("p", "Phần cài đặt mô-đun này, cách nối vào /donut/scan và hiệu quả đo trên tập test được trình bày ở mục 4.5.2.")),
]
