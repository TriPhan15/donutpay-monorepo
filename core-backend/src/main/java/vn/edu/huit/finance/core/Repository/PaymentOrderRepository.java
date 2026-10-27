package vn.edu.huit.finance.core.Repository;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import vn.edu.huit.finance.core.Entity.PaymentOrder;

import java.util.List;
import java.util.Optional;

public interface PaymentOrderRepository extends JpaRepository<PaymentOrder, Long> {

    Optional<PaymentOrder> findByOrderCode(String orderCode);

    /**
     * Đọc đơn kèm khóa ghi (SELECT ... FOR UPDATE): hai webhook cùng một đơn xếp hàng nhau, webhook sau đọc lại trạng thái
     * đã chốt của webhook trước và bỏ qua, nên ví không bị cộng hai lần.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select o from PaymentOrder o where o.orderCode = :orderCode")
    Optional<PaymentOrder> findLockedByOrderCode(@Param("orderCode") String orderCode);

    List<PaymentOrder> findByUserIdOrderByCreatedAtDesc(Long userId);
}
