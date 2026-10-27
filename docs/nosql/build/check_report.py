"""Kiểm tra một bản báo cáo NoSQL (.docx) trước khi giao.

Cách dùng: python3 check_report.py <docx> [--chapter N] [--facts facts.md] [--refs references.md] [--repo DIR]

Lỗi (mã thoát 1 nếu có ít nhất một lỗi):
  1. còn dòng giữ chỗ "[T7.cN_" của chương N (mọi chương khi không có --chapter);
  2. còn "[[" (tham chiếu [[key]] chưa giải);
  3. trích dẫn [n] không có mục tài liệu; không có --chapter: thêm mục tài liệu không được trích lần nào;
  4. "Hình c.n" / "Bảng c.n" trỏ tới số không có chú thích;
  5. mã FR/NFR/AP/Q/TC/S-xx không có trong bảng của facts.md; định danh trong đoạn MaNguon hoặc token dạng mã trong
     văn bản (camelCase, snake_case, @Annotation) không phải một định danh trọn vẹn có trong facts.md hoặc trong mã
     nguồn ở commit CODE_SHA (git grep -w); đường dẫn /api/..., /admin/... phải có nguyên văn trong facts.md.
Dòng giữ chỗ [T7.…] không được kiểm tra nội dung (chỉ báo lỗi 1); khi còn dòng giữ chỗ, kiểm tra "mục không được
trích" được hoãn (báo thông tin).
Thông tin (không làm hỏng): ảnh giữ chỗ "S-xx – chưa chụp" còn trong word/media, số ghi chú tô vàng, thứ tự trích dẫn.
Danh sách tài liệu: các đoạn bắt đầu bằng [n] sau tiêu đề "Tài liệu tham khảo" trong docx; nếu docx chưa có danh sách
thì lấy các mục "[n]" của references.md.
"""
import argparse
import re
import subprocess
import sys
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
PLACEHOLDER_PNG_KEY = "ledgermind-placeholder"
ID_RE = re.compile(r"(?<![\w-])((?:FR|NFR|AP|TC|S|Q)-\d{2,3})(?![\w-])")
CITE_RE = re.compile(r"\[(\d+(?:\s*[,–-]\s*\d+)*)\]")
REF_RE = re.compile(r"(Hình|Bảng|hình|bảng) (\d+)\.(\d+)((?: đến | và | tới )(?:(?:Hình|Bảng|hình|bảng) )?)?(\d+\.\d+)?")
CAPTION_RE = re.compile(r"^(Hình|Bảng) (\d+)\.(\d+)\s*:")
P_RE = re.compile(r"<w:p[ >](?:(?!<w:p[ >]).)*?</w:p>", re.S)
CODE_TOKEN_RE = re.compile(r"(?<![A-Za-z0-9_$])[A-Za-z_$@][A-Za-z0-9_$]*")  # không bắt đầu giữa một từ (01T00 -> không có T00)
PROSE_CODE_RE = re.compile(
    r"(?<![\w/@.-])("
    r"@[A-Z][A-Za-z]+"                      # @Annotation
    r"|/(?:api|admin)/[A-Za-z0-9_\-/{}.]+"  # đường dẫn API / admin
    r"|[a-z]+[A-Z][A-Za-z0-9]*"             # lowerCamelCase
    r"|[A-Za-z][A-Za-z0-9]*_[A-Za-z0-9_]+"  # snake_case / HẰNG_SỐ
    r")")
# Từ khóa ngôn ngữ và từ chung của các đoạn mã (Java, JS/mongosh, JSON, Lua, shell): không cần tìm trong mã nguồn.
STOP = set("""
abstract assert boolean break byte case catch char class const continue default do double else enum extends final
finally float for goto if implements import instanceof int interface long native new package private protected public
return short static strictfp super switch synchronized this throw throws transient try void volatile while var let
function true false null undefined local then end and or not nil print printjson return yield record sealed permits
String Integer Long Boolean Double Object List Map Set Optional Override Exception RuntimeException
echo export sudo curl docker compose exec run sh bash cat grep
""".split())


def text_of(p):
    return "".join(re.findall(r"<w:t[^>]*>([^<]*)</w:t>", p)).replace("&lt;", "<").replace("&gt;", ">") \
        .replace("&amp;", "&").replace("&quot;", '"')


def style_of(p):
    m = re.search(r'<w:pStyle w:val="([^"]+)"', p)
    return m.group(1) if m else ""


