// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get settings => 'Cài đặt';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get theme => 'Giao diện';

  @override
  String get dark => 'Tối';

  @override
  String get light => 'Sáng';

  @override
  String get system => 'Theo hệ thống';

  @override
  String get systemThemeDescription => 'Tự đổi theo cài đặt của thiết bị';

  @override
  String get english => 'English';

  @override
  String get vietnamese => 'Tiếng Việt';

  @override
  String get settingsSaveFailed =>
      'Không lưu được cài đặt. Thay đổi chỉ có hiệu lực đến khi đóng ứng dụng.';

  @override
  String get notificationsTitle => 'Thông báo';

  @override
  String get notificationsMarkAllRead => 'Đọc tất cả';

  @override
  String get notificationsEmpty => 'Chưa có thông báo nào.';

  @override
  String get notificationsLoadFailed => 'Không tải được thông báo.';

  @override
  String get notificationsLoadMoreFailed => 'Không tải thêm được thông báo.';

  @override
  String get notificationsRetry => 'Thử lại';

  @override
  String get notificationsMarkReadFailed =>
      'Không đánh dấu được thông báo là đã đọc. Vui lòng thử lại.';

  @override
  String get notificationsMarkAllReadFailed =>
      'Không đánh dấu được các thông báo là đã đọc. Vui lòng thử lại.';

  @override
  String get notificationsDetailUnavailable =>
      'Chưa thể mở chi tiết của thông báo này.';

  @override
  String get notificationsTransactionNotFound =>
      'Không tìm thấy giao dịch của thông báo này, có thể nó đã bị xóa.';

  @override
  String get notificationsUnread => 'Chưa đọc';

  @override
  String get notificationTypeBudgetWarning => 'Sắp chạm hạn mức ngân sách';

  @override
  String get notificationTypeBudgetExceeded => 'Đã vượt ngân sách';

  @override
  String get notificationTypeTransactionAlert => 'Cảnh báo giao dịch';

  @override
  String get notificationTypeReceiptProcessed => 'Hóa đơn đã được xử lý';

  @override
  String get notificationTypeOther => 'Thông báo';

  @override
  String get sessionEnded =>
      'Phiên đăng nhập đã kết thúc, có thể do mật khẩu vừa được thay đổi. Vui lòng đăng nhập lại.';

  @override
  String get dialogGotIt => 'Đã hiểu';

  @override
  String get forgotPasswordTitle => 'Quên mật khẩu';

  @override
  String get forgotPasswordHeading => 'Nhận mã OTP';

  @override
  String get forgotPasswordDescription =>
      'Nhập email tài khoản của bạn. Chúng tôi sẽ gửi mã OTP để bạn đặt mật khẩu mới.';

  @override
  String get forgotPasswordEmailLabel => 'Email';

  @override
  String get forgotPasswordEmailHint => 'Nhập địa chỉ email';

  @override
  String get forgotPasswordEmailRequired => 'Vui lòng nhập email.';

  @override
  String get forgotPasswordEmailInvalid => 'Email không hợp lệ.';

  @override
  String get forgotPasswordSendOtp => 'Gửi mã OTP';

  @override
  String get forgotPasswordSendFailed => 'Không gửi được mã OTP';

  @override
  String get forgotPasswordRejected =>
      'Không thể gửi mã OTP. Vui lòng kiểm tra email và thử lại.';

  @override
  String get resetPasswordTitle => 'Đặt lại mật khẩu';

  @override
  String get resetPasswordHeading => 'Tạo mật khẩu mới';

  @override
  String resetPasswordDescription(String email) {
    return 'Nhập mã OTP đã được gửi tới $email, sau đó đặt mật khẩu mới.';
  }

  @override
  String get resetPasswordOtpLabel => 'Mã OTP';

  @override
  String resetPasswordOtpHint(int length) {
    return 'Mã gồm $length chữ số';
  }

  @override
  String get resetPasswordOtpRequired => 'Vui lòng nhập mã OTP.';

  @override
  String resetPasswordOtpInvalid(int length) {
    return 'Mã OTP phải gồm đúng $length chữ số.';
  }

  @override
  String get resetPasswordResendOtp => 'Gửi lại mã OTP';

  @override
  String resetPasswordResendIn(int seconds) {
    return 'Gửi lại mã sau $seconds giây';
  }

  @override
  String get resetPasswordOtpResent =>
      'Đã gửi lại mã OTP. Vui lòng kiểm tra email.';

  @override
  String get resetPasswordNewPasswordLabel => 'Mật khẩu mới';

  @override
  String get resetPasswordNewPasswordHint => 'Nhập mật khẩu mới';

  @override
  String get resetPasswordPasswordRequired => 'Vui lòng nhập mật khẩu mới.';

  @override
  String resetPasswordPasswordPolicy(int min, int max) {
    return 'Từ $min đến $max ký tự, gồm ít nhất một chữ cái và một chữ số.';
  }

  @override
  String get resetPasswordConfirmPasswordLabel => 'Xác nhận mật khẩu mới';

  @override
  String get resetPasswordConfirmPasswordHint => 'Nhập lại mật khẩu mới';

  @override
  String get resetPasswordConfirmRequired => 'Vui lòng xác nhận mật khẩu mới.';

  @override
  String get resetPasswordMismatch => 'Mật khẩu xác nhận không khớp.';

  @override
  String get resetPasswordSubmit => 'Đặt lại mật khẩu';

  @override
  String get resetPasswordSubmitting => 'Đang xử lý...';

  @override
  String get resetPasswordSuccessTitle => 'Đặt lại mật khẩu thành công';

  @override
  String get resetPasswordSuccessMessage =>
      'Mật khẩu đã được thay đổi. Vui lòng đăng nhập bằng mật khẩu mới.';

  @override
  String get resetPasswordBackToLogin => 'Về trang đăng nhập';

  @override
  String get resetPasswordFailed => 'Đặt lại mật khẩu thất bại';

  @override
  String get resetPasswordRejected =>
      'Không thể đặt lại mật khẩu. Vui lòng kiểm tra mã OTP và thử lại.';

  @override
  String get passwordShow => 'Hiện mật khẩu';

  @override
  String get passwordHide => 'Ẩn mật khẩu';

  @override
  String get passwordRecoverySending => 'Đang gửi...';

  @override
  String get passwordRecoveryNetworkError =>
      'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng và thử lại.';

  @override
  String get passwordRecoveryTimeout =>
      'Máy chủ phản hồi quá lâu. Vui lòng thử lại.';

  @override
  String get passwordRecoveryServerError =>
      'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.';

  @override
  String get passwordRecoveryUnexpectedError =>
      'Đã xảy ra lỗi. Vui lòng thử lại.';

  @override
  String get navHome => 'Trang chủ';

  @override
  String get navLedger => 'Thống kê';

  @override
  String get navAi => 'AI';

  @override
  String get navProfile => 'Cá nhân';

  @override
  String get scanSheetTitle => 'Quét hóa đơn bằng AI';

  @override
  String get scanWithAi => 'Quét AI';

  @override
  String get scanFromGallery => 'Từ thư viện';

  @override
  String get scanScannerFailedTitle => 'Không mở được trình quét';

  @override
  String get scanScannerFailedMessage =>
      'Vui lòng thử lại hoặc chọn ảnh từ thư viện.';

  @override
  String get scanGalleryFailedTitle => 'Không mở được thư viện ảnh';

  @override
  String get scanGalleryFailedMessage =>
      'Vui lòng kiểm tra quyền truy cập ảnh của ứng dụng và thử lại.';

  @override
  String get dialogOk => 'OK';

  @override
  String get dialogConfirm => 'Đồng ý';

  @override
  String get dialogCancel => 'Hủy';

  @override
  String get errorNetwork =>
      'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng và thử lại.';

  @override
  String get errorTimeout => 'Máy chủ phản hồi quá lâu. Vui lòng thử lại.';

  @override
  String get errorServer => 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.';

  @override
  String get errorSessionExpired =>
      'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';

  @override
  String get errorUnexpected => 'Đã có lỗi xảy ra. Vui lòng thử lại.';

  @override
  String get transactionRefused =>
      'Máy chủ từ chối giao dịch này. Vui lòng kiểm tra lại thông tin.';

  @override
  String get defaultUserName => 'Người dùng';

  @override
  String get mainWalletName => 'Ví chính';

  @override
  String get syncStatusPending => 'Chờ gửi';

  @override
  String get syncStatusSynced => 'Đã đồng bộ';

  @override
  String get syncStatusError => 'Gửi lỗi';

  @override
  String get receiptStatusProcessing => 'Đang xử lý';

  @override
  String get receiptStatusSuccess => 'Hoàn tất';

  @override
  String get receiptStatusFailed => 'Lỗi · cần xác nhận lại';

  @override
  String get budgetPeriodWeek => 'Tuần';

  @override
  String get budgetPeriodMonth => 'Tháng';

  @override
  String get budgetAllCategories => 'Tất cả danh mục';

  @override
  String dateTodayAt(String time) {
    return 'Hôm nay, $time';
  }

  @override
  String dateYesterdayAt(String time) {
    return 'Hôm qua, $time';
  }

  @override
  String get passwordEmpty => 'Mật khẩu không được để trống.';

  @override
  String passwordLength(int min, int max) {
    return 'Mật khẩu phải từ $min đến $max ký tự.';
  }

  @override
  String get passwordLetterAndDigit =>
      'Mật khẩu phải chứa ít nhất một chữ cái và một chữ số.';

  @override
  String currencyVnd(String amount) {
    return '$amount đ';
  }

  @override
  String get weekdayShortMon => 'T2';

  @override
  String get weekdayShortTue => 'T3';

  @override
  String get weekdayShortWed => 'T4';

  @override
  String get weekdayShortThu => 'T5';

  @override
  String get weekdayShortFri => 'T6';

  @override
  String get weekdayShortSat => 'T7';

  @override
  String get weekdayShortSun => 'CN';

  @override
  String get categoryAll => 'Tất cả';

  @override
  String get categoryFood => 'Ăn uống';

  @override
  String get categoryGroceries => 'Siêu thị & Chợ';

  @override
  String get categoryTransport => 'Di chuyển';

  @override
  String get categoryHousing => 'Nhà ở';

  @override
  String get categoryUtilities => 'Điện nước';

  @override
  String get categoryTelecom => 'Internet & Điện thoại';

  @override
  String get categoryShopping => 'Mua sắm';

  @override
  String get categoryHealth => 'Sức khỏe';

  @override
  String get categoryEducation => 'Giáo dục';

  @override
  String get categoryEntertainment => 'Giải trí';

  @override
  String get categoryTravel => 'Du lịch';

  @override
  String get categoryFamily => 'Gia đình & Con cái';

  @override
  String get categorySocial => 'Hiếu hỉ';

  @override
  String get categoryInsurance => 'Bảo hiểm';

  @override
  String get categoryOtherExpense => 'Khác';

  @override
  String get categorySalary => 'Lương';

  @override
  String get categoryBonus => 'Thưởng';

  @override
  String get categoryBusiness => 'Kinh doanh';

  @override
  String get categoryInvestment => 'Đầu tư';

  @override
  String get categoryGift => 'Được tặng';

  @override
  String get categoryOtherIncome => 'Thu khác';

  @override
  String get authMissingInfoTitle => 'Thiếu thông tin';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authEmailHint => 'Nhập địa chỉ email';

  @override
  String get authPasswordLabel => 'Mật khẩu';

  @override
  String get authPasswordHint => 'Nhập mật khẩu';

  @override
  String get authProcessing => 'Đang xử lý...';

  @override
  String get loginFailedTitle => 'Đăng nhập thất bại';

  @override
  String get loginWrongCredentials => 'Sai email hoặc mật khẩu!';

  @override
  String get loginSocialFailed =>
      'Không đăng nhập được bằng tài khoản mạng xã hội. Vui lòng thử lại.';

  @override
  String get loginMissingCredentials => 'Vui lòng nhập email và mật khẩu.';

  @override
  String get loginInvalidResponse =>
      'Phản hồi từ máy chủ không hợp lệ. Vui lòng thử lại.';

  @override
  String get loginTagline => 'Quản lý tài chính thông minh';

  @override
  String get loginRememberMe => 'Ghi nhớ đăng nhập';

  @override
  String get loginForgotPassword => 'Quên mật khẩu?';

  @override
  String get loginSubmit => 'Đăng nhập';

  @override
  String get loginNoAccount => 'Chưa có tài khoản? ';

  @override
  String get loginSignUpNow => 'Đăng ký ngay';

  @override
  String get loginOrContinueWith => 'Hoặc đăng nhập với';

  @override
  String get registerTitle => 'Đăng ký';

  @override
  String get registerHeading => 'Tạo tài khoản';

  @override
  String get registerDescription =>
      'Điền thông tin để bắt đầu quản lý tài chính.';

  @override
  String get registerFullNameLabel => 'Họ và tên';

  @override
  String get registerFullNameHint => 'Nhập họ và tên';

  @override
  String get registerPhoneLabel => 'Số điện thoại';

  @override
  String get registerPhoneHint => 'Nhập số điện thoại';

  @override
  String get registerSubmit => 'Tạo tài khoản';

  @override
  String get registerOrContinueWith => 'Hoặc đăng ký với';

  @override
  String get registerTermsPrefix => 'Bằng việc đăng ký, bạn đồng ý với ';

  @override
  String get registerTerms => 'Điều khoản';

  @override
  String get registerTermsAnd => ' và ';

  @override
  String get registerConditions => 'Điều kiện sử dụng';

  @override
  String get registerMissingFields =>
      'Vui lòng nhập đủ thông tin (gồm số điện thoại).';

  @override
  String get registerWeakPasswordTitle => 'Mật khẩu yếu';

  @override
  String get registerWeakPasswordMessage => 'Mật khẩu chưa đạt yêu cầu.';

  @override
  String get registerSuccessTitle => 'Đăng ký thành công';

  @override
  String get registerSuccessMessage =>
      'Tài khoản đã được tạo. Vui lòng đăng nhập.';

  @override
  String get registerFailedTitle => 'Đăng ký thất bại';

  @override
  String get registerSocialFailed =>
      'Không đăng ký được bằng tài khoản mạng xã hội. Vui lòng thử lại.';

  @override
  String get registerPasswordNeeds => 'Mật khẩu cần:';

  @override
  String registerRuleMinLength(int min) {
    return 'Ít nhất $min ký tự';
  }

  @override
  String get registerRuleUppercase => 'Chữ viết hoa (A-Z)';

  @override
  String get registerRuleLowercase => 'Chữ viết thường (a-z)';

  @override
  String get registerRuleDigit => 'Chữ số (0-9)';

  @override
  String get registerRuleSpecial => 'Ký tự đặc biệt (!@#...)';

  @override
  String get commonSaveChanges => 'Lưu thay đổi';

  @override
  String get credentialsTitle => 'Tài khoản';

  @override
  String get credentialsNoData => 'Chưa có dữ liệu tài khoản.';

  @override
  String get credentialsTapToEdit => 'Chạm vào dòng cần sửa.';

  @override
  String get credentialsUsername => 'Tên đăng nhập';

  @override
  String get credentialsUsernameEmail => 'Tên đăng nhập (Email)';

  @override
  String get credentialsEditUsername => 'Chỉnh sửa tên đăng nhập';

  @override
  String get credentialsUsernameRequired => 'Vui lòng nhập tên đăng nhập.';

  @override
  String get credentialsUsernameChangeUnsupported =>
      'Máy chủ chưa hỗ trợ đổi tên đăng nhập.';

  @override
  String get credentialsChangePassword => 'Đổi mật khẩu';

  @override
  String get credentialsOldPassword => 'Mật khẩu cũ';

  @override
  String get credentialsOldPasswordRequired => 'Vui lòng nhập mật khẩu cũ.';

  @override
  String get credentialsPasswordMismatch => 'Mật khẩu mới không khớp.';

  @override
  String get credentialsChangePasswordFailed => 'Đổi mật khẩu thất bại';

  @override
  String get credentialsChangePasswordRejected =>
      'Không đổi được mật khẩu. Vui lòng kiểm tra mật khẩu cũ và thử lại.';

  @override
  String get credentialsChangePasswordSuccessTitle => 'Đổi mật khẩu thành công';

  @override
  String get credentialsChangePasswordSuccessMessage =>
      'Mật khẩu mới đã được áp dụng cho tài khoản của bạn.';

  @override
  String get accountInfoTitle => 'Thông tin tài khoản';

  @override
  String get accountInfoSignInAgain => 'Vui lòng đăng nhập lại.';

  @override
  String get userInfoTitle => 'Thông tin cá nhân';

  @override
  String get userInfoEdit => 'Chỉnh sửa';

  @override
  String get userInfoEmpty => 'Chưa có thông tin cá nhân.';

  @override
  String get userInfoNotSet => 'Chưa cập nhật';

  @override
  String get commonSuccess => 'Thành công';

  @override
  String get commonSaveFailed => 'Lưu thất bại';

  @override
  String get commonSaving => 'Đang lưu...';

  @override
  String get commonRetry => 'Thử lại';

  @override
  String get setUserInfoTitle => 'Thiết lập thông tin';

  @override
  String get setUserInfoLoadFailed =>
      'Không tải được thông tin cá nhân. Vui lòng thử lại.';

  @override
  String get setUserInfoNameRequired => 'Vui lòng nhập họ và tên.';

  @override
  String get setUserInfoPhoneInvalid =>
      'Số điện thoại không hợp lệ (10 số, bắt đầu bằng 0).';

  @override
  String get setUserInfoSaved => 'Đã lưu thông tin cá nhân.';

  @override
  String get profileUtilities => 'Tiện ích';

  @override
  String get profileMoneySources => 'Nguồn tiền';

  @override
  String get profileLinkedServices => 'Dịch vụ liên kết';

  @override
  String get profileBudget => 'Ngân sách';

  @override
  String get profileSecurityPrivacy => 'Bảo mật & Quyền riêng tư';

  @override
  String get profileSupport => 'Hỗ trợ';

  @override
  String get profileHelp => 'Hướng dẫn sử dụng';

  @override
  String get profileFeedback => 'Gửi phản hồi';

  @override
  String get profileAbout => 'Về ứng dụng';

  @override
  String get profileLogout => 'Đăng xuất';

  @override
  String get profileLogoutConfirmTitle => 'Đăng xuất?';

  @override
  String get profileLogoutConfirmMessage => 'Bạn có chắc chắn muốn thoát?';

  @override
  String get commonSave => 'Lưu';

  @override
  String get notificationSettingsTitle => 'Cài đặt thông báo';

  @override
  String get notificationSettingsPush => 'Thông báo đẩy';

  @override
  String get notificationSettingsBudgetAlert => 'Cảnh báo ngân sách';

  @override
  String get notificationSettingsSaved => 'Đã lưu cài đặt thông báo.';

  @override
  String get moneySourcesEmpty => 'Chưa có ví nào.';

  @override
  String get activityLogTitle => 'Lịch sử hoạt động';

  @override
  String get activityLogSubtitle => 'Xem các giao dịch gần đây';

  @override
  String activityLogTitleCount(int count) {
    return 'Lịch sử hoạt động ($count)';
  }

  @override
  String get pinSetupTitle => 'Tạo / Đổi mã PIN';

  @override
  String get pinSetupSubtitle => 'Bảo vệ ứng dụng bằng mã 4 số';

  @override
  String get pinNewLabel => 'Mã PIN mới';

  @override
  String get pinConfirmLabel => 'Xác nhận mã PIN';

  @override
  String get pinLengthInvalid => 'Mã PIN phải đúng 4 số.';

  @override
  String get pinMismatch => 'Mã PIN không khớp.';

  @override
  String get pinSaved => 'Đã lưu mã PIN thành công!';

  @override
  String get helpDashboardTitle => 'Dashboard';

  @override
  String get helpDashboardBody =>
      'Xem tổng quan tài sản, thu chi tháng và biểu đồ dòng tiền.';

  @override
  String get helpLedgerTitle => 'Sổ sách';

  @override
  String get helpLedgerBody =>
      'Thêm, lọc và xem chi tiết giao dịch theo ngày, lịch hoặc tháng.';

  @override
  String get helpScanTitle => 'Quét hóa đơn';

  @override
  String get helpScanBody =>
      'Nhấn nút tròn giữa thanh điều hướng để quét hóa đơn bằng AI.';

  @override
  String get helpAiTitle => 'Phân tích AI';

  @override
  String get helpAiBody =>
      'Xem xu hướng chi tiêu và mẫu hành vi tài chính được phân tích tự động.';

  @override
  String get helpTransferTitle => 'Chuyển tiền';

  @override
  String get helpTransferBody =>
      'Chuyển/nhận tiền qua số điện thoại hoặc mã QR.';

  @override
  String get feedbackTitle => 'Đánh giá ứng dụng';

  @override
  String get feedbackDescription =>
      'Ý kiến của bạn sẽ giúp hệ thống ngày càng hoàn thiện hơn!';

  @override
  String get feedbackHint => 'Nhập cảm nhận hoặc góp ý...';

  @override
  String get feedbackLater => 'Để sau';

  @override
  String get feedbackSubmit => 'Gửi ngay';

  @override
  String get feedbackThanks => 'Cảm ơn bạn đã gửi đánh giá góp ý!';

  @override
  String get feedbackFailed => 'Gửi đánh giá thất bại, vui lòng thử lại sau.';

  @override
  String get aboutDescription =>
      'Ứng dụng quản lý tài chính cá nhân thông minh với AI phân tích chi tiêu.';

  @override
  String get savingsTitle => 'Sổ tiết kiệm';

  @override
  String savingsLoadFailed(String reason) {
    return 'Không tải được sổ tiết kiệm. $reason';
  }

  @override
  String savingsDeleteFailed(String reason) {
    return 'Không xóa được mục tiêu. $reason';
  }

  @override
  String savingsDeleted(String title) {
    return 'Đã xóa mục tiêu: $title';
  }

  @override
  String get savingsAddTitle => 'Thêm mục tiêu tiết kiệm';

  @override
  String get savingsAdd => 'Thêm';

  @override
  String get savingsGoalName => 'Tên mục tiêu';

  @override
  String get savingsTargetAmount => 'Số tiền mục tiêu (₫)';

  @override
  String get savingsSavedAmount => 'Đã tiết kiệm (₫)';

  @override
  String get savingsDeadlineField => 'Hạn chót (dd/mm/yyyy)';

  @override
  String savingsUpdateTitle(String title) {
    return 'Cập nhật: $title';
  }

  @override
  String get savingsCurrentAmount => 'Số tiền đã tiết kiệm (₫)';

  @override
  String get savingsTotalSaved => 'Tổng đã tiết kiệm';

  @override
  String savingsGoalCount(int count) {
    return '$count mục tiêu';
  }

  @override
  String savingsTarget(String amount) {
    return 'Mục tiêu: $amount';
  }

  @override
  String get savingsAddGoalAction => 'Thêm\nmục tiêu';

  @override
  String get savingsGoalList => 'Danh sách mục tiêu';

  @override
  String get savingsEmpty => 'Chưa có mục tiêu nào.';

  @override
  String get savingsEmptyHint => 'Nhấn \"+\" để tạo mục tiêu tiết kiệm.';

  @override
  String savingsDeadline(String date) {
    return 'Hạn: $date';
  }

  @override
  String get savingsUpdate => 'Cập nhật';

  @override
  String get commonSessionExpiredTitle => 'Phiên đăng nhập hết hạn';

  @override
  String get commonInvalidAmountTitle => 'Số tiền không hợp lệ';

  @override
  String get commonSummary => 'Tổng kết';

  @override
  String get currencySymbol => 'đ';

  @override
  String get transactionSaveFailed =>
      'Không lưu được giao dịch. Vui lòng thử lại.';

  @override
  String get transactionNotSentTitle => 'Chưa gửi được lên máy chủ';

  @override
  String get transactionNotSentMessage =>
      'Giao dịch đã được lưu trên thiết bị nhưng chưa gửi được lên máy chủ. Khi có mạng, mở Sổ sách, chọn giao dịch và bấm \"Gửi lại\". Gửi lại sẽ không tạo giao dịch trùng.';

  @override
  String get transactionCategoryLabel => 'Danh mục';

  @override
  String get transactionDateLabel => 'Ngày giao dịch';

  @override
  String get transactionNoteOptional => 'Ghi chú (tùy chọn)';

  @override
  String get transactionPickExpenseCategory => 'Chọn danh mục chi';

  @override
  String get transactionPickIncomeCategory => 'Chọn danh mục thu';

  @override
  String get transactionExpenseMoney => 'Tiền chi';

  @override
  String get transactionIncomeMoney => 'Tiền thu';

  @override
  String get transactionExpenseKind => 'Khoản chi';

  @override
  String get transactionIncomeKind => 'Khoản thu';

  @override
  String get addTransactionTitle => 'Thêm giao dịch';

  @override
  String get addTransactionAmountLabel => 'Số tiền';

  @override
  String get addTransactionInvalidAmount => 'Vui lòng nhập số tiền hợp lệ.';

  @override
  String get addTransactionNoteHint => 'VD: Mua cafe Highlands';

  @override
  String get addTransactionSubmit => 'Lưu giao dịch';

  @override
  String get addTransactionSaved => 'Đã thêm giao dịch mới.';

  @override
  String get editTransactionTitle => 'Sửa giao dịch';

  @override
  String get editTransactionAmountLabel => 'Số tiền (₫)';

  @override
  String get editTransactionNoServerIdTitle => 'Không sửa được giao dịch';

  @override
  String get editTransactionNoServerIdMessage =>
      'Giao dịch này chưa có mã trên máy chủ.';

  @override
  String get editTransactionAmountPositive =>
      'Vui lòng nhập số tiền lớn hơn 0.';

  @override
  String get editTransactionNoChangesTitle => 'Chưa có thay đổi';

  @override
  String get editTransactionNoChangesMessage =>
      'Hãy sửa số tiền, danh mục hoặc ghi chú trước khi lưu.';

  @override
  String get editTransactionSaveFailedTitle => 'Không lưu được giao dịch';

  @override
  String get editTransactionRejected =>
      'Máy chủ chưa xử lý được yêu cầu. Vui lòng thử lại sau.';

  @override
  String get editTransactionSavedTitle => 'Đã lưu thay đổi';

  @override
  String get editTransactionSavedMessage => 'Giao dịch đã được cập nhật.';

  @override
  String get editTransactionCategoriesUnavailable =>
      'Không tải được danh sách danh mục. Bạn vẫn có thể sửa số tiền và ghi chú.';

  @override
  String get ledgerTitle => 'Sổ sách';

  @override
  String get ledgerSearchHint => 'Tìm tên, danh mục...';

  @override
  String get ledgerCalendar => 'Lịch';

  @override
  String get ledgerLegendIncome => 'Thu';

  @override
  String get ledgerLegendExpense => 'Chi';

  @override
  String ledgerChartMonth(String month) {
    return 'Th$month';
  }

  @override
  String get ledgerIncome => 'Thu nhập';

  @override
  String get ledgerExpense => 'Chi tiêu';

  @override
  String get ledgerRecent => 'Giao dịch gần đây';

  @override
  String get ledgerEmptyPeriod => 'Không có giao dịch trong kỳ này.';

  @override
  String get ledgerTotalIncome => 'Tổng thu';

  @override
  String get ledgerTotalExpense => 'Tổng chi';

  @override
  String get ledgerBalance => 'Số dư';

  @override
  String get ledgerFilterTitle => 'Bộ lọc & Sắp xếp thông minh';

  @override
  String get ledgerFilterType => '1. Loại giao dịch';

  @override
  String get ledgerFilterAll => 'Tất cả';

  @override
  String get ledgerFilterExpenseOnly => 'Chỉ Khoản Chi';

  @override
  String get ledgerFilterIncomeOnly => 'Chỉ Khoản Thu';

  @override
  String get ledgerFilterAmount => '2. Khoảng tiền';

  @override
  String get ledgerFilterAnyAmount => 'Mọi mức giá';

  @override
  String get ledgerFilterSort => '3. Sắp xếp theo';

  @override
  String get ledgerSortNewest => 'Mới nhất';

  @override
  String get ledgerSortOldest => 'Cũ nhất';

  @override
  String get ledgerSortHighest => 'Giá trị cao nhất';

  @override
  String get ledgerFilterApply => 'Áp dụng bộ lọc';

  @override
  String get ledgerDetailAmount => 'Số tiền:';

  @override
  String get ledgerDetailTime => 'Thời gian:';

  @override
  String get ledgerDetailReceiptStatus => 'Trạng thái hóa đơn:';

  @override
  String get ledgerDetailSync => 'Đồng bộ:';

  @override
  String get ledgerDetailUnsyncedHint =>
      'Giao dịch chưa được máy chủ xác nhận. Khi đã có mạng, bấm \"Gửi lại\". Gửi lại sẽ không tạo giao dịch trùng.';

  @override
  String get ledgerDetailReceiptImage => 'Ảnh hóa đơn gốc:';

  @override
  String get ledgerResend => 'Gửi lại';

  @override
  String get ledgerDelete => 'Xóa giao dịch này';

  @override
  String get ledgerDeleteTitle => 'Xóa giao dịch?';

  @override
  String get ledgerDeleteMessage =>
      'Hành động này sẽ hoàn lại tiền vào ví và không thể khôi phục. Bạn chắc chứ?';

  @override
  String get ledgerDeleteNow => 'Xóa ngay';

  @override
  String get ledgerDeleted => 'Đã xóa giao dịch và hoàn tiền';

  @override
  String get ledgerDeleteFailed => 'Xóa thất bại, vui lòng thử lại';

  @override
  String get ledgerResendFailedTitle => 'Gửi lại thất bại';

  @override
  String get ledgerResendFailedMessage =>
      'Không gửi lại được giao dịch. Vui lòng thử lại.';

  @override
  String get ledgerResent => 'Đã gửi giao dịch lên máy chủ';

  @override
  String get ledgerStillNotSentTitle => 'Vẫn chưa gửi được';

  @override
  String get ledgerStillNotSentMessage =>
      'Chưa kết nối được máy chủ. Giao dịch vẫn được giữ trên thiết bị, bạn có thể gửi lại sau.';

  @override
  String get ledgerDeleteUnsyncedTitle => 'Xóa giao dịch chưa gửi?';

  @override
  String get ledgerDeleteUnsyncedMessage =>
      'Giao dịch này chưa được máy chủ xác nhận. Xóa khỏi thiết bị và không gửi nữa? Hành động này không thể khôi phục.';

  @override
  String get ledgerDeletedUnsynced => 'Đã xóa giao dịch chưa gửi';

  @override
  String get ledgerLoadFailedNotice =>
      'Không tải được danh sách từ máy chủ. Chỉ hiển thị các giao dịch chưa gửi trên thiết bị. Kéo xuống để thử lại.';

  @override
  String ledgerExcelSheet(String month) {
    return 'Chi tiêu tháng $month';
  }

  @override
  String get ledgerExcelDate => 'Ngày';

  @override
  String get ledgerExcelTotal => 'Tổng cộng';

  @override
  String ledgerExcelBudgetHeader(String month) {
    return 'NGÂN SÁCH THÁNG $month';
  }

  @override
  String get ledgerExcelLimit => 'Giới hạn';

  @override
  String get ledgerExcelSpent => 'Đã tiêu';

  @override
  String get ledgerExcelRemaining => 'Còn lại';

  @override
  String ledgerExcelFileName(String month, String date) {
    return 'chi_tieu_$month$date';
  }

  @override
  String ledgerExcelShareText(String month) {
    return 'Báo cáo chi tiêu tháng $month';
  }

  @override
  String get reviewTitle => 'Xác nhận hóa đơn';

  @override
  String get reviewDateFallback =>
      'Không đọc được ngày trên hóa đơn, đang dùng thời điểm hiện tại. Chạm để chọn lại.';

  @override
  String get reviewFieldNeedsCheck =>
      'AI chưa chắc chắn ở trường này, vui lòng kiểm tra lại.';

  @override
  String get reviewNoTotal =>
      'Donut chưa đọc được tổng tiền từ ảnh — vui lòng nhập tay.';

  @override
  String get reviewScanFailed =>
      'Quét hóa đơn thất bại (Kiểm tra AI service). Vui lòng nhập tay.';

  @override
  String get reviewPhotoUploadFailedTitle => 'Không tải được ảnh hóa đơn';

  @override
  String get reviewPhotoUploadFailedMessage =>
      'Ảnh hóa đơn chưa được tải lên máy chủ. Bạn có muốn lưu giao dịch mà không kèm ảnh không?';

  @override
  String get reviewSaveWithoutPhoto => 'Lưu không kèm ảnh';

  @override
  String get reviewLater => 'Để sau';

  @override
  String get reviewTotalPositive => 'Vui lòng nhập tổng tiền lớn hơn 0.';

  @override
  String get reviewSaved => 'Đã lưu giao dịch từ hóa đơn.';

  @override
  String get reviewAnalyzing => 'Đang phân tích hóa đơn...';

  @override
  String get reviewPleaseWait => 'Vui lòng đợi trong giây lát';

  @override
  String get reviewExtracted => 'Trích xuất thành công';

  @override
  String get reviewCheckDetails =>
      'Vui lòng kiểm tra lại thông tin bên dưới và đối chiếu với ảnh gốc trước khi lưu.';

  @override
  String get reviewGeneralInfo => 'Thông tin chung';

  @override
  String get reviewStoreName => 'Tên cửa hàng';

  @override
  String get reviewTotalLabel => 'Tổng tiền (đ)';

  @override
  String get reviewSubtotal => 'Tạm tính:';

  @override
  String get reviewTax => 'Thuế VAT/Khác:';

  @override
  String get reviewGrandTotal => 'TỔNG TIỀN:';

  @override
  String get reviewSubmit => 'Xác nhận & Lưu CSDL';

  @override
  String get paymentHistoryTitle => 'Lịch sử nạp/rút';

  @override
  String paymentHistoryLoadFailed(String reason) {
    return 'Không tải được lịch sử. $reason';
  }

  @override
  String get paymentHistoryEmpty => 'Chưa có giao dịch nạp/rút.';

  @override
  String paymentCancelled(String code) {
    return 'Đã hủy đơn $code';
  }

  @override
  String paymentCancelFailed(String reason) {
    return 'Hủy đơn thất bại. $reason';
  }

  @override
  String get paymentDeposit => 'Nạp tiền';

  @override
  String get paymentWithdrawal => 'Rút tiền';

  @override
  String paymentOrderCode(String code) {
    return 'Mã: $code';
  }

  @override
  String get paymentCancelOrder => 'Hủy đơn';

  @override
  String get paymentStatusSuccess => 'Thành công';

  @override
  String get paymentStatusFailed => 'Thất bại';

  @override
  String get paymentStatusCancelled => 'Đã hủy';

  @override
  String get paymentStatusPending => 'Đang chờ';

  @override
  String linkedCreateOrderFailed(String reason) {
    return 'Tạo đơn đồng bộ thất bại. $reason';
  }

  @override
  String get linkedPollTimedOut =>
      'Chưa nhận được kết quả thanh toán. Vui lòng kiểm tra lại trong Lịch sử đồng bộ.';

  @override
  String get linkedDemoWallet => 'Ví Demo';

  @override
  String linkedSyncFrom(String wallet) {
    return 'Đồng bộ từ $wallet';
  }

  @override
  String get linkedAmountPrompt => 'Số tiền nạp vào ngân sách chi tiêu:';

  @override
  String get linkedAmountHint => 'VD: 100000';

  @override
  String get linkedSync => 'Đồng bộ';

  @override
  String linkedMinAmount(String amount) {
    return 'Số tiền tối thiểu $amount.';
  }

  @override
  String linkedSynced(String amount) {
    return 'Đã đồng bộ $amount vào ngân sách chi tiêu.';
  }

  @override
  String linkedSyncOutcome(String status) {
    return 'Đồng bộ: $status';
  }

  @override
  String get linkedHistoryTooltip => 'Lịch sử đồng bộ';

  @override
  String get linkedWalletsHeading => 'Ví điện tử đã liên kết';

  @override
  String get linkedWalletsDescription =>
      'Đồng bộ tiền từ ví vào ngân sách để quản lý chi tiêu.';

  @override
  String get linkedSyncing => 'Đang đồng bộ... hoàn tất thanh toán trên cổng.';

  @override
  String get linkedLinked => 'Đã liên kết';

  @override
  String get commonDelete => 'Xóa';

  @override
  String get commonApply => 'Áp dụng';

  @override
  String get commonRefresh => 'Làm mới';

  @override
  String get periodThisWeek => 'Tuần này';

  @override
  String get periodThisMonth => 'Tháng này';

  @override
  String get periodCustom => 'Tùy chọn';

  @override
  String get budgetTitle => 'Ngân sách';

  @override
  String get budgetManage => 'Quản lý';

  @override
  String get budgetEmptyPeriod => 'Chưa có ngân sách trong kỳ này.';

  @override
  String get budgetLoadFailedPullToRetry =>
      'Không tải được ngân sách. Kéo xuống để thử lại.';

  @override
  String budgetMoreCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count ngân sách khác',
    );
    return '$_temp0';
  }

  @override
  String budgetOverBy(String amount) {
    return 'Đã vượt hạn mức: $amount';
  }

  @override
  String budgetNearLimitLeft(String amount) {
    return 'Sắp chạm hạn mức · Còn lại: $amount';
  }

  @override
  String budgetLeft(String amount) {
    return 'Còn lại: $amount';
  }

  @override
  String get budgetAlertWarningTitle => 'Sắp chạm hạn mức ngân sách';

  @override
  String get budgetAlertExceededTitle => 'Đã vượt ngân sách';

  @override
  String budgetAlertExceededLine(
    String name,
    String period,
    String amounts,
    String percent,
  ) {
    return '• $name (theo $period): đã vượt hạn mức — $amounts ($percent%)';
  }

  @override
  String budgetAlertWarningLine(
    String name,
    String period,
    String amounts,
    String percent,
  ) {
    return '• $name (theo $period): đã dùng $percent% hạn mức — $amounts';
  }

  @override
  String get budgetLoadFailedTitle => 'Không tải được ngân sách';

  @override
  String get budgetDeleteTitle => 'Xóa ngân sách?';

  @override
  String budgetDeleteMessage(String name) {
    return 'Ngân sách \"$name\" sẽ bị xóa.';
  }

  @override
  String get budgetDeleteFailedTitle => 'Không xóa được ngân sách';

  @override
  String get budgetDeleted => 'Đã xóa ngân sách';

  @override
  String get budgetEmpty => 'Chưa có ngân sách nào.';

  @override
  String get budgetEmptyHint =>
      'Đặt hạn mức chi tiêu theo tuần hoặc tháng để kiểm soát tốt hơn.';

  @override
  String get budgetCreate => 'Thiết lập ngân sách';

  @override
  String get budgetEditTitle => 'Sửa ngân sách';

  @override
  String get budgetAmountLabel => 'Số tiền ngân sách (₫)';

  @override
  String get budgetAmountPositive =>
      'Vui lòng nhập số tiền ngân sách lớn hơn 0.';

  @override
  String get budgetPeriodLabel => 'Kỳ hạn';

  @override
  String get budgetAppliedPeriod => 'Kỳ áp dụng';

  @override
  String get budgetSave => 'Lưu ngân sách';

  @override
  String get budgetSaveFailedTitle => 'Không lưu được ngân sách';

  @override
  String get budgetSavedTitle => 'Đã lưu ngân sách';

  @override
  String get budgetSavedMessage => 'Hạn mức chi tiêu của bạn đã được cập nhật.';

  @override
  String get budgetCategoriesLoadFailedTitle => 'Không tải được danh mục';

  @override
  String budgetCategoriesLoadFailedMessage(String allLabel) {
    return 'Bạn vẫn có thể chọn \"$allLabel\" hoặc thử lại sau.';
  }

  @override
  String get dashboardGreeting => 'Xin chào,';

  @override
  String get dashboardBalance => 'Số dư hiện tại';

  @override
  String get dashboardVsLastMonth => 'so với tháng trước';

  @override
  String get dashboardReports => 'Báo cáo';

  @override
  String get dashboardAllFeatures => 'Tất cả';

  @override
  String get dashboardNoTransactions => 'Chưa có giao dịch nào.';

  @override
  String get moneySourcesSubtitle => 'Các ví đã liên kết với tài khoản';

  @override
  String get allFeaturesTitle => 'Tất cả tính năng';

  @override
  String get featureSavingsDescription => 'Quản lý mục tiêu tiết kiệm';

  @override
  String get featureMoneySourcesDescription => 'Xem ví và số dư';

  @override
  String get featureLinkedServicesDescription => 'MoMo, ZaloPay, ngân hàng...';

  @override
  String get aiTitle => 'Phân tích AI';

  @override
  String get aiPickRangeTitle => 'Chọn khoảng thời gian';

  @override
  String get aiErrorNetwork =>
      'Không kết nối được tới máy chủ phân tích. Vui lòng kiểm tra mạng và thử lại.';

  @override
  String get aiErrorServer =>
      'Máy chủ phân tích đang gặp sự cố. Vui lòng thử lại sau.';

  @override
  String get aiErrorRejected =>
      'Máy chủ phân tích chưa xử lý được yêu cầu. Vui lòng thử lại sau.';

  @override
  String get aiAnalyzeFailedTitle => 'Không phân tích được thói quen chi tiêu';

  @override
  String get aiNoData => 'Chưa có dữ liệu';

  @override
  String get aiNoDataHint =>
      'Hãy nhập giao dịch thực tế để hệ thống WCM-SPADE khai phá quy luật.';

  @override
  String get aiTrendTitle => 'Xu hướng chi tiêu';

  @override
  String get aiTopCategoryTitle => 'Chi nhiều nhất';

  @override
  String get aiSavingTipTitle => 'Mẹo tiết kiệm';

  @override
  String get aiWeekCompareTitle => 'So sánh tuần';

  @override
  String get aiChartTitle => 'Biểu đồ thu chi tuần';

  @override
  String get aiNoWeekData => 'Chưa có dữ liệu tuần này.';

  @override
  String aiTopWeek(int week, String amount) {
    return 'Tuần $week có chi tiêu cao nhất: $amount.';
  }

  @override
  String get aiSafeToSpendTitle => 'Hôm nay tiêu được bao nhiêu?';

  @override
  String get aiSafeToSpendNoIncome =>
      'Thêm khoản thu tháng này để tính số tiền an toàn.';

  @override
  String aiPerDay(String amount) {
    return '$amount / ngày';
  }

  @override
  String aiDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Còn lại chia đều $days ngày.',
    );
    return '$_temp0';
  }

  @override
  String get aiOverSafe => 'Bạn đã chi vượt phần an toàn của tháng.';

  @override
  String aiSpentThisMonth(String amount) {
    return 'Tháng này bạn đã chi $amount.';
  }

  @override
  String aiTrendUp(String percent) {
    return 'Chi tiêu tháng này tăng $percent% so với tháng trước.';
  }

  @override
  String aiTrendDown(String percent) {
    return 'Chi tiêu tháng này giảm $percent% so với tháng trước.';
  }

  @override
  String get aiNoSpendingThisMonth => 'Chưa có chi tiêu tháng này.';

  @override
  String aiTopCategory(String category, String amount, String percent) {
    return '$category chiếm $amount ($percent% tổng chi).';
  }

  @override
  String aiSurplus(String amount) {
    return 'Đang dư $amount. Hãy lập mục tiêu!';
  }

  @override
  String get aiAddGoal => 'Thêm mục tiêu tiết kiệm để AI phân tích.';

  @override
  String get aiOnTrack =>
      'Bạn đang trong lộ trình tiết kiệm. Xem gợi ý phân bổ tiền bên dưới để đạt mục tiêu nhanh hơn!';

  @override
  String get aiSpadeTitle => 'Mẫu Chi Tiêu Tuần Tự';

  @override
  String get aiSpadeSubtitle => 'Hành vi chi tiêu tuần tự thường gặp của bạn';

  @override
  String get aiSpadeLoadFailedTitle => 'Không tải được phân tích';

  @override
  String get aiSpadeLoadFailedMessage =>
      'Kiểm tra kết nối rồi làm mới để thử lại.';

  @override
  String get aiSpadeNotEnoughTitle => 'Chưa đủ dữ liệu';

  @override
  String get aiSpadeNotEnoughMessage =>
      'Thêm ít nhất 3 giao dịch để xem mẫu chi tiêu tuần tự.';

  @override
  String aiSpadeDetail(String count, String support) {
    return 'Tần suất: $count lần  ·  Độ hỗ trợ (W-Sup): $support';
  }

  @override
  String get aiAdviceTitle => 'Gợi ý phân bổ tiền';

  @override
  String get aiAdviceSubtitle =>
      'Đề xuất cắt/giữ từng mục để đạt mục tiêu tiết kiệm';

  @override
  String aiAdvicePerMonth(String current, String suggested) {
    return '$current → $suggested / tháng';
  }

  @override
  String get aiGuardTitle => 'Cảnh báo thói quen tương lai';

  @override
  String get aiGuardSubtitle =>
      'AI dự đoán các khoản chi sắp tới dựa trên lịch sử tuần tự của bạn.';

  @override
  String get aiGuardHeading => 'Dự báo hành vi · Khai phá chuỗi';

  @override
  String aiGuardRule(String from, String to) {
    return 'Thuật toán WCM-SPADE phát hiện luật [$from → $to]: Sau khi chi tiền cho $from, bạn có xu hướng sẽ chi cho $to trong vài ngày tới. Hãy chú ý kiểm soát hầu bao để không lạm lẹm vào khoản tiết kiệm!';
  }

  @override
  String get ai503020Title => 'Sức khỏe chi tiêu — quy tắc 50/30/20';

  @override
  String get ai503020Groups =>
      'Thiết yếu: Ăn uống, Di chuyển, Siêu thị, Sinh hoạt · Mong muốn: Giải trí, Khác';

  @override
  String get ai503020Needs => 'Thiết yếu';

  @override
  String get ai503020Wants => 'Mong muốn';

  @override
  String get ai503020Savings => 'Tiết kiệm (phần dư)';

  @override
  String get ai503020OnTrack =>
      'Cơ cấu chi tiêu tháng này đạt chuẩn 50/30/20. Giữ nhịp này!';

  @override
  String ai503020NeedsHigh(String percent) {
    return 'Nhóm thiết yếu đang chiếm $percent% thu nhập (chuẩn ≤50%). Rà lại Sinh hoạt/Siêu thị xem có khoản nào dồn được.';
  }

  @override
  String ai503020WantsHigh(String percent) {
    return 'Nhóm mong muốn (Giải trí, Khác) chiếm $percent% thu nhập (chuẩn ≤30%) — đây là chỗ dễ cắt nhất.';
  }

  @override
  String ai503020SavingsLow(String percent) {
    return 'Bạn mới để dành được $percent% thu nhập (chuẩn ≥20%). Tăng dần mỗi tháng một chút.';
  }
}
