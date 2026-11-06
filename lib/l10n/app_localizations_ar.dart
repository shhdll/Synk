// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get overlappingActivity => 'نشاط متداخل في الموعد';

  @override
  String get overlappingActivityNotice =>
      'إذا تم قبولك في نشاط، ستتم إزالتك تلقائيا من قائمة الانتظار المتداخلة الأخرى أو إلغاء طلبك المعلق';

  @override
  String get shareCode => 'مشاركة الرمز';

  @override
  String get share => 'مشاركة';

  @override
  String shareMessage(Object title, Object date, Object place, Object code) {
    return 'ودك تجي معنا $title!\n📅 $date\n📍 $place\n\nاكتب الرمز في Synk: $code';
  }

  @override
  String get couldntOpenTheShareMenu => 'تعذر فتح قائمة المشاركة';

  @override
  String get language => 'اللغة';

  @override
  String get appLanguage => 'لغة التطبيق';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'العربية';

  @override
  String get save => 'حفظ';

  @override
  String get saveChanges => 'حفظ التغييرات';

  @override
  String get cancel => 'إلغاء';

  @override
  String get done => 'تم';

  @override
  String get doneTitle => 'تم!';

  @override
  String get continueButton => 'متابعة';

  @override
  String get close => 'إغلاق';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get tryAgain => 'حاول مرة أخرى';

  @override
  String get refresh => 'تحديث';

  @override
  String get reset => 'إعادة ضبط';

  @override
  String get skip => 'تخطي';

  @override
  String get gotIt => 'حسنا';

  @override
  String get choose => 'اختيار';

  @override
  String get optional => 'اختياري';

  @override
  String get notSet => 'غير محدد';

  @override
  String get you => 'أنت';

  @override
  String get saved => 'تم الحفظ';

  @override
  String get yourChangesHaveBeenSaved => 'تم حفظ التغييرات';

  @override
  String get discardChanges => 'تجاهل التغييرات؟';

  @override
  String get unsavedChangesWillBeLost => 'ستفقد التعديلات غير المحفوظة';

  @override
  String get keepEditing => 'متابعة التعديل';

  @override
  String get discardAndLeave => 'خروج بدون حفظ';

  @override
  String get synkMember => 'عضو في Synk';

  @override
  String get synkUser => 'مستخدم Synk';

  @override
  String get communityMember => 'عضو';

  @override
  String get anonymous => 'شخص مجهول';

  @override
  String get untitledActivity => 'نشاط بدون عنوان';

  @override
  String get home => 'الرئيسية';

  @override
  String get map => 'الخريطة';

  @override
  String get activities => 'الأنشطة';

  @override
  String get profile => 'حسابي';

  @override
  String get create => 'إنشاء';

  @override
  String get findYourMissingPiece => 'القى\nقطعتك الناقصة';

  @override
  String get readyToSynk => 'جاهز لـ Synk؟';

  @override
  String get joinThousandsAlreadyDoingWhatThey => 'خلك مع ناس يشاركونك شغفك!';

  @override
  String get welcomeBack => 'مرحبا بعودتك';

  @override
  String get logInToConnectAndJoin => 'سجل دخولك وانضم للأنشطة من حولك';

  @override
  String get username => 'اسم المستخدم';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get emailAddress => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get pleaseEnterYourUsername => 'أدخل اسم المستخدم';

  @override
  String get pleaseEnterAValidEmail => 'أدخل بريد إلكتروني صحيح';

  @override
  String get pleaseEnterYourPassword => 'أدخل كلمة المرور';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get logIn => 'تسجيل الدخول';

  @override
  String get dontHaveAnAccount => 'ليس لديك حساب؟';

  @override
  String get signUp => 'إنشاء حساب';

  @override
  String get unableToLogIn => 'تعذر تسجيل الدخول';

  @override
  String get unableToLogInPleaseTry => 'تعذر تسجيل الدخول، حاول مرة أخرى';

  @override
  String get accountSuspended => 'تم إيقاف هذا الحساب';

  @override
  String get suspendedTitle => 'تم إيقاف حسابك';

  @override
  String suspendedMessage(Object email) {
    return 'إذا كنت ترى أن هذا خطأ، أخبرنا بما حدث وسنرد على $email';
  }

  @override
  String get suspendedMessageHint => 'رسالتك';

  @override
  String get contactSupport => 'تواصل مع الدعم';

  @override
  String get suspendedSent => 'تم إرسال رسالتك، سنرد عليك بالبريد';

  @override
  String get noAccountFoundWithThisUsername => 'لا يوجد حساب بهذا الاسم';

  @override
  String get pleaseVerifyYourEmailFirst => 'أكد بريدك الإلكتروني أولا';

  @override
  String get incorrectUsernameOrPassword =>
      'اسم المستخدم أو كلمة المرور غير صحيحة';

  @override
  String get incorrectEmailOrPassword => 'البريد أو كلمة المرور غير صحيحة';

  @override
  String get tellUsAboutYourself => 'أخبرنا\nعن نفسك';

  @override
  String get thisHelpsCustomizeYourCommunityExperience =>
      'لتخصيص تجربتك بما يناسبك';

  @override
  String get fullName => 'الاسم الكامل';

  @override
  String get birthday => 'تاريخ الميلاد';

  @override
  String get gender => 'الجنس';

  @override
  String get female => 'أنثى';

  @override
  String get male => 'ذكر';

  @override
  String get createYourAccount => 'أنشئ\nحسابك';

  @override
  String get completeRegistration => 'إكمال التسجيل';

  @override
  String get eightPlusCharacters => '8 أحرف أو أكثر';

  @override
  String get uppercaseLetter => 'حرف كبير';

  @override
  String get lowercaseLetter => 'حرف صغير';

  @override
  String get aNumber => 'رقم';

  @override
  String get specialCharacter => 'رمز خاص';

  @override
  String get fullNameIsRequired => 'الاسم الكامل مطلوب';

  @override
  String get nameCanBeAtMost50 => 'الاسم لا يتجاوز 50 حرف';

  @override
  String get nameCanOnlyContainLettersAnd => 'الاسم يحتوي على حروف ومسافات فقط';

  @override
  String get birthdayIsRequired => 'تاريخ الميلاد مطلوب';

  @override
  String get pleaseEnterAValidBirthday => 'أدخل تاريخ ميلاد صحيح';

  @override
  String get ageMustBeBetween16And => 'العمر يجب أن يكون بين 16 و 65 سنة';

  @override
  String get emailAddressIsRequired => 'البريد الإلكتروني مطلوب';

  @override
  String get anAccountWithThisEmailAlready => 'يوجد حساب بهذا البريد';

  @override
  String get pleaseSelectYourGender => 'اختر الجنس';

  @override
  String passwordTooWeakMix(Object n) {
    return 'كلمة المرور ضعيفة، استخدم $n أحرف على الأقل مع حروف وأرقام ورموز';
  }

  @override
  String get weCouldntCreateYourAccountPlease =>
      'تعذر إنشاء الحساب، حاول مرة أخرى';

  @override
  String get passwordIsRequired => 'كلمة المرور مطلوبة';

  @override
  String get passwordMustBeAtLeast8 => 'كلمة المرور 8 أحرف على الأقل';

  @override
  String get passwordNeedsUppercase =>
      'يجب أن تحتوي على حرف كبير واحد على الأقل';

  @override
  String get passwordNeedsLowercase =>
      'يجب أن تحتوي على حرف صغير واحد على الأقل';

  @override
  String get passwordNeedsNumber => 'يجب أن تحتوي على رقم واحد على الأقل';

  @override
  String get passwordNeedsSpecial =>
      'يجب أن تحتوي على رمز خاص واحد على الأقل (مثل @\$!%*?&)';

  @override
  String get usernameIsRequired => 'اسم المستخدم مطلوب';

  @override
  String get usernameMustBeAtLeast3 => 'اسم المستخدم 3 أحرف على الأقل';

  @override
  String get usernameCanBeAtMost30 => 'اسم المستخدم لا يتجاوز 30 حرف';

  @override
  String get usernameCanOnlyContainLettersNumbers =>
      'اسم المستخدم يحتوي على حروف وأرقام و _ و . فقط';

  @override
  String get whatAreYouInto => 'وش تحب؟';

  @override
  String get pickTheActivitiesYouEnjoy => 'اختر الأنشطة التي تستمتع بها';

  @override
  String get whereDoYouLikeToHave => 'وين تحب تقضي وقتك؟';

  @override
  String get tellUsWhatKindOfActivities => 'أخبرنا بنوع الأنشطة المفضلة لديك';

  @override
  String get howFarAreYouWillingTo => 'ما المسافة المناسبة لك؟';

  @override
  String get chooseHowCloseYouWantYour => 'اختر مدى قرب الأنشطة منك';

  @override
  String get indoor => 'أنشطة داخلية';

  @override
  String get outdoor => 'أنشطة خارجية';

  @override
  String get iDontMind => 'لا يهم';

  @override
  String get inTheCity => 'داخل المدينة';

  @override
  String get awayFromTheCity => 'خارج المدينة';

  @override
  String get checkYourInbox => 'تحقق من بريدك';

  @override
  String get weSentAConfirmationLinkTo => 'أرسلنا رابط التأكيد إلى:';

  @override
  String resendInSeconds(Object s) {
    return 'إعادة الإرسال بعد $s ث';
  }

  @override
  String get resendVerificationEmail => 'إعادة إرسال رسالة التأكيد';

  @override
  String get iveConfirmedMyEmail => 'أكدت بريدي';

  @override
  String get backToSignIn => 'العودة لتسجيل الدخول';

  @override
  String get notConfirmedYetTapTheLink =>
      'لم يتم التأكيد بعد، اضغط الرابط في البريد أولا';

  @override
  String get alreadyConfirmedGoBackAndSign => 'أكدت بريدك؟ ارجع وسجل دخولك';

  @override
  String get couldNotCheckRightNowPlease => 'تعذر التحقق الآن، حاول مرة أخرى';

  @override
  String get verificationEmailResentPleaseCheckYour =>
      'أعدنا إرسال رسالة التأكيد إلى بريدك';

  @override
  String get failedToResendConfirmationEmail =>
      'تعذر إعادة إرسال رسالة التأكيد';

  @override
  String get anUnexpectedErrorOccurredPleaseTry =>
      'حدث خطأ غير متوقع، حاول مرة أخرى';

  @override
  String get forgotYourPassword => 'نسيت كلمة المرور؟';

  @override
  String get itHappensEnterYourEmailAnd =>
      'أدخل بريدك وسنرسل لك رابط استعادة الحساب';

  @override
  String get sendResetLink => 'إرسال رابط الاستعادة';

  @override
  String get backToLogIn => 'العودة لتسجيل الدخول';

  @override
  String get forYourSecurityWellSendA =>
      'نرسل الرابط فقط إذا كان البريد مسجل في Synk';

  @override
  String get weSentAResetLinkTo => 'أرسلنا رابط الاستعادة إلى';

  @override
  String get theLinkCanOnlyBeUsed => 'الرابط يستخدم مرة واحدة فقط';

  @override
  String get openItOnThisDeviceSo => 'افتحه من هذا الجهاز ليتم تسجيل دخولك';

  @override
  String get notThereCheckYourSpamFolder =>
      'لم يصلك؟ تحقق من البريد غير المرغوب';

  @override
  String get resendLink => 'إعادة إرسال الرابط';

  @override
  String resendLinkCountdown(Object ss) {
    return 'إعادة الإرسال بعد 0:$ss';
  }

  @override
  String get wrongEmailEditIt => 'بريد خاطئ؟ عدله';

  @override
  String get unableToSendTheLink => 'تعذر إرسال الرابط';

  @override
  String get aNewLinkIsOnIts => 'أرسلنا رابط جديد';

  @override
  String get pleaseEnterYourEmail => 'أدخل بريدك الإلكتروني';

  @override
  String get pleaseEnterAValidEmailAddress => 'أدخل بريد إلكتروني صحيح';

  @override
  String get pleaseConfirmYourPassword => 'أكد كلمة المرور';

  @override
  String get couldntSendTheLinkCheckYour =>
      'تعذر إرسال الرابط، تحقق من اتصالك وحاول مرة أخرى';

  @override
  String get pleaseWaitAMomentBeforeRequesting =>
      'انتظر قليلا قبل طلب رابط آخر';

  @override
  String passwordTooWeakMinLength(Object n) {
    return 'كلمة المرور ضعيفة، استخدم $n أحرف على الأقل';
  }

  @override
  String get thatsYourCurrentPasswordPickA =>
      'هذه كلمة مرورك الحالية، اختر كلمة جديدة';

  @override
  String get thisLinkIsNoLongerValid => 'الرابط لم يعد صالح، اطلب رابط جديد';

  @override
  String get createANewPassword => 'أنشئ كلمة مرور جديدة';

  @override
  String get newPassword => 'كلمة المرور الجديدة';

  @override
  String get confirmPassword => 'تأكيد كلمة المرور';

  @override
  String get reTypePassword => 'أعد كتابة كلمة المرور';

  @override
  String get updatePassword => 'تحديث كلمة المرور';

  @override
  String get unableToUpdateYourPassword => 'تعذر تحديث كلمة المرور';

  @override
  String get passwordNotChanged => 'لم تتغير كلمة المرور';

  @override
  String get thisLinkHasExpired => 'انتهت صلاحية الرابط';

  @override
  String get resetLinksCanOnlyBeUsed =>
      'انتهت صلاحية الرابط، اطلب رابط جديد لاستعادة حسابك';

  @override
  String get requestANewLink => 'طلب رابط جديد';

  @override
  String get youreBackIn => 'عدت من جديد';

  @override
  String get yourNewPasswordIsSetLog =>
      'تم تعيين كلمة المرور، سجل دخولك وأكمل من حيث توقفت';

  @override
  String get thisLinkHasExpiredOrWas =>
      'الرابط منتهي أو مستخدم، اطلب رابط جديد';

  @override
  String get confirmedNowOpenTheLinkSent =>
      'تم التأكيد، افتح الرابط المرسل إلى بريدك الآخر';

  @override
  String get yourEmailAddressWasUpdated => 'تم تحديث بريدك الإلكتروني';

  @override
  String welcomeName(Object name) {
    return 'أهلا، $name';
  }

  @override
  String get welcomeToSynk => 'أهلا بك في Synk';

  @override
  String heyName(Object name) {
    return 'مرحبا $name';
  }

  @override
  String get heyThere => 'مرحبا';

  @override
  String get letsFindYourPeople => 'لنجد رفاقك';

  @override
  String get readyForSomethingNew => 'جاهز لشيء جديد؟';

  @override
  String get readyForSomethingNewFemale => 'جاهزة لشيء جديد؟';

  @override
  String get searchActivitiesOrLocations => 'ابحث عن نشاط أو مكان...';

  @override
  String get topPickLikesIndoor => 'تحب الأنشطة الداخلية';

  @override
  String get topPickLikesOutdoor => 'تحب الأنشطة الخارجية';

  @override
  String topPickYouLike(Object interest) {
    return 'تحب $interest';
  }

  @override
  String get topPickPopularNearYou => 'رائج بالقرب منك';

  @override
  String topPickDistanceKm(Object km) {
    return '$km كم';
  }

  @override
  String get clearFilters => 'مسح الفلاتر';

  @override
  String noPlansMatchQuery(Object q) {
    return 'لا توجد خطط تطابق \"$q\"';
  }

  @override
  String get noPlansMatchYourFilters => 'لا توجد خطط تطابق الفلاتر';

  @override
  String noCategoryPlans(Object category, Object when) {
    return 'لا توجد خطط $category $when';
  }

  @override
  String get weCouldntReachSynk => 'تعذر الاتصال بـ Synk';

  @override
  String get itsQuietHereForNow => 'لا شيء هنا حاليا';

  @override
  String get checkYourConnectionAndTryAgain => 'تحقق من اتصالك وحاول مرة أخرى';

  @override
  String get newPlansPopUpAllThe =>
      'تظهر خطط جديدة باستمرار، اضغط + لتبدأ خطتك';

  @override
  String get createOne => 'أنشئ واحدة';

  @override
  String get haveACode => 'لديك رمز؟';

  @override
  String get haveAnActivityCodeJoinWith => 'لديك رمز نشاط؟ انضم به';

  @override
  String get unableToLoadActivitiesPullDown =>
      'تعذر تحميل الأنشطة، اسحب للأسفل للتحديث';

  @override
  String get filters => 'الفلاتر';

  @override
  String filtersActive(Object n) {
    return 'الفلاتر، $n مفعلة';
  }

  @override
  String get sortBy => 'الترتيب حسب';

  @override
  String get soonest => 'الأقرب وقتا';

  @override
  String get latest => 'الأبعد وقتا';

  @override
  String get nearest => 'الأقرب';

  @override
  String get farthest => 'الأبعد';

  @override
  String get almostFull => 'قارب الامتلاء';

  @override
  String get mostSpots => 'أماكن أكثر';

  @override
  String get any => 'الكل';

  @override
  String get today => 'اليوم';

  @override
  String get tomorrow => 'غدا';

  @override
  String get morning => 'الصباح';

  @override
  String get evening => 'المساء';

  @override
  String get night => 'الليل';

  @override
  String get slotMorningHours => '6 ص–12 م';

  @override
  String get slotEveningHours => '12–9 م';

  @override
  String get slotNightHours => '9 م–12 ص';

  @override
  String get within => 'ضمن';

  @override
  String get fiveKm => '5 كم';

  @override
  String get locating => 'جار تحديد الموقع…';

  @override
  String get allowLocation => 'السماح بالموقع';

  @override
  String get startingFrom => 'يبدأ من';

  @override
  String fromTime(Object time) {
    return 'من $time';
  }

  @override
  String get pickATime => 'اختر الوقت';

  @override
  String get category => 'الفئة';

  @override
  String get spots => 'الأماكن';

  @override
  String get oneLeft => 'بقي مكان';

  @override
  String get hasSpots => 'متاح';

  @override
  String get full => 'ممتلئ';

  @override
  String get noMatchesTryFewerFilters => 'لا نتائج، قلل الفلاتر';

  @override
  String get showOneActivity => 'عرض نشاط واحد';

  @override
  String showActivities(Object n) {
    return 'عرض النتائج ($n)';
  }

  @override
  String todayAtTime(Object time) {
    return 'اليوم، $time';
  }

  @override
  String tomorrowAtTime(Object time) {
    return 'غدا، $time';
  }

  @override
  String get available => 'متاح';

  @override
  String get oneMoreNeeded => 'ناقص شخص واحد';

  @override
  String joinedOfMaxGoing(Object joined, Object max) {
    return '$joined/$max مشارك';
  }

  @override
  String get waitlisted => 'في الانتظار';

  @override
  String get code => 'الرمز';

  @override
  String get dateAndTime => 'التاريخ والوقت';

  @override
  String get viewOnMap => 'عرض على الخريطة';

  @override
  String get openInGoogleMaps => 'فتح في خرائط Google';

  @override
  String get couldntOpenGoogleMaps => 'تعذر فتح خرائط Google';

  @override
  String get participants => 'المشاركون';

  @override
  String joinedOfMaxSpots(Object joined, Object max) {
    return '$joined من $max';
  }

  @override
  String get youllSeeWhosGoingOnceThe =>
      'ستظهر لك قائمة المشاركين بعد قبول المنظم';

  @override
  String get host => 'المنظم';

  @override
  String get activityCode => 'رمز النشاط';

  @override
  String get copyCode => 'نسخ الرمز';

  @override
  String get activityCodeCopied => 'تم نسخ الرمز';

  @override
  String get deleteActivity => 'حذف النشاط';

  @override
  String get youreOnTheWaitlist => 'أنت في قائمة الانتظار';

  @override
  String waitlistPeopleAhead(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n شخص قبلك',
      many: '$n شخصا قبلك',
      few: '$n أشخاص قبلك',
      two: 'شخصان قبلك',
      one: 'شخص واحد قبلك',
      zero: 'أنت التالي في قائمة الانتظار',
    );
    return '$_temp0';
  }

  @override
  String get waitingForHostApproval => 'بانتظار موافقة المنظم';

  @override
  String get youveJoinedThisActivity => 'انضممت لهذا النشاط';

  @override
  String get joinWaitlist => 'انضم لقائمة الانتظار';

  @override
  String get joinActivity => 'انضم للنشاط';

  @override
  String get leaveActivity => 'مغادرة النشاط';

  @override
  String get leaveActivityTitle => 'مغادرة النشاط؟';

  @override
  String get confirmLeaveActivity => 'مغادرة هذا النشاط؟';

  @override
  String get stay => 'البقاء';

  @override
  String get youLeftTheActivity => 'غادرت النشاط';

  @override
  String get youHaveSuccessfullyLeftThisActivity => 'غادرت النشاط بنجاح';

  @override
  String get leaveWaitlistTitle => 'مغادرة قائمة الانتظار؟';

  @override
  String get confirmLeaveWaitlist => 'مغادرة قائمة الانتظار؟';

  @override
  String get stayOnWaitlist => 'البقاء في القائمة';

  @override
  String get leaveWaitlist => 'مغادرة القائمة';

  @override
  String get youLeftTheWaitlist => 'غادرت قائمة الانتظار';

  @override
  String get youHaveBeenRemovedFromThe => 'تمت إزالتك من قائمة الانتظار';

  @override
  String get cancelRequestTitle => 'إلغاء الطلب؟';

  @override
  String get confirmCancelRequest => 'إلغاء طلبك؟';

  @override
  String get keepRequest => 'إبقاء الطلب';

  @override
  String get cancelRequest => 'إلغاء الطلب';

  @override
  String get requestCancelled => 'تم إلغاء الطلب';

  @override
  String get yourJoinRequestHasBeenCancelled => 'تم إلغاء طلب الانضمام';

  @override
  String get youAreNowTheHostOf => 'أصبحت منظم هذا النشاط';

  @override
  String get transferHostingAndLeave => 'نقل التنظيم والمغادرة؟';

  @override
  String transferHostMessage(Object name) {
    return '$name سيصبح المنظم';
  }

  @override
  String get transferAndLeave => 'نقل ومغادرة';

  @override
  String newHostIs(Object name) {
    return 'المنظم الآن: $name';
  }

  @override
  String get chooseANewHost => 'اختر منظم جديد';

  @override
  String get thePersonYouChooseGetsFull =>
      'يحصل الشخص المختار على كل صلاحيات المنظم ومنها إدارة الطلبات وحذف النشاط، وستغادر أنت النشاط';

  @override
  String get unableToLoadParticipantsPleaseTry =>
      'تعذر تحميل المشاركين، حاول مرة أخرى';

  @override
  String get noOneCanTakeOverYet =>
      'لا يوجد من يتولى التنظيم بعد، المشاركون فقط يمكنهم أن يصبحوا منظمين ويمكنك حذف النشاط بدلا من ذلك';

  @override
  String get thisActivityIsNoLongerAvailable => 'هذا النشاط لم يعد متاح';

  @override
  String get unableToOpenThisActivity => 'تعذر فتح النشاط';

  @override
  String get all => 'الكل';

  @override
  String get hosting => 'أنظمها';

  @override
  String get joined => 'انضممت';

  @override
  String get requested => 'طلباتي';

  @override
  String get upcoming => 'القادمة';

  @override
  String get past => 'السابقة';

  @override
  String get noPastActivities => 'لا توجد أنشطة سابقة';

  @override
  String get activitiesYouveBeenPartOfWill =>
      'ستظهر هنا الأنشطة التي شاركت فيها';

  @override
  String get noUpcomingActivities => 'لا توجد أنشطة قادمة';

  @override
  String get joinOneFromHomeOrTap =>
      'انضم لنشاط من الرئيسية أو اضغط + لإنشاء نشاطك';

  @override
  String get joinRequests => 'طلبات الانضمام';

  @override
  String get deleteActivityTitle => 'حذف النشاط؟';

  @override
  String get thisActionCannotBeUndoneThe => 'سيحذف للجميع';

  @override
  String get keepActivity => 'إبقاء النشاط';

  @override
  String get deleteActivityButton => 'حذف النشاط';

  @override
  String get activityDeleted => 'تم حذف النشاط';

  @override
  String get theActivityHasBeenDeletedSuccessfully => 'تم حذف النشاط بنجاح';

  @override
  String get unableToDeleteTheActivityPlease =>
      'تعذر حذف النشاط، حاول مرة أخرى';

  @override
  String get joinWithACode => 'الانضمام برمز';

  @override
  String get enterThe6DigitActivityCode => 'أدخل رمز النشاط المكون من 6 أرقام';

  @override
  String get joinActivityButton => 'انضمام';

  @override
  String get enterAValid6DigitActivity => 'أدخل رمز صحيح من 6 أرقام';

  @override
  String get unableToJoinTheActivityPlease => 'تعذر الانضمام، حاول مرة أخرى';

  @override
  String get unableToJoin => 'تعذر الانضمام';

  @override
  String get thisActivityConflictsWithOneYouve =>
      'هناك نشاط آخر تستضيفه أو انضممت إليه يبدأ في الوقت نفسه، احذف النشاط الذي تستضيفه أو غادر النشاط الذي انضممت إليه، ثم حاول مجددا';

  @override
  String get joinedTitle => 'تم الانضمام!';

  @override
  String get alreadyJoined => 'منضم مسبقا';

  @override
  String get requestSent => 'تم إرسال الطلب!';

  @override
  String get requestAlreadySent => 'الطلب مرسل مسبقا';

  @override
  String get addedToWaitlist => 'تمت إضافتك لقائمة الانتظار!';

  @override
  String get alreadyWaitlisted => 'في قائمة الانتظار مسبقا';

  @override
  String get justNow => 'الآن';

  @override
  String minutesAgo(Object n) {
    return 'قبل $n د';
  }

  @override
  String hoursAgo(Object n) {
    return 'قبل $n س';
  }

  @override
  String daysAgo(Object n) {
    return 'قبل $n ي';
  }

  @override
  String requestCount(int n) {
    return 'الطلبات: $n';
  }

  @override
  String get requestApproved => 'تم قبول الطلب!';

  @override
  String get requestRejected => 'تم رفض الطلب';

  @override
  String get requestApprovedTheUserWasAdded =>
      'تم قبول الطلب وإضافة المستخدم لقائمة الانتظار';

  @override
  String get requestApprovedSuccessfully => 'تم قبول الطلب';

  @override
  String get requestRejectedSuccessfully => 'تم رفض الطلب';

  @override
  String get unableToReviewTheRequestPlease =>
      'تعذرت مراجعة الطلب، حاول مرة أخرى';

  @override
  String get unableToLoadJoinRequestsPlease =>
      'تعذر تحميل الطلبات، حاول مرة أخرى';

  @override
  String get reject => 'رفض';

  @override
  String get accept => 'قبول';

  @override
  String get noPendingRequests => 'لا توجد طلبات';

  @override
  String get requestsForYourPrivateActivitiesWill =>
      'ستظهر هنا طلبات أنشطتك الخاصة';

  @override
  String get newActivity => 'نشاط جديد';

  @override
  String get createActivity => 'إنشاء النشاط';

  @override
  String get whatWhereAndWhen => 'ماذا وأين ومتى';

  @override
  String get details => 'التفاصيل';

  @override
  String get review => 'المراجعة';

  @override
  String get discardActivity => 'تجاهل النشاط؟';

  @override
  String get yourActivityIsLiveAndReady => 'نشاطك منشور وجاهز للانضمام';

  @override
  String get activityCreated => 'تم إنشاء النشاط!';

  @override
  String get viewActivity => 'عرض النشاط';

  @override
  String get activityTitle => 'عنوان النشاط';

  @override
  String get location => 'الموقع';

  @override
  String get date => 'التاريخ';

  @override
  String get time => 'الوقت';

  @override
  String get activityTitleHint => 'Morning padel';

  @override
  String get tapToChange => 'اضغط للتغيير';

  @override
  String get chooseATime => 'اختر الوقت';

  @override
  String get pickAStartTime => 'اختر وقت البدء';

  @override
  String get setDate => 'تحديد التاريخ';

  @override
  String get setTime => 'تحديد الوقت';

  @override
  String get searchForAPlace => 'ابحث عن مكان';

  @override
  String get locationSearchHint => 'نادي بادل، مقهى، صالة رياضية…';

  @override
  String get clearSearch => 'مسح البحث';

  @override
  String get startTypingToSearchRiyadhVenues => 'اكتب للبحث عن أماكن في الرياض';

  @override
  String get useThisLocation => 'استخدم هذا الموقع';

  @override
  String get findingAddress => 'جار تحديد العنوان…';

  @override
  String get pinnedLocation => 'موقع محدد';

  @override
  String get noMatchesFound => 'لا توجد نتائج';

  @override
  String get numberOfPeople => 'عدد الأشخاص';

  @override
  String youPlusAvailable(int n) {
    return 'أنت + $n';
  }

  @override
  String get includingYou => 'بما فيهم أنت';

  @override
  String get description => 'الوصف';

  @override
  String get activityDescriptionHint => 'المبتدئون مرحب بهم، أحضر الماء';

  @override
  String get photo => 'الصورة';

  @override
  String get photos => 'الصور';

  @override
  String get camera => 'الكاميرا';

  @override
  String get addAPhoto => 'أضف صورة';

  @override
  String get photoAdded => 'تمت إضافة الصورة';

  @override
  String get changePhoto => 'تغيير الصورة';

  @override
  String get removePhoto => 'حذف الصورة';

  @override
  String get visibility => 'الظهور';

  @override
  String get public => 'عام';

  @override
  String get anyoneCanFindAndJoin => 'يمكن لأي شخص إيجاده والانضمام';

  @override
  String get private => 'خاص';

  @override
  String get joinByCodeYouApprove => 'الانضمام بالرمز بعد موافقتك';

  @override
  String get setting => 'المكان';

  @override
  String get settingIndoor => 'داخلي';

  @override
  String get settingOutdoor => 'خارجي';

  @override
  String get chooseIndoorOrOutdoor => 'اختر داخلي أو خارجي';

  @override
  String get whenLabel => 'متى';

  @override
  String get whereLabel => 'أين';

  @override
  String get people => 'الأشخاص';

  @override
  String peopleSummary(Object n) {
    return '$n بما فيهم أنت';
  }

  @override
  String get addATitle => 'أضف عنوان';

  @override
  String keepItToLetters(Object n) {
    return 'لا يتجاوز $n حرفا أو رمزا';
  }

  @override
  String get useLettersOnly =>
      'يجب أن يتكون اسم النشاط من حروف وأرقام ومسافات ورمز & وفواصل وعلامة اقتباس فقط';

  @override
  String get useEnglishLettersOnly => 'حروف إنجليزية فقط';

  @override
  String keepItToCharacters(Object n) {
    return 'لا يتجاوز $n حرف';
  }

  @override
  String get chooseALocation => 'اختر الموقع';

  @override
  String get pickADate => 'اختر التاريخ';

  @override
  String get chooseADateWithinTheNext => 'اختر تاريخ خلال 3 أشهر';

  @override
  String get thisTimeHasAlreadyPassed => 'هذا الوقت مضى';

  @override
  String get youAlreadyHaveAnActivityAtThisTime =>
      'يتعارض هذا الوقت مع نشاط آخر من أنشطتك، اختر تاريخا أو وقتا مختلفا';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get noNotificationsYet => 'لا شيء بعد';

  @override
  String get noNotificationsHint =>
      'انضم إلى نشاط أو أنشئ نشاطا لتصلك التحديثات هنا';

  @override
  String get couldntLoadNotifications =>
      'تعذر تحميل الإشعارات، اسحب للأسفل للمحاولة مجددا';

  @override
  String notifWaitlistPromotion(String title) {
    return 'توفر مكان، تم انضمامك إلى $title';
  }

  @override
  String notifActivityUpdated(String title) {
    return 'تم تحديث $title، اطلع على التفاصيل الجديدة';
  }

  @override
  String notifActivityDeleted(String title) {
    return 'ألغى المضيف $title';
  }

  @override
  String notifRequestAccepted(String title) {
    return 'تم قبول طلبك للانضمام إلى $title';
  }

  @override
  String notifRequestRejected(String title) {
    return 'تم رفض طلبك للانضمام إلى $title';
  }

  @override
  String notifRequestReceived(String title) {
    return 'طلب شخص الانضمام إلى $title، اضغط للمراجعة';
  }

  @override
  String notifActivityFull(String title) {
    return 'اكتمل عدد المشاركين في $title!';
  }

  @override
  String get friendRequestNotificationTitle => 'طلب صداقة جديد';

  @override
  String notifFriendRequestReceived(String name) {
    return 'أرسل إليك $name طلب صداقة';
  }

  @override
  String get friendRequestAcceptedNotificationTitle => 'تم قبول طلب الصداقة';

  @override
  String notifFriendRequestAccepted(String name) {
    return 'قبل $name طلب صداقتك، أصبحتما صديقين الآن';
  }

  @override
  String notifHostAssigned(String title) {
    return 'أصبحت مضيف $title';
  }

  @override
  String notifActivityConflict(String title) {
    return 'تغير موعد $title وأصبح يتعارض مع نشاط آخر، اضغط لحل التعارض';
  }

  @override
  String conflictJoinJoined(String title) {
    return 'يتعارض هذا النشاط مع $title الذي انضممت إليه، غادره أولا لتنضم إلى هذا النشاط';
  }

  @override
  String conflictJoinHosting(String title) {
    return 'يتعارض هذا النشاط مع $title الذي تستضيفه، غير موعده أو احذفه لتنضم إلى هذا النشاط';
  }

  @override
  String conflictCreateJoined(String title) {
    return 'يتعارض هذا الوقت مع $title الذي انضممت إليه، اختر وقتا آخر أو غادر ذلك النشاط';
  }

  @override
  String conflictCreateHosting(String title) {
    return 'يتعارض هذا الوقت مع $title الذي تستضيفه، اختر وقتا آخر';
  }

  @override
  String get conflictJoinUnknown =>
      'يتعارض هذا النشاط مع نشاط آخر انضممت إليه أو تستضيفه';

  @override
  String get serverParticipantHasConflict =>
      'لدى هذا المشارك نشاط آخر في نفس الوقت، اختر شخصا آخر';

  @override
  String get pleaseCompleteEveryStepBeforeCreating =>
      'أكمل كل الخطوات قبل الإنشاء';

  @override
  String get weCouldntCreateYourActivityPlease =>
      'تعذر إنشاء النشاط، حاول مرة أخرى';

  @override
  String get activityCreatedPhotoNotAdded =>
      'تم إنشاء النشاط لكن تعذرت إضافة الصورة';

  @override
  String get activityCreatedPhotoNotSaved =>
      'تم إنشاء النشاط لكن تعذر حفظ الصورة';

  @override
  String get couldntOpenYourPhotosPleaseTry => 'تعذر فتح الصور، حاول مرة أخرى';

  @override
  String get thatFileIsntAJpegOr => 'الملف ليس صورة JPEG أو PNG';

  @override
  String get thisImagesFileTypeAndIts =>
      'نوع الصورة لا يطابق محتواها، جرب صورة أخرى';

  @override
  String get theSelectedPlaceIsMissingIts =>
      'المكان المختار بدون عنوان أو إحداثيات';

  @override
  String placeSearchFailed(Object code) {
    return 'فشل البحث ($code)، حاول مرة أخرى';
  }

  @override
  String get couldNotReachPlaceSearchCheck =>
      'تعذر البحث، تحقق من اتصالك وحاول مرة أخرى';

  @override
  String get placeSearchReturnedAnUnexpectedResponse =>
      'نتيجة غير متوقعة من البحث';

  @override
  String get cannotCreateAnActivityWhileSigned => 'سجل دخولك لإنشاء نشاط';

  @override
  String get cannotDeleteAnActivityWhileSigned => 'سجل دخولك لحذف النشاط';

  @override
  String get theActivityWasNotFoundOr => 'النشاط غير موجود أو لا يمكن حذفه';

  @override
  String get myLocation => 'موقعي';

  @override
  String get searchActivitiesOrPlaces => 'ابحث عن نشاط أو مكان';

  @override
  String get zoomIn => 'تكبير';

  @override
  String get zoomOut => 'تصغير';

  @override
  String spotsLeft(int n) {
    return 'متبقي $n';
  }

  @override
  String get pleaseEnableLocationServicesToFind =>
      'فعل خدمات الموقع لرؤية الأنشطة القريبة';

  @override
  String get locationPermissionWasDenied => 'تم رفض إذن الموقع';

  @override
  String get locationPermissionIsPermanentlyDeniedPlease =>
      'فعل الموقع من إعدادات الجهاز لعرض الأنشطة القريبة منك';

  @override
  String get unableToRetrieveYourLocationShowing =>
      'تعذر تحديد موقعك، نعرض الرياض';

  @override
  String get addAShortBioSoPeople => 'أضف نبذة قصيرة ليتعرف عليك الآخرون';

  @override
  String get unableToSaveBioPleaseTry => 'تعذر حفظ النبذة، حاول مرة أخرى';

  @override
  String get activityType => 'نوع النشاط';

  @override
  String get preferredLocation => 'الموقع المفضل';

  @override
  String ageYears(Object age) {
    return '$age سنة';
  }

  @override
  String get friends => 'الأصدقاء';

  @override
  String get rating => 'التقييم';

  @override
  String streakWeeksInARow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أسبوعا متتاليا',
      few: 'أسابيع متتالية',
      two: 'أسبوعان متتاليان',
      one: 'أسبوع متتالي',
      zero: 'أسبوع متتالي',
    );
    return '$_temp0';
  }

  @override
  String streakBest(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'الأفضل: $count أسبوعا',
      few: 'الأفضل: $count أسابيع',
      two: 'الأفضل: أسبوعان',
      one: 'الأفضل: أسبوع',
      zero: 'الأفضل: 0',
    );
    return '$_temp0';
  }

  @override
  String streakDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'باقي $count يوما',
      few: 'باقي $count أيام',
      two: 'باقي يومان',
      one: 'آخر يوم',
    );
    return '$_temp0';
  }

  @override
  String get streakKeptThisWeek => 'حلو، خلصت هذا الأسبوع. نشوفك الأسبوع الجاي';

  @override
  String get streakKeepGoing => 'نشاط واحد هذا الأسبوع وتكمل';

  @override
  String get streakStart => 'انضم لنشاط واحد هذا الأسبوع وتبدأ';

  @override
  String get streakTitle => 'السلسلة الأسبوعية';

  @override
  String get streakThisWeek => 'هذا الأسبوع';

  @override
  String get streakLastWeek => 'الأسبوع الماضي';

  @override
  String get streakEarlierWeek => 'الأسبوع السابق';

  @override
  String get streakLaterWeek => 'الأسبوع التالي';

  @override
  String get interests => 'الاهتمامات';

  @override
  String get preferences => 'التفضيلات';

  @override
  String get about => 'نبذة';

  @override
  String get addInterestsSoPeopleGetTo => 'أضف اهتماماتك ليعرف الآخرون ما تحب';

  @override
  String get editProfile => 'تعديل الحساب';

  @override
  String get tapToChangePhoto => 'اضغط لتغيير الصورة';

  @override
  String get profileHeader => 'الغلاف';

  @override
  String get synkColors => 'ألوان Synk';

  @override
  String get moreColors => 'ألوان أخرى';

  @override
  String get headerPhoto => 'صورة';

  @override
  String get couldntUploadYourHeaderPhoto => 'تعذر رفع صورة الغلاف، حاول مجددا';

  @override
  String get name => 'الاسم';

  @override
  String get yourName => 'اسمك';

  @override
  String get bio => 'نبذة';

  @override
  String get tellPeopleABitAboutYourself => 'عرف الآخرين بنفسك...';

  @override
  String get birthdayHint => 'يوم/شهر/سنة';

  @override
  String get selectBirthday => 'اختر تاريخ الميلاد';

  @override
  String get setBirthday => 'تحديد تاريخ الميلاد';

  @override
  String get selectYourBirthday => 'اختر تاريخ ميلادك';

  @override
  String get editAge => 'تعديل العمر';

  @override
  String awaitingConfirmationOn(Object email) {
    return 'لم يتم تأكيد $email بعد';
  }

  @override
  String get changePassword => 'تغيير كلمة المرور';

  @override
  String get pleaseEnterYourName => 'أدخل اسمك';

  @override
  String get adultMustBeBetween16And => 'العمر يجب أن يكون بين 16 و 65 سنة';

  @override
  String get profileEmailRequired => 'أدخل بريدك الإلكتروني';

  @override
  String get yourChangesHaveBeenSavedCheck =>
      'تم حفظ التغييرات، تحقق من بريدك الجديد لتأكيد التغيير';

  @override
  String get unableToSaveYourChangesPlease =>
      'تعذر حفظ التغييرات، حاول مرة أخرى';

  @override
  String get profileUsernameRequired => 'أدخل اسم المستخدم';

  @override
  String get usernameMustBe330Characters =>
      'اسم المستخدم من 3 إلى 30 حرف ويحتوي على حروف وأرقام و . و _ فقط';

  @override
  String get thisUsernameIsAlreadyTaken => 'اسم المستخدم محجوز';

  @override
  String get usernameCannotBeEmpty => 'اسم المستخدم مطلوب';

  @override
  String get profileEmailInvalid => 'أدخل بريد إلكتروني صحيح';

  @override
  String get profilePhoto => 'صورة الحساب';

  @override
  String get addPhoto => 'إضافة صورة';

  @override
  String get adjustPhoto => 'تعديل الصورة';

  @override
  String get moveAndScale => 'تحريك وتكبير';

  @override
  String get unableToUpdateYourPhotoPlease =>
      'تعذر تحديث الصورة، حاول مرة أخرى';

  @override
  String get couldntLoadYourPhotoPleaseTry =>
      'تعذر تحميل الصورة، حاول مرة أخرى';

  @override
  String get unableToAdjustYourPhotoPlease =>
      'تعذر تعديل الصورة، حاول مرة أخرى';

  @override
  String get unableToRemoveYourPhotoPlease => 'تعذر حذف الصورة، حاول مرة أخرى';

  @override
  String get yourPhotoWasntSavedBecauseYoure =>
      'لم تحفظ الصورة لأنك غير مسجل الدخول';

  @override
  String get savedOnThisDeviceCloudPhoto => 'محفوظة على هذا الجهاز فقط';

  @override
  String get editInterests => 'تعديل الاهتمامات';

  @override
  String get yourInterests => 'اهتماماتك';

  @override
  String get tapAnInterestBelowToAdd => 'اضغط على اهتمام لإضافته';

  @override
  String get addMore => 'إضافة المزيد';

  @override
  String get youveAddedEveryInterest => 'أضفت كل الاهتمامات';

  @override
  String get unableToSavePleaseTryAgain => 'تعذر الحفظ، حاول مرة أخرى';

  @override
  String get changePasswordTitle => 'تغيير كلمة المرور';

  @override
  String get currentPassword => 'كلمة المرور الحالية';

  @override
  String get enterYourCurrentPassword => 'أدخل كلمة المرور الحالية';

  @override
  String get enterANewPassword => 'أدخل كلمة مرور جديدة';

  @override
  String get confirmNewPassword => 'تأكيد كلمة المرور الجديدة';

  @override
  String get reEnterTheNewPassword => 'أعد إدخال كلمة المرور الجديدة';

  @override
  String get newPasswordMustBeDifferentFrom =>
      'يجب أن تختلف كلمة المرور الجديدة عن الحالية';

  @override
  String get pleaseConfirmYourNewPassword => 'أكد كلمة المرور الجديدة';

  @override
  String get passwordsDoNotMatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get currentPasswordIsIncorrect => 'كلمة المرور الحالية غير صحيحة';

  @override
  String get passwordIsTooWeakPleaseChoose =>
      'كلمة المرور ضعيفة، اختر كلمة أقوى';

  @override
  String get yourSessionHasExpiredPleaseLog =>
      'انتهت الجلسة، سجل دخولك مرة أخرى';

  @override
  String get couldntUpdateYourPasswordPleaseTry =>
      'تعذر تحديث كلمة المرور، حاول مرة أخرى';

  @override
  String get couldntUpdateYourPasswordCheckYour =>
      'تعذر تحديث كلمة المرور، تحقق من اتصالك وحاول مرة أخرى';

  @override
  String get changeEmail => 'تغيير البريد';

  @override
  String get confirmYourNewEmail => 'أكد بريدك الجديد';

  @override
  String openTheLinkWeSentTo(Object email) {
    return 'افتح الرابط المرسل إلى $email';
  }

  @override
  String get cancelEmailChange => 'إلغاء التغيير';

  @override
  String get useADifferentEmailAddress => 'استخدام بريد آخر';

  @override
  String get pleaseEnterANewEmailAddress => 'أدخل بريد جديد';

  @override
  String get newEmailMustBeDifferentFrom =>
      'يجب أن يختلف البريد الجديد عن الحالي';

  @override
  String get enterNewEmailAddress => 'البريد الجديد';

  @override
  String get weWillSendALinkToConfirm => 'سنرسل رابط لتأكيده';

  @override
  String get sendLink => 'إرسال الرابط';

  @override
  String get linkSentCheckYourNewEmail =>
      'تم إرسال الرابط، تحقق من بريدك الجديد';

  @override
  String get unableToUpdateEmailPleaseTry => 'تعذر تحديث البريد، حاول مرة أخرى';

  @override
  String get linkSentAgain => 'أعدنا إرسال الرابط';

  @override
  String get pendingEmailChangeCancelled => 'تم إلغاء تغيير البريد';

  @override
  String get failedToCancelEmailChangeRequest => 'تعذر إلغاء تغيير البريد';

  @override
  String get logOut => 'تسجيل الخروج';

  @override
  String get logOutOfSynk => 'تسجيل الخروج من Synk؟';

  @override
  String get youllNeedToSignInAgain =>
      'ستحتاج لتسجيل الدخول مجددا للوصول إلى حسابك وأنشطتك';

  @override
  String get unableToLogOut => 'تعذر تسجيل الخروج';

  @override
  String get unableToLogOutPleaseTry => 'تعذر تسجيل الخروج، حاول مرة أخرى';

  @override
  String get noInternetConnectionCheckYourConnection =>
      'لا يوجد اتصال بالإنترنت';

  @override
  String get tooManyAttemptsPleaseWaitA =>
      'تجاوزت عدد المحاولات المسموح، انتظر بضع دقائق ثم حاول مرة أخرى';

  @override
  String get somethingWentWrongPleaseTryAgain => 'حدث خطأ، حاول مرة أخرى';

  @override
  String get somethingWentWrong => 'حدث خطأ';

  @override
  String get unableToTransferHostingPleaseTry =>
      'تعذر نقل التنظيم، حاول مرة أخرى';

  @override
  String get unableToLeaveTheActivityPlease =>
      'تعذرت مغادرة النشاط، حاول مرة أخرى';

  @override
  String get waitlistPromotions => 'تحديثات قائمة الانتظار';

  @override
  String get updatesWhenASpotOpensIn =>
      'تنبيه عند توفر مكان في نشاط أنت بانتظاره';

  @override
  String get youreIn => 'تم قبولك! 🎉';

  @override
  String get aSpotOpenedUpInYour => 'توفر لك مكان في النشاط';

  @override
  String get interestOpenToAnything => 'أي شيء';

  @override
  String get interestPadel => 'بادل';

  @override
  String get interestTennis => 'تنس';

  @override
  String get interestBadminton => 'ريشة طائرة';

  @override
  String get interestTableTennis => 'تنس الطاولة';

  @override
  String get interestFootball => 'كرة القدم';

  @override
  String get interestBasketball => 'كرة السلة';

  @override
  String get interestVolleyball => 'كرة الطائرة';

  @override
  String get interestGolf => 'غولف';

  @override
  String get interestBowling => 'بولينغ';

  @override
  String get interestKarting => 'كارتينغ';

  @override
  String get interestMartialArts => 'فنون قتالية';

  @override
  String get interestPaintball => 'بينت بول';

  @override
  String get interestCycling => 'دراجات';

  @override
  String get interestRunning => 'جري';

  @override
  String get interestHiking => 'هايكنغ';

  @override
  String get interestClimbing => 'تسلق';

  @override
  String get interestCamping => 'تخييم';

  @override
  String get interestDesertTrips => 'رحلات برية';

  @override
  String get interestRoadTrips => 'رحلات بالسيارة';

  @override
  String get interestBeach => 'شاطئ';

  @override
  String get interestPicnic => 'نزهة';

  @override
  String get interestPicnics => 'نزهات';

  @override
  String get interestTravel => 'سفر';

  @override
  String get interestFitness => 'لياقة';

  @override
  String get interestYoga => 'يوغا';

  @override
  String get interestSwimming => 'سباحة';

  @override
  String get interestDiving => 'غوص';

  @override
  String get interestSkating => 'تزلج';

  @override
  String get interestDance => 'رقص';

  @override
  String get interestCoffee => 'قهوة';

  @override
  String get interestCooking => 'طبخ';

  @override
  String get interestFood => 'أكل';

  @override
  String get interestShopping => 'تسوق';

  @override
  String get interestBoardGames => 'ألعاب لوحية';

  @override
  String get interestCardGames => 'ألعاب ورق';

  @override
  String get interestChess => 'شطرنج';

  @override
  String get interestEscapeRoom => 'غرفة الهروب';

  @override
  String get interestTrivia => 'مسابقات';

  @override
  String get interestGaming => 'ألعاب فيديو';

  @override
  String get interestMovies => 'أفلام';

  @override
  String get interestComedy => 'كوميديا';

  @override
  String get interestKaraoke => 'كاريوكي';

  @override
  String get interestMusic => 'موسيقى';

  @override
  String get interestArt => 'فن';

  @override
  String get interestPottery => 'فخار';

  @override
  String get interestMuseums => 'متاحف';

  @override
  String get interestBooks => 'كتب';

  @override
  String get interestPhotography => 'تصوير';

  @override
  String get interestLearning => 'تعلم';

  @override
  String get interestVolunteering => 'تطوع';

  @override
  String get interestPets => 'حيوانات أليفة';

  @override
  String get interestOther => 'أخرى';

  @override
  String get weekdayMon => 'الإثنين';

  @override
  String get weekdayTue => 'الثلاثاء';

  @override
  String get weekdayWed => 'الأربعاء';

  @override
  String get weekdayThu => 'الخميس';

  @override
  String get weekdayFri => 'الجمعة';

  @override
  String get weekdaySat => 'السبت';

  @override
  String get weekdaySun => 'الأحد';

  @override
  String get monthJanuary => 'يناير';

  @override
  String get monthFebruary => 'فبراير';

  @override
  String get monthMarch => 'مارس';

  @override
  String get monthApril => 'أبريل';

  @override
  String get monthMay => 'مايو';

  @override
  String get monthJune => 'يونيو';

  @override
  String get monthJuly => 'يوليو';

  @override
  String get monthAugust => 'أغسطس';

  @override
  String get monthSeptember => 'سبتمبر';

  @override
  String get monthOctober => 'أكتوبر';

  @override
  String get monthNovember => 'نوفمبر';

  @override
  String get monthDecember => 'ديسمبر';

  @override
  String get timeAm => 'ص';

  @override
  String get timePm => 'م';

  @override
  String get monthShortJan => 'يناير';

  @override
  String get monthShortFeb => 'فبراير';

  @override
  String get monthShortMar => 'مارس';

  @override
  String get monthShortApr => 'أبريل';

  @override
  String get monthShortMay => 'مايو';

  @override
  String get monthShortJun => 'يونيو';

  @override
  String get monthShortJul => 'يوليو';

  @override
  String get monthShortAug => 'أغسطس';

  @override
  String get monthShortSep => 'سبتمبر';

  @override
  String get monthShortOct => 'أكتوبر';

  @override
  String get monthShortNov => 'نوفمبر';

  @override
  String get monthShortDec => 'ديسمبر';

  @override
  String shortDate(Object weekday, Object month, Object day) {
    return '$weekday، $day $month';
  }

  @override
  String monthDay(Object month, Object day) {
    return '$day $month';
  }

  @override
  String timeOfDay(Object time, Object period) {
    return '$time $period';
  }

  @override
  String distanceKm(Object n) {
    return '$n كم';
  }

  @override
  String get weekdayLetterMon => 'ن';

  @override
  String get weekdayLetterTue => 'ث';

  @override
  String get weekdayLetterWed => 'ر';

  @override
  String get weekdayLetterThu => 'خ';

  @override
  String get weekdayLetterFri => 'ج';

  @override
  String get weekdayLetterSat => 'س';

  @override
  String get weekdayLetterSun => 'ح';

  @override
  String longDate(Object weekday, Object month, Object day, Object year) {
    return '$weekday، $day $month $year';
  }

  @override
  String get timeChipPick => 'اختر';

  @override
  String get timeChipATime => 'الوقت';

  @override
  String get timeChipFrom => 'من';

  @override
  String planCount(int n) {
    return 'الخطط: $n';
  }

  @override
  String get noPlans => 'لا توجد خطط';

  @override
  String onDate(Object date) {
    return 'يوم $date';
  }

  @override
  String get serverNoActivityWithCode => 'لا يوجد نشاط بهذا الرمز';

  @override
  String get serverYouAreTheHost => 'أنت منظم هذا النشاط';

  @override
  String get serverAlreadyJoined => 'انضممت لهذا النشاط مسبقا';

  @override
  String get serverRequestWaiting => 'طلبك بانتظار موافقة المنظم';

  @override
  String get serverRequestRejected => 'رفض المنظم طلبك';

  @override
  String get serverRequestSent => 'تم إرسال طلبك للمنظم';

  @override
  String get serverFullAddedToWaitlist =>
      'النشاط ممتلئ، تمت إضافتك لقائمة الانتظار';

  @override
  String get serverRequestNotFound => 'طلب الانضمام غير موجود';

  @override
  String get serverOnlyHostCanReview => 'المنظم فقط يمكنه مراجعة هذا الطلب';

  @override
  String get serverPublicNoApproval => 'الأنشطة العامة لا تحتاج موافقة المنظم';

  @override
  String get serverAlreadyReviewed => 'تمت مراجعة هذا الطلب مسبقا';

  @override
  String get serverUserHasConflict =>
      'لدى هذا الشخص نشاط آخر في نفس الوقت، لذلك لا يمكن قبوله';

  @override
  String get serverActivityNotFound => 'النشاط غير موجود';

  @override
  String get serverActivityPrivate => 'هذا النشاط خاص، اطلب الرمز من المنظم';

  @override
  String get serverHostCannotLeave => 'المنظم لا يمكنه مغادرة نشاطه';

  @override
  String get serverActivityStarted => 'بدأ هذا النشاط';

  @override
  String get serverNotParticipating => 'لم تعد مشارك في هذا النشاط';

  @override
  String get serverOnlyHostCanTransfer => 'المنظم فقط يمكنه نقل التنظيم';

  @override
  String get serverChooseAnotherHost => 'اختر مشارك آخر ليصبح المنظم';

  @override
  String get serverParticipantLeft => 'المشارك المختار لم يعد في النشاط';

  @override
  String get serverLeftAndTransferred => 'غادرت النشاط ونقلت التنظيم';

  @override
  String get settings => 'الإعدادات';

  @override
  String get weCouldntSaveYourChanges => 'تعذر حفظ التغييرات، حاول مرة أخرى';

  @override
  String get changesSaved => 'تم حفظ التغييرات!';

  @override
  String get changesSavedBanner => 'تم حفظ التغييرات';

  @override
  String get yourActivityDetailsHaveBeenUpdated => 'تم تحديث تفاصيل نشاطك';

  @override
  String get editActivity => 'تعديل النشاط';

  @override
  String get replacePhoto => 'تغيير الصورة';

  @override
  String get uploadActivityPhoto => 'رفع صورة النشاط';

  @override
  String get photoCouldntBeDetached => 'تعذر إزالة الصورة من النشاط';

  @override
  String get photoDetachedFileNotRemoved =>
      'تمت إزالة الصورة من النشاط لكن تعذر حذف ملفها';

  @override
  String get cannotUpdateActivitySignedOut => 'سجل دخولك لتعديل النشاط';

  @override
  String get activityNotFoundOrCannotUpdate =>
      'النشاط غير موجود أو لا يمكن تعديله';

  @override
  String get activityUpdates => 'تحديثات الأنشطة';

  @override
  String get updatesToActivitiesYouHaveJoined =>
      'تحديثات الأنشطة التي انضممت لها';

  @override
  String get activityUpdated => 'تم تحديث النشاط';

  @override
  String get anActivityYouJoinedHasNew => 'تغيرت تفاصيل نشاط انضممت له';

  @override
  String get findPeople => 'البحث عن أشخاص';

  @override
  String get searchFriends => 'ابحث في الأصدقاء';

  @override
  String get searchByNameOrUsername => 'ابحث بالاسم أو @اسم المستخدم';

  @override
  String get friendRequestsTab => 'الطلبات';

  @override
  String get receivedRequests => 'المستلمة';

  @override
  String get friendRequests => 'طلبات الصداقة';

  @override
  String get seeAll => 'عرض الكل';

  @override
  String get notificationsNew => 'جديد';

  @override
  String get notificationsEarlier => 'أقدم';

  @override
  String get delete => 'حذف';

  @override
  String get notificationDeleted => 'تم حذف الإشعار';

  @override
  String get loadMore => 'عرض المزيد';

  @override
  String get undo => 'تراجع';

  @override
  String get decline => 'رفض';

  @override
  String get requestAcceptedLabel => 'تم القبول';

  @override
  String get requestDeclinedLabel => 'تم الرفض';

  @override
  String hiName(Object name) {
    return 'أهلا، $name';
  }

  @override
  String get forYou => 'لك';

  @override
  String deckCounter(int n, int total) {
    return '$n من $total';
  }

  @override
  String get joinShort => 'انضم';

  @override
  String youJoinedTitle(Object title) {
    return 'انضممت إلى $title';
  }

  @override
  String spotsLeftShort(int n) {
    return 'متبقي $n';
  }

  @override
  String get seeAgain => 'شاهدها مجددا';

  @override
  String get nextActivity => 'النشاط التالي';

  @override
  String get previousActivity => 'النشاط السابق';

  @override
  String get explore => 'استكشف';

  @override
  String get recentSearches => 'عمليات البحث الأخيرة';

  @override
  String get removeRecentSearch => 'إزالة';

  @override
  String activitiesForQuery(int n, Object query) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n نشاط لـ \"$query\"',
      few: '$n أنشطة لـ \"$query\"',
      two: 'نشاطان لـ \"$query\"',
      one: 'نشاط واحد لـ \"$query\"',
    );
    return '$_temp0';
  }

  @override
  String get bestMatchForYou => 'الأنسب لك';

  @override
  String nothingForQueryYet(Object query) {
    return 'لا شيء لـ \"$query\" بعد';
  }

  @override
  String createQuery(Object query) {
    return 'أنشئ \"$query\"';
  }

  @override
  String get sentRequests => 'المرسلة';

  @override
  String get blockedUsers => 'المستخدمون المحظورون';

  @override
  String get addFriend => 'إضافة صديق';

  @override
  String get addShort => 'إضافة';

  @override
  String get acceptRequest => 'قبول الطلب';

  @override
  String get sentYouAFriendRequest => 'أرسل لك طلب صداقة';

  @override
  String get viewProfile => 'عرض الملف الشخصي';

  @override
  String get friendOptions => 'خيارات الصديق';

  @override
  String get moreOptions => 'خيارات أخرى';

  @override
  String get removeFriend => 'إزالة الصديق';

  @override
  String removeFriendTitle(Object name) {
    return 'إزالة $name؟';
  }

  @override
  String removeFriendMessage(Object name) {
    return 'تقدر تضيف $name مرة ثانية لاحقا';
  }

  @override
  String get remove => 'إزالة';

  @override
  String blockName(Object name) {
    return 'حظر $name';
  }

  @override
  String blockUserTitle(Object name) {
    return 'حظر $name؟';
  }

  @override
  String get blockUserMessage => 'لن يجدك أو يضيفك، ولن يعرف بذلك';

  @override
  String get blockHostMessage => 'حظر هذا المضيف سيزيلك من نشاطه';

  @override
  String get block => 'حظر';

  @override
  String get unblock => 'إلغاء الحظر';

  @override
  String reportName(Object name) {
    return 'الإبلاغ عن $name';
  }

  @override
  String get reportTitle => 'إبلاغ';

  @override
  String reportWhyName(Object name) {
    return 'لماذا تبلغ عن $name؟';
  }

  @override
  String get back => 'رجوع';

  @override
  String reportUserMessage(Object name) {
    return 'لن يعرف $name أنك أبلغت عنه';
  }

  @override
  String get reportReasonHarassment => 'تحرش أو تنمر';

  @override
  String get reportReasonSpam => 'رسائل مزعجة';

  @override
  String get reportReasonFakeProfile => 'حساب مزيف';

  @override
  String get reportReasonInappropriateContent => 'محتوى غير لائق';

  @override
  String get reportReasonOther => 'سبب آخر';

  @override
  String get reportDetailsHint =>
      'أضف أي تفاصيل تساعدنا في مراجعة البلاغ، هذا اختياري';

  @override
  String get reportDetailsRequiredHint => 'أخبرنا بما حدث';

  @override
  String reportAndBlockName(Object name) {
    return 'إرسال البلاغ وحظر $name';
  }

  @override
  String get submitReport => 'إرسال البلاغ';

  @override
  String get reportSent => 'تم إرسال البلاغ';

  @override
  String reportedAndBlockedName(Object name) {
    return 'تم الإبلاغ عن $name وحظره';
  }

  @override
  String alreadyReportedName(Object name) {
    return 'سبق أن أبلغت عن $name';
  }

  @override
  String get reportActivity => 'الإبلاغ عن النشاط';

  @override
  String get reportActivityWhy => 'لماذا تبلغ عن هذا النشاط؟';

  @override
  String get reportActivityMessage => 'لن يعرف المنظم أنك أبلغت عنه';

  @override
  String get reportReasonMisleading => 'مزيف أو مضلل';

  @override
  String get alreadyReportedActivity => 'سبق أن أبلغت عن هذا النشاط';

  @override
  String get blockedUsersInfo =>
      'لا يمكن للمستخدمين المحظورين العثور عليك أو إرسال طلبات صداقة لك، ولا يتم إشعارهم بالحظر';

  @override
  String get noBlockedUsers => 'لا يوجد مستخدمون محظورون';

  @override
  String get peopleYouBlockShowUpHere => 'سيظهر هنا الأشخاص الذين تحظرهم';

  @override
  String get noFriendsYet => 'لا يوجد أصدقاء بعد';

  @override
  String get findPeopleYouKnow => 'ابحث عن أشخاص تعرفهم وأضفهم كأصدقاء';

  @override
  String get noFriendRequests => 'لا توجد طلبات صداقة';

  @override
  String get newFriendRequestsShowUpHere => 'ستظهر طلبات الصداقة الجديدة هنا';

  @override
  String get noFriendsMatchYourSearch => 'لا يوجد أصدقاء يطابقون بحثك';

  @override
  String get noPeopleFound => 'لم يتم العثور على أشخاص';

  @override
  String get tryAnotherNameOrUsername => 'ابحث باسم آخر أو اسم مستخدم آخر';

  @override
  String get searchForPeopleOnSynk => 'ابحث عن أشخاص في Synk';

  @override
  String lookForQueryOnSynk(String query) {
    return 'ابحث عن \"$query\" في Synk';
  }

  @override
  String get friendRequestSent => 'تم إرسال طلب الصداقة';

  @override
  String get friendRequestCancelled => 'تم إلغاء طلب الصداقة';

  @override
  String youAreNowFriendsWith(Object name) {
    return 'أصبحت أنت و$name أصدقاء';
  }

  @override
  String get friendRequestRejected => 'تم رفض طلب الصداقة';

  @override
  String friendRemoved(Object name) {
    return 'تمت إزالة $name من أصدقائك';
  }

  @override
  String userBlocked(Object name) {
    return 'تم حظر $name';
  }

  @override
  String userUnblocked(Object name) {
    return 'تم إلغاء حظر $name';
  }

  @override
  String friendIsGoing(Object name) {
    return '$name مشارك';
  }

  @override
  String twoFriendsAreGoing(Object first, Object second) {
    return '$first و$second مشاركين';
  }

  @override
  String friendAndOthersAreGoing(Object name, int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n من أصدقائك',
      few: '$n أصدقاء آخرين',
      two: 'صديقان آخران',
      one: 'صديق آخر',
    );
    return '$name و$_temp0 مشاركين';
  }

  @override
  String get yourFriendsGroup => 'أصدقاؤك';

  @override
  String get othersGroup => 'الآخرون';

  @override
  String get chat => 'المحادثات';

  @override
  String get chats => 'المحادثات';

  @override
  String get catchUpWithFriends => 'تواصل مع أصدقائك!';

  @override
  String get activityChats => 'محادثات الأنشطة';

  @override
  String get searchChats => 'ابحث في المحادثات';

  @override
  String get newChat => 'محادثة جديدة';

  @override
  String membersCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n عضو',
      few: '$n أعضاء',
      two: 'عضوان',
      one: 'عضو واحد',
    );
    return '$_temp0';
  }

  @override
  String youSaid(Object message) {
    return 'أنت: $message';
  }

  @override
  String personSaid(Object name, Object message) {
    return '$name: $message';
  }

  @override
  String get noMessagesYet => 'لا توجد رسائل بعد';

  @override
  String get noChatsYet => 'لا توجد محادثات بعد';

  @override
  String get chatsShowUpHere => 'انضم إلى نشاط أو راسل صديقا لبدء المحادثة';

  @override
  String get noChatsMatchYourSearch => 'لا توجد محادثات تطابق بحثك';

  @override
  String get messageHint => 'رسالة';

  @override
  String get send => 'إرسال';

  @override
  String get messageNotSent => 'تعذر إرسال رسالتك';

  @override
  String noLongerFriendsWith(Object name) {
    return 'لم تعد أنت و$name أصدقاء';
  }

  @override
  String get canOnlyMessageFriends => 'يمكنك مراسلة أصدقائك فقط';

  @override
  String get couldntOpenChat => 'تعذر فتح هذه المحادثة';

  @override
  String get yesterday => 'أمس';

  @override
  String get messageAFriend => 'راسل صديقا';

  @override
  String get message => 'مراسلة';

  @override
  String get chatClosed => 'تم إغلاق هذه المحادثة';

  @override
  String get chatClosedActivityFinished => 'انتهى النشاط، لذلك أغلقت محادثته';

  @override
  String get listSeparator => '، ';

  @override
  String sayHiToName(Object name) {
    return 'ألق التحية على $name';
  }

  @override
  String youBothLike(Object interests) {
    return 'كلاكما تحبان $interests!';
  }

  @override
  String listAnd(Object rest, Object last) {
    return '$rest و$last';
  }

  @override
  String planActivityTogether(Object title) {
    return 'خططوا معا لـ $title';
  }

  @override
  String get sortOutTheDetails =>
      'رحبوا ببعض واتفقوا على التفاصيل مع المشاركين';

  @override
  String get following => 'متابع';

  @override
  String get messageWasDeleted => 'تم حذف هذه الرسالة';

  @override
  String get deleteChat => 'حذف المحادثة';

  @override
  String get deleteThisChat => 'حذف هذه المحادثة؟';

  @override
  String get chatDeletedOnlyForYou => 'لديك فقط';

  @override
  String get chatDeleted => 'تم حذف المحادثة';

  @override
  String get deleteLabel => 'حذف';

  @override
  String get deleteForEveryone => 'حذف لدى الجميع';

  @override
  String get deleteForMe => 'حذف لدي';

  @override
  String get mute => 'كتم';

  @override
  String get unmute => 'إلغاء الكتم';

  @override
  String get muted => 'مكتومة';

  @override
  String get sendSomething => 'إرسال';

  @override
  String get sendLocation => 'موقع';

  @override
  String get sendActivity => 'نشاط';

  @override
  String get sendThisLocation => 'أرسل هذا الموقع';

  @override
  String get shareAnActivity => 'شارك نشاطا';

  @override
  String get noUpcomingActivitiesToShare => 'لا توجد أنشطة قادمة للمشاركة';

  @override
  String get joinOrCreateToShare => 'انضم إلى نشاط أو أنشئ واحدا، ثم شاركه هنا';

  @override
  String get activityNotVisibleToAll =>
      'بعض الأشخاص في هذه المحادثة لا يمكنهم رؤية هذا النشاط';

  @override
  String sharedActivityLabel(Object title) {
    return 'نشاط: $title';
  }

  @override
  String sharedLocationLabel(Object name) {
    return 'موقع: $name';
  }

  @override
  String get shareInChat => 'شارك في المحادثة';

  @override
  String sentTo(Object name) {
    return 'أرسل إلى $name';
  }

  @override
  String get sent => 'تم الإرسال';

  @override
  String rateActivityTitle(Object title) {
    return 'كيف كانت تجربتك في $title؟';
  }

  @override
  String get rateActivitySubtitle =>
      'قيم الأشخاص اللي شاركوك النشاط، التقييم اختياري ولن يعرفوا من قيمهم';

  @override
  String get tapToRate => 'اضغط لإضافة تقييم';

  @override
  String starsOutOfFive(Object stars) {
    return '$stars من 5 نجوم';
  }

  @override
  String get submitRatings => 'إرسال التقييم';

  @override
  String get ratingsSavedTitle => 'شكرا لتقييمك!';

  @override
  String get ratingsSavedMessage => 'تم حفظ تقييماتك بنجاح';

  @override
  String get ratingNotEnded => 'يمكنك التقييم بعد انتهاء النشاط';

  @override
  String get ratingNotEligible => 'يمكنك تقييم من شاركوك هذا النشاط فقط';

  @override
  String get ratingAlreadyRated => 'سبق أن قيمت هذا الشخص في هذا النشاط';

  @override
  String get ratingInvalid => 'اختر من 0.5 إلى 5 نجوم';

  @override
  String get ratingActivityUnavailable => 'هذا النشاط لم يعد متاحا';

  @override
  String get recentActivities => 'الأنشطة الأخيرة';

  @override
  String userActivitiesTitle(Object name) {
    return 'أنشطة $name';
  }

  @override
  String get noCompletedActivitiesYet => 'لا توجد أنشطة منتهية حتى الآن';

  @override
  String get couldNotLoadActivities => 'تعذر تحميل الأنشطة';

  @override
  String get privacy => 'الخصوصية';

  @override
  String get support => 'الدعم';

  @override
  String get aboutSynk => 'عن Synk';

  @override
  String get ourStory => 'قصتنا';

  @override
  String get ourStoryBody =>
      'بدأت Synk من فكرة بسيطة: أجمل العلاقات تبدأ غالبًا بشيء صغير. نشاط مشترك، أو اهتمام واحد، أو سبب للحضور. صمّمنا Synk لنجعل هذه الخطوة الأولى أسهل، حتى يصبح التعرّف على أشخاص جدد ومشاركة اللحظات الجميلة أمرًا طبيعيًا.';

  @override
  String get ourMission => 'رسالتنا';

  @override
  String get ourMissionBody =>
      'حوّل أي يوم إلى خطة. اكتشف نشاطًا ممتعًا، والتقِ بمن يشبهونك، واصنع لحظات تستحق أن تُحكى.';

  @override
  String get theTeam => 'تعرّف على الفريق';

  @override
  String get theTeamBody =>
      'يقف خلف Synk فريق من طلاب هندسة البرمجيات يجمعهم هدف واحد: أن يصبح التواصل الاجتماعي أسهل وأكثر معنى. بالتعاون والإبداع والكثير من الليالي الطويلة، عملنا معًا لنُخرج Synk إلى النور.';

  @override
  String get madeInRiyadh => 'صنع في الرياض';

  @override
  String appVersion(Object version, Object build) {
    return 'الإصدار $version ($build)';
  }

  @override
  String get notifPrefReminders => 'التذكيرات';

  @override
  String get notifPrefRemindersHint => 'قبل ساعة من نشاط انضممت إليه';

  @override
  String get notifPrefActivityUpdates => 'تحديثات الأنشطة';

  @override
  String get notifPrefActivityUpdatesHint =>
      'التغييرات والإلغاء واكتمال الأنشطة';

  @override
  String get notifPrefJoinRequests => 'طلبات الانضمام';

  @override
  String get notifPrefJoinRequestsHint => 'الطلبات الجديدة والردود على طلباتك';

  @override
  String get notifPrefWaitlist => 'قائمة الانتظار';

  @override
  String get notifPrefWaitlistHint => 'عندما يتوفر لك مكان';

  @override
  String get notifPrefPeople => 'الأشخاص';

  @override
  String get notifPrefFriendRequests => 'طلبات الصداقة';

  @override
  String get notifPrefFriendRequestsHint => 'الطلبات الجديدة والمقبولة';

  @override
  String get notifPrefChats => 'الرسائل';

  @override
  String get notifPrefChatsHint => 'الرسائل الجديدة في محادثاتك';

  @override
  String get notifPrefOther => 'أخرى';

  @override
  String get notifPrefMarketing => 'الأخبار والنصائح';

  @override
  String get notifPrefMarketingHint => 'ميزات جديدة وأفكار للتجربة';

  @override
  String get notifPrefIphone => 'آيفون';

  @override
  String get notifPrefNtfy => 'الإرسال إلى ntfy';

  @override
  String get notifPrefNtfyHint => 'تصلك إشعارات Synk عبر ntfy';

  @override
  String get notifPrefNtfyTopic => 'الموضوع الخاص بك';

  @override
  String get notifPrefNtfyCopied => 'تم نسخ الموضوع';

  @override
  String get ntfyPageTitle => 'إشعارات الآيفون';

  @override
  String get ntfyStepsTitle => 'طريقة التفعيل';

  @override
  String get ntfyStep1 => 'حمل ntfy من App Store';

  @override
  String get ntfyStep2 => 'فعل الإرسال إلى ntfy في الأسفل';

  @override
  String get ntfyStep3 => 'اضغط على الموضوع لنسخه';

  @override
  String get ntfyStep4 => 'في ntfy، اضغط +، الصق الموضوع ثم اضغط Subscribe';

  @override
  String get ntfyGetApp => 'حمل ntfy';

  @override
  String get ntfyGetAppHint => 'مجاني على App Store';

  @override
  String get supportIntro =>
      'مشكلة، فكرة أو مجرد سلام. شخص حقيقي يقرأ كل رسالة';

  @override
  String get supportProblem => 'مشكلة';

  @override
  String get supportFeedback => 'فكرة';

  @override
  String get supportOther => 'أخرى';

  @override
  String supportReplyTo(Object email) {
    return 'سنرد عليك على $email';
  }

  @override
  String get supportSentTitle => 'وصلتنا رسالتك';

  @override
  String get supportSentMessage => 'راقب بريدك، سنرد قريبا';

  @override
  String get supportRateLimited => 'رسائل كثيرة ليوم واحد. حاول مرة أخرى غدا';

  @override
  String get account => 'الحساب';

  @override
  String get deleteAccount => 'حذف الحساب';

  @override
  String get deleteAccountIntro => 'حذف حسابك يزيل كل ما يرتبط به:';

  @override
  String get deleteAccountItemProfile => 'ملفك الشخصي وصورك واهتماماتك';

  @override
  String get deleteAccountItemActivities =>
      'الأنشطة التي تستضيفها ومشاركاتك في غيرها';

  @override
  String get deleteAccountItemChats => 'محادثاتك ورسائلك';

  @override
  String get deleteAccountItemFriends => 'الأصدقاء والتقييمات وقائمة الحظر';

  @override
  String get deleteAccountCantUndo => 'لا يمكن التراجع عن ذلك';

  @override
  String get enterPasswordToContinue => 'أدخل كلمة المرور للمتابعة';

  @override
  String get deleteAccountConfirmTitle => 'حذف حسابك؟';

  @override
  String get deleteAccountConfirmMessage => 'سيتم حذف كل شيء نهائيا';

  @override
  String get keepAccount => 'الإبقاء على حسابي';

  @override
  String get couldNotDeleteAccount => 'تعذر حذف حسابك، حاول مرة أخرى';

  @override
  String get weather => 'الطقس';

  @override
  String get loadingForecast => 'جار تحميل التوقعات…';

  @override
  String get forecastTooFarAhead => 'تظهر التوقعات قبل الموعد بأسبوعين تقريبا';

  @override
  String get weatherUnavailable => 'الطقس غير متاح حاليا';

  @override
  String rainChance(int percent) {
    return 'احتمال مطر $percent%';
  }

  @override
  String windSpeed(int speed) {
    return 'رياح $speed كم/س';
  }

  @override
  String get weatherFog => 'ضباب';

  @override
  String get weatherDrizzle => 'رذاذ';

  @override
  String get weatherRain => 'مطر';

  @override
  String get weatherSnow => 'ثلج';

  @override
  String get weatherStorm => 'عاصفة رعدية';

  @override
  String get notificationSettings => 'إعدادات الإشعارات';

  @override
  String notifActivityReminder(Object title) {
    return 'يبدأ $title خلال ساعة';
  }

  @override
  String get supportTitle => 'كلنا آذان صاغية';

  @override
  String get reply => 'رد';

  @override
  String get copy => 'نسخ';

  @override
  String get messageCopied => 'تم النسخ';

  @override
  String replyingTo(Object name) {
    return 'رد على $name';
  }

  @override
  String get originalMessageUnavailable => 'الرسالة الأصلية';

  @override
  String get seen => 'تمت المشاهدة';

  @override
  String get seenByEveryone => 'شاهدها الجميع';

  @override
  String seenByCount(int count) {
    return 'شاهدها $count';
  }

  @override
  String friendsOfName(Object name) {
    return 'أصدقاء $name';
  }

  @override
  String reviewsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تقييم',
      few: '$count تقييمات',
      two: 'تقييمان',
      one: 'تقييم واحد',
    );
    return '$_temp0';
  }

  @override
  String get couldntFindYourThing => 'ما لقيت اللي يناسبك؟';

  @override
  String get rateActivityFun => 'اعط ربعك نجوم';

  @override
  String get ratingsSentToast => 'شكرا! وصلت تقييماتك';

  @override
  String get ntfyIphoneOnly => 'لمستخدمي الآيفون فقط';

  @override
  String get supportSubtitle => 'نقرأ كل رسالة';

  @override
  String get supportBugHint => 'وش المشكلة؟';

  @override
  String get supportIdeaHint => 'وش ودك تشوف؟';

  @override
  String get supportOtherHint => 'قل أي شيء، كبير أو صغير';

  @override
  String get supportAddScreenshot => 'أضف لقطة شاشة (اختياري)';

  @override
  String get supportChange => 'تغيير';

  @override
  String get supportChangeEmailTitle => 'وين نرد عليك؟';

  @override
  String get supportInvalidEmail => 'أدخل بريدا صحيحا';

  @override
  String get supportThanksTitle => 'شكرا! وصلتنا';

  @override
  String get supportThanksMessage => 'بنرد عليك على بريدك';

  @override
  String get backToHome => 'العودة للرئيسية';

  @override
  String get shareLink => 'مشاركة الرابط';

  @override
  String shareLinkMessage(Object title, Object date, Object link) {
    return 'تبي تنضم لنا في $title؟\n📅 $date\n\n$link';
  }

  @override
  String get filter => 'فلتر';

  @override
  String get role => 'الدور';

  @override
  String get thisWeek => 'هذا الأسبوع';

  @override
  String shareLinkCodeMessage(
    Object title,
    Object date,
    Object link,
    Object code,
  ) {
    return 'تبي تنضم لنا في $title؟\n📅 $date\n\n$link\n\nأو اكتب الرمز في Synk: $code';
  }

  @override
  String friendsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صديق',
      many: '$count صديقا',
      few: '$count أصدقاء',
      two: 'صديقان',
      one: 'صديق واحد',
      zero: '0 أصدقاء',
    );
    return '$_temp0';
  }

  @override
  String get blockedTag => 'محظور';

  @override
  String get thisActivityIsUnavailable => 'هذا النشاط غير متاح';

  @override
  String get thisProfileIsUnavailable => 'هذا الملف الشخصي غير متاح';

  @override
  String get rateMembers => 'قيم الأعضاء';

  @override
  String get openChat => 'افتح المحادثة';

  @override
  String get weatherClear => 'صافي';

  @override
  String get weatherPartlyCloudy => 'غائم جزئيا';

  @override
  String get weatherCloudy => 'غائم';

  @override
  String get feelsLike => 'الحرارة المحسوسة';

  @override
  String get chanceOfRain => 'احتمال المطر';

  @override
  String get wind => 'الرياح';

  @override
  String get humidity => 'الرطوبة';

  @override
  String kmPerHour(int speed) {
    return '$speed كم/س';
  }

  @override
  String get weatherTipStorm => 'الجو عاصف، انتبه لنفسك والبس المناسب';

  @override
  String get weatherTipRain => 'فيه مطر، لا تنسى المظلة!';

  @override
  String get weatherTipHot => 'حر شديد، اشرب ماء وخلك في الظل';

  @override
  String get weatherTipWarm => 'الجو دافئ، البس شي خفيف';

  @override
  String get weatherTipNice => 'الجو حلو، استمتع!';

  @override
  String get weatherTipCool => 'فيه برودة خفيفة، خذ معك جاكيت';

  @override
  String get weatherTipCold => 'الجو بارد، تدفى زين';

  @override
  String get yourRatings => 'تقييماتك';

  @override
  String get discard => 'تجاهل';

  @override
  String get leave => 'مغادرة';

  @override
  String get withdraw => 'سحب';

  @override
  String get withdrawRequestTitle => 'سحب طلبك؟';
}
