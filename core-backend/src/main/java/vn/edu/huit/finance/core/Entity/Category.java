package vn.edu.huit.finance.core.Entity;
import org.hibernate.annotations.ColumnDefault;
import org.hibernate.envers.Audited;
import org.hibernate.envers.NotAudited;
import jakarta.persistence.*;
import lombok.*;
import java.util.List;
import java.util.Objects;

import com.fasterxml.jackson.annotation.JsonIgnore;
/**
 * A category of transactions and budgets. A default category (and one an administrator adds) belongs to nobody and every
 * user sees it; one a user creates by typing its name belongs to that user, and only that user sees it (B8).
 * A name is unique per owner, not overall: two users can each have a "Cafe sáng" of their own.
 */
@Audited
@Entity
@Table(name = "categories",
        uniqueConstraints = @UniqueConstraint(name = "uk_categories_owner_name", columnNames = {"owner_key", "name"}),
        indexes = @Index(name = "idx_categories_owner_id", columnList = "owner_id"))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class Category extends BaseEntity {

    /** Value of {@code owner_key} for a category that belongs to nobody; no user has id 0. */
    public static final long SYSTEM_OWNER_KEY = 0L;
    private static final String MSG_OWNER_NOT_SAVED = "The owner of a category must be a saved user";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false)
    private String type;

    /** The user who created the category by typing its name. Null for a default category and for one an administrator added. */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "owner_id", foreignKey = @ForeignKey(name = "fk_categories_owner"))
    private User owner;

    /**
     * Mirror of owner_id that is never null. SQL treats NULLs as distinct, so a unique constraint on (owner_id, name)
     * would let the default categories repeat a name. Only setOwner writes it. Not audited: it is derived from the owner.
     */
    @Setter(AccessLevel.NONE)
    @NotAudited
    @ColumnDefault("0")
    @Column(name = "owner_key", nullable = false)
    private long ownerKey = SYSTEM_OWNER_KEY;

    @OneToMany(mappedBy = "category", fetch = FetchType.LAZY)
    @ToString.Exclude
    @JsonIgnore
    private List<Transaction> transactions;

    public void setOwner(User owner) {
        this.owner = owner;
        this.ownerKey = owner == null ? SYSTEM_OWNER_KEY : Objects.requireNonNull(owner.getId(), MSG_OWNER_NOT_SAVED);
    }
}
