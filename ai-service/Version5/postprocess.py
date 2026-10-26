"""Bản sao nguyên văn clean_vietnamese_text từ ai-service/ai_service.py:49-67.

Bundle Kaggle phải tự chứa đủ code nên chép lại ở đây; chỉ dùng khi chấm model V3
(tokenizer V3 làm sai dấu cách tiếng Việt, V5 không cần hàm này).
"""

import re


def clean_vietnamese_text(sequence: str) -> str:
    sequence = re.sub(r'([,.;])([A-ZĐa-zà-ỹ])', r'\1 \2', sequence)
    toned_vowels = "áắấéếíóốớúứýàằầèềìòồờùừỳảẳẩẻểỉỏổởủửỷãẵẫẽễĩõỗỡũữỹạặậẹệịọộợụựỵ"
    toned_vowels += toned_vowels.upper()
    sequence = re.sub(r'(["' + toned_vowels + r'])(["' + toned_vowels + r'])', r'\1 \2', sequence)

    all_vowels = "aăâeêioôơuưyáàảãạăắằẳẵặâấầẩẫậéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵĐđ"
    all_vowels += all_vowels.upper()
    tails = ["c", "ch", "m", "n", "ng", "nh", "p", "t", "i", "y", "a", "o", "u"]
    tails += [t.upper() for t in tails]
    tail_pattern = "|".join(tails)
    pattern = r"([" + all_vowels + r"])\s+(" + tail_pattern + r")\b"

    old_sequence = ""
    while old_sequence != sequence:
        old_sequence = sequence
        sequence = re.sub(pattern, r"\1\2", sequence)

    return sequence
