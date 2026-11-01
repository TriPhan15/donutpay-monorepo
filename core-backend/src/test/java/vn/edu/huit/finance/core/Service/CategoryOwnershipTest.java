package vn.edu.huit.finance.core.Service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.autoconfigure.orm.jpa.TestEntityManager;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import vn.edu.huit.finance.core.Entity.Category;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Exception.InvalidCategoryException;
import vn.edu.huit.finance.core.Repository.CategoryRepository;
import vn.edu.huit.finance.core.Security.CurrentUserProvider;
import vn.edu.huit.finance.core.Service.Audit.AuditActor;

import java.text.Normalizer;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.when;

/**
 * The categories a user names themselves belong to that user (B8), against the real repository and mapping (H2). The
 * default categories (no owner) stay shared; a name a user types is looked up among the defaults and their own only,
 * and created for them when it is new.
 */
@DataJpaTest(properties = {
        "spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.H2Dialect",
        "spring.jpa.hibernate.ddl-auto=create-drop"})
@Import({CategoryService.class, AuditLogService.class})
class CategoryOwnershipTest {

    private static final String EXPENSE = CategoryService.TYPE_EXPENSE;
    private static final String CAFE = "Cafe sáng";

    @Autowired private CategoryService service;
    @Autowired private CategoryRepository categoryRepository;
    @Autowired private TestEntityManager entityManager;
    @MockBean private CurrentUserProvider currentUserProvider;

    private int userSeed;
    private User alice;
    private User bob;

    @BeforeEach
    void setUp() {
        alice = persistUser("alice");
        bob = persistUser("bob");
    }

    private User persistUser(String username) {
        User user = new User();
        user.setUsername(username);
        user.setPassword("hash");
        user.setEmail(username + "@example.com");
        user.setPhone(String.format("09%08d", ++userSeed));
        return entityManager.persistAndFlush(user);
    }

    private Category sharedCategory(String name, String type) {
        Category category = new Category();
        category.setName(name);
        category.setType(type);
        return entityManager.persistAndFlush(category);
    }

    private Category typed(User caller, String name) {
        return service.resolveOrCreate(null, name, EXPENSE, caller, AuditActor.of(caller));
    }

    private long countNamed(String name) {
        return categoryRepository.findAll().stream().filter(c -> c.getName().equalsIgnoreCase(name)).count();
    }

    /** What GET /api/categories lists for the user. */
    private List<String> visibleTo(User user) {
        return categoryRepository.findVisibleTo(user.getId()).stream().map(Category::getName).toList();
    }

    // -------------------------------------------------------------------------------------- the same name twice

    @Test
    void aliceTypingTheSameNewNameTwiceCreatesOneCategory() {
        Category first = typed(alice, CAFE);
        Category second = typed(alice, "  cafe SÁNG ");

        assertEquals(first.getId(), second.getId());
        assertEquals(1, countNamed(CAFE));
        assertEquals(alice.getId(), first.getOwner().getId());
    }

    @Test
    void bobTypingTheSameNameGetsACategoryOfHisOwn_andAliceKeepsHers() {
        Category alices = typed(alice, CAFE);
        Category bobs = typed(bob, CAFE);

        assertNotEquals(alices.getId(), bobs.getId());
        assertEquals(bob.getId(), bobs.getOwner().getId());
        assertEquals(alice.getId(), alices.getOwner().getId());
        assertEquals(2, countNamed(CAFE));
        assertEquals(bobs.getId(), typed(bob, CAFE).getId());
    }

    // -------------------------------------------------------------------------------------------- who sees what

    @Test
    void aUserSeesTheDefaultCategoriesAndTheirOwn_neverAnotherUsers() {
        sharedCategory("Ăn uống", EXPENSE);
        typed(alice, CAFE);
        typed(bob, "Phở tối");

        assertEquals(List.of("Ăn uống", CAFE), visibleTo(alice));
        assertEquals(List.of("Ăn uống", "Phở tối"), visibleTo(bob));
    }

    @Test
    void aCategoryOfAnotherUserCannotBeUsedById_asIfItDidNotExist() {
        Category bobs = typed(bob, CAFE);

        InvalidCategoryException refused = assertThrows(InvalidCategoryException.class,
                () -> service.resolveOrCreate(bobs.getId(), null, EXPENSE, alice, AuditActor.of(alice)));

        assertEquals("Không tìm thấy danh mục", refused.getMessage());
        assertEquals(bobs.getId(), service.resolveOrCreate(bobs.getId(), null, EXPENSE, bob, AuditActor.of(bob)).getId());
    }

    @Test
    void aDefaultCategoryIsUsableByIdByEveryone() {
        Category food = sharedCategory("Ăn uống", EXPENSE);

        assertEquals(food.getId(), service.resolveOrCreate(food.getId(), null, EXPENSE, alice, AuditActor.of(alice)).getId());
        assertEquals(food.getId(), service.resolveOrCreate(food.getId(), null, EXPENSE, bob, AuditActor.of(bob)).getId());
    }

    // --------------------------------------------------------------------------- defaults stay shared and canonical

    @Test
    void aNewDefaultNameTypedByAUserIsTheSharedCategoryAndInItsCanonicalSpelling() {
        Category fromAlice = typed(alice, "ăn UỐNG");
        Category fromBob = typed(bob, "Ăn uống");

        assertEquals("Ăn uống", fromAlice.getName());
        assertNull(fromAlice.getOwner(), "a default category belongs to nobody");
        assertEquals(fromAlice.getId(), fromBob.getId());
        assertEquals(1, countNamed("Ăn uống"));
        assertEquals(List.of("Ăn uống"), visibleTo(bob));
    }

    @Test
    void aNameAdministratorsAlreadyAddedIsReusedNotCopiedPerUser() {
        Category added = sharedCategory("Thú cưng", EXPENSE);

        assertEquals(added.getId(), typed(alice, "thú cưng").getId());
        assertEquals(added.getId(), typed(bob, "Thú cưng").getId());
        assertEquals(1, countNamed("Thú cưng"));
    }

    // ---------------------------------------------------------------------------------------------------- NFC (B7c)

    @Test
    void aNameTypedDecomposedIsStoredComposedAndMatchesTheComposedOne() {
        String composed = Normalizer.normalize(CAFE, Normalizer.Form.NFC);
        String decomposed = Normalizer.normalize(CAFE, Normalizer.Form.NFD);
        assertNotEquals(composed, decomposed);

        Category first = typed(alice, decomposed);
        Category second = typed(alice, composed);

        assertEquals(composed, first.getName());
        assertEquals(first.getId(), second.getId());
        assertEquals(1, countNamed(composed));
    }

    @Test
    void theSavingsCategoryTypedDecomposedIsTheSavingsCategory() {
        String decomposed = Normalizer.normalize("Tiết kiệm", Normalizer.Form.NFD);

        Category savings = typed(alice, decomposed);

        assertEquals("Tiết kiệm", savings.getName());
        assertNull(savings.getOwner());
        assertEquals(savings.getId(), typed(bob, "Tiết kiệm").getId());
    }

    // ---------------------------------------------------------------------------------------------- administrators

    @Test
    void aCategoryAnAdministratorAddsIsADefaultOne_visibleToEveryone() {
        when(currentUserProvider.getCurrentUser()).thenReturn(alice);

        service.createCategory("Học phí", EXPENSE);

        assertEquals(List.of("Học phí"), visibleTo(alice));
        assertEquals(List.of("Học phí"), visibleTo(bob));
        assertNull(categoryRepository.findAll().get(0).getOwner());
    }
}
