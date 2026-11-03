package vn.edu.huit.finance.core.Controller;

import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.web.servlet.MockMvc;
import vn.edu.huit.finance.core.Entity.BackupType;
import vn.edu.huit.finance.core.Exception.BackupInProgressException;
import vn.edu.huit.finance.core.Exception.GlobalExceptionHandler;
import vn.edu.huit.finance.core.Repository.AppReviewRepository;
import vn.edu.huit.finance.core.Repository.CampaignRepository;
import vn.edu.huit.finance.core.Repository.CategoryRepository;
import vn.edu.huit.finance.core.Repository.ReceiptRepository;
import vn.edu.huit.finance.core.Repository.SubscriptionPlanRepository;
import vn.edu.huit.finance.core.Repository.UserRepository;
import vn.edu.huit.finance.core.Service.AdminStatisticsService;
import vn.edu.huit.finance.core.Service.AppReviewService;
import vn.edu.huit.finance.core.Service.AuditLogQueryService;
import vn.edu.huit.finance.core.Service.BackupService;
import vn.edu.huit.finance.core.Service.CustomerSegmentationService;
import vn.edu.huit.finance.core.Service.Cache.SpendingLeaderboardService;
import vn.edu.huit.finance.core.Service.CategoryService;
import vn.edu.huit.finance.core.Service.LoginAttemptService;
import vn.edu.huit.finance.core.Service.ReceiptProcessingService;
import vn.edu.huit.finance.core.Service.SubscriptionPlanService;
import vn.edu.huit.finance.core.Service.TransactionService;
import vn.edu.huit.finance.core.Service.UserService;
import vn.edu.huit.finance.core.Service.Backup.ScheduledBackupService;

import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** The manual backup and restore buttons go through the lock of the scheduled backup; a busy lock answers 409 with a fixed text. */
@WebMvcTest(AdminController.class)
@ContextConfiguration(classes = {AdminController.class, GlobalExceptionHandler.class})
@AutoConfigureMockMvc(addFilters = false)
class AdminBackupExecuteTest {

    @Autowired private MockMvc mockMvc;
    @MockBean private ScheduledBackupService scheduledBackupService;
    @MockBean private AdminStatisticsService adminStatisticsService;
    @MockBean private SpendingLeaderboardService leaderboardService;
    @MockBean private ReceiptProcessingService receiptProcessingService;
    @MockBean private UserRepository userRepo;
    @MockBean private CategoryRepository categoryRepo;
    @MockBean private CampaignRepository campaignRepo;
    @MockBean private ReceiptRepository receiptRepo;
    @MockBean private BackupService backupService;
    @MockBean private CustomerSegmentationService customerSegmentationService;
    @MockBean private UserService userService;
    @MockBean private TransactionService transactionService;
    @MockBean private EntityManager entityManager;
    @MockBean private SubscriptionPlanRepository subscriptionPlanRepository;
    @MockBean private SubscriptionPlanService subscriptionPlanService;
    @MockBean private CategoryService categoryService;
    @MockBean private AppReviewService appReviewService;
    @MockBean private AuditLogQueryService auditLogQueryService;
    @MockBean private LoginAttemptService loginAttemptService;
    @MockBean private AppReviewRepository appReviewRepository;

    @Test
    void aFreeLockRunsTheBackupAndKeepsTheSuccessShape() throws Exception {
        when(scheduledBackupService.backupNow(BackupType.FULL)).thenReturn(true);

        mockMvc.perform(post("/admin/backup/execute").param("type", "full"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true));
    }

    @Test
    void aBusyLockAnswers409WithTheFixedTextWhenBackingUp() throws Exception {
        when(scheduledBackupService.backupNow(BackupType.FULL)).thenThrow(new BackupInProgressException());

        mockMvc.perform(post("/admin/backup/execute").param("type", "full"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value(409))
                .andExpect(jsonPath("$.message").value(BackupInProgressException.MESSAGE));
    }

    @Test
    void aFreeLockRunsTheRestoreAndKeepsTheSuccessShape() throws Exception {
        when(scheduledBackupService.restoreLatestFullNow()).thenReturn(true);

        mockMvc.perform(post("/admin/backup/restore").param("type", "FULL"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true));
    }

    @Test
    void aBusyLockAnswers409WithTheFixedTextWhenRestoring() throws Exception {
        when(scheduledBackupService.restoreLatestFullNow()).thenThrow(new BackupInProgressException());

        mockMvc.perform(post("/admin/backup/restore").param("type", "FULL"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.message").value(BackupInProgressException.MESSAGE));
    }

    @Test
    void anInvalidTypeIsRefusedBeforeTakingTheLock() throws Exception {
        mockMvc.perform(post("/admin/backup/execute").param("type", "nope"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(false));

        verifyNoInteractions(scheduledBackupService);
    }
}
