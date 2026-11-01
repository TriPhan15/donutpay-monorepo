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
  String get notificationsEmptyHint =>
      'Cảnh báo ngân sách, giao dịch và hóa đơn sẽ hiện ở đây.';

  @override
  String notificationsYesterdayAt(String time) {
    return 'Hôm qua, $time';
  }

  @override
  String get notificationDetailTitle => 'Chi tiết thông báo';

  @override
  String get notificationDetailType => 'Loại';

  @override
  String get notificationDetailTime => 'Thời gian';

  @override
  String get sessionEnded =>
      'Phiên đăng nhập đã kết thúc, có thể do mật khẩu vừa được thay đổi. Vui lòng đăng nhập lại.';

  @override
  String get dialogGotIt => 'Đã hiểu';

  @override
  String get forgotPasswordTitle => 'Quên mật khẩu';

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
  String get forgotPasswordRemembered => 'Nhớ ra rồi? ';

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
  String resetPasswordDescription(String email) {
    return 'Nhập mã OTP đã được gửi tới $email, sau đó đặt mật khẩu mới.';
  }

  @override
  String get resetPasswordOtpLabel => 'Mã OTP';

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
  String get scanSheetSubtitle => 'Chọn cách đưa hóa đơn vào';

  @override
  String get scanOptionCamera => 'Quét bằng camera';

  @override
  String get scanOptionCameraHint => 'Một hóa đơn, kiểm tra và lưu ngay';

  @override
  String get scanOptionGallery => 'Chọn từ thư viện';

  @override
  String get scanOptionGalleryHint => 'Một ảnh có sẵn trong máy';

  @override
  String get scanOptionBatch => 'Quét nhiều';

  @override
  String get scanOptionBatchHint => 'Chụp liên tục, AI đọc dần ở nền';

  @override
  String get scanOptionBatchGallery => 'Chọn nhiều ảnh';

  @override
  String get scanOptionBatchGalleryHint => 'Nhiều ảnh cùng lúc, xác nhận sau';

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
  String get dialogDone => 'Xong';

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
  String currencyThousandShort(String amount) {
    return '${amount}k';
  }

  @override
  String currencyMillionShort(String amount) {
    return '$amount tr';
  }

  @override
  String currencyBillionShort(String amount) {
    return '$amount tỷ';
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
  String get registerHaveAccount => 'Đã có tài khoản? ';

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
  String get accountInfoTitle => 'Thông tin tài khoản';

  @override
  String get accountInfoSignInAgain => 'Vui lòng đăng nhập lại.';

  @override
  String get accountSecurityTitle => 'Bảo mật';

  @override
  String get accountEmailLocked => 'Email dùng để đăng nhập, không đổi được';

  @override
  String get accountEditNameTitle => 'Sửa họ và tên';

  @override
  String get accountEditPhoneTitle => 'Sửa số điện thoại';

  @override
  String get accountPhoneRequired => 'Vui lòng nhập số điện thoại.';

  @override
  String get changePasswordDoneMessage =>
      'Mật khẩu mới đã được áp dụng. Các thiết bị khác cần đăng nhập lại.';

  @override
  String get changePasswordMatches => 'Khớp với mật khẩu mới';

  @override
  String get userInfoTitle => 'Thông tin cá nhân';

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
  String get feedbackTitle => 'Đánh giá ứng dụng';

  @override
  String get feedbackHint => 'Nhập cảm nhận hoặc góp ý...';

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
  String get appearanceLanguageTitle => 'Giao diện và ngôn ngữ';

  @override
  String get themeCardSystem => 'Hệ thống';

  @override
  String languageConfirmTitle(String language) {
    return 'Đổi sang $language?';
  }

  @override
  String get languageConfirmMessage =>
      'Toàn bộ chữ trong ứng dụng sẽ đổi sang ngôn ngữ này.';

  @override
  String get languageConfirmAction => 'Đổi';

  @override
  String get notificationSettingsPushDescription =>
      'Nhận thông báo trên điện thoại';

  @override
  String get notificationSettingsBudgetAlertDescription =>
      'Báo khi chi tới 80% và khi vượt hạn mức';

  @override
  String get moneySourcesTotal => 'Tổng';

  @override
  String get securityChangePasswordDescription =>
      'Đổi xong, thiết bị khác phải đăng nhập lại';

  @override
  String get guideHomeTitle => 'Trang chủ';

  @override
  String get guideHomeBody =>
      'Xem số dư, thu chi tháng, ngân sách và các giao dịch gần đây.';

  @override
  String get guideStatsTitle => 'Thống kê';

  @override
  String get guideStatsBody =>
      'Xem chi tiêu theo biểu đồ, lịch tháng và danh mục; lọc và xuất Excel.';

  @override
  String get guideScanTitle => 'Quét hóa đơn';

  @override
  String get guideScanBody =>
      'Nhấn nút tròn giữa thanh dưới, chụp hoặc chọn ảnh hóa đơn. AI đọc tên cửa hàng, ngày và tổng tiền để bạn kiểm tra rồi lưu.';

  @override
  String get guideAnalysisTitle => 'Phân tích chi tiêu';

  @override
  String get guideAnalysisBody =>
      'Xem số tiền tiêu được mỗi ngày, điểm nổi bật, thói quen chi tiêu và gợi ý cân đối.';

  @override
  String get guideBudgetSavingsTitle => 'Ngân sách và tiết kiệm';

  @override
  String get guideBudgetSavingsBody =>
      'Đặt hạn mức chi theo danh mục và theo dõi các mục tiêu tiết kiệm.';

  @override
  String get feedbackChipEasy => 'Dễ dùng';

  @override
  String get feedbackChipScan => 'Quét hóa đơn chính xác';

  @override
  String get feedbackChipLooks => 'Giao diện đẹp';

  @override
  String get feedbackChipMore => 'Cần thêm tính năng';

  @override
  String feedbackStarLabel(int count) {
    return '$count trên 5 sao';
  }

  @override
  String get aboutVersion => 'Phiên bản';

  @override
  String get aboutDeveloper => 'Phát triển';

  @override
  String get aboutDeveloperValue => 'Nhóm 7';

  @override
  String get aboutSchool => 'Trường';

  @override
  String get aboutSchoolValue => 'HUIT';

  @override
  String get aboutLicenses => 'Giấy phép mã nguồn mở';

  @override
  String get savingsTitle => 'Sổ tiết kiệm';

  @override
  String savingsDeleteFailed(String reason) {
    return 'Không xóa được mục tiêu. $reason';
  }

  @override
  String savingsDeleted(String title) {
    return 'Đã xóa mục tiêu: $title';
  }

  @override
  String savingsDeletedRefunded(String title, String amount) {
    return 'Đã xóa mục tiêu: $title. $amount đã được hoàn vào ví.';
  }

  @override
  String get savingsDeleteTitle => 'Xóa mục tiêu';

  @override
  String get savingsDeleteConfirm => 'Xóa mục tiêu này?';

  @override
  String savingsDeleteConfirmRefund(String amount) {
    return 'Xóa mục tiêu này? $amount đã góp sẽ được hoàn vào ví.';
  }

  @override
  String get savingsGoalName => 'Tên mục tiêu';

  @override
  String get ledgerSavingsManagedByGoal =>
      'Khoản góp tiết kiệm được quản lý ở mục Tiết kiệm.';

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
  String get commonSessionExpiredTitle => 'Phiên đăng nhập hết hạn';

  @override
  String get commonInvalidAmountTitle => 'Số tiền không hợp lệ';

  @override
  String get currencySymbol => 'đ';

  @override
  String get transactionSaveFailed =>
      'Không lưu được giao dịch. Vui lòng thử lại.';

  @override
  String get transactionNotSentTitle => 'Chưa gửi được lên máy chủ';

  @override
  String get transactionNotSentMessage =>
      'Giao dịch đã được lưu trên thiết bị nhưng chưa gửi được lên máy chủ. Khi có mạng, mở Thống kê, chọn giao dịch và bấm \"Gửi lại\". Gửi lại sẽ không tạo giao dịch trùng.';

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
  String get addTransactionNoteHint => 'VD: Mua cafe Highlands';

  @override
  String get addTransactionSaved => 'Đã thêm giao dịch mới.';

  @override
  String get categoryMoreTile => 'Khác';

  @override
  String get transactionTabExpense => 'Chi tiêu';

  @override
  String get transactionTabIncome => 'Thu nhập';

  @override
  String get addTransactionManualTab => 'Nhập tay';

  @override
  String get addTransactionScanTab => 'Quét hóa đơn';

  @override
  String get addTransactionSubmitExpense => 'Thêm giao dịch chi';

  @override
  String get addTransactionSubmitIncome => 'Thêm giao dịch thu';

  @override
  String get addTransactionDiscardTitle => 'Bỏ giao dịch đang nhập?';

  @override
  String get addTransactionDiscardMessage =>
      'Số tiền và ghi chú vừa nhập sẽ không được lưu.';

  @override
  String get addTransactionDiscardConfirm => 'Bỏ và quét';

  @override
  String editTransactionSummaryLine(String kind, String time) {
    return '$kind, $time';
  }

  @override
  String get editTransactionTitle => 'Sửa giao dịch';

  @override
  String get editTransactionNoServerIdTitle => 'Không sửa được giao dịch';

  @override
  String get editTransactionNoServerIdMessage =>
      'Giao dịch này chưa có mã trên máy chủ.';

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
  String get ledgerTitle => 'Thống kê';

  @override
  String get ledgerSearchHint => 'Tìm tên, danh mục...';

  @override
  String get ledgerLegendIncome => 'Thu';

  @override
  String get ledgerLegendExpense => 'Chi';

  @override
  String ledgerChartMonth(String month) {
    return 'Th$month';
  }

  @override
  String get ledgerEmptyPeriod => 'Không có giao dịch trong kỳ này.';

  @override
  String get ledgerBalance => 'Số dư';

  @override
  String get ledgerDetailUnsyncedHint =>
      'Giao dịch chưa được máy chủ xác nhận. Khi đã có mạng, bấm \"Gửi lại\". Gửi lại sẽ không tạo giao dịch trùng.';

  @override
  String get ledgerResend => 'Gửi lại';

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
  String get ledgerDeleteWhileSending =>
      'Giao dịch đang được gửi, hãy thử lại sau ít phút.';

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
  String reviewPhotoUploadFailedToast(String reason) {
    return 'Không tải được ảnh: $reason';
  }

  @override
  String get reviewPhotoRejected => 'Ảnh quá lớn hoặc không đúng định dạng.';

  @override
  String get reviewSaveWithoutPhoto => 'Lưu không kèm ảnh';

  @override
  String get reviewLater => 'Để sau';

  @override
  String get reviewSaved => 'Đã lưu giao dịch từ hóa đơn.';

  @override
  String get reviewStepPhoto => 'Ảnh';

  @override
  String get reviewStepCheck => 'Kiểm tra';

  @override
  String get reviewStepSave => 'Lưu';

  @override
  String get reviewZoom => 'Phóng to';

  @override
  String get reviewCompare => 'Đối chiếu';

  @override
  String get reviewNeedsCheck => 'Cần kiểm tra';

  @override
  String get reviewStoreHint => 'Chưa chắc tên cửa hàng, hãy sửa nếu sai.';

  @override
  String get reviewTotalHint => 'Chưa chắc tổng tiền, hãy so với ảnh.';

  @override
  String get reviewDateHint =>
      'Chưa đọc được ngày, hãy chọn lại nếu không phải hôm nay.';

  @override
  String get reviewTotal => 'Tổng tiền';

  @override
  String get reviewDateDoubtHint => 'Chưa chắc ngày, hãy so với ảnh.';

  @override
  String get reviewSaveAndScan => 'Lưu & quét tiếp';

  @override
  String get reviewSave => 'Lưu';

  @override
  String get reviewAnalyzing => 'Đang phân tích hóa đơn...';

  @override
  String get reviewPleaseWait => 'Vui lòng đợi trong giây lát';

  @override
  String get reviewStoreName => 'Tên cửa hàng';

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
  String get linkedSync => 'Đồng bộ';

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
  String get linkedWalletsDescription =>
      'Đồng bộ tiền từ ví vào ngân sách để quản lý chi tiêu.';

  @override
  String get linkedLinked => 'Đã liên kết';

  @override
  String linkedSyncingFrom(String amount, String wallet) {
    return 'Đang đồng bộ $amount từ $wallet… hoàn tất thanh toán trên cổng.';
  }

  @override
  String get linkedSheetTitle => 'Đồng bộ tiền';

  @override
  String linkedSheetFrom(String wallet) {
    return 'Từ $wallet';
  }

  @override
  String get linkedSheetTarget => 'Vào ngân sách chi tiêu';

  @override
  String get linkedAmountLabel => 'Số tiền nạp';

  @override
  String linkedMinAmountHint(String amount, String wallet) {
    return 'Tối thiểu $amount. Bạn sẽ được chuyển sang cổng $wallet để thanh toán.';
  }

  @override
  String linkedMaxAmountHint(String amount) {
    return 'Tối đa $amount mỗi lần đồng bộ.';
  }

  @override
  String get linkedContinuePayment => 'Tiếp tục thanh toán';

  @override
  String get paymentOrderDetails => 'Chi tiết đơn';

  @override
  String get paymentDetailWallet => 'Ví';

  @override
  String get paymentDetailCode => 'Mã đơn';

  @override
  String get paymentDetailTime => 'Thời gian';

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
  String get budgetEmptyHint =>
      'Đặt hạn mức chi tiêu theo tuần hoặc tháng để kiểm soát tốt hơn.';

  @override
  String get budgetCreate => 'Thiết lập ngân sách';

  @override
  String get budgetEditTitle => 'Sửa ngân sách';

  @override
  String get budgetAmountLabel => 'Số tiền ngân sách (₫)';

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
  String get dashboardBalance => 'Số dư';

  @override
  String dashboardPendingNotInBalance(String amount) {
    return 'Chưa tính $amount của giao dịch đang chờ gửi';
  }

  @override
  String dashboardMonthIncome(String amount) {
    return 'Thu $amount';
  }

  @override
  String dashboardMonthExpense(String amount) {
    return 'Chi $amount';
  }

  @override
  String get dashboardShowAmounts => 'Hiện số tiền';

  @override
  String get dashboardHideAmounts => 'Ẩn số tiền';

  @override
  String get dashboardSavingsShort => 'Tiết kiệm';

  @override
  String homeBudgetLeft(String amount, int days) {
    return 'Còn $amount cho $days ngày';
  }

  @override
  String homeBudgetOver(String amount) {
    return 'Đã vượt $amount';
  }

  @override
  String homeBudgetCategoryOver(String category, String amount) {
    return '$category đã vượt $amount';
  }

  @override
  String homeBudgetCategoryNear(String category, int percent) {
    return '$category đã dùng $percent%';
  }

  @override
  String get homeBudgetView => 'Xem';

  @override
  String get homeBudgetEmptyTitle => 'Đặt ngân sách tháng này';

  @override
  String get homeBudgetEmptyHint => 'Biết mỗi ngày còn tiêu được bao nhiêu';

  @override
  String get homeBudgetSet => 'Đặt';

  @override
  String get homeBudgetFailed => 'Chưa tải được ngân sách';

  @override
  String get dashboardRecent => 'Gần đây';

  @override
  String get dashboardSeeAll => 'Xem tất cả';

  @override
  String get dashboardLoadFailedTitle => 'Chưa tải được trang chủ';

  @override
  String get dashboardLoadFailedMessage => 'Kiểm tra kết nối rồi thử lại.';

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
  String get aiTodayLabel => 'Hôm nay tiêu được';

  @override
  String aiTodayDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'còn $days ngày',
    );
    return '$_temp0';
  }

  @override
  String aiTodaySpent(String amount) {
    return 'Đã tiêu $amount';
  }

  @override
  String aiTodayLeft(String amount) {
    return 'Còn $amount hôm nay';
  }

  @override
  String aiTodayOver(String amount) {
    return 'Vượt $amount hôm nay';
  }

  @override
  String get aiHighlightsTitle => 'Điểm nổi bật';

  @override
  String get aiTrendVsLastMonth => 'So với cùng kỳ tháng trước';

  @override
  String aiTopCategoryLine(String category, String amount) {
    return '$category, $amount';
  }

  @override
  String get aiTipSurplus => 'Tháng này còn dư, hãy lập mục tiêu';

  @override
  String get aiTipNeedMore => 'Cần góp thêm cho mục tiêu tháng này';

  @override
  String get aiTipOnTrack => 'Đúng lộ trình tiết kiệm';

  @override
  String get aiTipOverspent => 'Đã góp đủ, nhưng tháng này chi vượt số thu';

  @override
  String aiWeekCompareLine(String thisWeek, String lastWeek) {
    return '$thisWeek / tuần trước $lastWeek';
  }

  @override
  String get aiWeekCompareNone => 'Hai tuần này chưa có khoản chi';

  @override
  String get aiTopWeekTitle => 'Tuần chi nhiều nhất';

  @override
  String aiTopWeekLine(int week) {
    return 'Tuần $week của tháng này';
  }

  @override
  String get aiDailyChartTitle => 'Chi tiêu theo ngày';

  @override
  String get aiPickRangeStart => 'Từ ngày';

  @override
  String get aiPickRangeEnd => 'Đến ngày';

  @override
  String get aiHabitsTitle => 'Thói quen chi tiêu';

  @override
  String aiHabitRepeat(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: 'Lặp lại trong $weeks tuần qua',
    );
    return '$_temp0';
  }

  @override
  String aiTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lần',
    );
    return '$_temp0';
  }

  @override
  String aiHabitEvery(String days) {
    return 'Khoảng $days ngày một lần';
  }

  @override
  String aiHabitLastOn(String date) {
    return 'Lần cuối $date';
  }

  @override
  String aiHabitUpcoming(String from, String to) {
    return 'Sắp tới: sau $from bạn hay chi $to.';
  }

  @override
  String aiHabitUsually(String from, String to) {
    return 'Thường thì sau $from bạn hay chi $to.';
  }

  @override
  String get aiBalanceTitle => 'Cân đối chi tiêu';

  @override
  String aiBalanceLine(int percent, int target) {
    return '$percent% thu nhập, nên khoảng $target%';
  }

  @override
  String get aiBalanceSavings => 'Tiết kiệm';

  @override
  String get aiLevelOk => 'Ổn';

  @override
  String get aiLevelHigh => 'Hơi cao';

  @override
  String get aiLevelLow => 'Hơi thấp';

  @override
  String aiAdviceLine(String category, String current, String suggested) {
    return '$category: $current → $suggested / tháng';
  }

  @override
  String get aiNoDataMessage =>
      'Thêm giao dịch để xem phân tích chi tiêu của bạn.';

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
  String get aiTrendTitle => 'Xu hướng chi tiêu';

  @override
  String get aiTopCategoryTitle => 'Chi nhiều nhất';

  @override
  String get aiSavingTipTitle => 'Mẹo tiết kiệm';

  @override
  String get aiWeekCompareTitle => 'So sánh tuần';

  @override
  String get aiSafeToSpendNoIncome =>
      'Thêm khoản thu tháng này để tính số tiền an toàn.';

  @override
  String get aiOverSafe => 'Bạn đã chi vượt phần an toàn của tháng.';

  @override
  String aiSpentThisMonth(String amount) {
    return 'Tháng này bạn đã chi $amount.';
  }

  @override
  String get aiNoSpendingThisMonth => 'Chưa có chi tiêu tháng này.';

  @override
  String get aiAddGoal => 'Thêm mục tiêu tiết kiệm để AI phân tích.';

  @override
  String get aiGoalNoDeadline => 'Mục tiêu chưa có hạn, góp lúc nào cũng được';

  @override
  String get aiGoalOverdue =>
      'Mục tiêu đã quá hạn, hãy cập nhật hạn mới hoặc tiếp tục góp';

  @override
  String get aiSpadeLoadFailedTitle => 'Không tải được phân tích';

  @override
  String get aiSpadeLoadFailedMessage =>
      'Kiểm tra kết nối rồi làm mới để thử lại.';

  @override
  String get aiSpadeNotEnoughTitle => 'Chưa đủ dữ liệu';

  @override
  String aiSpadeNotEnoughWeeks(int weeks, int minWeeks) {
    return 'Mới có $weeks tuần có chi tiêu; cần ít nhất $minWeeks tuần để tìm mẫu tuần tự.';
  }

  @override
  String get aiSpadeNotEnoughUnknown =>
      'Chưa đủ lịch sử chi tiêu để tìm mẫu tuần tự.';

  @override
  String get aiSpadeNotEnoughNone =>
      'Chưa có khoản chi nào trong 26 tuần gần đây.';

  @override
  String get aiSpadeNoPatternTitle => 'Chưa có mẫu nào';

  @override
  String get aiSpadeNoPatternMessage =>
      'Chưa có chuỗi chi tiêu nào lặp lại đủ nhiều tuần.';

  @override
  String get ai503020Needs => 'Thiết yếu';

  @override
  String get ai503020Wants => 'Mong muốn';

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

  @override
  String get dateFieldToday => 'Hôm nay';

  @override
  String get dateFieldYesterday => 'Hôm qua';

  @override
  String get dateFieldPick => 'Chọn ngày';

  @override
  String get dashboardScanReceipt => 'Quét hóa đơn';

  @override
  String get reviewOpenImage => 'Xem ảnh hóa đơn';

  @override
  String get reviewCompareOn => 'Đối chiếu với ảnh';

  @override
  String get reviewCompareOff => 'Thoát chế độ đối chiếu';

  @override
  String reviewOtherMonthBalanceNote(String day) {
    return 'Giao dịch ngày $day vẫn được tính vào số dư hiện tại';
  }

  @override
  String reviewDuplicateTitle(String date) {
    return 'Hóa đơn này có vẻ đã lưu ngày $date';
  }

  @override
  String get reviewDuplicateTitleNoDate =>
      'Hóa đơn này có vẻ đã được lưu trước đó';

  @override
  String get reviewDuplicateMessage =>
      'Mở bản đã lưu để kiểm tra, hoặc vẫn lưu nếu đây là một lần mua khác.';

  @override
  String get reviewDuplicateView => 'Xem bản đã lưu';

  @override
  String get reviewDuplicateSaveAnyway => 'Vẫn lưu';

  @override
  String get reviewDuplicateCannotOpen =>
      'Không mở được bản đã lưu từ đây. Bạn có thể tìm nó ở tab Thống kê.';

  @override
  String get linkedDemoBadge => 'Bản demo';

  @override
  String get linkedDemoNotice =>
      'Đây là bản demo: ví và giao dịch đồng bộ là dữ liệu giả lập, không kết nối ngân hàng hay ví điện tử thật.';

  @override
  String get budgetPeriodYear => 'Năm';

  @override
  String get periodThisYear => 'Năm nay';

  @override
  String get budgetCustomCategoryLabel => 'Tên danh mục';

  @override
  String get budgetCustomCategoryHelper =>
      'Danh mục chưa có sẽ được tạo mới. Ghi giao dịch với đúng tên này để tính vào ngân sách';

  @override
  String get budgetCustomCategoryRequired => 'Nhập tên danh mục';

  @override
  String budgetCustomCategoryTooLong(int max) {
    return 'Tối đa $max ký tự';
  }

  @override
  String get budgetGroupOver => 'Đang vượt';

  @override
  String get budgetGroupWithin => 'Trong mức';

  @override
  String budgetGroupCount(int count) {
    return '$count ngân sách';
  }

  @override
  String budgetLeft(String amount) {
    return 'Còn $amount';
  }

  @override
  String budgetOver(String amount) {
    return 'Vượt $amount';
  }

  @override
  String budgetAmounts(String spent, String limit) {
    return '$spent / $limit';
  }

  @override
  String get budgetEmptyPeriod => 'Chưa có ngân sách cho kỳ này';

  @override
  String ledgerYearLabel(String year) {
    return 'Năm $year';
  }

  @override
  String get categorySavings => 'Tiết kiệm';

  @override
  String get savingsTargetDateClear => 'Bỏ ngày đạt mục tiêu';

  @override
  String get savingsContribute => 'Góp tiền';

  @override
  String savingsContributeFailed(String reason) {
    return 'Không góp được tiền. $reason';
  }

  @override
  String get savingsContributeRejected => 'Kiểm tra lại số tiền và số dư ví.';

  @override
  String savingsContributed(String title) {
    return 'Đã góp tiền vào \"$title\"';
  }

  @override
  String savingsGoalReached(String title) {
    return 'Chúc mừng! Bạn đã đạt mục tiêu \"$title\"';
  }

  @override
  String scanQueueAdded(int count) {
    return 'Đã thêm $count hóa đơn vào hàng chờ';
  }

  @override
  String scanQueueOverLimit(int count, int skipped, int limit) {
    return 'Đã thêm $count hóa đơn vào hàng chờ (bỏ $skipped ảnh vì quá $limit)';
  }

  @override
  String scanQueueReading(int current, int total) {
    return 'Đang đọc hóa đơn $current/$total';
  }

  @override
  String scanQueueReady(int count) {
    return '$count hóa đơn chờ xác nhận';
  }

  @override
  String scanQueueFailed(int count) {
    return '$count hóa đơn đọc lỗi';
  }

  @override
  String get scanQueueStorageFailed =>
      'Không cập nhật được hàng chờ hóa đơn trên máy. Vui lòng thử lại.';

  @override
  String get pendingReceiptsTitle => 'Chờ xác nhận';

  @override
  String get pendingReceiptsEmpty => 'Không có hóa đơn nào đang chờ.';

  @override
  String get pendingStatusQueued => 'Đang chờ';

  @override
  String get pendingStatusReading => 'Đang đọc';

  @override
  String get pendingStatusFailed => 'Lỗi';

  @override
  String get pendingRetry => 'Đọc lại';

  @override
  String get pendingDiscard => 'Bỏ';

  @override
  String get pendingDiscardConfirm => 'Bỏ hóa đơn này khỏi danh sách?';

  @override
  String pendingConfirmAllAsk(int count) {
    return 'Lưu $count hóa đơn hợp lệ thành giao dịch?';
  }

  @override
  String pendingConfirmAllResult(int saved, int duplicates, int notSaved) {
    return 'Đã lưu $saved, trùng $duplicates, chưa lưu $notSaved';
  }

  @override
  String get pendingErrorNetwork => 'Không kết nối được dịch vụ AI.';

  @override
  String get pendingErrorServer => 'Dịch vụ AI không đọc được hóa đơn này.';

  @override
  String get pendingErrorMissingImage => 'Ảnh không còn trên máy.';

  @override
  String pendingGroupReady(int count) {
    return 'Sẵn sàng $count';
  }

  @override
  String pendingGroupProcessing(int count) {
    return 'Đang xử lý $count';
  }

  @override
  String pendingTabReading(int count) {
    return 'Đang đọc $count';
  }

  @override
  String pendingTabFailed(int count) {
    return 'Lỗi $count';
  }

  @override
  String get pendingReadingTitle => 'Đang đọc…';

  @override
  String pendingPhotoTitle(int index) {
    return 'Ảnh $index';
  }

  @override
  String get pendingQuickSave => 'Lưu';

  @override
  String get pendingReview => 'Kiểm tra';

  @override
  String pendingReadyFooter(int count) {
    return '$count hóa đơn sẵn sàng';
  }

  @override
  String pendingSelected(int count) {
    return 'Đã chọn $count';
  }

  @override
  String get pendingSelectAll => 'Chọn tất cả';

  @override
  String pendingSaveSelected(int count) {
    return 'Lưu $count hóa đơn đã chọn';
  }

  @override
  String get pendingConfirmAllShort => 'Xác nhận tất cả';

  @override
  String toastStackCount(int count) {
    return '$count thông báo · chạm để xem';
  }

  @override
  String get toastCollapse => 'Thu gọn';

  @override
  String get toastCloseAll => 'Đóng tất cả';

  @override
  String get toastDismiss => 'Đóng';

  @override
  String get toastJustNow => 'vừa xong';

  @override
  String toastSecondsAgo(int count) {
    return '$count giây trước';
  }

  @override
  String toastMinutesAgo(int count) {
    return '$count phút trước';
  }

  @override
  String get receiptViewerTitle => 'Ảnh hóa đơn';

  @override
  String get receiptViewerShare => 'Chia sẻ';

  @override
  String get receiptViewerShareFailed => 'Không chia sẻ được ảnh';

  @override
  String get datePickerTransactionTitle => 'Chọn ngày giao dịch';

  @override
  String get datePickerTitle => 'Chọn ngày';

  @override
  String get datePickerLastRecorded => 'Ngày vừa ghi';

  @override
  String datePickerMonthTitle(String month, String year, String monthName) {
    return 'Tháng $month, $year';
  }

  @override
  String get datePickerWeekdays => 'T2,T3,T4,T5,T6,T7,CN';

  @override
  String get datePickerPreviousMonth => 'Tháng trước';

  @override
  String get datePickerNextMonth => 'Tháng sau';

  @override
  String dateFieldTodayValue(String date) {
    return 'Hôm nay, $date';
  }

  @override
  String dateFieldYesterdayValue(String date) {
    return 'Hôm qua, $date';
  }

  @override
  String get filterTitle => 'Lọc';

  @override
  String get filterAll => 'Tất cả';

  @override
  String get filterExpense => 'Chi';

  @override
  String get filterIncome => 'Thu';

  @override
  String get filterAnyAmount => 'Mọi mức';

  @override
  String get filterUnder100k => '<100k';

  @override
  String get filter100kTo500k => '100–500k';

  @override
  String get filterOver500k => '>500k';

  @override
  String get filterNewest => 'Mới nhất';

  @override
  String get filterOldest => 'Cũ nhất';

  @override
  String get filterLargest => 'Lớn nhất';

  @override
  String get filterReset => 'Đặt lại';

  @override
  String filterShowCount(int count) {
    return 'Xem $count giao dịch';
  }

  @override
  String get transactionDetailTitle => 'Chi tiết giao dịch';

  @override
  String get transactionDetailCategory => 'Danh mục';

  @override
  String get transactionDetailTime => 'Thời gian';

  @override
  String get transactionDetailReceipt => 'Hóa đơn';

  @override
  String get transactionDetailSync => 'Đồng bộ';

  @override
  String get transactionDetailReceiptImage => 'Ảnh hóa đơn';

  @override
  String get transactionDetailDelete => 'Xóa';

  @override
  String statsIncome(String amount) {
    return 'Thu $amount';
  }

  @override
  String statsExpense(String amount) {
    return 'Chi $amount';
  }

  @override
  String statsLeft(String amount) {
    return 'Còn $amount';
  }

  @override
  String get statsViewChart => 'Biểu đồ';

  @override
  String get statsViewCalendar => 'Lịch';

  @override
  String get statsViewCategories => 'Danh mục';

  @override
  String statsMonthLabel(String month, String year) {
    return 'Tháng $month/$year';
  }

  @override
  String get statsSearch => 'Tìm giao dịch';

  @override
  String get statsExport => 'Xuất Excel';

  @override
  String get statsPickDate => 'Chọn ngày';

  @override
  String get statsAdd => '+ Thêm';

  @override
  String get statsTapBarHint => 'Chạm cột để xem số';

  @override
  String get statsSpent => 'đã chi';

  @override
  String statsCategoryLine(int percent, int count) {
    return '$percent%, $count lần';
  }

  @override
  String get statsByCategory => 'Theo danh mục';

  @override
  String get statsNoSpending => 'Chưa có khoản chi trong kỳ này';

  @override
  String get statsTransactions => 'Giao dịch';

  @override
  String statsTransactionsOfDay(String date) {
    return 'Giao dịch ngày $date';
  }

  @override
  String statsTotalIncome(String amount) {
    return 'Tổng thu $amount';
  }

  @override
  String statsTotalExpense(String amount) {
    return 'Tổng chi $amount';
  }

  @override
  String get statsNoMatch => 'Không có giao dịch khớp bộ lọc';

  @override
  String get statsCategoriesFilterHint =>
      'Lọc và tìm kiếm chỉ áp dụng cho danh sách giao dịch ở Biểu đồ và Lịch.';

  @override
  String get savingsTabActive => 'Đang thực hiện';

  @override
  String get savingsTabDone => 'Đã xong';

  @override
  String get savingsMissing => 'Còn thiếu';

  @override
  String savingsDaysLeft(int days, String date) {
    return 'Còn $days ngày · $date';
  }

  @override
  String savingsDueToday(String date) {
    return 'Hạn hôm nay · $date';
  }

  @override
  String savingsOverdue(String date) {
    return 'Quá hạn · $date';
  }

  @override
  String get savingsNoDeadline => 'Không đặt hạn';

  @override
  String get savingsReached => 'Đã đạt mục tiêu';

  @override
  String get savingsEmptyActiveTitle => 'Chưa có mục tiêu đang thực hiện';

  @override
  String get savingsEmptyActiveHint => 'Nhấn + để tạo mục tiêu tiết kiệm.';

  @override
  String get savingsEmptyDoneTitle => 'Chưa có mục tiêu đã xong';

  @override
  String get savingsEmptyDoneHint => 'Mục tiêu góp đủ tiền sẽ hiện ở đây.';

  @override
  String get savingsLoadFailedTitle => 'Không tải được sổ tiết kiệm';

  @override
  String get savingsCreate => 'Thêm mục tiêu';

  @override
  String get savingsEditGoal => 'Sửa mục tiêu';

  @override
  String get savingsFormGoalCard => 'Mục tiêu';

  @override
  String get savingsFormDeadlineCard => 'Thời hạn';

  @override
  String get savingsTargetAmountLabel => 'Số tiền mục tiêu';

  @override
  String get savingsSavedLabel => 'Đã tiết kiệm';

  @override
  String get savingsSavedHint => 'Chỉ thay đổi qua Góp tiền.';

  @override
  String get savingsDeadlineLabel => 'Ngày đạt mục tiêu (không bắt buộc)';

  @override
  String get savingsDeadlinePick => 'Chọn ngày';

  @override
  String get savingsSaveGoal => 'Lưu mục tiêu';

  @override
  String savingsCreated(String title) {
    return 'Đã thêm mục tiêu: $title';
  }

  @override
  String savingsUpdated(String title) {
    return 'Đã lưu mục tiêu: $title';
  }

  @override
  String get savingsSaveFailedTitle => 'Không lưu được mục tiêu';

  @override
  String get savingsContributeAmountLabel => 'Số tiền góp';

  @override
  String savingsContributeAddition(String saved, String added) {
    return '$saved + $added =';
  }

  @override
  String savingsAmountsOf(String saved, String target) {
    return '$saved / $target';
  }

  @override
  String get savingsSuggestedBadge => 'Gợi ý';

  @override
  String savingsSuggestionHint(String amount, String date) {
    return 'Gợi ý: góp $amount mỗi tháng để kịp hạn $date.';
  }

  @override
  String savingsWalletLine(String balance) {
    return 'Trừ từ ví (số dư $balance) và ghi thành khoản chi \"Tiết kiệm\".';
  }

  @override
  String get savingsWalletLineNoBalance =>
      'Trừ từ ví và ghi thành khoản chi \"Tiết kiệm\".';

  @override
  String savingsContributeButton(String amount) {
    return 'Góp $amount';
  }

  @override
  String savingsReloadFailed(String reason) {
    return 'Không tải lại được sổ tiết kiệm. $reason';
  }

  @override
  String get savingsNoTarget => 'Chưa đặt số tiền';

  @override
  String savingsOverfillHint(String missing) {
    return 'Mục tiêu chỉ còn thiếu $missing. Phần dư vẫn được góp vào mục tiêu.';
  }

  @override
  String get receiptDetailTitle => 'Hóa đơn';

  @override
  String get receiptDetailStatus => 'Trạng thái';

  @override
  String get receiptDetailVendor => 'Cửa hàng';

  @override
  String get receiptDetailTotal => 'Tổng tiền';

  @override
  String get receiptDetailDate => 'Ngày';

  @override
  String get receiptDetailNoValue => 'Chưa có';

  @override
  String get receiptDetailStatusPending => 'Chờ đọc';

  @override
  String get receiptDetailStatusProcessing => 'Đang xử lý';

  @override
  String get receiptDetailStatusCompleted => 'AI đã đọc';

  @override
  String get receiptDetailStatusEdited => 'Bạn đã sửa';

  @override
  String get receiptDetailStatusFailed => 'Chưa đọc được';

  @override
  String get receiptDetailStatusWaitingForReview => 'Chờ quản trị viên duyệt';

  @override
  String get receiptDetailStatusApproved => 'Đã được duyệt';

  @override
  String get receiptDetailStatusCanceled => 'Đã hủy';

  @override
  String get receiptDetailStatusUnknown => 'Không rõ';

  @override
  String get receiptDetailFailedTitle => 'Chưa đọc được hóa đơn này';

  @override
  String get receiptDetailEdit => 'Sửa thông tin';

  @override
  String get receiptDetailRetry => 'Đọc lại';

  @override
  String get receiptDetailSendAmount => 'Gửi số tiền đúng';

  @override
  String get receiptDetailEditHint =>
      'Giao dịch và số dư chỉ đổi sau khi quản trị viên duyệt.';

  @override
  String get receiptDetailSendAmountHint =>
      'Nhập đúng tổng tiền trên hóa đơn. Quản trị viên sẽ kiểm tra rồi mới cập nhật giao dịch.';

  @override
  String get receiptDetailSend => 'Gửi';

  @override
  String get receiptDetailEdited => 'Đã cập nhật hóa đơn';

  @override
  String get receiptDetailRetried => 'Đã đọc lại hóa đơn';

  @override
  String get receiptDetailRetryStillFailed => 'Vẫn chưa đọc được tổng tiền';

  @override
  String get receiptDetailAmountSent => 'Đã gửi quản trị viên duyệt';

  @override
  String get receiptDetailLoadFailedTitle => 'Không tải được hóa đơn';

  @override
  String get receiptDetailConflict =>
      'Hóa đơn đã thay đổi. Đã tải lại, bạn kiểm tra rồi thử lại nhé.';

  @override
  String get receiptDetailPhotoFailed =>
      'Không tải được ảnh hóa đơn để đọc lại.';
}
