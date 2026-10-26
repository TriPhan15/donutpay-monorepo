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

  /// Button that opens the update goal dialog.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get savingsUpdate;

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

  /// Heading of a totals block (Ledger, receipt form).
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get commonSummary;

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
  /// **'The transaction is saved on this device but hasn\'t reached the server yet. When you\'re back online, open the Ledger, select the transaction and tap \"Resend\". Resending won\'t create a duplicate.'**
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

  /// The typed amount is not usable.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount.'**
  String get addTransactionInvalidAmount;

  /// Example note in the add form.
  ///
  /// In en, this message translates to:
  /// **'e.g. Coffee at Highlands'**
  String get addTransactionNoteHint;

  /// Save button of the add form.
  ///
  /// In en, this message translates to:
  /// **'Save transaction'**
  String get addTransactionSubmit;

  /// The server saved the new transaction.
  ///
  /// In en, this message translates to:
  /// **'New transaction added.'**
  String get addTransactionSaved;

  /// Title of the edit form and the Ledger button that opens it.
  ///
  /// In en, this message translates to:
  /// **'Edit transaction'**
  String get editTransactionTitle;

  /// Label of the amount field of the edit form.
  ///
  /// In en, this message translates to:
  /// **'Amount (₫)'**
  String get editTransactionAmountLabel;

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

  /// The amount must be above zero.
  ///
  /// In en, this message translates to:
  /// **'Please enter an amount greater than 0.'**
  String get editTransactionAmountPositive;

  /// Title when the user saves without changing anything.
  ///
  /// In en, this message translates to:
  /// **'No changes yet'**
  String get editTransactionNoChangesTitle;

  /// Asks the user to change something first.
  ///
  /// In en, this message translates to:
  /// **'Change the amount, category or note before saving.'**
  String get editTransactionNoChangesMessage;

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
  /// **'Ledger'**
  String get ledgerTitle;

  /// Hint of the Ledger search box.
  ///
  /// In en, this message translates to:
  /// **'Search name, category...'**
  String get ledgerSearchHint;

  /// Label of the date picker button.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get ledgerCalendar;

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

  /// Stat card: income of the period.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get ledgerIncome;

  /// Stat card: spending of the period.
  ///
  /// In en, this message translates to:
  /// **'Spending'**
  String get ledgerExpense;

  /// Heading of the transaction list.
  ///
  /// In en, this message translates to:
  /// **'Recent transactions'**
  String get ledgerRecent;

  /// The period has no transactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions in this period.'**
  String get ledgerEmptyPeriod;

  /// Summary row: total income.
  ///
  /// In en, this message translates to:
  /// **'Total income'**
  String get ledgerTotalIncome;

  /// Summary row: total spending.
  ///
  /// In en, this message translates to:
  /// **'Total spending'**
  String get ledgerTotalExpense;

  /// Summary row and Excel row: income minus spending.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get ledgerBalance;

  /// Title of the filter sheet.
  ///
  /// In en, this message translates to:
  /// **'Smart filter & sort'**
  String get ledgerFilterTitle;

  /// Filter section: transaction type.
  ///
  /// In en, this message translates to:
  /// **'1. Transaction type'**
  String get ledgerFilterType;

  /// Filter chip: expenses and income.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get ledgerFilterAll;

  /// Filter chip: expenses only.
  ///
  /// In en, this message translates to:
  /// **'Expenses only'**
  String get ledgerFilterExpenseOnly;

  /// Filter chip: income only.
  ///
  /// In en, this message translates to:
  /// **'Income only'**
  String get ledgerFilterIncomeOnly;

  /// Filter section: amount range.
  ///
  /// In en, this message translates to:
  /// **'2. Amount range'**
  String get ledgerFilterAmount;

  /// Filter chip: no amount limit.
  ///
  /// In en, this message translates to:
  /// **'Any amount'**
  String get ledgerFilterAnyAmount;

  /// Filter section: sort order.
  ///
  /// In en, this message translates to:
  /// **'3. Sort by'**
  String get ledgerFilterSort;

  /// Sort chip: newest first.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get ledgerSortNewest;

  /// Sort chip: oldest first.
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get ledgerSortOldest;

  /// Sort chip: highest amount first.
  ///
  /// In en, this message translates to:
  /// **'Highest amount'**
  String get ledgerSortHighest;

  /// Button that applies the filters.
  ///
  /// In en, this message translates to:
  /// **'Apply filters'**
  String get ledgerFilterApply;

  /// Detail sheet label.
  ///
  /// In en, this message translates to:
  /// **'Amount:'**
  String get ledgerDetailAmount;

  /// Detail sheet label.
  ///
  /// In en, this message translates to:
  /// **'Time:'**
  String get ledgerDetailTime;

  /// Detail sheet label.
  ///
  /// In en, this message translates to:
  /// **'Receipt status:'**
  String get ledgerDetailReceiptStatus;

  /// Detail sheet label of the sync state.
  ///
  /// In en, this message translates to:
  /// **'Sync:'**
  String get ledgerDetailSync;

  /// Explains the Resend button.
  ///
  /// In en, this message translates to:
  /// **'The server hasn\'t confirmed this transaction yet. When you\'re back online, tap \"Resend\". Resending won\'t create a duplicate.'**
  String get ledgerDetailUnsyncedHint;

  /// Detail sheet label above the receipt photo.
  ///
  /// In en, this message translates to:
  /// **'Original receipt photo:'**
  String get ledgerDetailReceiptImage;

  /// Button that sends an unsynced transaction again.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get ledgerResend;

  /// Delete button of the detail sheet.
  ///
  /// In en, this message translates to:
  /// **'Delete this transaction'**
  String get ledgerDelete;

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

  /// Notice above the list when the server list failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the list from the server. Only the unsent transactions on this device are shown. Pull down to try again.'**
  String get ledgerLoadFailedNotice;

  /// Excel sheet name and share subject; month is e.g. 'October 2026'.
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

  /// Excel heading of the budget table.
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

  /// Excel file name without extension.
  ///
  /// In en, this message translates to:
  /// **'spending_{month}{date}'**
  String ledgerExcelFileName(String month, String date);

  /// Text sent with the shared Excel file.
  ///
  /// In en, this message translates to:
  /// **'Spending report for {month}'**
  String ledgerExcelShareText(String month);

  /// Title of the receipt review form.
  ///
  /// In en, this message translates to:
  /// **'Confirm receipt'**
  String get reviewTitle;

  /// Shown under the date when the scan found no date.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the date on the receipt, so the current time is used. Tap to choose another.'**
  String get reviewDateFallback;

  /// Shown under a scanned field (store, total, date) that the AI post-processing marked as not valid.
  ///
  /// In en, this message translates to:
  /// **'The AI isn\'t sure about this field. Please check it.'**
  String get reviewFieldNeedsCheck;

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

  /// The total must be above zero.
  ///
  /// In en, this message translates to:
  /// **'Please enter a total greater than 0.'**
  String get reviewTotalPositive;

  /// The server saved the receipt transaction.
  ///
  /// In en, this message translates to:
  /// **'Transaction saved from the receipt.'**
  String get reviewSaved;

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

  /// Heading once the scan answered.
  ///
  /// In en, this message translates to:
  /// **'Extraction complete'**
  String get reviewExtracted;

  /// Asks the user to check the scanned fields.
  ///
  /// In en, this message translates to:
  /// **'Check the details below against the original photo before saving.'**
  String get reviewCheckDetails;

  /// Section heading of the review form.
  ///
  /// In en, this message translates to:
  /// **'General information'**
  String get reviewGeneralInfo;

  /// Label of the store name field.
  ///
  /// In en, this message translates to:
  /// **'Store name'**
  String get reviewStoreName;

  /// Label of the total field.
  ///
  /// In en, this message translates to:
  /// **'Total (đ)'**
  String get reviewTotalLabel;

  /// Totals card row.
  ///
  /// In en, this message translates to:
  /// **'Subtotal:'**
  String get reviewSubtotal;

  /// Totals card row.
  ///
  /// In en, this message translates to:
  /// **'VAT/Other taxes:'**
  String get reviewTax;

  /// Totals card row: the grand total.
  ///
  /// In en, this message translates to:
  /// **'TOTAL:'**
  String get reviewGrandTotal;

  /// Save button of the review form.
  ///
  /// In en, this message translates to:
  /// **'Confirm & save'**
  String get reviewSubmit;

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

  /// The order code.
  ///
  /// In en, this message translates to:
  /// **'Code: {code}'**
  String paymentOrderCode(String code);

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

  /// Name of the demo e-wallet.
  ///
  /// In en, this message translates to:
  /// **'Demo wallet'**
  String get linkedDemoWallet;

  /// Title of the sync dialog.
  ///
  /// In en, this message translates to:
  /// **'Sync from {wallet}'**
  String linkedSyncFrom(String wallet);

  /// Sync dialog prompt.
  ///
  /// In en, this message translates to:
  /// **'Amount to add to your spending budget:'**
  String get linkedAmountPrompt;

  /// Example amount in the sync dialog.
  ///
  /// In en, this message translates to:
  /// **'e.g. 100000'**
  String get linkedAmountHint;

  /// Button that syncs money from a wallet.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get linkedSync;

  /// The amount is below the minimum.
  ///
  /// In en, this message translates to:
  /// **'The minimum amount is {amount}.'**
  String linkedMinAmount(String amount);

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

  /// Heading of the wallet list.
  ///
  /// In en, this message translates to:
  /// **'Linked e-wallets'**
  String get linkedWalletsHeading;

  /// Explains the wallet list.
  ///
  /// In en, this message translates to:
  /// **'Sync money from a wallet into your budget to manage spending.'**
  String get linkedWalletsDescription;

  /// Shown while a payment is pending.
  ///
  /// In en, this message translates to:
  /// **'Syncing... finish the payment on the gateway.'**
  String get linkedSyncing;

  /// Status of a linked wallet.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get linkedLinked;

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

  /// Button that runs an analysis again.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

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

  /// Link from the budget block to the budget screen.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get budgetManage;

  /// The budget block has nothing to show.
  ///
  /// In en, this message translates to:
  /// **'No budgets in this period.'**
  String get budgetEmptyPeriod;

  /// The budget block could not load.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your budgets. Pull down to try again.'**
  String get budgetLoadFailedPullToRetry;

  /// How many budgets the block does not show.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{+1 more budget} other{+{count} more budgets}}'**
  String budgetMoreCount(int count);

  /// A budget past its limit; amount is formatted money.
  ///
  /// In en, this message translates to:
  /// **'Over the limit by {amount}'**
  String budgetOverBy(String amount);

  /// A budget at 80% or more; amount is formatted money.
  ///
  /// In en, this message translates to:
  /// **'Almost at the limit · Left: {amount}'**
  String budgetNearLimitLeft(String amount);

  /// What is left of a budget; amount is formatted money.
  ///
  /// In en, this message translates to:
  /// **'Left: {amount}'**
  String budgetLeft(String amount);

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

  /// The budget list is empty.
  ///
  /// In en, this message translates to:
  /// **'No budgets yet.'**
  String get budgetEmpty;

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

  /// The amount is missing or not positive.
  ///
  /// In en, this message translates to:
  /// **'Please enter a budget amount greater than 0.'**
  String get budgetAmountPositive;

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

  /// Label of the balance card.
  ///
  /// In en, this message translates to:
  /// **'Current balance'**
  String get dashboardBalance;

  /// After the percentage change of the month.
  ///
  /// In en, this message translates to:
  /// **'vs. last month'**
  String get dashboardVsLastMonth;

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

  /// Title of the AI tab.
  ///
  /// In en, this message translates to:
  /// **'AI analysis'**
  String get aiTitle;

  /// Title of the date range picker.
  ///
  /// In en, this message translates to:
  /// **'Choose a time range'**
  String get aiPickRangeTitle;

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

  /// Hint when there are no transactions.
  ///
  /// In en, this message translates to:
  /// **'Add real transactions so WCM-SPADE can mine your spending patterns.'**
  String get aiNoDataHint;

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

  /// Title of the spending chart.
  ///
  /// In en, this message translates to:
  /// **'Income & spending chart'**
  String get aiChartTitle;

  /// No spending in any week of the month.
  ///
  /// In en, this message translates to:
  /// **'No data for the weeks of this month yet.'**
  String get aiNoWeekData;

  /// week is 1-4; amount is formatted money.
  ///
  /// In en, this message translates to:
  /// **'Week {week} has the highest spending: {amount}.'**
  String aiTopWeek(int week, String amount);

  /// Title of the safe-to-spend card.
  ///
  /// In en, this message translates to:
  /// **'How much can I spend today?'**
  String get aiSafeToSpendTitle;

  /// No income this month.
  ///
  /// In en, this message translates to:
  /// **'Add this month\'s income to work out a safe amount.'**
  String get aiSafeToSpendNoIncome;

  /// Money per day; amount is formatted money.
  ///
  /// In en, this message translates to:
  /// **'{amount} / day'**
  String aiPerDay(String amount);

  /// Days left in the month.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{What is left covers the last day.} other{What is left spread evenly over {days} days.}}'**
  String aiDaysLeft(int days);

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

  /// percent has one decimal.
  ///
  /// In en, this message translates to:
  /// **'Spending this month is up {percent}% on last month.'**
  String aiTrendUp(String percent);

  /// percent has one decimal.
  ///
  /// In en, this message translates to:
  /// **'Spending this month is down {percent}% on last month.'**
  String aiTrendDown(String percent);

  /// Top category card without spending.
  ///
  /// In en, this message translates to:
  /// **'No spending this month yet.'**
  String get aiNoSpendingThisMonth;

  /// category is the category label; amount is formatted money.
  ///
  /// In en, this message translates to:
  /// **'{category} accounts for {amount} ({percent}% of spending).'**
  String aiTopCategory(String category, String amount, String percent);

  /// Income above spending, no goal yet.
  ///
  /// In en, this message translates to:
  /// **'You\'re {amount} ahead. Set a goal!'**
  String aiSurplus(String amount);

  /// No savings goal yet.
  ///
  /// In en, this message translates to:
  /// **'Add a savings goal for the AI to analyse.'**
  String get aiAddGoal;

  /// The user has savings goals.
  ///
  /// In en, this message translates to:
  /// **'You\'re on your savings path. See the money allocation tips below to reach your goal faster!'**
  String get aiOnTrack;

  /// Title of the WCM-SPADE section.
  ///
  /// In en, this message translates to:
  /// **'Sequential spending patterns'**
  String get aiSpadeTitle;

  /// Under the WCM-SPADE title.
  ///
  /// In en, this message translates to:
  /// **'Spending sequences you often follow'**
  String get aiSpadeSubtitle;

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

  /// No pattern found.
  ///
  /// In en, this message translates to:
  /// **'Add at least 3 transactions to see sequential spending patterns.'**
  String get aiSpadeNotEnoughMessage;

  /// count and support come from the AI service.
  ///
  /// In en, this message translates to:
  /// **'Frequency: {count} times  ·  Support (W-Sup): {support}'**
  String aiSpadeDetail(String count, String support);

  /// Title of the budget advice section.
  ///
  /// In en, this message translates to:
  /// **'Money allocation tips'**
  String get aiAdviceTitle;

  /// Under the advice title.
  ///
  /// In en, this message translates to:
  /// **'Suggested cuts and keeps per item to reach your savings goal'**
  String get aiAdviceSubtitle;

  /// Current and suggested monthly amounts.
  ///
  /// In en, this message translates to:
  /// **'{current} → {suggested} / month'**
  String aiAdvicePerMonth(String current, String suggested);

  /// Title of the habit alert section.
  ///
  /// In en, this message translates to:
  /// **'Future habit alerts'**
  String get aiGuardTitle;

  /// Under the habit alert title.
  ///
  /// In en, this message translates to:
  /// **'The AI predicts upcoming spending from your spending sequence history.'**
  String get aiGuardSubtitle;

  /// Heading of one habit alert.
  ///
  /// In en, this message translates to:
  /// **'Behaviour forecast · Sequence mining'**
  String get aiGuardHeading;

  /// from and to are category labels.
  ///
  /// In en, this message translates to:
  /// **'WCM-SPADE found the rule [{from} → {to}]: after spending on {from}, you tend to spend on {to} within a few days. Keep an eye on your wallet so it does not eat into your savings!'**
  String aiGuardRule(String from, String to);

  /// Title of the 50/30/20 card.
  ///
  /// In en, this message translates to:
  /// **'Spending health — the 50/30/20 rule'**
  String get ai503020Title;

  /// Which categories count as needs and wants.
  ///
  /// In en, this message translates to:
  /// **'Needs: Food & drinks, Transport, Supermarket, Living costs · Wants: Entertainment, Other'**
  String get ai503020Groups;

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

  /// Savings share row.
  ///
  /// In en, this message translates to:
  /// **'Savings (what\'s left)'**
  String get ai503020Savings;

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

  /// Tooltip of the button that puts the shared date field back on today; shown only when another day is picked.
  ///
  /// In en, this message translates to:
  /// **'Back to today'**
  String get dateFieldBackToToday;

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

  /// Label of the day whose week, month or year the budget covers.
  ///
  /// In en, this message translates to:
  /// **'Period that contains'**
  String get budgetPeriodDayLabel;

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

  /// Helper under the optional saved amount when creating a goal.
  ///
  /// In en, this message translates to:
  /// **'Leave empty if there is none yet or you don\'t remember; you can change it later'**
  String get savingsSavedAmountHint;

  /// Label of the optional target date of a goal.
  ///
  /// In en, this message translates to:
  /// **'Target date'**
  String get savingsTargetDateField;

  /// Button that adds the optional target date.
  ///
  /// In en, this message translates to:
  /// **'Add a target date (optional)'**
  String get savingsTargetDateAdd;

  /// Tooltip of the button that removes the target date.
  ///
  /// In en, this message translates to:
  /// **'Remove the target date'**
  String get savingsTargetDateClear;

  /// Target date under a goal's name.
  ///
  /// In en, this message translates to:
  /// **'Target date: {date}'**
  String savingsTargetDateShown(String date);

  /// Button of a goal that moves money from the wallet into it.
  ///
  /// In en, this message translates to:
  /// **'Add money'**
  String get savingsContribute;

  /// Title of the add money sheet.
  ///
  /// In en, this message translates to:
  /// **'Add money: {title}'**
  String savingsContributeTitle(String title);

  /// Amount field of the add money sheet.
  ///
  /// In en, this message translates to:
  /// **'Amount (₫)'**
  String get savingsContributeAmount;

  /// Helper of the add money amount.
  ///
  /// In en, this message translates to:
  /// **'Taken from your wallet and recorded as a \"Savings\" expense'**
  String get savingsContributeHelper;

  /// Toast when the add money amount is empty or zero.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount greater than 0'**
  String get savingsContributeInvalidAmount;

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
