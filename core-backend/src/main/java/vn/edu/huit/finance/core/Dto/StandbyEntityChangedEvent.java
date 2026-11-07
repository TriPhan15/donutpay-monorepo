package vn.edu.huit.finance.core.Dto;

/**
 * Sự kiện nội bộ phát ra khi các thực thể nghiệp vụ cốt lõi ({@code User}, {@code Category}, {@code Receipt},
 * {@code Budget}, {@code SavingGoal}) thay đổi trên PostgreSQL. Được lắng nghe bởi {@code MongoSelectiveMirrorService}
 * sau khi transaction PostgreSQL commit ({@code AFTER_COMMIT}) để đồng bộ bất đồng bộ sang MongoDB.
 */
public record StandbyEntityChangedEvent(EntityType entityType, Long entityId, boolean deleted) {

    public enum EntityType {
        USER,
        ALL_USERS,
        CATEGORY,
        RECEIPT,
        BUDGET,
        SAVING_GOAL
    }

    public static StandbyEntityChangedEvent userUpserted(Long userId) {
        return new StandbyEntityChangedEvent(EntityType.USER, userId, false);
    }

    public static StandbyEntityChangedEvent userDeleted(Long userId) {
        return new StandbyEntityChangedEvent(EntityType.USER, userId, true);
    }

    public static StandbyEntityChangedEvent allUsersUpdated() {
        return new StandbyEntityChangedEvent(EntityType.ALL_USERS, 0L, false);
    }

    public static StandbyEntityChangedEvent categoryUpserted(Long categoryId) {
        return new StandbyEntityChangedEvent(EntityType.CATEGORY, categoryId, false);
    }

    public static StandbyEntityChangedEvent categoryDeleted(Long categoryId) {
        return new StandbyEntityChangedEvent(EntityType.CATEGORY, categoryId, true);
    }

    public static StandbyEntityChangedEvent receiptUpserted(Long receiptId) {
        return new StandbyEntityChangedEvent(EntityType.RECEIPT, receiptId, false);
    }

    public static StandbyEntityChangedEvent budgetUpserted(Long budgetId) {
        return new StandbyEntityChangedEvent(EntityType.BUDGET, budgetId, false);
    }

    public static StandbyEntityChangedEvent budgetDeleted(Long budgetId) {
        return new StandbyEntityChangedEvent(EntityType.BUDGET, budgetId, true);
    }

    public static StandbyEntityChangedEvent savingGoalUpserted(Long goalId) {
        return new StandbyEntityChangedEvent(EntityType.SAVING_GOAL, goalId, false);
    }

    public static StandbyEntityChangedEvent savingGoalDeleted(Long goalId) {
        return new StandbyEntityChangedEvent(EntityType.SAVING_GOAL, goalId, true);
    }
}
