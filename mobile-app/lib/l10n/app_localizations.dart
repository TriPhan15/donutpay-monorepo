import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('vi'),
    Locale('en'),
  ];

  /// Title of the settings screen.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Label of the language setting.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Label of the theme setting.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// Dark theme option.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// Light theme option.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// Theme option that follows the device setting.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// Subtitle of the System theme option.
  ///
  /// In en, this message translates to:
  /// **'Follows your device setting'**
  String get systemThemeDescription;

  /// Name of the English language, written in English in every locale so that its speakers can find it.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// Name of the Vietnamese language, written in Vietnamese in every locale so that its speakers can find it.
  ///
  /// In en, this message translates to:
  /// **'Tiếng Việt'**
  String get vietnamese;

  /// Snackbar shown when a theme or language choice could not be written to the device.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save this setting. The change applies until you close the app.'**
  String get settingsSaveFailed;

  /// Title of the notification screen, also the tooltip of the bell on the home screen.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// App bar action of the notification screen that marks every notification as read.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get notificationsMarkAllRead;

  /// Shown on the notification screen when the user has no notification at all.
  ///
  /// In en, this message translates to:
  /// **'You have no notifications yet.'**
  String get notificationsEmpty;

  /// Shown when the list of notifications could not be loaded from the server.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your notifications.'**
  String get notificationsLoadFailed;

  /// Shown at the end of the list when the next page of notifications could not be loaded.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load more notifications.'**
  String get notificationsLoadMoreFailed;

  /// Button that asks the server for the notifications again after a failure.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get notificationsRetry;

  /// Snackbar shown when the server refused or missed marking one notification as read; it shows as unread again.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t mark the notification as read. Please try again.'**
  String get notificationsMarkReadFailed;

  /// Snackbar shown when marking every notification as read failed; they show as unread again.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t mark your notifications as read. Please try again.'**
  String get notificationsMarkAllReadFailed;

  /// Snackbar on the Ledger when a tapped notification points to a transaction that is not in the user's list (for example deleted).
  ///
  /// In en, this message translates to:
  /// **'The transaction of this notification wasn\'t found; it may have been deleted.'**
  String get notificationsTransactionNotFound;

  /// Screen reader label of the dot that marks an unread notification.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get notificationsUnread;

  /// Heading of a notification saying that spending reached 80% of a budget.
  ///
  /// In en, this message translates to:
  /// **'Budget almost used up'**
  String get notificationTypeBudgetWarning;

  /// Heading of a notification saying that spending reached or passed 100% of a budget.
  ///
  /// In en, this message translates to:
  /// **'Budget exceeded'**
  String get notificationTypeBudgetExceeded;

  /// Heading of a notification about one transaction.
  ///
  /// In en, this message translates to:
  /// **'Transaction alert'**
  String get notificationTypeTransactionAlert;

  /// Heading of a notification saying that a receipt has been processed.
  ///
  /// In en, this message translates to:
  /// **'Receipt processed'**
  String get notificationTypeReceiptProcessed;

  /// Heading of a notification whose kind this version of the app does not know.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get notificationTypeOther;

  /// Line under the empty-state title of the notification list.
  ///
  /// In en, this message translates to:
  /// **'Budget, transaction and receipt alerts will show up here.'**
  String get notificationsEmptyHint;

  /// Time of a notification from yesterday in the notification list.
  ///
  /// In en, this message translates to:
  /// **'Yesterday, {time}'**
  String notificationsYesterdayAt(String time);

  /// Title of the sheet that shows the whole of a notification.
  ///
  /// In en, this message translates to:
  /// **'Notification details'**
  String get notificationDetailTitle;

  /// Label of the kind row in the notification details sheet.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get notificationDetailType;

  /// Label of the date and time row in the notification details sheet.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get notificationDetailTime;

  /// SnackBar shown on the login screen after the app signed the user out because the session could not be renewed, e.g. the password was changed or reset on another device.
  ///
  /// In en, this message translates to:
  /// **'Your session has ended, for example because your password was changed. Please sign in again.'**
  String get sessionEnded;

  /// Button that closes an error dialog.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get dialogGotIt;

  /// App bar title of the forgot-password screen, the first step of the password recovery.
  ///
  /// In en, this message translates to:
  /// **'Forgot password'**
  String get forgotPasswordTitle;

  /// Explains on the forgot-password screen that a one-time code will be emailed to the address typed below.
  ///
  /// In en, this message translates to:
  /// **'Enter the email of your account. We\'ll send you a one-time code (OTP) to set a new password.'**
  String get forgotPasswordDescription;

  /// Label above the email field of the forgot-password screen.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get forgotPasswordEmailLabel;

  /// Hint inside the empty email field of the forgot-password screen.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address'**
  String get forgotPasswordEmailHint;

  /// Error under the email field when the user asks for a code without typing an email.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email.'**
  String get forgotPasswordEmailRequired;

  /// Error under the email field when what was typed is not an email address.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get forgotPasswordEmailInvalid;

  /// Forgot-password footer, before the bold sign-in link
  ///
  /// In en, this message translates to:
  /// **'Remembered it? '**
  String get forgotPasswordRemembered;

  /// Button of the forgot-password screen that asks the server to email a one-time code.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get forgotPasswordSendOtp;

  /// Title of the error dialog shown when the one-time code could not be sent or sent again.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the code'**
  String get forgotPasswordSendFailed;

  /// Error dialog text when the server refused to send a one-time code without saying why.
  ///
  /// In en, this message translates to:
  /// **'The code couldn\'t be sent. Please check the email and try again.'**
  String get forgotPasswordRejected;

  /// App bar title of the reset-password screen, where the user types the one-time code and a new password.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPasswordTitle;

  /// Description of the reset-password screen. The email is shown partly hidden.
  ///
  /// In en, this message translates to:
  /// **'Enter the code we sent to {email}, then choose a new password.'**
  String resetPasswordDescription(String email);

  /// Label above the one-time code field of the reset-password screen.
  ///
  /// In en, this message translates to:
  /// **'Verification code (OTP)'**
  String get resetPasswordOtpLabel;

  /// Error under the one-time code field when it is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter the code.'**
  String get resetPasswordOtpRequired;

  /// Error under the one-time code field when it does not hold exactly the expected number of digits.
  ///
  /// In en, this message translates to:
  /// **'The code must be exactly {length} digits.'**
  String resetPasswordOtpInvalid(int length);

  /// Button that emails a new one-time code to the same address.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resetPasswordResendOtp;

  /// Disabled resend button while the user has to wait before asking for another code.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {seconds}s'**
  String resetPasswordResendIn(int seconds);

  /// SnackBar shown when a new one-time code has been sent.
  ///
  /// In en, this message translates to:
  /// **'A new code has been sent. Please check your email.'**
  String get resetPasswordOtpResent;

  /// Label above the new password field of the reset-password screen.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get resetPasswordNewPasswordLabel;

  /// Hint inside the empty new password field.
  ///
  /// In en, this message translates to:
  /// **'Enter a new password'**
  String get resetPasswordNewPasswordHint;

  /// Error under the new password field when it is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a new password.'**
  String get resetPasswordPasswordRequired;

  /// The password rules, shown under the new password field, in the error colour when the password breaks them.
  ///
  /// In en, this message translates to:
  /// **'{min} to {max} characters, with at least one letter and one digit.'**
  String resetPasswordPasswordPolicy(int min, int max);

  /// Label above the field where the new password is typed a second time.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get resetPasswordConfirmPasswordLabel;

  /// Hint inside the empty confirmation field.
  ///
  /// In en, this message translates to:
  /// **'Enter the new password again'**
  String get resetPasswordConfirmPasswordHint;

  /// Error under the confirmation field when it is empty.
  ///
  /// In en, this message translates to:
  /// **'Please confirm the new password.'**
  String get resetPasswordConfirmRequired;

  /// Error under the confirmation field when it differs from the new password.
  ///
  /// In en, this message translates to:
  /// **'The passwords don\'t match.'**
  String get resetPasswordMismatch;

  /// Button that sets the new password with the one-time code.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPasswordSubmit;

  /// Label of the disabled reset button while the request is on its way.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get resetPasswordSubmitting;

  /// Title of the dialog shown when the password has been reset.
  ///
  /// In en, this message translates to:
  /// **'Password reset'**
  String get resetPasswordSuccessTitle;

  /// Text of the dialog shown when the password has been reset; the user is not signed in automatically.
  ///
  /// In en, this message translates to:
  /// **'Your password has been changed. Please sign in with your new password.'**
  String get resetPasswordSuccessMessage;

  /// Button of the success dialog that opens the login screen.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get resetPasswordBackToLogin;

  /// Title of the error dialog shown when the password could not be reset.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reset your password'**
  String get resetPasswordFailed;

  /// Error dialog text when the server refused the reset without saying why.
  ///
  /// In en, this message translates to:
  /// **'Your password couldn\'t be reset. Please check the code and try again.'**
  String get resetPasswordRejected;

  /// Tooltip of the eye button that shows a hidden password.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get passwordShow;

  /// Tooltip of the eye button that hides a shown password.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get passwordHide;

  /// Label of a disabled send or resend button while the one-time code request is on its way.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get passwordRecoverySending;

  /// Error dialog text when a password recovery request got no answer from the server.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server. Please check your connection and try again.'**
  String get passwordRecoveryNetworkError;

  /// Error dialog text when a password recovery request timed out.
  ///
  /// In en, this message translates to:
  /// **'The server is taking too long to respond. Please try again.'**
  String get passwordRecoveryTimeout;

  /// Error dialog text when the server failed (5xx) on a password recovery request.
  ///
  /// In en, this message translates to:
  /// **'The server ran into a problem. Please try again later.'**
  String get passwordRecoveryServerError;

  /// Error dialog text when a password recovery request failed for a reason the app does not know.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get passwordRecoveryUnexpectedError;

  /// Label of the Home tab in the bottom bar.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Label of the Ledger tab in the bottom bar.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get navLedger;

  /// Label of the AI tab in the bottom bar.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get navAi;

  /// Label of the Profile tab in the bottom bar.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// Title of the sheet opened by the scan button.
  ///
  /// In en, this message translates to:
  /// **'Scan a receipt with AI'**
  String get scanSheetTitle;

  /// Line under the scan sheet title.
  ///
  /// In en, this message translates to:
  /// **'Choose how to add receipts'**
  String get scanSheetSubtitle;

  /// Scan sheet: one receipt with the camera.
  ///
  /// In en, this message translates to:
  /// **'Scan with camera'**
  String get scanOptionCamera;

  /// Explains the camera option.
  ///
  /// In en, this message translates to:
  /// **'One receipt, check and save now'**
  String get scanOptionCameraHint;

  /// Scan sheet: one photo from the gallery.
  ///
  /// In en, this message translates to:
  /// **'Pick from gallery'**
  String get scanOptionGallery;

  /// Explains the gallery option.
  ///
  /// In en, this message translates to:
  /// **'One photo already on the phone'**
  String get scanOptionGalleryHint;

  /// Scan sheet: several receipts with the camera.
  ///
  /// In en, this message translates to:
  /// **'Scan many'**
  String get scanOptionBatch;

  /// Explains the batch camera option.
  ///
  /// In en, this message translates to:
  /// **'Keep shooting, AI reads them in the background'**
  String get scanOptionBatchHint;

  /// Scan sheet: several photos from the gallery.
  ///
  /// In en, this message translates to:
  /// **'Pick many photos'**
  String get scanOptionBatchGallery;

  /// Explains the batch gallery option.
  ///
  /// In en, this message translates to:
  /// **'Several photos at once, confirm later'**
  String get scanOptionBatchGalleryHint;

  /// Error dialog title when the document scanner fails to open.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the scanner'**
  String get scanScannerFailedTitle;

  /// Error dialog text when the document scanner fails to open.
  ///
  /// In en, this message translates to:
  /// **'Please try again or pick a photo from the gallery.'**
  String get scanScannerFailedMessage;

  /// Error dialog title when the photo gallery fails to open.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the photo gallery'**
  String get scanGalleryFailedTitle;

  /// Error dialog text when the photo gallery fails to open.
  ///
  /// In en, this message translates to:
  /// **'Please check the app\'s photo access and try again.'**
  String get scanGalleryFailedMessage;

  /// Default button of a success dialog.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get dialogDone;

  /// Default confirm button of a confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get dialogConfirm;

  /// Default cancel button of a confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get dialogCancel;

  /// A request got no answer from the server.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server. Please check your connection and try again.'**
  String get errorNetwork;

  /// A request timed out.
  ///
  /// In en, this message translates to:
  /// **'The server is taking too long to respond. Please try again.'**
  String get errorTimeout;

  /// The server failed (5xx).
  ///
  /// In en, this message translates to:
  /// **'The server ran into a problem. Please try again later.'**
  String get errorServer;

  /// The server answered 401 without a message.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get errorSessionExpired;

  /// A request failed for a reason the app does not know.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorUnexpected;

  /// The server refused a transaction (4xx) without a message the app can show.
  ///
  /// In en, this message translates to:
  /// **'The server refused this transaction. Please check the details.'**
  String get transactionRefused;

  /// Name shown for an account that has neither a username nor an email.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get defaultUserName;

  /// Name of the single wallet of the user.
  ///
  /// In en, this message translates to:
  /// **'Main wallet'**
  String get mainWalletName;

  /// Badge of a transaction saved on the device but not confirmed by the server yet.
  ///
  /// In en, this message translates to:
  /// **'Waiting to send'**
  String get syncStatusPending;

  /// Badge of a transaction the server has.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get syncStatusSynced;

  /// Badge of a transaction whose last send failed.
  ///
  /// In en, this message translates to:
  /// **'Send failed'**
  String get syncStatusError;

  /// Badge of a receipt that is being read or reviewed.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get receiptStatusProcessing;

  /// Badge of a receipt that was read and confirmed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get receiptStatusSuccess;

  /// Badge of a receipt that could not be read or was rejected.
  ///
  /// In en, this message translates to:
  /// **'Failed · confirm again'**
  String get receiptStatusFailed;

  /// Label on a transaction: the money of a deleted savings goal going back to the wallet. It is not income.
  ///
  /// In en, this message translates to:
  /// **'Savings goal refund'**
  String get transactionSourceGoalRefund;

  /// Label on a transaction: money moved between the wallet of the app and a linked e-wallet. It is neither income nor spending.
  ///
  /// In en, this message translates to:
  /// **'Linked wallet transfer'**
  String get transactionSourceWalletTransfer;

  /// Weekly budget period.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get budgetPeriodWeek;

  /// Monthly budget period.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get budgetPeriodMonth;

  /// What a budget without a category is called.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get budgetAllCategories;

  /// Date of a transaction made today, with its time (HH:mm).
  ///
  /// In en, this message translates to:
  /// **'Today, {time}'**
  String dateTodayAt(String time);

  /// Date of a transaction made yesterday, with its time (HH:mm).
  ///
  /// In en, this message translates to:
  /// **'Yesterday, {time}'**
  String dateYesterdayAt(String time);

  /// Validation error: the password is empty.
  ///
  /// In en, this message translates to:
  /// **'Password can\'t be empty.'**
  String get passwordEmpty;

  /// Validation error: the password is too short or too long.
  ///
  /// In en, this message translates to:
  /// **'Password must be {min} to {max} characters long.'**
  String passwordLength(int min, int max);

  /// Validation error: the password lacks a letter or a digit.
  ///
  /// In en, this message translates to:
  /// **'Password must contain at least one letter and one digit.'**
  String get passwordLetterAndDigit;

  /// An amount in Vietnamese dong; the unit stays VND in every language.
  ///
  /// In en, this message translates to:
  /// **'{amount} đ'**
  String currencyVnd(String amount);

  /// A compact amount in thousands of dong, e.g. 850K.
  ///
  /// In en, this message translates to:
  /// **'{amount}K'**
  String currencyThousandShort(String amount);

  /// A compact amount in millions of dong, e.g. 18.5M.
  ///
  /// In en, this message translates to:
  /// **'{amount}M'**
  String currencyMillionShort(String amount);

  /// A compact amount in billions of dong, e.g. 1.2B.
  ///
  /// In en, this message translates to:
  /// **'{amount}B'**
  String currencyBillionShort(String amount);

  /// Short name of Monday, under a chart bar.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayShortMon;

  /// Short name of Tuesday, under a chart bar.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayShortTue;

  /// Short name of Wednesday, under a chart bar.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayShortWed;

  /// Short name of Thursday, under a chart bar.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayShortThu;

  /// Short name of Friday, under a chart bar.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayShortFri;

  /// Short name of Saturday, under a chart bar.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdayShortSat;

  /// Short name of Sunday, under a chart bar.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdayShortSun;

  /// Category filter that shows every category.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get categoryAll;

  /// Default category stored by the backend as "Ăn uống" (DefaultCategory).
  ///
  /// In en, this message translates to:
  /// **'Food & drinks'**
  String get categoryFood;

  /// Default category stored by the backend as "Siêu thị & Chợ" (DefaultCategory).
  ///
  /// In en, this message translates to:
  /// **'Groceries & markets'**
  String get categoryGroceries;

  /// Default category stored by the backend as "Di chuyển" (DefaultCategory).
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get categoryTransport;

  /// Default category stored by the backend as "Nhà ở" (DefaultCategory).
  ///
  /// In en, this message translates to:
  /// **'Housing'**
  String get categoryHousing;

  /// Default category stored by the backend as "Điện nước" (DefaultCategory).
  ///
  /// In en, this message translates to:
  /// **'Electricity & water'**
  String get categoryUtilities;

  /// Default category stored by the backend as "Internet & Điện thoại" (DefaultCategory).
  ///
  /// In en, this message translates to:
  /// **'Internet & phone'**
  String get categoryTelecom;

  /// Default category stored by the backend as "Mua sắm" (DefaultCategory).
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get categoryShopping;

  /// Default category stored by the backend as "Sức khỏe" (DefaultCategory).
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get categoryHealth;

  /// Default category stored by the backend as "Giáo dục" (DefaultCategory).
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get categoryEducation;

  /// Default category stored by the backend as "Giải trí" (DefaultCategory).
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get categoryEntertainment;

  /// Default category stored by the backend as "Du lịch" (DefaultCategory).
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get categoryTravel;

  /// Default category stored by the backend as "Gia đình & Con cái" (DefaultCategory).
  ///
  /// In en, this message translates to:
  /// **'Family & children'**
  String get categoryFamily;

  /// Default category stored by the backend as "Hiếu hỉ" (DefaultCategory).
  ///
  /// In en, this message translates to:
  /// **'Weddings & funerals'**
  String get categorySocial;

  /// Default category stored by the backend as "Bảo hiểm" (DefaultCategory).
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get categoryInsurance;

  /// Default category stored by the backend as "Khác" (DefaultCategory).
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get categoryOtherExpense;

  /// Default category stored by the backend as "Lương" (DefaultCategory).
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get categorySalary;

  /// Default category stored by the backend as "Thưởng" (DefaultCategory).
  ///
  /// In en, this message translates to:
  /// **'Bonus'**
  String get categoryBonus;

  /// Default category stored by the backend as "Kinh doanh" (DefaultCategory).
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get categoryBusiness;

  /// Default category stored by the backend as "Đầu tư" (DefaultCategory).
  ///
  /// In en, this message translates to:
  /// **'Investment'**
  String get categoryInvestment;

  /// Default category stored by the backend as "Được tặng" (DefaultCategory).
  ///
  /// In en, this message translates to:
  /// **'Gifts received'**
  String get categoryGift;

  /// Default category stored by the backend as "Thu khác" (DefaultCategory).
  ///
  /// In en, this message translates to:
  /// **'Other income'**
  String get categoryOtherIncome;

  /// Title of the dialog shown when a required field of a form is empty.
  ///
  /// In en, this message translates to:
  /// **'Missing information'**
  String get authMissingInfoTitle;

  /// Label of the email field on the login and register screens.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmailLabel;

  /// Hint of the email field on the login and register screens.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address'**
  String get authEmailHint;

  /// Label of the password field on the login and register screens.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// Hint of the password field on the login and register screens.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get authPasswordHint;

  /// Button text while a login or save request is running.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get authProcessing;

  /// Title of the dialog shown when login fails.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get loginFailedTitle;

  /// Shown when the server answers 401 to a login.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password.'**
  String get loginWrongCredentials;

  /// Shown when a Google or Facebook login fails for an unknown reason.
  ///
  /// In en, this message translates to:
  /// **'Could not sign in with your social account. Please try again.'**
  String get loginSocialFailed;

  /// Shown when the login form is submitted with an empty field.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email and password.'**
  String get loginMissingCredentials;

  /// Shown when the login answer has no user id.
  ///
  /// In en, this message translates to:
  /// **'The server sent an invalid response. Please try again.'**
  String get loginInvalidResponse;

  /// Tagline under the app name on the login screen.
  ///
  /// In en, this message translates to:
  /// **'Smart personal finance'**
  String get loginTagline;

  /// Checkbox label on the login screen.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get loginRememberMe;

  /// Link from the login screen to the password recovery.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get loginForgotPassword;

  /// Login button.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get loginSubmit;

  /// First part of the sign-up link on the login screen; keep the trailing space.
  ///
  /// In en, this message translates to:
  /// **'No account yet? '**
  String get loginNoAccount;

  /// Second, highlighted part of the sign-up link on the login screen.
  ///
  /// In en, this message translates to:
  /// **'Sign up now'**
  String get loginSignUpNow;

  /// Divider text above the social login buttons.
  ///
  /// In en, this message translates to:
  /// **'Or log in with'**
  String get loginOrContinueWith;

  /// Heading of the register screen.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get registerHeading;

  /// Text under the heading of the register screen.
  ///
  /// In en, this message translates to:
  /// **'Fill in your details to start managing your finances.'**
  String get registerDescription;

  /// Label of the full name field on the register screen.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get registerFullNameLabel;

  /// Hint of the full name field on the register screen.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get registerFullNameHint;

  /// Label of the phone field on the register screen.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get registerPhoneLabel;

  /// Hint of the phone field on the register screen.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get registerPhoneHint;

  /// Register button.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get registerSubmit;

  /// Register footer, before the bold sign-in link
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get registerHaveAccount;

  /// Divider text above the social sign-up buttons.
  ///
  /// In en, this message translates to:
  /// **'Or sign up with'**
  String get registerOrContinueWith;

  /// First part of the terms sentence; keep the trailing space.
  ///
  /// In en, this message translates to:
  /// **'By signing up, you agree to the '**
  String get registerTermsPrefix;

  /// Highlighted part of the terms sentence.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get registerTerms;

  /// Joins the two highlighted parts of the terms sentence; keep both spaces.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get registerTermsAnd;

  /// Last highlighted part of the terms sentence.
  ///
  /// In en, this message translates to:
  /// **'Conditions of use'**
  String get registerConditions;

  /// Shown when the register form is submitted with an empty field.
  ///
  /// In en, this message translates to:
  /// **'Please fill in every field (including the phone number).'**
  String get registerMissingFields;

  /// Title of the dialog shown when the password does not meet the rules.
  ///
  /// In en, this message translates to:
  /// **'Weak password'**
  String get registerWeakPasswordTitle;

  /// Shown when the password misses a rule of the checklist.
  ///
  /// In en, this message translates to:
  /// **'The password does not meet the requirements yet.'**
  String get registerWeakPasswordMessage;

  /// Title of the dialog shown after a successful sign-up.
  ///
  /// In en, this message translates to:
  /// **'Sign-up successful'**
  String get registerSuccessTitle;

  /// Message of the dialog shown after a successful sign-up.
  ///
  /// In en, this message translates to:
  /// **'Your account has been created. Please log in.'**
  String get registerSuccessMessage;

  /// Title of the dialog shown when sign-up fails.
  ///
  /// In en, this message translates to:
  /// **'Sign-up failed'**
  String get registerFailedTitle;

  /// Shown when a Google or Facebook sign-up fails for an unknown reason.
  ///
  /// In en, this message translates to:
  /// **'Could not sign up with your social account. Please try again.'**
  String get registerSocialFailed;

  /// Heading of the password checklist.
  ///
  /// In en, this message translates to:
  /// **'Your password needs:'**
  String get registerPasswordNeeds;

  /// Password checklist rule.
  ///
  /// In en, this message translates to:
  /// **'At least {min} characters'**
  String registerRuleMinLength(int min);

  /// Password checklist rule.
  ///
  /// In en, this message translates to:
  /// **'An uppercase letter (A-Z)'**
  String get registerRuleUppercase;

  /// Password checklist rule.
  ///
  /// In en, this message translates to:
  /// **'A lowercase letter (a-z)'**
  String get registerRuleLowercase;

  /// Password checklist rule.
  ///
  /// In en, this message translates to:
  /// **'A digit (0-9)'**
  String get registerRuleDigit;

  /// Password checklist rule.
  ///
  /// In en, this message translates to:
  /// **'A special character (!@#...)'**
  String get registerRuleSpecial;

  /// Save button of the profile edit forms.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get commonSaveChanges;

  /// App bar title of the account credentials screen.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get credentialsTitle;

  /// Heading of the change password form.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get credentialsChangePassword;

  /// Label of the current password field.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get credentialsOldPassword;

  /// Shown when the current password field is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter your current password.'**
  String get credentialsOldPasswordRequired;

  /// Shown when the confirmation differs from the new password.
  ///
  /// In en, this message translates to:
  /// **'The new passwords do not match.'**
  String get credentialsPasswordMismatch;

  /// Title of the dialog shown when the password change fails.
  ///
  /// In en, this message translates to:
  /// **'Could not change the password'**
  String get credentialsChangePasswordFailed;

  /// Shown when the server refuses the password change (4xx) in a language the server does not write.
  ///
  /// In en, this message translates to:
  /// **'The password was not changed. Please check your current password and try again.'**
  String get credentialsChangePasswordRejected;

  /// Title of the dialog shown after the password change.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get credentialsChangePasswordSuccessTitle;

  /// App bar title of the account information screen.
  ///
  /// In en, this message translates to:
  /// **'Account information'**
  String get accountInfoTitle;

  /// Shown when an account row is tapped without a session.
  ///
  /// In en, this message translates to:
  /// **'Please log in again.'**
  String get accountInfoSignInAgain;

  /// Caption of the security group on the account information screen.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get accountSecurityTitle;

  /// Spoken label of the lock on the email row of the account information screen.
  ///
  /// In en, this message translates to:
  /// **'The sign-in email cannot be changed'**
  String get accountEmailLocked;

  /// Title of the sheet that edits the full name.
  ///
  /// In en, this message translates to:
  /// **'Edit full name'**
  String get accountEditNameTitle;

  /// Title of the sheet that edits the phone number.
  ///
  /// In en, this message translates to:
  /// **'Edit phone number'**
  String get accountEditPhoneTitle;

  /// Toast when the phone sheet is saved empty; the server cannot clear the phone.
  ///
  /// In en, this message translates to:
  /// **'Please enter a phone number.'**
  String get accountPhoneRequired;

  /// Message of the success view after the password change.
  ///
  /// In en, this message translates to:
  /// **'Your new password is in use. Other devices need to sign in again.'**
  String get changePasswordDoneMessage;

  /// Spoken label of the tick shown when the confirmation matches the new password.
  ///
  /// In en, this message translates to:
  /// **'Matches the new password'**
  String get changePasswordMatches;

  /// Title of the personal information screen and its row.
  ///
  /// In en, this message translates to:
  /// **'Personal information'**
  String get userInfoTitle;

  /// Shown instead of an empty phone number.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get userInfoNotSet;

  /// Title of a success dialog.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get commonSuccess;

  /// Title of the dialog shown when a save fails.
  ///
  /// In en, this message translates to:
  /// **'Could not save'**
  String get commonSaveFailed;

  /// Save button text while the save is running.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get commonSaving;

  /// Retry button.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonRetry;

  /// Shown when the profile edit screen cannot read the profile.
  ///
  /// In en, this message translates to:
  /// **'Could not load your personal information. Please try again.'**
  String get setUserInfoLoadFailed;

  /// Shown when the full name is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter your full name.'**
  String get setUserInfoNameRequired;

  /// Shown when the phone number does not match the format.
  ///
  /// In en, this message translates to:
  /// **'Invalid phone number (10 digits starting with 0).'**
  String get setUserInfoPhoneInvalid;

  /// Message of the dialog shown after the profile is saved.
  ///
  /// In en, this message translates to:
  /// **'Your personal information has been saved.'**
  String get setUserInfoSaved;

  /// Section title on the profile screen.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get profileUtilities;

  /// Profile row that opens the money sources sheet.
  ///
  /// In en, this message translates to:
  /// **'Money sources'**
  String get profileMoneySources;

  /// Profile row that opens the linked services screen.
  ///
  /// In en, this message translates to:
  /// **'Linked services'**
  String get profileLinkedServices;

  /// Profile row that opens the budget screen.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get profileBudget;

  /// Profile row that opens the security menu.
  ///
  /// In en, this message translates to:
  /// **'Security & privacy'**
  String get profileSecurityPrivacy;

  /// Section title on the profile screen.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get profileSupport;

  /// Profile row that opens the user guide.
  ///
  /// In en, this message translates to:
  /// **'User guide'**
  String get profileHelp;

  /// Profile row that opens the feedback form.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get profileFeedback;

  /// Profile row that opens the about sheet.
  ///
  /// In en, this message translates to:
  /// **'About the app'**
  String get profileAbout;

  /// Logout row and the confirm button of the logout dialog.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get profileLogout;

  /// Title of the logout confirmation.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get profileLogoutConfirmTitle;

  /// Message of the logout confirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get profileLogoutConfirmMessage;

  /// Short save button of sheets and dialogs.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// Title of the notification settings sheet.
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get notificationSettingsTitle;

  /// Switch of the notification settings sheet.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get notificationSettingsPush;

  /// Switch of the notification settings sheet.
  ///
  /// In en, this message translates to:
  /// **'Budget alerts'**
  String get notificationSettingsBudgetAlert;

  /// Snackbar after the notification settings are saved.
  ///
  /// In en, this message translates to:
  /// **'Notification settings saved.'**
  String get notificationSettingsSaved;

  /// Shown in the money sources sheet without wallets.
  ///
  /// In en, this message translates to:
  /// **'No wallets yet.'**
  String get moneySourcesEmpty;

  /// Security menu row that opens the activity history.
  ///
  /// In en, this message translates to:
  /// **'Activity history'**
  String get activityLogTitle;

  /// Subtitle of the activity history row.
  ///
  /// In en, this message translates to:
  /// **'See your recent transactions'**
  String get activityLogSubtitle;

  /// Title of the activity history sheet with the number of transactions.
  ///
  /// In en, this message translates to:
  /// **'Activity history ({count})'**
  String activityLogTitleCount(int count);

  /// Title of the feedback dialog (a star follows it).
  ///
  /// In en, this message translates to:
  /// **'Rate the app'**
  String get feedbackTitle;

  /// Hint of the feedback comment field.
  ///
  /// In en, this message translates to:
  /// **'Share your thoughts or suggestions...'**
  String get feedbackHint;

  /// Button that sends the feedback.
  ///
  /// In en, this message translates to:
  /// **'Send now'**
  String get feedbackSubmit;

  /// Snackbar after the feedback is sent.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your feedback!'**
  String get feedbackThanks;

  /// Snackbar when the feedback could not be sent.
  ///
  /// In en, this message translates to:
  /// **'Could not send your feedback, please try again later.'**
  String get feedbackFailed;

  /// Text of the about dialog.
  ///
  /// In en, this message translates to:
  /// **'A smart personal finance app with AI spending analysis.'**
  String get aboutDescription;

  /// Title of the appearance and language screen.
  ///
  /// In en, this message translates to:
  /// **'Appearance and language'**
  String get appearanceLanguageTitle;

  /// Label of the system theme preview card.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeCardSystem;

  /// Title of the sheet confirming a language change.
  ///
  /// In en, this message translates to:
  /// **'Switch to {language}?'**
  String languageConfirmTitle(String language);

  /// Message of the language change sheet.
  ///
  /// In en, this message translates to:
  /// **'All text in the app will switch to this language.'**
  String get languageConfirmMessage;

  /// Confirm button of the language change sheet.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get languageConfirmAction;

  /// Description of the push notification switch.
  ///
  /// In en, this message translates to:
  /// **'Get notifications on this phone'**
  String get notificationSettingsPushDescription;

  /// Description of the budget alert switch.
  ///
  /// In en, this message translates to:
  /// **'Alerts at 80% of a budget and when it is exceeded'**
  String get notificationSettingsBudgetAlertDescription;

  /// Last row of the money sources sheet.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get moneySourcesTotal;

  /// Description of the change password row in the security sheet.
  ///
  /// In en, this message translates to:
  /// **'Other devices will have to sign in again'**
  String get securityChangePasswordDescription;

  /// Guide step title.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get guideHomeTitle;

  /// Guide step text.
  ///
  /// In en, this message translates to:
  /// **'See your balance, this month\'s income and spending, your budget and recent transactions.'**
  String get guideHomeBody;

  /// Guide step title.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get guideStatsTitle;

  /// Guide step text.
  ///
  /// In en, this message translates to:
  /// **'See spending as a chart, a month calendar or by category; filter and export to Excel.'**
  String get guideStatsBody;

  /// Guide step title.
  ///
  /// In en, this message translates to:
  /// **'Scan receipts'**
  String get guideScanTitle;

  /// Guide step text.
  ///
  /// In en, this message translates to:
  /// **'Tap the round button in the middle of the bottom bar and take or pick a photo. The AI reads the store, the date and the total for you to check and save.'**
  String get guideScanBody;

  /// Guide step title.
  ///
  /// In en, this message translates to:
  /// **'Spending analysis'**
  String get guideAnalysisTitle;

  /// Guide step text.
  ///
  /// In en, this message translates to:
  /// **'See what you can spend each day, highlights, spending habits and balance tips.'**
  String get guideAnalysisBody;

  /// Guide step title.
  ///
  /// In en, this message translates to:
  /// **'Budgets and savings'**
  String get guideBudgetSavingsTitle;

  /// Guide step text.
  ///
  /// In en, this message translates to:
  /// **'Set spending limits per category and follow your savings goals.'**
  String get guideBudgetSavingsBody;

  /// Feedback suggestion chip.
  ///
  /// In en, this message translates to:
  /// **'Easy to use'**
  String get feedbackChipEasy;

  /// Feedback suggestion chip.
  ///
  /// In en, this message translates to:
  /// **'Accurate receipt scanning'**
  String get feedbackChipScan;

  /// Feedback suggestion chip.
  ///
  /// In en, this message translates to:
  /// **'Nice design'**
  String get feedbackChipLooks;

  /// Feedback suggestion chip.
  ///
  /// In en, this message translates to:
  /// **'Needs more features'**
  String get feedbackChipMore;

  /// Tooltip of a rating star.
  ///
  /// In en, this message translates to:
  /// **'{count} of 5 stars'**
  String feedbackStarLabel(int count);

  /// About sheet row.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get aboutVersion;

  /// About sheet row.
  ///
  /// In en, this message translates to:
  /// **'Developed by'**
  String get aboutDeveloper;

  /// About sheet value.
  ///
  /// In en, this message translates to:
  /// **'Team 7'**
  String get aboutDeveloperValue;

  /// About sheet row.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get aboutSchool;

  /// About sheet value.
  ///
  /// In en, this message translates to:
  /// **'HUIT'**
  String get aboutSchoolValue;

  /// About sheet row opening the licence page.
  ///
  /// In en, this message translates to:
  /// **'Open source licenses'**
  String get aboutLicenses;

  /// Title of the savings screen and its profile row.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get savingsTitle;

  /// Snackbar when a goal cannot be deleted; reason is the error text.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the goal. {reason}'**
  String savingsDeleteFailed(String reason);

  /// Snackbar after a goal is deleted.
  ///
  /// In en, this message translates to:
  /// **'Goal deleted: {title}'**
  String savingsDeleted(String title);

  /// Snackbar after a goal holding money is deleted; amount is what was refunded to the wallet.
  ///
  /// In en, this message translates to:
  /// **'Goal deleted: {title}. {amount} went back to your wallet.'**
  String savingsDeletedRefunded(String title, String amount);

  /// Title of the dialog that confirms deleting a savings goal.
  ///
  /// In en, this message translates to:
  /// **'Delete goal'**
  String get savingsDeleteTitle;

  /// Message of the delete goal dialog when nothing has been contributed yet.
  ///
  /// In en, this message translates to:
  /// **'Delete this goal?'**
  String get savingsDeleteConfirm;

  /// Message of the delete goal dialog when the goal holds money; amount is what goes back to the wallet.
  ///
  /// In en, this message translates to:
  /// **'Delete this goal? The {amount} contributed will be refunded to your wallet.'**
  String savingsDeleteConfirmRefund(String amount);

  /// Field of the add goal dialog.
  ///
  /// In en, this message translates to:
  /// **'Goal name'**
  String get savingsGoalName;

  /// Shown in the detail sheet of a savings contribution, which cannot be edited (nor deleted while the user has savings goals).
  ///
  /// In en, this message translates to:
  /// **'Savings contributions are managed on the Savings page.'**
  String get ledgerSavingsManagedByGoal;

  /// Label of the savings summary card.
  ///
  /// In en, this message translates to:
  /// **'Total saved'**
  String get savingsTotalSaved;

  /// Number of savings goals.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 goal} other{{count} goals}}'**
  String savingsGoalCount(int count);

  /// Total target of the savings summary card.
  ///
  /// In en, this message translates to:
  /// **'Target: {amount}'**
  String savingsTarget(String amount);

  /// Title of the dialog shown when a form is used without a signed-in user.
  ///
  /// In en, this message translates to:
  /// **'Session expired'**
  String get commonSessionExpiredTitle;

  /// Title of the dialog shown when the typed amount is not a positive number.
  ///
  /// In en, this message translates to:
  /// **'Invalid amount'**
  String get commonInvalidAmountTitle;

  /// The VND symbol shown after an amount field; the unit stays VND in every language.
  ///
  /// In en, this message translates to:
  /// **'đ'**
  String get currencySymbol;

  /// A transaction could not be saved for an unexpected reason.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the transaction. Please try again.'**
  String get transactionSaveFailed;

  /// Title when a new transaction was kept on the device but has not reached the server.
  ///
  /// In en, this message translates to:
  /// **'Not sent to the server yet'**
  String get transactionNotSentTitle;

  /// Explains how to resend a transaction kept on the device.
  ///
  /// In en, this message translates to:
  /// **'The transaction is saved on this device but hasn\'t reached the server yet. When you\'re back online, open Statistics, select the transaction and tap \"Resend\". Resending won\'t create a duplicate.'**
  String get transactionNotSentMessage;

  /// Label of the category field or column.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get transactionCategoryLabel;

  /// Label of the transaction date field.
  ///
  /// In en, this message translates to:
  /// **'Transaction date'**
  String get transactionDateLabel;

  /// Label of the optional note field.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get transactionNoteOptional;

  /// Title of the expense category picker.
  ///
  /// In en, this message translates to:
  /// **'Choose an expense category'**
  String get transactionPickExpenseCategory;

  /// Title of the income category picker.
  ///
  /// In en, this message translates to:
  /// **'Choose an income category'**
  String get transactionPickIncomeCategory;

  /// Money going out: the type toggle of the add form and the Excel column.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get transactionExpenseMoney;

  /// Money coming in: the type toggle of the add form and the Excel column.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get transactionIncomeMoney;

  /// The kind of an existing transaction that spends money.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get transactionExpenseKind;

  /// The kind of an existing transaction that brings money in.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get transactionIncomeKind;

  /// Title of the add transaction form.
  ///
  /// In en, this message translates to:
  /// **'Add transaction'**
  String get addTransactionTitle;

  /// Label of the amount field of the add form.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get addTransactionAmountLabel;

  /// Example note in the add form.
  ///
  /// In en, this message translates to:
  /// **'e.g. Coffee at Highlands'**
  String get addTransactionNoteHint;

  /// The server saved the new transaction.
  ///
  /// In en, this message translates to:
  /// **'New transaction added.'**
  String get addTransactionSaved;

  /// Last category tile of a transaction form: opens the full category list.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get categoryMoreTile;

  /// Tab of the add-transaction form for spending.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get transactionTabExpense;

  /// Tab of the add-transaction form for income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get transactionTabIncome;

  /// Tab of the add-transaction form: type the transaction in.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get addTransactionManualTab;

  /// Tab of the add-transaction form: opens the receipt scanner.
  ///
  /// In en, this message translates to:
  /// **'Scan receipt'**
  String get addTransactionScanTab;

  /// Button that saves a new spending.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get addTransactionSubmitExpense;

  /// Button that saves a new income.
  ///
  /// In en, this message translates to:
  /// **'Add income'**
  String get addTransactionSubmitIncome;

  /// Asked before the scanner replaces a form with typed data.
  ///
  /// In en, this message translates to:
  /// **'Discard this transaction?'**
  String get addTransactionDiscardTitle;

  /// Body of the discard question.
  ///
  /// In en, this message translates to:
  /// **'The amount and note you typed will not be saved.'**
  String get addTransactionDiscardMessage;

  /// Confirms leaving the form for the scanner.
  ///
  /// In en, this message translates to:
  /// **'Discard and scan'**
  String get addTransactionDiscardConfirm;

  /// Footer of the edit form's summary card: the type and the moment of the transaction.
  ///
  /// In en, this message translates to:
  /// **'{kind}, {time}'**
  String editTransactionSummaryLine(String kind, String time);

  /// Title of the edit form and the Ledger button that opens it.
  ///
  /// In en, this message translates to:
  /// **'Edit transaction'**
  String get editTransactionTitle;

  /// Title when the transaction has no server id.
  ///
  /// In en, this message translates to:
  /// **'Can\'t edit this transaction'**
  String get editTransactionNoServerIdTitle;

  /// The transaction has no server id, so it cannot be edited.
  ///
  /// In en, this message translates to:
  /// **'This transaction doesn\'t have a server ID yet.'**
  String get editTransactionNoServerIdMessage;

  /// Title when the server did not save the edit.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the transaction'**
  String get editTransactionSaveFailedTitle;

  /// A 4xx answer without a message from the server.
  ///
  /// In en, this message translates to:
  /// **'The server couldn\'t process the request. Please try again later.'**
  String get editTransactionRejected;

  /// Title when the edit was saved.
  ///
  /// In en, this message translates to:
  /// **'Changes saved'**
  String get editTransactionSavedTitle;

  /// The edit was saved.
  ///
  /// In en, this message translates to:
  /// **'The transaction has been updated.'**
  String get editTransactionSavedMessage;

  /// The category list could not be loaded.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the category list. You can still edit the amount and note.'**
  String get editTransactionCategoriesUnavailable;

  /// Title of the Ledger page.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get ledgerTitle;

  /// Hint of the Ledger search box.
  ///
  /// In en, this message translates to:
  /// **'Search name, category...'**
  String get ledgerSearchHint;

  /// Chart legend for income bars.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get ledgerLegendIncome;

  /// Chart legend for expense bars.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get ledgerLegendExpense;

  /// Short month label under a chart bar; month is the month number 1-12.
  ///
  /// In en, this message translates to:
  /// **'{month, select, 1{Jan} 2{Feb} 3{Mar} 4{Apr} 5{May} 6{Jun} 7{Jul} 8{Aug} 9{Sep} 10{Oct} 11{Nov} 12{Dec} other{{month}}}'**
  String ledgerChartMonth(String month);

  /// The period has no transactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions in this period.'**
  String get ledgerEmptyPeriod;

  /// Summary row and Excel row: income minus spending.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get ledgerBalance;

  /// Explains the Resend button.
  ///
  /// In en, this message translates to:
  /// **'The server hasn\'t confirmed this transaction yet. When you\'re back online, tap \"Resend\". Resending won\'t create a duplicate.'**
  String get ledgerDetailUnsyncedHint;

  /// Button that sends an unsynced transaction again.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get ledgerResend;

  /// Title of the delete confirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete transaction?'**
  String get ledgerDeleteTitle;

  /// Delete confirmation text.
  ///
  /// In en, this message translates to:
  /// **'The amount will go back to your wallet and this can\'t be undone. Are you sure?'**
  String get ledgerDeleteMessage;

  /// Confirm button of a delete dialog.
  ///
  /// In en, this message translates to:
  /// **'Delete now'**
  String get ledgerDeleteNow;

  /// Snack bar after a delete.
  ///
  /// In en, this message translates to:
  /// **'Transaction deleted and amount refunded'**
  String get ledgerDeleted;

  /// Snack bar when a delete failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete. Please try again'**
  String get ledgerDeleteFailed;

  /// Title when the server refused a resend.
  ///
  /// In en, this message translates to:
  /// **'Resend failed'**
  String get ledgerResendFailedTitle;

  /// A resend failed for an unexpected reason.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t resend the transaction. Please try again.'**
  String get ledgerResendFailedMessage;

  /// Snack bar after a successful resend.
  ///
  /// In en, this message translates to:
  /// **'Transaction sent to the server'**
  String get ledgerResent;

  /// Title when a resend did not reach the server.
  ///
  /// In en, this message translates to:
  /// **'Still not sent'**
  String get ledgerStillNotSentTitle;

  /// A resend did not reach the server.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server. The transaction stays on this device and you can resend it later.'**
  String get ledgerStillNotSentMessage;

  /// Title of the local delete confirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete unsent transaction?'**
  String get ledgerDeleteUnsyncedTitle;

  /// Local delete confirmation text.
  ///
  /// In en, this message translates to:
  /// **'The server hasn\'t confirmed this transaction. Remove it from this device and stop sending it? This can\'t be undone.'**
  String get ledgerDeleteUnsyncedMessage;

  /// Snack bar after a local delete.
  ///
  /// In en, this message translates to:
  /// **'Unsent transaction deleted'**
  String get ledgerDeletedUnsynced;

  /// Toast when the user deletes an unsent transaction that started being sent meanwhile.
  ///
  /// In en, this message translates to:
  /// **'This transaction is being sent. Try again in a moment.'**
  String get ledgerDeleteWhileSending;

  /// Notice above the list when the server list failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the list from the server. Only the unsent transactions on this device are shown. Pull down to try again.'**
  String get ledgerLoadFailedNotice;

  /// Excel sheet name (at most 31 characters) and share subject; month is numeric, e.g. '10-2026'.
  ///
  /// In en, this message translates to:
  /// **'Spending {month}'**
  String ledgerExcelSheet(String month);

  /// Excel column: date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get ledgerExcelDate;

  /// Excel row: totals.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get ledgerExcelTotal;

  /// Excel heading of the budget table; month is numeric, e.g. '10-2026'.
  ///
  /// In en, this message translates to:
  /// **'BUDGETS {month}'**
  String ledgerExcelBudgetHeader(String month);

  /// Excel column: budget limit.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get ledgerExcelLimit;

  /// Excel column: amount spent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get ledgerExcelSpent;

  /// Excel column: amount left.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get ledgerExcelRemaining;

  /// Excel column: amount of a refund or wallet transfer, which is neither income nor spending.
  ///
  /// In en, this message translates to:
  /// **'Not counted'**
  String get ledgerExcelNotCounted;

  /// Excel file name without extension, letters, digits, '_' and '-' only; name is '_' plus the user's name without diacritics or spaces, or empty when unknown, e.g. '_JohnDoe'; month is numeric, e.g. '10-2026'.
  ///
  /// In en, this message translates to:
  /// **'Spending{name}_{month}'**
  String ledgerExcelFileName(String name, String month);

  /// Text sent with the shared Excel file; month is numeric, e.g. '10-2026'.
  ///
  /// In en, this message translates to:
  /// **'Spending report for {month}'**
  String ledgerExcelShareText(String month);

  /// Toast when the Excel report could not be created, saved or shared.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t export the Excel file. Please try again.'**
  String get ledgerExcelFailed;

  /// Title of the receipt review form.
  ///
  /// In en, this message translates to:
  /// **'Confirm receipt'**
  String get reviewTitle;

  /// The scan found no total.
  ///
  /// In en, this message translates to:
  /// **'Donut couldn\'t read the total from the photo. Please enter it manually.'**
  String get reviewNoTotal;

  /// The scan request failed.
  ///
  /// In en, this message translates to:
  /// **'Receipt scan failed (check the AI service). Please enter the details manually.'**
  String get reviewScanFailed;

  /// Title when the photo upload failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t upload the receipt photo'**
  String get reviewPhotoUploadFailedTitle;

  /// Asks whether to save without the photo.
  ///
  /// In en, this message translates to:
  /// **'The receipt photo hasn\'t been uploaded to the server. Save the transaction without the photo?'**
  String get reviewPhotoUploadFailedMessage;

  /// Toast when the receipt photo could not be uploaded; reason is the user-facing text of the error.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t upload the photo: {reason}'**
  String reviewPhotoUploadFailedToast(String reason);

  /// Reason in the upload toast when the server refused the photo without saying why (400, 413).
  ///
  /// In en, this message translates to:
  /// **'The photo is too large or not an image the server accepts.'**
  String get reviewPhotoRejected;

  /// Confirm button: save without the photo.
  ///
  /// In en, this message translates to:
  /// **'Save without photo'**
  String get reviewSaveWithoutPhoto;

  /// Cancel button: do not save now.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get reviewLater;

  /// The server saved the receipt transaction.
  ///
  /// In en, this message translates to:
  /// **'Transaction saved from the receipt.'**
  String get reviewSaved;

  /// Done step of the receipt review band.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get reviewStepPhoto;

  /// Current step of the receipt review band.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get reviewStepCheck;

  /// Last step of the receipt review band.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get reviewStepSave;

  /// Pill on the receipt photo that opens the viewer.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get reviewZoom;

  /// Pill in the review band: photo and fields side by side.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get reviewCompare;

  /// Marks a field the AI is not sure about.
  ///
  /// In en, this message translates to:
  /// **'Check this'**
  String get reviewNeedsCheck;

  /// Hint under an unsure store name.
  ///
  /// In en, this message translates to:
  /// **'Store name may be wrong, please correct it.'**
  String get reviewStoreHint;

  /// Hint under an unsure total.
  ///
  /// In en, this message translates to:
  /// **'Total may be wrong, compare it with the photo.'**
  String get reviewTotalHint;

  /// Hint under a date the AI could not read.
  ///
  /// In en, this message translates to:
  /// **'Could not read the date; pick it if it was not today.'**
  String get reviewDateHint;

  /// Label of the receipt total field.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get reviewTotal;

  /// Hint under a date the AI read but doubts.
  ///
  /// In en, this message translates to:
  /// **'Date may be wrong, compare it with the photo.'**
  String get reviewDateDoubtHint;

  /// Secondary button: saves and goes on scanning.
  ///
  /// In en, this message translates to:
  /// **'Save & scan next'**
  String get reviewSaveAndScan;

  /// Main button of the receipt review form.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get reviewSave;

  /// Shown while the scan runs.
  ///
  /// In en, this message translates to:
  /// **'Analyzing the receipt...'**
  String get reviewAnalyzing;

  /// Shown while the scan runs.
  ///
  /// In en, this message translates to:
  /// **'This will only take a moment'**
  String get reviewPleaseWait;

  /// Label of the store name field.
  ///
  /// In en, this message translates to:
  /// **'Store name'**
  String get reviewStoreName;

  /// Label of the optional store address field of the review form.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get reviewAddress;

  /// Hint under an unsure store address.
  ///
  /// In en, this message translates to:
  /// **'Address may be wrong, please correct it.'**
  String get reviewAddressHint;

  /// Title of the payment history page.
  ///
  /// In en, this message translates to:
  /// **'Deposit/withdrawal history'**
  String get paymentHistoryTitle;

  /// The history could not be loaded; reason is a user-facing error text.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the history. {reason}'**
  String paymentHistoryLoadFailed(String reason);

  /// The history is empty.
  ///
  /// In en, this message translates to:
  /// **'No deposits or withdrawals yet.'**
  String get paymentHistoryEmpty;

  /// Snack bar after cancelling an order.
  ///
  /// In en, this message translates to:
  /// **'Order {code} cancelled'**
  String paymentCancelled(String code);

  /// Cancelling failed; reason is a user-facing error text.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t cancel the order. {reason}'**
  String paymentCancelFailed(String reason);

  /// Order type: deposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get paymentDeposit;

  /// Order type: withdrawal.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal'**
  String get paymentWithdrawal;

  /// Button that cancels a pending order.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get paymentCancelOrder;

  /// Order status SUCCESS.
  ///
  /// In en, this message translates to:
  /// **'Successful'**
  String get paymentStatusSuccess;

  /// Order status FAILED.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get paymentStatusFailed;

  /// Order status CANCELLED.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get paymentStatusCancelled;

  /// Order status PENDING.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get paymentStatusPending;

  /// Creating the order failed; reason is a user-facing error text.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the sync order. {reason}'**
  String linkedCreateOrderFailed(String reason);

  /// The payment status did not change in time.
  ///
  /// In en, this message translates to:
  /// **'No payment result yet. Please check again in the sync history.'**
  String get linkedPollTimedOut;

  /// The payment page of a new sync order could not be opened, so nothing is waited for.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the payment page. Please try again.'**
  String get linkedOpenPayUrlFailed;

  /// Name of the demo e-wallet.
  ///
  /// In en, this message translates to:
  /// **'Demo wallet'**
  String get linkedDemoWallet;

  /// Button that syncs money from a wallet.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get linkedSync;

  /// The payment succeeded.
  ///
  /// In en, this message translates to:
  /// **'Synced {amount} to your spending budget.'**
  String linkedSynced(String amount);

  /// The payment ended without success; status is a translated order status.
  ///
  /// In en, this message translates to:
  /// **'Sync: {status}'**
  String linkedSyncOutcome(String status);

  /// Tooltip of the history button.
  ///
  /// In en, this message translates to:
  /// **'Sync history'**
  String get linkedHistoryTooltip;

  /// Explains the wallet list.
  ///
  /// In en, this message translates to:
  /// **'Sync money from a wallet into your budget to manage spending.'**
  String get linkedWalletsDescription;

  /// Status of a linked wallet.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get linkedLinked;

  /// Banner while a sync waits for the payment gateway.
  ///
  /// In en, this message translates to:
  /// **'Syncing {amount} from {wallet}… finish the payment on the gateway.'**
  String linkedSyncingFrom(String amount, String wallet);

  /// Title of the amount sheet of a wallet sync.
  ///
  /// In en, this message translates to:
  /// **'Sync money'**
  String get linkedSheetTitle;

  /// Wallet card of the amount sheet.
  ///
  /// In en, this message translates to:
  /// **'From {wallet}'**
  String linkedSheetFrom(String wallet);

  /// Second line of the wallet card of the amount sheet.
  ///
  /// In en, this message translates to:
  /// **'Into your spending budget'**
  String get linkedSheetTarget;

  /// Label of the amount field of a wallet sync.
  ///
  /// In en, this message translates to:
  /// **'Amount to add'**
  String get linkedAmountLabel;

  /// Line under the quick amounts of a wallet sync.
  ///
  /// In en, this message translates to:
  /// **'Minimum {amount}. You will be taken to the {wallet} gateway to pay.'**
  String linkedMinAmountHint(String amount, String wallet);

  /// Error line under the amount of a wallet sync while the amount is above the limit of one payment order.
  ///
  /// In en, this message translates to:
  /// **'At most {amount} per sync.'**
  String linkedMaxAmountHint(String amount);

  /// Button of the amount sheet.
  ///
  /// In en, this message translates to:
  /// **'Continue to payment'**
  String get linkedContinuePayment;

  /// Title of the order details sheet.
  ///
  /// In en, this message translates to:
  /// **'Order details'**
  String get paymentOrderDetails;

  /// Wallet row of the order details sheet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get paymentDetailWallet;

  /// Order code row of the order details sheet.
  ///
  /// In en, this message translates to:
  /// **'Order code'**
  String get paymentDetailCode;

  /// Time row of the order details sheet.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get paymentDetailTime;

  /// Button that deletes an item.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// Button that applies a choice (e.g. a date range).
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get commonApply;

  /// The current calendar week.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get periodThisWeek;

  /// The current calendar month.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get periodThisMonth;

  /// A range of days the user picks.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get periodCustom;

  /// Title of the budget screen and of the budget block.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get budgetTitle;

  /// Title of the 80% budget alert.
  ///
  /// In en, this message translates to:
  /// **'Budget almost used up'**
  String get budgetAlertWarningTitle;

  /// Title of the 100% budget alert.
  ///
  /// In en, this message translates to:
  /// **'Budget exceeded'**
  String get budgetAlertExceededTitle;

  /// One exceeded budget in the alert; period is the lowercase period name, amounts is "spent / limit".
  ///
  /// In en, this message translates to:
  /// **'• {name} (per {period}): over the limit — {amounts} ({percent}%)'**
  String budgetAlertExceededLine(
    String name,
    String period,
    String amounts,
    String percent,
  );

  /// One budget at 80% or more in the alert; period is the lowercase period name, amounts is "spent / limit".
  ///
  /// In en, this message translates to:
  /// **'• {name} (per {period}): {percent}% of the limit used — {amounts}'**
  String budgetAlertWarningLine(
    String name,
    String period,
    String amounts,
    String percent,
  );

  /// Error title when the budget list fails to load.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your budgets'**
  String get budgetLoadFailedTitle;

  /// Title of the delete confirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete budget?'**
  String get budgetDeleteTitle;

  /// Delete confirmation; name is the category label.
  ///
  /// In en, this message translates to:
  /// **'The budget \"{name}\" will be deleted.'**
  String budgetDeleteMessage(String name);

  /// Error title when a delete fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the budget'**
  String get budgetDeleteFailedTitle;

  /// Shown after a delete.
  ///
  /// In en, this message translates to:
  /// **'Budget deleted'**
  String get budgetDeleted;

  /// Hint under the empty budget list.
  ///
  /// In en, this message translates to:
  /// **'Set a weekly or monthly spending limit to stay in control.'**
  String get budgetEmptyHint;

  /// Button and form title for a new budget.
  ///
  /// In en, this message translates to:
  /// **'Set up a budget'**
  String get budgetCreate;

  /// Form title for an existing budget.
  ///
  /// In en, this message translates to:
  /// **'Edit budget'**
  String get budgetEditTitle;

  /// Label of the amount field.
  ///
  /// In en, this message translates to:
  /// **'Budget amount (₫)'**
  String get budgetAmountLabel;

  /// Label of the week/month choice.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get budgetPeriodLabel;

  /// The dates an edited budget keeps.
  ///
  /// In en, this message translates to:
  /// **'Applied period'**
  String get budgetAppliedPeriod;

  /// Submit button of the budget form.
  ///
  /// In en, this message translates to:
  /// **'Save budget'**
  String get budgetSave;

  /// Error title when saving fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the budget'**
  String get budgetSaveFailedTitle;

  /// Shown after a save.
  ///
  /// In en, this message translates to:
  /// **'Budget saved'**
  String get budgetSavedTitle;

  /// Shown after a save.
  ///
  /// In en, this message translates to:
  /// **'Your spending limit has been updated.'**
  String get budgetSavedMessage;

  /// The category list of the form failed to load.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the categories'**
  String get budgetCategoriesLoadFailedTitle;

  /// allLabel is the "all categories" option.
  ///
  /// In en, this message translates to:
  /// **'You can still choose \"{allLabel}\" or try again later.'**
  String budgetCategoriesLoadFailedMessage(String allLabel);

  /// Greeting above the user name.
  ///
  /// In en, this message translates to:
  /// **'Hello,'**
  String get dashboardGreeting;

  /// Label of the balance on the home band.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get dashboardBalance;

  /// Note under the balance: the signed total of the transactions still waiting to be sent, which the balance does not include.
  ///
  /// In en, this message translates to:
  /// **'Excludes {amount} from transactions waiting to be sent'**
  String dashboardPendingNotInBalance(String amount);

  /// Pill on the home band: the income of this month, in compact form.
  ///
  /// In en, this message translates to:
  /// **'In {amount}'**
  String dashboardMonthIncome(String amount);

  /// Pill on the home band: the spending of this month, in compact form.
  ///
  /// In en, this message translates to:
  /// **'Out {amount}'**
  String dashboardMonthExpense(String amount);

  /// Tooltip of the eye button while the amounts are hidden.
  ///
  /// In en, this message translates to:
  /// **'Show amounts'**
  String get dashboardShowAmounts;

  /// Tooltip of the eye button while the amounts are shown.
  ///
  /// In en, this message translates to:
  /// **'Hide amounts'**
  String get dashboardHideAmounts;

  /// Label of the savings shortcut on the home band.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get dashboardSavingsShort;

  /// Main line of the home budget band: what is left of the budget total and how many days its period still has, today included.
  ///
  /// In en, this message translates to:
  /// **'{amount} left for {days, plural, =1{1 day} other{{days} days}}'**
  String homeBudgetLeft(String amount, int days);

  /// Main line of the home budget band once the total is exceeded.
  ///
  /// In en, this message translates to:
  /// **'Over by {amount}'**
  String homeBudgetOver(String amount);

  /// Second line of the home budget band: the category budget exceeded the most.
  ///
  /// In en, this message translates to:
  /// **'{category} is over by {amount}'**
  String homeBudgetCategoryOver(String category, String amount);

  /// Second line of the home budget band: the category budget closest to its limit, past 80%.
  ///
  /// In en, this message translates to:
  /// **'{category} has used {percent}%'**
  String homeBudgetCategoryNear(String category, int percent);

  /// Button of the home budget band that opens the budget screen.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get homeBudgetView;

  /// Home budget band when no budget runs today.
  ///
  /// In en, this message translates to:
  /// **'Set this month\'s budget'**
  String get homeBudgetEmptyTitle;

  /// Second line of the home budget band when no budget runs today.
  ///
  /// In en, this message translates to:
  /// **'See how much is left for each day'**
  String get homeBudgetEmptyHint;

  /// Button of the home budget band that opens the budget screen to set a budget.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get homeBudgetSet;

  /// Home budget band when the budgets could not be loaded.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load budgets'**
  String get homeBudgetFailed;

  /// Title of the recent transactions card on the home screen.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get dashboardRecent;

  /// Link next to the recent transactions title: opens the statistics tab.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get dashboardSeeAll;

  /// Error state of the home screen when its first load failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the home screen'**
  String get dashboardLoadFailedTitle;

  /// Under the error title of the home screen.
  ///
  /// In en, this message translates to:
  /// **'Check the connection and try again.'**
  String get dashboardLoadFailedMessage;

  /// The recent transaction list is empty.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet.'**
  String get dashboardNoTransactions;

  /// Under the money sources title.
  ///
  /// In en, this message translates to:
  /// **'Wallets linked to your account'**
  String get moneySourcesSubtitle;

  /// Title of the feature sheet.
  ///
  /// In en, this message translates to:
  /// **'All features'**
  String get allFeaturesTitle;

  /// Under the savings feature.
  ///
  /// In en, this message translates to:
  /// **'Manage savings goals'**
  String get featureSavingsDescription;

  /// Under the money sources feature.
  ///
  /// In en, this message translates to:
  /// **'See wallets and balances'**
  String get featureMoneySourcesDescription;

  /// Under the linked services feature.
  ///
  /// In en, this message translates to:
  /// **'MoMo, ZaloPay, banks...'**
  String get featureLinkedServicesDescription;

  /// AI tab band: label above today's allowance.
  ///
  /// In en, this message translates to:
  /// **'You can spend today'**
  String get aiTodayLabel;

  /// AI tab band: days left in the month, today included.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{last day} other{{days} days left}}'**
  String aiTodayDaysLeft(int days);

  /// AI tab band: spent today; amount is formatted money.
  ///
  /// In en, this message translates to:
  /// **'Spent {amount}'**
  String aiTodaySpent(String amount);

  /// AI tab band: what is left of today's allowance.
  ///
  /// In en, this message translates to:
  /// **'{amount} left today'**
  String aiTodayLeft(String amount);

  /// AI tab band: spent past today's allowance.
  ///
  /// In en, this message translates to:
  /// **'{amount} over today'**
  String aiTodayOver(String amount);

  /// AI tab section title.
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get aiHighlightsTitle;

  /// Highlights: second line of the spending trend row.
  ///
  /// In en, this message translates to:
  /// **'Compared with the same days last month'**
  String get aiTrendVsLastMonth;

  /// Highlights: top category and what was spent on it.
  ///
  /// In en, this message translates to:
  /// **'{category}, {amount}'**
  String aiTopCategoryLine(String category, String amount);

  /// Highlights: saving tip when money is left and there is no goal.
  ///
  /// In en, this message translates to:
  /// **'Money left this month: set a goal'**
  String get aiTipSurplus;

  /// Highlights: saving tip when the month does not cover the goal; the pill shows the amount.
  ///
  /// In en, this message translates to:
  /// **'Still to put into your goal this month'**
  String get aiTipNeedMore;

  /// Highlights: saving tip when the month covers the goal.
  ///
  /// In en, this message translates to:
  /// **'On track for your goal'**
  String get aiTipOnTrack;

  /// Highlights: saving tip when contributions cover the goal but the month spent more than its income.
  ///
  /// In en, this message translates to:
  /// **'Goal covered, but this month is spending more than came in'**
  String get aiTipOverspent;

  /// Highlights: this week so far against the same days of last week; compact money.
  ///
  /// In en, this message translates to:
  /// **'{thisWeek} / last week {lastWeek}'**
  String aiWeekCompareLine(String thisWeek, String lastWeek);

  /// Highlights: week comparison without spending.
  ///
  /// In en, this message translates to:
  /// **'No spending in these two weeks'**
  String get aiWeekCompareNone;

  /// Highlights: title of the top week row.
  ///
  /// In en, this message translates to:
  /// **'Top spending week'**
  String get aiTopWeekTitle;

  /// Highlights: week is 1-4.
  ///
  /// In en, this message translates to:
  /// **'Week {week} of this month'**
  String aiTopWeekLine(int week);

  /// AI tab section title above the area chart.
  ///
  /// In en, this message translates to:
  /// **'Daily spending'**
  String get aiDailyChartTitle;

  /// Title of the date sheet for the first day of a custom range.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get aiPickRangeStart;

  /// Title of the date sheet for the last day of a custom range.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get aiPickRangeEnd;

  /// AI tab section title.
  ///
  /// In en, this message translates to:
  /// **'Spending habits'**
  String get aiHabitsTitle;

  /// Habits: weeks with spending that the analysis looked at.
  ///
  /// In en, this message translates to:
  /// **'{weeks, plural, =1{Seen in the last week} other{Repeated over the last {weeks} weeks}}'**
  String aiHabitRepeat(int weeks);

  /// Habits: how many weeks a sequence came back in.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{once} other{{count} times}}'**
  String aiTimes(int count);

  /// Habits: mean gap of a periodic expense; days is a formatted decimal.
  ///
  /// In en, this message translates to:
  /// **'About every {days} days'**
  String aiHabitEvery(String days);

  /// Habits: pill of a periodic expense whose expected date is past; date is dd/MM.
  ///
  /// In en, this message translates to:
  /// **'Last on {date}'**
  String aiHabitLastOn(String date);

  /// Habits: prediction when this week already has the first categories.
  ///
  /// In en, this message translates to:
  /// **'Coming up: after {from} you usually spend on {to}.'**
  String aiHabitUpcoming(String from, String to);

  /// Habits: a habit that is not under way this week.
  ///
  /// In en, this message translates to:
  /// **'After {from} you usually spend on {to}.'**
  String aiHabitUsually(String from, String to);

  /// AI tab section title (50/30/20).
  ///
  /// In en, this message translates to:
  /// **'Spending balance'**
  String get aiBalanceTitle;

  /// Balance: share of the month's income and its target.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of income, about {target}% advised'**
  String aiBalanceLine(int percent, int target);

  /// Balance: the saved share.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get aiBalanceSavings;

  /// Pill: the share is where it should be.
  ///
  /// In en, this message translates to:
  /// **'On track'**
  String get aiLevelOk;

  /// Pill: the share is above its target.
  ///
  /// In en, this message translates to:
  /// **'A bit high'**
  String get aiLevelHigh;

  /// Pill: the share is below its target.
  ///
  /// In en, this message translates to:
  /// **'A bit low'**
  String get aiLevelLow;

  /// Advice box: one recommendation of the budget advisor; formatted money.
  ///
  /// In en, this message translates to:
  /// **'{category}: {current} → {suggested} / month'**
  String aiAdviceLine(String category, String current, String suggested);

  /// AI tab without any transaction.
  ///
  /// In en, this message translates to:
  /// **'Add transactions to see your spending analysis.'**
  String get aiNoDataMessage;

  /// The AI service did not answer.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the analysis server. Please check your connection and try again.'**
  String get aiErrorNetwork;

  /// The AI service answered 5xx.
  ///
  /// In en, this message translates to:
  /// **'The analysis server ran into a problem. Please try again later.'**
  String get aiErrorServer;

  /// The AI service answered 4xx.
  ///
  /// In en, this message translates to:
  /// **'The analysis server couldn\'t process the request. Please try again later.'**
  String get aiErrorRejected;

  /// Error title of a failed analysis.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t analyse your spending habits'**
  String get aiAnalyzeFailedTitle;

  /// The user has no transactions.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get aiNoData;

  /// Insight card title.
  ///
  /// In en, this message translates to:
  /// **'Spending trend'**
  String get aiTrendTitle;

  /// Insight card title.
  ///
  /// In en, this message translates to:
  /// **'Top spending'**
  String get aiTopCategoryTitle;

  /// Insight card title.
  ///
  /// In en, this message translates to:
  /// **'Saving tip'**
  String get aiSavingTipTitle;

  /// Insight card title.
  ///
  /// In en, this message translates to:
  /// **'Week comparison'**
  String get aiWeekCompareTitle;

  /// No income this month.
  ///
  /// In en, this message translates to:
  /// **'Add this month\'s income to work out a safe amount.'**
  String get aiSafeToSpendNoIncome;

  /// The safe amount is below zero.
  ///
  /// In en, this message translates to:
  /// **'You\'ve spent past this month\'s safe share.'**
  String get aiOverSafe;

  /// No spending last month to compare with.
  ///
  /// In en, this message translates to:
  /// **'You\'ve spent {amount} this month.'**
  String aiSpentThisMonth(String amount);

  /// Top category card without spending.
  ///
  /// In en, this message translates to:
  /// **'No spending this month yet.'**
  String get aiNoSpendingThisMonth;

  /// No savings goal yet.
  ///
  /// In en, this message translates to:
  /// **'Add a savings goal for the AI to analyse.'**
  String get aiAddGoal;

  /// Savings tip: the urgent goal has no deadline, so no monthly need.
  ///
  /// In en, this message translates to:
  /// **'This goal has no deadline, contribute whenever you can'**
  String get aiGoalNoDeadline;

  /// Savings tip: the urgent goal has a deadline that is already past.
  ///
  /// In en, this message translates to:
  /// **'This goal is past its deadline: set a new date or keep contributing'**
  String get aiGoalOverdue;

  /// AI tab: title of the error state when the first load of the transactions failed and there is nothing to show.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your data'**
  String get aiLoadFailedTitle;

  /// AI tab: notice above the cards when a refresh failed; the data shown is the one loaded before. Followed by a retry button.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh your data. You are seeing what was loaded earlier.'**
  String get aiLoadFailedNotice;

  /// The last analysis failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the analysis'**
  String get aiSpadeLoadFailedTitle;

  /// The last analysis failed.
  ///
  /// In en, this message translates to:
  /// **'Check your connection, then refresh to try again.'**
  String get aiSpadeLoadFailedMessage;

  /// No pattern found.
  ///
  /// In en, this message translates to:
  /// **'Not enough data'**
  String get aiSpadeNotEnoughTitle;

  /// Not enough weeks of spending for the sequence mining.
  ///
  /// In en, this message translates to:
  /// **'Only {weeks} weeks with spending so far; at least {minWeeks} weeks are needed to look for sequences.'**
  String aiSpadeNotEnoughWeeks(int weeks, int minWeeks);

  /// Not enough history and the server did not say how much is needed.
  ///
  /// In en, this message translates to:
  /// **'Not enough spending history to look for sequences.'**
  String get aiSpadeNotEnoughUnknown;

  /// No spending to analyse.
  ///
  /// In en, this message translates to:
  /// **'No spending in the last 26 weeks yet.'**
  String get aiSpadeNotEnoughNone;

  /// Enough weeks, but no sequence repeats often enough.
  ///
  /// In en, this message translates to:
  /// **'No sequence yet'**
  String get aiSpadeNoPatternTitle;

  /// Enough weeks, but no sequence repeats often enough.
  ///
  /// In en, this message translates to:
  /// **'No sequence of spending repeats in enough weeks yet.'**
  String get aiSpadeNoPatternMessage;

  /// Needs share row.
  ///
  /// In en, this message translates to:
  /// **'Needs'**
  String get ai503020Needs;

  /// Wants share row.
  ///
  /// In en, this message translates to:
  /// **'Wants'**
  String get ai503020Wants;

  /// Advice when every share is on target.
  ///
  /// In en, this message translates to:
  /// **'This month\'s spending meets the 50/30/20 rule. Keep it up!'**
  String get ai503020OnTrack;

  /// percent is a whole number.
  ///
  /// In en, this message translates to:
  /// **'Needs take {percent}% of your income (target ≤50%). Check Living costs/Supermarket for anything you can trim.'**
  String ai503020NeedsHigh(String percent);

  /// percent is a whole number.
  ///
  /// In en, this message translates to:
  /// **'Wants (Entertainment, Other) take {percent}% of your income (target ≤30%) — the easiest place to cut.'**
  String ai503020WantsHigh(String percent);

  /// percent is a whole number.
  ///
  /// In en, this message translates to:
  /// **'You\'ve saved only {percent}% of your income (target ≥20%). Raise it a little each month.'**
  String ai503020SavingsLow(String percent);

  /// Chip of the shared date field that picks today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dateFieldToday;

  /// Chip of the shared date field that picks yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get dateFieldYesterday;

  /// Accessibility label of the shared date field, which opens the date picker.
  ///
  /// In en, this message translates to:
  /// **'Choose a date'**
  String get dateFieldPick;

  /// Home screen shortcut that opens the receipt scan options (same sheet as the scan button).
  ///
  /// In en, this message translates to:
  /// **'Scan receipt'**
  String get dashboardScanReceipt;

  /// Accessibility label of the receipt thumbnail on the review form, and title of the full-screen photo viewer it opens.
  ///
  /// In en, this message translates to:
  /// **'Receipt photo'**
  String get reviewOpenImage;

  /// Tooltip of the review form button that shows the photo above the fields.
  ///
  /// In en, this message translates to:
  /// **'Compare with the photo'**
  String get reviewCompareOn;

  /// Tooltip of the review form button that goes back to the normal layout.
  ///
  /// In en, this message translates to:
  /// **'Leave compare mode'**
  String get reviewCompareOff;

  /// Note under the date of a receipt that is not from the current month; day is dd/MM.
  ///
  /// In en, this message translates to:
  /// **'A transaction dated {day} still counts toward your current balance'**
  String reviewOtherMonthBalanceNote(String day);

  /// Title of the dialog shown when the server takes a scanned receipt for one already saved; date is dd/MM/yyyy HH:mm of the saved transaction.
  ///
  /// In en, this message translates to:
  /// **'This receipt seems to have been saved on {date}'**
  String reviewDuplicateTitle(String date);

  /// Title of the duplicate receipt dialog when the server sent no date.
  ///
  /// In en, this message translates to:
  /// **'This receipt seems to have been saved before'**
  String get reviewDuplicateTitleNoDate;

  /// Body of the duplicate receipt dialog.
  ///
  /// In en, this message translates to:
  /// **'Open the saved one to check it, or save anyway if this is another purchase.'**
  String get reviewDuplicateMessage;

  /// Duplicate receipt dialog button that opens the transaction already saved.
  ///
  /// In en, this message translates to:
  /// **'View saved one'**
  String get reviewDuplicateView;

  /// Duplicate receipt dialog button that saves the receipt again.
  ///
  /// In en, this message translates to:
  /// **'Save anyway'**
  String get reviewDuplicateSaveAnyway;

  /// Toast when the review form has no way to open the saved transaction.
  ///
  /// In en, this message translates to:
  /// **'The saved one can\'t be opened from here. You can find it in the Statistics tab.'**
  String get reviewDuplicateCannotOpen;

  /// Badge on the linked services page and its profile row: the wallets are simulated.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get linkedDemoBadge;

  /// Notice at the top of the linked services page.
  ///
  /// In en, this message translates to:
  /// **'This is a demo: the wallets and synced payments are simulated, with no real bank or e-wallet connection.'**
  String get linkedDemoNotice;

  /// Yearly budget period; also the year mode of the Ledger.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get budgetPeriodYear;

  /// The current calendar year.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get periodThisYear;

  /// Field shown when the budget category is 'Other'.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get budgetCustomCategoryLabel;

  /// Helper under the custom category name field.
  ///
  /// In en, this message translates to:
  /// **'A new category is created if needed. Use this exact name in your transactions so they count'**
  String get budgetCustomCategoryHelper;

  /// Error when the custom category name is empty.
  ///
  /// In en, this message translates to:
  /// **'Enter the category name'**
  String get budgetCustomCategoryRequired;

  /// Error when the custom category name is too long.
  ///
  /// In en, this message translates to:
  /// **'At most {max} characters'**
  String budgetCustomCategoryTooLong(int max);

  /// Header of the budget group whose limit is passed.
  ///
  /// In en, this message translates to:
  /// **'Over budget'**
  String get budgetGroupOver;

  /// Header of the budget group still within the limit.
  ///
  /// In en, this message translates to:
  /// **'On track'**
  String get budgetGroupWithin;

  /// How many budgets a group holds, at the end of its header.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 budget} other{{count} budgets}}'**
  String budgetGroupCount(int count);

  /// What is left of a budget, compact amount.
  ///
  /// In en, this message translates to:
  /// **'{amount} left'**
  String budgetLeft(String amount);

  /// How much a budget is exceeded by, compact amount.
  ///
  /// In en, this message translates to:
  /// **'{amount} over'**
  String budgetOver(String amount);

  /// Spent and limit of a budget, compact amounts.
  ///
  /// In en, this message translates to:
  /// **'{spent} / {limit}'**
  String budgetAmounts(String spent, String limit);

  /// Title of the budget screen when the selected tab has no running budget.
  ///
  /// In en, this message translates to:
  /// **'No budget for this period'**
  String get budgetEmptyPeriod;

  /// Period label of the Ledger in year mode.
  ///
  /// In en, this message translates to:
  /// **'Year {year}'**
  String ledgerYearLabel(String year);

  /// Default expense category 'savings': money moved into a savings goal.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get categorySavings;

  /// Tooltip of the button that removes the target date.
  ///
  /// In en, this message translates to:
  /// **'Remove the target date'**
  String get savingsTargetDateClear;

  /// Button of a goal that moves money from the wallet into it.
  ///
  /// In en, this message translates to:
  /// **'Add money'**
  String get savingsContribute;

  /// Toast when a contribution fails; reason is the error text.
  ///
  /// In en, this message translates to:
  /// **'Could not add the money. {reason}'**
  String savingsContributeFailed(String reason);

  /// Reason shown when the server refuses a contribution and its message cannot be shown.
  ///
  /// In en, this message translates to:
  /// **'Check the amount and your wallet balance.'**
  String get savingsContributeRejected;

  /// Toast after a contribution.
  ///
  /// In en, this message translates to:
  /// **'Money added to \"{title}\"'**
  String savingsContributed(String title);

  /// Toast when a contribution completes the goal.
  ///
  /// In en, this message translates to:
  /// **'Congratulations! You reached your goal \"{title}\"'**
  String savingsGoalReached(String title);

  /// Toast after receipts were queued for reading.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 receipt added to the queue} other{{count} receipts added to the queue}}'**
  String scanQueueAdded(int count);

  /// Toast after queueing when some images were left out because the queue holds at most limit receipts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 receipt added to the queue} other{{count} receipts added to the queue}} ({skipped} skipped, over {limit})'**
  String scanQueueOverLimit(int count, int skipped, int limit);

  /// Banner above the tab bar while the queue reads receipts.
  ///
  /// In en, this message translates to:
  /// **'Reading receipt {current}/{total}'**
  String scanQueueReading(int current, int total);

  /// Banner above the tab bar when read receipts wait for a confirmation.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 receipt to confirm} other{{count} receipts to confirm}}'**
  String scanQueueReady(int count);

  /// Banner above the tab bar when only failed receipts are left in the queue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 receipt could not be read} other{{count} receipts could not be read}}'**
  String scanQueueFailed(int count);

  /// Toast when the scan queue could not be read or written on the device.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the receipt queue on this device. Please try again.'**
  String get scanQueueStorageFailed;

  /// Title of the screen listing the queued receipts.
  ///
  /// In en, this message translates to:
  /// **'Receipts to confirm'**
  String get pendingReceiptsTitle;

  /// Shown when the scan queue is empty.
  ///
  /// In en, this message translates to:
  /// **'No receipts waiting.'**
  String get pendingReceiptsEmpty;

  /// Status chip: the receipt waits to be read.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get pendingStatusQueued;

  /// Status chip: the receipt is being read.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get pendingStatusReading;

  /// Status chip: the receipt could not be read.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get pendingStatusFailed;

  /// Button that queues a failed receipt again.
  ///
  /// In en, this message translates to:
  /// **'Read again'**
  String get pendingRetry;

  /// Button that removes a receipt from the queue.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get pendingDiscard;

  /// Question before a receipt is removed from the queue.
  ///
  /// In en, this message translates to:
  /// **'Remove this receipt from the list?'**
  String get pendingDiscardConfirm;

  /// Question before the valid receipts are saved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Save 1 valid receipt as a transaction?} other{Save {count} valid receipts as transactions?}}'**
  String pendingConfirmAllAsk(int count);

  /// Toast after confirming all valid receipts.
  ///
  /// In en, this message translates to:
  /// **'Saved {saved}, duplicates {duplicates}, not saved {notSaved}'**
  String pendingConfirmAllResult(int saved, int duplicates, int notSaved);

  /// Why a receipt failed: no network or timeout.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the AI service.'**
  String get pendingErrorNetwork;

  /// Why a receipt failed: the AI service answered with an error.
  ///
  /// In en, this message translates to:
  /// **'The AI service couldn\'t read this receipt.'**
  String get pendingErrorServer;

  /// Why a receipt failed: the image copy is gone.
  ///
  /// In en, this message translates to:
  /// **'The photo is no longer on this device.'**
  String get pendingErrorMissingImage;

  /// Group / tab title of the ready receipts.
  ///
  /// In en, this message translates to:
  /// **'Ready {count}'**
  String pendingGroupReady(int count);

  /// Group title of the receipts not ready yet.
  ///
  /// In en, this message translates to:
  /// **'Processing {count}'**
  String pendingGroupProcessing(int count);

  /// Tab of the receipts waiting or being read.
  ///
  /// In en, this message translates to:
  /// **'Reading {count}'**
  String pendingTabReading(int count);

  /// Tab of the receipts whose reading failed.
  ///
  /// In en, this message translates to:
  /// **'Failed {count}'**
  String pendingTabFailed(int count);

  /// Title of a card whose receipt is not read yet.
  ///
  /// In en, this message translates to:
  /// **'Reading…'**
  String get pendingReadingTitle;

  /// Title of a failed receipt: its place in the list.
  ///
  /// In en, this message translates to:
  /// **'Photo {index}'**
  String pendingPhotoTitle(int index);

  /// Quick button of a ready receipt.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get pendingQuickSave;

  /// Quick button of a ready receipt with a doubted field.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get pendingReview;

  /// Line above the bottom button: receipts that can be saved now.
  ///
  /// In en, this message translates to:
  /// **'{count} receipts ready'**
  String pendingReadyFooter(int count);

  /// Band title in the selection mode.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String pendingSelected(int count);

  /// Selects every receipt that can be saved now.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get pendingSelectAll;

  /// Bottom button in the selection mode.
  ///
  /// In en, this message translates to:
  /// **'Save {count} selected'**
  String pendingSaveSelected(int count);

  /// Bottom button: saves every receipt that can be saved now.
  ///
  /// In en, this message translates to:
  /// **'Confirm all'**
  String get pendingConfirmAllShort;

  /// Label under a stack of toasts: how many there are and that a tap opens the list.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 notification · tap to see} other{{count} notifications · tap to see}}'**
  String toastStackCount(int count);

  /// Button under the open list of toasts that folds it back into a stack.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get toastCollapse;

  /// Button under the open list of toasts that closes every toast.
  ///
  /// In en, this message translates to:
  /// **'Close all'**
  String get toastCloseAll;

  /// Tooltip of the cross that closes one toast in the open list.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get toastDismiss;

  /// Age of a toast shown less than five seconds ago.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get toastJustNow;

  /// Age of a toast in seconds.
  ///
  /// In en, this message translates to:
  /// **'{count}s ago'**
  String toastSecondsAgo(int count);

  /// Age of a toast in minutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String toastMinutesAgo(int count);

  /// Title of the full-screen receipt photo viewer.
  ///
  /// In en, this message translates to:
  /// **'Receipt photo'**
  String get receiptViewerTitle;

  /// Tooltip of the share button of the receipt photo viewer (the system sheet also offers saving to Photos).
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get receiptViewerShare;

  /// Toast when the receipt photo could not be downloaded or shared.
  ///
  /// In en, this message translates to:
  /// **'Could not share the photo'**
  String get receiptViewerShareFailed;

  /// Title of the date picker sheet opened from a transaction form.
  ///
  /// In en, this message translates to:
  /// **'Choose the transaction date'**
  String get datePickerTransactionTitle;

  /// Title of the date picker sheet opened from any other form.
  ///
  /// In en, this message translates to:
  /// **'Choose a date'**
  String get datePickerTitle;

  /// Quick choice of the date picker: the day of the transaction recorded last.
  ///
  /// In en, this message translates to:
  /// **'Last used'**
  String get datePickerLastRecorded;

  /// Month shown above the calendar of the date picker sheet.
  ///
  /// In en, this message translates to:
  /// **'{monthName} {year}'**
  String datePickerMonthTitle(String month, String year, String monthName);

  /// Short weekday names, Monday first, separated by commas, above the calendar.
  ///
  /// In en, this message translates to:
  /// **'Mo,Tu,We,Th,Fr,Sa,Su'**
  String get datePickerWeekdays;

  /// Tooltip of the button that shows the previous month.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get datePickerPreviousMonth;

  /// Tooltip of the button that shows the next month.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get datePickerNextMonth;

  /// What a date field shows when its day is today.
  ///
  /// In en, this message translates to:
  /// **'Today, {date}'**
  String dateFieldTodayValue(String date);

  /// What a date field shows when its day is yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday, {date}'**
  String dateFieldYesterdayValue(String date);

  /// Title of the filter sheet of the statistics tab.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filterTitle;

  /// Filter: every direction of money.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// Filter: spending only.
  ///
  /// In en, this message translates to:
  /// **'Out'**
  String get filterExpense;

  /// Filter: income only.
  ///
  /// In en, this message translates to:
  /// **'In'**
  String get filterIncome;

  /// Filter: any amount.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get filterAnyAmount;

  /// Filter: amounts below 100,000.
  ///
  /// In en, this message translates to:
  /// **'<100K'**
  String get filterUnder100k;

  /// Filter: amounts from 100,000 to 500,000.
  ///
  /// In en, this message translates to:
  /// **'100–500K'**
  String get filter100kTo500k;

  /// Filter: amounts above 500,000.
  ///
  /// In en, this message translates to:
  /// **'>500K'**
  String get filterOver500k;

  /// Order: newest first.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get filterNewest;

  /// Order: oldest first.
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get filterOldest;

  /// Order: largest amount first.
  ///
  /// In en, this message translates to:
  /// **'Largest'**
  String get filterLargest;

  /// Puts the filter back to all / any / newest.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get filterReset;

  /// Applies the filter; count is how many transactions it keeps.
  ///
  /// In en, this message translates to:
  /// **'Show {count, plural, =1{1 transaction} other{{count} transactions}}'**
  String filterShowCount(int count);

  /// Title of the transaction detail page.
  ///
  /// In en, this message translates to:
  /// **'Transaction details'**
  String get transactionDetailTitle;

  /// Row label on the transaction detail page.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get transactionDetailCategory;

  /// Row label on the transaction detail page.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get transactionDetailTime;

  /// Row label on the transaction detail page: state of the scanned receipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get transactionDetailReceipt;

  /// Row label on the transaction detail page: the send state of a transaction not confirmed by the server.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get transactionDetailSync;

  /// Title above the receipt photo on the transaction detail page.
  ///
  /// In en, this message translates to:
  /// **'Receipt photo'**
  String get transactionDetailReceiptImage;

  /// Delete button at the bottom of the transaction detail page.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get transactionDetailDelete;

  /// Income pill on the statistics band.
  ///
  /// In en, this message translates to:
  /// **'In {amount}'**
  String statsIncome(String amount);

  /// Spending pill on the statistics band.
  ///
  /// In en, this message translates to:
  /// **'Out {amount}'**
  String statsExpense(String amount);

  /// Income minus spending of the period, on the statistics band.
  ///
  /// In en, this message translates to:
  /// **'Left {amount}'**
  String statsLeft(String amount);

  /// Statistics view toggle.
  ///
  /// In en, this message translates to:
  /// **'Chart'**
  String get statsViewChart;

  /// Statistics view toggle.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get statsViewCalendar;

  /// Statistics view toggle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get statsViewCategories;

  /// The month on the statistics band.
  ///
  /// In en, this message translates to:
  /// **'{month}/{year}'**
  String statsMonthLabel(String month, String year);

  /// Tooltip of the search button on the statistics band.
  ///
  /// In en, this message translates to:
  /// **'Search transactions'**
  String get statsSearch;

  /// Tooltip of the Excel button on the statistics band.
  ///
  /// In en, this message translates to:
  /// **'Export to Excel'**
  String get statsExport;

  /// Title of the date sheet opened from the period label of the statistics band.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get statsPickDate;

  /// Adds a transaction, from the day list of the statistics calendar.
  ///
  /// In en, this message translates to:
  /// **'+ Add'**
  String get statsAdd;

  /// Hint above the statistics chart.
  ///
  /// In en, this message translates to:
  /// **'Tap a bar to see the amounts'**
  String get statsTapBarHint;

  /// Under the total in the middle of the category ring.
  ///
  /// In en, this message translates to:
  /// **'spent'**
  String get statsSpent;

  /// Share of spending and number of transactions of one category.
  ///
  /// In en, this message translates to:
  /// **'{percent}%, {count, plural, =1{1 time} other{{count} times}}'**
  String statsCategoryLine(int percent, int count);

  /// Title of the category list of the statistics tab.
  ///
  /// In en, this message translates to:
  /// **'By category'**
  String get statsByCategory;

  /// Category view of a period without spending.
  ///
  /// In en, this message translates to:
  /// **'No spending in this period'**
  String get statsNoSpending;

  /// Title of the transaction list of the statistics tab.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get statsTransactions;

  /// Title of the day list of the statistics calendar.
  ///
  /// In en, this message translates to:
  /// **'Transactions on {date}'**
  String statsTransactionsOfDay(String date);

  /// Income of the chosen day, statistics calendar.
  ///
  /// In en, this message translates to:
  /// **'Total in {amount}'**
  String statsTotalIncome(String amount);

  /// Spending of the chosen day, statistics calendar.
  ///
  /// In en, this message translates to:
  /// **'Total out {amount}'**
  String statsTotalExpense(String amount);

  /// Statistics list when the filter or the search hides every transaction of the period.
  ///
  /// In en, this message translates to:
  /// **'No transaction matches the filter'**
  String get statsNoMatch;

  /// Under the Categories view of the statistics tab while a filter or a search is active: they do not change the category shares.
  ///
  /// In en, this message translates to:
  /// **'Filter and search only narrow the transaction list of Chart and Calendar.'**
  String get statsCategoriesFilterHint;

  /// Savings screen toggle: goals still being funded.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get savingsTabActive;

  /// Savings screen toggle: reached goals.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get savingsTabDone;

  /// Caption above the amount a savings goal still misses.
  ///
  /// In en, this message translates to:
  /// **'Still needed'**
  String get savingsMissing;

  /// Row of a savings goal: days to its target date, then the date.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day left} other{{days} days left}} · {date}'**
  String savingsDaysLeft(int days, String date);

  /// Row of a savings goal whose target date is today.
  ///
  /// In en, this message translates to:
  /// **'Due today · {date}'**
  String savingsDueToday(String date);

  /// Row of an unfinished savings goal whose target date is past.
  ///
  /// In en, this message translates to:
  /// **'Overdue · {date}'**
  String savingsOverdue(String date);

  /// Row of a savings goal without a target date.
  ///
  /// In en, this message translates to:
  /// **'No target date'**
  String get savingsNoDeadline;

  /// Row of a reached savings goal.
  ///
  /// In en, this message translates to:
  /// **'Goal reached'**
  String get savingsReached;

  /// Empty state of the In progress tab.
  ///
  /// In en, this message translates to:
  /// **'No goals in progress'**
  String get savingsEmptyActiveTitle;

  /// Empty state of the In progress tab.
  ///
  /// In en, this message translates to:
  /// **'Tap + to create a savings goal.'**
  String get savingsEmptyActiveHint;

  /// Empty state of the Done tab.
  ///
  /// In en, this message translates to:
  /// **'No goals reached yet'**
  String get savingsEmptyDoneTitle;

  /// Empty state of the Done tab.
  ///
  /// In en, this message translates to:
  /// **'Goals you fully fund show up here.'**
  String get savingsEmptyDoneHint;

  /// Title of the error state of the savings screen.
  ///
  /// In en, this message translates to:
  /// **'Could not load your savings'**
  String get savingsLoadFailedTitle;

  /// Title of the new goal form and tooltip of the + button.
  ///
  /// In en, this message translates to:
  /// **'Add goal'**
  String get savingsCreate;

  /// Title of the goal form when editing.
  ///
  /// In en, this message translates to:
  /// **'Edit goal'**
  String get savingsEditGoal;

  /// Header of the first card of the goal form.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get savingsFormGoalCard;

  /// Header of the target date card of the goal form.
  ///
  /// In en, this message translates to:
  /// **'Deadline'**
  String get savingsFormDeadlineCard;

  /// Label of the target amount field.
  ///
  /// In en, this message translates to:
  /// **'Target amount'**
  String get savingsTargetAmountLabel;

  /// Read-only saved amount in the goal form.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get savingsSavedLabel;

  /// Why the saved amount cannot be typed in the goal form.
  ///
  /// In en, this message translates to:
  /// **'Changes only through Add money.'**
  String get savingsSavedHint;

  /// Label of the target date field.
  ///
  /// In en, this message translates to:
  /// **'Target date (optional)'**
  String get savingsDeadlineLabel;

  /// Target date field without a date.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get savingsDeadlinePick;

  /// Button of the goal form.
  ///
  /// In en, this message translates to:
  /// **'Save goal'**
  String get savingsSaveGoal;

  /// Toast after a goal is created.
  ///
  /// In en, this message translates to:
  /// **'Goal added: {title}'**
  String savingsCreated(String title);

  /// Toast after a goal is edited.
  ///
  /// In en, this message translates to:
  /// **'Goal saved: {title}'**
  String savingsUpdated(String title);

  /// Error dialog of the goal form.
  ///
  /// In en, this message translates to:
  /// **'Could not save the goal'**
  String get savingsSaveFailedTitle;

  /// Label of the amount field of the Add money sheet.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get savingsContributeAmountLabel;

  /// Head card of the Add money sheet: saved amount plus the amount typed.
  ///
  /// In en, this message translates to:
  /// **'{saved} + {added} ='**
  String savingsContributeAddition(String saved, String added);

  /// Saved amount over the target.
  ///
  /// In en, this message translates to:
  /// **'{saved} / {target}'**
  String savingsAmountsOf(String saved, String target);

  /// Badge on the suggested quick amount.
  ///
  /// In en, this message translates to:
  /// **'Suggested'**
  String get savingsSuggestedBadge;

  /// Line under the quick amounts when the goal has a target date.
  ///
  /// In en, this message translates to:
  /// **'Suggestion: add {amount} a month to reach it by {date}.'**
  String savingsSuggestionHint(String amount, String date);

  /// Add money sheet: where the money comes from.
  ///
  /// In en, this message translates to:
  /// **'Taken from your wallet (balance {balance}) and recorded as a \"Savings\" expense.'**
  String savingsWalletLine(String balance);

  /// Add money sheet when the balance could not be read.
  ///
  /// In en, this message translates to:
  /// **'Taken from your wallet and recorded as a \"Savings\" expense.'**
  String get savingsWalletLineNoBalance;

  /// Button of the Add money sheet with the amount.
  ///
  /// In en, this message translates to:
  /// **'Add {amount}'**
  String savingsContributeButton(String amount);

  /// Toast when a reload fails while goals are already shown; reason is the error text.
  ///
  /// In en, this message translates to:
  /// **'Could not reload your savings. {reason}'**
  String savingsReloadFailed(String reason);

  /// Row of a savings goal whose target is 0.
  ///
  /// In en, this message translates to:
  /// **'No amount set'**
  String get savingsNoTarget;

  /// Add money sheet when the amount typed is above what the goal misses.
  ///
  /// In en, this message translates to:
  /// **'The goal only misses {missing}. The extra still goes into the goal.'**
  String savingsOverfillHint(String missing);

  /// Title of the receipt detail sheet opened from the transaction detail page.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get receiptDetailTitle;

  /// Row label in the receipt detail sheet: where the receipt stands.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get receiptDetailStatus;

  /// Label of the store name in the receipt detail sheet and its edit form.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get receiptDetailVendor;

  /// Label of the receipt total in the receipt detail sheet and its forms.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get receiptDetailTotal;

  /// Label of the receipt date in the receipt detail sheet.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get receiptDetailDate;

  /// Shown in place of a receipt field that has no value.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get receiptDetailNoValue;

  /// Lifecycle status PENDING of a receipt.
  ///
  /// In en, this message translates to:
  /// **'Waiting to be read'**
  String get receiptDetailStatusPending;

  /// Lifecycle status PROCESSING of a receipt.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get receiptDetailStatusProcessing;

  /// Lifecycle status COMPLETED_RAW of a receipt: the AI read a total and nobody changed it.
  ///
  /// In en, this message translates to:
  /// **'Read by AI'**
  String get receiptDetailStatusCompleted;

  /// Lifecycle status EDITED of a receipt: its owner corrected what the AI read.
  ///
  /// In en, this message translates to:
  /// **'Edited by you'**
  String get receiptDetailStatusEdited;

  /// Lifecycle status FAILED of a receipt.
  ///
  /// In en, this message translates to:
  /// **'Could not be read'**
  String get receiptDetailStatusFailed;

  /// Lifecycle status WAITING_FOR_REVIEW of a receipt: the owner sent the amount and waits for an administrator.
  ///
  /// In en, this message translates to:
  /// **'Waiting for review'**
  String get receiptDetailStatusWaitingForReview;

  /// Lifecycle status APPROVED of a receipt.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get receiptDetailStatusApproved;

  /// Lifecycle status CANCELED of a receipt.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get receiptDetailStatusCanceled;

  /// Status of a receipt that this version of the app does not know.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get receiptDetailStatusUnknown;

  /// Title of the error block of a FAILED receipt; the reason from the server is shown under it.
  ///
  /// In en, this message translates to:
  /// **'This receipt could not be read'**
  String get receiptDetailFailedTitle;

  /// Button of the receipt detail sheet: correct the store, total and date.
  ///
  /// In en, this message translates to:
  /// **'Edit details'**
  String get receiptDetailEdit;

  /// Button of the receipt detail sheet: scan the photo of a FAILED receipt again.
  ///
  /// In en, this message translates to:
  /// **'Read again'**
  String get receiptDetailRetry;

  /// Button of the receipt detail sheet: tell an administrator the right total of a FAILED receipt.
  ///
  /// In en, this message translates to:
  /// **'Send the right amount'**
  String get receiptDetailSendAmount;

  /// Hint under the receipt edit form: editing a receipt does not change the transaction or the wallet.
  ///
  /// In en, this message translates to:
  /// **'The transaction and your balance only change after an administrator approves.'**
  String get receiptDetailEditHint;

  /// Hint above the amount field of the send-the-right-amount form.
  ///
  /// In en, this message translates to:
  /// **'Enter the right total of this receipt. An administrator will check it before the transaction is updated.'**
  String get receiptDetailSendAmountHint;

  /// Button that sends the right amount of a FAILED receipt.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get receiptDetailSend;

  /// Toast after the receipt was edited.
  ///
  /// In en, this message translates to:
  /// **'Receipt updated'**
  String get receiptDetailEdited;

  /// Toast after a FAILED receipt was read again and a total was found.
  ///
  /// In en, this message translates to:
  /// **'Receipt read again'**
  String get receiptDetailRetried;

  /// Toast after a FAILED receipt was read again and no total was found.
  ///
  /// In en, this message translates to:
  /// **'The total still could not be read'**
  String get receiptDetailRetryStillFailed;

  /// Toast after the right amount of a FAILED receipt was sent.
  ///
  /// In en, this message translates to:
  /// **'Sent to an administrator for review'**
  String get receiptDetailAmountSent;

  /// Title of the error view of the receipt detail sheet.
  ///
  /// In en, this message translates to:
  /// **'Could not load the receipt'**
  String get receiptDetailLoadFailedTitle;

  /// Toast when the server refuses an action on a receipt (409) and the message of the server cannot be shown in this language.
  ///
  /// In en, this message translates to:
  /// **'The receipt has changed. It was reloaded: please check it and try again.'**
  String get receiptDetailConflict;

  /// Toast when the photo of a FAILED receipt cannot be downloaded for a new scan.
  ///
  /// In en, this message translates to:
  /// **'Could not download the receipt photo to read it again.'**
  String get receiptDetailPhotoFailed;

  /// Section title for the optional 0.5-5.0 star experience rating on transaction forms.
  ///
  /// In en, this message translates to:
  /// **'Experience rating (optional)'**
  String get experienceRatingLabel;

  /// Button to clear the selected star rating back to unrated.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get experienceRatingClear;

  /// Hint text shown when no star rating has been chosen yet.
  ///
  /// In en, this message translates to:
  /// **'Tap or drag stars to rate (0.5 – 5.0)'**
  String get experienceRatingUnrated;

  /// Sentiment label for a 0.5 to 1.5 star rating.
  ///
  /// In en, this message translates to:
  /// **'Poor experience'**
  String get experienceRatingBad;

  /// Sentiment label for a 2.0 to 2.5 star rating.
  ///
  /// In en, this message translates to:
  /// **'Below average'**
  String get experienceRatingFair;

  /// Sentiment label for a 3.0 to 3.5 star rating.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get experienceRatingAverage;

  /// Sentiment label for a 4.0 to 4.5 star rating.
  ///
  /// In en, this message translates to:
  /// **'Good experience'**
  String get experienceRatingGood;

  /// Sentiment label for a 5.0 star rating.
  ///
  /// In en, this message translates to:
  /// **'Excellent experience'**
  String get experienceRatingExcellent;

  /// Floating label of the optional personal experience review note field.
  ///
  /// In en, this message translates to:
  /// **'Experience review note (optional)'**
  String get experienceReviewNoteLabel;

  /// Placeholder text inside the optional personal experience review note field.
  ///
  /// In en, this message translates to:
  /// **'e.g., Friendly staff, great drinks, cozy space...'**
  String get experienceReviewNoteHint;

  /// Label of the experience rating row in TransactionDetailPage.
  ///
  /// In en, this message translates to:
  /// **'Experience rating'**
  String get transactionDetailExperience;

  /// Label of the experience review note row in TransactionDetailPage.
  ///
  /// In en, this message translates to:
  /// **'Experience note'**
  String get transactionDetailReviewNote;

  /// Banner shown on the receipt review form when the store has previous rated transactions.
  ///
  /// In en, this message translates to:
  /// **'Past visits to {store}: avg {avg} ★ ({count} ratings)'**
  String reviewPastStoreRating(String store, String avg, int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