def load_paragraphs(docx):
    """[(chương, style, text)] theo thứ tự; chương = số Heading1 đã gặp (0 = phần đầu)."""
    with zipfile.ZipFile(docx) as z:
        xml = z.read("word/document.xml").decode("utf8")
    out, chapter = [], 0
    for m in P_RE.finditer(xml):
        p = m.group(0)
        st = style_of(p)
        if st == "Heading1":
            chapter += 1
        out.append((chapter, st, text_of(p), "yellow" in p and "highlight" in p))
    return out


def placeholder_pngs(docx):
    """Mã S-xx của các ảnh giữ chỗ còn trong word/media (khóa tEXt do make_placeholder_png.py ghi)."""
    found = []
    with zipfile.ZipFile(docx) as z:
        for name in z.namelist():
            if name.startswith("word/media/") and name.lower().endswith(".png"):
                data = z.read(name)
                m = re.search(PLACEHOLDER_PNG_KEY.encode() + rb"\x00(S-\d{2,3})", data)
                if m:
                    found.append((m.group(1).decode(), name))
    return sorted(found)


def facts_index(facts_path):
    text = facts_path.read_text(encoding="utf8")
    ids = set(re.findall(r"^\|\s*((?:FR|NFR|AP|TC|S|Q)-\d{2,3})\s*\|", text, flags=re.M))
    sha = re.search(r"CODE_SHA:\s*`?([0-9a-f]{40})", text)
    return text, ids, sha.group(1) if sha else None


def reference_numbers_from_md(refs_path):
    if not refs_path or not refs_path.exists():
        return set()
    return {int(n) for n in re.findall(r"^\s*(?:#+\s*)?\[(\d+)\]", refs_path.read_text(encoding="utf8"), flags=re.M)}


def expand_citation(body):
    nums = []
    for part in re.split(r"\s*,\s*", body):
        if re.search(r"[–-]", part):
            a, b = [int(x) for x in re.split(r"\s*[–-]\s*", part)]
            nums.extend(range(a, b + 1))
        else:
            nums.append(int(part))
    return nums


