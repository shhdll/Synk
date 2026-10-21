import 'package:flutter/widgets.dart';

import '../controllers/language_controller.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

// For code without a BuildContext, such as controllers and models.
AppLocalizations get appL10n =>
    lookupAppLocalizations(LanguageController.instance.locale);

// Interests, categories, activity type, location preference and gender are
// saved in English. This is the label to show for a saved value.
String valueLabel(String value) {
  final l = appL10n;
  return switch (value) {
    'Female' => l.female,
    'Male' => l.male,
    'Indoor' => l.indoor,
    'Outdoor' => l.outdoor,
    "I don't mind" || 'I don’t mind' => l.iDontMind,
    'In the city' => l.inTheCity,
    'Away from the city' => l.awayFromTheCity,
    'Open to Anything' => l.interestOpenToAnything,
    'Padel' => l.interestPadel,
    'Tennis' => l.interestTennis,
    'Badminton' => l.interestBadminton,
    'Table Tennis' => l.interestTableTennis,
    'Football' => l.interestFootball,
    'Basketball' => l.interestBasketball,
    'Volleyball' => l.interestVolleyball,
    'Golf' => l.interestGolf,
    'Bowling' => l.interestBowling,
    'Karting' => l.interestKarting,
    'Martial Arts' => l.interestMartialArts,
    'Paintball' => l.interestPaintball,
    'Cycling' => l.interestCycling,
    'Running' => l.interestRunning,
    'Hiking' => l.interestHiking,
    'Climbing' => l.interestClimbing,
    'Camping' => l.interestCamping,
    'Desert Trips' => l.interestDesertTrips,
    'Road Trips' => l.interestRoadTrips,
    'Beach' => l.interestBeach,
    'Picnic' => l.interestPicnic,
    'Picnics' => l.interestPicnics,
    'Travel' => l.interestTravel,
    'Fitness' => l.interestFitness,
    'Yoga' => l.interestYoga,
    'Swimming' => l.interestSwimming,
    'Diving' => l.interestDiving,
    'Skating' => l.interestSkating,
    'Dance' => l.interestDance,
    'Coffee' => l.interestCoffee,
    'Cooking' => l.interestCooking,
    'Food' => l.interestFood,
    'Shopping' => l.interestShopping,
    'Board Games' => l.interestBoardGames,
    'Card Games' => l.interestCardGames,
    'Chess' => l.interestChess,
    'Escape Room' => l.interestEscapeRoom,
    'Trivia' => l.interestTrivia,
    'Gaming' => l.interestGaming,
    'Movies' => l.interestMovies,
    'Comedy' => l.interestComedy,
    'Karaoke' => l.interestKaraoke,
    'Music' => l.interestMusic,
    'Art' => l.interestArt,
    'Pottery' => l.interestPottery,
    'Museums' => l.interestMuseums,
    'Books' => l.interestBooks,
    'Photography' => l.interestPhotography,
    'Learning' => l.interestLearning,
    'Volunteering' => l.interestVolunteering,
    'Pets' => l.interestPets,
    'Other' => l.interestOther,
    _ => value,
  };
}

