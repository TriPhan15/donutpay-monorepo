package vn.edu.huit.finance.core.Service.DemoData;

import com.fasterxml.jackson.databind.node.JsonNodeFactory;
import com.fasterxml.jackson.databind.node.ObjectNode;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.edu.huit.finance.core.Config.DemoSeedProperties;
import vn.edu.huit.finance.core.Entity.AuditAction;
import vn.edu.huit.finance.core.Entity.Budget;
import vn.edu.huit.finance.core.Entity.BudgetPeriodType;
import vn.edu.huit.finance.core.Entity.Category;
import vn.edu.huit.finance.core.Entity.DefaultCategory;
import vn.edu.huit.finance.core.Entity.Notification;
import vn.edu.huit.finance.core.Entity.NotificationType;
import vn.edu.huit.finance.core.Entity.Receipt;
import vn.edu.huit.finance.core.Entity.ReceiptErrorCode;
import vn.edu.huit.finance.core.Entity.ReceiptProcessingAttempt;
import vn.edu.huit.finance.core.Entity.ReceiptStatus;
import vn.edu.huit.finance.core.Entity.SavingGoal;
import vn.edu.huit.finance.core.Entity.Transaction;
import vn.edu.huit.finance.core.Entity.User;
import vn.edu.huit.finance.core.Repository.BudgetRepository;
import vn.edu.huit.finance.core.Repository.CategoryRepository;
import vn.edu.huit.finance.core.Repository.NotificationRepository;
import vn.edu.huit.finance.core.Repository.SavingGoalRepository;
import vn.edu.huit.finance.core.Repository.TransactionRepository;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Security.Roles;
import vn.edu.huit.finance.core.Service.Audit.AuditActor;
import vn.edu.huit.finance.core.Service.Audit.AuditEntry;
import vn.edu.huit.finance.core.Service.AuditLogService;
import vn.edu.huit.finance.core.Service.BudgetAlertService;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Clock;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.time.temporal.TemporalAdjusters;
import java.util.ArrayList;
import java.util.Collections;
import java.util.EnumSet;
import java.util.HashMap;
import java.util.HashSet;
import java.util.IdentityHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Ghi dữ liệu demo vào database trống, trong một transaction duy nhất: hoặc đủ hết, hoặc không có gì. Database đã có
 * người dùng thì không ghi gì và không bao giờ xóa gì. Giao dịch thường được ghi theo lô bằng JDBC (vài nghìn dòng, không
 * cần lịch sử Envers); giao dịch có hóa đơn, ngân sách, mục tiêu, thông báo đi qua JPA như app thật, và nhật ký hệ thống
 * đi qua {@link AuditLogService}, nơi duy nhất ghi action_logs.
 */
@Slf4j
@Service
@ConditionalOnProperty(name = DemoSeedProperties.ENABLED_PROPERTY, havingValue = "true")
@RequiredArgsConstructor
public class DemoDataWriter {

    public static final String ADMIN_USERNAME = "admin";
    public static final String ADMIN_EMAIL = ADMIN_USERNAME + DemoDataGenerator.EMAIL_DOMAIN;
    /** Phương thức thanh toán mà app mobile gửi kèm mọi giao dịch. */
    static final String PAYMENT_METHOD_WALLET = "WALLET";

    private static final int ADMIN_PHONE_SERIAL = 0;
    private static final int BATCH_SIZE = 500;
    private static final Set<DefaultCategory> SCANNABLE =
            EnumSet.of(DefaultCategory.FOOD, DefaultCategory.GROCERIES, DefaultCategory.SHOPPING);
    private static final String INSERT_TRANSACTION = "INSERT INTO transactions (user_id, category_id, category_name, "
            + "amount, note, transaction_date, is_expense, location, payment_method, created_at, updated_at) "
            + "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

    // Câu trả lời của AI có dạng {"seller": {...}} như ai-service /donut/scan trả về và OcrService đọc.
    private static final String KEY_SELLER_NODE = "seller";
    private static final String KEY_SELLER_NAME = "seller_name";
    private static final String KEY_ADDRESS = "address";
    private static final String KEY_TIMESTAMP = "timestamp";
    private static final String KEY_TOTAL_TEXT = "total_cost";
    private static final String KEY_TOTAL_NUMBER = "total_cost_number";
    private static final DateTimeFormatter RECEIPT_TIMESTAMP = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");
    private static final DateTimeFormatter GOAL_DEADLINE = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    private static final BigDecimal BUDGET_UNIT = BigDecimal.valueOf(10_000);
    private static final BigDecimal MIN_BUDGET = BigDecimal.valueOf(100_000);