class GitGrep:
    def __init__(self, repo, sha):
        self.repo, self.sha, self.cache = repo, sha, {}

    def has(self, token):
        if token not in self.cache:
            if not self.sha:
                self.cache[token] = False
            else:
                r = subprocess.run(["git", "-C", str(self.repo), "grep", "-q", "-F", "-w", "-e", token, self.sha, "--", "."],
                                   capture_output=True)
                self.cache[token] = r.returncode == 0
        return self.cache[token]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("docx")
    ap.add_argument("--chapter", type=int)
    ap.add_argument("--facts", default=str(HERE.parent / "facts.md"))
    ap.add_argument("--refs", default=str(HERE.parent / "references.md"))
    ap.add_argument("--repo", default=str(HERE.parents[2]))
    args = ap.parse_args()

    paras = load_paragraphs(args.docx)
    facts_path = Path(args.facts)
    facts_text, known_ids, sha = facts_index(facts_path) if facts_path.exists() else ("", set(), None)
    grep = GitGrep(Path(args.repo), sha)
    # Định danh trọn vẹn (không so chuỗi con): topSpender không được qua chỉ vì có topSpenders.
    facts_idents = set(re.findall(r"[A-Za-z_][A-Za-z0-9_]*", facts_text))

    def known_ident(tok):
        return tok in facts_idents or grep.has(tok)
    errors, infos = [], []
    ch = args.chapter

    def in_scope(c):
        return ch is None or c == ch

    # Danh sách tài liệu trong docx (đoạn [n] sau tiêu đề Tài liệu tham khảo, trước tiêu đề kế tiếp).
    doc_refs, in_refs = set(), False
    for c, st, t, _ in paras:
        if st.startswith("Heading") or st == "TieuDeKhongSo":
            in_refs = "tài liệu tham khảo" in t.lower()
            continue
        if in_refs:
            m = re.match(r"\s*\[(\d+)\]", t)
            if m:
                doc_refs.add(int(m.group(1)))
    entries = doc_refs or reference_numbers_from_md(Path(args.refs))
    entry_source = "docx" if doc_refs else "references.md"

    captions = set()
    for c, st, t, _ in paras:
        if st in ("Caption", "ChuThichBang"):
            m = CAPTION_RE.match(t)
            if m:
                captions.add((m.group(1), int(m.group(2)), int(m.group(3))))

    cited_order, cited = [], set()
    yellow = placeholders = 0
    in_refs = False
    for c, st, t, is_yellow in paras:
        if st.startswith("Heading") or st == "TieuDeKhongSo":
            in_refs = "tài liệu tham khảo" in t.lower()
        # 1. dòng giữ chỗ
        for m in re.finditer(r"\[T7\.c(\d+)_\w*\]", t):
            if ch is None or int(m.group(1)) == ch:
                errors.append(f"còn dòng giữ chỗ {m.group(0)} (chương {c}): {t[:70]!r}")
        # 2. [[ chưa giải
        if "[[" in t:
            errors.append(f"còn tham chiếu chưa giải '[[' (chương {c}): {t[:70]!r}")
        if re.match(r"\s*\[T7\.\w+\]", t):
            placeholders += 1
            continue  # dòng giữ chỗ chỉ là ghi chú cho người viết, không phải nội dung
        if not in_scope(c):
            continue
        if is_yellow:
            yellow += 1
        if st == "MaNguon":
            for tok in set(CODE_TOKEN_RE.findall(t)):
                bare = tok.lstrip("@$")
                if len(bare) < 3 or bare in STOP or bare.isdigit():
                    continue
                if not known_ident(bare):
                    errors.append(f"định danh trong MaNguon không có trong facts.md / mã nguồn @{(sha or '?')[:7]}: {tok!r} (chương {c})")
            continue
        # 3. trích dẫn
        if not in_refs:
            for m in CITE_RE.finditer(t):
                for n in expand_citation(m.group(1)):
                    if n not in cited:
                        cited_order.append(n)
                    cited.add(n)
                    if n not in entries:
                        errors.append(f"trích dẫn [{n}] không có mục tài liệu ({entry_source}) (chương {c}): {t[:60]!r}")
        # 4. Hình/Bảng c.n
        if st not in ("Caption", "ChuThichBang"):
            for m in REF_RE.finditer(t):
                label, a, b, sep, second = m.groups()
                lab = "Hình" if label.lower() == "hình" else "Bảng"
                targets = [(lab, int(a), int(b))]
                if second:
                    l2 = re.search(r"(Hình|Bảng|hình|bảng) $", sep or "")
                    lab2 = ("Hình" if l2.group(1).lower() == "hình" else "Bảng") if l2 else lab
                    c2, n2 = second.split(".")
                    targets.append((lab2, int(c2), int(n2)))
                for tgt in targets:
                    if tgt not in captions:
                        errors.append(f"tham chiếu {tgt[0]} {tgt[1]}.{tgt[2]} không có chú thích (chương {c}): {t[:60]!r}")
        # 5. mã định danh + token dạng mã trong văn bản
        for m in ID_RE.finditer(t):
            if m.group(1) not in known_ids:
                errors.append(f"mã {m.group(1)} không có trong bảng của facts.md (chương {c})")
        if not in_refs:
            for tok in set(PROSE_CODE_RE.findall(t)):
                core = tok.rstrip(".,;:)")
                if core.startswith("/"):
                    # Đường dẫn: phải có nguyên văn trong facts.md (bảng endpoint §1.5), kể cả {id}.
                    if re.search(re.escape(core) + r"(?![A-Za-z0-9_/-])", facts_text):
                        continue
                elif known_ident(core.lstrip("@")):
                    continue
                errors.append(f"token dạng mã không có trong facts.md / mã nguồn @{(sha or '?')[:7]}: {tok!r} (chương {c})")

    if ch is None and placeholders:
        infos.append(f"hoãn kiểm tra 'mục tài liệu không được trích' vì còn {placeholders} dòng giữ chỗ")
    elif ch is None:
        for n in sorted(entries - cited):
            errors.append(f"mục tài liệu [{n}] ({entry_source}) không được trích lần nào")
        if cited_order and cited_order != sorted(cited_order):
            infos.append(f"thứ tự trích dẫn lần đầu chưa tăng dần (IEEE đánh số theo lần trích đầu): {cited_order[:20]}")
    if not sha:
        infos.append("facts.md không có CODE_SHA: chỉ so được với facts.md")
    for sid, name in placeholder_pngs(args.docx):
        infos.append(f"{sid} – chưa chụp ({name})")
    if yellow:
        infos.append(f"{yellow} đoạn tô vàng (ghi chú/giữ chỗ) trong phạm vi kiểm tra")

    scope = f"chương {ch}" if ch is not None else "toàn văn"
    for e in errors:
        print("LỖI:", e)
    for i in infos:
        print("TT :", i)
    print(f"check_report ({scope}): {len(errors)} lỗi, {len(infos)} thông tin")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
