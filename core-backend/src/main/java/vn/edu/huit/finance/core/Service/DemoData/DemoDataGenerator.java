package vn.edu.huit.finance.core.Service.DemoData;

import vn.edu.huit.finance.core.Entity.DefaultCategory;

import java.math.BigDecimal;
import java.text.Normalizer;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Random;

import static vn.edu.huit.finance.core.Entity.DefaultCategory.BONUS;
import static vn.edu.huit.finance.core.Entity.DefaultCategory.EDUCATION;
import static vn.edu.huit.finance.core.Entity.DefaultCategory.ENTERTAINMENT;
import static vn.edu.huit.finance.core.Entity.DefaultCategory.FAMILY;
import static vn.edu.huit.finance.core.Entity.DefaultCategory.FOOD;
import static vn.edu.huit.finance.core.Entity.DefaultCategory.GIFT;
import static vn.edu.huit.finance.core.Entity.DefaultCategory.GROCERIES;
import static vn.edu.huit.finance.core.Entity.DefaultCategory.HEALTH;
import static vn.edu.huit.finance.core.Entity.DefaultCategory.HOUSING;
import static vn.edu.huit.finance.core.Entity.DefaultCategory.INSURANCE;
import static vn.edu.huit.finance.core.Entity.DefaultCategory.OTHER_INCOME;
import static vn.edu.huit.finance.core.Entity.DefaultCategory.SALARY;
import static vn.edu.huit.finance.core.Entity.DefaultCategory.SHOPPING;
import static vn.edu.huit.finance.core.Entity.DefaultCategory.SOCIAL;
import static vn.edu.huit.finance.core.Entity.DefaultCategory.TELECOM;
import static vn.edu.huit.finance.core.Entity.DefaultCategory.TRANSPORT;
import static vn.edu.huit.finance.core.Entity.DefaultCategory.TRAVEL;
import static vn.edu.huit.finance.core.Entity.DefaultCategory.UTILITIES;

/**
 * Sinh người dùng và giao dịch demo giống thực tế Việt Nam: lương đầu tháng, tiền nhà và điện nước định kỳ, ăn uống hằng
 * ngày, cuối tuần chi giải trí nhiều hơn, giá theo mặt bằng TP.HCM, làm tròn nghìn đồng. Không đụng database: cùng hạt
 * giống và cùng thời điểm thì ra đúng cùng dữ liệu. Một khoản chi vượt số dư lúc đó bị bỏ (app cũng từ chối), nên số dư
 * không bao giờ âm và bằng tổng thu trừ tổng chi.
 */
public class DemoDataGenerator {

    /** Hạt giống cố định: lần chạy nào cũng ra cùng dữ liệu, ảnh chụp khóa luận ổn định. */
    public static final long SEED = 42L;

    /** Tên miền dành riêng cho ví dụ (RFC 2606): không email nào tới hộp thư thật. */
    public static final String EMAIL_DOMAIN = "@example.com";
    public static final String OFFICE_WORKER_USERNAME = "demo.vanphong";
    public static final String STUDENT_USERNAME = "demo.sinhvien";
    /** Số điện thoại thứ n là "09" + n đủ 8 chữ số; số 0 dành cho admin. */
    public static final String PHONE_FORMAT = "09%08d";

    static final int SALARIED_COUNT = 8;
    static final int NEWCOMER_COUNT = 14;
    static final int FADING_COUNT = 8;
    static final int CHURNED_COUNT = 6;

    /** Lịch sử của người đang dùng: tháng hiện tại và 3 tháng trước đó. */
    static final int HISTORY_MONTHS = 3;
    static final int NEWCOMER_MIN_DAYS = 10;
    static final int NEWCOMER_MAX_DAYS = 28;
    static final int FADING_START_DAYS = 110;
    static final int FADING_MIN_IDLE_DAYS = 35;
    static final int FADING_MAX_IDLE_DAYS = 95;
    static final int CHURNED_START_DAYS = 175;
    static final int CHURNED_MIN_IDLE_DAYS = 125;
    static final int CHURNED_MAX_IDLE_DAYS = 160;