    private static final String AUDIT_ADMIN_CREATED = "Khởi tạo tài khoản quản trị (dữ liệu demo)";
    private static final String AUDIT_DEMO_USER_CREATED = "Khởi tạo tài khoản demo";
    private static final String AUDIT_RECEIPT_CREATED = "Quét hóa đơn %s";
    private static final String AUDIT_RECEIPT_CORRECTED = "Sửa tên cửa hàng thành %s";
    private static final String AUDIT_FEEDBACK_SUBMITTED = "Gửi số tiền hóa đơn chờ duyệt";
    private static final String AUDIT_RECEIPT_APPROVED = "Duyệt hóa đơn %s";

    private static final String MSG_RECEIPT_READ = "Hóa đơn %s đã được AI đọc xong.";
    private static final String MSG_RECEIPT_NO_TOTAL =
            "AI chưa đọc được tổng tiền trên hóa đơn %s. Bạn có thể nhập số tiền để gửi duyệt.";
    private static final String MSG_RECEIPT_WAITING = "Hóa đơn %s đang chờ quản trị viên duyệt.";
    private static final String MSG_RECEIPT_APPROVED = "Hóa đơn %s đã được quản trị viên duyệt.";

    /** Ngân sách demo; số tiền được tính để đã chi đúng {@code spentShare} của nó (0,88 = đã vượt ngưỡng cảnh báo 80%). */
    private record BudgetPlan(BudgetPeriodType period, DefaultCategory category, double spentShare) {
    }

    private record GoalPlan(String title, long target, long saved, int monthsLeft) {
    }

    private static final List<BudgetPlan> OFFICE_WORKER_BUDGETS = List.of(
            new BudgetPlan(BudgetPeriodType.MONTH, null, 0.6),
            new BudgetPlan(BudgetPeriodType.MONTH, DefaultCategory.FOOD, 0.88),
            new BudgetPlan(BudgetPeriodType.WEEK, DefaultCategory.TRANSPORT, 0.45));
    private static final List<BudgetPlan> STUDENT_BUDGETS = List.of(
            new BudgetPlan(BudgetPeriodType.MONTH, null, 0.55),
            new BudgetPlan(BudgetPeriodType.WEEK, DefaultCategory.FOOD, 0.5));
    private static final List<GoalPlan> OFFICE_WORKER_GOALS = List.of(
            new GoalPlan("Quỹ dự phòng 6 tháng", 60_000_000, 21_500_000, 10),
            new GoalPlan("Du lịch Đà Nẵng", 12_000_000, 7_800_000, 3),
            new GoalPlan("Mua laptop mới", 25_000_000, 4_000_000, 6));
    private static final List<GoalPlan> STUDENT_GOALS = List.of(
            new GoalPlan("Mua laptop học tập", 15_000_000, 3_200_000, 6),
            new GoalPlan("Học phí IELTS", 8_000_000, 5_500_000, 3));

    private final UserRepository userRepository;
    private final CategoryRepository categoryRepository;
    private final TransactionRepository transactionRepository;
    private final BudgetRepository budgetRepository;
    private final SavingGoalRepository savingGoalRepository;
    private final NotificationRepository notificationRepository;
    private final AuditLogService auditLogService;
    private final PasswordEncoder passwordEncoder;
    private final JdbcTemplate jdbcTemplate;

    // Không inject: production dùng đồng hồ hệ thống, test thay để cố định "hôm nay".
    private Clock clock = Clock.systemDefaultZone();

