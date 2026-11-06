import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @overlappingActivity.
  ///
  /// In en, this message translates to:
  /// **'Overlapping activity'**
  String get overlappingActivity;

  /// No description provided for @overlappingActivityNotice.
  ///
  /// In en, this message translates to:
  /// **'If you’re accepted into one activity, you’ll automatically be removed from the other conflicting waitlist or your pending request will be cancelled.'**
  String get overlappingActivityNotice;

  /// No description provided for @shareCode.
  ///
  /// In en, this message translates to:
  /// **'Share code'**
  String get shareCode;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @shareMessage.
  ///
  /// In en, this message translates to:
  /// **'Want to join us for {title}?\n📅 {date}\n📍 {place}\n\nEnter the code in Synk: {code}'**
  String shareMessage(Object title, Object date, Object place, Object code);

  /// No description provided for @couldntOpenTheShareMenu.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the share menu.'**
  String get couldntOpenTheShareMenu;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get appLanguage;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @doneTitle.
  ///
  /// In en, this message translates to:
  /// **'Done!'**
  String get doneTitle;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @choose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get choose;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @yourChangesHaveBeenSaved.
  ///
  /// In en, this message translates to:
  /// **'Your changes have been saved.'**
  String get yourChangesHaveBeenSaved;

  /// No description provided for @discardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get discardChanges;

  /// No description provided for @unsavedChangesWillBeLost.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes will be lost'**
  String get unsavedChangesWillBeLost;

  /// No description provided for @keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditing;

  /// No description provided for @discardAndLeave.
  ///
  /// In en, this message translates to:
  /// **'Discard and leave'**
  String get discardAndLeave;

  /// No description provided for @synkMember.
  ///
  /// In en, this message translates to:
  /// **'Synk member'**
  String get synkMember;

  /// No description provided for @synkUser.
  ///
  /// In en, this message translates to:
  /// **'Synk user'**
  String get synkUser;

  /// No description provided for @communityMember.
  ///
  /// In en, this message translates to:
  /// **'Community Member'**
  String get communityMember;

  /// No description provided for @anonymous.
  ///
  /// In en, this message translates to:
  /// **'Anonymous'**
  String get anonymous;

  /// No description provided for @untitledActivity.
  ///
  /// In en, this message translates to:
  /// **'Untitled activity'**
  String get untitledActivity;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @map.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get map;

  /// No description provided for @activities.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get activities;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @findYourMissingPiece.
  ///
  /// In en, this message translates to:
  /// **'Find your\nmissing piece.'**
  String get findYourMissingPiece;

  /// No description provided for @readyToSynk.
  ///
  /// In en, this message translates to:
  /// **'Ready to Synk?'**
  String get readyToSynk;

  /// No description provided for @joinThousandsAlreadyDoingWhatThey.
  ///
  /// In en, this message translates to:
  /// **'Join thousands already doing what they love, together!'**
  String get joinThousandsAlreadyDoingWhatThey;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// No description provided for @logInToConnectAndJoin.
  ///
  /// In en, this message translates to:
  /// **'Log in to connect and join activities around you.'**
  String get logInToConnectAndJoin;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailAddress;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @pleaseEnterYourUsername.
  ///
  /// In en, this message translates to:
  /// **'Please enter your username'**
  String get pleaseEnterYourUsername;

  /// No description provided for @pleaseEnterAValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get pleaseEnterAValidEmail;

  /// No description provided for @pleaseEnterYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get pleaseEnterYourPassword;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get logIn;

  /// No description provided for @dontHaveAnAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAnAccount;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @unableToLogIn.
  ///
  /// In en, this message translates to:
  /// **'Unable to log in.'**
  String get unableToLogIn;

  /// No description provided for @unableToLogInPleaseTry.
  ///
  /// In en, this message translates to:
  /// **'Unable to log in. Please try again.'**
  String get unableToLogInPleaseTry;

  /// No description provided for @accountSuspended.
  ///
  /// In en, this message translates to:
  /// **'This account is suspended.'**
  String get accountSuspended;

  /// No description provided for @suspendedTitle.
  ///
  /// In en, this message translates to:
  /// **'Your account is suspended'**
  String get suspendedTitle;

  /// No description provided for @suspendedMessage.
  ///
  /// In en, this message translates to:
  /// **'If you think this is a mistake, tell us what happened. We\'ll reply to {email}.'**
  String suspendedMessage(Object email);

  /// No description provided for @suspendedMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Your message'**
  String get suspendedMessageHint;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get contactSupport;

  /// No description provided for @suspendedSent.
  ///
  /// In en, this message translates to:
  /// **'Message sent. We\'ll reply by email.'**
  String get suspendedSent;

  /// No description provided for @noAccountFoundWithThisUsername.
  ///
  /// In en, this message translates to:
  /// **'No account found with this username'**
  String get noAccountFoundWithThisUsername;

  /// No description provided for @pleaseVerifyYourEmailFirst.
  ///
  /// In en, this message translates to:
  /// **'Please verify your email first.'**
  String get pleaseVerifyYourEmailFirst;

  /// No description provided for @incorrectUsernameOrPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect username or password'**
  String get incorrectUsernameOrPassword;

  /// No description provided for @incorrectEmailOrPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password'**
  String get incorrectEmailOrPassword;

  /// No description provided for @tellUsAboutYourself.
  ///
  /// In en, this message translates to:
  /// **'Tell us about\nyourself.'**
  String get tellUsAboutYourself;

  /// No description provided for @thisHelpsCustomizeYourCommunityExperience.
  ///
  /// In en, this message translates to:
  /// **'This helps customize your community experience.'**
  String get thisHelpsCustomizeYourCommunityExperience;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @birthday.
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get birthday;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @createYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Create your\naccount.'**
  String get createYourAccount;

  /// No description provided for @completeRegistration.
  ///
  /// In en, this message translates to:
  /// **'Complete Registration'**
  String get completeRegistration;

  /// No description provided for @eightPlusCharacters.
  ///
  /// In en, this message translates to:
  /// **'8+ characters'**
  String get eightPlusCharacters;

  /// No description provided for @uppercaseLetter.
  ///
  /// In en, this message translates to:
  /// **'Uppercase letter'**
  String get uppercaseLetter;

  /// No description provided for @lowercaseLetter.
  ///
  /// In en, this message translates to:
  /// **'Lowercase letter'**
  String get lowercaseLetter;

  /// No description provided for @aNumber.
  ///
  /// In en, this message translates to:
  /// **'A number'**
  String get aNumber;

  /// No description provided for @specialCharacter.
  ///
  /// In en, this message translates to:
  /// **'Special character'**
  String get specialCharacter;

  /// No description provided for @fullNameIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Full name is required'**
  String get fullNameIsRequired;

  /// No description provided for @nameCanBeAtMost50.
  ///
  /// In en, this message translates to:
  /// **'Name can be at most 50 characters'**
  String get nameCanBeAtMost50;

  /// No description provided for @nameCanOnlyContainLettersAnd.
  ///
  /// In en, this message translates to:
  /// **'Name can only contain letters and spaces'**
  String get nameCanOnlyContainLettersAnd;

  /// No description provided for @birthdayIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Birthday is required'**
  String get birthdayIsRequired;

  /// No description provided for @pleaseEnterAValidBirthday.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid birthday'**
  String get pleaseEnterAValidBirthday;

  /// No description provided for @ageMustBeBetween16And.
  ///
  /// In en, this message translates to:
  /// **'Age must be between 16 and 65 years'**
  String get ageMustBeBetween16And;

  /// No description provided for @emailAddressIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Email address is required'**
  String get emailAddressIsRequired;

  /// No description provided for @anAccountWithThisEmailAlready.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists'**
  String get anAccountWithThisEmailAlready;

  /// No description provided for @pleaseSelectYourGender.
  ///
  /// In en, this message translates to:
  /// **'Please select your gender'**
  String get pleaseSelectYourGender;

  /// No description provided for @passwordTooWeakMix.
  ///
  /// In en, this message translates to:
  /// **'Password is too weak. Please use at least {n} characters with a mix of letters, numbers, and symbols.'**
  String passwordTooWeakMix(Object n);

  /// No description provided for @weCouldntCreateYourAccountPlease.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t create your account. Please try again.'**
  String get weCouldntCreateYourAccountPlease;

  /// No description provided for @passwordIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordIsRequired;

  /// No description provided for @passwordMustBeAtLeast8.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordMustBeAtLeast8;

  /// No description provided for @passwordNeedsUppercase.
  ///
  /// In en, this message translates to:
  /// **'Password must contain at least 1 uppercase letter'**
  String get passwordNeedsUppercase;

  /// No description provided for @passwordNeedsLowercase.
  ///
  /// In en, this message translates to:
  /// **'Password must contain at least 1 lowercase letter'**
  String get passwordNeedsLowercase;

  /// No description provided for @passwordNeedsNumber.
  ///
  /// In en, this message translates to:
  /// **'Password must contain at least 1 number'**
  String get passwordNeedsNumber;

  /// No description provided for @passwordNeedsSpecial.
  ///
  /// In en, this message translates to:
  /// **'Password must contain at least 1 special character (e.g., @\$!%*?&)'**
  String get passwordNeedsSpecial;

  /// No description provided for @usernameIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Username is required'**
  String get usernameIsRequired;

  /// No description provided for @usernameMustBeAtLeast3.
  ///
  /// In en, this message translates to:
  /// **'Username must be at least 3 characters'**
  String get usernameMustBeAtLeast3;

  /// No description provided for @usernameCanBeAtMost30.
  ///
  /// In en, this message translates to:
  /// **'Username can be at most 30 characters'**
  String get usernameCanBeAtMost30;

  /// No description provided for @usernameCanOnlyContainLettersNumbers.
  ///
  /// In en, this message translates to:
  /// **'Username can only contain letters, numbers, underscores, and dots'**
  String get usernameCanOnlyContainLettersNumbers;

  /// No description provided for @whatAreYouInto.
  ///
  /// In en, this message translates to:
  /// **'What are you into?'**
  String get whatAreYouInto;

  /// No description provided for @pickTheActivitiesYouEnjoy.
  ///
  /// In en, this message translates to:
  /// **'Pick the activities you enjoy.'**
  String get pickTheActivitiesYouEnjoy;

  /// No description provided for @whereDoYouLikeToHave.
  ///
  /// In en, this message translates to:
  /// **'Where do you like to have fun?'**
  String get whereDoYouLikeToHave;

  /// No description provided for @tellUsWhatKindOfActivities.
  ///
  /// In en, this message translates to:
  /// **'Tell us what kind of activities you prefer.'**
  String get tellUsWhatKindOfActivities;

  /// No description provided for @howFarAreYouWillingTo.
  ///
  /// In en, this message translates to:
  /// **'How far are you willing to go?'**
  String get howFarAreYouWillingTo;

  /// No description provided for @chooseHowCloseYouWantYour.
  ///
  /// In en, this message translates to:
  /// **'Choose how close you want your activities to be.'**
  String get chooseHowCloseYouWantYour;

  /// No description provided for @indoor.
  ///
  /// In en, this message translates to:
  /// **'Indoor'**
  String get indoor;

  /// No description provided for @outdoor.
  ///
  /// In en, this message translates to:
  /// **'Outdoor'**
  String get outdoor;

  /// No description provided for @iDontMind.
  ///
  /// In en, this message translates to:
  /// **'I don\'t mind'**
  String get iDontMind;

  /// No description provided for @inTheCity.
  ///
  /// In en, this message translates to:
  /// **'In the city'**
  String get inTheCity;

  /// No description provided for @awayFromTheCity.
  ///
  /// In en, this message translates to:
  /// **'Away from the city'**
  String get awayFromTheCity;

  /// No description provided for @checkYourInbox.
  ///
  /// In en, this message translates to:
  /// **'Check your inbox'**
  String get checkYourInbox;

  /// No description provided for @weSentAConfirmationLinkTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a confirmation link to:'**
  String get weSentAConfirmationLinkTo;

  /// No description provided for @resendInSeconds.
  ///
  /// In en, this message translates to:
  /// **'Resend in {s}s'**
  String resendInSeconds(Object s);

  /// No description provided for @resendVerificationEmail.
  ///
  /// In en, this message translates to:
  /// **'Resend verification email'**
  String get resendVerificationEmail;

  /// No description provided for @iveConfirmedMyEmail.
  ///
  /// In en, this message translates to:
  /// **'I\'ve confirmed my email'**
  String get iveConfirmedMyEmail;

  /// No description provided for @backToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to Sign In'**
  String get backToSignIn;

  /// No description provided for @notConfirmedYetTapTheLink.
  ///
  /// In en, this message translates to:
  /// **'Not confirmed yet. Tap the link in the email first.'**
  String get notConfirmedYetTapTheLink;

  /// No description provided for @alreadyConfirmedGoBackAndSign.
  ///
  /// In en, this message translates to:
  /// **'Already confirmed? Go back and sign in.'**
  String get alreadyConfirmedGoBackAndSign;

  /// No description provided for @couldNotCheckRightNowPlease.
  ///
  /// In en, this message translates to:
  /// **'Could not check right now. Please try again.'**
  String get couldNotCheckRightNowPlease;

  /// No description provided for @verificationEmailResentPleaseCheckYour.
  ///
  /// In en, this message translates to:
  /// **'Verification email resent! Please check your inbox.'**
  String get verificationEmailResentPleaseCheckYour;

  /// No description provided for @failedToResendConfirmationEmail.
  ///
  /// In en, this message translates to:
  /// **'Failed to resend confirmation email.'**
  String get failedToResendConfirmationEmail;

  /// No description provided for @anUnexpectedErrorOccurredPleaseTry.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try again.'**
  String get anUnexpectedErrorOccurredPleaseTry;

  /// No description provided for @forgotYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get forgotYourPassword;

  /// No description provided for @itHappensEnterYourEmailAnd.
  ///
  /// In en, this message translates to:
  /// **'It happens. Enter your email and we\'ll send you a link to get back in.'**
  String get itHappensEnterYourEmailAnd;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendResetLink;

  /// No description provided for @backToLogIn.
  ///
  /// In en, this message translates to:
  /// **'Back to Log In'**
  String get backToLogIn;

  /// No description provided for @forYourSecurityWellSendA.
  ///
  /// In en, this message translates to:
  /// **'We only send a link if this email has a Synk account.'**
  String get forYourSecurityWellSendA;

  /// No description provided for @weSentAResetLinkTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a reset link to'**
  String get weSentAResetLinkTo;

  /// No description provided for @theLinkCanOnlyBeUsed.
  ///
  /// In en, this message translates to:
  /// **'The link can only be used once'**
  String get theLinkCanOnlyBeUsed;

  /// No description provided for @openItOnThisDeviceSo.
  ///
  /// In en, this message translates to:
  /// **'Open it on this device so Synk can sign you in'**
  String get openItOnThisDeviceSo;

  /// No description provided for @notThereCheckYourSpamFolder.
  ///
  /// In en, this message translates to:
  /// **'Not there? Check your spam folder'**
  String get notThereCheckYourSpamFolder;

  /// No description provided for @resendLink.
  ///
  /// In en, this message translates to:
  /// **'Resend link'**
  String get resendLink;

  /// No description provided for @resendLinkCountdown.
  ///
  /// In en, this message translates to:
  /// **'Resend link in 0:{ss}'**
  String resendLinkCountdown(Object ss);

  /// No description provided for @wrongEmailEditIt.
  ///
  /// In en, this message translates to:
  /// **'Wrong email? Edit it'**
  String get wrongEmailEditIt;

  /// No description provided for @unableToSendTheLink.
  ///
  /// In en, this message translates to:
  /// **'Unable to send the link.'**
  String get unableToSendTheLink;

  /// No description provided for @aNewLinkIsOnIts.
  ///
  /// In en, this message translates to:
  /// **'A new link is on its way.'**
  String get aNewLinkIsOnIts;

  /// No description provided for @pleaseEnterYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get pleaseEnterYourEmail;

  /// No description provided for @pleaseEnterAValidEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get pleaseEnterAValidEmailAddress;

  /// No description provided for @pleaseConfirmYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get pleaseConfirmYourPassword;

  /// No description provided for @couldntSendTheLinkCheckYour.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the link. Check your connection and try again.'**
  String get couldntSendTheLinkCheckYour;

  /// No description provided for @pleaseWaitAMomentBeforeRequesting.
  ///
  /// In en, this message translates to:
  /// **'Please wait a moment before requesting another link.'**
  String get pleaseWaitAMomentBeforeRequesting;

  /// No description provided for @passwordTooWeakMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password is too weak. Please use at least {n} characters.'**
  String passwordTooWeakMinLength(Object n);

  /// No description provided for @thatsYourCurrentPasswordPickA.
  ///
  /// In en, this message translates to:
  /// **'That\'s your current password. Pick a new one.'**
  String get thatsYourCurrentPasswordPickA;

  /// No description provided for @thisLinkIsNoLongerValid.
  ///
  /// In en, this message translates to:
  /// **'This link is no longer valid. Please request a new one.'**
  String get thisLinkIsNoLongerValid;

  /// No description provided for @createANewPassword.
  ///
  /// In en, this message translates to:
  /// **'Create a new password'**
  String get createANewPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @reTypePassword.
  ///
  /// In en, this message translates to:
  /// **'Re-type password'**
  String get reTypePassword;

  /// No description provided for @updatePassword.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get updatePassword;

  /// No description provided for @unableToUpdateYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Unable to update your password.'**
  String get unableToUpdateYourPassword;

  /// No description provided for @passwordNotChanged.
  ///
  /// In en, this message translates to:
  /// **'Password not changed.'**
  String get passwordNotChanged;

  /// No description provided for @thisLinkHasExpired.
  ///
  /// In en, this message translates to:
  /// **'This link has expired'**
  String get thisLinkHasExpired;

  /// No description provided for @resetLinksCanOnlyBeUsed.
  ///
  /// In en, this message translates to:
  /// **'Reset links can only be used once and expire after a short time. Request a fresh one and we\'ll get you back in.'**
  String get resetLinksCanOnlyBeUsed;

  /// No description provided for @requestANewLink.
  ///
  /// In en, this message translates to:
  /// **'Request a new link'**
  String get requestANewLink;

  /// No description provided for @youreBackIn.
  ///
  /// In en, this message translates to:
  /// **'You\'re back in.'**
  String get youreBackIn;

  /// No description provided for @yourNewPasswordIsSetLog.
  ///
  /// In en, this message translates to:
  /// **'Your new password is set. Log in to pick up where you left off.'**
  String get yourNewPasswordIsSetLog;

  /// No description provided for @thisLinkHasExpiredOrWas.
  ///
  /// In en, this message translates to:
  /// **'This link has expired or was already used. Please request a new one.'**
  String get thisLinkHasExpiredOrWas;

  /// No description provided for @confirmedNowOpenTheLinkSent.
  ///
  /// In en, this message translates to:
  /// **'Confirmed. Now open the link sent to your other email address.'**
  String get confirmedNowOpenTheLinkSent;

  /// No description provided for @yourEmailAddressWasUpdated.
  ///
  /// In en, this message translates to:
  /// **'Your email address was updated.'**
  String get yourEmailAddressWasUpdated;

  /// No description provided for @welcomeName.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}'**
  String welcomeName(Object name);

  /// No description provided for @welcomeToSynk.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Synk'**
  String get welcomeToSynk;

  /// No description provided for @heyName.
  ///
  /// In en, this message translates to:
  /// **'Hey {name}'**
  String heyName(Object name);

  /// No description provided for @heyThere.
  ///
  /// In en, this message translates to:
  /// **'Hey there'**
  String get heyThere;

  /// No description provided for @letsFindYourPeople.
  ///
  /// In en, this message translates to:
  /// **'Let\'s find your people'**
  String get letsFindYourPeople;

  /// No description provided for @readyForSomethingNew.
  ///
  /// In en, this message translates to:
  /// **'Ready for something new?'**
  String get readyForSomethingNew;

  /// Same as readyForSomethingNew, for women; Arabic changes the adjective
  ///
  /// In en, this message translates to:
  /// **'Ready for something new?'**
  String get readyForSomethingNewFemale;

  /// No description provided for @searchActivitiesOrLocations.
  ///
  /// In en, this message translates to:
  /// **'Search activities or locations...'**
  String get searchActivitiesOrLocations;

  /// No description provided for @topPickLikesIndoor.
  ///
  /// In en, this message translates to:
  /// **'You like indoor plans'**
  String get topPickLikesIndoor;

  /// No description provided for @topPickLikesOutdoor.
  ///
  /// In en, this message translates to:
  /// **'You like outdoor plans'**
  String get topPickLikesOutdoor;

  /// No description provided for @topPickYouLike.
  ///
  /// In en, this message translates to:
  /// **'You like {interest}'**
  String topPickYouLike(Object interest);

  /// No description provided for @topPickPopularNearYou.
  ///
  /// In en, this message translates to:
  /// **'Popular near you'**
  String get topPickPopularNearYou;

  /// No description provided for @topPickDistanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String topPickDistanceKm(Object km);

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @noPlansMatchQuery.
  ///
  /// In en, this message translates to:
  /// **'No plans match \"{q}\"'**
  String noPlansMatchQuery(Object q);

  /// No description provided for @noPlansMatchYourFilters.
  ///
  /// In en, this message translates to:
  /// **'No plans match your filters'**
  String get noPlansMatchYourFilters;

  /// No description provided for @noCategoryPlans.
  ///
  /// In en, this message translates to:
  /// **'No {category} plans {when}'**
  String noCategoryPlans(Object category, Object when);

  /// No description provided for @weCouldntReachSynk.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t reach Synk'**
  String get weCouldntReachSynk;

  /// No description provided for @itsQuietHereForNow.
  ///
  /// In en, this message translates to:
  /// **'It\'s quiet here for now'**
  String get itsQuietHereForNow;

  /// No description provided for @checkYourConnectionAndTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get checkYourConnectionAndTryAgain;

  /// No description provided for @newPlansPopUpAllThe.
  ///
  /// In en, this message translates to:
  /// **'New plans pop up all the time. Tap + to start one.'**
  String get newPlansPopUpAllThe;

  /// No description provided for @createOne.
  ///
  /// In en, this message translates to:
  /// **'Create one'**
  String get createOne;

  /// No description provided for @haveACode.
  ///
  /// In en, this message translates to:
  /// **'Have a code?'**
  String get haveACode;

  /// No description provided for @haveAnActivityCodeJoinWith.
  ///
  /// In en, this message translates to:
  /// **'Have an activity code? Join with it'**
  String get haveAnActivityCodeJoinWith;

  /// No description provided for @unableToLoadActivitiesPullDown.
  ///
  /// In en, this message translates to:
  /// **'Unable to load activities. Pull down to refresh.'**
  String get unableToLoadActivitiesPullDown;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @filtersActive.
  ///
  /// In en, this message translates to:
  /// **'Filters, {n} active'**
  String filtersActive(Object n);

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @soonest.
  ///
  /// In en, this message translates to:
  /// **'Soonest'**
  String get soonest;

  /// No description provided for @latest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get latest;

  /// No description provided for @nearest.
  ///
  /// In en, this message translates to:
  /// **'Nearest'**
  String get nearest;

  /// No description provided for @farthest.
  ///
  /// In en, this message translates to:
  /// **'Farthest'**
  String get farthest;

  /// No description provided for @almostFull.
  ///
  /// In en, this message translates to:
  /// **'Almost full'**
  String get almostFull;

  /// No description provided for @mostSpots.
  ///
  /// In en, this message translates to:
  /// **'Most spots'**
  String get mostSpots;

  /// No description provided for @any.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get any;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @morning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get morning;

  /// No description provided for @evening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get evening;

  /// No description provided for @night.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get night;

  /// No description provided for @slotMorningHours.
  ///
  /// In en, this message translates to:
  /// **'6 AM–12 PM'**
  String get slotMorningHours;

  /// No description provided for @slotEveningHours.
  ///
  /// In en, this message translates to:
  /// **'12–9 PM'**
  String get slotEveningHours;

  /// No description provided for @slotNightHours.
  ///
  /// In en, this message translates to:
  /// **'9 PM–12 AM'**
  String get slotNightHours;

  /// No description provided for @within.
  ///
  /// In en, this message translates to:
  /// **'Within'**
  String get within;

  /// No description provided for @fiveKm.
  ///
  /// In en, this message translates to:
  /// **'5 km'**
  String get fiveKm;

  /// No description provided for @locating.
  ///
  /// In en, this message translates to:
  /// **'Locating…'**
  String get locating;

  /// No description provided for @allowLocation.
  ///
  /// In en, this message translates to:
  /// **'Allow location'**
  String get allowLocation;

  /// No description provided for @startingFrom.
  ///
  /// In en, this message translates to:
  /// **'Starting from'**
  String get startingFrom;

  /// No description provided for @fromTime.
  ///
  /// In en, this message translates to:
  /// **'From {time}'**
  String fromTime(Object time);

  /// No description provided for @pickATime.
  ///
  /// In en, this message translates to:
  /// **'Pick a time'**
  String get pickATime;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @spots.
  ///
  /// In en, this message translates to:
  /// **'Spots'**
  String get spots;

  /// No description provided for @oneLeft.
  ///
  /// In en, this message translates to:
  /// **'1 left'**
  String get oneLeft;

  /// No description provided for @hasSpots.
  ///
  /// In en, this message translates to:
  /// **'Has spots'**
  String get hasSpots;

  /// No description provided for @full.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get full;

  /// No description provided for @noMatchesTryFewerFilters.
  ///
  /// In en, this message translates to:
  /// **'No matches, try fewer filters'**
  String get noMatchesTryFewerFilters;

  /// No description provided for @showOneActivity.
  ///
  /// In en, this message translates to:
  /// **'Show 1 activity'**
  String get showOneActivity;

  /// No description provided for @showActivities.
  ///
  /// In en, this message translates to:
  /// **'Show {n} activities'**
  String showActivities(Object n);

  /// No description provided for @todayAtTime.
  ///
  /// In en, this message translates to:
  /// **'Today, {time}'**
  String todayAtTime(Object time);

  /// No description provided for @tomorrowAtTime.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow, {time}'**
  String tomorrowAtTime(Object time);

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// No description provided for @oneMoreNeeded.
  ///
  /// In en, this message translates to:
  /// **'One More Needed'**
  String get oneMoreNeeded;

  /// No description provided for @joinedOfMaxGoing.
  ///
  /// In en, this message translates to:
  /// **'{joined}/{max} going'**
  String joinedOfMaxGoing(Object joined, Object max);

  /// No description provided for @waitlisted.
  ///
  /// In en, this message translates to:
  /// **'Waitlisted'**
  String get waitlisted;

  /// No description provided for @code.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get code;

  /// No description provided for @dateAndTime.
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get dateAndTime;

  /// No description provided for @viewOnMap.
  ///
  /// In en, this message translates to:
  /// **'View on map'**
  String get viewOnMap;

  /// No description provided for @openInGoogleMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Google Maps'**
  String get openInGoogleMaps;

  /// No description provided for @couldntOpenGoogleMaps.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open Google Maps.'**
  String get couldntOpenGoogleMaps;

  /// No description provided for @participants.
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get participants;

  /// No description provided for @joinedOfMaxSpots.
  ///
  /// In en, this message translates to:
  /// **'{joined} / {max} spots'**
  String joinedOfMaxSpots(Object joined, Object max);

  /// No description provided for @youllSeeWhosGoingOnceThe.
  ///
  /// In en, this message translates to:
  /// **'You\'ll see who\'s going once the host accepts you.'**
  String get youllSeeWhosGoingOnceThe;

  /// No description provided for @host.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get host;

  /// No description provided for @activityCode.
  ///
  /// In en, this message translates to:
  /// **'Activity code'**
  String get activityCode;

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get copyCode;

  /// No description provided for @activityCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Activity code copied'**
  String get activityCodeCopied;

  /// No description provided for @deleteActivity.
  ///
  /// In en, this message translates to:
  /// **'Delete activity'**
  String get deleteActivity;

  /// No description provided for @youreOnTheWaitlist.
  ///
  /// In en, this message translates to:
  /// **'You\'re on the waitlist'**
  String get youreOnTheWaitlist;

  /// No description provided for @waitlistPeopleAhead.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =0{You\'re next in the waitlist} =1{1 person ahead of you} other{{n} people ahead of you}}'**
  String waitlistPeopleAhead(int n);

  /// No description provided for @waitingForHostApproval.
  ///
  /// In en, this message translates to:
  /// **'Waiting for host approval'**
  String get waitingForHostApproval;

  /// No description provided for @youveJoinedThisActivity.
  ///
  /// In en, this message translates to:
  /// **'You\'ve joined this activity'**
  String get youveJoinedThisActivity;

  /// No description provided for @joinWaitlist.
  ///
  /// In en, this message translates to:
  /// **'Join waitlist'**
  String get joinWaitlist;

  /// No description provided for @joinActivity.
  ///
  /// In en, this message translates to:
  /// **'Join activity'**
  String get joinActivity;

  /// No description provided for @leaveActivity.
  ///
  /// In en, this message translates to:
  /// **'Leave Activity'**
  String get leaveActivity;

  /// No description provided for @leaveActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave activity?'**
  String get leaveActivityTitle;

  /// No description provided for @confirmLeaveActivity.
  ///
  /// In en, this message translates to:
  /// **'Leave this activity?'**
  String get confirmLeaveActivity;

  /// No description provided for @stay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get stay;

  /// No description provided for @youLeftTheActivity.
  ///
  /// In en, this message translates to:
  /// **'You Left the Activity'**
  String get youLeftTheActivity;

  /// No description provided for @youHaveSuccessfullyLeftThisActivity.
  ///
  /// In en, this message translates to:
  /// **'You have successfully left this activity.'**
  String get youHaveSuccessfullyLeftThisActivity;

  /// No description provided for @leaveWaitlistTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave waitlist?'**
  String get leaveWaitlistTitle;

  /// No description provided for @confirmLeaveWaitlist.
  ///
  /// In en, this message translates to:
  /// **'Leave the waitlist?'**
  String get confirmLeaveWaitlist;

  /// No description provided for @stayOnWaitlist.
  ///
  /// In en, this message translates to:
  /// **'Stay on Waitlist'**
  String get stayOnWaitlist;

  /// No description provided for @leaveWaitlist.
  ///
  /// In en, this message translates to:
  /// **'Leave Waitlist'**
  String get leaveWaitlist;

  /// No description provided for @youLeftTheWaitlist.
  ///
  /// In en, this message translates to:
  /// **'You Left the Waitlist'**
  String get youLeftTheWaitlist;

  /// No description provided for @youHaveBeenRemovedFromThe.
  ///
  /// In en, this message translates to:
  /// **'You have been removed from the waitlist.'**
  String get youHaveBeenRemovedFromThe;

  /// No description provided for @cancelRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel request?'**
  String get cancelRequestTitle;

  /// No description provided for @confirmCancelRequest.
  ///
  /// In en, this message translates to:
  /// **'Cancel your request?'**
  String get confirmCancelRequest;

  /// No description provided for @keepRequest.
  ///
  /// In en, this message translates to:
  /// **'Keep Request'**
  String get keepRequest;

  /// No description provided for @cancelRequest.
  ///
  /// In en, this message translates to:
  /// **'Cancel Request'**
  String get cancelRequest;

  /// No description provided for @requestCancelled.
  ///
  /// In en, this message translates to:
  /// **'Request Cancelled'**
  String get requestCancelled;

  /// No description provided for @yourJoinRequestHasBeenCancelled.
  ///
  /// In en, this message translates to:
  /// **'Your join request has been cancelled.'**
  String get yourJoinRequestHasBeenCancelled;

  /// No description provided for @youAreNowTheHostOf.
  ///
  /// In en, this message translates to:
  /// **'You are now the host of this activity.'**
  String get youAreNowTheHostOf;

  /// No description provided for @transferHostingAndLeave.
  ///
  /// In en, this message translates to:
  /// **'Transfer hosting and leave?'**
  String get transferHostingAndLeave;

  /// No description provided for @transferHostMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} becomes the host.'**
  String transferHostMessage(Object name);

  /// No description provided for @transferAndLeave.
  ///
  /// In en, this message translates to:
  /// **'Transfer & Leave'**
  String get transferAndLeave;

  /// No description provided for @newHostIs.
  ///
  /// In en, this message translates to:
  /// **'{name} is now the host.'**
  String newHostIs(Object name);

  /// No description provided for @chooseANewHost.
  ///
  /// In en, this message translates to:
  /// **'Choose a new host'**
  String get chooseANewHost;

  /// No description provided for @thePersonYouChooseGetsFull.
  ///
  /// In en, this message translates to:
  /// **'The person you choose gets full host permissions, including managing join requests and deleting the activity. You will leave the activity.'**
  String get thePersonYouChooseGetsFull;

  /// No description provided for @unableToLoadParticipantsPleaseTry.
  ///
  /// In en, this message translates to:
  /// **'Unable to load participants. Please try again.'**
  String get unableToLoadParticipantsPleaseTry;

  /// No description provided for @noOneCanTakeOverYet.
  ///
  /// In en, this message translates to:
  /// **'No one can take over yet. Only joined participants can become the host. You can delete the activity instead.'**
  String get noOneCanTakeOverYet;

  /// No description provided for @thisActivityIsNoLongerAvailable.
  ///
  /// In en, this message translates to:
  /// **'This activity is no longer available.'**
  String get thisActivityIsNoLongerAvailable;

  /// No description provided for @unableToOpenThisActivity.
  ///
  /// In en, this message translates to:
  /// **'Unable to open this activity.'**
  String get unableToOpenThisActivity;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @hosting.
  ///
  /// In en, this message translates to:
  /// **'Hosting'**
  String get hosting;

  /// No description provided for @joined.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get joined;

  /// No description provided for @requested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get requested;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @past.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get past;

  /// No description provided for @noPastActivities.
  ///
  /// In en, this message translates to:
  /// **'No past activities'**
  String get noPastActivities;

  /// No description provided for @activitiesYouveBeenPartOfWill.
  ///
  /// In en, this message translates to:
  /// **'Activities you\'ve been part of will show up here.'**
  String get activitiesYouveBeenPartOfWill;

  /// No description provided for @noUpcomingActivities.
  ///
  /// In en, this message translates to:
  /// **'No upcoming activities'**
  String get noUpcomingActivities;

  /// No description provided for @joinOneFromHomeOrTap.
  ///
  /// In en, this message translates to:
  /// **'Join one from Home, or tap + to plan your own.'**
  String get joinOneFromHomeOrTap;

  /// No description provided for @joinRequests.
  ///
  /// In en, this message translates to:
  /// **'Join Requests'**
  String get joinRequests;

  /// No description provided for @deleteActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete activity?'**
  String get deleteActivityTitle;

  /// No description provided for @thisActionCannotBeUndoneThe.
  ///
  /// In en, this message translates to:
  /// **'It\'ll be gone for everyone.'**
  String get thisActionCannotBeUndoneThe;

  /// No description provided for @keepActivity.
  ///
  /// In en, this message translates to:
  /// **'Keep Activity'**
  String get keepActivity;

  /// No description provided for @deleteActivityButton.
  ///
  /// In en, this message translates to:
  /// **'Delete Activity'**
  String get deleteActivityButton;

  /// No description provided for @activityDeleted.
  ///
  /// In en, this message translates to:
  /// **'Activity Deleted'**
  String get activityDeleted;

  /// No description provided for @theActivityHasBeenDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'The activity has been deleted successfully.'**
  String get theActivityHasBeenDeletedSuccessfully;

  /// No description provided for @unableToDeleteTheActivityPlease.
  ///
  /// In en, this message translates to:
  /// **'Unable to delete the activity. Please try again.'**
  String get unableToDeleteTheActivityPlease;

  /// No description provided for @joinWithACode.
  ///
  /// In en, this message translates to:
  /// **'Join with a code'**
  String get joinWithACode;

  /// No description provided for @enterThe6DigitActivityCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit activity code.'**
  String get enterThe6DigitActivityCode;

  /// No description provided for @joinActivityButton.
  ///
  /// In en, this message translates to:
  /// **'Join Activity'**
  String get joinActivityButton;

  /// No description provided for @enterAValid6DigitActivity.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 6-digit activity code.'**
  String get enterAValid6DigitActivity;

  /// No description provided for @unableToJoinTheActivityPlease.
  ///
  /// In en, this message translates to:
  /// **'Unable to join the activity. Please try again.'**
  String get unableToJoinTheActivityPlease;

  /// No description provided for @unableToJoin.
  ///
  /// In en, this message translates to:
  /// **'Unable to Join'**
  String get unableToJoin;

  /// No description provided for @thisActivityConflictsWithOneYouve.
  ///
  /// In en, this message translates to:
  /// **'Another activity you host or have joined starts at the same time. Delete the one you host or leave the one you joined, then try again.'**
  String get thisActivityConflictsWithOneYouve;

  /// No description provided for @joinedTitle.
  ///
  /// In en, this message translates to:
  /// **'Joined!'**
  String get joinedTitle;

  /// No description provided for @alreadyJoined.
  ///
  /// In en, this message translates to:
  /// **'Already Joined'**
  String get alreadyJoined;

  /// No description provided for @requestSent.
  ///
  /// In en, this message translates to:
  /// **'Request Sent!'**
  String get requestSent;

  /// No description provided for @requestAlreadySent.
  ///
  /// In en, this message translates to:
  /// **'Request Already Sent'**
  String get requestAlreadySent;

  /// No description provided for @addedToWaitlist.
  ///
  /// In en, this message translates to:
  /// **'Added to Waitlist!'**
  String get addedToWaitlist;

  /// No description provided for @alreadyWaitlisted.
  ///
  /// In en, this message translates to:
  /// **'Already Waitlisted'**
  String get alreadyWaitlisted;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}m ago'**
  String minutesAgo(Object n);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}h ago'**
  String hoursAgo(Object n);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}d ago'**
  String daysAgo(Object n);

  /// No description provided for @requestCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 request} other{{n} requests}}'**
  String requestCount(int n);

  /// No description provided for @requestApproved.
  ///
  /// In en, this message translates to:
  /// **'Request Approved!'**
  String get requestApproved;

  /// No description provided for @requestRejected.
  ///
  /// In en, this message translates to:
  /// **'Request Rejected'**
  String get requestRejected;

  /// No description provided for @requestApprovedTheUserWasAdded.
  ///
  /// In en, this message translates to:
  /// **'Request approved. The user was added to the waitlist.'**
  String get requestApprovedTheUserWasAdded;

  /// No description provided for @requestApprovedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Request approved successfully.'**
  String get requestApprovedSuccessfully;

  /// No description provided for @requestRejectedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Request rejected successfully.'**
  String get requestRejectedSuccessfully;

  /// No description provided for @unableToReviewTheRequestPlease.
  ///
  /// In en, this message translates to:
  /// **'Unable to review the request. Please try again.'**
  String get unableToReviewTheRequestPlease;

  /// No description provided for @unableToLoadJoinRequestsPlease.
  ///
  /// In en, this message translates to:
  /// **'Unable to load join requests. Please try again.'**
  String get unableToLoadJoinRequestsPlease;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @noPendingRequests.
  ///
  /// In en, this message translates to:
  /// **'No pending requests'**
  String get noPendingRequests;

  /// No description provided for @requestsForYourPrivateActivitiesWill.
  ///
  /// In en, this message translates to:
  /// **'Requests for your private activities will appear here.'**
  String get requestsForYourPrivateActivitiesWill;

  /// No description provided for @newActivity.
  ///
  /// In en, this message translates to:
  /// **'New Activity'**
  String get newActivity;

  /// No description provided for @createActivity.
  ///
  /// In en, this message translates to:
  /// **'Create activity'**
  String get createActivity;

  /// No description provided for @whatWhereAndWhen.
  ///
  /// In en, this message translates to:
  /// **'What, where & when'**
  String get whatWhereAndWhen;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @discardActivity.
  ///
  /// In en, this message translates to:
  /// **'Discard activity?'**
  String get discardActivity;

  /// No description provided for @yourActivityIsLiveAndReady.
  ///
  /// In en, this message translates to:
  /// **'Your activity is live and ready for people to join.'**
  String get yourActivityIsLiveAndReady;

  /// No description provided for @activityCreated.
  ///
  /// In en, this message translates to:
  /// **'Activity created!'**
  String get activityCreated;

  /// No description provided for @viewActivity.
  ///
  /// In en, this message translates to:
  /// **'View activity'**
  String get viewActivity;

  /// No description provided for @activityTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity title'**
  String get activityTitle;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @activityTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Morning padel'**
  String get activityTitleHint;

  /// No description provided for @tapToChange.
  ///
  /// In en, this message translates to:
  /// **'Tap to change'**
  String get tapToChange;

  /// No description provided for @chooseATime.
  ///
  /// In en, this message translates to:
  /// **'Choose a time'**
  String get chooseATime;

  /// No description provided for @pickAStartTime.
  ///
  /// In en, this message translates to:
  /// **'Pick a start time'**
  String get pickAStartTime;

  /// No description provided for @setDate.
  ///
  /// In en, this message translates to:
  /// **'Set date'**
  String get setDate;

  /// No description provided for @setTime.
  ///
  /// In en, this message translates to:
  /// **'Set time'**
  String get setTime;

  /// No description provided for @searchForAPlace.
  ///
  /// In en, this message translates to:
  /// **'Search for a place'**
  String get searchForAPlace;

  /// No description provided for @locationSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Padel club, café, gym…'**
  String get locationSearchHint;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @startTypingToSearchRiyadhVenues.
  ///
  /// In en, this message translates to:
  /// **'Start typing to search Riyadh venues.'**
  String get startTypingToSearchRiyadhVenues;

  /// No description provided for @useThisLocation.
  ///
  /// In en, this message translates to:
  /// **'Use this location'**
  String get useThisLocation;

  /// No description provided for @findingAddress.
  ///
  /// In en, this message translates to:
  /// **'Finding address…'**
  String get findingAddress;

  /// No description provided for @pinnedLocation.
  ///
  /// In en, this message translates to:
  /// **'Pinned location'**
  String get pinnedLocation;

  /// No description provided for @noMatchesFound.
  ///
  /// In en, this message translates to:
  /// **'No matches found.'**
  String get noMatchesFound;

  /// No description provided for @numberOfPeople.
  ///
  /// In en, this message translates to:
  /// **'Number of people'**
  String get numberOfPeople;

  /// No description provided for @youPlusAvailable.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{You + 1 available spot} other{You + {n} available spots}}'**
  String youPlusAvailable(int n);

  /// No description provided for @includingYou.
  ///
  /// In en, this message translates to:
  /// **'Including you'**
  String get includingYou;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @activityDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Beginners welcome, bring water'**
  String get activityDescriptionHint;

  /// No description provided for @photo.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photo;

  /// No description provided for @photos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @addAPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get addAPhoto;

  /// No description provided for @photoAdded.
  ///
  /// In en, this message translates to:
  /// **'Photo added'**
  String get photoAdded;

  /// No description provided for @changePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get changePhoto;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// No description provided for @visibility.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get visibility;

  /// No description provided for @public.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get public;

  /// No description provided for @anyoneCanFindAndJoin.
  ///
  /// In en, this message translates to:
  /// **'Anyone can find and join'**
  String get anyoneCanFindAndJoin;

  /// No description provided for @private.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get private;

  /// No description provided for @joinByCodeYouApprove.
  ///
  /// In en, this message translates to:
  /// **'Join by code, you approve'**
  String get joinByCodeYouApprove;

  /// No description provided for @setting.
  ///
  /// In en, this message translates to:
  /// **'Setting'**
  String get setting;

  /// No description provided for @settingIndoor.
  ///
  /// In en, this message translates to:
  /// **'Indoor'**
  String get settingIndoor;

  /// No description provided for @settingOutdoor.
  ///
  /// In en, this message translates to:
  /// **'Outdoor'**
  String get settingOutdoor;

  /// No description provided for @chooseIndoorOrOutdoor.
  ///
  /// In en, this message translates to:
  /// **'Choose indoor or outdoor'**
  String get chooseIndoorOrOutdoor;

  /// No description provided for @whenLabel.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get whenLabel;

  /// No description provided for @whereLabel.
  ///
  /// In en, this message translates to:
  /// **'Where'**
  String get whereLabel;

  /// No description provided for @people.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get people;

  /// No description provided for @peopleSummary.
  ///
  /// In en, this message translates to:
  /// **'{n} including you'**
  String peopleSummary(Object n);

  /// No description provided for @addATitle.
  ///
  /// In en, this message translates to:
  /// **'Add a title'**
  String get addATitle;

  /// No description provided for @keepItToLetters.
  ///
  /// In en, this message translates to:
  /// **'Keep it to {n} characters'**
  String keepItToLetters(Object n);

  /// No description provided for @useLettersOnly.
  ///
  /// In en, this message translates to:
  /// **'Activity names can contain letters, numbers, spaces, &, apostrophes, and commas only.'**
  String get useLettersOnly;

  /// No description provided for @useEnglishLettersOnly.
  ///
  /// In en, this message translates to:
  /// **'Use English letters only'**
  String get useEnglishLettersOnly;

  /// No description provided for @keepItToCharacters.
  ///
  /// In en, this message translates to:
  /// **'Keep it to {n} characters'**
  String keepItToCharacters(Object n);

  /// No description provided for @chooseALocation.
  ///
  /// In en, this message translates to:
  /// **'Choose a location'**
  String get chooseALocation;

  /// No description provided for @pickADate.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get pickADate;

  /// No description provided for @chooseADateWithinTheNext.
  ///
  /// In en, this message translates to:
  /// **'Choose a date within the next 3 months'**
  String get chooseADateWithinTheNext;

  /// No description provided for @thisTimeHasAlreadyPassed.
  ///
  /// In en, this message translates to:
  /// **'This time has already passed'**
  String get thisTimeHasAlreadyPassed;

  /// No description provided for @youAlreadyHaveAnActivityAtThisTime.
  ///
  /// In en, this message translates to:
  /// **'This time overlaps with another one of your activities. Choose a different date or time.'**
  String get youAlreadyHaveAnActivityAtThisTime;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @noNotificationsYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet'**
  String get noNotificationsYet;

  /// No description provided for @noNotificationsHint.
  ///
  /// In en, this message translates to:
  /// **'Join or create an activity to get updates here.'**
  String get noNotificationsHint;

  /// No description provided for @couldntLoadNotifications.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load notifications. Pull down to try again.'**
  String get couldntLoadNotifications;

  /// No description provided for @notifWaitlistPromotion.
  ///
  /// In en, this message translates to:
  /// **'A spot opened up! You\'ve joined {title}.'**
  String notifWaitlistPromotion(String title);

  /// No description provided for @notifActivityUpdated.
  ///
  /// In en, this message translates to:
  /// **'{title} was updated. Check the new details.'**
  String notifActivityUpdated(String title);

  /// No description provided for @notifActivityDeleted.
  ///
  /// In en, this message translates to:
  /// **'{title} was cancelled by the host.'**
  String notifActivityDeleted(String title);

  /// No description provided for @notifRequestAccepted.
  ///
  /// In en, this message translates to:
  /// **'Your request to join {title} was accepted. You\'re in!'**
  String notifRequestAccepted(String title);

  /// No description provided for @notifRequestRejected.
  ///
  /// In en, this message translates to:
  /// **'Your request to join {title} was declined.'**
  String notifRequestRejected(String title);

  /// No description provided for @notifRequestReceived.
  ///
  /// In en, this message translates to:
  /// **'Someone asked to join {title}. Tap to review.'**
  String notifRequestReceived(String title);

  /// No description provided for @notifActivityFull.
  ///
  /// In en, this message translates to:
  /// **'{title} is full! Every spot has been taken.'**
  String notifActivityFull(String title);

  /// No description provided for @friendRequestNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'New friend request'**
  String get friendRequestNotificationTitle;

  /// No description provided for @notifFriendRequestReceived.
  ///
  /// In en, this message translates to:
  /// **'{name} sent you a friend request.'**
  String notifFriendRequestReceived(String name);

  /// No description provided for @friendRequestAcceptedNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Friend request accepted'**
  String get friendRequestAcceptedNotificationTitle;

  /// No description provided for @notifFriendRequestAccepted.
  ///
  /// In en, this message translates to:
  /// **'{name} accepted your friend request. You\'re now friends!'**
  String notifFriendRequestAccepted(String name);

  /// No description provided for @notifHostAssigned.
  ///
  /// In en, this message translates to:
  /// **'You\'re now the host of {title}.'**
  String notifHostAssigned(String title);

  /// No description provided for @notifActivityConflict.
  ///
  /// In en, this message translates to:
  /// **'{title} was rescheduled and now overlaps another activity. Tap to resolve.'**
  String notifActivityConflict(String title);

  /// No description provided for @conflictJoinJoined.
  ///
  /// In en, this message translates to:
  /// **'This overlaps with {title}, which you\'ve already joined. Leave it first to join this one.'**
  String conflictJoinJoined(String title);

  /// No description provided for @conflictJoinHosting.
  ///
  /// In en, this message translates to:
  /// **'This overlaps with {title}, which you\'re hosting. Change its time or delete it to join this one.'**
  String conflictJoinHosting(String title);

  /// No description provided for @conflictCreateJoined.
  ///
  /// In en, this message translates to:
  /// **'This time overlaps with {title}, which you\'ve joined. Pick another time or leave that activity.'**
  String conflictCreateJoined(String title);

  /// No description provided for @conflictCreateHosting.
  ///
  /// In en, this message translates to:
  /// **'This time overlaps with {title}, which you\'re hosting. Pick another time.'**
  String conflictCreateHosting(String title);

  /// No description provided for @conflictJoinUnknown.
  ///
  /// In en, this message translates to:
  /// **'This activity overlaps with another one you\'ve joined or are hosting.'**
  String get conflictJoinUnknown;

  /// No description provided for @serverParticipantHasConflict.
  ///
  /// In en, this message translates to:
  /// **'This participant already has another activity at this time. Choose someone else.'**
  String get serverParticipantHasConflict;

  /// No description provided for @pleaseCompleteEveryStepBeforeCreating.
  ///
  /// In en, this message translates to:
  /// **'Please complete every step before creating.'**
  String get pleaseCompleteEveryStepBeforeCreating;

  /// No description provided for @weCouldntCreateYourActivityPlease.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t create your activity. Please try again.'**
  String get weCouldntCreateYourActivityPlease;

  /// No description provided for @activityCreatedPhotoNotAdded.
  ///
  /// In en, this message translates to:
  /// **'Your activity was created, but the photo couldn\'t be added to it.'**
  String get activityCreatedPhotoNotAdded;

  /// No description provided for @activityCreatedPhotoNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Your activity was created, but the photo couldn\'t be saved.'**
  String get activityCreatedPhotoNotSaved;

  /// No description provided for @couldntOpenYourPhotosPleaseTry.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open your photos. Please try again.'**
  String get couldntOpenYourPhotosPleaseTry;

  /// No description provided for @thatFileIsntAJpegOr.
  ///
  /// In en, this message translates to:
  /// **'That file isn\'t a JPEG or PNG image.'**
  String get thatFileIsntAJpegOr;

  /// No description provided for @thisImagesFileTypeAndIts.
  ///
  /// In en, this message translates to:
  /// **'This image\'s file type and its contents don\'t match. Try another photo.'**
  String get thisImagesFileTypeAndIts;

  /// No description provided for @theSelectedPlaceIsMissingIts.
  ///
  /// In en, this message translates to:
  /// **'The selected place is missing its address or coordinates.'**
  String get theSelectedPlaceIsMissingIts;

  /// No description provided for @placeSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Place search failed ({code}). Please try again.'**
  String placeSearchFailed(Object code);

  /// No description provided for @couldNotReachPlaceSearchCheck.
  ///
  /// In en, this message translates to:
  /// **'Could not reach place search. Check your connection and try again.'**
  String get couldNotReachPlaceSearchCheck;

  /// No description provided for @placeSearchReturnedAnUnexpectedResponse.
  ///
  /// In en, this message translates to:
  /// **'Place search returned an unexpected response.'**
  String get placeSearchReturnedAnUnexpectedResponse;

  /// No description provided for @cannotCreateAnActivityWhileSigned.
  ///
  /// In en, this message translates to:
  /// **'Cannot create an activity while signed out.'**
  String get cannotCreateAnActivityWhileSigned;

  /// No description provided for @cannotDeleteAnActivityWhileSigned.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete an activity while signed out.'**
  String get cannotDeleteAnActivityWhileSigned;

  /// No description provided for @theActivityWasNotFoundOr.
  ///
  /// In en, this message translates to:
  /// **'The activity was not found or cannot be deleted.'**
  String get theActivityWasNotFoundOr;

  /// No description provided for @myLocation.
  ///
  /// In en, this message translates to:
  /// **'My location'**
  String get myLocation;

  /// No description provided for @searchActivitiesOrPlaces.
  ///
  /// In en, this message translates to:
  /// **'Search activities or places'**
  String get searchActivitiesOrPlaces;

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// No description provided for @spotsLeft.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 spot available} other{{n} spots available}}'**
  String spotsLeft(int n);

  /// No description provided for @pleaseEnableLocationServicesToFind.
  ///
  /// In en, this message translates to:
  /// **'Please enable location services to find nearby activities.'**
  String get pleaseEnableLocationServicesToFind;

  /// No description provided for @locationPermissionWasDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission was denied.'**
  String get locationPermissionWasDenied;

  /// No description provided for @locationPermissionIsPermanentlyDeniedPlease.
  ///
  /// In en, this message translates to:
  /// **'Location permission is permanently denied. Please enable it in your device settings.'**
  String get locationPermissionIsPermanentlyDeniedPlease;

  /// No description provided for @unableToRetrieveYourLocationShowing.
  ///
  /// In en, this message translates to:
  /// **'Unable to retrieve your location. Showing Riyadh instead.'**
  String get unableToRetrieveYourLocationShowing;

  /// No description provided for @addAShortBioSoPeople.
  ///
  /// In en, this message translates to:
  /// **'Add a short bio so people get to know you.'**
  String get addAShortBioSoPeople;

  /// No description provided for @unableToSaveBioPleaseTry.
  ///
  /// In en, this message translates to:
  /// **'Unable to save bio. Please try again.'**
  String get unableToSaveBioPleaseTry;

  /// No description provided for @activityType.
  ///
  /// In en, this message translates to:
  /// **'Activity type'**
  String get activityType;

  /// No description provided for @preferredLocation.
  ///
  /// In en, this message translates to:
  /// **'Preferred location'**
  String get preferredLocation;

  /// No description provided for @ageYears.
  ///
  /// In en, this message translates to:
  /// **'{age} yrs'**
  String ageYears(Object age);

  /// No description provided for @friends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friends;

  /// No description provided for @rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rating;

  /// No description provided for @streakWeeksInARow.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{week in a row} other{weeks in a row}}'**
  String streakWeeksInARow(int count);

  /// No description provided for @streakBest.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Best: 1 week} other{Best: {count} weeks}}'**
  String streakBest(int count);

  /// No description provided for @streakDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Last day} other{{count} days left}}'**
  String streakDaysLeft(int count);

  /// No description provided for @streakKeptThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Nice, this week\'s done. See you next week'**
  String get streakKeptThisWeek;

  /// No description provided for @streakKeepGoing.
  ///
  /// In en, this message translates to:
  /// **'One activity this week keeps it going'**
  String get streakKeepGoing;

  /// No description provided for @streakStart.
  ///
  /// In en, this message translates to:
  /// **'Join one activity this week to get it going'**
  String get streakStart;

  /// No description provided for @streakTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly streak'**
  String get streakTitle;

  /// No description provided for @streakThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get streakThisWeek;

  /// No description provided for @streakLastWeek.
  ///
  /// In en, this message translates to:
  /// **'Last week'**
  String get streakLastWeek;

  /// No description provided for @streakEarlierWeek.
  ///
  /// In en, this message translates to:
  /// **'Earlier week'**
  String get streakEarlierWeek;

  /// No description provided for @streakLaterWeek.
  ///
  /// In en, this message translates to:
  /// **'Later week'**
  String get streakLaterWeek;

  /// No description provided for @interests.
  ///
  /// In en, this message translates to:
  /// **'Interests'**
  String get interests;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @addInterestsSoPeopleGetTo.
  ///
  /// In en, this message translates to:
  /// **'Add interests so people get to know what you\'re into.'**
  String get addInterestsSoPeopleGetTo;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @tapToChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Tap to change photo'**
  String get tapToChangePhoto;

  /// No description provided for @profileHeader.
  ///
  /// In en, this message translates to:
  /// **'Header'**
  String get profileHeader;

  /// No description provided for @synkColors.
  ///
  /// In en, this message translates to:
  /// **'Synk colors'**
  String get synkColors;

  /// No description provided for @moreColors.
  ///
  /// In en, this message translates to:
  /// **'More colors'**
  String get moreColors;

  /// No description provided for @headerPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get headerPhoto;

  /// No description provided for @couldntUploadYourHeaderPhoto.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t upload your header photo. Please try again.'**
  String get couldntUploadYourHeaderPhoto;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourName;

  /// No description provided for @bio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bio;

  /// No description provided for @tellPeopleABitAboutYourself.
  ///
  /// In en, this message translates to:
  /// **'Tell people a bit about yourself...'**
  String get tellPeopleABitAboutYourself;

  /// No description provided for @birthdayHint.
  ///
  /// In en, this message translates to:
  /// **'DD/MM/YYYY'**
  String get birthdayHint;

  /// No description provided for @selectBirthday.
  ///
  /// In en, this message translates to:
  /// **'Select birthday'**
  String get selectBirthday;

  /// No description provided for @setBirthday.
  ///
  /// In en, this message translates to:
  /// **'Set birthday'**
  String get setBirthday;

  /// No description provided for @selectYourBirthday.
  ///
  /// In en, this message translates to:
  /// **'Select your birthday'**
  String get selectYourBirthday;

  /// No description provided for @editAge.
  ///
  /// In en, this message translates to:
  /// **'Edit age'**
  String get editAge;

  /// No description provided for @awaitingConfirmationOn.
  ///
  /// In en, this message translates to:
  /// **'{email} isn\'t confirmed yet'**
  String awaitingConfirmationOn(Object email);

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @pleaseEnterYourName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name.'**
  String get pleaseEnterYourName;

  /// No description provided for @adultMustBeBetween16And.
  ///
  /// In en, this message translates to:
  /// **'Adult must be between 16 and 65 years old.'**
  String get adultMustBeBetween16And;

  /// No description provided for @profileEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email.'**
  String get profileEmailRequired;

  /// No description provided for @yourChangesHaveBeenSavedCheck.
  ///
  /// In en, this message translates to:
  /// **'Your changes have been saved. Check your new email to confirm the address change.'**
  String get yourChangesHaveBeenSavedCheck;

  /// No description provided for @unableToSaveYourChangesPlease.
  ///
  /// In en, this message translates to:
  /// **'Unable to save your changes. Please try again.'**
  String get unableToSaveYourChangesPlease;

  /// No description provided for @profileUsernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your username.'**
  String get profileUsernameRequired;

  /// No description provided for @usernameMustBe330Characters.
  ///
  /// In en, this message translates to:
  /// **'Username must be 3–30 characters and can only include letters, numbers, dots, and underscores.'**
  String get usernameMustBe330Characters;

  /// No description provided for @thisUsernameIsAlreadyTaken.
  ///
  /// In en, this message translates to:
  /// **'This username is already taken.'**
  String get thisUsernameIsAlreadyTaken;

  /// No description provided for @usernameCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Username cannot be empty'**
  String get usernameCannotBeEmpty;

  /// No description provided for @profileEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get profileEmailInvalid;

  /// No description provided for @profilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Profile photo'**
  String get profilePhoto;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get addPhoto;

  /// No description provided for @adjustPhoto.
  ///
  /// In en, this message translates to:
  /// **'Adjust photo'**
  String get adjustPhoto;

  /// No description provided for @moveAndScale.
  ///
  /// In en, this message translates to:
  /// **'Move and Scale'**
  String get moveAndScale;

  /// No description provided for @unableToUpdateYourPhotoPlease.
  ///
  /// In en, this message translates to:
  /// **'Unable to update your photo. Please try again.'**
  String get unableToUpdateYourPhotoPlease;

  /// No description provided for @couldntLoadYourPhotoPleaseTry.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your photo. Please try again.'**
  String get couldntLoadYourPhotoPleaseTry;

  /// No description provided for @unableToAdjustYourPhotoPlease.
  ///
  /// In en, this message translates to:
  /// **'Unable to adjust your photo. Please try again.'**
  String get unableToAdjustYourPhotoPlease;

  /// No description provided for @unableToRemoveYourPhotoPlease.
  ///
  /// In en, this message translates to:
  /// **'Unable to remove your photo. Please try again.'**
  String get unableToRemoveYourPhotoPlease;

  /// No description provided for @yourPhotoWasntSavedBecauseYoure.
  ///
  /// In en, this message translates to:
  /// **'Your photo wasn\'t saved because you\'re signed out.'**
  String get yourPhotoWasntSavedBecauseYoure;

  /// No description provided for @savedOnThisDeviceCloudPhoto.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device (cloud photo storage isn\'t set up yet).'**
  String get savedOnThisDeviceCloudPhoto;

  /// No description provided for @editInterests.
  ///
  /// In en, this message translates to:
  /// **'Edit Interests'**
  String get editInterests;

  /// No description provided for @yourInterests.
  ///
  /// In en, this message translates to:
  /// **'Your interests'**
  String get yourInterests;

  /// No description provided for @tapAnInterestBelowToAdd.
  ///
  /// In en, this message translates to:
  /// **'Tap an interest below to add it.'**
  String get tapAnInterestBelowToAdd;

  /// No description provided for @addMore.
  ///
  /// In en, this message translates to:
  /// **'Add more'**
  String get addMore;

  /// No description provided for @youveAddedEveryInterest.
  ///
  /// In en, this message translates to:
  /// **'You\'ve added every interest.'**
  String get youveAddedEveryInterest;

  /// No description provided for @unableToSavePleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Unable to save. Please try again.'**
  String get unableToSavePleaseTryAgain;

  /// No description provided for @changePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePasswordTitle;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @enterYourCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your current password'**
  String get enterYourCurrentPassword;

  /// No description provided for @enterANewPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter a new password'**
  String get enterANewPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmNewPassword;

  /// No description provided for @reEnterTheNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Re-enter the new password'**
  String get reEnterTheNewPassword;

  /// No description provided for @newPasswordMustBeDifferentFrom.
  ///
  /// In en, this message translates to:
  /// **'New password must be different from your current one'**
  String get newPasswordMustBeDifferentFrom;

  /// No description provided for @pleaseConfirmYourNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your new password'**
  String get pleaseConfirmYourNewPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @currentPasswordIsIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Current password is incorrect'**
  String get currentPasswordIsIncorrect;

  /// No description provided for @passwordIsTooWeakPleaseChoose.
  ///
  /// In en, this message translates to:
  /// **'Password is too weak. Please choose a stronger one.'**
  String get passwordIsTooWeakPleaseChoose;

  /// No description provided for @yourSessionHasExpiredPleaseLog.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please log in again.'**
  String get yourSessionHasExpiredPleaseLog;

  /// No description provided for @couldntUpdateYourPasswordPleaseTry.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update your password. Please try again.'**
  String get couldntUpdateYourPasswordPleaseTry;

  /// No description provided for @couldntUpdateYourPasswordCheckYour.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update your password. Check your connection and try again.'**
  String get couldntUpdateYourPasswordCheckYour;

  /// No description provided for @changeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get changeEmail;

  /// No description provided for @confirmYourNewEmail.
  ///
  /// In en, this message translates to:
  /// **'Confirm your new email'**
  String get confirmYourNewEmail;

  /// No description provided for @openTheLinkWeSentTo.
  ///
  /// In en, this message translates to:
  /// **'Open the link we sent to {email}.'**
  String openTheLinkWeSentTo(Object email);

  /// No description provided for @cancelEmailChange.
  ///
  /// In en, this message translates to:
  /// **'Cancel change'**
  String get cancelEmailChange;

  /// No description provided for @useADifferentEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Use a different email'**
  String get useADifferentEmailAddress;

  /// No description provided for @pleaseEnterANewEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Please enter a new email address.'**
  String get pleaseEnterANewEmailAddress;

  /// No description provided for @newEmailMustBeDifferentFrom.
  ///
  /// In en, this message translates to:
  /// **'New email must be different from current email.'**
  String get newEmailMustBeDifferentFrom;

  /// No description provided for @enterNewEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'New email address'**
  String get enterNewEmailAddress;

  /// No description provided for @weWillSendALinkToConfirm.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send a link to confirm it.'**
  String get weWillSendALinkToConfirm;

  /// No description provided for @sendLink.
  ///
  /// In en, this message translates to:
  /// **'Send link'**
  String get sendLink;

  /// No description provided for @linkSentCheckYourNewEmail.
  ///
  /// In en, this message translates to:
  /// **'Link sent. Check your new email.'**
  String get linkSentCheckYourNewEmail;

  /// No description provided for @unableToUpdateEmailPleaseTry.
  ///
  /// In en, this message translates to:
  /// **'Unable to update email. Please try again.'**
  String get unableToUpdateEmailPleaseTry;

  /// No description provided for @linkSentAgain.
  ///
  /// In en, this message translates to:
  /// **'Link sent again.'**
  String get linkSentAgain;

  /// No description provided for @pendingEmailChangeCancelled.
  ///
  /// In en, this message translates to:
  /// **'Email change cancelled.'**
  String get pendingEmailChangeCancelled;

  /// No description provided for @failedToCancelEmailChangeRequest.
  ///
  /// In en, this message translates to:
  /// **'Failed to cancel email change request.'**
  String get failedToCancelEmailChangeRequest;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// No description provided for @logOutOfSynk.
  ///
  /// In en, this message translates to:
  /// **'Log out of Synk?'**
  String get logOutOfSynk;

  /// No description provided for @youllNeedToSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'You\'ll need to sign in again to access your profile, activities, and matches.'**
  String get youllNeedToSignInAgain;

  /// No description provided for @unableToLogOut.
  ///
  /// In en, this message translates to:
  /// **'Unable to log out.'**
  String get unableToLogOut;

  /// No description provided for @unableToLogOutPleaseTry.
  ///
  /// In en, this message translates to:
  /// **'Unable to log out. Please try again.'**
  String get unableToLogOutPleaseTry;

  /// No description provided for @noInternetConnectionCheckYourConnection.
  ///
  /// In en, this message translates to:
  /// **'No internet connection.'**
  String get noInternetConnectionCheckYourConnection;

  /// No description provided for @tooManyAttemptsPleaseWaitA.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a few minutes and try again.'**
  String get tooManyAttemptsPleaseWaitA;

  /// No description provided for @somethingWentWrongPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get somethingWentWrongPleaseTryAgain;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get somethingWentWrong;

  /// No description provided for @unableToTransferHostingPleaseTry.
  ///
  /// In en, this message translates to:
  /// **'Unable to transfer hosting. Please try again.'**
  String get unableToTransferHostingPleaseTry;

  /// No description provided for @unableToLeaveTheActivityPlease.
  ///
  /// In en, this message translates to:
  /// **'Unable to leave the activity. Please try again.'**
  String get unableToLeaveTheActivityPlease;

  /// No description provided for @waitlistPromotions.
  ///
  /// In en, this message translates to:
  /// **'Waitlist promotions'**
  String get waitlistPromotions;

  /// No description provided for @updatesWhenASpotOpensIn.
  ///
  /// In en, this message translates to:
  /// **'Updates when a spot opens in a waitlisted activity.'**
  String get updatesWhenASpotOpensIn;

  /// No description provided for @youreIn.
  ///
  /// In en, this message translates to:
  /// **'You\'re In! 🎉'**
  String get youreIn;

  /// No description provided for @aSpotOpenedUpInYour.
  ///
  /// In en, this message translates to:
  /// **'A spot opened up in your activity.'**
  String get aSpotOpenedUpInYour;

  /// No description provided for @interestOpenToAnything.
  ///
  /// In en, this message translates to:
  /// **'Open to Anything'**
  String get interestOpenToAnything;

  /// No description provided for @interestPadel.
  ///
  /// In en, this message translates to:
  /// **'Padel'**
  String get interestPadel;

  /// No description provided for @interestTennis.
  ///
  /// In en, this message translates to:
  /// **'Tennis'**
  String get interestTennis;

  /// No description provided for @interestBadminton.
  ///
  /// In en, this message translates to:
  /// **'Badminton'**
  String get interestBadminton;

  /// No description provided for @interestTableTennis.
  ///
  /// In en, this message translates to:
  /// **'Table Tennis'**
  String get interestTableTennis;

  /// No description provided for @interestFootball.
  ///
  /// In en, this message translates to:
  /// **'Football'**
  String get interestFootball;

  /// No description provided for @interestBasketball.
  ///
  /// In en, this message translates to:
  /// **'Basketball'**
  String get interestBasketball;

  /// No description provided for @interestVolleyball.
  ///
  /// In en, this message translates to:
  /// **'Volleyball'**
  String get interestVolleyball;

  /// No description provided for @interestGolf.
  ///
  /// In en, this message translates to:
  /// **'Golf'**
  String get interestGolf;

  /// No description provided for @interestBowling.
  ///
  /// In en, this message translates to:
  /// **'Bowling'**
  String get interestBowling;

  /// No description provided for @interestKarting.
  ///
  /// In en, this message translates to:
  /// **'Karting'**
  String get interestKarting;

  /// No description provided for @interestMartialArts.
  ///
  /// In en, this message translates to:
  /// **'Martial Arts'**
  String get interestMartialArts;

  /// No description provided for @interestPaintball.
  ///
  /// In en, this message translates to:
  /// **'Paintball'**
  String get interestPaintball;

  /// No description provided for @interestCycling.
  ///
  /// In en, this message translates to:
  /// **'Cycling'**
  String get interestCycling;

  /// No description provided for @interestRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get interestRunning;

  /// No description provided for @interestHiking.
  ///
  /// In en, this message translates to:
  /// **'Hiking'**
  String get interestHiking;

  /// No description provided for @interestClimbing.
  ///
  /// In en, this message translates to:
  /// **'Climbing'**
  String get interestClimbing;

  /// No description provided for @interestCamping.
  ///
  /// In en, this message translates to:
  /// **'Camping'**
  String get interestCamping;

  /// No description provided for @interestDesertTrips.
  ///
  /// In en, this message translates to:
  /// **'Desert Trips'**
  String get interestDesertTrips;

  /// No description provided for @interestRoadTrips.
  ///
  /// In en, this message translates to:
  /// **'Road Trips'**
  String get interestRoadTrips;

  /// No description provided for @interestBeach.
  ///
  /// In en, this message translates to:
  /// **'Beach'**
  String get interestBeach;

  /// No description provided for @interestPicnic.
  ///
  /// In en, this message translates to:
  /// **'Picnic'**
  String get interestPicnic;

  /// No description provided for @interestPicnics.
  ///
  /// In en, this message translates to:
  /// **'Picnics'**
  String get interestPicnics;

  /// No description provided for @interestTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get interestTravel;

  /// No description provided for @interestFitness.
  ///
  /// In en, this message translates to:
  /// **'Fitness'**
  String get interestFitness;

  /// No description provided for @interestYoga.
  ///
  /// In en, this message translates to:
  /// **'Yoga'**
  String get interestYoga;

  /// No description provided for @interestSwimming.
  ///
  /// In en, this message translates to:
  /// **'Swimming'**
  String get interestSwimming;

  /// No description provided for @interestDiving.
  ///
  /// In en, this message translates to:
  /// **'Diving'**
  String get interestDiving;

  /// No description provided for @interestSkating.
  ///
  /// In en, this message translates to:
  /// **'Skating'**
  String get interestSkating;

  /// No description provided for @interestDance.
  ///
  /// In en, this message translates to:
  /// **'Dance'**
  String get interestDance;

  /// No description provided for @interestCoffee.
  ///
  /// In en, this message translates to:
  /// **'Coffee'**
  String get interestCoffee;

  /// No description provided for @interestCooking.
  ///
  /// In en, this message translates to:
  /// **'Cooking'**
  String get interestCooking;

  /// No description provided for @interestFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get interestFood;

  /// No description provided for @interestShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get interestShopping;

  /// No description provided for @interestBoardGames.
  ///
  /// In en, this message translates to:
  /// **'Board Games'**
  String get interestBoardGames;

  /// No description provided for @interestCardGames.
  ///
  /// In en, this message translates to:
  /// **'Card Games'**
  String get interestCardGames;

  /// No description provided for @interestChess.
  ///
  /// In en, this message translates to:
  /// **'Chess'**
  String get interestChess;

  /// No description provided for @interestEscapeRoom.
  ///
  /// In en, this message translates to:
  /// **'Escape Room'**
  String get interestEscapeRoom;

  /// No description provided for @interestTrivia.
  ///
  /// In en, this message translates to:
  /// **'Trivia'**
  String get interestTrivia;

  /// No description provided for @interestGaming.
  ///
  /// In en, this message translates to:
  /// **'Gaming'**
  String get interestGaming;

  /// No description provided for @interestMovies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get interestMovies;

  /// No description provided for @interestComedy.
  ///
  /// In en, this message translates to:
  /// **'Comedy'**
  String get interestComedy;

  /// No description provided for @interestKaraoke.
  ///
  /// In en, this message translates to:
  /// **'Karaoke'**
  String get interestKaraoke;

  /// No description provided for @interestMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get interestMusic;

  /// No description provided for @interestArt.
  ///
  /// In en, this message translates to:
  /// **'Art'**
  String get interestArt;

  /// No description provided for @interestPottery.
  ///
  /// In en, this message translates to:
  /// **'Pottery'**
  String get interestPottery;

  /// No description provided for @interestMuseums.
  ///
  /// In en, this message translates to:
  /// **'Museums'**
  String get interestMuseums;

  /// No description provided for @interestBooks.
  ///
  /// In en, this message translates to:
  /// **'Books'**
  String get interestBooks;

  /// No description provided for @interestPhotography.
  ///
  /// In en, this message translates to:
  /// **'Photography'**
  String get interestPhotography;

  /// No description provided for @interestLearning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get interestLearning;

  /// No description provided for @interestVolunteering.
  ///
  /// In en, this message translates to:
  /// **'Volunteering'**
  String get interestVolunteering;

  /// No description provided for @interestPets.
  ///
  /// In en, this message translates to:
  /// **'Pets'**
  String get interestPets;

  /// No description provided for @interestOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get interestOther;

  /// No description provided for @weekdayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdaySun;

  /// No description provided for @monthJanuary.
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get monthJanuary;

  /// No description provided for @monthFebruary.
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get monthFebruary;

  /// No description provided for @monthMarch.
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get monthMarch;

  /// No description provided for @monthApril.
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get monthApril;

  /// No description provided for @monthMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthMay;

  /// No description provided for @monthJune.
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get monthJune;

  /// No description provided for @monthJuly.
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get monthJuly;

  /// No description provided for @monthAugust.
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get monthAugust;

  /// No description provided for @monthSeptember.
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get monthSeptember;

  /// No description provided for @monthOctober.
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get monthOctober;

  /// No description provided for @monthNovember.
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get monthNovember;

  /// No description provided for @monthDecember.
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get monthDecember;

  /// No description provided for @timeAm.
  ///
  /// In en, this message translates to:
  /// **'AM'**
  String get timeAm;

  /// No description provided for @timePm.
  ///
  /// In en, this message translates to:
  /// **'PM'**
  String get timePm;

  /// Short month name. Arabic uses the full name.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get monthShortJan;

  /// No description provided for @monthShortFeb.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get monthShortFeb;

  /// No description provided for @monthShortMar.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get monthShortMar;

  /// No description provided for @monthShortApr.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get monthShortApr;

  /// No description provided for @monthShortMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthShortMay;

  /// No description provided for @monthShortJun.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get monthShortJun;

  /// No description provided for @monthShortJul.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get monthShortJul;

  /// No description provided for @monthShortAug.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get monthShortAug;

  /// No description provided for @monthShortSep.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get monthShortSep;

  /// No description provided for @monthShortOct.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get monthShortOct;

  /// No description provided for @monthShortNov.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get monthShortNov;

  /// No description provided for @monthShortDec.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get monthShortDec;

  /// For example Tue, Oct 21
  ///
  /// In en, this message translates to:
  /// **'{weekday}, {month} {day}'**
  String shortDate(Object weekday, Object month, Object day);

  /// For example Oct 21
  ///
  /// In en, this message translates to:
  /// **'{month} {day}'**
  String monthDay(Object month, Object day);

  /// For example 7:30 PM
  ///
  /// In en, this message translates to:
  /// **'{time} {period}'**
  String timeOfDay(Object time, Object period);

  /// Distance filter, for example 10 km
  ///
  /// In en, this message translates to:
  /// **'{n} km'**
  String distanceKm(Object n);

  /// One-letter day heading in the calendar
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get weekdayLetterMon;

  /// No description provided for @weekdayLetterTue.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get weekdayLetterTue;

  /// No description provided for @weekdayLetterWed.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get weekdayLetterWed;

  /// No description provided for @weekdayLetterThu.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get weekdayLetterThu;

  /// No description provided for @weekdayLetterFri.
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get weekdayLetterFri;

  /// No description provided for @weekdayLetterSat.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get weekdayLetterSat;

  /// No description provided for @weekdayLetterSun.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get weekdayLetterSun;

  /// Full date with the year, for example Tue, Oct 21, 2026
  ///
  /// In en, this message translates to:
  /// **'{weekday}, {month} {day}, {year}'**
  String longDate(Object weekday, Object month, Object day, Object year);

  /// First line of the time filter chip (Pick / a time)
  ///
  /// In en, this message translates to:
  /// **'Pick'**
  String get timeChipPick;

  /// Second line of the time filter chip (Pick / a time)
  ///
  /// In en, this message translates to:
  /// **'a time'**
  String get timeChipATime;

  /// First line of the time filter chip once a time is set (From / 7:30 PM)
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get timeChipFrom;

  /// Screen reader label for a day in the day strip
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 plan} other{{n} plans}}'**
  String planCount(int n);

  /// Screen reader label for a day with no plans
  ///
  /// In en, this message translates to:
  /// **'no plans'**
  String get noPlans;

  /// Used in: No Padel plans on Tue, Oct 21
  ///
  /// In en, this message translates to:
  /// **'on {date}'**
  String onDate(Object date);

  /// No description provided for @serverNoActivityWithCode.
  ///
  /// In en, this message translates to:
  /// **'No activity was found with this code.'**
  String get serverNoActivityWithCode;

  /// No description provided for @serverYouAreTheHost.
  ///
  /// In en, this message translates to:
  /// **'You are the host of this activity.'**
  String get serverYouAreTheHost;

  /// No description provided for @serverAlreadyJoined.
  ///
  /// In en, this message translates to:
  /// **'You have already joined this activity.'**
  String get serverAlreadyJoined;

  /// No description provided for @serverRequestWaiting.
  ///
  /// In en, this message translates to:
  /// **'Your request is waiting for host approval.'**
  String get serverRequestWaiting;

  /// No description provided for @serverRequestRejected.
  ///
  /// In en, this message translates to:
  /// **'Your request was rejected by the host.'**
  String get serverRequestRejected;

  /// No description provided for @serverRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Your request was sent to the host.'**
  String get serverRequestSent;

  /// No description provided for @serverFullAddedToWaitlist.
  ///
  /// In en, this message translates to:
  /// **'The activity is full. You were added to the waitlist.'**
  String get serverFullAddedToWaitlist;

  /// No description provided for @serverRequestNotFound.
  ///
  /// In en, this message translates to:
  /// **'The join request was not found.'**
  String get serverRequestNotFound;

  /// No description provided for @serverOnlyHostCanReview.
  ///
  /// In en, this message translates to:
  /// **'Only the activity host can review this request.'**
  String get serverOnlyHostCanReview;

  /// No description provided for @serverPublicNoApproval.
  ///
  /// In en, this message translates to:
  /// **'Public activities do not require host approval.'**
  String get serverPublicNoApproval;

  /// No description provided for @serverAlreadyReviewed.
  ///
  /// In en, this message translates to:
  /// **'This request has already been reviewed.'**
  String get serverAlreadyReviewed;

  /// No description provided for @serverUserHasConflict.
  ///
  /// In en, this message translates to:
  /// **'This person already has another activity at this time, so they can\'t be accepted.'**
  String get serverUserHasConflict;

  /// No description provided for @serverActivityNotFound.
  ///
  /// In en, this message translates to:
  /// **'This activity was not found.'**
  String get serverActivityNotFound;

  /// No description provided for @serverActivityPrivate.
  ///
  /// In en, this message translates to:
  /// **'This activity is private. Ask the host for its code.'**
  String get serverActivityPrivate;

  /// No description provided for @serverHostCannotLeave.
  ///
  /// In en, this message translates to:
  /// **'Hosts cannot leave their own activity.'**
  String get serverHostCannotLeave;

  /// No description provided for @serverActivityStarted.
  ///
  /// In en, this message translates to:
  /// **'This activity has already started.'**
  String get serverActivityStarted;

  /// No description provided for @serverNotParticipating.
  ///
  /// In en, this message translates to:
  /// **'You are no longer part of this activity.'**
  String get serverNotParticipating;

  /// No description provided for @serverOnlyHostCanTransfer.
  ///
  /// In en, this message translates to:
  /// **'Only the host can transfer this activity.'**
  String get serverOnlyHostCanTransfer;

  /// No description provided for @serverChooseAnotherHost.
  ///
  /// In en, this message translates to:
  /// **'Choose another participant to become the host.'**
  String get serverChooseAnotherHost;

  /// No description provided for @serverParticipantLeft.
  ///
  /// In en, this message translates to:
  /// **'The selected participant is no longer in this activity.'**
  String get serverParticipantLeft;

  /// No description provided for @serverLeftAndTransferred.
  ///
  /// In en, this message translates to:
  /// **'You left the activity and transferred hosting.'**
  String get serverLeftAndTransferred;

  /// Title of the Settings page and the gear button on Profile
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Editing an activity failed
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t save your changes. Please try again.'**
  String get weCouldntSaveYourChanges;

  /// Title after editing an activity
  ///
  /// In en, this message translates to:
  /// **'Changes saved!'**
  String get changesSaved;

  /// Banner after editing an activity
  ///
  /// In en, this message translates to:
  /// **'Changes saved'**
  String get changesSavedBanner;

  /// No description provided for @yourActivityDetailsHaveBeenUpdated.
  ///
  /// In en, this message translates to:
  /// **'Your activity details have been updated.'**
  String get yourActivityDetailsHaveBeenUpdated;

  /// No description provided for @editActivity.
  ///
  /// In en, this message translates to:
  /// **'Edit activity'**
  String get editActivity;

  /// No description provided for @replacePhoto.
  ///
  /// In en, this message translates to:
  /// **'Replace Photo'**
  String get replacePhoto;

  /// No description provided for @uploadActivityPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload Activity Photo'**
  String get uploadActivityPhoto;

  /// No description provided for @photoCouldntBeDetached.
  ///
  /// In en, this message translates to:
  /// **'The photo couldn\'t be detached from the activity.'**
  String get photoCouldntBeDetached;

  /// No description provided for @photoDetachedFileNotRemoved.
  ///
  /// In en, this message translates to:
  /// **'The photo was detached, but its stored file couldn\'t be removed.'**
  String get photoDetachedFileNotRemoved;

  /// No description provided for @cannotUpdateActivitySignedOut.
  ///
  /// In en, this message translates to:
  /// **'Cannot update an activity while signed out.'**
  String get cannotUpdateActivitySignedOut;

  /// No description provided for @activityNotFoundOrCannotUpdate.
  ///
  /// In en, this message translates to:
  /// **'The activity was not found or cannot be updated.'**
  String get activityNotFoundOrCannotUpdate;

  /// Notification channel name in Android settings
  ///
  /// In en, this message translates to:
  /// **'Activity updates'**
  String get activityUpdates;

  /// Notification channel description in Android settings
  ///
  /// In en, this message translates to:
  /// **'Updates to activities you have joined.'**
  String get updatesToActivitiesYouHaveJoined;

  /// Notification title when a joined activity changes
  ///
  /// In en, this message translates to:
  /// **'Activity updated'**
  String get activityUpdated;

  /// Notification text when a joined activity changes
  ///
  /// In en, this message translates to:
  /// **'An activity you joined has new details.'**
  String get anActivityYouJoinedHasNew;

  /// No description provided for @findPeople.
  ///
  /// In en, this message translates to:
  /// **'Find people'**
  String get findPeople;

  /// No description provided for @searchFriends.
  ///
  /// In en, this message translates to:
  /// **'Search friends'**
  String get searchFriends;

  /// No description provided for @searchByNameOrUsername.
  ///
  /// In en, this message translates to:
  /// **'Search by name or @username'**
  String get searchByNameOrUsername;

  /// No description provided for @friendRequestsTab.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get friendRequestsTab;

  /// No description provided for @receivedRequests.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get receivedRequests;

  /// No description provided for @friendRequests.
  ///
  /// In en, this message translates to:
  /// **'Friend requests'**
  String get friendRequests;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @notificationsNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get notificationsNew;

  /// No description provided for @notificationsEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get notificationsEarlier;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @notificationDeleted.
  ///
  /// In en, this message translates to:
  /// **'Notification deleted'**
  String get notificationDeleted;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @requestAcceptedLabel.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get requestAcceptedLabel;

  /// No description provided for @requestDeclinedLabel.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get requestDeclinedLabel;

  /// No description provided for @hiName.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}'**
  String hiName(Object name);

  /// No description provided for @forYou.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get forYou;

  /// No description provided for @deckCounter.
  ///
  /// In en, this message translates to:
  /// **'{n} of {total}'**
  String deckCounter(int n, int total);

  /// No description provided for @joinShort.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get joinShort;

  /// No description provided for @youJoinedTitle.
  ///
  /// In en, this message translates to:
  /// **'You joined {title}'**
  String youJoinedTitle(Object title);

  /// No description provided for @spotsLeftShort.
  ///
  /// In en, this message translates to:
  /// **'{n} left'**
  String spotsLeftShort(int n);

  /// No description provided for @seeAgain.
  ///
  /// In en, this message translates to:
  /// **'See again'**
  String get seeAgain;

  /// No description provided for @nextActivity.
  ///
  /// In en, this message translates to:
  /// **'Next activity'**
  String get nextActivity;

  /// No description provided for @previousActivity.
  ///
  /// In en, this message translates to:
  /// **'Previous activity'**
  String get previousActivity;

  /// No description provided for @explore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore;

  /// No description provided for @recentSearches.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recentSearches;

  /// No description provided for @removeRecentSearch.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeRecentSearch;

  /// No description provided for @activitiesForQuery.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 activity for \"{query}\"} other{{n} activities for \"{query}\"}}'**
  String activitiesForQuery(int n, Object query);

  /// No description provided for @bestMatchForYou.
  ///
  /// In en, this message translates to:
  /// **'Best match for you'**
  String get bestMatchForYou;

  /// No description provided for @nothingForQueryYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing for \"{query}\" yet'**
  String nothingForQueryYet(Object query);

  /// No description provided for @createQuery.
  ///
  /// In en, this message translates to:
  /// **'Create \"{query}\"'**
  String createQuery(Object query);

  /// No description provided for @sentRequests.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get sentRequests;

  /// No description provided for @blockedUsers.
  ///
  /// In en, this message translates to:
  /// **'Blocked users'**
  String get blockedUsers;

  /// No description provided for @addFriend.
  ///
  /// In en, this message translates to:
  /// **'Add friend'**
  String get addFriend;

  /// No description provided for @addShort.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addShort;

  /// No description provided for @acceptRequest.
  ///
  /// In en, this message translates to:
  /// **'Accept request'**
  String get acceptRequest;

  /// No description provided for @sentYouAFriendRequest.
  ///
  /// In en, this message translates to:
  /// **'Sent you a friend request'**
  String get sentYouAFriendRequest;

  /// No description provided for @viewProfile.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get viewProfile;

  /// No description provided for @friendOptions.
  ///
  /// In en, this message translates to:
  /// **'Friend options'**
  String get friendOptions;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @removeFriend.
  ///
  /// In en, this message translates to:
  /// **'Remove friend'**
  String get removeFriend;

  /// No description provided for @removeFriendTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String removeFriendTitle(Object name);

  /// No description provided for @removeFriendMessage.
  ///
  /// In en, this message translates to:
  /// **'You can add {name} again later.'**
  String removeFriendMessage(Object name);

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @blockName.
  ///
  /// In en, this message translates to:
  /// **'Block {name}'**
  String blockName(Object name);

  /// No description provided for @blockUserTitle.
  ///
  /// In en, this message translates to:
  /// **'Block {name}?'**
  String blockUserTitle(Object name);

  /// No description provided for @blockUserMessage.
  ///
  /// In en, this message translates to:
  /// **'They can\'t find or add you. They won\'t know.'**
  String get blockUserMessage;

  /// No description provided for @blockHostMessage.
  ///
  /// In en, this message translates to:
  /// **'Blocking this host will remove you from their activity.'**
  String get blockHostMessage;

  /// No description provided for @block.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get block;

  /// No description provided for @unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblock;

  /// No description provided for @reportName.
  ///
  /// In en, this message translates to:
  /// **'Report {name}'**
  String reportName(Object name);

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get reportTitle;

  /// No description provided for @reportWhyName.
  ///
  /// In en, this message translates to:
  /// **'Why are you reporting {name}?'**
  String reportWhyName(Object name);

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @reportUserMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} won\'t know you reported them.'**
  String reportUserMessage(Object name);

  /// No description provided for @reportReasonHarassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment or bullying'**
  String get reportReasonHarassment;

  /// No description provided for @reportReasonSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam'**
  String get reportReasonSpam;

  /// No description provided for @reportReasonFakeProfile.
  ///
  /// In en, this message translates to:
  /// **'Fake profile'**
  String get reportReasonFakeProfile;

  /// No description provided for @reportReasonInappropriateContent.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate content'**
  String get reportReasonInappropriateContent;

  /// No description provided for @reportReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get reportReasonOther;

  /// No description provided for @reportDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'Add anything that would help us review this. This is optional.'**
  String get reportDetailsHint;

  /// No description provided for @reportDetailsRequiredHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us what happened'**
  String get reportDetailsRequiredHint;

  /// No description provided for @reportAndBlockName.
  ///
  /// In en, this message translates to:
  /// **'Send report & block {name}'**
  String reportAndBlockName(Object name);

  /// No description provided for @submitReport.
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get submitReport;

  /// No description provided for @reportSent.
  ///
  /// In en, this message translates to:
  /// **'Report sent'**
  String get reportSent;

  /// No description provided for @reportedAndBlockedName.
  ///
  /// In en, this message translates to:
  /// **'Reported and blocked {name}'**
  String reportedAndBlockedName(Object name);

  /// No description provided for @alreadyReportedName.
  ///
  /// In en, this message translates to:
  /// **'You already reported {name}'**
  String alreadyReportedName(Object name);

  /// No description provided for @reportActivity.
  ///
  /// In en, this message translates to:
  /// **'Report activity'**
  String get reportActivity;

  /// No description provided for @reportActivityWhy.
  ///
  /// In en, this message translates to:
  /// **'Why are you reporting this activity?'**
  String get reportActivityWhy;

  /// No description provided for @reportActivityMessage.
  ///
  /// In en, this message translates to:
  /// **'The host won\'t know you reported it.'**
  String get reportActivityMessage;

  /// No description provided for @reportReasonMisleading.
  ///
  /// In en, this message translates to:
  /// **'Fake or misleading'**
  String get reportReasonMisleading;

  /// No description provided for @alreadyReportedActivity.
  ///
  /// In en, this message translates to:
  /// **'You already reported this activity'**
  String get alreadyReportedActivity;

  /// No description provided for @blockedUsersInfo.
  ///
  /// In en, this message translates to:
  /// **'Blocked users can\'t find you or send you friend requests. They aren\'t told they\'re blocked.'**
  String get blockedUsersInfo;

  /// No description provided for @noBlockedUsers.
  ///
  /// In en, this message translates to:
  /// **'No blocked users'**
  String get noBlockedUsers;

  /// No description provided for @peopleYouBlockShowUpHere.
  ///
  /// In en, this message translates to:
  /// **'People you block will show up here.'**
  String get peopleYouBlockShowUpHere;

  /// No description provided for @noFriendsYet.
  ///
  /// In en, this message translates to:
  /// **'No friends yet'**
  String get noFriendsYet;

  /// No description provided for @findPeopleYouKnow.
  ///
  /// In en, this message translates to:
  /// **'Find people you know and add them as friends.'**
  String get findPeopleYouKnow;

  /// No description provided for @noFriendRequests.
  ///
  /// In en, this message translates to:
  /// **'No friend requests'**
  String get noFriendRequests;

  /// No description provided for @newFriendRequestsShowUpHere.
  ///
  /// In en, this message translates to:
  /// **'New friend requests will show up here.'**
  String get newFriendRequestsShowUpHere;

  /// No description provided for @noFriendsMatchYourSearch.
  ///
  /// In en, this message translates to:
  /// **'No friends match your search'**
  String get noFriendsMatchYourSearch;

  /// No description provided for @noPeopleFound.
  ///
  /// In en, this message translates to:
  /// **'No people found'**
  String get noPeopleFound;

  /// No description provided for @tryAnotherNameOrUsername.
  ///
  /// In en, this message translates to:
  /// **'Try another name or username.'**
  String get tryAnotherNameOrUsername;

  /// No description provided for @searchForPeopleOnSynk.
  ///
  /// In en, this message translates to:
  /// **'Search for people on Synk'**
  String get searchForPeopleOnSynk;

  /// No description provided for @lookForQueryOnSynk.
  ///
  /// In en, this message translates to:
  /// **'Look for \"{query}\" on Synk'**
  String lookForQueryOnSynk(String query);

  /// No description provided for @friendRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Friend request sent'**
  String get friendRequestSent;

  /// No description provided for @friendRequestCancelled.
  ///
  /// In en, this message translates to:
  /// **'Friend request cancelled'**
  String get friendRequestCancelled;

  /// No description provided for @youAreNowFriendsWith.
  ///
  /// In en, this message translates to:
  /// **'You\'re now friends with {name}'**
  String youAreNowFriendsWith(Object name);

  /// No description provided for @friendRequestRejected.
  ///
  /// In en, this message translates to:
  /// **'Friend request rejected'**
  String get friendRequestRejected;

  /// No description provided for @friendRemoved.
  ///
  /// In en, this message translates to:
  /// **'{name} was removed from your friends'**
  String friendRemoved(Object name);

  /// No description provided for @userBlocked.
  ///
  /// In en, this message translates to:
  /// **'{name} was blocked'**
  String userBlocked(Object name);

  /// No description provided for @userUnblocked.
  ///
  /// In en, this message translates to:
  /// **'{name} was unblocked'**
  String userUnblocked(Object name);

  /// No description provided for @friendIsGoing.
  ///
  /// In en, this message translates to:
  /// **'{name} is going'**
  String friendIsGoing(Object name);

  /// No description provided for @twoFriendsAreGoing.
  ///
  /// In en, this message translates to:
  /// **'{first} and {second} are going'**
  String twoFriendsAreGoing(Object first, Object second);

  /// No description provided for @friendAndOthersAreGoing.
  ///
  /// In en, this message translates to:
  /// **'{name} and {n, plural, =1{1 other friend} other{{n} other friends}} are going'**
  String friendAndOthersAreGoing(Object name, int n);

  /// No description provided for @yourFriendsGroup.
  ///
  /// In en, this message translates to:
  /// **'Your friends'**
  String get yourFriendsGroup;

  /// No description provided for @othersGroup.
  ///
  /// In en, this message translates to:
  /// **'Others'**
  String get othersGroup;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @chats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chats;

  /// No description provided for @catchUpWithFriends.
  ///
  /// In en, this message translates to:
  /// **'Catch up with friends!'**
  String get catchUpWithFriends;

  /// No description provided for @activityChats.
  ///
  /// In en, this message translates to:
  /// **'Activity chats'**
  String get activityChats;

  /// No description provided for @searchChats.
  ///
  /// In en, this message translates to:
  /// **'Search chats'**
  String get searchChats;

  /// No description provided for @newChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get newChat;

  /// No description provided for @membersCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 member} other{{n} members}}'**
  String membersCount(int n);

  /// No description provided for @youSaid.
  ///
  /// In en, this message translates to:
  /// **'You: {message}'**
  String youSaid(Object message);

  /// No description provided for @personSaid.
  ///
  /// In en, this message translates to:
  /// **'{name}: {message}'**
  String personSaid(Object name, Object message);

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @noChatsYet.
  ///
  /// In en, this message translates to:
  /// **'No chats yet'**
  String get noChatsYet;

  /// No description provided for @chatsShowUpHere.
  ///
  /// In en, this message translates to:
  /// **'Join an activity or message a friend to start chatting.'**
  String get chatsShowUpHere;

  /// No description provided for @noChatsMatchYourSearch.
  ///
  /// In en, this message translates to:
  /// **'No chats match your search'**
  String get noChatsMatchYourSearch;

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageHint;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @messageNotSent.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send your message'**
  String get messageNotSent;

  /// No description provided for @canOnlyMessageFriends.
  ///
  /// In en, this message translates to:
  /// **'You can only message friends'**
  String get canOnlyMessageFriends;

  /// No description provided for @couldntOpenChat.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open this chat'**
  String get couldntOpenChat;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @messageAFriend.
  ///
  /// In en, this message translates to:
  /// **'Message a friend'**
  String get messageAFriend;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @chatClosed.
  ///
  /// In en, this message translates to:
  /// **'This chat is closed'**
  String get chatClosed;

  /// No description provided for @chatClosedActivityFinished.
  ///
  /// In en, this message translates to:
  /// **'The activity has finished, so its chat was closed.'**
  String get chatClosedActivityFinished;

  /// No description provided for @listSeparator.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get listSeparator;

  /// No description provided for @sayHiToName.
  ///
  /// In en, this message translates to:
  /// **'Say hi to {name}'**
  String sayHiToName(Object name);

  /// No description provided for @youBothLike.
  ///
  /// In en, this message translates to:
  /// **'You both like {interests}!'**
  String youBothLike(Object interests);

  /// No description provided for @listAnd.
  ///
  /// In en, this message translates to:
  /// **'{rest} and {last}'**
  String listAnd(Object rest, Object last);

  /// No description provided for @planActivityTogether.
  ///
  /// In en, this message translates to:
  /// **'Plan {title} together'**
  String planActivityTogether(Object title);

  /// No description provided for @sortOutTheDetails.
  ///
  /// In en, this message translates to:
  /// **'Say hi and sort out the details with everyone going.'**
  String get sortOutTheDetails;

  /// No description provided for @following.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get following;

  /// No description provided for @messageWasDeleted.
  ///
  /// In en, this message translates to:
  /// **'This message was deleted'**
  String get messageWasDeleted;

  /// No description provided for @deleteChat.
  ///
  /// In en, this message translates to:
  /// **'Delete chat'**
  String get deleteChat;

  /// No description provided for @deleteThisChat.
  ///
  /// In en, this message translates to:
  /// **'Delete this chat?'**
  String get deleteThisChat;

  /// No description provided for @chatDeletedOnlyForYou.
  ///
  /// In en, this message translates to:
  /// **'Only for you.'**
  String get chatDeletedOnlyForYou;

  /// No description provided for @chatDeleted.
  ///
  /// In en, this message translates to:
  /// **'Chat deleted'**
  String get chatDeleted;

  /// No description provided for @deleteLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteLabel;

  /// No description provided for @deleteForEveryone.
  ///
  /// In en, this message translates to:
  /// **'Delete for everyone'**
  String get deleteForEveryone;

  /// No description provided for @deleteForMe.
  ///
  /// In en, this message translates to:
  /// **'Delete for me'**
  String get deleteForMe;

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// No description provided for @unmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmute;

  /// No description provided for @muted.
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get muted;

  /// No description provided for @sendSomething.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendSomething;

  /// No description provided for @sendLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get sendLocation;

  /// No description provided for @sendActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get sendActivity;

  /// No description provided for @sendThisLocation.
  ///
  /// In en, this message translates to:
  /// **'Send this location'**
  String get sendThisLocation;

  /// No description provided for @shareAnActivity.
  ///
  /// In en, this message translates to:
  /// **'Share an activity'**
  String get shareAnActivity;

  /// No description provided for @noUpcomingActivitiesToShare.
  ///
  /// In en, this message translates to:
  /// **'No upcoming activities to share'**
  String get noUpcomingActivitiesToShare;

  /// No description provided for @joinOrCreateToShare.
  ///
  /// In en, this message translates to:
  /// **'Join or create an activity, then share it here.'**
  String get joinOrCreateToShare;

  /// No description provided for @activityNotVisibleToAll.
  ///
  /// In en, this message translates to:
  /// **'Some people in this chat can\'t see this activity'**
  String get activityNotVisibleToAll;

  /// No description provided for @sharedActivityLabel.
  ///
  /// In en, this message translates to:
  /// **'Activity: {title}'**
  String sharedActivityLabel(Object title);

  /// No description provided for @sharedLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location: {name}'**
  String sharedLocationLabel(Object name);

  /// No description provided for @shareInChat.
  ///
  /// In en, this message translates to:
  /// **'Share in chat'**
  String get shareInChat;

  /// No description provided for @sentTo.
  ///
  /// In en, this message translates to:
  /// **'Sent to {name}'**
  String sentTo(Object name);

  /// No description provided for @sent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get sent;

  /// No description provided for @rateActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'How was {title}?'**
  String rateActivityTitle(Object title);

  /// No description provided for @rateActivitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Rate the people who joined you. It\'s optional, and they won\'t see who rated them.'**
  String get rateActivitySubtitle;

  /// No description provided for @tapToRate.
  ///
  /// In en, this message translates to:
  /// **'Tap to rate'**
  String get tapToRate;

  /// No description provided for @starsOutOfFive.
  ///
  /// In en, this message translates to:
  /// **'{stars} out of 5 stars'**
  String starsOutOfFive(Object stars);

  /// No description provided for @submitRatings.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submitRatings;

  /// No description provided for @ratingsSavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Thanks for rating!'**
  String get ratingsSavedTitle;

  /// No description provided for @ratingsSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your ratings were saved.'**
  String get ratingsSavedMessage;

  /// No description provided for @ratingNotEnded.
  ///
  /// In en, this message translates to:
  /// **'You can rate once the activity has ended.'**
  String get ratingNotEnded;

  /// No description provided for @ratingNotEligible.
  ///
  /// In en, this message translates to:
  /// **'You can only rate people who joined this activity with you.'**
  String get ratingNotEligible;

  /// No description provided for @ratingAlreadyRated.
  ///
  /// In en, this message translates to:
  /// **'You\'ve already rated this person for this activity.'**
  String get ratingAlreadyRated;

  /// No description provided for @ratingInvalid.
  ///
  /// In en, this message translates to:
  /// **'Choose between 0.5 and 5 stars.'**
  String get ratingInvalid;

  /// No description provided for @ratingActivityUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This activity is no longer available.'**
  String get ratingActivityUnavailable;

  /// No description provided for @recentActivities.
  ///
  /// In en, this message translates to:
  /// **'Recent activities'**
  String get recentActivities;

  /// No description provided for @userActivitiesTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s activities'**
  String userActivitiesTitle(Object name);

  /// No description provided for @noCompletedActivitiesYet.
  ///
  /// In en, this message translates to:
  /// **'No completed activities yet'**
  String get noCompletedActivitiesYet;

  /// No description provided for @couldNotLoadActivities.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load activities.'**
  String get couldNotLoadActivities;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @aboutSynk.
  ///
  /// In en, this message translates to:
  /// **'About Synk'**
  String get aboutSynk;

  /// No description provided for @ourStory.
  ///
  /// In en, this message translates to:
  /// **'Our story'**
  String get ourStory;

  /// No description provided for @ourStoryBody.
  ///
  /// In en, this message translates to:
  /// **'Synk started with a simple belief: the best connections often begin with something small. A shared activity, a common interest, a reason to show up. We built Synk to make that first step easier, so meeting new people and sharing good moments feels natural.'**
  String get ourStoryBody;

  /// No description provided for @ourMission.
  ///
  /// In en, this message translates to:
  /// **'Our mission'**
  String get ourMission;

  /// No description provided for @ourMissionBody.
  ///
  /// In en, this message translates to:
  /// **'Turn any day into a plan. Find something fun, meet your people, and make moments worth talking about.'**
  String get ourMissionBody;

  /// No description provided for @theTeam.
  ///
  /// In en, this message translates to:
  /// **'Meet the team'**
  String get theTeam;

  /// No description provided for @theTeamBody.
  ///
  /// In en, this message translates to:
  /// **'Synk is built by a team of Software Engineering students who share one goal: making social connections easier and more meaningful. Through collaboration, creativity, and a lot of late nights, we brought Synk to life together.'**
  String get theTeamBody;

  /// No description provided for @madeInRiyadh.
  ///
  /// In en, this message translates to:
  /// **'Made in Riyadh'**
  String get madeInRiyadh;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version} ({build})'**
  String appVersion(Object version, Object build);

  /// No description provided for @notifPrefReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get notifPrefReminders;

  /// No description provided for @notifPrefRemindersHint.
  ///
  /// In en, this message translates to:
  /// **'An hour before an activity you joined'**
  String get notifPrefRemindersHint;

  /// No description provided for @notifPrefActivityUpdates.
  ///
  /// In en, this message translates to:
  /// **'Activity updates'**
  String get notifPrefActivityUpdates;

  /// No description provided for @notifPrefActivityUpdatesHint.
  ///
  /// In en, this message translates to:
  /// **'Changes, cancellations and full activities'**
  String get notifPrefActivityUpdatesHint;

  /// No description provided for @notifPrefJoinRequests.
  ///
  /// In en, this message translates to:
  /// **'Join requests'**
  String get notifPrefJoinRequests;

  /// No description provided for @notifPrefJoinRequestsHint.
  ///
  /// In en, this message translates to:
  /// **'New requests and replies to yours'**
  String get notifPrefJoinRequestsHint;

  /// No description provided for @notifPrefWaitlist.
  ///
  /// In en, this message translates to:
  /// **'Waitlist'**
  String get notifPrefWaitlist;

  /// No description provided for @notifPrefWaitlistHint.
  ///
  /// In en, this message translates to:
  /// **'When a spot opens up for you'**
  String get notifPrefWaitlistHint;

  /// No description provided for @notifPrefPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get notifPrefPeople;

  /// No description provided for @notifPrefFriendRequests.
  ///
  /// In en, this message translates to:
  /// **'Friend requests'**
  String get notifPrefFriendRequests;

  /// No description provided for @notifPrefFriendRequestsHint.
  ///
  /// In en, this message translates to:
  /// **'New requests and accepted ones'**
  String get notifPrefFriendRequestsHint;

  /// No description provided for @notifPrefChats.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get notifPrefChats;

  /// No description provided for @notifPrefChatsHint.
  ///
  /// In en, this message translates to:
  /// **'New messages in your chats'**
  String get notifPrefChatsHint;

  /// No description provided for @notifPrefOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get notifPrefOther;

  /// No description provided for @notifPrefMarketing.
  ///
  /// In en, this message translates to:
  /// **'News and tips'**
  String get notifPrefMarketing;

  /// No description provided for @notifPrefMarketingHint.
  ///
  /// In en, this message translates to:
  /// **'New features and things to try'**
  String get notifPrefMarketingHint;

  /// No description provided for @notifPrefIphone.
  ///
  /// In en, this message translates to:
  /// **'iPhone'**
  String get notifPrefIphone;

  /// No description provided for @notifPrefNtfy.
  ///
  /// In en, this message translates to:
  /// **'Send to ntfy'**
  String get notifPrefNtfy;

  /// No description provided for @notifPrefNtfyHint.
  ///
  /// In en, this message translates to:
  /// **'Your Synk notifications go to ntfy'**
  String get notifPrefNtfyHint;

  /// No description provided for @notifPrefNtfyTopic.
  ///
  /// In en, this message translates to:
  /// **'Your topic'**
  String get notifPrefNtfyTopic;

  /// No description provided for @notifPrefNtfyCopied.
  ///
  /// In en, this message translates to:
  /// **'Topic copied'**
  String get notifPrefNtfyCopied;

  /// No description provided for @ntfyPageTitle.
  ///
  /// In en, this message translates to:
  /// **'iPhone notifications'**
  String get ntfyPageTitle;

  /// No description provided for @ntfyStepsTitle.
  ///
  /// In en, this message translates to:
  /// **'How to set it up'**
  String get ntfyStepsTitle;

  /// No description provided for @ntfyStep1.
  ///
  /// In en, this message translates to:
  /// **'Get ntfy from the App Store'**
  String get ntfyStep1;

  /// No description provided for @ntfyStep2.
  ///
  /// In en, this message translates to:
  /// **'Turn on Send to ntfy below'**
  String get ntfyStep2;

  /// No description provided for @ntfyStep3.
  ///
  /// In en, this message translates to:
  /// **'Tap your topic to copy it'**
  String get ntfyStep3;

  /// No description provided for @ntfyStep4.
  ///
  /// In en, this message translates to:
  /// **'In ntfy, tap +, paste the topic and tap Subscribe'**
  String get ntfyStep4;

  /// No description provided for @ntfyGetApp.
  ///
  /// In en, this message translates to:
  /// **'Get ntfy'**
  String get ntfyGetApp;

  /// No description provided for @ntfyGetAppHint.
  ///
  /// In en, this message translates to:
  /// **'Free on the App Store'**
  String get ntfyGetAppHint;

  /// No description provided for @supportIntro.
  ///
  /// In en, this message translates to:
  /// **'Bugs, ideas or a quick hello. A real human reads every one.'**
  String get supportIntro;

  /// No description provided for @supportProblem.
  ///
  /// In en, this message translates to:
  /// **'Bug'**
  String get supportProblem;

  /// No description provided for @supportFeedback.
  ///
  /// In en, this message translates to:
  /// **'Idea'**
  String get supportFeedback;

  /// No description provided for @supportOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get supportOther;

  /// No description provided for @supportReplyTo.
  ///
  /// In en, this message translates to:
  /// **'We\'ll reply to {email}'**
  String supportReplyTo(Object email);

  /// No description provided for @supportSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Message sent!'**
  String get supportSentTitle;

  /// No description provided for @supportSentMessage.
  ///
  /// In en, this message translates to:
  /// **'Keep an eye on your inbox.'**
  String get supportSentMessage;

  /// No description provided for @supportRateLimited.
  ///
  /// In en, this message translates to:
  /// **'That\'s a lot of messages for one day. Try again tomorrow.'**
  String get supportRateLimited;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountIntro.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account removes everything tied to it:'**
  String get deleteAccountIntro;

  /// No description provided for @deleteAccountItemProfile.
  ///
  /// In en, this message translates to:
  /// **'Your profile, photos and interests'**
  String get deleteAccountItemProfile;

  /// No description provided for @deleteAccountItemActivities.
  ///
  /// In en, this message translates to:
  /// **'Activities you host and your spots in others'**
  String get deleteAccountItemActivities;

  /// No description provided for @deleteAccountItemChats.
  ///
  /// In en, this message translates to:
  /// **'Your chats and messages'**
  String get deleteAccountItemChats;

  /// No description provided for @deleteAccountItemFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends, ratings and blocks'**
  String get deleteAccountItemFriends;

  /// No description provided for @deleteAccountCantUndo.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone.'**
  String get deleteAccountCantUndo;

  /// No description provided for @enterPasswordToContinue.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to continue'**
  String get enterPasswordToContinue;

  /// No description provided for @deleteAccountConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountConfirmTitle;

  /// No description provided for @deleteAccountConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Everything will be removed for good.'**
  String get deleteAccountConfirmMessage;

  /// No description provided for @keepAccount.
  ///
  /// In en, this message translates to:
  /// **'Keep my account'**
  String get keepAccount;

  /// No description provided for @couldNotDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t delete your account. Please try again.'**
  String get couldNotDeleteAccount;

  /// No description provided for @weather.
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get weather;

  /// No description provided for @loadingForecast.
  ///
  /// In en, this message translates to:
  /// **'Loading forecast…'**
  String get loadingForecast;

  /// No description provided for @forecastTooFarAhead.
  ///
  /// In en, this message translates to:
  /// **'The forecast shows up about 2 weeks before'**
  String get forecastTooFarAhead;

  /// No description provided for @weatherUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Weather isn\'t available right now'**
  String get weatherUnavailable;

  /// No description provided for @rainChance.
  ///
  /// In en, this message translates to:
  /// **'{percent}% rain'**
  String rainChance(int percent);

  /// No description provided for @windSpeed.
  ///
  /// In en, this message translates to:
  /// **'{speed} km/h wind'**
  String windSpeed(int speed);

  /// No description provided for @weatherFog.
  ///
  /// In en, this message translates to:
  /// **'Foggy'**
  String get weatherFog;

  /// No description provided for @weatherDrizzle.
  ///
  /// In en, this message translates to:
  /// **'Drizzle'**
  String get weatherDrizzle;

  /// No description provided for @weatherRain.
  ///
  /// In en, this message translates to:
  /// **'Rain'**
  String get weatherRain;

  /// No description provided for @weatherSnow.
  ///
  /// In en, this message translates to:
  /// **'Snow'**
  String get weatherSnow;

  /// No description provided for @weatherStorm.
  ///
  /// In en, this message translates to:
  /// **'Thunderstorm'**
  String get weatherStorm;

  /// No description provided for @notificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get notificationSettings;

  /// No description provided for @notifActivityReminder.
  ///
  /// In en, this message translates to:
  /// **'{title} starts in an hour.'**
  String notifActivityReminder(Object title);

  /// No description provided for @supportTitle.
  ///
  /// In en, this message translates to:
  /// **'We\'re all ears'**
  String get supportTitle;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @messageCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get messageCopied;

  /// No description provided for @replyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to {name}'**
  String replyingTo(Object name);

  /// No description provided for @originalMessageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Original message'**
  String get originalMessageUnavailable;

  /// No description provided for @seen.
  ///
  /// In en, this message translates to:
  /// **'Seen'**
  String get seen;

  /// No description provided for @seenByEveryone.
  ///
  /// In en, this message translates to:
  /// **'Seen by everyone'**
  String get seenByEveryone;

  /// No description provided for @seenByCount.
  ///
  /// In en, this message translates to:
  /// **'Seen by {count}'**
  String seenByCount(int count);

  /// No description provided for @friendsOfName.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s friends'**
  String friendsOfName(Object name);

  /// No description provided for @reviewsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 review} other{{count} reviews}}'**
  String reviewsCount(int count);

  /// No description provided for @couldntFindYourThing.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t find your thing?'**
  String get couldntFindYourThing;

  /// No description provided for @rateActivityFun.
  ///
  /// In en, this message translates to:
  /// **'Give your crew some stars'**
  String get rateActivityFun;

  /// No description provided for @ratingsSentToast.
  ///
  /// In en, this message translates to:
  /// **'Thanks! Ratings sent'**
  String get ratingsSentToast;

  /// No description provided for @ntfyIphoneOnly.
  ///
  /// In en, this message translates to:
  /// **'Only for iPhone users'**
  String get ntfyIphoneOnly;

  /// No description provided for @supportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We read every message.'**
  String get supportSubtitle;

  /// No description provided for @supportBugHint.
  ///
  /// In en, this message translates to:
  /// **'What went wrong?'**
  String get supportBugHint;

  /// No description provided for @supportIdeaHint.
  ///
  /// In en, this message translates to:
  /// **'What would you like to see?'**
  String get supportIdeaHint;

  /// No description provided for @supportOtherHint.
  ///
  /// In en, this message translates to:
  /// **'Say anything, big or small.'**
  String get supportOtherHint;

  /// No description provided for @supportAddScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Add screenshot (optional)'**
  String get supportAddScreenshot;

  /// No description provided for @supportChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get supportChange;

  /// No description provided for @supportChangeEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Where should we reply?'**
  String get supportChangeEmailTitle;

  /// No description provided for @supportInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get supportInvalidEmail;

  /// No description provided for @supportThanksTitle.
  ///
  /// In en, this message translates to:
  /// **'Thanks! We got it.'**
  String get supportThanksTitle;

  /// No description provided for @supportThanksMessage.
  ///
  /// In en, this message translates to:
  /// **'We\'ll get back to you by email.'**
  String get supportThanksMessage;

  /// No description provided for @backToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get backToHome;

  /// No description provided for @shareLink.
  ///
  /// In en, this message translates to:
  /// **'Share link'**
  String get shareLink;

  /// No description provided for @shareLinkMessage.
  ///
  /// In en, this message translates to:
  /// **'Want to join us for {title}?\n📅 {date}\n\n{link}'**
  String shareLinkMessage(Object title, Object date, Object link);

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeek;

  /// No description provided for @shareLinkCodeMessage.
  ///
  /// In en, this message translates to:
  /// **'Want to join us for {title}?\n📅 {date}\n\n{link}\n\nOr enter the code in Synk: {code}'**
  String shareLinkCodeMessage(
    Object title,
    Object date,
    Object link,
    Object code,
  );

  /// No description provided for @friendsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 friend} other{{count} friends}}'**
  String friendsCount(int count);

  /// No description provided for @blockedTag.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get blockedTag;

  /// No description provided for @thisActivityIsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This activity is unavailable.'**
  String get thisActivityIsUnavailable;

  /// No description provided for @thisProfileIsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This profile is unavailable.'**
  String get thisProfileIsUnavailable;

  /// No description provided for @rateMembers.
  ///
  /// In en, this message translates to:
  /// **'Rate members'**
  String get rateMembers;

  /// No description provided for @openChat.
  ///
  /// In en, this message translates to:
  /// **'Open chat'**
  String get openChat;

  /// No description provided for @weatherClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get weatherClear;

  /// No description provided for @weatherPartlyCloudy.
  ///
  /// In en, this message translates to:
  /// **'Partly cloudy'**
  String get weatherPartlyCloudy;

  /// No description provided for @weatherCloudy.
  ///
  /// In en, this message translates to:
  /// **'Cloudy'**
  String get weatherCloudy;

  /// No description provided for @feelsLike.
  ///
  /// In en, this message translates to:
  /// **'Feels like'**
  String get feelsLike;

  /// No description provided for @chanceOfRain.
  ///
  /// In en, this message translates to:
  /// **'Chance of rain'**
  String get chanceOfRain;

  /// No description provided for @wind.
  ///
  /// In en, this message translates to:
  /// **'Wind'**
  String get wind;

  /// No description provided for @humidity.
  ///
  /// In en, this message translates to:
  /// **'Humidity'**
  String get humidity;

  /// No description provided for @kmPerHour.
  ///
  /// In en, this message translates to:
  /// **'{speed} km/h'**
  String kmPerHour(int speed);

  /// No description provided for @weatherTipStorm.
  ///
  /// In en, this message translates to:
  /// **'Stormy out there. Stay safe and dress for it.'**
  String get weatherTipStorm;

  /// No description provided for @weatherTipRain.
  ///
  /// In en, this message translates to:
  /// **'Rain\'s on the way. Bring an umbrella!'**
  String get weatherTipRain;

  /// No description provided for @weatherTipHot.
  ///
  /// In en, this message translates to:
  /// **'Very hot. Drink water and stay in the shade.'**
  String get weatherTipHot;

  /// No description provided for @weatherTipWarm.
  ///
  /// In en, this message translates to:
  /// **'Warm out. Wear something light.'**
  String get weatherTipWarm;

  /// No description provided for @weatherTipNice.
  ///
  /// In en, this message translates to:
  /// **'Perfect weather. Enjoy it!'**
  String get weatherTipNice;

  /// No description provided for @weatherTipCool.
  ///
  /// In en, this message translates to:
  /// **'A little chilly. Bring a light jacket.'**
  String get weatherTipCool;

  /// No description provided for @weatherTipCold.
  ///
  /// In en, this message translates to:
  /// **'Cold out. Dress warm and cozy.'**
  String get weatherTipCold;

  /// No description provided for @yourRatings.
  ///
  /// In en, this message translates to:
  /// **'Your ratings'**
  String get yourRatings;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @withdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get withdraw;

  /// No description provided for @withdrawRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Withdraw your request?'**
  String get withdrawRequestTitle;
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
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
