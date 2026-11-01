package vn.edu.huit.finance.core.Repository;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import vn.edu.huit.finance.core.Entity.AppReview;

import java.util.List;

@Repository
public interface AppReviewRepository extends JpaRepository<AppReview, Long> {
    Page<AppReview> findAllByOrderByCreatedAtDesc(Pageable pageable);
    List<AppReview> findByStatusOrderByCreatedAtDesc(String status);
}