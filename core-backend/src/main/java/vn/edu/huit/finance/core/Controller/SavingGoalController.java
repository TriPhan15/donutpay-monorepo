package vn.edu.huit.finance.core.Controller;

import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import vn.edu.huit.finance.core.Dto.ApiResponse;
import vn.edu.huit.finance.core.Dto.SavingContributionRequestDto;
import vn.edu.huit.finance.core.Dto.SavingGoalDto;
import vn.edu.huit.finance.core.Service.SavingGoalService;

import java.util.List;

/** The caller's saving goals. The owner is resolved from the SecurityContext inside SavingGoalService. */
@RestController
@RequestMapping("/api/savings")
public class SavingGoalController {

    private static final String MSG_OK = "OK";
    private static final String MSG_CREATED = "Thêm thành công";
    private static final String MSG_UPDATED = "Cập nhật thành công";
    private static final String MSG_DELETED = "Xóa thành công";
    private static final String MSG_CONTRIBUTED = "Góp tiền vào mục tiêu thành công";
    private static final int CODE_OK = 200;

    @Autowired
    private SavingGoalService savingGoalService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<SavingGoalDto>>> getMySavings() {
        return ResponseEntity.ok(ApiResponse.<List<SavingGoalDto>>builder()
                .code(CODE_OK).message(MSG_OK).data(savingGoalService.getMySavings()).build());
    }

    @PostMapping
    public ResponseEntity<ApiResponse<String>> createSaving(@Valid @RequestBody SavingGoalDto dto) {
        savingGoalService.createSaving(dto);
        return ResponseEntity.ok(ApiResponse.<String>builder().code(CODE_OK).message(MSG_CREATED).build());
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<SavingGoalDto>> updateSaving(@PathVariable Long id,
                                                                   @Valid @RequestBody SavingGoalDto dto) {
        return ApiResponses.respond(HttpStatus.OK, MSG_UPDATED, savingGoalService.updateMySaving(id, dto));
    }

    /** Moves money from the caller's wallet into the goal: an expense in "Tiết kiệm", and the goal's current amount grows. */
    @PostMapping("/{id}/contributions")
    public ResponseEntity<ApiResponse<SavingGoalDto>> contribute(@PathVariable Long id,
                                                                 @Valid @RequestBody SavingContributionRequestDto request) {
        return ApiResponses.respond(HttpStatus.OK, MSG_CONTRIBUTED,
                savingGoalService.contributeToMySaving(id, request.getAmount()));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<String>> deleteSaving(@PathVariable Long id) {
        savingGoalService.deleteSaving(id);
        return ResponseEntity.ok(ApiResponse.<String>builder().code(CODE_OK).message(MSG_DELETED).build());
    }
}
