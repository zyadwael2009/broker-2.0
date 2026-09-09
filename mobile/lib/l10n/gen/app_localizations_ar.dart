// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppL10nAr extends AppL10n {
  AppL10nAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'وسيط';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get comingSoon => 'قريباً';

  @override
  String get loginHeroTitle => 'مرحباً بك في وسيط';

  @override
  String get loginHeroSubtitle =>
      'المنصة الأولى الموثقة للوساطة العقارية في مصر.';

  @override
  String get loginCredentialPill => 'اعتماد رسمي وسجل عقاري إلكتروني';

  @override
  String get loginPhoneHint => 'مربوط بالرقم القومي';

  @override
  String get loginAltDivider => 'أو المتابعة عبر';

  @override
  String get loginSsoDigitalEgypt => 'مصر الرقمية (النفاذ الوطني)';

  @override
  String get loginSsoDigitalEgyptSub => 'التحقق اللحظي عبر بطاقة الرقم القومي';

  @override
  String get loginOtpTitle => 'تسجيل سريع برمز التحقق (SMS OTP)';

  @override
  String get loginOtpSub => 'دخول بضغطة واحدة عبر التحقق من الهاتف';

  @override
  String get loginNoAccountPrompt => 'ليس لديك حساب؟';

  @override
  String get loginRegisterCta => 'إنشاء حساب جديد';

  @override
  String get loginTrustContracts => 'عقود رسمية';

  @override
  String get loginTrustContractsSub => 'موثقة ومطابقة للقانون';

  @override
  String get loginTrustInspect => 'معاينة فنية';

  @override
  String get loginTrustInspectSub => 'فحص ميداني دقيق';

  @override
  String get loginFooterTitle => 'ضمان الأمان والشرعية العقارية';

  @override
  String get loginFooterSub =>
      'جميع العقارات والوسطاء مفحوصون ومعتمدون رسمياً عبر هيئة السجل العقاري.';

  @override
  String get otpLoginTitle => 'دخول برمز التحقق';

  @override
  String get otpLoginComingSoon =>
      'دخول الرمز فقط بيوصل قريباً. استخدم الهاتف وكلمة المرور دلوقتي.';

  @override
  String get registerHeroPill => 'منظومة التسجيل العقاري الرقمي';

  @override
  String get registerHeroTitle => 'انضم إلى شبكة وسيط الموثقة';

  @override
  String get registerHeroSubtitle =>
      'اختر نوع حسابك للبدء في تصفح أو عرض العقارات المفحوصة والمطابقة للسجل العقاري.';

  @override
  String get registerAccountType => 'نوع الحساب';

  @override
  String registerStep(int current, int total) {
    return 'خطوة $current من $total';
  }

  @override
  String get registerRoleBrokerLicensed => 'وسيط معتمد';

  @override
  String get registerRoleBrokerLicenseChip => 'رخصة';

  @override
  String get registerTrustBannerTitle => 'ضمانة التحقق والشفافية';

  @override
  String get registerTrustBannerSub =>
      'حساب المشتري يتيح لك فحص حجية العقود والسجلات المساحية دون رسوم سمسرة خفية.';

  @override
  String get registerFullNameHint => '(كما في بطاقة الرقم القومي)';

  @override
  String get registerFullNameExample => 'مثال: أحمد عبد الله الشربيني';

  @override
  String get emailField => 'البريد الإلكتروني';

  @override
  String get registerEmailOptionalHint => 'اختياري';

  @override
  String get registerPasswordHint => '8+ أحرف ورموز';

  @override
  String get registerPasswordRule =>
      'يجب أن تشمل أرقاماً، أحرفاً كبيرة وصغيرة، ورمزاً خاصاً.';

  @override
  String get registerLinkRegistryTitle => 'ربط فوري بالسجل العيني';

  @override
  String get registerLinkRegistrySub => 'تدقيق إلكتروني مشفر للعقود المسجلة.';

  @override
  String get registerAgreeTerms =>
      'أوافق على شروط الخدمة وسياسة التحقق من الملكية العقارية وحماية البيانات.';

  @override
  String get registerMustAgreeTerms => 'اقبل الشروط أولاً عشان نكمل.';

  @override
  String get registerContinueCta => 'إنشاء الحساب والمتابعة';

  @override
  String get registerTrustEncrypted => 'بيانات مشفرة';

  @override
  String get registerTrustLicensed => 'ترخيص قانوني';

  @override
  String get registerTrustSupport => 'دعم مستمر 24/7';

  @override
  String get verifyPhoneIntro =>
      'تم إرسال رمز التحقق المكون من 6 أرقام إلى الرقم';

  @override
  String get verifyPhoneEditNumber => 'تعديل الرقم';

  @override
  String get verifyPhoneCodeSent => 'تم إرسال الرمز.';

  @override
  String verifyPhoneDigitsEntered(int n) {
    return 'تم إدخال $n من 6 أرقام';
  }

  @override
  String get verifyPhoneAutoDecrypt => 'مشفر تلقائياً';

  @override
  String get verifyPhoneResendInPrefix => 'إعادة إرسال الرمز خلال';

  @override
  String get verifyPhoneResendSms => 'إعادة الإرسال عبر رسالة نصية';

  @override
  String get verifyPhoneConfirmCta => 'تأكيد الرمز والمتابعة';

  @override
  String get verifyPhoneSecurityNote =>
      'وسيط يحمي بياناتك برمز تشفير آمن 256-bit.';

  @override
  String get createAccount => 'إنشاء حساب';

  @override
  String get fullName => 'الاسم الكامل';

  @override
  String get phone => 'رقم الهاتف';

  @override
  String get email => 'البريد الإلكتروني (اختياري)';

  @override
  String get password => 'كلمة المرور';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get deleteAccount => 'حذف الحساب';

  @override
  String get deleteAccountTitle => 'تحذف حسابك نهائياً؟';

  @override
  String get deleteAccountBody =>
      'هذا بيمسح حسابك للأبد وبيخفي إعلاناتك. مفيش تراجع. أدخل كلمة السر عشان نأكد.';

  @override
  String get deleteAccountConfirm => 'احذف نهائياً';

  @override
  String get deleteAccountDone => 'تم حذف حسابك.';

  @override
  String get refresh => 'تحديث';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get cancel => 'إلغاء';

  @override
  String get delete => 'حذف';

  @override
  String get remove => 'إزالة';

  @override
  String get save => 'حفظ';

  @override
  String get close => 'إغلاق';

  @override
  String get ok => 'حسناً';

  @override
  String get roleBuyer => 'مشتري / مستأجر';

  @override
  String get roleBroker => 'سمسار';

  @override
  String get loginPromptRegister => 'لا تملك حساباً؟ سجّل الآن';

  @override
  String get registerPromptLogin => 'لديك حساب بالفعل؟ سجّل الدخول';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get forgotPasswordTitle => 'إعادة تعيين كلمة المرور';

  @override
  String get forgotPasswordStep1Sub =>
      'أدخل رقم هاتف حسابك وسنرسل لك رمزاً من ٦ أرقام.';

  @override
  String get forgotPasswordStep2Sub =>
      'أدخل الرمز الذي أرسلناه إلى هاتفك مع كلمة مرور جديدة.';

  @override
  String get forgotPasswordSendCode => 'إرسال الرمز';

  @override
  String get forgotPasswordConfirmReset => 'إعادة تعيين كلمة المرور';

  @override
  String get forgotPasswordSuccess =>
      'تمت إعادة التعيين. سجّل الدخول بكلمة المرور الجديدة.';

  @override
  String get verifyPhoneTitle => 'توثيق رقم الهاتف';

  @override
  String verifyPhoneSub(String phone) {
    return 'أرسلنا رمزاً من ٦ أرقام إلى $phone. أدخله لتوثيق حسابك.';
  }

  @override
  String get verifyPhoneCodeLabel => 'رمز مكون من ٦ أرقام';

  @override
  String get verifyPhoneConfirm => 'توثيق';

  @override
  String get verifyPhoneResend => 'إعادة إرسال الرمز';

  @override
  String verifyPhoneResendIn(int seconds) {
    return 'إعادة الإرسال خلال $seconds ث';
  }

  @override
  String get verifyPhoneSkip => 'تخطي حالياً';

  @override
  String get verifyPhoneSuccess => 'تم توثيق رقم الهاتف.';

  @override
  String get verifyBannerText => 'وثّق رقم هاتفك لتأمين حسابك.';

  @override
  String get verifyBannerCta => 'توثيق';

  @override
  String get newPassword => 'كلمة المرور الجديدة';

  @override
  String get confirmPassword => 'تأكيد كلمة المرور';

  @override
  String get passwordsDoNotMatch => 'كلمتا المرور غير متطابقتين.';

  @override
  String get codeIncorrect => 'الرمز غير صحيح أو منتهي الصلاحية.';

  @override
  String get phoneRequired => 'من فضلك أدخل رقم هاتفك.';

  @override
  String get passwordMin8 => '٨ أحرف على الأقل';

  @override
  String get namePleaseEnter => 'من فضلك أدخل اسمك';

  @override
  String get phoneInvalid => 'رقم هاتف غير صالح';

  @override
  String get brokerDisclaimer =>
      'يبدأ السماسرة كغير موثّقين. قدّم إثبات تسجيلك في الهيئة العامة للاستعلامات (GOEIC) في الخطوة التالية ليراجعه أحد المسؤولين. فقط السماسرة الموثّقون تظهر شارة الثقة على قوائمهم.';

  @override
  String get themeSystem => 'المظهر: تلقائي';

  @override
  String get themeLight => 'المظهر: فاتح';

  @override
  String get themeDark => 'المظهر: داكن';

  @override
  String get languageEnglish => 'اللغة: English';

  @override
  String get languageArabic => 'اللغة: العربية';

  @override
  String get languageSystem => 'اللغة: تلقائي';

  @override
  String get verifyTitle => 'توثيقي';

  @override
  String get verifyMyStatus => 'توثيقي';

  @override
  String get verifyStatusVerifiedHeading => 'سمسار موثّق';

  @override
  String get verifyStatusPendingHeading => 'قيد المراجعة';

  @override
  String get verifyStatusRejectedHeading => 'تم رفض التقديم';

  @override
  String get verifyStatusPendingSub => 'سيراجع أحد المسؤولين تقديمك قريباً.';

  @override
  String get verifyStatusRejectedSub => 'حدّث مستندك وأعد تقديمه أدناه.';

  @override
  String verifyStatusVerifiedSubDated(String date) {
    return 'تم التوثيق بتاريخ $date. تظهر شارة التوثيق على قوائمك.';
  }

  @override
  String get verifyStatusVerifiedSubUndated => 'تظهر شارة التوثيق على قوائمك.';

  @override
  String get reviewerNote => 'ملاحظة المراجع';

  @override
  String get goeicField => 'رقم تسجيل GOEIC';

  @override
  String get goeicHint => 'مثال: EG-2024-08841';

  @override
  String get registrationDetails => 'بيانات التسجيل';

  @override
  String get updateRegistration => 'تحديث بيانات تسجيلك';

  @override
  String get chooseDocument => 'اختر مستند التسجيل';

  @override
  String get documentAllowed =>
      'PDF أو JPG أو PNG أو WEBP · الحد الأقصى ٢٠ ميجابايت';

  @override
  String tapToReplace(String size) {
    return '$size · اضغط للاستبدال';
  }

  @override
  String get resubmitDocuments => 'أعد تقديم المستندات';

  @override
  String get submitForReview => 'قدّم للمراجعة';

  @override
  String get submitNewDocuments => 'قدّم مستندات جديدة';

  @override
  String get required => 'مطلوب';

  @override
  String get verifyPickDocument => 'من فضلك اختر مستند التسجيل.';

  @override
  String get verifySubmitted => 'تم التقديم. سيراجع المسؤول قريباً.';

  @override
  String get verifySubmitFailed => 'فشل التقديم.';

  @override
  String get verifyHonestNote =>
      'التوثيق يؤكد أن فريقنا راجع تسجيلك في GOEIC، وهو لا يغني عن التحقق القانوني المستقل.';

  @override
  String get myListings => 'قوائمي';

  @override
  String get browseListings => 'تصفح القوائم';

  @override
  String get navBrowse => 'تصفح';

  @override
  String get navMyListings => 'عقاراتي';

  @override
  String get navSaved => 'المفضلة';

  @override
  String get navMessages => 'محادثات';

  @override
  String get navAccount => 'حسابي';

  @override
  String get navAdminQueue => 'الطلبات';

  @override
  String get savedEmptyTitle => 'مفيش عقارات محفوظة لسه.';

  @override
  String get savedEmptySub =>
      'اضغط على أيقونة القلب في أي إعلان عشان تحفظه هنا.';

  @override
  String get accountPreferences => 'التفضيلات';

  @override
  String get accountTheme => 'الوضع';

  @override
  String get accountLanguage => 'اللغة';

  @override
  String get accountActions => 'الحساب';

  @override
  String get newListing => 'قائمة جديدة';

  @override
  String get priceTransparency => 'شفافية الأسعار';

  @override
  String get unverifiedRejectedTitle => 'تم رفض تقديمك.';

  @override
  String get unverifiedNotYetTitle => 'يجب أن تكون موثّقاً لتنشر قوائم.';

  @override
  String get unverifiedRejectedSub =>
      'افتح شاشة التوثيق لمراجعة ملاحظة المراجع وأعد التقديم.';

  @override
  String get unverifiedNotYetSub =>
      'قدّم مستند تسجيلك في GOEIC ليراجعه فريقنا. فقط السماسرة الموثّقون يستطيعون نشر القوائم — هكذا يعرف المشترون أنه يمكنهم الوثوق بك.';

  @override
  String get openVerification => 'فتح شاشة التوثيق';

  @override
  String get noListingsYet => 'لا توجد قوائم بعد';

  @override
  String get noListingsHint => 'اضغط \"قائمة جديدة\" لنشر أول عقار لك.';

  @override
  String get listingTitle => 'العنوان';

  @override
  String get listingDescription => 'الوصف (اختياري)';

  @override
  String get listingPrice => 'السعر (جنيه)';

  @override
  String get listingArea => 'المساحة (م²)';

  @override
  String get listingPropertyType => 'نوع العقار';

  @override
  String get listingKindLabel => 'بيع أم إيجار';

  @override
  String get listingKindSale => 'للبيع';

  @override
  String get listingKindRent => 'للإيجار';

  @override
  String get listingBedrooms => 'الغرف';

  @override
  String get listingBathrooms => 'الحمامات';

  @override
  String get listingFloor => 'الدور';

  @override
  String get listingCompound => 'الكمبوند';

  @override
  String get listingCompoundHint => 'مثال: بالم هيلز، الرحاب';

  @override
  String get listingFurnishedLabel => 'مفروش';

  @override
  String get listingFurnishedYes => 'نعم';

  @override
  String get listingFurnishedNo => 'لا';

  @override
  String get listingFurnishedUnspecified => 'غير محدد';

  @override
  String get listingDeliveryLabel => 'حالة التسليم';

  @override
  String get listingDeliveryUnspecified => 'غير محدد';

  @override
  String get listingDeliveryReady => 'جاهز للسكن';

  @override
  String get listingDeliveryUnderConstruction => 'تحت الإنشاء';

  @override
  String get filtersLabel => 'الفلاتر';

  @override
  String get filterAnyGov => 'كل المحافظات';

  @override
  String get filterAnyCity => 'كل المدن';

  @override
  String get filterBedroomsAny => 'الكل';

  @override
  String get filterPriceMin => 'أقل سعر';

  @override
  String get filterPriceMax => 'أعلى سعر';

  @override
  String get filterApply => 'تطبيق';

  @override
  String get filterReset => 'مسح';

  @override
  String get shareWhatsApp => 'شارك عبر واتساب';

  @override
  String get whatsappOpenFailed => 'تعذّر فتح واتساب.';

  @override
  String get referralTitle => 'ادعُ وسطاء آخرين';

  @override
  String get referralShareText =>
      'انضم إلينا على وسيط — منصة الوسطاء العقاريين الموثّقين في مصر.';

  @override
  String get referralCopied => 'تم نسخ رابط الدعوة.';

  @override
  String referralJoinedCount(int count) {
    return 'انضم $count';
  }

  @override
  String get listingGovernorate => 'المحافظة';

  @override
  String get listingCity => 'المدينة';

  @override
  String get listingDistrict => 'الحي (اختياري)';

  @override
  String get listingLat => 'خط العرض';

  @override
  String get listingLng => 'خط الطول';

  @override
  String get useMyLocation => 'استخدم موقعي';

  @override
  String get photosLabel => 'الصور';

  @override
  String get locationLabel => 'الموقع';

  @override
  String get addPhoto => 'إضافة';

  @override
  String get publishListing => 'نشر القائمة';

  @override
  String get listingCreated => 'تم إنشاء القائمة.';

  @override
  String listingCreatedPartial(int uploaded, int total, String reason) {
    return 'تم إنشاء القائمة — لكن تم رفع $uploaded من $total صورة فقط ($reason).';
  }

  @override
  String createFailed(String reason) {
    return 'فشل الإنشاء: $reason';
  }

  @override
  String get atLeastOnePhoto => 'أضف صورة واحدة على الأقل للعقار.';

  @override
  String get coordsRequired => 'أضف الإحداثيات أو اضغط \"استخدم موقعي\".';

  @override
  String get titleMin3 => '٣ أحرف على الأقل';

  @override
  String get priceInvalid => 'أدخل سعراً صحيحاً';

  @override
  String get areaRequired => 'أدخل المساحة';

  @override
  String get duplicatePhotoNote =>
      'الصور المطابقة لقوائم أخرى قد تُرفع للمراجعة. ارفع صورك الخاصة للعقار الفعلي.';

  @override
  String get propertyApartment => 'شقة';

  @override
  String get propertyHouse => 'منزل';

  @override
  String get propertyVilla => 'فيلا';

  @override
  String get propertyLand => 'أرض';

  @override
  String get propertyCommercial => 'تجاري';

  @override
  String get statusVerified => 'موثّق';

  @override
  String get statusPending => 'قيد المراجعة';

  @override
  String get statusRejected => 'مرفوض';

  @override
  String get adminVerified => 'موثّق من الإدارة';

  @override
  String get awaitingReview => 'قيد المراجعة';

  @override
  String get selfReported => 'إقرار ذاتي';

  @override
  String get notProvided => 'غير مقدّم';

  @override
  String get priceLabel => 'السعر';

  @override
  String get areaLabel => 'المساحة';

  @override
  String get typeLabel => 'النوع';

  @override
  String get aboutLabel => 'الوصف';

  @override
  String get brokerLabel => 'السمسار';

  @override
  String get propertyDocuments => 'مستندات العقار';

  @override
  String get stillAvailable => 'لا يزال متاحاً';

  @override
  String get callBroker => 'اتصل بالسمسار';

  @override
  String get buyerCallDisclaimer =>
      'هذا التطبيق يساعد على التحقق. تأكد دائماً من الملكية وسند العقار مع محامٍ أو مكتب الشهر العقاري قبل دفع أي شيء.';

  @override
  String get confirmedStillAvailable => 'تم تأكيد التوفر.';

  @override
  String get confirmFailed => 'فشل التأكيد.';

  @override
  String get deleteListingTitle => 'حذف القائمة؟';

  @override
  String get deleteListingBody => 'لا يمكن التراجع عن هذا. ستُحذف الصور أيضاً.';

  @override
  String get deleteFailed => 'فشل الحذف.';

  @override
  String get noDialer => 'لا يوجد تطبيق اتصال متاح على هذا الجهاز.';

  @override
  String get dialerOpenFailed => 'تعذّر فتح تطبيق الاتصال.';

  @override
  String postedOn(String date) {
    return 'نُشرت بتاريخ $date';
  }

  @override
  String get postedRecently => 'نُشرت مؤخراً';

  @override
  String get docsTitleDeed => 'سند الملكية مسجّل في الشهر العقاري';

  @override
  String get docsNoLiens => 'خالٍ من الرهون والنزاعات';

  @override
  String get docsTaxClearance => 'براءة ذمة ضريبية';

  @override
  String get docsHonestNote =>
      'التوثيق يؤكد أن المسؤول عندنا راجع المستند — وهو لا يغني عن محامٍ أو مكتب الشهر العقاري. الإقرارات الذاتية ليس خلفها أي توثيق.';

  @override
  String get uploadProof => 'رفع الإثبات';

  @override
  String get replaceProof => 'استبدال مستند الإثبات';

  @override
  String get uploadProofSub => 'سيراجعه أحد المسؤولين قبل التوثيق.';

  @override
  String get iHaveThisNoProof => 'أملك هذا — بدون إثبات حالياً';

  @override
  String get iHaveThisNoProofSub =>
      'يظهر للمشترين كـ\"إقرار ذاتي من السمسار\".';

  @override
  String get docSubmitted => 'تم الرفع. سيراجعه المسؤول قريباً.';

  @override
  String get docSelfReported => 'تم التسجيل كإقرار ذاتي.';

  @override
  String get docCleared => 'تم المسح.';

  @override
  String get actionFailed => 'فشل الإجراء.';

  @override
  String get adminTitle => 'الإدارة';

  @override
  String get brokersTab => 'السماسرة';

  @override
  String get flaggedTab => 'المُبلَّغ عنها';

  @override
  String get docsTab => 'المستندات';

  @override
  String get filterPending => 'قيد المراجعة';

  @override
  String get filterVerified => 'موثّق';

  @override
  String get filterRejected => 'مرفوض';

  @override
  String get noPendingBrokers => 'لا يوجد سماسرة قيد المراجعة — الصندوق فارغ.';

  @override
  String get noVerifiedBrokers => 'لا يوجد سماسرة موثّقون بعد.';

  @override
  String get noRejectedBrokers => 'لا توجد تقديمات مرفوضة.';

  @override
  String get noFlagged => 'لا توجد قوائم مُبلَّغ عنها.';

  @override
  String get noPendingDocs => 'لا توجد مستندات للمراجعة.';

  @override
  String get rejectionReasonTitle => 'سبب الرفض';

  @override
  String get rejectionReasonHint => 'اشرح ما يحتاج للتصحيح — سيراه السمسار.';

  @override
  String get reject => 'رفض';

  @override
  String get approve => 'قبول';

  @override
  String get brokerVerified => 'تم توثيق السمسار.';

  @override
  String get brokerRejected => 'تم رفض السمسار.';

  @override
  String get documentVerified => 'تم توثيق المستند.';

  @override
  String get documentRejected => 'تم رفض المستند.';

  @override
  String get approveFailed => 'فشل القبول.';

  @override
  String get rejectFailed => 'فشل الرفض.';

  @override
  String get unflag => 'إزالة الإبلاغ';

  @override
  String get listingUnflagged => 'تم إزالة الإبلاغ عن القائمة.';

  @override
  String get unflagFailed => 'فشلت إزالة الإبلاغ.';

  @override
  String get goeicShort => 'رقم GOEIC';

  @override
  String get lastUpdate => 'آخر تحديث';

  @override
  String get previousRejectionReason => 'سبب الرفض السابق';

  @override
  String get registrationDocument => 'مستند التسجيل';

  @override
  String get tapToOpen => 'اضغط للفتح في العارض';

  @override
  String get brokerHasNotUploaded => 'لم يقم السمسار بالرفع بعد';

  @override
  String get noDocumentSubmitted => 'لم يتم تقديم مستند';

  @override
  String couldNotOpenDocument(String reason) {
    return 'تعذّر فتح المستند: $reason';
  }

  @override
  String get duplicateSuspected => 'مشتبه بأنها مكررة';

  @override
  String duplicateOf(int id) {
    return 'مكررة من #$id';
  }

  @override
  String get view => 'عرض';

  @override
  String submittedRelative(String when) {
    return 'قُدّمت $when';
  }

  @override
  String get medianPricePerM2 => 'متوسط السعر / م²';

  @override
  String get rangeLabel => 'المدى';

  @override
  String get middle50Label => 'الوسط ٥٠٪';

  @override
  String get listingsLabel => 'القوائم';

  @override
  String get notEnoughListings => 'لا توجد قوائم كافية تطابق هذه الفلاتر.';

  @override
  String get medianTrendTitle => 'اتجاه المتوسط — آخر ١٢ شهراً';

  @override
  String get notEnoughMonthly =>
      'لا توجد بيانات شهرية كافية بعد — نحتاج شهرين على الأقل بقائمتين لكل منهما.';

  @override
  String get marketHonest =>
      'أسعار المطلوب من سماسرة موثّقين على هذا التطبيق، بالإضافة إلى القوائم المباعة عند التبليغ. هذه إشارة سوقية، وليست خدمة تقييم — تأكد دائماً بتقييم مهني قبل الالتزام.';

  @override
  String get all => 'الكل';

  @override
  String get filterAll => 'الكل';

  @override
  String get expiryExpired => 'منتهية · اضغط لإعادة التأكيد';

  @override
  String expiryDaysLeft(int days) {
    return 'تنتهي خلال $days يوماً';
  }

  @override
  String expiryActive(int days) {
    return 'نشطة · متبقٍ $days يوماً';
  }

  @override
  String get emptyBrowseTitle => 'لا توجد قوائم مطابقة';

  @override
  String get emptyBrowseSub => 'جرّب نوع عقار مختلف، أو عد لاحقاً.';

  @override
  String welcomeName(String name) {
    return 'مرحباً، $name';
  }

  @override
  String get messages => 'الرسائل';

  @override
  String get messageBroker => 'راسل السمسار';

  @override
  String get rateBroker => 'قيّم هذا السمسار';

  @override
  String get rateBrokerSub => 'كيف كانت تجربتك حتى الآن؟';

  @override
  String rateStars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نجمة',
      many: '$count نجمة',
      few: '$count نجوم',
      two: 'نجمتان',
      one: 'نجمة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get rateNoteLabel => 'أضف ملاحظة (اختياري)';

  @override
  String get rateNoteHint => 'ما الذي أعجبك، أو ما يمكن تحسينه؟';

  @override
  String get rateSubmit => 'أرسل التقييم';

  @override
  String get rateSubmitted => 'شكراً — تقييمك ظاهر على ملف السمسار العام.';

  @override
  String get rateFailed => 'تعذّر إرسال التقييم.';

  @override
  String get rateEditMine => 'حدّث تقييمي';

  @override
  String get rateRemoveMine => 'احذف تقييمي';

  @override
  String get reviewsTitle => 'المراجعات';

  @override
  String get noReviewsYet => 'لا توجد مراجعات بعد.';

  @override
  String basedOnRatings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'مبني على $count تقييم',
      many: 'مبني على $count تقييماً',
      few: 'مبني على $count تقييمات',
      two: 'مبني على تقييمين',
      one: 'مبني على تقييم واحد',
    );
    return '$_temp0';
  }

  @override
  String get brokerProfileTitle => 'السمسار';

  @override
  String get reportListing => 'أبلغ عن القائمة';

  @override
  String get more => 'المزيد';

  @override
  String get shareLink => 'نسخ رابط المشاركة';

  @override
  String get linkCopied => 'تم نسخ الرابط';

  @override
  String get copy => 'نسخ';

  @override
  String get sharePublicProfileTitle => 'رابط ملفك العام';

  @override
  String get sharePublicProfileCopied => 'تم نسخ رابط الملف العام';

  @override
  String get reportBroker => 'أبلغ عن السمسار';

  @override
  String get reportReason => 'السبب';

  @override
  String get reasonFraud => 'احتيال أو نصب';

  @override
  String get reasonSpam => 'بريد مزعج';

  @override
  String get reasonInappropriate => 'محتوى غير لائق';

  @override
  String get reasonWrongInfo => 'معلومات خاطئة';

  @override
  String get reasonOther => 'أخرى';

  @override
  String get reportNoteLabel => 'أي شيء آخر؟ (اختياري)';

  @override
  String get reportSubmit => 'أرسل البلاغ';

  @override
  String get reportSubmitted => 'شكراً — سيراجع أحد المسؤولين البلاغ قريباً.';

  @override
  String get reportFailed => 'تعذّر إرسال البلاغ.';

  @override
  String get reportCannotSelf => 'لا يمكنك الإبلاغ عن نفسك.';

  @override
  String get adminReportsTab => 'البلاغات';

  @override
  String get adminReportsOpen => 'مفتوح';

  @override
  String get adminReportsResolved => 'تم الحل';

  @override
  String get adminReportsDismissed => 'تم الرفض';

  @override
  String adminReportAbout(String target) {
    return 'بخصوص: $target';
  }

  @override
  String adminReportedBy(String name) {
    return 'بلاغ من $name';
  }

  @override
  String get adminDismiss => 'رفض';

  @override
  String get adminResolveNoAction => 'حل — بدون إجراء';

  @override
  String get adminTakeAction => 'اتخذ إجراءً';

  @override
  String get adminResolveDialogTitle => 'حل البلاغ';

  @override
  String get adminResolveNoteLabel => 'ملاحظة الحل (اختياري)';

  @override
  String get adminReportResolved => 'تم حل البلاغ.';

  @override
  String get adminReportDismissed => 'تم رفض البلاغ.';

  @override
  String get adminNoOpenReports => 'لا توجد بلاغات مفتوحة.';

  @override
  String get adminNoResolvedReports => 'لا توجد بلاغات محلولة.';

  @override
  String get adminNoDismissedReports => 'لا توجد بلاغات مرفوضة.';

  @override
  String get noMessagesYet => 'لا توجد محادثات بعد.';

  @override
  String get noMessagesYetSub => 'عندما يتواصل معك مشترٍ حول قائمة، ستظهر هنا.';

  @override
  String get noMessagesYetBuyerSub =>
      'اضغط \"راسل السمسار\" على أي قائمة لبدء محادثة.';

  @override
  String get sendMessagePlaceholder => 'اكتب رسالة…';

  @override
  String get sendMessage => 'إرسال';

  @override
  String get cannotStartConversation => 'تعذّر بدء المحادثة.';

  @override
  String get cannotLoadMessages => 'تعذّر تحميل الرسائل.';

  @override
  String get cannotSendMessage => 'تعذّر الإرسال.';

  @override
  String conversationWith(String title) {
    return 'بخصوص: $title';
  }

  @override
  String get yourInbox => 'صندوق الوارد';

  @override
  String get messagesTooltip => 'الرسائل';

  @override
  String get analyticsTitle => 'إحصائياتك';

  @override
  String get analyticsViews7d => 'المشاهدات (٧ أيام)';

  @override
  String get analyticsViews30d => 'المشاهدات (٣٠ يومًا)';

  @override
  String get analyticsMessages7d => 'الرسائل (٧ أيام)';

  @override
  String get analyticsAvgRating => 'متوسط التقييم';

  @override
  String get analyticsChartLabel => 'المشاهدات — آخر ٣٠ يومًا';

  @override
  String get analyticsPerListing => 'لكل إعلان (هذا الأسبوع)';

  @override
  String get analyticsError => 'تعذّر تحميل إحصائياتك.';

  @override
  String get analyticsEmpty =>
      'لا توجد بيانات بعد — شارك إعلاناتك لبدء تسجيل المشاهدات.';

  @override
  String get pdplConsent =>
      'أوافق على معالجة Wasit لرقم تسجيل الهيئة العامة للرقابة على الصادرات والواردات والوثيقة المرفقة لأغراض التحقق من الهوية، وذلك وفقًا لسياسة الخصوصية وقانون حماية البيانات الشخصية المصري رقم 151 لسنة 2020.';

  @override
  String get signupTermsNotice =>
      'بالتسجيل أنت توافق على شروط الاستخدام وسياسة الخصوصية.';

  @override
  String get termsLink => 'شروط الاستخدام';

  @override
  String get privacyLink => 'سياسة الخصوصية';

  @override
  String get brandTagline => 'عقارات موثّقة رسميًا';

  @override
  String get clear => 'مسح';

  @override
  String get copiedToClipboard => 'تم النسخ.';

  @override
  String get currencyEgp => 'ج.م';

  @override
  String get currencyEgpPerMonth => 'ج.م / شهريًا';

  @override
  String get unitM2 => 'م²';

  @override
  String get areaLabelShort => 'المساحة';

  @override
  String get typeLabelShort => 'النوع';

  @override
  String get detailsCta => 'التفاصيل';

  @override
  String get brokerLicensedLabel => 'وسيط عقاري معتمد';

  @override
  String listingRef(int id) {
    return 'رقم الإعلان #$id';
  }

  @override
  String get listingSaved => 'تمت الإضافة إلى المحفوظات.';

  @override
  String get listingUnsaved => 'تمت الإزالة من المحفوظات.';

  @override
  String get listingSaveFailed => 'تعذّر تحديث قائمة المحفوظات.';

  @override
  String get listingSaveAction => 'حفظ الإعلان';

  @override
  String get listingUnsaveAction => 'إزالة من المحفوظات';

  @override
  String get browseSearchHint => 'ابحث بالحي، المدينة، أو رقم الإعلان…';

  @override
  String browseVerifiedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عقار موثّق',
      many: '$count عقارًا موثّقًا',
      few: '$count عقارات موثّقة',
      two: 'عقاران موثّقان',
      one: 'عقار موثّق واحد',
      zero: 'لا توجد عقارات مطابقة',
    );
    return '$_temp0';
  }

  @override
  String get filtersAdvanced => 'تصفية متقدمة';

  @override
  String get sortLabel => 'الترتيب';

  @override
  String get sortNewest => 'الأحدث';

  @override
  String get sortPriceAsc => 'السعر: من الأقل';

  @override
  String get sortPriceDesc => 'السعر: من الأعلى';

  @override
  String get sortAreaDesc => 'الأكبر مساحة';

  @override
  String get emptySearchTitle => 'لا توجد نتائج لهذا البحث';

  @override
  String get emptySearchSub => 'جرّب كلمات أقل، أو اسم الحي، أو رقم الإعلان.';

  @override
  String get listingAuditTitle => 'ملف تدقيق العقار';

  @override
  String brokerRatingTag(String avg, int count) {
    return '$avg من $count تقييم';
  }

  @override
  String get paneDocuments => 'المستندات';

  @override
  String get paneDescription => 'الوصف';

  @override
  String get paneBroker => 'الوسيط';

  @override
  String get noDescription => 'لم يكتب الوسيط وصفًا لهذا العقار.';

  @override
  String get brokerUnavailable => 'بيانات الوسيط غير متاحة لهذا الإعلان.';

  @override
  String get viewTrustFile => 'عرض ملف الثقة';

  @override
  String get viewOnMap => 'الخريطة';

  @override
  String get openInMaps => 'فتح في الخرائط';

  @override
  String get mapOpenFailed => 'تعذّر فتح تطبيق الخرائط.';

  @override
  String get locationSectionTitle => 'الموقع الذي حدّده الوسيط';

  @override
  String get brokerTrustMetrics => 'مؤشرات الثقة';

  @override
  String brokerGoeicChip(String number) {
    return 'سجل GOEIC #$number';
  }

  @override
  String brokerMemberSince(String date) {
    return 'على وسيط منذ $date';
  }

  @override
  String brokerLiveListings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إعلان نشط',
      many: '$count إعلانًا نشطًا',
      few: '$count إعلانات نشطة',
      two: 'إعلانان نشطان',
      one: 'إعلان نشط واحد',
      zero: 'لا توجد إعلانات نشطة',
    );
    return '$_temp0';
  }

  @override
  String get brokerLiveListingsLabel => 'إعلانات نشطة';

  @override
  String get brokerAdminChecked => 'راجعه فريقنا';

  @override
  String get brokerRatedThreads => 'تقييمات المشترين';

  @override
  String get brokerMetricsHonestNote =>
      'التقييمات من مشترين تواصلوا فعلًا مع الوسيط داخل التطبيق. والتوثيق يعني أننا راجعنا مستند تسجيله في GOEIC — وليس ضمانًا لأي صفقة بعينها.';

  @override
  String brokerTabListings(int count) {
    return 'الإعلانات ($count)';
  }

  @override
  String brokerTabReviews(int count) {
    return 'التقييمات ($count)';
  }

  @override
  String get brokerNoListings => 'لا توجد إعلانات نشطة لهذا الوسيط حاليًا.';
}