    // ------------------------------------------------------------------------------------------- lịch thu chi cố định
    private static final int RENT_DAY = 5;
    private static final int FAMILY_DAY = 6;
    private static final int UTILITIES_DAY = 10;
    private static final int STREAMING_DAY = 12;
    private static final int TELECOM_DAY = 15;
    private static final int BONUS_DAY = 15;
    private static final int INSURANCE_DAY = 20;
    private static final int ALLOWANCE_DAY = 2;
    private static final int PART_TIME_PAY_DAY = 10;
    private static final int LATEST_SALARY_DAY = 5;
    private static final int QUARTER_MONTHS = 3;

    // ------------------------------------------------------------------------------------------------------- số tiền
    private static final long THOUSAND = 1_000;
    private static final long HUNDRED_THOUSAND = 100_000;
    private static final long HALF_MILLION = 500_000;
    private static final long OFFICE_SALARY = 25_000_000;
    private static final long OFFICE_RENT = 6_500_000;
    private static final long OFFICE_INSURANCE = 1_200_000;
    private static final long OFFICE_OPENING = 15_000_000;
    private static final long STUDENT_OPENING = 2_500_000;
    private static final long STUDENT_RENT = 2_200_000;
    private static final long STUDENT_MOBILE_PLAN = 90_000;
    private static final long INTERNET_FEE = 220_000;
    private static final long NETFLIX_FEE = 260_000;
    private static final long REFERENCE_SALARY = 25_000_000;
    private static final double MIN_SCALE = 0.7;
    private static final double MAX_SCALE = 1.8;
    private static final double INSURED_SHARE = 0.5;
    private static final double INSURANCE_SALARY_SHARE = 0.05;

    // -------------------------------------------------------------------------------------------------------- ghi chú
    private static final DateTimeFormatter MONTH_LABEL = DateTimeFormatter.ofPattern("MM/yyyy");
    private static final String NOTE_OPENING_BALANCE = "Số dư đầu kỳ";
    private static final String NOTE_SALARY = "Lương tháng %s";
    private static final String NOTE_PART_TIME_SALARY = "Lương làm thêm tháng %s";
    private static final String NOTE_ALLOWANCE = "Bố mẹ gửi tiền tháng %s";
    private static final String NOTE_BONUS = "Thưởng quý";
    private static final String NOTE_RENT = "Tiền thuê nhà tháng %s";
    private static final String NOTE_STUDENT_RENT = "Tiền phòng trọ tháng %s";
    private static final String NOTE_PARENTS = "Gửi tiền bố mẹ";
    private static final String NOTE_ELECTRICITY = "Tiền điện EVNHCMC";
    private static final String NOTE_WATER = "Tiền nước SAWACO";
    private static final String NOTE_STUDENT_UTILITIES = "Tiền điện nước phòng trọ";
    private static final String NOTE_INTERNET = "Cước Internet FPT Telecom";
    private static final String NOTE_MOBILE = "Cước di động Viettel";
    private static final String NOTE_STUDENT_MOBILE = "Gói cước 4G Viettel";
    private static final String NOTE_NETFLIX = "Netflix";
    private static final String NOTE_INSURANCE = "Phí bảo hiểm Prudential";
    private static final String NOTE_BIRTHDAY_GIFT = "Mừng sinh nhật bạn";
    private static final String FUEL_STATION = "Petrolimex";
    private static final String AIRLINE = "Vietjet Air";
    private static final String HOTEL_BOOKING = "Agoda";

