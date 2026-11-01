package vn.edu.huit.finance.core.Util;

import org.junit.jupiter.api.Test;
import vn.edu.huit.finance.core.Entity.DefaultCategory;

import java.text.Normalizer;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;

class CategoryNamesTest {

    @Test
    void aNameIsTrimmedAndComposed() {
        String decomposed = Normalizer.normalize("  Cà phê sáng\t", Normalizer.Form.NFD);

        assertEquals("Cà phê sáng", CategoryNames.clean(decomposed));
    }

    @Test
    void aComposedNameIsLeftAlone() {
        assertEquals("Thú cưng", CategoryNames.clean("Thú cưng"));
    }

    @Test
    void theComposedAndTheDecomposedSpellingOfOneNameCleanToTheSameText() {
        String composed = Normalizer.normalize("Đầu tư", Normalizer.Form.NFC);
        String decomposed = Normalizer.normalize("Đầu tư", Normalizer.Form.NFD);
        assertNotEquals(composed, decomposed);

        assertEquals(CategoryNames.clean(composed), CategoryNames.clean(decomposed));
    }

    @Test
    void everyDefaultCategoryIsWrittenComposed_soComparingByCleanedNameFindsIt() {
        for (DefaultCategory category : DefaultCategory.values()) {
            assertEquals(category.getDisplayName(), CategoryNames.clean(category.getDisplayName()), category.name());
        }
    }
}
