package vn.edu.huit.finance.core.Util;

import java.text.Normalizer;

/**
 * A category name as it is stored and compared. A keyboard (or an app) may send a Vietnamese name decomposed (NFD: a base
 * letter followed by combining marks) while the default categories are written composed (NFC); the two look the same but
 * are different strings, so a name is always brought to NFC, and trimmed, before it is looked up or saved.
 */
public final class CategoryNames {

    private CategoryNames() {
    }

    /** [name] trimmed and in Unicode normalization form NFC. */
    public static String clean(String name) {
        return Normalizer.normalize(name, Normalizer.Form.NFC).trim();
    }
}