// The database answers joins, reviews and leaves with an English message.
// This shows it in the app's language; unknown messages stay as they are.
String serverMessage(String message) {
  final l = appL10n;
  return switch (message) {
    'Enter a valid six-digit activity code.' => l.enterAValid6DigitActivity,
    'No activity was found with this code.' => l.serverNoActivityWithCode,
    'This activity is no longer available to join.' =>
      l.thisActivityIsNoLongerAvailable,
    'You are the host of this activity.' => l.serverYouAreTheHost,
    'You have already joined this activity.' => l.serverAlreadyJoined,
    'Your request is waiting for host approval.' => l.serverRequestWaiting,
    'You are already on the waitlist.' => l.youreOnTheWaitlist,
    'Your request was rejected by the host.' => l.serverRequestRejected,
    'You are already hosting an activity at this time or have joined '
        'another activity on this date.' =>
      l.thisActivityConflictsWithOneYouve,
    'You are already hosting or have joined an activity at this start time.' =>
      l.thisActivityConflictsWithOneYouve,
    'You joined the activity successfully.' => l.youveJoinedThisActivity,
    'Your request was sent to the host.' => l.serverRequestSent,
    'The activity is full. You were added to the waitlist.' =>
      l.serverFullAddedToWaitlist,
    'The join request was not found.' => l.serverRequestNotFound,
    'Only the activity host can review this request.' =>
      l.serverOnlyHostCanReview,
    'Public activities do not require host approval.' =>
      l.serverPublicNoApproval,
    'This request has already been reviewed.' => l.serverAlreadyReviewed,
    'The request was accepted.' => l.requestApprovedSuccessfully,
    'The request was rejected.' => l.requestRejectedSuccessfully,
    'The activity is full. The user was moved to the waitlist.' =>
      l.requestApprovedTheUserWasAdded,
    'The user is already hosting an activity at this time or has joined '
        'another activity on this date.' =>
      l.serverUserHasConflict,
    'This activity was not found.' => l.serverActivityNotFound,
    'This activity is private. Ask the host for its code.' =>
      l.serverActivityPrivate,
    'Hosts cannot leave their own activity.' => l.serverHostCannotLeave,
    'This activity has already started.' => l.serverActivityStarted,
    'You are no longer part of this activity.' => l.serverNotParticipating,
    'You have successfully left this activity.' =>
      l.youHaveSuccessfullyLeftThisActivity,
    'You have been removed from the waitlist.' => l.youHaveBeenRemovedFromThe,
    'Your join request has been cancelled.' =>
      l.yourJoinRequestHasBeenCancelled,
    'Only the host can transfer this activity.' => l.serverOnlyHostCanTransfer,
    'Choose another participant to become the host.' =>
      l.serverChooseAnotherHost,
    'The selected participant is no longer in this activity.' =>
      l.serverParticipantLeft,
    'You left the activity and transferred hosting.' =>
      l.serverLeftAndTransferred,
    _ => message,
  };
}

// ---- Dates and times -------------------------------------------------------
// Arabic has no common short forms, so it uses the full day and month names
// (الثلاثاء، 21 أكتوبر). Digits stay 0-9 in both languages.

String weekdayShort(DateTime date) {
  final l = appL10n;
  return [
    l.weekdayMon,
    l.weekdayTue,
    l.weekdayWed,
    l.weekdayThu,
    l.weekdayFri,
    l.weekdaySat,
    l.weekdaySun,
  ][date.weekday - 1];
}

// Jan, Feb... in English; the full name in Arabic.
String monthShort(int month) {
  final l = appL10n;
  return [
    l.monthShortJan,
    l.monthShortFeb,
    l.monthShortMar,
    l.monthShortApr,
    l.monthShortMay,
    l.monthShortJun,
    l.monthShortJul,
    l.monthShortAug,
    l.monthShortSep,
    l.monthShortOct,
    l.monthShortNov,
    l.monthShortDec,
  ][month - 1];
}

String monthName(int month) {
  final l = appL10n;
  return [
    l.monthJanuary,
    l.monthFebruary,
    l.monthMarch,
    l.monthApril,
    l.monthMay,
    l.monthJune,
    l.monthJuly,
    l.monthAugust,
    l.monthSeptember,
    l.monthOctober,
    l.monthNovember,
    l.monthDecember,
  ][month - 1];
}

// "Tue, Oct 21" / "الثلاثاء، 21 أكتوبر"
String formatShortDate(DateTime date) =>
    appL10n.shortDate(weekdayShort(date), monthShort(date.month), date.day);

// AM/PM, or ص/م in Arabic.
String periodLabel(int hour) => hour < 12 ? appL10n.timeAm : appL10n.timePm;

// "7:30 PM" / "7:30 م"
String formatTime(int hour, int minute) {
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  final mm = minute.toString().padLeft(2, '0');
  return appL10n.timeOfDay('$h12:$mm', periodLabel(hour));
}