    /** Seed khi bảng users còn trống; ngược lại không làm gì. Mật khẩu đã được kiểm tra @StrongPassword lúc khởi động. */
    @Transactional
    public DemoSeedResult seedIfEmpty(String adminPassword, String demoPassword) {
        long existingUsers = userRepository.count();
        if (existingUsers > 0) {
            log.info("Demo seed skipped: the database already has {} users", existingUsers);
            return DemoSeedResult.skipped();
        }
        LocalDateTime now = LocalDateTime.now(clock);
        Map<DefaultCategory, Category> categories = ensureCategories();
        List<DemoAccount> accounts = new DemoDataGenerator(DemoDataGenerator.SEED).generate(now);

        User admin = saveAdmin(adminPassword);
        List<User> users = saveAccounts(accounts, demoPassword);
        List<SeededReceipt> receipts = new ArrayList<>();
        int transactionCount = 0;
        for (int i = 0; i < accounts.size(); i++) {
            DemoAccount account = accounts.get(i);
            User user = users.get(i);
            transactionCount += account.transactions().size();
            List<SeededReceipt> accountReceipts = saveTransactions(account, user, categories, admin);
            receipts.addAll(accountReceipts);
            if (account.persona().isDemoLogin()) {
                saveDemoExtras(account, user, categories, now.toLocalDate(), accountReceipts);
            }
        }
        log.info("Demo seed done: {} users, {} transactions, {} receipts",
                users.size() + 1, transactionCount, receipts.size());
        return new DemoSeedResult(true, users.size() + 1, transactionCount, receipts);
    }

    // ---------------------------------------------------------------------------------------- danh mục và tài khoản

    /** Danh mục mặc định nào chưa có (theo tên) thì thêm; danh mục đã có giữ nguyên. */
    private Map<DefaultCategory, Category> ensureCategories() {
        Map<String, Category> byName = categoryRepository.findAll().stream()
                .collect(Collectors.toMap(Category::getName, Function.identity(), (first, second) -> first));
        Map<DefaultCategory, Category> categories = new HashMap<>();
        for (DefaultCategory category : DefaultCategory.values()) {
            Category stored = byName.get(category.getDisplayName());
            if (stored == null) {
                stored = new Category();
                stored.setName(category.getDisplayName());
                stored.setType(category.getType());
                stored = categoryRepository.save(stored);
            }
            categories.put(category, stored);
        }
        return categories;
    }

    private User saveAdmin(String adminPassword) {
        User admin = newUser(ADMIN_USERNAME, ADMIN_EMAIL, String.format(Locale.ROOT, DemoDataGenerator.PHONE_FORMAT,
                ADMIN_PHONE_SERIAL), passwordEncoder.encode(adminPassword), BigDecimal.ZERO);
        admin.setRole(Roles.ADMIN);
        admin = userRepository.save(admin);
        auditLogService.record(AuditEntry.of(AuditAction.USER_CREATED, AuditActor.system(), admin.getId(),
                AUDIT_ADMIN_CREATED));
        return admin;
    }

    /** Tài khoản nền dùng chung một mật khẩu ngẫu nhiên không ai biết: chúng chỉ để làm đầy thống kê, không đăng nhập. */
    private List<User> saveAccounts(List<DemoAccount> accounts, String demoPassword) {
        String demoHash = passwordEncoder.encode(demoPassword);
        String unusableHash = passwordEncoder.encode(UUID.randomUUID().toString());
        List<User> users = new ArrayList<>();
        for (DemoAccount account : accounts) {
            String hash = account.persona().isDemoLogin() ? demoHash : unusableHash;
            users.add(newUser(account.username(), account.email(), account.phone(), hash, account.walletBalance()));
        }
        List<User> saved = userRepository.saveAll(users);
        for (int i = 0; i < accounts.size(); i++) {
            if (accounts.get(i).persona().isDemoLogin()) {
                auditLogService.record(AuditEntry.of(AuditAction.USER_CREATED, AuditActor.system(),
                        saved.get(i).getId(), AUDIT_DEMO_USER_CREATED));
            }
        }
        return saved;
    }

    private static User newUser(String username, String email, String phone, String passwordHash, BigDecimal wallet) {
        User user = new User();
        user.setUsername(username);
        user.setEmail(email);
        user.setPhone(phone);
        user.setPassword(passwordHash);
        user.setRole(Roles.USER);
        user.setActive(true);
        user.setWalletBalance(wallet);
        return user;
    }

    // ---------------------------------------------------------------------------------------------------- giao dịch

