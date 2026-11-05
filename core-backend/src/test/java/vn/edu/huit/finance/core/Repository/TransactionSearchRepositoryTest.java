package vn.edu.huit.finance.core.Repository;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.autoconfigure.orm.jpa.TestEntityManager;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import vn.edu.huit.finance.core.Entity.Category;
import vn.edu.huit.finance.core.Entity.Receipt;
import vn.edu.huit.finance.core.Entity.Transaction;
import vn.edu.huit.finance.core.Entity.User;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** The PostgreSQL side of the transaction search, on H2: the LIKE pattern, the ownership filter and the join to the receipt. */
@DataJpaTest(properties = {
        "spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.H2Dialect",
        "spring.jpa.hibernate.ddl-auto=create-drop"})
class TransactionSearchRepositoryTest {

    @Autowired private TransactionRepository transactionRepository;
    @Autowired private TestEntityManager entityManager;

    private User alice;
    private User bob;
    private Category food;

    @BeforeEach
    void setUp() {
        alice = user("alice", "0900000001");
        bob = user("bob", "0900000002");
        food = new Category();
        food.setName("Ăn uống");
        food.setType("EXPENSE");
        entityManager.persist(food);
    }

    private User user(String name, String phone) {
        User user = new User();
        user.setUsername(name);
        user.setPassword("hash");
        user.setEmail(name + "@example.com");
        user.setPhone(phone);
        entityManager.persist(user);
        return user;
    }

    private Transaction save(User owner, String note, String vendor, LocalDateTime date) {
        return saveWithReview(owner, note, vendor, null, null, date);
    }

    private Transaction saveWithReview(User owner, String note, String vendor, BigDecimal rating, String reviewNote, LocalDateTime date) {
        Transaction transaction = new Transaction();
        transaction.setUser(owner);
        transaction.setCategory(food);
        transaction.setCategoryName(food.getName());
        transaction.setAmount(new BigDecimal("100000"));
        transaction.setExpense(true);
        transaction.setNote(note);
        transaction.setRating(rating);
        transaction.setReviewNote(reviewNote);
        transaction.setTransactionDate(date);
        if (vendor != null) {
            Receipt receipt = new Receipt();
            receipt.setVendorName(vendor);
            receipt.setImageUrl("https://img.example.com/1.jpg");
            transaction.setReceipt(receipt);
        }
        entityManager.persist(transaction);
        entityManager.flush();
        return transaction;
    }

    @Test
    void likePattern_escapesPercentUnderscoreBackslash() {
        assertEquals("%50\\% off%", TransactionRepository.likePattern("50% OFF"));
        assertEquals("%a\\_b%", TransactionRepository.likePattern("a_b"));
        assertEquals("%c:\\\\x%", TransactionRepository.likePattern("C:\\x"));
    }

    @Test
    void searchIdsByText_matchesVendorThroughReceipt() {
        Transaction viaVendor = save(alice, "bữa trưa", "Phở Hưng", LocalDateTime.of(2026, 10, 1, 12, 0));
        save(alice, "cà phê", null, LocalDateTime.of(2026, 10, 2, 12, 0));

        Page<Long> page = transactionRepository.searchIdsByText(
                alice.getId(), TransactionRepository.likePattern("phở hưng"), PageRequest.of(0, 10));

        assertEquals(List.of(viaVendor.getId()), page.getContent());
        assertEquals(1, page.getTotalElements());
    }

    @Test
    void searchIdsByText_matchesReviewNote() {
        Transaction viaReview = saveWithReview(alice, "Highlands Coffee", "Highlands Coffee",
                new BigDecimal("1.5"), "Nhân viên thái độ tệ, đồ uống nguội", LocalDateTime.of(2026, 10, 1, 12, 0));
        save(alice, "Phúc Long", "Phúc Long", LocalDateTime.of(2026, 10, 2, 12, 0));

        Page<Long> page = transactionRepository.searchIdsByText(
                alice.getId(), TransactionRepository.likePattern("thái độ tệ"), PageRequest.of(0, 10));

        assertEquals(List.of(viaReview.getId()), page.getContent());
        assertEquals(1, page.getTotalElements());
    }

    @Test
    void searchIdsByText_onlyCallerRows() {
        Transaction mine = save(alice, "phở bò", null, LocalDateTime.of(2026, 10, 1, 12, 0));
        save(bob, "phở bò", null, LocalDateTime.of(2026, 10, 2, 12, 0));

        Page<Long> page = transactionRepository.searchIdsByText(
                alice.getId(), TransactionRepository.likePattern("phở"), PageRequest.of(0, 10));

        assertEquals(List.of(mine.getId()), page.getContent());
    }

    @Test
    void searchIdsByText_percentIsLiteral_andNewestFirst() {
        Transaction older = save(alice, "giảm 50% hôm nay", null, LocalDateTime.of(2026, 10, 1, 12, 0));
        Transaction newer = save(alice, "50% off", null, LocalDateTime.of(2026, 10, 3, 12, 0));
        save(alice, "500 nghìn", null, LocalDateTime.of(2026, 10, 2, 12, 0));

        Page<Long> page = transactionRepository.searchIdsByText(
                alice.getId(), TransactionRepository.likePattern("50%"), PageRequest.of(0, 10));

        assertEquals(List.of(newer.getId(), older.getId()), page.getContent());
    }

    @Test
    void findAllByIdInAndUserIdWithReceipt_skipsForeignIds() {
        Transaction mine = save(alice, "a", "Highlands", LocalDateTime.of(2026, 10, 1, 12, 0));
        Transaction theirs = save(bob, "b", "Highlands", LocalDateTime.of(2026, 10, 1, 12, 0));
        entityManager.clear();

        List<Transaction> found = transactionRepository.findAllByIdInAndUserIdWithReceipt(
                List.of(mine.getId(), theirs.getId()), alice.getId());

        assertEquals(1, found.size());
        assertEquals(mine.getId(), found.get(0).getId());
        assertTrue(entityManager.getEntityManager().getEntityManagerFactory().getPersistenceUnitUtil()
                .isLoaded(found.get(0), "receipt"));
    }
}
