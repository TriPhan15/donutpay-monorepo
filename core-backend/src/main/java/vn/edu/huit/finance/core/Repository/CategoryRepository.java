package vn.edu.huit.finance.core.Repository;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import vn.edu.huit.finance.core.Entity.Category;

import java.util.List;
import java.util.Optional;

/**
 * The default categories have no owner and every user sees them; a category a user named belongs to that user. Every
 * lookup on behalf of a user goes through the findVisible methods, so a user never reaches another user's category.
 */
public interface CategoryRepository  extends JpaRepository<Category, Long> {

    /** The default categories and the user's own, oldest first. */
    @Query("select c from Category c where c.owner is null or c.owner.id = :ownerId order by c.id")
    List<Category> findVisibleTo(@Param("ownerId") Long ownerId);

    /** The category when it is a default one or the user's own; empty for another user's category, as if it did not exist. */
    @Query("select c from Category c where c.id = :id and (c.owner is null or c.owner.id = :ownerId)")
    Optional<Category> findVisibleById(@Param("id") Long id, @Param("ownerId") Long ownerId);

    /**
     * The categories named [name] (ignoring case) among the default ones and the user's own: the default ones first, then
     * the oldest, so a name that is both is the shared category.
     */
    @Query("select c from Category c where upper(c.name) = upper(:name) and (c.owner is null or c.owner.id = :ownerId) "
            + "order by c.ownerKey, c.id")
    List<Category> findVisibleByName(@Param("name") String name, @Param("ownerId") Long ownerId);

    /** The default categories only. */
    List<Category> findAllByOwnerIsNull();

    /** Every category with its owner loaded, for the administrators' page. */
    @Query("select c from Category c left join fetch c.owner order by c.id")
    List<Category> findAllWithOwner();

    @Query("select c from Category c left join fetch c.owner where c.id = :id")
    Optional<Category> findByIdWithOwner(@Param("id") Long id);
}