    /** Ghi mọi giao dịch của một tài khoản; vài giao dịch gần nhất của tài khoản demo được gắn hóa đơn. */
    private List<SeededReceipt> saveTransactions(DemoAccount account, User user, Map<DefaultCategory, Category> categories,
                                                 User admin) {
        List<ReceiptScenario> scenarios = ReceiptScenario.forPersona(account.persona());
        List<DemoTransaction> scanned = pickScanned(account.transactions(), scenarios.size());
        Set<DemoTransaction> scannedSet = Collections.newSetFromMap(new IdentityHashMap<>());
        scannedSet.addAll(scanned);
        List<DemoTransaction> plain = account.transactions().stream().filter(t -> !scannedSet.contains(t)).toList();

        jdbcTemplate.batchUpdate(INSERT_TRANSACTION, plain, BATCH_SIZE, (statement, transaction) -> {
            Category category = categories.get(transaction.category());
            statement.setLong(1, user.getId());
            statement.setLong(2, category.getId());
            statement.setString(3, category.getName());
            statement.setBigDecimal(4, transaction.amount());
            statement.setString(5, transaction.note());
            statement.setObject(6, transaction.at());
            statement.setBoolean(7, transaction.isExpense());
            statement.setString(8, transaction.location());
            statement.setString(9, PAYMENT_METHOD_WALLET);
            statement.setObject(10, transaction.at());
            statement.setObject(11, transaction.at());
        });

        List<SeededReceipt> receipts = new ArrayList<>();
        for (int i = 0; i < scanned.size(); i++) {
            receipts.add(saveScanned(scanned.get(i), scenarios.get(i), user, categories, admin));
        }
        return receipts;
    }

    /** Các khoản chi gần nhất có cửa hàng (ăn uống, siêu thị, mua sắm), mỗi cửa hàng một lần. */
    private static List<DemoTransaction> pickScanned(List<DemoTransaction> transactions, int count) {
        List<DemoTransaction> picked = new ArrayList<>();
        Set<String> merchants = new HashSet<>();
        for (int i = transactions.size() - 1; i >= 0 && picked.size() < count; i--) {
            DemoTransaction transaction = transactions.get(i);
            if (SCANNABLE.contains(transaction.category()) && transaction.location() != null
                    && merchants.add(transaction.note())) {
                picked.add(transaction);
            }
        }
        return picked;
    }

    private SeededReceipt saveScanned(DemoTransaction demo, ReceiptScenario scenario, User user,
                                      Map<DefaultCategory, Category> categories, User admin) {
        Category category = categories.get(demo.category());
        String readSeller = scenario == ReceiptScenario.CORRECTED
                ? DemoDataGenerator.withoutDiacritics(demo.note()).toUpperCase(Locale.ROOT)
                : demo.note();
        String aiRawData = aiAnswer(readSeller, demo, scenario.totalRead());
        Receipt receipt = buildReceipt(demo, scenario, readSeller, aiRawData);

        Transaction transaction = new Transaction();
        transaction.setUser(user);
        transaction.setCategory(category);
        transaction.setCategoryName(category.getName());
        transaction.setAmount(demo.amount());
        transaction.setNote(demo.note());
        transaction.setTransactionDate(demo.at());
        transaction.setExpense(demo.isExpense());
        transaction.setLocation(demo.location());
        transaction.setPaymentMethod(PAYMENT_METHOD_WALLET);
        transaction.setReceipt(receipt);
        receipt.setTransaction(transaction);
        transaction = transactionRepository.save(transaction);

        auditReceipt(scenario, receipt, user, admin, demo.note());
        return new SeededReceipt(transaction.getId(), receipt.getId(), user.getId(), scenario, aiRawData, readSeller,
                demo.note(), demo.amount(), demo.at());
    }

