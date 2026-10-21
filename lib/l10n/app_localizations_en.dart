// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get shareCode => 'Share code';

  @override
  String get share => 'Share';

  @override
  String shareMessage(Object title, Object date, Object place, Object code) {
    return 'Want to join us for $title?\n📅 $date\n📍 $place\n\nEnter the code in Synk: $code';
  }

  @override
  String get couldntOpenTheShareMenu => 'Couldn\'t open the share menu.';

  @override
  String get language => 'Language';

  @override
  String get appLanguage => 'App language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'العربية';

  @override
  String get save => 'Save';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get cancel => 'Cancel';

  @override
  String get done => 'Done';

  @override
  String get doneTitle => 'Done!';

  @override
  String get continueButton => 'Continue';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Retry';

  @override
  String get tryAgain => 'Try again';

  @override
  String get refresh => 'Refresh';

  @override
  String get reset => 'Reset';

  @override
  String get skip => 'Skip';

  @override
  String get gotIt => 'Got it';

  @override
  String get choose => 'Choose';

  @override
  String get optional => 'Optional';

  @override
  String get notSet => 'Not set';

  @override
  String get you => 'You';

  @override
  String get saved => 'Saved';

  @override
  String get yourChangesHaveBeenSaved => 'Your changes have been saved.';

  @override
  String get discardChanges => 'Discard changes?';

  @override
  String get unsavedChangesWillBeLost => 'Unsaved changes will be lost';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get discardAndLeave => 'Discard and leave';

  @override
  String get synkMember => 'Synk member';

  @override
  String get synkUser => 'Synk user';

  @override
  String get communityMember => 'Community Member';

  @override
  String get anonymous => 'Anonymous';

  @override
  String get untitledActivity => 'Untitled activity';

  @override
  String get home => 'Home';

  @override
  String get map => 'Map';

  @override
  String get activities => 'Activities';

  @override
  String get profile => 'Profile';

  @override
  String get create => 'Create';

  @override
  String get findYourMissingPiece => 'Find your\nmissing piece.';

  @override
  String get readyToSynk => 'Ready to Synk?';

  @override
  String get joinThousandsAlreadyDoingWhatThey =>
      'Join thousands already doing what they love, together!';

  @override
  String get welcomeBack => 'Welcome Back';

  @override
  String get logInToConnectAndJoin =>
      'Log in to connect and join activities around you.';

  @override
  String get username => 'Username';

  @override
  String get email => 'Email';

  @override
  String get emailAddress => 'Email address';

  @override
  String get password => 'Password';

  @override
  String get pleaseEnterYourUsername => 'Please enter your username';

  @override
  String get pleaseEnterAValidEmail => 'Please enter a valid email';

  @override
  String get pleaseEnterYourPassword => 'Please enter your password';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get logIn => 'Log In';

  @override
  String get dontHaveAnAccount => 'Don\'t have an account?';

  @override
  String get signUp => 'Sign Up';

  @override
  String get unableToLogIn => 'Unable to log in.';

  @override
  String get unableToLogInPleaseTry => 'Unable to log in. Please try again.';

  @override
  String get noAccountFoundWithThisUsername =>
      'No account found with this username';

  @override
  String get pleaseVerifyYourEmailFirst => 'Please verify your email first.';

  @override
  String get incorrectUsernameOrPassword => 'Incorrect username or password';

  @override
  String get incorrectEmailOrPassword => 'Incorrect email or password';

  @override
  String get tellUsAboutYourself => 'Tell us about\nyourself.';

  @override
  String get thisHelpsCustomizeYourCommunityExperience =>
      'This helps customize your community experience.';

  @override
  String get fullName => 'Full name';

  @override
  String get birthday => 'Birthday';

  @override
  String get gender => 'Gender';

  @override
  String get female => 'Female';

  @override
  String get male => 'Male';

  @override
  String get createYourAccount => 'Create your\naccount.';

  @override
  String get completeRegistration => 'Complete Registration';

  @override
  String get eightPlusCharacters => '8+ characters';

  @override
  String get uppercaseLetter => 'Uppercase letter';

  @override
  String get lowercaseLetter => 'Lowercase letter';

  @override
  String get aNumber => 'A number';

  @override
  String get specialCharacter => 'Special character';

  @override
  String get fullNameIsRequired => 'Full name is required';

  @override
  String get nameCanBeAtMost50 => 'Name can be at most 50 characters';

  @override
  String get nameCanOnlyContainLettersAnd =>
      'Name can only contain letters and spaces';

  @override
  String get birthdayIsRequired => 'Birthday is required';

  @override
  String get pleaseEnterAValidBirthday => 'Please enter a valid birthday';

  @override
  String get ageMustBeBetween16And => 'Age must be between 16 and 65 years';

  @override
  String get emailAddressIsRequired => 'Email address is required';

  @override
  String get anAccountWithThisEmailAlready =>
      'An account with this email already exists';

  @override
  String get pleaseSelectYourGender => 'Please select your gender';

  @override
  String passwordTooWeakMix(Object n) {
    return 'Password is too weak. Please use at least $n characters with a mix of letters, numbers, and symbols.';
  }

  @override
  String get weCouldntCreateYourAccountPlease =>
      'We couldn\'t create your account. Please try again.';

  @override
  String get passwordIsRequired => 'Password is required';

  @override
  String get passwordMustBeAtLeast8 => 'Password must be at least 8 characters';

  @override
  String get passwordNeedsUppercase =>
      'Password must contain at least 1 uppercase letter';

  @override
  String get passwordNeedsLowercase =>
      'Password must contain at least 1 lowercase letter';

  @override
  String get passwordNeedsNumber => 'Password must contain at least 1 number';

  @override
  String get passwordNeedsSpecial =>
      'Password must contain at least 1 special character (e.g., @\$!%*?&)';

  @override
  String get usernameIsRequired => 'Username is required';

  @override
  String get usernameMustBeAtLeast3 => 'Username must be at least 3 characters';

  @override
  String get usernameCanBeAtMost30 => 'Username can be at most 30 characters';

  @override
  String get usernameCanOnlyContainLettersNumbers =>
      'Username can only contain letters, numbers, underscores, and dots';

  @override
  String get whatAreYouInto => 'What are you into?';

  @override
  String get pickTheActivitiesYouEnjoy => 'Pick the activities you enjoy.';

  @override
  String get whereDoYouLikeToHave => 'Where do you like to have fun?';

  @override
  String get tellUsWhatKindOfActivities =>
      'Tell us what kind of activities you prefer.';

  @override
  String get howFarAreYouWillingTo => 'How far are you willing to go?';

  @override
  String get chooseHowCloseYouWantYour =>
      'Choose how close you want your activities to be.';

  @override
  String get indoor => 'Indoor';

  @override
  String get outdoor => 'Outdoor';

  @override
  String get iDontMind => 'I don\'t mind';

  @override
  String get inTheCity => 'In the city';

  @override
  String get awayFromTheCity => 'Away from the city';

  @override
  String get checkYourInbox => 'Check your inbox';

  @override
  String get weSentAConfirmationLinkTo => 'We sent a confirmation link to:';

  @override
  String resendInSeconds(Object s) {
    return 'Resend in ${s}s';
  }

  @override
  String get resendVerificationEmail => 'Resend verification email';

  @override
  String get iveConfirmedMyEmail => 'I\'ve confirmed my email';

  @override
  String get backToSignIn => 'Back to Sign In';

  @override
  String get notConfirmedYetTapTheLink =>
      'Not confirmed yet. Tap the link in the email first.';

  @override
  String get alreadyConfirmedGoBackAndSign =>
      'Already confirmed? Go back and sign in.';

  @override
  String get couldNotCheckRightNowPlease =>
      'Could not check right now. Please try again.';

  @override
  String get verificationEmailResentPleaseCheckYour =>
      'Verification email resent! Please check your inbox.';

  @override
  String get failedToResendConfirmationEmail =>
      'Failed to resend confirmation email.';

  @override
  String get anUnexpectedErrorOccurredPleaseTry =>
      'An unexpected error occurred. Please try again.';

  @override
  String get forgotYourPassword => 'Forgot your password?';

  @override
  String get itHappensEnterYourEmailAnd =>
      'It happens. Enter your email and we\'ll send you a link to get back in.';

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get backToLogIn => 'Back to Log In';

  @override
  String get forYourSecurityWellSendA =>
      'We only send a link if this email has a Synk account.';

  @override
  String get weSentAResetLinkTo => 'We sent a reset link to';

  @override
  String get theLinkCanOnlyBeUsed => 'The link can only be used once';

  @override
  String get openItOnThisDeviceSo =>
      'Open it on this device so Synk can sign you in';

  @override
  String get notThereCheckYourSpamFolder => 'Not there? Check your spam folder';

  @override
  String get resendLink => 'Resend link';

  @override
  String resendLinkCountdown(Object ss) {
    return 'Resend link in 0:$ss';
  }

  @override
  String get wrongEmailEditIt => 'Wrong email? Edit it';

  @override
  String get unableToSendTheLink => 'Unable to send the link.';

  @override
  String get aNewLinkIsOnIts => 'A new link is on its way.';

  @override
  String get pleaseEnterYourEmail => 'Please enter your email';

  @override
  String get pleaseEnterAValidEmailAddress =>
      'Please enter a valid email address';

  @override
  String get pleaseConfirmYourPassword => 'Please confirm your password';

  @override
  String get couldntSendTheLinkCheckYour =>
      'Couldn\'t send the link. Check your connection and try again.';

  @override
  String get pleaseWaitAMomentBeforeRequesting =>
      'Please wait a moment before requesting another link.';

  @override
  String passwordTooWeakMinLength(Object n) {
    return 'Password is too weak. Please use at least $n characters.';
  }

  @override
  String get thatsYourCurrentPasswordPickA =>
      'That\'s your current password. Pick a new one.';

  @override
  String get thisLinkIsNoLongerValid =>
      'This link is no longer valid. Please request a new one.';

  @override
  String get createANewPassword => 'Create a new password';

  @override
  String get newPassword => 'New password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get reTypePassword => 'Re-type password';

  @override
  String get updatePassword => 'Update password';

  @override
  String get unableToUpdateYourPassword => 'Unable to update your password.';

  @override
  String get passwordNotChanged => 'Password not changed.';

  @override
  String get thisLinkHasExpired => 'This link has expired';

  @override
  String get resetLinksCanOnlyBeUsed =>
      'Reset links can only be used once and expire after a short time. Request a fresh one and we\'ll get you back in.';

  @override
  String get requestANewLink => 'Request a new link';

  @override
  String get youreBackIn => 'You\'re back in.';

  @override
  String get yourNewPasswordIsSetLog =>
      'Your new password is set. Log in to pick up where you left off.';

  @override
  String get thisLinkHasExpiredOrWas =>
      'This link has expired or was already used. Please request a new one.';

  @override
  String get confirmedNowOpenTheLinkSent =>
      'Confirmed. Now open the link sent to your other email address.';

  @override
  String get yourEmailAddressWasUpdated => 'Your email address was updated.';

  @override
  String welcomeName(Object name) {
    return 'Welcome, $name';
  }

  @override
  String get welcomeToSynk => 'Welcome to Synk';

  @override
  String heyName(Object name) {
    return 'Hey $name';
  }

  @override
  String get heyThere => 'Hey there';

  @override
  String get letsFindYourPeople => 'Let\'s find your people';

  @override
  String get readyForSomethingNew => 'Ready for something new?';

  @override
  String get readyForSomethingNewFemale => 'Ready for something new?';

  @override
  String get searchActivitiesOrLocations => 'Search activities or locations...';

  @override
  String get upcomingPlans => 'Upcoming plans';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String noPlansMatchQuery(Object q) {
    return 'No plans match \"$q\"';
  }

  @override
  String get noPlansMatchYourFilters => 'No plans match your filters';

  @override
  String noCategoryPlans(Object category, Object when) {
    return 'No $category plans $when';
  }

  @override
  String get weCouldntReachSynk => 'We couldn\'t reach Synk';

  @override
  String get itsQuietHereForNow => 'It\'s quiet here for now';

  @override
  String get checkYourConnectionAndTryAgain =>
      'Check your connection and try again.';

  @override
  String get newPlansPopUpAllThe =>
      'New plans pop up all the time. Tap + to start one.';

  @override
  String get createOne => 'Create one';

  @override
  String get haveACode => 'Have a code?';

  @override
  String get haveAnActivityCodeJoinWith =>
      'Have an activity code? Join with it';

  @override
  String get unableToLoadActivitiesPullDown =>
      'Unable to load activities. Pull down to refresh.';

  @override
  String get filters => 'Filters';

  @override
  String filtersActive(Object n) {
    return 'Filters, $n active';
  }

  @override
  String get sortBy => 'Sort by';

  @override
  String get soonest => 'Soonest';

  @override
  String get latest => 'Latest';

  @override
  String get nearest => 'Nearest';

  @override
  String get farthest => 'Farthest';

  @override
  String get almostFull => 'Almost full';

  @override
  String get mostSpots => 'Most spots';

  @override
  String get any => 'Any';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get morning => 'Morning';

  @override
  String get evening => 'Evening';

  @override
  String get night => 'Night';

  @override
  String get slotMorningHours => '6 AM–12 PM';

  @override
  String get slotEveningHours => '12–9 PM';

  @override
  String get slotNightHours => '9 PM–12 AM';

  @override
  String get within => 'Within';

  @override
  String get fiveKm => '5 km';

  @override
  String get locating => 'Locating…';

  @override
  String get allowLocation => 'Allow location';

  @override
  String get startingFrom => 'Starting from';

  @override
  String fromTime(Object time) {
    return 'From $time';
  }

  @override
  String get pickATime => 'Pick a time';

  @override
  String get category => 'Category';

  @override
  String get spots => 'Spots';

  @override
  String get oneLeft => '1 left';

  @override
  String get hasSpots => 'Has spots';

  @override
  String get full => 'Full';

  @override
  String get noMatchesTryFewerFilters => 'No matches, try fewer filters';

  @override
  String get showOneActivity => 'Show 1 activity';

  @override
  String showActivities(Object n) {
    return 'Show $n activities';
  }

  @override
  String todayAtTime(Object time) {
    return 'Today, $time';
  }

  @override
  String tomorrowAtTime(Object time) {
    return 'Tomorrow, $time';
  }

  @override
  String get available => 'Available';

  @override
  String get oneMoreNeeded => 'One More Needed';

  @override
  String joinedOfMaxGoing(Object joined, Object max) {
    return '$joined/$max going';
  }

  @override
  String get waitlisted => 'Waitlisted';

  @override
  String get code => 'Code';

  @override
  String get dateAndTime => 'Date & Time';

  @override
  String get viewOnMap => 'View on map';

  @override
  String get openInGoogleMaps => 'Open in Google Maps';

  @override
  String get couldntOpenGoogleMaps => 'Couldn\'t open Google Maps.';

  @override
  String get aboutThisActivity => 'About This Activity';

  @override
  String get participants => 'Participants';

  @override
  String joinedOfMaxSpots(Object joined, Object max) {
    return '$joined / $max spots';
  }

  @override
  String get youllSeeWhosGoingOnceThe =>
      'You\'ll see who\'s going once the host accepts you.';

  @override
  String get host => 'Host';

  @override
  String get activityCode => 'Activity code';

  @override
  String get copyCode => 'Copy code';

  @override
  String get activityCodeCopied => 'Activity code copied';

  @override
  String get deleteActivity => 'Delete activity';

  @override
  String get youreOnTheWaitlist => 'You\'re on the waitlist';

  @override
  String get waitingForHostApproval => 'Waiting for host approval';

  @override
  String get youveJoinedThisActivity => 'You\'ve joined this activity';

  @override
  String get joinWaitlist => 'Join waitlist';

  @override
  String get joinActivity => 'Join activity';

  @override
  String get leaveActivity => 'Leave Activity';

  @override
  String get leaveActivityTitle => 'Leave activity?';

  @override
  String get confirmLeaveActivity =>
      'Are you sure you want to leave this activity?';

  @override
  String get stay => 'Stay';

  @override
  String get youLeftTheActivity => 'You Left the Activity';

  @override
  String get youHaveSuccessfullyLeftThisActivity =>
      'You have successfully left this activity.';

  @override
  String get leaveWaitlistTitle => 'Leave waitlist?';

  @override
  String get confirmLeaveWaitlist =>
      'Are you sure you want to leave the waitlist for this activity?';

  @override
  String get stayOnWaitlist => 'Stay on Waitlist';

  @override
  String get leaveWaitlist => 'Leave Waitlist';

  @override
  String get youLeftTheWaitlist => 'You Left the Waitlist';

  @override
  String get youHaveBeenRemovedFromThe =>
      'You have been removed from the waitlist.';

  @override
  String get cancelRequestTitle => 'Cancel request?';

  @override
  String get confirmCancelRequest =>
      'Are you sure you want to cancel your request to join this activity?';

  @override
  String get keepRequest => 'Keep Request';

  @override
  String get cancelRequest => 'Cancel Request';

  @override
  String get requestCancelled => 'Request Cancelled';

  @override
  String get yourJoinRequestHasBeenCancelled =>
      'Your join request has been cancelled.';

  @override
  String get youAreNowTheHostOf => 'You are now the host of this activity.';

  @override
  String get transferHostingAndLeave => 'Transfer hosting and leave?';

  @override
  String transferHostMessage(Object name) {
    return '$name will become the host of this activity. You will no longer be able to manage it.';
  }

  @override
  String get transferAndLeave => 'Transfer & Leave';

  @override
  String newHostIs(Object name) {
    return '$name is now the host.';
  }

  @override
  String get chooseANewHost => 'Choose a new host';

  @override
  String get thePersonYouChooseGetsFull =>
      'The person you choose gets full host permissions, including managing join requests and deleting the activity. You will leave the activity.';

  @override
  String get unableToLoadParticipantsPleaseTry =>
      'Unable to load participants. Please try again.';

  @override
  String get noOneCanTakeOverYet =>
      'No one can take over yet. Only joined participants can become the host. You can delete the activity instead.';

  @override
  String get thisActivityIsNoLongerAvailable =>
      'This activity is no longer available.';

  @override
  String get unableToOpenThisActivity => 'Unable to open this activity.';

  @override
  String get all => 'All';

  @override
  String get hosting => 'Hosting';

  @override
  String get joined => 'Joined';

  @override
  String get requested => 'Requested';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get past => 'Past';

  @override
  String get noPastActivities => 'No past activities';

  @override
  String get activitiesYouveBeenPartOfWill =>
      'Activities you\'ve been part of will show up here.';

  @override
  String get noUpcomingActivities => 'No upcoming activities';

  @override
  String get joinOneFromHomeOrTap =>
      'Join one from Home, or tap + to plan your own.';

  @override
  String get joinRequests => 'Join Requests';

  @override
  String get deleteActivityTitle => 'Delete activity?';

  @override
  String get thisActionCannotBeUndoneThe =>
      'This action cannot be undone. The activity will be removed for everyone.';

  @override
  String get keepActivity => 'Keep Activity';

  @override
  String get deleteActivityButton => 'Delete Activity';

  @override
  String get activityDeleted => 'Activity Deleted';

  @override
  String get theActivityHasBeenDeletedSuccessfully =>
      'The activity has been deleted successfully.';

  @override
  String get unableToDeleteTheActivityPlease =>
      'Unable to delete the activity. Please try again.';

  @override
  String get joinWithACode => 'Join with a code';

  @override
  String get enterThe6DigitActivityCode => 'Enter the 6-digit activity code.';

  @override
  String get joinActivityButton => 'Join Activity';

  @override
  String get enterAValid6DigitActivity =>
      'Enter a valid 6-digit activity code.';

  @override
  String get unableToJoinTheActivityPlease =>
      'Unable to join the activity. Please try again.';

  @override
  String get unableToJoin => 'Unable to Join';

  @override
  String get thisActivityConflictsWithOneYouve =>
      'This activity conflicts with one you\'ve already joined or created.';

  @override
  String get joinedTitle => 'Joined!';

  @override
  String get alreadyJoined => 'Already Joined';

  @override
  String get requestSent => 'Request Sent!';

  @override
  String get requestAlreadySent => 'Request Already Sent';

  @override
  String get addedToWaitlist => 'Added to Waitlist!';

  @override
  String get alreadyWaitlisted => 'Already Waitlisted';

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(Object n) {
    return '${n}m ago';
  }

  @override
  String hoursAgo(Object n) {
    return '${n}h ago';
  }

  @override
  String daysAgo(Object n) {
    return '${n}d ago';
  }

  @override
  String requestCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n requests',
      one: '1 request',
    );
    return '$_temp0';
  }

  @override
  String get requestApproved => 'Request Approved!';

  @override
  String get requestRejected => 'Request Rejected';

  @override
  String get requestApprovedTheUserWasAdded =>
      'Request approved. The user was added to the waitlist.';

  @override
  String get requestApprovedSuccessfully => 'Request approved successfully.';

  @override
  String get requestRejectedSuccessfully => 'Request rejected successfully.';

  @override
  String get unableToReviewTheRequestPlease =>
      'Unable to review the request. Please try again.';

  @override
  String get unableToLoadJoinRequestsPlease =>
      'Unable to load join requests. Please try again.';

  @override
  String get reject => 'Reject';

  @override
  String get accept => 'Accept';

  @override
  String get noPendingRequests => 'No pending requests';

  @override
  String get requestsForYourPrivateActivitiesWill =>
      'Requests for your private activities will appear here.';

  @override
  String get newActivity => 'New Activity';

  @override
  String get createActivity => 'Create activity';

  @override
  String get whatWhereAndWhen => 'What, where & when';

  @override
  String get details => 'Details';

  @override
  String get review => 'Review';

  @override
  String get discardActivity => 'Discard activity?';

  @override
  String get yourActivityIsLiveAndReady =>
      'Your activity is live and ready for people to join.';

  @override
  String get activityCreated => 'Activity created!';

  @override
  String get viewActivity => 'View activity';

  @override
  String get activityTitle => 'Activity title';

  @override
  String get location => 'Location';

  @override
  String get date => 'Date';

  @override
  String get time => 'Time';

  @override
  String get activityTitleHint => 'Morning padel';

  @override
  String get tapToChange => 'Tap to change';

  @override
  String get chooseATime => 'Choose a time';

  @override
  String get pickAStartTime => 'Pick a start time';

  @override
  String get setDate => 'Set date';

  @override
  String get setTime => 'Set time';

  @override
  String get searchForAPlace => 'Search for a place';

  @override
  String get locationSearchHint => 'Padel club, café, gym…';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get startTypingToSearchRiyadhVenues =>
      'Start typing to search Riyadh venues.';

  @override
  String get noMatchesFound => 'No matches found.';

  @override
  String get numberOfPeople => 'Number of people';

  @override
  String youPlusAvailable(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'You + $n available spots',
      one: 'You + 1 available spot',
    );
    return '$_temp0';
  }

  @override
  String get includingYou => 'Including you';

  @override
  String get description => 'Description';

  @override
  String get activityDescriptionHint => 'Beginners welcome, bring water';

  @override
  String get photo => 'Photo';

  @override
  String get addAPhoto => 'Add a photo';

  @override
  String get photoAdded => 'Photo added';

  @override
  String get changePhoto => 'Change photo';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get visibility => 'Visibility';

  @override
  String get public => 'Public';

  @override
  String get anyoneCanFindAndJoin => 'Anyone can find and join';

  @override
  String get private => 'Private';

  @override
  String get joinByCodeYouApprove => 'Join by code, you approve';

  @override
  String get whenLabel => 'When';

  @override
  String get whereLabel => 'Where';

  @override
  String get people => 'People';

  @override
  String peopleSummary(Object n) {
    return '$n including you';
  }

  @override
  String get addATitle => 'Add a title';

  @override
  String keepItToLetters(Object n) {
    return 'Keep it to $n letters';
  }

  @override
  String get useLettersOnly => 'Use letters only';

  @override
  String get useEnglishLettersOnly => 'Use English letters only';

  @override
  String keepItToCharacters(Object n) {
    return 'Keep it to $n characters';
  }

  @override
  String get chooseALocation => 'Choose a location';

  @override
  String get pickADate => 'Pick a date';

  @override
  String get chooseADateWithinTheNext =>
      'Choose a date within the next 3 months';

  @override
  String get thisTimeHasAlreadyPassed => 'This time has already passed';

  @override
  String get pleaseCompleteEveryStepBeforeCreating =>
      'Please complete every step before creating.';

  @override
  String get weCouldntCreateYourActivityPlease =>
      'We couldn\'t create your activity. Please try again.';

  @override
  String get activityCreatedPhotoNotAdded =>
      'Your activity was created, but the photo couldn\'t be added to it.';

  @override
  String get activityCreatedPhotoNotSaved =>
      'Your activity was created, but the photo couldn\'t be saved.';

  @override
  String get couldntOpenYourPhotosPleaseTry =>
      'Couldn\'t open your photos. Please try again.';

  @override
  String get thatFileIsntAJpegOr => 'That file isn\'t a JPEG or PNG image.';

  @override
  String get thisImagesFileTypeAndIts =>
      'This image\'s file type and its contents don\'t match. Try another photo.';

  @override
  String get theSelectedPlaceIsMissingIts =>
      'The selected place is missing its address or coordinates.';

  @override
  String placeSearchFailed(Object code) {
    return 'Place search failed ($code). Please try again.';
  }

  @override
  String get couldNotReachPlaceSearchCheck =>
      'Could not reach place search. Check your connection and try again.';

  @override
  String get placeSearchReturnedAnUnexpectedResponse =>
      'Place search returned an unexpected response.';

  @override
  String get cannotCreateAnActivityWhileSigned =>
      'Cannot create an activity while signed out.';

  @override
  String get cannotDeleteAnActivityWhileSigned =>
      'Cannot delete an activity while signed out.';

  @override
  String get theActivityWasNotFoundOr =>
      'The activity was not found or cannot be deleted.';

  @override
  String get myLocation => 'My location';

  @override
  String get searchActivitiesOrPlaces => 'Search activities or places';

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String spotsLeft(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n spots available',
      one: '1 spot available',
    );
    return '$_temp0';
  }

  @override
  String get pleaseEnableLocationServicesToFind =>
      'Please enable location services to find nearby activities.';

  @override
  String get locationPermissionWasDenied => 'Location permission was denied.';

  @override
  String get locationPermissionIsPermanentlyDeniedPlease =>
      'Location permission is permanently denied. Please enable it in your device settings.';

  @override
  String get unableToRetrieveYourLocationShowing =>
      'Unable to retrieve your location. Showing Riyadh instead.';

  @override
  String get addAShortBioSoPeople =>
      'Add a short bio so people get to know you.';

  @override
  String get unableToSaveBioPleaseTry =>
      'Unable to save bio. Please try again.';

  @override
  String get activityType => 'Activity type';

  @override
  String get preferredLocation => 'Preferred location';

  @override
  String ageYears(Object age) {
    return '$age yrs';
  }

  @override
  String get friends => 'Friends';

  @override
  String get rating => 'Rating';

  @override
  String get interests => 'Interests';

  @override
  String get preferences => 'Preferences';

  @override
  String get about => 'About';

  @override
  String get addInterestsSoPeopleGetTo =>
      'Add interests so people get to know what you\'re into.';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get tapToChangePhoto => 'Tap to change photo';

  @override
  String get name => 'Name';

  @override
  String get yourName => 'Your name';

  @override
  String get bio => 'Bio';

  @override
  String get tellPeopleABitAboutYourself =>
      'Tell people a bit about yourself...';

  @override
  String get birthdayHint => 'DD/MM/YYYY';

  @override
  String get selectBirthday => 'Select birthday';

  @override
  String get setBirthday => 'Set birthday';

  @override
  String get selectYourBirthday => 'Select your birthday';

  @override
  String get editAge => 'Edit age';

  @override
  String awaitingConfirmationOn(Object email) {
    return '$email isn\'t confirmed yet';
  }

  @override
  String get changePassword => 'Change password';

  @override
  String get pleaseEnterYourName => 'Please enter your name.';

  @override
  String get adultMustBeBetween16And =>
      'Adult must be between 16 and 65 years old.';

  @override
  String get profileEmailRequired => 'Please enter your email.';

  @override
  String get yourChangesHaveBeenSavedCheck =>
      'Your changes have been saved. Check your new email to confirm the address change.';

  @override
  String get unableToSaveYourChangesPlease =>
      'Unable to save your changes. Please try again.';

  @override
  String get profileUsernameRequired => 'Please enter your username.';

  @override
  String get usernameMustBe330Characters =>
      'Username must be 3–30 characters and can only include letters, numbers, dots, and underscores.';

  @override
  String get thisUsernameIsAlreadyTaken => 'This username is already taken.';

  @override
  String get usernameCannotBeEmpty => 'Username cannot be empty';

  @override
  String get profileEmailInvalid => 'Please enter a valid email address.';

  @override
  String get profilePhoto => 'Profile photo';

  @override
  String get addPhoto => 'Add photo';

  @override
  String get adjustPhoto => 'Adjust photo';

  @override
  String get moveAndScale => 'Move and Scale';

  @override
  String get unableToUpdateYourPhotoPlease =>
      'Unable to update your photo. Please try again.';

  @override
  String get couldntLoadYourPhotoPleaseTry =>
      'Couldn\'t load your photo. Please try again.';

  @override
  String get unableToAdjustYourPhotoPlease =>
      'Unable to adjust your photo. Please try again.';

  @override
  String get unableToRemoveYourPhotoPlease =>
      'Unable to remove your photo. Please try again.';

  @override
  String get yourPhotoWasntSavedBecauseYoure =>
      'Your photo wasn\'t saved because you\'re signed out.';

  @override
  String get savedOnThisDeviceCloudPhoto =>
      'Saved on this device (cloud photo storage isn\'t set up yet).';

  @override
  String get editInterests => 'Edit Interests';

  @override
  String get yourInterests => 'Your interests';

  @override
  String get tapAnInterestBelowToAdd => 'Tap an interest below to add it.';

  @override
  String get addMore => 'Add more';

  @override
  String get youveAddedEveryInterest => 'You\'ve added every interest.';

  @override
  String get unableToSavePleaseTryAgain => 'Unable to save. Please try again.';

  @override
  String get changePasswordTitle => 'Change Password';

  @override
  String get currentPassword => 'Current password';

  @override
  String get enterYourCurrentPassword => 'Enter your current password';

  @override
  String get enterANewPassword => 'Enter a new password';

  @override
  String get confirmNewPassword => 'Confirm new password';

  @override
  String get reEnterTheNewPassword => 'Re-enter the new password';

  @override
  String get newPasswordMustBeDifferentFrom =>
      'New password must be different from your current one';

  @override
  String get pleaseConfirmYourNewPassword => 'Please confirm your new password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get currentPasswordIsIncorrect => 'Current password is incorrect';

  @override
  String get passwordIsTooWeakPleaseChoose =>
      'Password is too weak. Please choose a stronger one.';

  @override
  String get yourSessionHasExpiredPleaseLog =>
      'Your session has expired. Please log in again.';

  @override
  String get couldntUpdateYourPasswordPleaseTry =>
      'Couldn\'t update your password. Please try again.';

  @override
  String get couldntUpdateYourPasswordCheckYour =>
      'Couldn\'t update your password. Check your connection and try again.';

  @override
  String get changeEmail => 'Change email';

  @override
  String get confirmYourNewEmail => 'Confirm your new email';

  @override
  String openTheLinkWeSentTo(Object email) {
    return 'Open the link we sent to $email.';
  }

  @override
  String get cancelEmailChange => 'Cancel change';

  @override
  String get useADifferentEmailAddress => 'Use a different email';

  @override
  String get pleaseEnterANewEmailAddress => 'Please enter a new email address.';

  @override
  String get newEmailMustBeDifferentFrom =>
      'New email must be different from current email.';

  @override
  String get enterNewEmailAddress => 'New email address';

  @override
  String get weWillSendALinkToConfirm => 'We\'ll send a link to confirm it.';

  @override
  String get sendLink => 'Send link';

  @override
  String get linkSentCheckYourNewEmail => 'Link sent. Check your new email.';

  @override
  String get unableToUpdateEmailPleaseTry =>
      'Unable to update email. Please try again.';

  @override
  String get linkSentAgain => 'Link sent again.';

  @override
  String get pendingEmailChangeCancelled => 'Email change cancelled.';

  @override
  String get failedToCancelEmailChangeRequest =>
      'Failed to cancel email change request.';

  @override
  String get logOut => 'Log Out';

  @override
  String get logOutOfSynk => 'Log out of Synk?';

  @override
  String get youllNeedToSignInAgain =>
      'You\'ll need to sign in again to access your profile, activities, and matches.';

  @override
  String get unableToLogOut => 'Unable to log out.';

  @override
  String get unableToLogOutPleaseTry => 'Unable to log out. Please try again.';

  @override
  String get noInternetConnectionCheckYourConnection =>
      'No internet connection.';

  @override
  String get tooManyAttemptsPleaseWaitA =>
      'Too many attempts. Please wait a few minutes and try again.';

  @override
  String get somethingWentWrongPleaseTryAgain =>
      'Something went wrong. Please try again.';

  @override
  String get somethingWentWrong => 'Something went wrong.';

  @override
  String get unableToTransferHostingPleaseTry =>
      'Unable to transfer hosting. Please try again.';

  @override
  String get unableToLeaveTheActivityPlease =>
      'Unable to leave the activity. Please try again.';

  @override
  String get waitlistPromotions => 'Waitlist promotions';

  @override
  String get updatesWhenASpotOpensIn =>
      'Updates when a spot opens in a waitlisted activity.';

  @override
  String get youreIn => 'You\'re In! 🎉';

  @override
  String get aSpotOpenedUpInYour => 'A spot opened up in your activity.';

  @override
  String get interestOpenToAnything => 'Open to Anything';

  @override
  String get interestPadel => 'Padel';

  @override
  String get interestTennis => 'Tennis';

  @override
  String get interestBadminton => 'Badminton';

  @override
  String get interestTableTennis => 'Table Tennis';

  @override
  String get interestFootball => 'Football';

  @override
  String get interestBasketball => 'Basketball';

  @override
  String get interestVolleyball => 'Volleyball';

  @override
  String get interestGolf => 'Golf';

  @override
  String get interestBowling => 'Bowling';

  @override
  String get interestKarting => 'Karting';

  @override
  String get interestMartialArts => 'Martial Arts';

  @override
  String get interestPaintball => 'Paintball';

  @override
  String get interestCycling => 'Cycling';

  @override
  String get interestRunning => 'Running';

  @override
  String get interestHiking => 'Hiking';

  @override
  String get interestClimbing => 'Climbing';

  @override
  String get interestCamping => 'Camping';

  @override
  String get interestDesertTrips => 'Desert Trips';

  @override
  String get interestRoadTrips => 'Road Trips';

  @override
  String get interestBeach => 'Beach';

  @override
  String get interestPicnic => 'Picnic';

  @override
  String get interestPicnics => 'Picnics';

  @override
  String get interestTravel => 'Travel';

  @override
  String get interestFitness => 'Fitness';

  @override
  String get interestYoga => 'Yoga';

  @override
  String get interestSwimming => 'Swimming';

  @override
  String get interestDiving => 'Diving';

  @override
  String get interestSkating => 'Skating';

  @override
  String get interestDance => 'Dance';

  @override
  String get interestCoffee => 'Coffee';

  @override
  String get interestCooking => 'Cooking';

  @override
  String get interestFood => 'Food';

  @override
  String get interestShopping => 'Shopping';

  @override
  String get interestBoardGames => 'Board Games';

  @override
  String get interestCardGames => 'Card Games';

  @override
  String get interestChess => 'Chess';

  @override
  String get interestEscapeRoom => 'Escape Room';

  @override
  String get interestTrivia => 'Trivia';

  @override
  String get interestGaming => 'Gaming';

  @override
  String get interestMovies => 'Movies';

  @override
  String get interestComedy => 'Comedy';

  @override
  String get interestKaraoke => 'Karaoke';

  @override
  String get interestMusic => 'Music';

  @override
  String get interestArt => 'Art';

  @override
  String get interestPottery => 'Pottery';

  @override
  String get interestMuseums => 'Museums';

  @override
  String get interestBooks => 'Books';

  @override
  String get interestPhotography => 'Photography';

  @override
  String get interestLearning => 'Learning';

  @override
  String get interestVolunteering => 'Volunteering';

  @override
  String get interestPets => 'Pets';

  @override
  String get interestOther => 'Other';

  @override
  String get weekdayMon => 'Mon';

  @override
  String get weekdayTue => 'Tue';

  @override
  String get weekdayWed => 'Wed';

  @override
  String get weekdayThu => 'Thu';

  @override
  String get weekdayFri => 'Fri';

  @override
  String get weekdaySat => 'Sat';

  @override
  String get weekdaySun => 'Sun';

  @override
  String get monthJanuary => 'January';

  @override
  String get monthFebruary => 'February';

  @override
  String get monthMarch => 'March';

  @override
  String get monthApril => 'April';

  @override
  String get monthMay => 'May';

  @override
  String get monthJune => 'June';

  @override
  String get monthJuly => 'July';

  @override
  String get monthAugust => 'August';

  @override
  String get monthSeptember => 'September';

  @override
  String get monthOctober => 'October';

  @override
  String get monthNovember => 'November';

  @override
  String get monthDecember => 'December';

  @override
  String get timeAm => 'AM';

  @override
  String get timePm => 'PM';

  @override
  String get monthShortJan => 'Jan';

  @override
  String get monthShortFeb => 'Feb';

  @override
  String get monthShortMar => 'Mar';

  @override
  String get monthShortApr => 'Apr';

  @override
  String get monthShortMay => 'May';

  @override
  String get monthShortJun => 'Jun';

  @override
  String get monthShortJul => 'Jul';

  @override
  String get monthShortAug => 'Aug';

  @override
  String get monthShortSep => 'Sep';

  @override
  String get monthShortOct => 'Oct';

  @override
  String get monthShortNov => 'Nov';

  @override
  String get monthShortDec => 'Dec';

  @override
  String shortDate(Object weekday, Object month, Object day) {
    return '$weekday, $month $day';
  }

  @override
  String monthDay(Object month, Object day) {
    return '$month $day';
  }

  @override
  String timeOfDay(Object time, Object period) {
    return '$time $period';
  }

  @override
  String distanceKm(Object n) {
    return '$n km';
  }

  @override
  String get weekdayLetterMon => 'M';

  @override
  String get weekdayLetterTue => 'T';

  @override
  String get weekdayLetterWed => 'W';

  @override
  String get weekdayLetterThu => 'T';

  @override
  String get weekdayLetterFri => 'F';

  @override
  String get weekdayLetterSat => 'S';

  @override
  String get weekdayLetterSun => 'S';

  @override
  String longDate(Object weekday, Object month, Object day, Object year) {
    return '$weekday, $month $day, $year';
  }

  @override
  String get timeChipPick => 'Pick';

  @override
  String get timeChipATime => 'a time';

  @override
  String get timeChipFrom => 'From';

  @override
  String planCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n plans',
      one: '1 plan',
    );
    return '$_temp0';
  }

  @override
  String get noPlans => 'no plans';

  @override
  String onDate(Object date) {
    return 'on $date';
  }

  @override
  String get serverNoActivityWithCode =>
      'No activity was found with this code.';

  @override
  String get serverYouAreTheHost => 'You are the host of this activity.';

  @override
  String get serverAlreadyJoined => 'You have already joined this activity.';

  @override
  String get serverRequestWaiting =>
      'Your request is waiting for host approval.';

  @override
  String get serverRequestRejected => 'Your request was rejected by the host.';

  @override
  String get serverRequestSent => 'Your request was sent to the host.';

  @override
  String get serverFullAddedToWaitlist =>
      'The activity is full. You were added to the waitlist.';

  @override
  String get serverRequestNotFound => 'The join request was not found.';

  @override
  String get serverOnlyHostCanReview =>
      'Only the activity host can review this request.';

  @override
  String get serverPublicNoApproval =>
      'Public activities do not require host approval.';

  @override
  String get serverAlreadyReviewed => 'This request has already been reviewed.';

  @override
  String get serverUserHasConflict =>
      'The user is already hosting an activity at this time or has joined another activity on this date.';

  @override
  String get serverActivityNotFound => 'This activity was not found.';

  @override
  String get serverActivityPrivate =>
      'This activity is private. Ask the host for its code.';

  @override
  String get serverHostCannotLeave => 'Hosts cannot leave their own activity.';

  @override
  String get serverActivityStarted => 'This activity has already started.';

  @override
  String get serverNotParticipating =>
      'You are no longer part of this activity.';

  @override
  String get serverOnlyHostCanTransfer =>
      'Only the host can transfer this activity.';

  @override
  String get serverChooseAnotherHost =>
      'Choose another participant to become the host.';

  @override
  String get serverParticipantLeft =>
      'The selected participant is no longer in this activity.';

  @override
  String get serverLeftAndTransferred =>
      'You left the activity and transferred hosting.';

  @override
  String get settings => 'Settings';

  @override
  String get weCouldntSaveYourChanges =>
      'We couldn\'t save your changes. Please try again.';

  @override
  String get changesSaved => 'Changes saved!';

  @override
  String get changesSavedBanner => 'Changes saved';

  @override
  String get yourActivityDetailsHaveBeenUpdated =>
      'Your activity details have been updated.';

  @override
  String get editActivity => 'Edit activity';

  @override
  String get replacePhoto => 'Replace Photo';

  @override
  String get uploadActivityPhoto => 'Upload Activity Photo';

  @override
  String get photoCouldntBeDetached =>
      'The photo couldn\'t be detached from the activity.';

  @override
  String get photoDetachedFileNotRemoved =>
      'The photo was detached, but its stored file couldn\'t be removed.';

  @override
  String get cannotUpdateActivitySignedOut =>
      'Cannot update an activity while signed out.';

  @override
  String get activityNotFoundOrCannotUpdate =>
      'The activity was not found or cannot be updated.';

  @override
  String get activityUpdates => 'Activity updates';

  @override
  String get updatesToActivitiesYouHaveJoined =>
      'Updates to activities you have joined.';

  @override
  String get activityUpdated => 'Activity updated';

  @override
  String get anActivityYouJoinedHasNew =>
      'An activity you joined has new details.';
}
