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

  /// Snackbar shown when the tapped notification has no screen to open in the app yet.
  ///
  /// In en, this message translates to:
  /// **'This notification can\'t be opened yet.'**
  String get notificationsDetailUnavailable;

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

  /// Heading of the forgot-password screen, above its description.
  ///
  /// In en, this message translates to:
  /// **'Get a verification code'**
  String get forgotPasswordHeading;

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

  /// Heading of the reset-password screen, above its description.
  ///
  /// In en, this message translates to:
  /// **'Create a new password'**
  String get resetPasswordHeading;

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

  /// Hint inside the empty one-time code field.
  ///
  /// In en, this message translates to:
  /// **'{length}-digit code'**
  String resetPasswordOtpHint(int length);

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

  /// Scan sheet option that opens the document scanner.
  ///
  /// In en, this message translates to:
  /// **'AI scan'**
  String get scanWithAi;

  /// Scan sheet option that picks a receipt photo from the gallery.
  ///
  /// In en, this message translates to:
  /// **'From gallery'**
  String get scanFromGallery;

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

  /// Default button of a success or info dialog.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get dialogOk;

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