    // ---------------------------------------------------------------------------------------- cửa hàng và địa điểm
    private static final String[] COFFEE_SHOPS = {
            "Highlands Coffee", "Phúc Long", "The Coffee House", "Katinat", "Cộng Cà Phê", "Starbucks"};
    private static final String[] LUNCH_PLACES = {
            "Cơm Tấm Cali", "Phở 24", "Phở Hòa Pasteur", "Bánh Mì Huỳnh Hoa", "Jollibee", "KFC", "Lotteria",
            "McDonald's"};
    private static final String[] RESTAURANTS = {
            "Haidilao", "Kichi-Kichi", "GoGi House", "Pizza 4P's", "Manwah", "King BBQ"};
    private static final String[] STUDENT_MEALS = {"Căn tin trường", "Circle K", "GS25", "Jollibee", "Lotteria"};
    private static final String[] CONVENIENCE_STORES = {"Circle K", "GS25", "FamilyMart", "Ministop", "WinMart+"};
    private static final String[] BUBBLE_TEA = {"Mixue", "Gong Cha", "Phúc Long", "Tocotoco", "KOI Thé", "Katinat"};
    private static final String[] GROCERY_STORES = {
            "Bách Hóa Xanh", "Co.opmart", "WinMart", "Lotte Mart", "AEON", "MM Mega Market"};
    private static final String[] RIDE_HAILING = {"Grab", "Be", "Xanh SM"};
    private static final String[] ENTERTAINMENT_PLACES = {
            "CGV Cinemas", "Lotte Cinema", "Galaxy Cinema", "Karaoke Nice", "Timezone"};
    private static final String[] SHOPPING_STORES = {
            "Shopee", "Lazada", "Tiki", "Uniqlo", "Thế Giới Di Động", "Điện Máy Xanh", "Guardian"};
    private static final String[] ONLINE_STORES = {"Shopee", "Lazada", "Tiki", "TikTok Shop"};
    private static final String[] PHARMACIES = {"Nhà thuốc Long Châu", "Pharmacity", "Nhà thuốc An Khang"};
    private static final String[] BOOK_STORES = {"Fahasa", "Nhà sách Phương Nam", "Udemy"};
    private static final String[] SOCIAL_NOTES = {
            "Mừng cưới đồng nghiệp", "Mừng cưới bạn thân", "Viếng đám tang", "Mừng tân gia", "Thăm người ốm"};
    private static final String[] DISTRICTS = {
            "Quận 1, TP.HCM", "Quận 3, TP.HCM", "Quận 7, TP.HCM", "Quận 10, TP.HCM", "Bình Thạnh, TP.HCM",
            "Phú Nhuận, TP.HCM", "Gò Vấp, TP.HCM", "Tân Bình, TP.HCM", "TP. Thủ Đức, TP.HCM"};

    private static final String[] FAMILY_NAMES = {
            "Nguyễn", "Trần", "Lê", "Phạm", "Hoàng", "Huỳnh", "Phan", "Vũ", "Võ", "Đặng", "Bùi", "Đỗ", "Ngô", "Dương"};
    private static final String[] GIVEN_NAMES = {
            "An", "Bình", "Châu", "Dũng", "Giang", "Hà", "Hải", "Hùng", "Khánh", "Linh", "Long", "Mai", "Minh", "Nam",
            "Ngân", "Nhung", "Phúc", "Quân", "Tâm", "Thảo", "Trang", "Tuấn", "Vy", "Yến"};
    private static final String USERNAME_FORMAT = "%s.%s%02d";
    private static final String DIACRITICS = "\\p{M}";

    private static final int MINUTES_PER_HOUR = 60;
    private static final int MINUTES_PER_DAY = 24 * MINUTES_PER_HOUR;
    private static final int SECONDS_PER_MINUTE = 60;

    /** Thói quen của một người đi làm: lương, ngày nhận lương, tiền nhà, hệ số mức chi và phí bảo hiểm (0 = không mua). */
    private record Lifestyle(long salary, int salaryDay, long rent, double scale, long insurancePremium) {
    }

    private static final Lifestyle OFFICE_LIFESTYLE =
            new Lifestyle(OFFICE_SALARY, LATEST_SALARY_DAY, OFFICE_RENT, 1.0, OFFICE_INSURANCE);

    private final Random random;

    public DemoDataGenerator(long seed) {
        this.random = new Random(seed);
    }

