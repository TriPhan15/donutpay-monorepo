package vn.edu.huit.finance.core.Service;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import vn.edu.huit.finance.core.Exception.SubscriptionPlanNotFoundException;
import vn.edu.huit.finance.core.Dto.SubscriptionPlanRequestDto;
import vn.edu.huit.finance.core.Entity.AuditAction;
import vn.edu.huit.finance.core.Entity.SubscriptionPlan;
import vn.edu.huit.finance.core.Repository.SubscriptionPlanRepository;
import vn.edu.huit.finance.core.Service.Audit.AuditActor;
import vn.edu.huit.finance.core.Service.Audit.AuditEntry;

import java.util.List;
import java.util.NoSuchElementException;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/** Membership plans as administrators change them: each change with its row; a new plan is always a new row. */
@ExtendWith(MockitoExtension.class)
class SubscriptionPlanServiceTest {

    @Mock private SubscriptionPlanRepository repository;
    @Mock private AuditLogService auditLogService;
    @InjectMocks private SubscriptionPlanService service;

    private static SubscriptionPlanRequestDto values(String name) {
        return SubscriptionPlanRequestDto.builder().planName(name).price(99000.0).durationDays(30).maxAiScans(100)
                .wcmSpadeEnabled(true).build();
    }

    private static SubscriptionPlan plan(String name) {
        SubscriptionPlan plan = new SubscriptionPlan();
        plan.setPlanName(name);
        plan.setPrice(99000.0);
        plan.setDurationDays(30);
        plan.setMaxAiScans(100);
        plan.setWcmSpadeEnabled(true);
        return plan;
    }

    private List<AuditEntry> recorded() {
        ArgumentCaptor<AuditEntry> entries = ArgumentCaptor.forClass(AuditEntry.class);
        verify(auditLogService, atLeastOnce()).record(entries.capture());
        return entries.getAllValues();
    }

    @Test
    void aNewPlanIsANewActiveRow_andIsRecorded() {
        SubscriptionPlanRequestDto sent = values("VIP");
        when(repository.save(any(SubscriptionPlan.class))).thenAnswer(invocation -> {
            SubscriptionPlan saved = invocation.getArgument(0);
            saved.setId(8L);
            return saved;
        });

        SubscriptionPlan created = service.createPlan(sent);

        assertTrue(created.isActive());
        assertEquals("VIP", created.getPlanName());
        assertTrue(created.isWcmSpadeEnabled());
        AuditEntry entry = recorded().get(0);
        assertEquals(AuditAction.PLAN_CREATED, entry.action());
        assertEquals(AuditActor.currentCaller(), entry.actor());
        assertEquals(8L, entry.targetId());
        assertEquals("Tạo gói hội viên \"VIP\"", entry.description());
    }

    @Test
    void anUpdateAndBothTogglesAreRecorded() {
        SubscriptionPlan plan = plan("VIP");
        plan.setId(8L);
        plan.setActive(true);
        when(repository.findById(8L)).thenReturn(Optional.of(plan));
        when(repository.save(any(SubscriptionPlan.class))).thenAnswer(invocation -> invocation.getArgument(0));

        service.updatePlan(8L, values("VIP Plus"));
        service.togglePlan(8L);
        service.togglePlan(8L);

        List<AuditEntry> entries = recorded();
        assertEquals(List.of(AuditAction.PLAN_UPDATED, AuditAction.PLAN_STATUS_CHANGED, AuditAction.PLAN_STATUS_CHANGED),
                entries.stream().map(AuditEntry::action).toList());
        assertEquals("Cập nhật thông tin gói \"VIP Plus\"", entries.get(0).description());
        assertEquals("Tạm ẩn gói \"VIP Plus\"", entries.get(1).description());
        assertEquals("Mở bán gói \"VIP Plus\"", entries.get(2).description());
    }

    @Test
    void aDeletionIsRecorded() {
        SubscriptionPlan plan = plan("VIP");
        plan.setId(8L);
        when(repository.findById(8L)).thenReturn(Optional.of(plan));

        service.deletePlan(8L);

        verify(repository).delete(plan);
        assertEquals(AuditAction.PLAN_DELETED, recorded().get(0).action());
    }

    @Test
    void aPlanThatDoesNotExistIsRefused_andNothingIsRecorded() {
        when(repository.findById(9L)).thenReturn(Optional.empty());

        SubscriptionPlanNotFoundException refused = assertThrows(SubscriptionPlanNotFoundException.class, () -> service.togglePlan(9L));

        assertEquals("Không tìm thấy gói hội viên", refused.getMessage());
        verifyNoInteractions(auditLogService);
    }
}
