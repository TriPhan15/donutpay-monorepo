package vn.edu.huit.finance.core.Repository;

import org.hibernate.SessionFactory;
import org.hibernate.stat.Statistics;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.autoconfigure.orm.jpa.TestEntityManager;
import org.springframework.dao.DataIntegrityViolationException;
import vn.edu.huit.finance.core.Entity.Category;
import vn.edu.huit.finance.core.Entity.User;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Which categories a user sees, and the uniqueness of their names, on the real mapping (H2): the default categories (no
 * owner) are everybody's, a category a user named belongs to that user, and a name is unique per owner, not overall, so
 * two users can each have a "Cafe sáng" while nobody gets the same name twice.
 */
@DataJpaTest(properties = {
        "spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.H2Dialect",
        "spring.jpa.hibernate.ddl-auto=create-drop",
        "spring.jpa.properties.hibernate.generate_statistics=true"})
class CategoryRepositoryTest {

    private static final String EXPENSE = "EXPENSE";
    private static final String CAFE = "Cafe sáng";

    @Autowired private CategoryRepository categoryRepository;
    @Autowired private TestEntityManager entityManager;

    private int userSeed;
    private User alice;
    private User bob;
    private Category food;

    @BeforeEach
    void setUp() {
        alice = persistUser("alice");
        bob = persistUser("bob");
        food = persistCategory("Ăn uống", null);
    }

    private User persistUser(String username) {
        User user = new User();
        user.setUsername(username);
        user.setPassword("hash");
        user.setEmail(username + "@example.com");
        user.setPhone(String.format("09%08d", ++userSeed));
        return entityManager.persistAndFlush(user);
    }

    private Category persistCategory(String name, User owner) {
        Category category = new Category();
        category.setName(name);
        category.setType(EXPENSE);
        category.setOwner(owner);
        return entityManager.persistAndFlush(category);
    }

    private static List<String> namesOf(List<Category> categories) {
        return categories.stream().map(Category::getName).toList();
    }

    private Statistics statistics() {
        return entityManager.getEntityManager().getEntityManagerFactory().unwrap(SessionFactory.class).getStatistics();
    }

    // ------------------------------------------------------------------------------------------ who sees what

    @Test
    void aUserSeesTheDefaultCategoriesAndTheirOwn_butNeverAnotherUsersCategory() {
        persistCategory(CAFE, alice);
        persistCategory("Phở tối", bob);

        assertEquals(List.of("Ăn uống", CAFE), namesOf(categoryRepository.findVisibleTo(alice.getId())));
        assertEquals(List.of("Ăn uống", "Phở tối"), namesOf(categoryRepository.findVisibleTo(bob.getId())));
    }

    @Test
    void aUserWithNoCategoryOfTheirOwnSeesOnlyTheDefaultOnes() {
        persistCategory(CAFE, alice);

        assertEquals(List.of("Ăn uống"), namesOf(categoryRepository.findVisibleTo(bob.getId())));
    }

    @Test
    void anotherUsersCategoryCannotBeFoundById_aDefaultOneAndTheirOwnCan() {
        Category alices = persistCategory(CAFE, alice);

        assertTrue(categoryRepository.findVisibleById(alices.getId(), alice.getId()).isPresent());
        assertTrue(categoryRepository.findVisibleById(food.getId(), alice.getId()).isPresent());
        assertTrue(categoryRepository.findVisibleById(food.getId(), bob.getId()).isPresent());
        assertTrue(categoryRepository.findVisibleById(alices.getId(), bob.getId()).isEmpty());
    }

    @Test
    void aNameIsFoundIgnoringCaseAmongTheDefaultAndTheCallersCategories_neverAmongAnotherUsers() {
        persistCategory(CAFE, alice);

        assertEquals(List.of(CAFE), namesOf(categoryRepository.findVisibleByName("cafe SÁNG", alice.getId())));
        assertEquals(List.of("Ăn uống"), namesOf(categoryRepository.findVisibleByName("ĂN UỐNG", bob.getId())));
        assertEquals(List.of(), categoryRepository.findVisibleByName(CAFE, bob.getId()));
    }

    @Test
    void whenTheDefaultAndTheCallersOwnShareAName_theDefaultComesFirst() {
        Category own = persistCategory("ăn uống", alice);

        List<Category> found = categoryRepository.findVisibleByName("Ăn uống", alice.getId());

        assertEquals(List.of(food.getId(), own.getId()), found.stream().map(Category::getId).toList());
    }

    @Test
    void theDefaultCategoriesAreTheOnesWithoutAnOwner() {
        persistCategory(CAFE, alice);

        assertEquals(List.of("Ăn uống"), namesOf(categoryRepository.findAllByOwnerIsNull()));
    }

    @Test
    void theAdminListLoadsEveryOwnerWithoutAQueryPerCategory() {
        persistCategory(CAFE, alice);
        persistCategory("Phở tối", bob);
        entityManager.flush();
        entityManager.clear();
        statistics().clear();

        List<String> creators = categoryRepository.findAllWithOwner().stream()
                .map(category -> category.getOwner() == null ? "system" : category.getOwner().getEmail())
                .toList();

        assertEquals(List.of("system", "alice@example.com", "bob@example.com"), creators);
        assertEquals(1, statistics().getPrepareStatementCount(), "listing must not issue a query per owner");
    }

    // ------------------------------------------------------------------------------------------ unique per owner

    @Test
    void twoUsersMayEachHaveTheSameName() {
        persistCategory(CAFE, alice);

        assertDoesNotThrow(() -> persistCategory(CAFE, bob));
    }

    @Test
    void aUserMayNotHaveTheSameNameTwice() {
        persistCategory(CAFE, alice);

        assertThrows(Exception.class, () -> persistCategory(CAFE, alice));
    }

    @Test
    void theDefaultCategoriesMayNotRepeatAName_althoughNullOwnersAreDistinctInSql() {
        assertThrows(Exception.class, () -> persistCategory("Ăn uống", null));
    }

    @Test
    void aNameOfTheDefaultCategoriesMayAlsoBeAUsersOwn_theDatabaseOnlyKeepsEachOwnerApart() {
        assertDoesNotThrow(() -> persistCategory("Ăn uống", alice));
    }

    @Test
    void theOwnerKeyFollowsTheOwner() {
        Category own = persistCategory(CAFE, alice);

        assertEquals(alice.getId(), own.getOwnerKey());
        assertEquals(Category.SYSTEM_OWNER_KEY, food.getOwnerKey());
        own.setOwner(null);
        assertEquals(Category.SYSTEM_OWNER_KEY, own.getOwnerKey());
    }

    @Test
    void aDuplicateIsRefusedWithSpringsIntegrityViolation_whichTheServiceTurnsIntoAConflict() {
        persistCategory(CAFE, alice);
        Category again = new Category();
        again.setName(CAFE);
        again.setType(EXPENSE);
        again.setOwner(alice);

        assertThrows(DataIntegrityViolationException.class, () -> categoryRepository.saveAndFlush(again));
    }
}