    /** Hai tài khoản demo trước, sau đó các tài khoản nền; không giao dịch nào sau {@code now}. */
    public List<DemoAccount> generate(LocalDateTime now) {
        LocalDate today = now.toLocalDate();
        LocalDate historyStart = today.minusMonths(HISTORY_MONTHS).withDayOfMonth(1);
        List<DemoAccount> accounts = new ArrayList<>();

        accounts.add(new DemoAccount(OFFICE_WORKER_USERNAME, OFFICE_WORKER_USERNAME + EMAIL_DOMAIN, phone(1),
                DemoPersona.OFFICE_WORKER, salariedHistory(OFFICE_LIFESTYLE, OFFICE_OPENING, historyStart, today, now)));
        accounts.add(new DemoAccount(STUDENT_USERNAME, STUDENT_USERNAME + EMAIL_DOMAIN, phone(2),
                DemoPersona.STUDENT, studentHistory(historyStart, today, now)));

        int serial = accounts.size();
        for (int i = 0; i < SALARIED_COUNT; i++) {
            accounts.add(backgroundAccount(++serial, DemoPersona.SALARIED,
                    salariedHistory(randomLifestyle(), money(8_000_000, 30_000_000), historyStart, today, now)));
        }
        for (int i = 0; i < NEWCOMER_COUNT; i++) {
            LocalDate start = today.minusDays(between(NEWCOMER_MIN_DAYS, NEWCOMER_MAX_DAYS));
            accounts.add(backgroundAccount(++serial, DemoPersona.NEWCOMER, newcomerHistory(start, today, now)));
        }
        for (int i = 0; i < FADING_COUNT; i++) {
            LocalDate end = today.minusDays(between(FADING_MIN_IDLE_DAYS, FADING_MAX_IDLE_DAYS));
            accounts.add(backgroundAccount(++serial, DemoPersona.FADING, salariedHistory(randomLifestyle(),
                    money(3_000_000, 10_000_000), today.minusDays(FADING_START_DAYS), end, now)));
        }
        for (int i = 0; i < CHURNED_COUNT; i++) {
            LocalDate end = today.minusDays(between(CHURNED_MIN_IDLE_DAYS, CHURNED_MAX_IDLE_DAYS));
            accounts.add(backgroundAccount(++serial, DemoPersona.CHURNED, salariedHistory(randomLifestyle(),
                    money(3_000_000, 10_000_000), today.minusDays(CHURNED_START_DAYS), end, now)));
        }
        return accounts;
    }

    // ------------------------------------------------------------------------------------------------------ tài khoản

    private DemoAccount backgroundAccount(int serial, DemoPersona persona, List<DemoTransaction> history) {
        String username = String.format(Locale.ROOT, USERNAME_FORMAT,
                slug(pick(GIVEN_NAMES)), slug(pick(FAMILY_NAMES)), serial);
        return new DemoAccount(username, username + EMAIL_DOMAIN, phone(serial), persona, history);
    }

    private static String phone(int serial) {
        return String.format(Locale.ROOT, PHONE_FORMAT, serial);
    }

    /** "Đặng" thành "dang": bỏ dấu, chữ thường. */
    private static String slug(String vietnamese) {
        return withoutDiacritics(vietnamese).toLowerCase(Locale.ROOT);
    }

    /** "Phúc Long" thành "Phuc Long": bỏ dấu, đ thành d (cách DONUT hay đọc sai tên có dấu). */
    static String withoutDiacritics(String vietnamese) {
        String withoutD = vietnamese.replace('đ', 'd').replace('Đ', 'D');
        return Normalizer.normalize(withoutD, Normalizer.Form.NFD).replaceAll(DIACRITICS, "");
    }

    private Lifestyle randomLifestyle() {
        long salary = roundTo(money(15_000_000, 45_000_000), HALF_MILLION);
        double scale = Math.max(MIN_SCALE, Math.min(MAX_SCALE, (double) salary / REFERENCE_SALARY));
        long premium = chance(INSURED_SHARE) ? roundTo((long) (salary * INSURANCE_SALARY_SHARE), HUNDRED_THOUSAND) : 0;
        return new Lifestyle(salary, between(1, LATEST_SALARY_DAY), roundTo(money(3_500_000, 9_000_000), HUNDRED_THOUSAND),
                scale, premium);
    }

    // ------------------------------------------------------------------------------------------------------- lịch sử

