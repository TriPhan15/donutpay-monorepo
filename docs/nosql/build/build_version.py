"""Dựng một phiên bản báo cáo NoSQL từ phiên bản trước: vN = v(N-1) + một content module. Chạy lại được; chỉ ghi đè vN.

Cách dùng (từ thư mục gốc repo):
    python3 docs/nosql/build/build_version.py <src> <dst> <content_module.py> <chương>
Ví dụ (Chương 4, v3 từ v2):
    python3 docs/nosql/build/build_version.py v2 v3 content_c4.py 4

<src>/<dst> là "vN" (tệp NoSQL_38_BaoCao_vN.docx trong thư mục OUT) hoặc một đường dẫn .docx; <content_module.py> là tên
tệp trong docs/nosql/build hoặc một đường dẫn. Các bước:
  1. giải nén <src> vào một thư mục tạm, chạy builder_nosql.py với content module, đóng gói lại thành <dst>.docx;
  2. render PDF bằng image scratch-lo-render:1 (mạng tắt, hồ sơ LibreOffice nằm trong thư mục tạm, không để lại gì ở OUT);
  3. chép .docx và .pdf vào OUT, xóa thư mục tạm (và OUT/home nếu một lần chạy cũ để lại);
  4. chạy check_report.py --chapter <chương>, đếm trang PDF, đếm "[[" và "[T7.c<chương>" trong chữ của PDF.
Mã thoát = mã thoát của check_report.py (0 khi chương sạch). Biến môi trường NOSQL_OUT đổi thư mục OUT.
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

BUILD = Path(__file__).resolve().parent
OUT = Path(os.environ.get("NOSQL_OUT", "/home/triphan/Workspace/Deploy_Project/Nosql/Nosql_38"))
PREFIX = "NoSQL_38_BaoCao_"
RENDER_IMAGE = "scratch-lo-render:1"


def docx_path(arg):
    return Path(arg) if arg.endswith(".docx") else OUT / f"{PREFIX}{arg}.docx"


def main():
    if len(sys.argv) != 5:
        raise SystemExit(__doc__)
    src, dst, module, chapter = docx_path(sys.argv[1]), docx_path(sys.argv[2]), sys.argv[3], sys.argv[4]
    module = Path(module) if "/" in module else BUILD / module
    if not src.exists() or not module.exists():
        raise SystemExit(f"Thiếu {src if not src.exists() else module}")
    if src.resolve() == dst.resolve():
        raise SystemExit("Nguồn và đích trùng nhau: mỗi phiên bản là một tệp riêng")
    name = dst.stem

    tmp = Path(tempfile.mkdtemp(prefix="nosql_build_"))
    try:
        work, render = tmp / "unpacked", tmp / "render"
        render.mkdir()
        with zipfile.ZipFile(src) as z:
            names = z.namelist()
            z.extractall(work)
        subprocess.run([sys.executable, str(BUILD / "builder_nosql.py"), str(work), str(module)], check=True)
        allf = [p.relative_to(work).as_posix() for p in work.rglob("*") if p.is_file()]
        order = [n for n in names if n in allf] + sorted(set(allf) - set(names))
        docx = render / f"{name}.docx"
        with zipfile.ZipFile(docx, "w", zipfile.ZIP_DEFLATED) as z:
            for n in order:
                z.write(work / n, n)
        r = subprocess.run(["docker", "run", "--rm", "--network", "none", "-u", f"{os.getuid()}:{os.getgid()}",
                            "-e", "HOME=/w/home", "-v", f"{render}:/w", "-w", "/w", RENDER_IMAGE, "soffice",
                            "-env:UserInstallation=file:///w/home/lo", "--headless", "--convert-to", "pdf", docx.name],
                           capture_output=True, text=True)
        if r.returncode != 0 or not (render / f"{name}.pdf").exists():
            raise SystemExit(f"Render PDF hỏng: {r.stdout}\n{r.stderr}")
        for ext in ("docx", "pdf"):
            shutil.copy2(render / f"{name}.{ext}", OUT / f"{name}.{ext}")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
        shutil.rmtree(OUT / "home", ignore_errors=True)

    rc = subprocess.run([sys.executable, str(BUILD / "check_report.py"), str(OUT / f"{name}.docx"),
                         "--chapter", chapter]).returncode
    txt = subprocess.run(["pdftotext", "-layout", str(OUT / f"{name}.pdf"), "-"], capture_output=True, text=True).stdout
    pages = subprocess.run(["pdfinfo", str(OUT / f"{name}.pdf")], capture_output=True, text=True).stdout
    pages = re.search(r"Pages:\s+(\d+)", pages)
    left = len(re.findall(r"\[T7\.c" + chapter + "_", txt))
    print(f"{name}: check_report --chapter {chapter} exit {rc}; PDF {pages.group(1) if pages else '?'} trang; "
          f"'[[': {txt.count('[[')}; '[T7.c{chapter}': {left}; "
          f"'[T7.' còn lại: {txt.count('[T7.')}")
    sys.exit(rc)


if __name__ == "__main__":
    main()
