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

  /// App bar title of the register screen.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get registerTitle;

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

  /// Shown when the account could not be loaded.
  ///
  /// In en, this message translates to:
  /// **'No account data yet.'**
  String get credentialsNoData;

  /// Hint above the editable rows of the account credentials screen.
  ///
  /// In en, this message translates to:
  /// **'Tap the row you want to change.'**
  String get credentialsTapToEdit;

  /// Row label of the username (the email).
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get credentialsUsername;

  /// Label of the username field.
  ///
  /// In en, this message translates to:
  /// **'Username (email)'**
  String get credentialsUsernameEmail;

  /// Heading of the username form.
  ///
  /// In en, this message translates to:
  /// **'Edit username'**
  String get credentialsEditUsername;

  /// Shown when the username field is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a username.'**
  String get credentialsUsernameRequired;

  /// Shown when the user saves a new username.
  ///
  /// In en, this message translates to:
  /// **'The server does not support changing the username yet.'**
  String get credentialsUsernameChangeUnsupported;

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

  /// Message of the dialog shown after the password change.
  ///
  /// In en, this message translates to:
  /// **'Your new password now applies to your account.'**
  String get credentialsChangePasswordSuccessMessage;

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

  /// Title of the personal information screen and its row.
  ///
  /// In en, this message translates to:
  /// **'Personal information'**
  String get userInfoTitle;

  /// Tooltip of the edit button of the personal information screen.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get userInfoEdit;

  /// Shown when the user could not be loaded.
  ///
  /// In en, this message translates to:
  /// **'No personal information yet.'**
  String get userInfoEmpty;

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

  /// App bar title of the profile edit screen.
  ///
  /// In en, this message translates to:
  /// **'Edit information'**
  String get setUserInfoTitle;

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

  /// Security menu row and title of the PIN dialog.
  ///
  /// In en, this message translates to:
  /// **'Create / change PIN'**
  String get pinSetupTitle;

  /// Subtitle of the PIN row.
  ///
  /// In en, this message translates to:
  /// **'Protect the app with a 4-digit code'**
  String get pinSetupSubtitle;

  /// Label of the new PIN field.
  ///
  /// In en, this message translates to:
  /// **'New PIN'**
  String get pinNewLabel;

  /// Label of the PIN confirmation field.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get pinConfirmLabel;

  /// Shown when the PIN is not 4 digits.
  ///
  /// In en, this message translates to:
  /// **'The PIN must be exactly 4 digits.'**
  String get pinLengthInvalid;

  /// Shown when the PIN confirmation differs.
  ///
  /// In en, this message translates to:
  /// **'The PINs do not match.'**
  String get pinMismatch;

  /// Snackbar after the PIN is saved.
  ///
  /// In en, this message translates to:
  /// **'PIN saved.'**
  String get pinSaved;

  /// User guide topic.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get helpDashboardTitle;

  /// User guide text.
  ///
  /// In en, this message translates to:
  /// **'See your assets, the month\'s income and spending and the cash flow chart.'**
  String get helpDashboardBody;

  /// User guide topic.
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get helpLedgerTitle;

  /// User guide text.
  ///
  /// In en, this message translates to:
  /// **'Add, filter and view transactions by day, calendar or month.'**
  String get helpLedgerBody;

  /// User guide topic.
  ///
  /// In en, this message translates to:
  /// **'Receipt scan'**
  String get helpScanTitle;

  /// User guide text.
  ///
  /// In en, this message translates to:
  /// **'Tap the round button in the middle of the navigation bar to scan a receipt with AI.'**
  String get helpScanBody;

  /// User guide topic.
  ///
  /// In en, this message translates to:
  /// **'AI analysis'**
  String get helpAiTitle;

  /// User guide text.
  ///
  /// In en, this message translates to:
  /// **'See spending trends and financial habits analysed automatically.'**
  String get helpAiBody;

  /// User guide topic.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get helpTransferTitle;

  /// User guide text.
  ///
  /// In en, this message translates to:
  /// **'Send or receive money by phone number or QR code.'**
  String get helpTransferBody;

  /// Title of the feedback dialog (a star follows it).
  ///
  /// In en, this message translates to:
  /// **'Rate the app'**
  String get feedbackTitle;

  /// Text of the feedback dialog.
  ///
  /// In en, this message translates to:
  /// **'Your feedback helps us keep improving the app!'**
  String get feedbackDescription;

  /// Hint of the feedback comment field.
  ///
  /// In en, this message translates to:
  /// **'Share your thoughts or suggestions...'**
  String get feedbackHint;

  /// Button that closes the feedback dialog.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get feedbackLater;

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

  /// Title of the savings screen and its profile row.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get savingsTitle;

  /// Snackbar when the savings cannot be loaded; reason is the error text.
  ///
  /// In en, this message translates to:
  /// **'Could not load your savings. {reason}'**
  String savingsLoadFailed(String reason);

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

  /// Title of the add goal dialog.
  ///
  /// In en, this message translates to:
  /// **'Add a savings goal'**
  String get savingsAddTitle;

  /// Submit button of the add goal dialog.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get savingsAdd;

  /// Field of the add goal dialog.
  ///
  /// In en, this message translates to:
  /// **'Goal name'**
  String get savingsGoalName;

  /// Field of the add goal dialog.
  ///
  /// In en, this message translates to:
  /// **'Target amount (₫)'**
  String get savingsTargetAmount;

  /// Field of the add goal dialog.
  ///
  /// In en, this message translates to:
  /// **'Saved so far (₫)'**
  String get savingsSavedAmount;

  /// Field of the add goal dialog.
  ///
  /// In en, this message translates to:
  /// **'Deadline (dd/mm/yyyy)'**
  String get savingsDeadlineField;

  /// Title of the update goal dialog.
  ///
  /// In en, this message translates to:
  /// **'Update: {title}'**
  String savingsUpdateTitle(String title);

  /// Field of the update goal dialog.
  ///
  /// In en, this message translates to:
  /// **'Amount saved (₫)'**
  String get savingsCurrentAmount;

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

  /// Two-line label of the add goal shortcut.
  ///
  /// In en, this message translates to:
  /// **'Add\ngoal'**
  String get savingsAddGoalAction;

  /// Heading of the goal list.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get savingsGoalList;

  /// Shown when there is no goal.
  ///
  /// In en, this message translates to:
  /// **'No goals yet.'**
  String get savingsEmpty;

  /// Hint under the empty goal list.
  ///
  /// In en, this message translates to:
  /// **'Tap \"+\" to create a savings goal.'**
  String get savingsEmptyHint;

  /// Deadline of a goal.
  ///
  /// In en, this message translates to:
  /// **'Due: {date}'**
  String savingsDeadline(String date);

  /// Button that opens the update goal dialog.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get savingsUpdate;
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