    private List<DemoTransaction> salariedHistory(Lifestyle life, long opening, LocalDate start, LocalDate end,
                                                  LocalDateTime now) {
        Ledger ledger = openLedger(opening, start, now);
        for (LocalDate day = start; !day.isAfter(end); day = day.plusDays(1)) {
            salariedDay(life, day, ledger);
            ledger.closeDay();
        }
        return ledger.booked;
    }

    private List<DemoTransaction> studentHistory(LocalDate start, LocalDate end, LocalDateTime now) {
        Ledger ledger = openLedger(STUDENT_OPENING, start, now);
        for (LocalDate day = start; !day.isAfter(end); day = day.plusDays(1)) {
            studentDay(day, ledger);
            ledger.closeDay();
        }
        return ledger.booked;
    }

    private List<DemoTransaction> newcomerHistory(LocalDate start, LocalDate end, LocalDateTime now) {
        Ledger ledger = openLedger(money(2_000_000, 4_000_000), start, now);
        for (LocalDate day = start; !day.isAfter(end); day = day.plusDays(1)) {
            newcomerDay(day, ledger);
            ledger.closeDay();
        }
        return ledger.booked;
    }

    private Ledger openLedger(long opening, LocalDate start, LocalDateTime now) {
        Ledger ledger = new Ledger(now);
        ledger.add(OTHER_INCOME, opening, start.atStartOfDay(), NOTE_OPENING_BALANCE, null);
        return ledger;
    }

    // -------------------------------------------------------------------------------------------------------- một ngày

    private void salariedDay(Lifestyle life, LocalDate day, Ledger ledger) {
        salariedFixedItems(life, day, ledger);
        double scale = life.scale();
        boolean weekend = isWeekend(day);

        if (!weekend && chance(0.55)) {
            shop(ledger, FOOD, scaled(35_000, 69_000, scale), at(day, 7, 40, 20), pick(COFFEE_SHOPS));
        }
        if (chance(weekend ? 0.5 : 0.9)) {
            shop(ledger, FOOD, scaled(40_000, 90_000, scale), at(day, 12, 0, 25), pick(LUNCH_PLACES));
        }
        if (weekend ? chance(0.65) : chance(0.25)) {
            long dinner = weekend ? scaled(250_000, 900_000, scale) : scaled(80_000, 200_000, scale);
            shop(ledger, FOOD, dinner, at(day, 19, 0, 45), pick(weekend ? RESTAURANTS : LUNCH_PLACES));
        }
        if (chance(0.28)) {
            shop(ledger, GROCERIES, scaled(120_000, 700_000, scale), at(day, weekend ? 10 : 18, 30, 60),
                    pick(GROCERY_STORES));
        }
        if (!weekend && chance(0.45)) {
            shop(ledger, TRANSPORT, scaled(25_000, 90_000, scale), at(day, 8, 15, 30), pick(RIDE_HAILING));
        }
        if (day.getDayOfWeek() == DayOfWeek.SATURDAY && chance(0.8)) {
            shop(ledger, TRANSPORT, money(70_000, 120_000), at(day, 9, 0, 60), FUEL_STATION);
        }
        if (weekend && chance(0.35)) {
            shop(ledger, ENTERTAINMENT, scaled(120_000, 450_000, scale), at(day, 16, 0, 120), pick(ENTERTAINMENT_PLACES));
        }
        if (chance(isShoppingFestival(day) ? 0.6 : 0.07)) {
            shop(ledger, SHOPPING, scaled(150_000, 1_500_000, scale), at(day, 21, 30, 60), pick(SHOPPING_STORES));
        }
        if (chance(0.025)) {
            shop(ledger, HEALTH, scaled(60_000, 500_000, scale), at(day, 18, 30, 60), pick(PHARMACIES));
        }
        if (chance(0.02)) {
            shop(ledger, EDUCATION, scaled(100_000, 600_000, scale), at(day, 20, 0, 60), pick(BOOK_STORES));
        }
        if (weekend && chance(0.06)) {
            bill(ledger, SOCIAL, roundTo(scaled(500_000, 1_500_000, scale), HUNDRED_THOUSAND), at(day, 11, 0, 60),
                    pick(SOCIAL_NOTES));
        }
        if (day.getDayOfWeek() == DayOfWeek.FRIDAY && chance(0.03)) {
            shop(ledger, TRAVEL, scaled(1_500_000, 4_000_000, scale), at(day, 20, 0, 60), AIRLINE);
            shop(ledger, TRAVEL, scaled(1_000_000, 3_000_000, scale), at(day, 21, 0, 30), HOTEL_BOOKING);
        }
    }

