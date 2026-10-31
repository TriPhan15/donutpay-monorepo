"""Trích chữ của một tệp .docx ra tệp .txt, mỗi dòng một đoạn: [P<số>|<style>] chữ, hoặc một dòng của bảng: [T<số>.r<dòng>] ô | ô.

Cách dùng: python3 -I extract_text.py <tệp.docx> <tệp.txt>. Dùng để so trước và sau khi sửa (diff hai tệp .txt)."""
import zipfile, sys, re
import xml.etree.ElementTree as ET
W='{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'
z=zipfile.ZipFile(sys.argv[1]); root=ET.fromstring(z.read('word/document.xml'))
body=root.find(W+'body'); out=[]; n=0
def ptext(p):
    return ''.join(t.text or '' for t in p.iter() if t.tag in (W+'t',)) 
for el in body:
    if el.tag==W+'p':
        n+=1; st=el.find(f'{W}pPr/{W}pStyle'); s=st.get(W+'val') if st is not None else ''
        t=ptext(el).strip()
        if t: out.append(f'[P{n}|{s}] {t}')
    elif el.tag==W+'tbl':
        n+=1
        for r,tr in enumerate(el.iter(W+'tr')):
            cells=[ptext(tc).strip() for tc in tr.findall(W+'tc')]
            out.append(f'[T{n}.r{r}] '+' | '.join(cells))
open(sys.argv[2],'w').write('\n'.join(out))