    /** Hóa đơn đi đúng các bước của vòng đời tới trạng thái của câu chuyện, lần đọc đầu tiên lưu cùng hóa đơn. */
    private static Receipt buildReceipt(DemoTransaction demo, ReceiptScenario scenario, String readSeller,
                                        String aiRawData) {
        Receipt receipt = new Receipt();
        receipt.setVendorName(readSeller);
        receipt.setExtractedDate(demo.at().toLocalDate());
        if (scenario.totalRead()) {
            receipt.setExtractedTotal(demo.amount());
            receipt.addFirstAttempt(ReceiptProcessingAttempt.completed(receipt,
                    ReceiptProcessingAttempt.FIRST_ATTEMPT_NUMBER, aiRawData, null, demo.at()));
            receipt.moveTo(ReceiptStatus.COMPLETED_RAW);
        } else {
            receipt.addFirstAttempt(ReceiptProcessingAttempt.failed(receipt,
                    ReceiptProcessingAttempt.FIRST_ATTEMPT_NUMBER, aiRawData, null, ReceiptErrorCode.AI_NO_TOTAL,
                    demo.at()));
            receipt.failWith(ReceiptErrorCode.AI_NO_TOTAL);
        }
        switch (scenario) {
            case CORRECTED -> {
                receipt.setVendorName(demo.note());
                receipt.moveTo(ReceiptStatus.EDITED);
            }
            case AWAITING_REVIEW -> {
                receipt.setExtractedTotal(demo.amount());
                receipt.moveTo(ReceiptStatus.WAITING_FOR_REVIEW);
            }
            case APPROVED -> receipt.moveTo(ReceiptStatus.APPROVED);
            default -> {
                // READ, UNREADABLE_TOTAL: dừng ở kết quả của lần đọc đầu tiên.
            }
        }
        return receipt;
    }

    /** Câu trả lời giả của AI; không đọc được tổng tiền thì hai trường tổng tiền để trống. */
    private static String aiAnswer(String readSeller, DemoTransaction demo, boolean totalRead) {
        ObjectNode seller = JsonNodeFactory.instance.objectNode();
        seller.put(KEY_SELLER_NAME, readSeller);
        seller.put(KEY_ADDRESS, demo.location());
        seller.put(KEY_TIMESTAMP, demo.at().format(RECEIPT_TIMESTAMP));
        if (totalRead) {
            seller.put(KEY_TOTAL_TEXT, String.format(Locale.GERMANY, "%,d", demo.amount().longValueExact()));
            seller.put(KEY_TOTAL_NUMBER, demo.amount().longValueExact());
        } else {
            seller.put(KEY_TOTAL_TEXT, "");
        }
        ObjectNode root = JsonNodeFactory.instance.objectNode();
        root.set(KEY_SELLER_NODE, seller);
        return root.toString();
    }

    private void auditReceipt(ReceiptScenario scenario, Receipt receipt, User owner, User admin, String seller) {
        Long receiptId = receipt.getId();
        auditLogService.record(AuditEntry.of(AuditAction.RECEIPT_CREATED, AuditActor.of(owner), receiptId,
                String.format(AUDIT_RECEIPT_CREATED, seller)));
        switch (scenario) {
            case CORRECTED -> auditLogService.record(AuditEntry.of(AuditAction.RECEIPT_UPDATED, AuditActor.of(owner),
                    receiptId, String.format(AUDIT_RECEIPT_CORRECTED, seller)));
            case AWAITING_REVIEW -> auditLogService.record(AuditEntry.of(AuditAction.RECEIPT_FEEDBACK_SUBMITTED,
                    AuditActor.of(owner), receiptId, AUDIT_FEEDBACK_SUBMITTED));
            case APPROVED -> auditLogService.record(AuditEntry.of(AuditAction.RECEIPT_APPROVED, AuditActor.of(admin),
                    receiptId, String.format(AUDIT_RECEIPT_APPROVED, seller)));
            default -> {
                // READ, UNREADABLE_TOTAL: chỉ có dòng tạo hóa đơn.
            }
        }
    }

    // ----------------------------------------------------------------------- ngân sách, mục tiêu, thông báo (demo)

