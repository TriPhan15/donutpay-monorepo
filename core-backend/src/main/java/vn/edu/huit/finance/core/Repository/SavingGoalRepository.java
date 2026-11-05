package vn.edu.huit.finance.core.Repository;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import vn.edu.huit.finance.core.Entity.SavingGoal;
import java.util.List;
import java.util.Optional;

public interface SavingGoalRepository extends JpaRepository<SavingGoal, Long> {
    List<SavingGoal> findByUserIdOrderByCreatedAtDesc(Long userId);

    /** True when the user has at least one savings goal (reached or not). */
    boolean existsByUserId(Long userId);

    /**
     * One goal, its row locked (SELECT ... FOR UPDATE) until the end of the transaction, so that two contributions to the
     * same goal add up instead of overwriting each other's currentAmount. Call it before the goal is otherwise loaded in
     * the transaction: a goal already in the persistence context would keep the state it was read with.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT g FROM SavingGoal g WHERE g.id = :id")
    Optional<SavingGoal> findLockedById(@Param("id") Long id);

    @Query("SELECT g FROM SavingGoal g JOIN FETCH g.user ORDER BY g.id")
    List<SavingGoal> findAllWithUser();

    @Query("SELECT g FROM SavingGoal g JOIN FETCH g.user WHERE g.id = :id")
    Optional<SavingGoal> findByIdWithUser(@Param("id") Long id);
}