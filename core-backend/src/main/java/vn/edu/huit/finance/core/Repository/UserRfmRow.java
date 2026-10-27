package vn.edu.huit.finance.core.Repository;

import java.math.BigDecimal;

/** Một dòng RFM của một người dùng: số ngày từ lần chi gần nhất, số lần chi, tổng tiền chi. */
public interface UserRfmRow {
    Long getUserId();

    Integer getRecency();

    Long getFrequency();

    BigDecimal getMonetary();
}
