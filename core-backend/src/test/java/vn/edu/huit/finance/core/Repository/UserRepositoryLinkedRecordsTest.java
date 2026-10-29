package vn.edu.huit.finance.core.Repository;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.autoconfigure.orm.jpa.TestEntityManager;
import vn.edu.huit.finance.core.Entity.Budget;
import vn.edu.huit.finance.core.Entity.BudgetPeriodType;
import vn.edu.huit.finance.core.Entity.Category;
import vn.edu.huit.finance.core.Entity.Transaction;
import vn.edu.huit.finance.core.Entity.User;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** UserRepository.existsLinkedRecords on H2: what decides whether UserService deletes an account or only locks it (A1). */
@DataJpaTest(properties = {
        "spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.H2Dialect",
        "spring.jpa.hibernate.ddl-auto=create-drop"})
class UserRepositoryLinkedRecordsTest {

    @Autowired private UserRepository userRepository;
    @Autowired private TestEntityManager entityManager;

    private User alice;

    @BeforeEach
    void setUp() {
        alice = user("alice", "0900000001");
    }

    private User user(String name, String phone) {
        User user = new User();
        user.setUsername(name);
        user.setPassword("hash");
        user.setEmail(name + "@example.com");
        user.setPhone(phone);
        return entityManager.persistAndFlush(user);
    }

    @Test
    void anAccountWithoutAnyRecordHasNone() {
        assertFalse(userRepository.existsLinkedRecords(alice.getId()));
    }

    @Test
    void aTransactionIsALinkedRecord() {
        Category food = new Category();
        food.setName("Ăn uống");
        food.setType("EXPENSE");
        entityManager.persist(food);
        Transaction transaction = new Transaction();
        transaction.setUser(alice);
        transaction.setCategory(food);
        transaction.setAmount(new BigDecimal("1000"));
        transaction.setTransactionDate(LocalDateTime.of(2026, 10, 1, 8, 0));
        transaction.setExpense(true);
        entityManager.persistAndFlush(transaction);

        assertTrue(userRepository.existsLinkedRecords(alice.getId()));
    }

    @Test
    void aBudgetAloneIsALinkedRecordToo_andOtherUsersAreNotAffected() {
        User bob = user("bob", "0900000002");
        Budget budget = new Budget();
        budget.setUser(alice);
        budget.setAmount(new BigDecimal("500000"));
        budget.setPeriodType(BudgetPeriodType.MONTH);
        budget.setStartDate(LocalDate.of(2026, 10, 1));
        budget.setEndDate(LocalDate.of(2026, 10, 31));
        entityManager.persistAndFlush(budget);

        assertTrue(userRepository.existsLinkedRecords(alice.getId()));
        assertFalse(userRepository.existsLinkedRecords(bob.getId()));
    }
}
