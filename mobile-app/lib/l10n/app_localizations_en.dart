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
  String get notificationsTransactionNotFound =>
      'The transaction of this notification wasn\'t found; it may have been deleted.';

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
  String get notificationsEmptyHint =>
      'Budget, transaction and receipt alerts will show up here.';

  @override
  String notificationsYesterdayAt(String time) {
    return 'Yesterday, $time';
  }

  @override
  String get notificationDetailTitle => 'Notification details';

  @override
  String get notificationDetailType => 'Type';

  @override
  String get notificationDetailTime => 'Time';

  @override
  String get sessionEnded =>
      'Your session has ended, for example because your password was changed. Please sign in again.';

  @override
  String get dialogGotIt => 'Got it';

  @override
  String get forgotPasswordTitle => 'Forgot password';

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
  String get forgotPasswordRemembered => 'Remembered it? ';

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
  String resetPasswordDescription(String email) {
    return 'Enter the code we sent to $email, then choose a new password.';
  }

  @override
  String get resetPasswordOtpLabel => 'Verification code (OTP)';

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
  String get scanSheetSubtitle => 'Choose how to add receipts';

  @override
  String get scanOptionCamera => 'Scan with camera';

  @override
  String get scanOptionCameraHint => 'One receipt, check and save now';

  @override
  String get scanOptionGallery => 'Pick from gallery';

  @override
  String get scanOptionGalleryHint => 'One photo already on the phone';

  @override
  String get scanOptionBatch => 'Scan many';

  @override
  String get scanOptionBatchHint =>
      'Keep shooting, AI reads them in the background';

  @override
  String get scanOptionBatchGallery => 'Pick many photos';

  @override
  String get scanOptionBatchGalleryHint =>
      'Several photos at once, confirm later';

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
  String get dialogDone => 'Done';

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
  String get transactionSourceGoalRefund => 'Savings goal refund';

  @override
  String get transactionSourceWalletTransfer => 'Linked wallet transfer';

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
  String currencyThousandShort(String amount) {
    return '${amount}K';
  }

  @override
  String currencyMillionShort(String amount) {
    return '${amount}M';
  }

  @override
  String currencyBillionShort(String amount) {
    return '${amount}B';
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

  @override
  String get authMissingInfoTitle => 'Missing information';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authEmailHint => 'Enter your email address';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authPasswordHint => 'Enter your password';

  @override
  String get authProcessing => 'Processing...';

  @override
  String get loginFailedTitle => 'Login failed';

  @override
  String get loginWrongCredentials => 'Wrong email or password.';

  @override
  String get loginSocialFailed =>
      'Could not sign in with your social account. Please try again.';

  @override
  String get loginMissingCredentials => 'Please enter your email and password.';

  @override
  String get loginInvalidResponse =>
      'The server sent an invalid response. Please try again.';

  @override
  String get loginTagline => 'Smart personal finance';

  @override
  String get loginRememberMe => 'Remember me';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get loginSubmit => 'Log in';

  @override
  String get loginNoAccount => 'No account yet? ';

  @override
  String get loginSignUpNow => 'Sign up now';

  @override
  String get loginOrContinueWith => 'Or log in with';

  @override
  String get registerHeading => 'Create an account';

  @override
  String get registerDescription =>
      'Fill in your details to start managing your finances.';

  @override
  String get registerFullNameLabel => 'Full name';

  @override
  String get registerFullNameHint => 'Enter your full name';

  @override
  String get registerPhoneLabel => 'Phone number';

  @override
  String get registerPhoneHint => 'Enter your phone number';

  @override
  String get registerSubmit => 'Create account';

  @override
  String get registerHaveAccount => 'Already have an account? ';

  @override
  String get registerOrContinueWith => 'Or sign up with';

  @override
  String get registerTermsPrefix => 'By signing up, you agree to the ';

  @override
  String get registerTerms => 'Terms';

  @override
  String get registerTermsAnd => ' and ';

  @override
  String get registerConditions => 'Conditions of use';

  @override
  String get registerMissingFields =>
      'Please fill in every field (including the phone number).';

  @override
  String get registerWeakPasswordTitle => 'Weak password';

  @override
  String get registerWeakPasswordMessage =>
      'The password does not meet the requirements yet.';

  @override
  String get registerSuccessTitle => 'Sign-up successful';

  @override
  String get registerSuccessMessage =>
      'Your account has been created. Please log in.';

  @override
  String get registerFailedTitle => 'Sign-up failed';

  @override
  String get registerSocialFailed =>
      'Could not sign up with your social account. Please try again.';

  @override
  String get registerPasswordNeeds => 'Your password needs:';

  @override
  String registerRuleMinLength(int min) {
    return 'At least $min characters';
  }

  @override
  String get registerRuleUppercase => 'An uppercase letter (A-Z)';

  @override
  String get registerRuleLowercase => 'A lowercase letter (a-z)';

  @override
  String get registerRuleDigit => 'A digit (0-9)';

  @override
  String get registerRuleSpecial => 'A special character (!@#...)';

  @override
  String get commonSaveChanges => 'Save changes';

  @override
  String get credentialsTitle => 'Account';

  @override
  String get credentialsChangePassword => 'Change password';

  @override
  String get credentialsOldPassword => 'Current password';

  @override
  String get credentialsOldPasswordRequired =>
      'Please enter your current password.';

  @override
  String get credentialsPasswordMismatch => 'The new passwords do not match.';

  @override
  String get credentialsChangePasswordFailed => 'Could not change the password';

  @override
  String get credentialsChangePasswordRejected =>
      'The password was not changed. Please check your current password and try again.';

  @override
  String get credentialsChangePasswordSuccessTitle => 'Password changed';

  @override
  String get accountInfoTitle => 'Account information';

  @override
  String get accountInfoSignInAgain => 'Please log in again.';

  @override
  String get accountSecurityTitle => 'Security';

  @override
  String get accountEmailLocked => 'The sign-in email cannot be changed';

  @override
  String get accountEditNameTitle => 'Edit full name';

  @override
  String get accountEditPhoneTitle => 'Edit phone number';

  @override
  String get accountPhoneRequired => 'Please enter a phone number.';

  @override
  String get changePasswordDoneMessage =>
      'Your new password is in use. Other devices need to sign in again.';

  @override
  String get changePasswordMatches => 'Matches the new password';

  @override
  String get userInfoTitle => 'Personal information';

  @override
  String get userInfoNotSet => 'Not set';

  @override
  String get commonSuccess => 'Success';

  @override
  String get commonSaveFailed => 'Could not save';

  @override
  String get commonSaving => 'Saving...';

  @override
  String get commonRetry => 'Try again';

  @override
  String get setUserInfoLoadFailed =>
      'Could not load your personal information. Please try again.';

  @override
  String get setUserInfoNameRequired => 'Please enter your full name.';

  @override
  String get setUserInfoPhoneInvalid =>
      'Invalid phone number (10 digits starting with 0).';

  @override
  String get setUserInfoSaved => 'Your personal information has been saved.';

  @override
  String get profileUtilities => 'Utilities';

  @override
  String get profileMoneySources => 'Money sources';

  @override
  String get profileLinkedServices => 'Linked services';

  @override
  String get profileBudget => 'Budgets';

  @override
  String get profileSecurityPrivacy => 'Security & privacy';

  @override
  String get profileSupport => 'Support';

  @override
  String get profileHelp => 'User guide';

  @override
  String get profileFeedback => 'Send feedback';

  @override
  String get profileAbout => 'About the app';

  @override
  String get profileLogout => 'Log out';

  @override
  String get profileLogoutConfirmTitle => 'Log out?';

  @override
  String get profileLogoutConfirmMessage => 'Are you sure you want to log out?';

  @override
  String get commonSave => 'Save';

  @override
  String get notificationSettingsTitle => 'Notification settings';

  @override
  String get notificationSettingsPush => 'Push notifications';

  @override
  String get notificationSettingsBudgetAlert => 'Budget alerts';

  @override
  String get notificationSettingsSaved => 'Notification settings saved.';

  @override
  String get moneySourcesEmpty => 'No wallets yet.';

  @override
  String get activityLogTitle => 'Activity history';

  @override
  String get activityLogSubtitle => 'See your recent transactions';

  @override
  String activityLogTitleCount(int count) {
    return 'Activity history ($count)';
  }

  @override
  String get feedbackTitle => 'Rate the app';

  @override
  String get feedbackHint => 'Share your thoughts or suggestions...';

  @override
  String get feedbackSubmit => 'Send now';

  @override
  String get feedbackThanks => 'Thank you for your feedback!';

  @override
  String get feedbackFailed =>
      'Could not send your feedback, please try again later.';

  @override
  String get aboutDescription =>
      'A smart personal finance app with AI spending analysis.';

  @override
  String get appearanceLanguageTitle => 'Appearance and language';

  @override
  String get themeCardSystem => 'System';

  @override
  String languageConfirmTitle(String language) {
    return 'Switch to $language?';
  }

  @override
  String get languageConfirmMessage =>
      'All text in the app will switch to this language.';

  @override
  String get languageConfirmAction => 'Switch';

  @override
  String get notificationSettingsPushDescription =>
      'Get notifications on this phone';

  @override
  String get notificationSettingsBudgetAlertDescription =>
      'Alerts at 80% of a budget and when it is exceeded';

  @override
  String get moneySourcesTotal => 'Total';

  @override
  String get securityChangePasswordDescription =>
      'Other devices will have to sign in again';

  @override
  String get guideHomeTitle => 'Home';

  @override
  String get guideHomeBody =>
      'See your balance, this month\'s income and spending, your budget and recent transactions.';

  @override
  String get guideStatsTitle => 'Statistics';

  @override
  String get guideStatsBody =>
      'See spending as a chart, a month calendar or by category; filter and export to Excel.';

  @override
  String get guideScanTitle => 'Scan receipts';

  @override
  String get guideScanBody =>
      'Tap the round button in the middle of the bottom bar and take or pick a photo. The AI reads the store, the date and the total for you to check and save.';

  @override
  String get guideAnalysisTitle => 'Spending analysis';

  @override
  String get guideAnalysisBody =>
      'See what you can spend each day, highlights, spending habits and balance tips.';

  @override
  String get guideBudgetSavingsTitle => 'Budgets and savings';

  @override
  String get guideBudgetSavingsBody =>
      'Set spending limits per category and follow your savings goals.';

  @override
  String get feedbackChipEasy => 'Easy to use';

  @override
  String get feedbackChipScan => 'Accurate receipt scanning';

  @override
  String get feedbackChipLooks => 'Nice design';

  @override
  String get feedbackChipMore => 'Needs more features';

  @override
  String feedbackStarLabel(int count) {
    return '$count of 5 stars';
  }

  @override
  String get aboutVersion => 'Version';

  @override
  String get aboutDeveloper => 'Developed by';

  @override
  String get aboutDeveloperValue => 'Team 7';

  @override
  String get aboutSchool => 'School';

  @override
  String get aboutSchoolValue => 'HUIT';

  @override
  String get aboutLicenses => 'Open source licenses';

  @override
  String get savingsTitle => 'Savings';

  @override
  String savingsDeleteFailed(String reason) {
    return 'Could not delete the goal. $reason';
  }

  @override
  String savingsDeleted(String title) {
    return 'Goal deleted: $title';
  }

  @override
  String savingsDeletedRefunded(String title, String amount) {
    return 'Goal deleted: $title. $amount went back to your wallet.';
  }

  @override
  String get savingsDeleteTitle => 'Delete goal';

  @override
  String get savingsDeleteConfirm => 'Delete this goal?';

  @override
  String savingsDeleteConfirmRefund(String amount) {
    return 'Delete this goal? The $amount contributed will be refunded to your wallet.';
  }

  @override
  String get savingsGoalName => 'Goal name';

  @override
  String get ledgerSavingsManagedByGoal =>
      'Savings contributions are managed on the Savings page.';

  @override
  String get savingsTotalSaved => 'Total saved';

  @override
  String savingsGoalCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count goals',
      one: '1 goal',
    );
    return '$_temp0';
  }

  @override
  String savingsTarget(String amount) {
    return 'Target: $amount';
  }

  @override
  String get commonSessionExpiredTitle => 'Session expired';

  @override
  String get commonInvalidAmountTitle => 'Invalid amount';

  @override
  String get currencySymbol => 'đ';

  @override
  String get transactionSaveFailed =>
      'Couldn\'t save the transaction. Please try again.';

  @override
  String get transactionNotSentTitle => 'Not sent to the server yet';

  @override
  String get transactionNotSentMessage =>
      'The transaction is saved on this device but hasn\'t reached the server yet. When you\'re back online, open Statistics, select the transaction and tap \"Resend\". Resending won\'t create a duplicate.';

  @override
  String get transactionCategoryLabel => 'Category';

  @override
  String get transactionDateLabel => 'Transaction date';

  @override
  String get transactionNoteOptional => 'Note (optional)';

  @override
  String get transactionPickExpenseCategory => 'Choose an expense category';

  @override
  String get transactionPickIncomeCategory => 'Choose an income category';

  @override
  String get transactionExpenseMoney => 'Expense';

  @override
  String get transactionIncomeMoney => 'Income';

  @override
  String get transactionExpenseKind => 'Expense';

  @override
  String get transactionIncomeKind => 'Income';

  @override
  String get addTransactionTitle => 'Add transaction';

  @override
  String get addTransactionAmountLabel => 'Amount';

  @override
  String get addTransactionNoteHint => 'e.g. Coffee at Highlands';

  @override
  String get addTransactionSaved => 'New transaction added.';

  @override
  String get categoryMoreTile => 'More';

  @override
  String get transactionTabExpense => 'Expense';

  @override
  String get transactionTabIncome => 'Income';

  @override
  String get addTransactionManualTab => 'Manual';

  @override
  String get addTransactionScanTab => 'Scan receipt';

  @override
  String get addTransactionSubmitExpense => 'Add expense';

  @override
  String get addTransactionSubmitIncome => 'Add income';

  @override
  String get addTransactionDiscardTitle => 'Discard this transaction?';

  @override
  String get addTransactionDiscardMessage =>
      'The amount and note you typed will not be saved.';

  @override
  String get addTransactionDiscardConfirm => 'Discard and scan';

  @override
  String editTransactionSummaryLine(String kind, String time) {
    return '$kind, $time';
  }

  @override
  String get editTransactionTitle => 'Edit transaction';

  @override
  String get editTransactionNoServerIdTitle => 'Can\'t edit this transaction';

  @override
  String get editTransactionNoServerIdMessage =>
      'This transaction doesn\'t have a server ID yet.';

  @override
  String get editTransactionSaveFailedTitle => 'Couldn\'t save the transaction';

  @override
  String get editTransactionRejected =>
      'The server couldn\'t process the request. Please try again later.';

  @override
  String get editTransactionSavedTitle => 'Changes saved';

  @override
  String get editTransactionSavedMessage => 'The transaction has been updated.';

  @override
  String get editTransactionCategoriesUnavailable =>
      'Couldn\'t load the category list. You can still edit the amount and note.';

  @override
  String get ledgerTitle => 'Statistics';

  @override
  String get ledgerSearchHint => 'Search name, category...';

  @override
  String get ledgerLegendIncome => 'Income';

  @override
  String get ledgerLegendExpense => 'Expense';

  @override
  String ledgerChartMonth(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      '1': 'Jan',
      '2': 'Feb',
      '3': 'Mar',
      '4': 'Apr',
      '5': 'May',
      '6': 'Jun',
      '7': 'Jul',
      '8': 'Aug',
      '9': 'Sep',
      '10': 'Oct',
      '11': 'Nov',
      '12': 'Dec',
      'other': '$month',
    });
    return '$_temp0';
  }

  @override
  String get ledgerEmptyPeriod => 'No transactions in this period.';

  @override
  String get ledgerBalance => 'Balance';

  @override
  String get ledgerDetailUnsyncedHint =>
      'The server hasn\'t confirmed this transaction yet. When you\'re back online, tap \"Resend\". Resending won\'t create a duplicate.';

  @override
  String get ledgerResend => 'Resend';

  @override
  String get ledgerDeleteTitle => 'Delete transaction?';

  @override
  String get ledgerDeleteMessage =>
      'The amount will go back to your wallet and this can\'t be undone. Are you sure?';

  @override
  String get ledgerDeleteNow => 'Delete now';

  @override
  String get ledgerDeleted => 'Transaction deleted and amount refunded';

  @override
  String get ledgerDeleteFailed => 'Couldn\'t delete. Please try again';

  @override
  String get ledgerResendFailedTitle => 'Resend failed';

  @override
  String get ledgerResendFailedMessage =>
      'Couldn\'t resend the transaction. Please try again.';

  @override
  String get ledgerResent => 'Transaction sent to the server';

  @override
  String get ledgerStillNotSentTitle => 'Still not sent';

  @override
  String get ledgerStillNotSentMessage =>
      'Can\'t reach the server. The transaction stays on this device and you can resend it later.';

  @override
  String get ledgerDeleteUnsyncedTitle => 'Delete unsent transaction?';

  @override
  String get ledgerDeleteUnsyncedMessage =>
      'The server hasn\'t confirmed this transaction. Remove it from this device and stop sending it? This can\'t be undone.';

  @override
  String get ledgerDeletedUnsynced => 'Unsent transaction deleted';

  @override
  String get ledgerDeleteWhileSending =>
      'This transaction is being sent. Try again in a moment.';

  @override
  String get ledgerLoadFailedNotice =>
      'Couldn\'t load the list from the server. Only the unsent transactions on this device are shown. Pull down to try again.';

  @override
  String ledgerExcelSheet(String month) {
    return 'Spending $month';
  }

  @override
  String get ledgerExcelDate => 'Date';

  @override
  String get ledgerExcelTotal => 'Total';

  @override
  String ledgerExcelBudgetHeader(String month) {
    return 'BUDGETS $month';
  }

  @override
  String get ledgerExcelLimit => 'Limit';

  @override
  String get ledgerExcelSpent => 'Spent';

  @override
  String get ledgerExcelRemaining => 'Remaining';

  @override
  String ledgerExcelFileName(String month, String date) {
    return 'spending_$month$date';
  }

  @override
  String ledgerExcelShareText(String month) {
    return 'Spending report for $month';
  }

  @override
  String get reviewTitle => 'Confirm receipt';

  @override
  String get reviewNoTotal =>
      'Donut couldn\'t read the total from the photo. Please enter it manually.';

  @override
  String get reviewScanFailed =>
      'Receipt scan failed (check the AI service). Please enter the details manually.';

  @override
  String get reviewPhotoUploadFailedTitle =>
      'Couldn\'t upload the receipt photo';

  @override
  String get reviewPhotoUploadFailedMessage =>
      'The receipt photo hasn\'t been uploaded to the server. Save the transaction without the photo?';

  @override
  String reviewPhotoUploadFailedToast(String reason) {
    return 'Couldn\'t upload the photo: $reason';
  }

  @override
  String get reviewPhotoRejected =>
      'The photo is too large or not an image the server accepts.';

  @override
  String get reviewSaveWithoutPhoto => 'Save without photo';

  @override
  String get reviewLater => 'Later';

  @override
  String get reviewSaved => 'Transaction saved from the receipt.';

  @override
  String get reviewStepPhoto => 'Photo';

  @override
  String get reviewStepCheck => 'Check';

  @override
  String get reviewStepSave => 'Save';

  @override
  String get reviewZoom => 'Zoom';

  @override
  String get reviewCompare => 'Compare';

  @override
  String get reviewNeedsCheck => 'Check this';

  @override
  String get reviewStoreHint => 'Store name may be wrong, please correct it.';

  @override
  String get reviewTotalHint =>
      'Total may be wrong, compare it with the photo.';

  @override
  String get reviewDateHint =>
      'Could not read the date; pick it if it was not today.';

  @override
  String get reviewTotal => 'Total';

  @override
  String get reviewDateDoubtHint =>
      'Date may be wrong, compare it with the photo.';

  @override
  String get reviewSaveAndScan => 'Save & scan next';

  @override
  String get reviewSave => 'Save';

  @override
  String get reviewAnalyzing => 'Analyzing the receipt...';

  @override
  String get reviewPleaseWait => 'This will only take a moment';

  @override
  String get reviewStoreName => 'Store name';

  @override
  String get paymentHistoryTitle => 'Deposit/withdrawal history';

  @override
  String paymentHistoryLoadFailed(String reason) {
    return 'Couldn\'t load the history. $reason';
  }

  @override
  String get paymentHistoryEmpty => 'No deposits or withdrawals yet.';

  @override
  String paymentCancelled(String code) {
    return 'Order $code cancelled';
  }

  @override
  String paymentCancelFailed(String reason) {
    return 'Couldn\'t cancel the order. $reason';
  }

  @override
  String get paymentDeposit => 'Deposit';

  @override
  String get paymentWithdrawal => 'Withdrawal';

  @override
  String get paymentCancelOrder => 'Cancel order';

  @override
  String get paymentStatusSuccess => 'Successful';

  @override
  String get paymentStatusFailed => 'Failed';

  @override
  String get paymentStatusCancelled => 'Cancelled';

  @override
  String get paymentStatusPending => 'Pending';

  @override
  String linkedCreateOrderFailed(String reason) {
    return 'Couldn\'t create the sync order. $reason';
  }

  @override
  String get linkedPollTimedOut =>
      'No payment result yet. Please check again in the sync history.';

  @override
  String get linkedDemoWallet => 'Demo wallet';

  @override
  String get linkedSync => 'Sync';

  @override
  String linkedSynced(String amount) {
    return 'Synced $amount to your spending budget.';
  }

  @override
  String linkedSyncOutcome(String status) {
    return 'Sync: $status';
  }

  @override
  String get linkedHistoryTooltip => 'Sync history';

  @override
  String get linkedWalletsDescription =>
      'Sync money from a wallet into your budget to manage spending.';

  @override
  String get linkedLinked => 'Linked';

  @override
  String linkedSyncingFrom(String amount, String wallet) {
    return 'Syncing $amount from $wallet… finish the payment on the gateway.';
  }

  @override
  String get linkedSheetTitle => 'Sync money';

  @override
  String linkedSheetFrom(String wallet) {
    return 'From $wallet';
  }

  @override
  String get linkedSheetTarget => 'Into your spending budget';

  @override
  String get linkedAmountLabel => 'Amount to add';

  @override
  String linkedMinAmountHint(String amount, String wallet) {
    return 'Minimum $amount. You will be taken to the $wallet gateway to pay.';
  }

  @override
  String linkedMaxAmountHint(String amount) {
    return 'At most $amount per sync.';
  }

  @override
  String get linkedContinuePayment => 'Continue to payment';

  @override
  String get paymentOrderDetails => 'Order details';

  @override
  String get paymentDetailWallet => 'Wallet';

  @override
  String get paymentDetailCode => 'Order code';

  @override
  String get paymentDetailTime => 'Time';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonApply => 'Apply';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get periodThisWeek => 'This week';

  @override
  String get periodThisMonth => 'This month';

  @override
  String get periodCustom => 'Custom';

  @override
  String get budgetTitle => 'Budgets';

  @override
  String get budgetAlertWarningTitle => 'Budget almost used up';

  @override
  String get budgetAlertExceededTitle => 'Budget exceeded';

  @override
  String budgetAlertExceededLine(
    String name,
    String period,
    String amounts,
    String percent,
  ) {
    return '• $name (per $period): over the limit — $amounts ($percent%)';
  }

  @override
  String budgetAlertWarningLine(
    String name,
    String period,
    String amounts,
    String percent,
  ) {
    return '• $name (per $period): $percent% of the limit used — $amounts';
  }

  @override
  String get budgetLoadFailedTitle => 'Couldn\'t load your budgets';

  @override
  String get budgetDeleteTitle => 'Delete budget?';

  @override
  String budgetDeleteMessage(String name) {
    return 'The budget \"$name\" will be deleted.';
  }

  @override
  String get budgetDeleteFailedTitle => 'Couldn\'t delete the budget';

  @override
  String get budgetDeleted => 'Budget deleted';

  @override
  String get budgetEmptyHint =>
      'Set a weekly or monthly spending limit to stay in control.';

  @override
  String get budgetCreate => 'Set up a budget';

  @override
  String get budgetEditTitle => 'Edit budget';

  @override
  String get budgetAmountLabel => 'Budget amount (₫)';

  @override
  String get budgetPeriodLabel => 'Period';

  @override
  String get budgetAppliedPeriod => 'Applied period';

  @override
  String get budgetSave => 'Save budget';

  @override
  String get budgetSaveFailedTitle => 'Couldn\'t save the budget';

  @override
  String get budgetSavedTitle => 'Budget saved';

  @override
  String get budgetSavedMessage => 'Your spending limit has been updated.';

  @override
  String get budgetCategoriesLoadFailedTitle => 'Couldn\'t load the categories';

  @override
  String budgetCategoriesLoadFailedMessage(String allLabel) {
    return 'You can still choose \"$allLabel\" or try again later.';
  }

  @override
  String get dashboardGreeting => 'Hello,';

  @override
  String get dashboardBalance => 'Balance';

  @override
  String dashboardPendingNotInBalance(String amount) {
    return 'Excludes $amount from transactions waiting to be sent';
  }

  @override
  String dashboardMonthIncome(String amount) {
    return 'In $amount';
  }

  @override
  String dashboardMonthExpense(String amount) {
    return 'Out $amount';
  }

  @override
  String get dashboardShowAmounts => 'Show amounts';

  @override
  String get dashboardHideAmounts => 'Hide amounts';

  @override
  String get dashboardSavingsShort => 'Savings';

  @override
  String homeBudgetLeft(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$amount left for $_temp0';
  }

  @override
  String homeBudgetOver(String amount) {
    return 'Over by $amount';
  }

  @override
  String homeBudgetCategoryOver(String category, String amount) {
    return '$category is over by $amount';
  }

  @override
  String homeBudgetCategoryNear(String category, int percent) {
    return '$category has used $percent%';
  }

  @override
  String get homeBudgetView => 'View';

  @override
  String get homeBudgetEmptyTitle => 'Set this month\'s budget';

  @override
  String get homeBudgetEmptyHint => 'See how much is left for each day';

  @override
  String get homeBudgetSet => 'Set';

  @override
  String get homeBudgetFailed => 'Couldn\'t load budgets';

  @override
  String get dashboardRecent => 'Recent';

  @override
  String get dashboardSeeAll => 'See all';

  @override
  String get dashboardLoadFailedTitle => 'Couldn\'t load the home screen';

  @override
  String get dashboardLoadFailedMessage =>
      'Check the connection and try again.';

  @override
  String get dashboardNoTransactions => 'No transactions yet.';

  @override
  String get moneySourcesSubtitle => 'Wallets linked to your account';

  @override
  String get allFeaturesTitle => 'All features';

  @override
  String get featureSavingsDescription => 'Manage savings goals';

  @override
  String get featureMoneySourcesDescription => 'See wallets and balances';

  @override
  String get featureLinkedServicesDescription => 'MoMo, ZaloPay, banks...';

  @override
  String get aiTodayLabel => 'You can spend today';

  @override
  String aiTodayDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days left',
      one: 'last day',
    );
    return '$_temp0';
  }

  @override
  String aiTodaySpent(String amount) {
    return 'Spent $amount';
  }

  @override
  String aiTodayLeft(String amount) {
    return '$amount left today';
  }

  @override
  String aiTodayOver(String amount) {
    return '$amount over today';
  }

  @override
  String get aiHighlightsTitle => 'Highlights';

  @override
  String get aiTrendVsLastMonth => 'Compared with the same days last month';

  @override
  String aiTopCategoryLine(String category, String amount) {
    return '$category, $amount';
  }

  @override
  String get aiTipSurplus => 'Money left this month: set a goal';

  @override
  String get aiTipNeedMore => 'Still to put into your goal this month';

  @override
  String get aiTipOnTrack => 'On track for your goal';

  @override
  String get aiTipOverspent =>
      'Goal covered, but this month is spending more than came in';

  @override
  String aiWeekCompareLine(String thisWeek, String lastWeek) {
    return '$thisWeek / last week $lastWeek';
  }

  @override
  String get aiWeekCompareNone => 'No spending in these two weeks';

  @override
  String get aiTopWeekTitle => 'Top spending week';

  @override
  String aiTopWeekLine(int week) {
    return 'Week $week of this month';
  }

  @override
  String get aiDailyChartTitle => 'Daily spending';

  @override
  String get aiPickRangeStart => 'From';

  @override
  String get aiPickRangeEnd => 'To';

  @override
  String get aiHabitsTitle => 'Spending habits';

  @override
  String aiHabitRepeat(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: 'Repeated over the last $weeks weeks',
      one: 'Seen in the last week',
    );
    return '$_temp0';
  }

  @override
  String aiTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times',
      one: 'once',
    );
    return '$_temp0';
  }

  @override
  String aiHabitEvery(String days) {
    return 'About every $days days';
  }

  @override
  String aiHabitLastOn(String date) {
    return 'Last on $date';
  }

  @override
  String aiHabitUpcoming(String from, String to) {
    return 'Coming up: after $from you usually spend on $to.';
  }

  @override
  String aiHabitUsually(String from, String to) {
    return 'After $from you usually spend on $to.';
  }

  @override
  String get aiBalanceTitle => 'Spending balance';

  @override
  String aiBalanceLine(int percent, int target) {
    return '$percent% of income, about $target% advised';
  }

  @override
  String get aiBalanceSavings => 'Savings';

  @override
  String get aiLevelOk => 'On track';

  @override
  String get aiLevelHigh => 'A bit high';

  @override
  String get aiLevelLow => 'A bit low';

  @override
  String aiAdviceLine(String category, String current, String suggested) {
    return '$category: $current → $suggested / month';
  }

  @override
  String get aiNoDataMessage =>
      'Add transactions to see your spending analysis.';

  @override
  String get aiErrorNetwork =>
      'Can\'t reach the analysis server. Please check your connection and try again.';

  @override
  String get aiErrorServer =>
      'The analysis server ran into a problem. Please try again later.';

  @override
  String get aiErrorRejected =>
      'The analysis server couldn\'t process the request. Please try again later.';

  @override
  String get aiAnalyzeFailedTitle => 'Couldn\'t analyse your spending habits';

  @override
  String get aiNoData => 'No data yet';

  @override
  String get aiTrendTitle => 'Spending trend';

  @override
  String get aiTopCategoryTitle => 'Top spending';

  @override
  String get aiSavingTipTitle => 'Saving tip';

  @override
  String get aiWeekCompareTitle => 'Week comparison';

  @override
  String get aiSafeToSpendNoIncome =>
      'Add this month\'s income to work out a safe amount.';

  @override
  String get aiOverSafe => 'You\'ve spent past this month\'s safe share.';

  @override
  String aiSpentThisMonth(String amount) {
    return 'You\'ve spent $amount this month.';
  }

  @override
  String get aiNoSpendingThisMonth => 'No spending this month yet.';

  @override
  String get aiAddGoal => 'Add a savings goal for the AI to analyse.';

  @override
  String get aiGoalNoDeadline =>
      'This goal has no deadline, contribute whenever you can';

  @override
  String get aiGoalOverdue =>
      'This goal is past its deadline: set a new date or keep contributing';

  @override
  String get aiSpadeLoadFailedTitle => 'Couldn\'t load the analysis';

  @override
  String get aiSpadeLoadFailedMessage =>
      'Check your connection, then refresh to try again.';

  @override
  String get aiSpadeNotEnoughTitle => 'Not enough data';

  @override
  String aiSpadeNotEnoughWeeks(int weeks, int minWeeks) {
    return 'Only $weeks weeks with spending so far; at least $minWeeks weeks are needed to look for sequences.';
  }

  @override
  String get aiSpadeNotEnoughUnknown =>
      'Not enough spending history to look for sequences.';

  @override
  String get aiSpadeNotEnoughNone => 'No spending in the last 26 weeks yet.';

  @override
  String get aiSpadeNoPatternTitle => 'No sequence yet';

  @override
  String get aiSpadeNoPatternMessage =>
      'No sequence of spending repeats in enough weeks yet.';

  @override
  String get ai503020Needs => 'Needs';

  @override
  String get ai503020Wants => 'Wants';

  @override
  String get ai503020OnTrack =>
      'This month\'s spending meets the 50/30/20 rule. Keep it up!';

  @override
  String ai503020NeedsHigh(String percent) {
    return 'Needs take $percent% of your income (target ≤50%). Check Living costs/Supermarket for anything you can trim.';
  }

  @override
  String ai503020WantsHigh(String percent) {
    return 'Wants (Entertainment, Other) take $percent% of your income (target ≤30%) — the easiest place to cut.';
  }

  @override
  String ai503020SavingsLow(String percent) {
    return 'You\'ve saved only $percent% of your income (target ≥20%). Raise it a little each month.';
  }

  @override
  String get dateFieldToday => 'Today';

  @override
  String get dateFieldYesterday => 'Yesterday';

  @override
  String get dateFieldPick => 'Choose a date';

  @override
  String get dashboardScanReceipt => 'Scan receipt';

  @override
  String get reviewOpenImage => 'Receipt photo';

  @override
  String get reviewCompareOn => 'Compare with the photo';

  @override
  String get reviewCompareOff => 'Leave compare mode';

  @override
  String reviewOtherMonthBalanceNote(String day) {
    return 'A transaction dated $day still counts toward your current balance';
  }

  @override
  String reviewDuplicateTitle(String date) {
    return 'This receipt seems to have been saved on $date';
  }

  @override
  String get reviewDuplicateTitleNoDate =>
      'This receipt seems to have been saved before';

  @override
  String get reviewDuplicateMessage =>
      'Open the saved one to check it, or save anyway if this is another purchase.';

  @override
  String get reviewDuplicateView => 'View saved one';

  @override
  String get reviewDuplicateSaveAnyway => 'Save anyway';

  @override
  String get reviewDuplicateCannotOpen =>
      'The saved one can\'t be opened from here. You can find it in the Statistics tab.';

  @override
  String get linkedDemoBadge => 'Demo';

  @override
  String get linkedDemoNotice =>
      'This is a demo: the wallets and synced payments are simulated, with no real bank or e-wallet connection.';

  @override
  String get budgetPeriodYear => 'Year';

  @override
  String get periodThisYear => 'This year';

  @override
  String get budgetCustomCategoryLabel => 'Category name';

  @override
  String get budgetCustomCategoryHelper =>
      'A new category is created if needed. Use this exact name in your transactions so they count';

  @override
  String get budgetCustomCategoryRequired => 'Enter the category name';

  @override
  String budgetCustomCategoryTooLong(int max) {
    return 'At most $max characters';
  }

  @override
  String get budgetGroupOver => 'Over budget';

  @override
  String get budgetGroupWithin => 'On track';

  @override
  String budgetGroupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count budgets',
      one: '1 budget',
    );
    return '$_temp0';
  }

  @override
  String budgetLeft(String amount) {
    return '$amount left';
  }

  @override
  String budgetOver(String amount) {
    return '$amount over';
  }

  @override
  String budgetAmounts(String spent, String limit) {
    return '$spent / $limit';
  }

  @override
  String get budgetEmptyPeriod => 'No budget for this period';

  @override
  String ledgerYearLabel(String year) {
    return 'Year $year';
  }

  @override
  String get categorySavings => 'Savings';

  @override
  String get savingsTargetDateClear => 'Remove the target date';

  @override
  String get savingsContribute => 'Add money';

  @override
  String savingsContributeFailed(String reason) {
    return 'Could not add the money. $reason';
  }

  @override
  String get savingsContributeRejected =>
      'Check the amount and your wallet balance.';

  @override
  String savingsContributed(String title) {
    return 'Money added to \"$title\"';
  }

  @override
  String savingsGoalReached(String title) {
    return 'Congratulations! You reached your goal \"$title\"';
  }

  @override
  String scanQueueAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count receipts added to the queue',
      one: '1 receipt added to the queue',
    );
    return '$_temp0';
  }

  @override
  String scanQueueOverLimit(int count, int skipped, int limit) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count receipts added to the queue',
      one: '1 receipt added to the queue',
    );
    return '$_temp0 ($skipped skipped, over $limit)';
  }

  @override
  String scanQueueReading(int current, int total) {
    return 'Reading receipt $current/$total';
  }

  @override
  String scanQueueReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count receipts to confirm',
      one: '1 receipt to confirm',
    );
    return '$_temp0';
  }

  @override
  String scanQueueFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count receipts could not be read',
      one: '1 receipt could not be read',
    );
    return '$_temp0';
  }

  @override
  String get scanQueueStorageFailed =>
      'Couldn\'t update the receipt queue on this device. Please try again.';

  @override
  String get pendingReceiptsTitle => 'Receipts to confirm';

  @override
  String get pendingReceiptsEmpty => 'No receipts waiting.';

  @override
  String get pendingStatusQueued => 'Waiting';

  @override
  String get pendingStatusReading => 'Reading';

  @override
  String get pendingStatusFailed => 'Failed';

  @override
  String get pendingRetry => 'Read again';

  @override
  String get pendingDiscard => 'Discard';

  @override
  String get pendingDiscardConfirm => 'Remove this receipt from the list?';

  @override
  String pendingConfirmAllAsk(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Save $count valid receipts as transactions?',
      one: 'Save 1 valid receipt as a transaction?',
    );
    return '$_temp0';
  }

  @override
  String pendingConfirmAllResult(int saved, int duplicates, int notSaved) {
    return 'Saved $saved, duplicates $duplicates, not saved $notSaved';
  }

  @override
  String get pendingErrorNetwork => 'Couldn\'t reach the AI service.';

  @override
  String get pendingErrorServer =>
      'The AI service couldn\'t read this receipt.';

  @override
  String get pendingErrorMissingImage =>
      'The photo is no longer on this device.';

  @override
  String pendingGroupReady(int count) {
    return 'Ready $count';
  }

  @override
  String pendingGroupProcessing(int count) {
    return 'Processing $count';
  }

  @override
  String pendingTabReading(int count) {
    return 'Reading $count';
  }

  @override
  String pendingTabFailed(int count) {
    return 'Failed $count';
  }

  @override
  String get pendingReadingTitle => 'Reading…';

  @override
  String pendingPhotoTitle(int index) {
    return 'Photo $index';
  }

  @override
  String get pendingQuickSave => 'Save';

  @override
  String get pendingReview => 'Check';

  @override
  String pendingReadyFooter(int count) {
    return '$count receipts ready';
  }

  @override
  String pendingSelected(int count) {
    return '$count selected';
  }

  @override
  String get pendingSelectAll => 'Select all';

  @override
  String pendingSaveSelected(int count) {
    return 'Save $count selected';
  }

  @override
  String get pendingConfirmAllShort => 'Confirm all';

  @override
  String toastStackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notifications · tap to see',
      one: '1 notification · tap to see',
    );
    return '$_temp0';
  }

  @override
  String get toastCollapse => 'Collapse';

  @override
  String get toastCloseAll => 'Close all';

  @override
  String get toastDismiss => 'Dismiss';

  @override
  String get toastJustNow => 'just now';

  @override
  String toastSecondsAgo(int count) {
    return '${count}s ago';
  }

  @override
  String toastMinutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String get receiptViewerTitle => 'Receipt photo';

  @override
  String get receiptViewerShare => 'Share';

  @override
  String get receiptViewerShareFailed => 'Could not share the photo';

  @override
  String get datePickerTransactionTitle => 'Choose the transaction date';

  @override
  String get datePickerTitle => 'Choose a date';

  @override
  String get datePickerLastRecorded => 'Last used';

  @override
  String datePickerMonthTitle(String month, String year, String monthName) {
    return '$monthName $year';
  }

  @override
  String get datePickerWeekdays => 'Mo,Tu,We,Th,Fr,Sa,Su';

  @override
  String get datePickerPreviousMonth => 'Previous month';

  @override
  String get datePickerNextMonth => 'Next month';

  @override
  String dateFieldTodayValue(String date) {
    return 'Today, $date';
  }

  @override
  String dateFieldYesterdayValue(String date) {
    return 'Yesterday, $date';
  }

  @override
  String get filterTitle => 'Filter';

  @override
  String get filterAll => 'All';

  @override
  String get filterExpense => 'Out';

  @override
  String get filterIncome => 'In';

  @override
  String get filterAnyAmount => 'Any';

  @override
  String get filterUnder100k => '<100K';

  @override
  String get filter100kTo500k => '100–500K';

  @override
  String get filterOver500k => '>500K';

  @override
  String get filterNewest => 'Newest';

  @override
  String get filterOldest => 'Oldest';

  @override
  String get filterLargest => 'Largest';

  @override
  String get filterReset => 'Reset';

  @override
  String filterShowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '1 transaction',
    );
    return 'Show $_temp0';
  }

  @override
  String get transactionDetailTitle => 'Transaction details';

  @override
  String get transactionDetailCategory => 'Category';

  @override
  String get transactionDetailTime => 'Time';

  @override
  String get transactionDetailReceipt => 'Receipt';

  @override
  String get transactionDetailSync => 'Sync';

  @override
  String get transactionDetailReceiptImage => 'Receipt photo';

  @override
  String get transactionDetailDelete => 'Delete';

  @override
  String statsIncome(String amount) {
    return 'In $amount';
  }

  @override
  String statsExpense(String amount) {
    return 'Out $amount';
  }

  @override
  String statsLeft(String amount) {
    return 'Left $amount';
  }

  @override
  String get statsViewChart => 'Chart';

  @override
  String get statsViewCalendar => 'Calendar';

  @override
  String get statsViewCategories => 'Categories';

  @override
  String statsMonthLabel(String month, String year) {
    return '$month/$year';
  }

  @override
  String get statsSearch => 'Search transactions';

  @override
  String get statsExport => 'Export to Excel';

  @override
  String get statsPickDate => 'Pick a date';

  @override
  String get statsAdd => '+ Add';

  @override
  String get statsTapBarHint => 'Tap a bar to see the amounts';

  @override
  String get statsSpent => 'spent';

  @override
  String statsCategoryLine(int percent, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times',
      one: '1 time',
    );
    return '$percent%, $_temp0';
  }

  @override
  String get statsByCategory => 'By category';

  @override
  String get statsNoSpending => 'No spending in this period';

  @override
  String get statsTransactions => 'Transactions';

  @override
  String statsTransactionsOfDay(String date) {
    return 'Transactions on $date';
  }

  @override
  String statsTotalIncome(String amount) {
    return 'Total in $amount';
  }

  @override
  String statsTotalExpense(String amount) {
    return 'Total out $amount';
  }

  @override
  String get statsNoMatch => 'No transaction matches the filter';

  @override
  String get statsCategoriesFilterHint =>
      'Filter and search only narrow the transaction list of Chart and Calendar.';

  @override
  String get savingsTabActive => 'In progress';

  @override
  String get savingsTabDone => 'Done';

  @override
  String get savingsMissing => 'Still needed';

  @override
  String savingsDaysLeft(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days left',
      one: '1 day left',
    );
    return '$_temp0 · $date';
  }

  @override
  String savingsDueToday(String date) {
    return 'Due today · $date';
  }

  @override
  String savingsOverdue(String date) {
    return 'Overdue · $date';
  }

  @override
  String get savingsNoDeadline => 'No target date';

  @override
  String get savingsReached => 'Goal reached';

  @override
  String get savingsEmptyActiveTitle => 'No goals in progress';

  @override
  String get savingsEmptyActiveHint => 'Tap + to create a savings goal.';

  @override
  String get savingsEmptyDoneTitle => 'No goals reached yet';

  @override
  String get savingsEmptyDoneHint => 'Goals you fully fund show up here.';

  @override
  String get savingsLoadFailedTitle => 'Could not load your savings';

  @override
  String get savingsCreate => 'Add goal';

  @override
  String get savingsEditGoal => 'Edit goal';

  @override
  String get savingsFormGoalCard => 'Goal';

  @override
  String get savingsFormDeadlineCard => 'Deadline';

  @override
  String get savingsTargetAmountLabel => 'Target amount';

  @override
  String get savingsSavedLabel => 'Saved';

  @override
  String get savingsSavedHint => 'Changes only through Add money.';

  @override
  String get savingsDeadlineLabel => 'Target date (optional)';

  @override
  String get savingsDeadlinePick => 'Pick a date';

  @override
  String get savingsSaveGoal => 'Save goal';

  @override
  String savingsCreated(String title) {
    return 'Goal added: $title';
  }

  @override
  String savingsUpdated(String title) {
    return 'Goal saved: $title';
  }

  @override
  String get savingsSaveFailedTitle => 'Could not save the goal';

  @override
  String get savingsContributeAmountLabel => 'Amount';

  @override
  String savingsContributeAddition(String saved, String added) {
    return '$saved + $added =';
  }

  @override
  String savingsAmountsOf(String saved, String target) {
    return '$saved / $target';
  }

  @override
  String get savingsSuggestedBadge => 'Suggested';

  @override
  String savingsSuggestionHint(String amount, String date) {
    return 'Suggestion: add $amount a month to reach it by $date.';
  }

  @override
  String savingsWalletLine(String balance) {
    return 'Taken from your wallet (balance $balance) and recorded as a \"Savings\" expense.';
  }

  @override
  String get savingsWalletLineNoBalance =>
      'Taken from your wallet and recorded as a \"Savings\" expense.';

  @override
  String savingsContributeButton(String amount) {
    return 'Add $amount';
  }

  @override
  String savingsReloadFailed(String reason) {
    return 'Could not reload your savings. $reason';
  }

  @override
  String get savingsNoTarget => 'No amount set';

  @override
  String savingsOverfillHint(String missing) {
    return 'The goal only misses $missing. The extra still goes into the goal.';
  }
}