    private void saveDemoExtras(DemoAccount account, User user, Map<DefaultCategory, Category> categories,
                                LocalDate today, List<SeededReceipt> receipts) {
        boolean officeWorker = account.persona() == DemoPersona.OFFICE_WORKER;
        for (BudgetPlan plan : officeWorker ? OFFICE_WORKER_BUDGETS : STUDENT_BUDGETS) {
            saveBudget(plan, account, user, categories, today);
        }
        for (GoalPlan plan : officeWorker ? OFFICE_WORKER_GOALS : STUDENT_GOALS) {
            SavingGoal goal = new SavingGoal();
            goal.setUser(user);
            goal.setTitle(plan.title());
            goal.setTargetAmount(BigDecimal.valueOf(plan.target()));
            goal.setCurrentAmount(BigDecimal.valueOf(plan.saved()));
            goal.setDeadline(today.plusMonths(plan.monthsLeft()).format(GOAL_DEADLINE));
            savingGoalRepository.save(goal);
        }
        receipts.forEach(receipt -> notifyReceipt(user, receipt));
    }

    /** Ngân sách kỳ hiện tại; đã chạm mức cảnh báo thì kèm thông báo như BudgetAlertService sẽ gửi. */
    private void saveBudget(BudgetPlan plan, DemoAccount account, User user, Map<DefaultCategory, Category> categories,
                            LocalDate today) {
        LocalDate start = plan.period() == BudgetPeriodType.WEEK
                ? today.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
                : today.withDayOfMonth(1);
        LocalDate end = plan.period() == BudgetPeriodType.WEEK
                ? start.plusDays(DayOfWeek.values().length - 1)
                : today.with(TemporalAdjusters.lastDayOfMonth());
        BigDecimal spent = spentBetween(account, plan.category(), start, end);

        Budget budget = new Budget();
        budget.setUser(user);
        budget.setCategory(plan.category() == null ? null : categories.get(plan.category()));
        budget.setPeriodType(plan.period());
        budget.setStartDate(start);
        budget.setEndDate(end);
        budget.setAmount(budgetAmount(spent, plan.spentShare()));
        budget = budgetRepository.save(budget);

        Optional<NotificationType> level = BudgetAlertService.highestReached(spent, budget.getAmount());
        if (level.isPresent()) {
            saveNotification(user, level.get(), BudgetAlertService.messageFor(level.get(), budget, spent), false,
                    budget.getId(), null);
        }
    }

    /** Tổng chi trong kỳ, theo danh mục (null = mọi danh mục), đúng như truy vấn ngân sách của backend tính. */
    private static BigDecimal spentBetween(DemoAccount account, DefaultCategory category, LocalDate start,
                                           LocalDate end) {
        return account.transactions().stream()
                .filter(DemoTransaction::isExpense)
                .filter(t -> category == null || t.category() == category)
                .filter(t -> !t.at().toLocalDate().isBefore(start) && !t.at().toLocalDate().isAfter(end))
                .map(DemoTransaction::amount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    /** Hạn mức để {@code spent} là đúng {@code spentShare} của nó, làm tròn lên chục nghìn, ít nhất 100.000 đ. */
    private static BigDecimal budgetAmount(BigDecimal spent, double spentShare) {
        BigDecimal units = spent.divide(BigDecimal.valueOf(spentShare), 0, RoundingMode.UP)
                .divide(BUDGET_UNIT, 0, RoundingMode.UP);
        return units.multiply(BUDGET_UNIT).max(MIN_BUDGET);
    }

    /** Thông báo kết quả xử lý một hóa đơn; hóa đơn đã xong việc thì coi như người dùng đã đọc. */
    private void notifyReceipt(User user, SeededReceipt receipt) {
        String seller = receipt.seller();
        String message = switch (receipt.scenario()) {
            case UNREADABLE_TOTAL -> String.format(MSG_RECEIPT_NO_TOTAL, seller);
            case AWAITING_REVIEW -> String.format(MSG_RECEIPT_WAITING, seller);
            case APPROVED -> String.format(MSG_RECEIPT_APPROVED, seller);
            case READ, CORRECTED -> String.format(MSG_RECEIPT_READ, seller);
        };
        boolean settled = receipt.scenario().totalRead();
        saveNotification(user, NotificationType.RECEIPT_PROCESSED, message, settled, null, receipt.receiptId());
    }

    private void saveNotification(User user, NotificationType type, String message, boolean read, Long budgetId,
                                  Long receiptId) {
        Notification notification = new Notification();
        notification.setUser(user);
        notification.setType(type);
        notification.setMessage(message);
        notification.setRead(read);
        notification.setBudgetId(budgetId);
        notification.setReceiptId(receiptId);
        notificationRepository.save(notification);
    }
}
