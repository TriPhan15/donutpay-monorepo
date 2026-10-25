// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get dark => 'Dark';

  @override
  String get light => 'Light';

  @override
  String get system => 'System';

  @override
  String get systemThemeDescription => 'Follows your device setting';

  @override
  String get english => 'English';

  @override
  String get vietnamese => 'Tiếng Việt';

  @override
  String get settingsSaveFailed =>
      'Couldn\'t save this setting. The change applies until you close the app.';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsMarkAllRead => 'Mark all as read';

  @override
  String get notificationsEmpty => 'You have no notifications yet.';

  @override
  String get notificationsLoadFailed => 'Couldn\'t load your notifications.';

  @override
  String get notificationsLoadMoreFailed =>
      'Couldn\'t load more notifications.';

  @override
  String get notificationsRetry => 'Try again';

  @override
  String get notificationsMarkReadFailed =>
      'Couldn\'t mark the notification as read. Please try again.';

  @override
  String get notificationsMarkAllReadFailed =>
      'Couldn\'t mark your notifications as read. Please try again.';

  @override
  String get notificationsDetailUnavailable =>
      'This notification can\'t be opened yet.';

  @override
  String get notificationsUnread => 'Unread';

  @override
  String get notificationTypeBudgetWarning => 'Budget almost used up';

  @override
  String get notificationTypeBudgetExceeded => 'Budget exceeded';

  @override
  String get notificationTypeTransactionAlert => 'Transaction alert';

  @override
  String get notificationTypeReceiptProcessed => 'Receipt processed';

  @override
  String get notificationTypeOther => 'Notification';

  @override
  String get sessionEnded =>
      'Your session has ended, for example because your password was changed. Please sign in again.';

  @override
  String get dialogGotIt => 'Got it';

  @override
  String get forgotPasswordTitle => 'Forgot password';

  @override
  String get forgotPasswordHeading => 'Get a verification code';

  @override
  String get forgotPasswordDescription =>
      'Enter the email of your account. We\'ll send you a one-time code (OTP) to set a new password.';

  @override
  String get forgotPasswordEmailLabel => 'Email';

  @override
  String get forgotPasswordEmailHint => 'Enter your email address';

  @override
  String get forgotPasswordEmailRequired => 'Please enter your email.';

  @override
  String get forgotPasswordEmailInvalid =>
      'Please enter a valid email address.';

  @override
  String get forgotPasswordSendOtp => 'Send code';

  @override
  String get forgotPasswordSendFailed => 'Couldn\'t send the code';

  @override
  String get forgotPasswordRejected =>
      'The code couldn\'t be sent. Please check the email and try again.';

  @override
  String get resetPasswordTitle => 'Reset password';

  @override
  String get resetPasswordHeading => 'Create a new password';

  @override
  String resetPasswordDescription(String email) {
    return 'Enter the code we sent to $email, then choose a new password.';
  }

  @override
  String get resetPasswordOtpLabel => 'Verification code (OTP)';

  @override
  String resetPasswordOtpHint(int length) {
    return '$length-digit code';
  }

  @override
  String get resetPasswordOtpRequired => 'Please enter the code.';

  @override
  String resetPasswordOtpInvalid(int length) {
    return 'The code must be exactly $length digits.';
  }

  @override
  String get resetPasswordResendOtp => 'Resend code';

  @override
  String resetPasswordResendIn(int seconds) {
    return 'Resend code in ${seconds}s';
  }

  @override
  String get resetPasswordOtpResent =>
      'A new code has been sent. Please check your email.';

  @override
  String get resetPasswordNewPasswordLabel => 'New password';

  @override
  String get resetPasswordNewPasswordHint => 'Enter a new password';

  @override
  String get resetPasswordPasswordRequired => 'Please enter a new password.';

  @override
  String resetPasswordPasswordPolicy(int min, int max) {
    return '$min to $max characters, with at least one letter and one digit.';
  }

  @override
  String get resetPasswordConfirmPasswordLabel => 'Confirm new password';

  @override
  String get resetPasswordConfirmPasswordHint => 'Enter the new password again';

  @override
  String get resetPasswordConfirmRequired => 'Please confirm the new password.';

  @override
  String get resetPasswordMismatch => 'The passwords don\'t match.';

  @override
  String get resetPasswordSubmit => 'Reset password';

  @override
  String get resetPasswordSubmitting => 'Processing...';

  @override
  String get resetPasswordSuccessTitle => 'Password reset';

  @override
  String get resetPasswordSuccessMessage =>
      'Your password has been changed. Please sign in with your new password.';

  @override
  String get resetPasswordBackToLogin => 'Back to sign in';

  @override
  String get resetPasswordFailed => 'Couldn\'t reset your password';

  @override
  String get resetPasswordRejected =>
      'Your password couldn\'t be reset. Please check the code and try again.';

  @override
  String get passwordShow => 'Show password';

  @override
  String get passwordHide => 'Hide password';

  @override
  String get passwordRecoverySending => 'Sending...';

  @override
  String get passwordRecoveryNetworkError =>
      'Can\'t reach the server. Please check your connection and try again.';

  @override
  String get passwordRecoveryTimeout =>
      'The server is taking too long to respond. Please try again.';

  @override
  String get passwordRecoveryServerError =>
      'The server ran into a problem. Please try again later.';

  @override
  String get passwordRecoveryUnexpectedError =>
      'Something went wrong. Please try again.';

  @override
  String get navHome => 'Home';

  @override
  String get navLedger => 'Statistics';

  @override
  String get navAi => 'AI';

  @override
  String get navProfile => 'Profile';

  @override
  String get scanSheetTitle => 'Scan a receipt with AI';

  @override
  String get scanWithAi => 'AI scan';

  @override
  String get scanFromGallery => 'From gallery';

  @override
  String get scanScannerFailedTitle => 'Couldn\'t open the scanner';

  @override
  String get scanScannerFailedMessage =>
      'Please try again or pick a photo from the gallery.';

  @override
  String get scanGalleryFailedTitle => 'Couldn\'t open the photo gallery';

  @override
  String get scanGalleryFailedMessage =>
      'Please check the app\'s photo access and try again.';

  @override
  String get dialogOk => 'OK';

  @override
  String get dialogConfirm => 'Confirm';

  @override
  String get dialogCancel => 'Cancel';

  @override
  String get errorNetwork =>
      'Can\'t reach the server. Please check your connection and try again.';

  @override
  String get errorTimeout =>
      'The server is taking too long to respond. Please try again.';

  @override
  String get errorServer =>
      'The server ran into a problem. Please try again later.';

  @override
  String get errorSessionExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get errorUnexpected => 'Something went wrong. Please try again.';

  @override
  String get transactionRefused =>
      'The server refused this transaction. Please check the details.';

  @override
  String get defaultUserName => 'User';

  @override
  String get mainWalletName => 'Main wallet';

  @override
  String get syncStatusPending => 'Waiting to send';

  @override
  String get syncStatusSynced => 'Synced';

  @override
  String get syncStatusError => 'Send failed';

  @override
  String get receiptStatusProcessing => 'Processing';

  @override
  String get receiptStatusSuccess => 'Completed';

  @override
  String get receiptStatusFailed => 'Failed · confirm again';

  @override
  String get budgetPeriodWeek => 'Week';

  @override
  String get budgetPeriodMonth => 'Month';

  @override
  String get budgetAllCategories => 'All categories';

  @override
  String dateTodayAt(String time) {
    return 'Today, $time';
  }

  @override
  String dateYesterdayAt(String time) {
    return 'Yesterday, $time';
  }

  @override
  String get passwordEmpty => 'Password can\'t be empty.';

  @override
  String passwordLength(int min, int max) {
    return 'Password must be $min to $max characters long.';
  }

  @override
  String get passwordLetterAndDigit =>
      'Password must contain at least one letter and one digit.';

  @override
  String currencyVnd(String amount) {
    return '$amount đ';
  }

  @override
  String get weekdayShortMon => 'Mon';

  @override
  String get weekdayShortTue => 'Tue';

  @override
  String get weekdayShortWed => 'Wed';

  @override
  String get weekdayShortThu => 'Thu';

  @override
  String get weekdayShortFri => 'Fri';

  @override
  String get weekdayShortSat => 'Sat';

  @override
  String get weekdayShortSun => 'Sun';

  @override
  String get categoryAll => 'All';

  @override
  String get categoryFood => 'Food & drinks';

  @override
  String get categoryGroceries => 'Groceries & markets';

  @override
  String get categoryTransport => 'Transport';

  @override
  String get categoryHousing => 'Housing';

  @override
  String get categoryUtilities => 'Electricity & water';

  @override
  String get categoryTelecom => 'Internet & phone';

  @override
  String get categoryShopping => 'Shopping';

  @override
  String get categoryHealth => 'Health';

  @override
  String get categoryEducation => 'Education';

  @override
  String get categoryEntertainment => 'Entertainment';

  @override
  String get categoryTravel => 'Travel';

  @override
  String get categoryFamily => 'Family & children';

  @override
  String get categorySocial => 'Weddings & funerals';

  @override
  String get categoryInsurance => 'Insurance';

  @override
  String get categoryOtherExpense => 'Other';

  @override
  String get categorySalary => 'Salary';

  @override
  String get categoryBonus => 'Bonus';

  @override
  String get categoryBusiness => 'Business';

  @override
  String get categoryInvestment => 'Investment';

  @override
  String get categoryGift => 'Gifts received';

  @override
  String get categoryOtherIncome => 'Other income';
}
