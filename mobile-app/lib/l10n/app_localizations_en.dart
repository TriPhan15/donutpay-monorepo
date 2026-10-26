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
  String get registerTitle => 'Sign up';

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
  String get credentialsNoData => 'No account data yet.';

  @override
  String get credentialsTapToEdit => 'Tap the row you want to change.';

  @override
  String get credentialsUsername => 'Username';

  @override
  String get credentialsUsernameEmail => 'Username (email)';

  @override
  String get credentialsEditUsername => 'Edit username';

  @override
  String get credentialsUsernameRequired => 'Please enter a username.';

  @override
  String get credentialsUsernameChangeUnsupported =>
      'The server does not support changing the username yet.';

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
  String get credentialsChangePasswordSuccessMessage =>
      'Your new password now applies to your account.';

  @override
  String get accountInfoTitle => 'Account information';

  @override
  String get accountInfoSignInAgain => 'Please log in again.';

  @override
  String get userInfoTitle => 'Personal information';

  @override
  String get userInfoEdit => 'Edit';

  @override
  String get userInfoEmpty => 'No personal information yet.';

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
  String get setUserInfoTitle => 'Edit information';

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
  String get helpDashboardTitle => 'Dashboard';

  @override
  String get helpDashboardBody =>
      'See your assets, the month\'s income and spending and the cash flow chart.';

  @override
  String get helpLedgerTitle => 'Ledger';

  @override
  String get helpLedgerBody =>
      'Add, filter and view transactions by day, calendar or month.';

  @override
  String get helpScanTitle => 'Receipt scan';

  @override
  String get helpScanBody =>
      'Tap the round button in the middle of the navigation bar to scan a receipt with AI.';

  @override
  String get helpAiTitle => 'AI analysis';

  @override
  String get helpAiBody =>
      'See spending trends and financial habits analysed automatically.';

  @override
  String get helpTransferTitle => 'Transfers';

  @override
  String get helpTransferBody =>
      'Send or receive money by phone number or QR code.';

  @override
  String get feedbackTitle => 'Rate the app';

  @override
  String get feedbackDescription =>
      'Your feedback helps us keep improving the app!';

  @override
  String get feedbackHint => 'Share your thoughts or suggestions...';

  @override
  String get feedbackLater => 'Later';

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
  String get savingsTitle => 'Savings';

  @override
  String savingsLoadFailed(String reason) {
    return 'Could not load your savings. $reason';
  }

  @override
  String savingsDeleteFailed(String reason) {
    return 'Could not delete the goal. $reason';
  }

  @override
  String savingsDeleted(String title) {
    return 'Goal deleted: $title';
  }

  @override
  String get savingsAddTitle => 'Add a savings goal';

  @override
  String get savingsAdd => 'Add';

  @override
  String get savingsGoalName => 'Goal name';

  @override
  String get savingsTargetAmount => 'Target amount (₫)';

  @override
  String get savingsSavedAmount => 'Saved so far (₫)';

  @override
  String savingsUpdateTitle(String title) {
    return 'Update: $title';
  }

  @override
  String get savingsCurrentAmount => 'Amount saved (₫)';

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
  String get savingsAddGoalAction => 'Add\ngoal';

  @override
  String get savingsGoalList => 'Goals';

  @override
  String get savingsEmpty => 'No goals yet.';

  @override
  String get savingsEmptyHint => 'Tap \"+\" to create a savings goal.';

  @override
  String get savingsUpdate => 'Update';

  @override
  String get commonSessionExpiredTitle => 'Session expired';

  @override
  String get commonInvalidAmountTitle => 'Invalid amount';

  @override
  String get commonSummary => 'Summary';

  @override
  String get currencySymbol => 'đ';

  @override
  String get transactionSaveFailed =>
      'Couldn\'t save the transaction. Please try again.';

  @override
  String get transactionNotSentTitle => 'Not sent to the server yet';

  @override
  String get transactionNotSentMessage =>
      'The transaction is saved on this device but hasn\'t reached the server yet. When you\'re back online, open the Ledger, select the transaction and tap \"Resend\". Resending won\'t create a duplicate.';

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
  String get addTransactionInvalidAmount => 'Please enter a valid amount.';

  @override
  String get addTransactionNoteHint => 'e.g. Coffee at Highlands';

  @override
  String get addTransactionSubmit => 'Save transaction';

  @override
  String get addTransactionSaved => 'New transaction added.';

  @override
  String get editTransactionTitle => 'Edit transaction';

  @override
  String get editTransactionAmountLabel => 'Amount (₫)';

  @override
  String get editTransactionNoServerIdTitle => 'Can\'t edit this transaction';

  @override
  String get editTransactionNoServerIdMessage =>
      'This transaction doesn\'t have a server ID yet.';

  @override
  String get editTransactionAmountPositive =>
      'Please enter an amount greater than 0.';

  @override
  String get editTransactionNoChangesTitle => 'No changes yet';

  @override
  String get editTransactionNoChangesMessage =>
      'Change the amount, category or note before saving.';

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
  String get ledgerTitle => 'Ledger';

  @override
  String get ledgerSearchHint => 'Search name, category...';

  @override
  String get ledgerCalendar => 'Calendar';

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
  String get ledgerIncome => 'Income';

  @override
  String get ledgerExpense => 'Spending';

  @override
  String get ledgerRecent => 'Recent transactions';

  @override
  String get ledgerEmptyPeriod => 'No transactions in this period.';

  @override
  String get ledgerTotalIncome => 'Total income';

  @override
  String get ledgerTotalExpense => 'Total spending';

  @override
  String get ledgerBalance => 'Balance';

  @override
  String get ledgerFilterTitle => 'Smart filter & sort';

  @override
  String get ledgerFilterType => '1. Transaction type';

  @override
  String get ledgerFilterAll => 'All';

  @override
  String get ledgerFilterExpenseOnly => 'Expenses only';

  @override
  String get ledgerFilterIncomeOnly => 'Income only';

  @override
  String get ledgerFilterAmount => '2. Amount range';

  @override
  String get ledgerFilterAnyAmount => 'Any amount';

  @override
  String get ledgerFilterSort => '3. Sort by';

  @override
  String get ledgerSortNewest => 'Newest';

  @override
  String get ledgerSortOldest => 'Oldest';

  @override
  String get ledgerSortHighest => 'Highest amount';

  @override
  String get ledgerFilterApply => 'Apply filters';

  @override
  String get ledgerDetailAmount => 'Amount:';

  @override
  String get ledgerDetailTime => 'Time:';

  @override
  String get ledgerDetailReceiptStatus => 'Receipt status:';

  @override
  String get ledgerDetailSync => 'Sync:';

  @override
  String get ledgerDetailUnsyncedHint =>
      'The server hasn\'t confirmed this transaction yet. When you\'re back online, tap \"Resend\". Resending won\'t create a duplicate.';

  @override
  String get ledgerDetailReceiptImage => 'Original receipt photo:';

  @override
  String get ledgerResend => 'Resend';

  @override
  String get ledgerDelete => 'Delete this transaction';

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
  String get reviewDateFallback =>
      'Couldn\'t read the date on the receipt, so the current time is used. Tap to choose another.';

  @override
  String get reviewFieldNeedsCheck =>
      'The AI isn\'t sure about this field. Please check it.';

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
  String get reviewSaveWithoutPhoto => 'Save without photo';

  @override
  String get reviewLater => 'Later';

  @override
  String get reviewTotalPositive => 'Please enter a total greater than 0.';

  @override
  String get reviewSaved => 'Transaction saved from the receipt.';

  @override
  String get reviewAnalyzing => 'Analyzing the receipt...';

  @override
  String get reviewPleaseWait => 'This will only take a moment';

  @override
  String get reviewExtracted => 'Extraction complete';

  @override
  String get reviewCheckDetails =>
      'Check the details below against the original photo before saving.';

  @override
  String get reviewGeneralInfo => 'General information';

  @override
  String get reviewStoreName => 'Store name';

  @override
  String get reviewTotalLabel => 'Total (đ)';

  @override
  String get reviewSubtotal => 'Subtotal:';

  @override
  String get reviewTax => 'VAT/Other taxes:';

  @override
  String get reviewGrandTotal => 'TOTAL:';

  @override
  String get reviewSubmit => 'Confirm & save';

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
  String paymentOrderCode(String code) {
    return 'Code: $code';
  }

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
  String linkedSyncFrom(String wallet) {
    return 'Sync from $wallet';
  }

  @override
  String get linkedAmountPrompt => 'Amount to add to your spending budget:';

  @override
  String get linkedAmountHint => 'e.g. 100000';

  @override
  String get linkedSync => 'Sync';

  @override
  String linkedMinAmount(String amount) {
    return 'The minimum amount is $amount.';
  }

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
  String get linkedWalletsHeading => 'Linked e-wallets';

  @override
  String get linkedWalletsDescription =>
      'Sync money from a wallet into your budget to manage spending.';

  @override
  String get linkedSyncing => 'Syncing... finish the payment on the gateway.';

  @override
  String get linkedLinked => 'Linked';

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
  String get budgetManage => 'Manage';

  @override
  String get budgetEmptyPeriod => 'No budgets in this period.';

  @override
  String get budgetLoadFailedPullToRetry =>
      'Couldn\'t load your budgets. Pull down to try again.';

  @override
  String budgetMoreCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count more budgets',
      one: '+1 more budget',
    );
    return '$_temp0';
  }

  @override
  String budgetOverBy(String amount) {
    return 'Over the limit by $amount';
  }

  @override
  String budgetNearLimitLeft(String amount) {
    return 'Almost at the limit · Left: $amount';
  }

  @override
  String budgetLeft(String amount) {
    return 'Left: $amount';
  }

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
  String get budgetEmpty => 'No budgets yet.';

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
  String get budgetAmountPositive =>
      'Please enter a budget amount greater than 0.';

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
  String get dashboardBalance => 'Current balance';

  @override
  String get dashboardVsLastMonth => 'vs. last month';

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
  String get aiTitle => 'AI analysis';

  @override
  String get aiPickRangeTitle => 'Choose a time range';

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
  String get aiNoDataHint =>
      'Add real transactions so WCM-SPADE can mine your spending patterns.';

  @override
  String get aiTrendTitle => 'Spending trend';

  @override
  String get aiTopCategoryTitle => 'Top spending';

  @override
  String get aiSavingTipTitle => 'Saving tip';

  @override
  String get aiWeekCompareTitle => 'Week comparison';

  @override
  String get aiChartTitle => 'Income & spending chart';

  @override
  String get aiNoWeekData => 'No data for the weeks of this month yet.';

  @override
  String aiTopWeek(int week, String amount) {
    return 'Week $week has the highest spending: $amount.';
  }

  @override
  String get aiSafeToSpendTitle => 'How much can I spend today?';

  @override
  String get aiSafeToSpendNoIncome =>
      'Add this month\'s income to work out a safe amount.';

  @override
  String aiPerDay(String amount) {
    return '$amount / day';
  }

  @override
  String aiDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'What is left spread evenly over $days days.',
      one: 'What is left covers the last day.',
    );
    return '$_temp0';
  }

  @override
  String get aiOverSafe => 'You\'ve spent past this month\'s safe share.';

  @override
  String aiSpentThisMonth(String amount) {
    return 'You\'ve spent $amount this month.';
  }

  @override
  String aiTrendUp(String percent) {
    return 'Spending this month is up $percent% on last month.';
  }

  @override
  String aiTrendDown(String percent) {
    return 'Spending this month is down $percent% on last month.';
  }

  @override
  String get aiNoSpendingThisMonth => 'No spending this month yet.';

  @override
  String aiTopCategory(String category, String amount, String percent) {
    return '$category accounts for $amount ($percent% of spending).';
  }

  @override
  String aiSurplus(String amount) {
    return 'You\'re $amount ahead. Set a goal!';
  }

  @override
  String get aiAddGoal => 'Add a savings goal for the AI to analyse.';

  @override
  String get aiOnTrack =>
      'You\'re on your savings path. See the money allocation tips below to reach your goal faster!';

  @override
  String get aiSpadeTitle => 'Sequential spending patterns';

  @override
  String get aiSpadeSubtitle => 'Spending sequences you often follow';

  @override
  String get aiSpadeLoadFailedTitle => 'Couldn\'t load the analysis';

  @override
  String get aiSpadeLoadFailedMessage =>
      'Check your connection, then refresh to try again.';

  @override
  String get aiSpadeNotEnoughTitle => 'Not enough data';

  @override
  String get aiSpadeNotEnoughMessage =>
      'Add at least 3 transactions to see sequential spending patterns.';

  @override
  String aiSpadeDetail(String count, String support) {
    return 'Frequency: $count times  ·  Support (W-Sup): $support';
  }

  @override
  String get aiAdviceTitle => 'Money allocation tips';

  @override
  String get aiAdviceSubtitle =>
      'Suggested cuts and keeps per item to reach your savings goal';

  @override
  String aiAdvicePerMonth(String current, String suggested) {
    return '$current → $suggested / month';
  }

  @override
  String get aiGuardTitle => 'Future habit alerts';

  @override
  String get aiGuardSubtitle =>
      'The AI predicts upcoming spending from your spending sequence history.';

  @override
  String get aiGuardHeading => 'Behaviour forecast · Sequence mining';

  @override
  String aiGuardRule(String from, String to) {
    return 'WCM-SPADE found the rule [$from → $to]: after spending on $from, you tend to spend on $to within a few days. Keep an eye on your wallet so it does not eat into your savings!';
  }

  @override
  String get ai503020Title => 'Spending health — the 50/30/20 rule';

  @override
  String get ai503020Groups =>
      'Needs: Food & drinks, Transport, Supermarket, Living costs · Wants: Entertainment, Other';

  @override
  String get ai503020Needs => 'Needs';

  @override
  String get ai503020Wants => 'Wants';

  @override
  String get ai503020Savings => 'Savings (what\'s left)';

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
  String get dateFieldBackToToday => 'Back to today';

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
  String get budgetPeriodDayLabel => 'Period that contains';

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
  String ledgerYearLabel(String year) {
    return 'Year $year';
  }

  @override
  String get categorySavings => 'Savings';

  @override
  String get savingsSavedAmountHint =>
      'Leave empty if there is none yet or you don\'t remember; you can change it later';

  @override
  String get savingsTargetDateField => 'Target date';

  @override
  String get savingsTargetDateAdd => 'Add a target date (optional)';

  @override
  String get savingsTargetDateClear => 'Remove the target date';

  @override
  String savingsTargetDateShown(String date) {
    return 'Target date: $date';
  }

  @override
  String get savingsContribute => 'Add money';

  @override
  String savingsContributeTitle(String title) {
    return 'Add money: $title';
  }

  @override
  String get savingsContributeAmount => 'Amount (₫)';

  @override
  String get savingsContributeHelper =>
      'Taken from your wallet and recorded as a \"Savings\" expense';

  @override
  String get savingsContributeInvalidAmount => 'Enter an amount greater than 0';

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
  String get scanBatchCamera => 'Scan several';

  @override
  String get scanBatchGallery => 'Pick several';

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
  String get pendingStatusReady => 'Ready';

  @override
  String get pendingStatusFailed => 'Failed';

  @override
  String get pendingRetry => 'Read again';

  @override
  String get pendingDiscard => 'Discard';

  @override
  String get pendingDiscardConfirm => 'Remove this receipt from the list?';

  @override
  String pendingConfirmAll(int count) {
    return 'Confirm all valid ($count)';
  }

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
}