    /** Lương, thưởng quý, tiền nhà, gửi bố mẹ, điện nước, cước, Netflix và bảo hiểm: mỗi thứ một ngày cố định trong tháng. */
    private void salariedFixedItems(Lifestyle life, LocalDate day, Ledger ledger) {
        int dayOfMonth = day.getDayOfMonth();
        String month = day.format(MONTH_LABEL);
        double scale = life.scale();

        if (day.equals(payday(day, life.salaryDay()))) {
            bill(ledger, SALARY, life.salary(), at(day, 9, 0, 60), String.format(NOTE_SALARY, month));
        }
        if (dayOfMonth == BONUS_DAY && day.getMonthValue() % QUARTER_MONTHS == 0 && chance(0.6)) {
            bill(ledger, BONUS, roundTo((long) (life.salary() * (0.3 + random.nextDouble() * 0.5)), HUNDRED_THOUSAND),
                    at(day, 10, 0, 60), NOTE_BONUS);
        }
        if (dayOfMonth == RENT_DAY) {
            bill(ledger, HOUSING, life.rent(), at(day, 20, 0, 60), String.format(NOTE_RENT, month));
        }
        if (dayOfMonth == FAMILY_DAY) {
            bill(ledger, FAMILY, roundTo(scaled(2_000_000, 4_000_000, scale), HALF_MILLION), at(day, 20, 30, 60),
                    NOTE_PARENTS);
        }
        if (dayOfMonth == UTILITIES_DAY) {
            bill(ledger, UTILITIES, scaled(450_000, 1_100_000, scale), at(day, 19, 0, 60), NOTE_ELECTRICITY);
            bill(ledger, UTILITIES, scaled(80_000, 200_000, scale), at(day, 19, 10, 60), NOTE_WATER);
        }
        if (dayOfMonth == TELECOM_DAY) {
            bill(ledger, TELECOM, INTERNET_FEE, at(day, 8, 0, 30), NOTE_INTERNET);
            bill(ledger, TELECOM, money(90_000, 200_000), at(day, 8, 10, 30), NOTE_MOBILE);
        }
        if (dayOfMonth == STREAMING_DAY) {
            bill(ledger, ENTERTAINMENT, NETFLIX_FEE, at(day, 2, 0, 30), NOTE_NETFLIX);
        }
        if (dayOfMonth == INSURANCE_DAY && life.insurancePremium() > 0) {
            bill(ledger, INSURANCE, life.insurancePremium(), at(day, 10, 0, 60), NOTE_INSURANCE);
        }
    }

