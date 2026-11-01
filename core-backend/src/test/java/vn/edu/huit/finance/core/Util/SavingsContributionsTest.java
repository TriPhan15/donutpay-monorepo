package vn.edu.huit.finance.core.Util;

import org.junit.jupiter.api.Test;
import vn.edu.huit.finance.core.Entity.Category;
import vn.edu.huit.finance.core.Entity.DefaultCategory;
import vn.edu.huit.finance.core.Entity.Transaction;

import java.text.Normalizer;

import static org.assertj.core.api.Assertions.assertThat;

class SavingsContributionsTest {

    private static Category category(String name, String type) {
        Category category = new Category();
        category.setName(name);
        category.setType(type);
        return category;
    }

    private static Transaction tx(boolean expense, Category category) {
        Transaction transaction = new Transaction();
        transaction.setExpense(expense);
        transaction.setCategory(category);
        return transaction;
    }

    @Test
    void anExpenseInTheSavingsCategoryIsAContribution() {
        assertThat(SavingsContributions.isContribution(
                tx(true, category(DefaultCategory.SAVINGS.getDisplayName(), DefaultCategory.TYPE_EXPENSE)))).isTrue();
    }

    @Test
    void anIncomeOrAnotherCategoryIsNot() {
        assertThat(SavingsContributions.isContribution(
                tx(false, category(SavingsContributions.CATEGORY_NAME, DefaultCategory.TYPE_EXPENSE)))).isFalse();
        assertThat(SavingsContributions.isContribution(
                tx(true, category("Ăn uống", DefaultCategory.TYPE_EXPENSE)))).isFalse();
        assertThat(SavingsContributions.isSavingsCategory(null)).isFalse();
    }

    @Test
    void aSavingsCategoryWhoseNameWasStoredDecomposedIsStillTheSavingsCategory() {
        String decomposed = Normalizer.normalize(SavingsContributions.CATEGORY_NAME, Normalizer.Form.NFD);
        assertThat(decomposed).isNotEqualTo(SavingsContributions.CATEGORY_NAME);

        assertThat(SavingsContributions.isContribution(
                tx(true, category(decomposed, DefaultCategory.TYPE_EXPENSE)))).isTrue();
    }

    @Test
    void aSavingsNamedCategoryOfTheIncomeTypeIsNotASavingsCategory() {
        assertThat(SavingsContributions.isSavingsCategory(
                category(SavingsContributions.CATEGORY_NAME, DefaultCategory.TYPE_INCOME))).isFalse();
    }
}