    private void studentDay(LocalDate day, Ledger ledger) {
        int dayOfMonth = day.getDayOfMonth();
        String month = day.format(MONTH_LABEL);
        boolean weekend = isWeekend(day);

        if (dayOfMonth == ALLOWANCE_DAY) {
            bill(ledger, GIFT, roundTo(money(3_500_000, 4_500_000), HALF_MILLION), at(day, 10, 0, 60),
                    String.format(NOTE_ALLOWANCE, month));
        }
        if (dayOfMonth == PART_TIME_PAY_DAY) {
            bill(ledger, SALARY, roundTo(money(2_000_000, 3_000_000), HUNDRED_THOUSAND), at(day, 18, 0, 30),
                    String.format(NOTE_PART_TIME_SALARY, month));
        }
        if (dayOfMonth == RENT_DAY) {
            bill(ledger, HOUSING, STUDENT_RENT, at(day, 20, 0, 60), String.format(NOTE_STUDENT_RENT, month));
        }
        if (dayOfMonth == UTILITIES_DAY) {
            bill(ledger, UTILITIES, money(250_000, 450_000), at(day, 20, 30, 60), NOTE_STUDENT_UTILITIES);
        }
        if (dayOfMonth == TELECOM_DAY) {
            bill(ledger, TELECOM, STUDENT_MOBILE_PLAN, at(day, 8, 0, 30), NOTE_STUDENT_MOBILE);
        }

        if (chance(0.6)) {
            shop(ledger, FOOD, money(15_000, 35_000), at(day, 7, 0, 20), pick(CONVENIENCE_STORES));
        }
        if (chance(0.85)) {
            shop(ledger, FOOD, money(25_000, 50_000), at(day, 11, 45, 20), pick(STUDENT_MEALS));
        }
        if (chance(0.7)) {
            shop(ledger, FOOD, money(25_000, 60_000), at(day, 18, 45, 30), pick(STUDENT_MEALS));
        }
        if (chance(0.35)) {
            shop(ledger, FOOD, money(25_000, 60_000), at(day, 15, 0, 60), pick(BUBBLE_TEA));
        }
        if (chance(0.12)) {
            shop(ledger, GROCERIES, money(60_000, 250_000), at(day, 19, 30, 60), pick(GROCERY_STORES));
        }
        if (chance(0.25)) {
            shop(ledger, TRANSPORT, money(15_000, 40_000), at(day, 8, 0, 30), pick(RIDE_HAILING));
        }
        if (day.getDayOfWeek() == DayOfWeek.SUNDAY && chance(0.6)) {
            shop(ledger, TRANSPORT, money(50_000, 70_000), at(day, 17, 0, 60), FUEL_STATION);
        }
        if (weekend && chance(0.3)) {
            shop(ledger, ENTERTAINMENT, money(60_000, 200_000), at(day, 20, 0, 60), pick(ENTERTAINMENT_PLACES));
        }
        if (chance(isShoppingFestival(day) ? 0.5 : 0.05)) {
            shop(ledger, SHOPPING, money(80_000, 450_000), at(day, 22, 0, 45), pick(ONLINE_STORES));
        }
        if (chance(0.04)) {
            shop(ledger, EDUCATION, money(20_000, 250_000), at(day, 16, 0, 60), pick(BOOK_STORES));
        }
        if (chance(0.015)) {
            shop(ledger, HEALTH, money(30_000, 150_000), at(day, 18, 0, 60), pick(PHARMACIES));
        }
        if (weekend && chance(0.02)) {
            bill(ledger, SOCIAL, roundTo(money(100_000, 300_000), HUNDRED_THOUSAND), at(day, 19, 0, 60),
                    NOTE_BIRTHDAY_GIFT);
        }
    }

    private void newcomerDay(LocalDate day, Ledger ledger) {
        if (chance(0.3)) {
            shop(ledger, FOOD, money(29_000, 59_000), at(day, 8, 0, 30), pick(COFFEE_SHOPS));
        }
        if (chance(0.6)) {
            shop(ledger, FOOD, money(35_000, 70_000), at(day, 12, 0, 30), pick(LUNCH_PLACES));
        }
        if (chance(0.25)) {
            shop(ledger, TRANSPORT, money(20_000, 60_000), at(day, 18, 0, 60), pick(RIDE_HAILING));
        }
        if (chance(0.1)) {
            shop(ledger, GROCERIES, money(80_000, 300_000), at(day, 19, 0, 60), pick(GROCERY_STORES));
        }
    }

    // --------------------------------------------------------------------------------------------------- trợ giúp

    /**
     * Ngày nhận lương của tháng chứa {@code day}: ngày {@code salaryDay}, rơi vào cuối tuần thì lùi về thứ Sáu trước đó,
     * trừ khi lùi sang tháng trước (lương ngày 1, 2): khi đó dời tới thứ Hai sau, để tháng nào cũng có đúng một kỳ lương.
     */
    private static LocalDate payday(LocalDate day, int salaryDay) {
        LocalDate scheduled = day.withDayOfMonth(salaryDay);
        LocalDate earlier = scheduled;
        while (isWeekend(earlier)) {
            earlier = earlier.minusDays(1);
        }
        if (earlier.getMonth() == scheduled.getMonth()) {
            return earlier;
        }
        LocalDate later = scheduled;
        while (isWeekend(later)) {
            later = later.plusDays(1);
        }
        return later;
    }

    private static boolean isWeekend(LocalDate day) {
        return day.getDayOfWeek() == DayOfWeek.SATURDAY || day.getDayOfWeek() == DayOfWeek.SUNDAY;
    }

    /** Ngày đôi khuyến mãi của sàn thương mại điện tử: 9/9, 10/10, 11/11, 12/12... */
    private static boolean isShoppingFestival(LocalDate day) {
        return day.getDayOfMonth() == day.getMonthValue();
    }

    /** Khoản chi có cửa hàng: ghi kèm quận/thành phố. */
    private void shop(Ledger ledger, DefaultCategory category, long amount, LocalDateTime at, String merchant) {
        ledger.add(category, amount, at, merchant, pick(DISTRICTS));
    }

    /** Khoản thu hoặc chi không gắn cửa hàng (lương, tiền nhà, cước, chuyển khoản). */
    private static void bill(Ledger ledger, DefaultCategory category, long amount, LocalDateTime at, String note) {
        ledger.add(category, amount, at, note, null);
    }

    /** Một thời điểm trong ngày, lệch ngẫu nhiên quanh giờ:phút đã cho (phân phối chuẩn, không vượt khỏi ngày). */
    private LocalDateTime at(LocalDate day, int hour, int minute, int spreadMinutes) {
        int minutes = hour * MINUTES_PER_HOUR + minute + (int) Math.round(random.nextGaussian() * spreadMinutes);
        minutes = Math.max(0, Math.min(MINUTES_PER_DAY - 1, minutes));
        return day.atTime(minutes / MINUTES_PER_HOUR, minutes % MINUTES_PER_HOUR, random.nextInt(SECONDS_PER_MINUTE));
    }

    /** Số tiền ngẫu nhiên trong [min, max], làm tròn nghìn đồng, ít nhất 1.000 đ. */
    private long money(long min, long max) {
        long raw = min + (long) (random.nextDouble() * (max - min));
        return Math.max(THOUSAND, roundTo(raw, THOUSAND));
    }

    private long scaled(long min, long max, double scale) {
        return money(Math.round(min * scale), Math.round(max * scale));
    }

    private static long roundTo(long amount, long unit) {
        return Math.max(unit, Math.round((double) amount / unit) * unit);
    }

    private int between(int min, int max) {
        return min + random.nextInt(max - min + 1);
    }

    private boolean chance(double probability) {
        return random.nextDouble() < probability;
    }

    private String pick(String[] pool) {
        return pool[random.nextInt(pool.length)];
    }

    /**
     * Sổ giao dịch của một người. Các khoản trong ngày được gom lại rồi ghi theo giờ, để số dư được kiểm tra đúng thứ tự
     * thời gian: khoản ở tương lai và khoản chi lớn hơn số dư lúc đó bị bỏ.
     */
    private static final class Ledger {
        private final LocalDateTime now;
        private final List<DemoTransaction> booked = new ArrayList<>();
        private final List<DemoTransaction> today = new ArrayList<>();
        private long balance;

        private Ledger(LocalDateTime now) {
            this.now = now;
        }

        private void add(DefaultCategory category, long amount, LocalDateTime at, String note, String location) {
            today.add(new DemoTransaction(category, BigDecimal.valueOf(amount), at, note, location));
        }

        private void closeDay() {
            today.sort(Comparator.comparing(DemoTransaction::at));
            for (DemoTransaction transaction : today) {
                long amount = transaction.amount().longValueExact();
                if (transaction.at().isAfter(now) || (transaction.isExpense() && amount > balance)) {
                    continue;
                }
                balance += transaction.isExpense() ? -amount : amount;
                booked.add(transaction);
            }
            today.clear();
        }
    }
}
