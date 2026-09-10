// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Wasit';

  @override
  String get signIn => 'Sign in';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get loginHeroTitle => 'Welcome to Wasit';

  @override
  String get loginHeroSubtitle =>
      'Egypt\'\'s first verified real-estate brokerage platform.';

  @override
  String get loginCredentialPill =>
      'Official accreditation & digital land registry';

  @override
  String get loginPhoneHint => 'Linked to your National ID';

  @override
  String get loginAltDivider => 'Or continue with';

  @override
  String get loginSsoDigitalEgypt => 'Egyptian Digital ID (National Access)';

  @override
  String get loginSsoDigitalEgyptSub =>
      'Instant verification via your national ID card';

  @override
  String get loginOtpTitle => 'Sign in with SMS code';

  @override
  String get loginOtpSub => 'One-tap login by phone verification';

  @override
  String get loginNoAccountPrompt => 'Don\'\'t have an account?';

  @override
  String get loginRegisterCta => 'Create one';

  @override
  String get loginTrustContracts => 'Official contracts';

  @override
  String get loginTrustContractsSub => 'Verified and legally compliant';

  @override
  String get loginTrustInspect => 'Professional inspection';

  @override
  String get loginTrustInspectSub => 'Rigorous on-site checks';

  @override
  String get loginFooterTitle => 'Real-estate safety & legality guarantee';

  @override
  String get loginFooterSub =>
      'Every property and broker is officially vetted through the Real-Estate Registry.';

  @override
  String get otpLoginTitle => 'Sign in by SMS code';

  @override
  String get otpLoginComingSoon =>
      'OTP-only sign-in is coming soon. Please use phone + password for now.';

  @override
  String get registerHeroPill => 'Digital real-estate registration system';

  @override
  String get registerHeroTitle => 'Join Wasit\'\'s verified network';

  @override
  String get registerHeroSubtitle =>
      'Choose your account type to start browsing or listing verified properties.';

  @override
  String get registerAccountType => 'Account type';

  @override
  String registerStep(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get registerRoleBrokerLicensed => 'Licensed broker';

  @override
  String get registerRoleBrokerLicenseChip => 'License';

  @override
  String get registerTrustBannerTitle =>
      'Verification & transparency guarantee';

  @override
  String get registerTrustBannerSub =>
      'Buyers get contract validity and land-registry checks with no hidden brokerage fees.';

  @override
  String get registerFullNameHint => '(As on your National ID)';

  @override
  String get registerFullNameExample => 'e.g. Ahmed Abdallah El-Sherbiny';

  @override
  String get emailField => 'Email';

  @override
  String get registerEmailOptionalHint => 'Optional';

  @override
  String get registerPasswordHint => '8+ letters & symbols';

  @override
  String get registerPasswordRule =>
      'Must include digits, upper + lowercase letters, and a special character.';

  @override
  String get registerLinkRegistryTitle =>
      'Instant link to the Real-Estate Registry';

  @override
  String get registerLinkRegistrySub =>
      'Encrypted verification against registered contracts.';

  @override
  String get registerAgreeTerms =>
      'I agree to the terms of service, real-estate verification policy, and data protection.';

  @override
  String get registerMustAgreeTerms => 'Please tick the terms box to continue.';

  @override
  String get registerContinueCta => 'Create account and continue';

  @override
  String get registerTrustEncrypted => 'Encrypted data';

  @override
  String get registerTrustLicensed => 'Legal licensing';

  @override
  String get registerTrustSupport => '24/7 support';

  @override
  String get verifyPhoneIntro => 'We sent a 6-digit verification code to';

  @override
  String get verifyPhoneEditNumber => 'Change number';

  @override
  String get verifyPhoneCodeSent => 'Code sent.';

  @override
  String verifyPhoneDigitsEntered(int n) {
    return '$n of 6 digits entered';
  }

  @override
  String get verifyPhoneAutoDecrypt => 'Auto-encrypted';

  @override
  String get verifyPhoneResendInPrefix => 'Resend code in';

  @override
  String get verifyPhoneResendSms => 'Resend code by SMS';

  @override
  String get verifyPhoneConfirmCta => 'Confirm code and continue';

  @override
  String get verifyPhoneSecurityNote =>
      'Wasit protects your data with 256-bit AES encryption.';

  @override
  String get createAccount => 'Create account';

  @override
  String get fullName => 'Full name';

  @override
  String get phone => 'Phone';

  @override
  String get email => 'Email (optional)';

  @override
  String get password => 'Password';

  @override
  String get signOut => 'Sign out';

  @override
  String get logout => 'Sign out';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountTitle => 'Delete your account?';

  @override
  String get deleteAccountBody =>
      'This permanently deletes your account and hides your listings. You can\'\'t undo this. Enter your password to confirm.';

  @override
  String get deleteAccountConfirm => 'Delete permanently';

  @override
  String get deleteAccountDone => 'Your account has been deleted.';

  @override
  String get refresh => 'Refresh';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get remove => 'Remove';

  @override
  String get save => 'Save';

  @override
  String get close => 'Close';

  @override
  String get ok => 'OK';

  @override
  String get roleBuyer => 'Buyer';

  @override
  String get roleBroker => 'Broker';

  @override
  String get loginPromptRegister => 'Don\'\'t have an account? Register';

  @override
  String get registerPromptLogin => 'Already have an account? Sign in';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get forgotPasswordTitle => 'Reset your password';

  @override
  String get forgotPasswordStep1Sub =>
      'Enter the phone number on your account. We\'\'ll send you a 6-digit code.';

  @override
  String get forgotPasswordStep2Sub =>
      'Enter the code we sent to your phone plus a new password.';

  @override
  String get forgotPasswordSendCode => 'Send code';

  @override
  String get forgotPasswordConfirmReset => 'Reset password';

  @override
  String get forgotPasswordSuccess =>
      'Password reset. Sign in with your new password.';

  @override
  String get verifyPhoneTitle => 'Verify your phone';

  @override
  String verifyPhoneSub(String phone) {
    return 'We sent a 6-digit code to $phone. Enter it to verify your account.';
  }

  @override
  String get verifyPhoneCodeLabel => '6-digit code';

  @override
  String get verifyPhoneConfirm => 'Verify';

  @override
  String get verifyPhoneResend => 'Resend code';

  @override
  String verifyPhoneResendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get verifyPhoneSkip => 'Skip for now';

  @override
  String get verifyPhoneSuccess => 'Phone verified.';

  @override
  String get verifyBannerText =>
      'Verify your phone number to secure your account.';

  @override
  String get verifyBannerCta => 'Verify';

  @override
  String get newPassword => 'New password';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get passwordsDoNotMatch => 'Passwords don\'\'t match.';

  @override
  String get codeIncorrect => 'That code is incorrect or has expired.';

  @override
  String get phoneRequired => 'Please enter your phone number.';

  @override
  String get passwordMin8 => 'At least 8 characters';

  @override
  String get namePleaseEnter => 'Please enter your name';

  @override
  String get phoneInvalid => 'Invalid phone number';

  @override
  String get brokerDisclaimer =>
      'Brokers start as unverified. Submit your GOEIC registration proof in the next step so an admin can review it. Only verified brokers show the trust badge on their listings.';

  @override
  String get themeSystem => 'Theme: system';

  @override
  String get themeLight => 'Theme: light';

  @override
  String get themeDark => 'Theme: dark';

  @override
  String get languageEnglish => 'Language: English';

  @override
  String get languageArabic => 'Language: العربية';

  @override
  String get languageSystem => 'Language: system';

  @override
  String get verifyTitle => 'My verification';

  @override
  String get verifyMyStatus => 'My verification';

  @override
  String get verifyStatusVerifiedHeading => 'Verified broker';

  @override
  String get verifyStatusPendingHeading => 'Awaiting review';

  @override
  String get verifyStatusRejectedHeading => 'Submission rejected';

  @override
  String get verifyStatusPendingSub =>
      'An admin will review your submission shortly.';

  @override
  String get verifyStatusRejectedSub =>
      'Update your document and submit again below.';

  @override
  String verifyStatusVerifiedSubDated(String date) {
    return 'Verified on $date. Your listings show a Verified badge.';
  }

  @override
  String get verifyStatusVerifiedSubUndated =>
      'Your listings show a Verified badge.';

  @override
  String get reviewerNote => 'REVIEWER NOTE';

  @override
  String get goeicField => 'GOEIC registration number';

  @override
  String get goeicHint => 'e.g. EG-2024-08841';

  @override
  String get registrationDetails => 'Registration details';

  @override
  String get updateRegistration => 'Update your registration';

  @override
  String get chooseDocument => 'Choose registration document';

  @override
  String get documentAllowed => 'PDF, JPG, PNG, or WEBP · max 20 MB';

  @override
  String tapToReplace(String size) {
    return '$size · tap to replace';
  }

  @override
  String get resubmitDocuments => 'Resubmit documents';

  @override
  String get submitForReview => 'Submit for review';

  @override
  String get submitNewDocuments => 'Submit new documents';

  @override
  String get required => 'Required';

  @override
  String get verifyPickDocument => 'Please select a registration document.';

  @override
  String get verifySubmitted => 'Submitted. An admin will review shortly.';

  @override
  String get verifySubmitFailed => 'Submission failed.';

  @override
  String get verifyHonestNote =>
      'Verification confirms your GOEIC registration was reviewed by our team. It does not replace independent legal verification.';

  @override
  String get myListings => 'My listings';

  @override
  String get browseListings => 'Browse listings';

  @override
  String get navBrowse => 'Browse';

  @override
  String get navMyListings => 'My listings';

  @override
  String get navSaved => 'Saved';

  @override
  String get navMessages => 'Messages';

  @override
  String get navAccount => 'Account';

  @override
  String get navAdminQueue => 'Queue';

  @override
  String get savedEmptyTitle => 'No saved listings yet.';

  @override
  String get savedEmptySub =>
      'Tap the heart icon on any listing to save it here.';

  @override
  String get accountPreferences => 'Preferences';

  @override
  String get accountTheme => 'Theme';

  @override
  String get accountLanguage => 'Language';

  @override
  String get accountActions => 'Account';

  @override
  String get newListing => 'New listing';

  @override
  String get priceTransparency => 'Price transparency';

  @override
  String get unverifiedRejectedTitle => 'Your submission was rejected.';

  @override
  String get unverifiedNotYetTitle =>
      'You need to be verified to post listings.';

  @override
  String get unverifiedRejectedSub =>
      'Open your verification screen to review the reviewer\'\'s note and resubmit.';

  @override
  String get unverifiedNotYetSub =>
      'Submit your GOEIC registration document so our team can verify you. Only verified brokers can post listings — this is how buyers know they can trust you.';

  @override
  String get openVerification => 'Open verification';

  @override
  String get noListingsYet => 'No listings yet';

  @override
  String get noListingsHint =>
      'Tap \"New listing\" to post your first property.';

  @override
  String get listingTitle => 'Title';

  @override
  String get listingDescription => 'Description (optional)';

  @override
  String get listingPrice => 'Price (EGP)';

  @override
  String get listingArea => 'Area (m²)';

  @override
  String get listingPropertyType => 'Property type';

  @override
  String get listingKindLabel => 'Sale or rent';

  @override
  String get listingKindSale => 'For sale';

  @override
  String get listingKindRent => 'For rent';

  @override
  String get listingBedrooms => 'Bedrooms';

  @override
  String get listingBathrooms => 'Bathrooms';

  @override
  String get listingFloor => 'Floor';

  @override
  String get listingCompound => 'Compound';

  @override
  String get listingCompoundHint => 'e.g. Palm Hills, Rehab';

  @override
  String get listingFurnishedLabel => 'Furnished';

  @override
  String get listingFurnishedYes => 'Yes';

  @override
  String get listingFurnishedNo => 'No';

  @override
  String get listingFurnishedUnspecified => 'Unspecified';

  @override
  String get listingDeliveryLabel => 'Delivery status';

  @override
  String get listingDeliveryUnspecified => 'Not specified';

  @override
  String get listingDeliveryReady => 'Ready to move in';

  @override
  String get listingDeliveryUnderConstruction => 'Under construction';

  @override
  String get filtersLabel => 'FILTERS';

  @override
  String get filterAnyGov => 'Any governorate';

  @override
  String get filterAnyCity => 'Any city';

  @override
  String get filterBedroomsAny => 'Any';

  @override
  String get filterPriceMin => 'Min price';

  @override
  String get filterPriceMax => 'Max price';

  @override
  String get filterApply => 'Apply';

  @override
  String get filterReset => 'Reset';

  @override
  String get shareWhatsApp => 'Share on WhatsApp';

  @override
  String get whatsappOpenFailed => 'Could not open WhatsApp.';

  @override
  String get referralTitle => 'Invite fellow brokers';

  @override
  String get referralShareText =>
      'Join me on Wasit — the verified brokers platform for Egyptian real estate.';

  @override
  String get referralCopied => 'Referral link copied.';

  @override
  String referralJoinedCount(int count) {
    return '$count joined';
  }

  @override
  String get listingGovernorate => 'Governorate';

  @override
  String get listingCity => 'City';

  @override
  String get listingDistrict => 'District (optional)';

  @override
  String get listingLat => 'Latitude';

  @override
  String get listingLng => 'Longitude';

  @override
  String get useMyLocation => 'Use my location';

  @override
  String get photosLabel => 'PHOTOS';

  @override
  String get locationLabel => 'LOCATION';

  @override
  String get addPhoto => 'Add';

  @override
  String get publishListing => 'Publish listing';

  @override
  String get listingCreated => 'Listing created.';

  @override
  String listingCreatedPartial(int uploaded, int total, String reason) {
    return 'Listing created — but only $uploaded of $total photo(s) uploaded ($reason).';
  }

  @override
  String createFailed(String reason) {
    return 'Create failed: $reason';
  }

  @override
  String get atLeastOnePhoto => 'Add at least one photo of the property.';

  @override
  String get coordsRequired => 'Add coordinates or tap \"Use my location\".';

  @override
  String get titleMin3 => 'At least 3 characters';

  @override
  String get priceInvalid => 'Enter a valid price';

  @override
  String get areaRequired => 'Enter area';

  @override
  String get duplicatePhotoNote =>
      'Photos matching another listing may be flagged for admin review. Upload your own photos of the actual property.';

  @override
  String get propertyApartment => 'Apartment';

  @override
  String get propertyHouse => 'House';

  @override
  String get propertyVilla => 'Villa';

  @override
  String get propertyLand => 'Land';

  @override
  String get propertyCommercial => 'Commercial';

  @override
  String get statusVerified => 'Verified';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusRejected => 'Rejected';

  @override
  String get adminVerified => 'Admin verified';

  @override
  String get awaitingReview => 'Awaiting review';

  @override
  String get selfReported => 'Self-reported';

  @override
  String get notProvided => 'Not provided';

  @override
  String get priceLabel => 'PRICE';

  @override
  String get areaLabel => 'AREA';

  @override
  String get typeLabel => 'TYPE';

  @override
  String get aboutLabel => 'ABOUT';

  @override
  String get brokerLabel => 'BROKER';

  @override
  String get propertyDocuments => 'PROPERTY DOCUMENTS';

  @override
  String get stillAvailable => 'Still available';

  @override
  String get callBroker => 'Call broker';

  @override
  String get buyerCallDisclaimer =>
      'This app assists with verification. Always confirm ownership and title with a lawyer or the notary office before paying anything.';

  @override
  String get confirmedStillAvailable => 'Marked as still available.';

  @override
  String get confirmFailed => 'Confirm failed.';

  @override
  String get deleteListingTitle => 'Delete listing?';

  @override
  String get deleteListingBody =>
      'This cannot be undone. Photos will also be removed.';

  @override
  String get deleteFailed => 'Delete failed.';

  @override
  String get noDialer => 'No phone dialer available on this device.';

  @override
  String get dialerOpenFailed => 'Could not open the dialer.';

  @override
  String postedOn(String date) {
    return 'Posted $date';
  }

  @override
  String get postedRecently => 'Posted recently';

  @override
  String get docsTitleDeed => 'Title deed registered at notary';

  @override
  String get docsNoLiens => 'No liens or disputes';

  @override
  String get docsTaxClearance => 'Tax clearance';

  @override
  String get docsHonestNote =>
      'Verification confirms our admin reviewed the document — it does not replace a lawyer or the notary office. Self-reported entries have no verification behind them.';

  @override
  String get uploadProof => 'Upload proof';

  @override
  String get replaceProof => 'Replace proof document';

  @override
  String get uploadProofSub => 'An admin will review it before verifying.';

  @override
  String get iHaveThisNoProof => 'I have this — no proof yet';

  @override
  String get iHaveThisNoProofSub =>
      'Shown to buyers as \"self-reported by the broker\".';

  @override
  String get docSubmitted => 'Uploaded. An admin will review it shortly.';

  @override
  String get docSelfReported => 'Marked as self-reported.';

  @override
  String get docCleared => 'Cleared.';

  @override
  String get actionFailed => 'Action failed.';

  @override
  String get adminTitle => 'Admin';

  @override
  String get brokersTab => 'Brokers';

  @override
  String get flaggedTab => 'Flagged';

  @override
  String get docsTab => 'Docs';

  @override
  String get filterPending => 'Pending';

  @override
  String get filterVerified => 'Verified';

  @override
  String get filterRejected => 'Rejected';

  @override
  String get noPendingBrokers => 'No pending brokers — inbox zero.';

  @override
  String get noVerifiedBrokers => 'No verified brokers yet.';

  @override
  String get noRejectedBrokers => 'No rejected submissions.';

  @override
  String get noFlagged => 'No flagged listings.';

  @override
  String get noPendingDocs => 'No documents to review.';

  @override
  String get rejectionReasonTitle => 'Rejection reason';

  @override
  String get rejectionReasonHint =>
      'Explain what needs fixing — the broker will see this.';

  @override
  String get reject => 'Reject';

  @override
  String get approve => 'Approve';

  @override
  String get brokerVerified => 'Broker verified.';

  @override
  String get brokerRejected => 'Broker rejected.';

  @override
  String get documentVerified => 'Document verified.';

  @override
  String get documentRejected => 'Document rejected.';

  @override
  String get approveFailed => 'Approve failed.';

  @override
  String get rejectFailed => 'Reject failed.';

  @override
  String get unflag => 'Unflag';

  @override
  String get listingUnflagged => 'Listing unflagged.';

  @override
  String get unflagFailed => 'Unflag failed.';

  @override
  String get goeicShort => 'GOEIC no.';

  @override
  String get lastUpdate => 'Last update';

  @override
  String get previousRejectionReason => 'PREVIOUS REJECTION REASON';

  @override
  String get registrationDocument => 'REGISTRATION DOCUMENT';

  @override
  String get tapToOpen => 'Tap to open in system viewer';

  @override
  String get brokerHasNotUploaded => 'Broker has not uploaded yet';

  @override
  String get noDocumentSubmitted => 'No document submitted';

  @override
  String couldNotOpenDocument(String reason) {
    return 'Could not open document: $reason';
  }

  @override
  String get duplicateSuspected => 'Duplicate suspected';

  @override
  String duplicateOf(int id) {
    return 'Duplicate of #$id';
  }

  @override
  String get view => 'View';

  @override
  String submittedRelative(String when) {
    return 'Submitted $when';
  }

  @override
  String get medianPricePerM2 => 'MEDIAN PRICE / m²';

  @override
  String get rangeLabel => 'RANGE';

  @override
  String get middle50Label => 'MIDDLE 50%';

  @override
  String get listingsLabel => 'LISTINGS';

  @override
  String get notEnoughListings => 'Not enough listings match these filters.';

  @override
  String get medianTrendTitle => 'MEDIAN TREND — LAST 12 MONTHS';

  @override
  String get notEnoughMonthly =>
      'Not enough monthly data yet — need at least two months with 2+ listings each.';

  @override
  String get marketHonest =>
      'Asking prices from verified brokers on this app, plus sold listings when reported. This is a market signal, not a valuation service — always confirm with a professional appraisal before you commit.';

  @override
  String get all => 'All';

  @override
  String get filterAll => 'All';

  @override
  String get expiryExpired => 'Expired · tap to reconfirm';

  @override
  String expiryDaysLeft(int days) {
    return 'Expires in ${days}d';
  }

  @override
  String expiryActive(int days) {
    return 'Active · $days days left';
  }

  @override
  String get emptyBrowseTitle => 'No matching listings';

  @override
  String get emptyBrowseSub =>
      'Try a different property type, or check back later.';

  @override
  String welcomeName(String name) {
    return 'Welcome, $name';
  }

  @override
  String get messages => 'Messages';

  @override
  String get messageBroker => 'Message broker';

  @override
  String get rateBroker => 'Rate this broker';

  @override
  String get rateBrokerSub => 'How was your interaction so far?';

  @override
  String rateStars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stars',
      one: '1 star',
    );
    return '$_temp0';
  }

  @override
  String get rateNoteLabel => 'Share a note (optional)';

  @override
  String get rateNoteHint => 'What went well, or what could improve?';

  @override
  String get rateSubmit => 'Submit rating';

  @override
  String get rateSubmitted =>
      'Thanks — your rating is public on the broker\'s profile.';

  @override
  String get rateFailed => 'Could not submit rating.';

  @override
  String get rateEditMine => 'Update my rating';

  @override
  String get rateRemoveMine => 'Remove my rating';

  @override
  String get reviewsTitle => 'Reviews';

  @override
  String get noReviewsYet => 'No reviews yet.';

  @override
  String basedOnRatings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Based on $count ratings',
      one: 'Based on 1 rating',
    );
    return '$_temp0';
  }

  @override
  String get brokerProfileTitle => 'Broker';

  @override
  String get reportListing => 'Report listing';

  @override
  String get more => 'More';

  @override
  String get shareLink => 'Copy share link';

  @override
  String get linkCopied => 'Link copied to clipboard';

  @override
  String get copy => 'Copy';

  @override
  String get sharePublicProfileTitle => 'Your public profile link';

  @override
  String get sharePublicProfileCopied => 'Public profile link copied';

  @override
  String get reportBroker => 'Report broker';

  @override
  String get reportReason => 'Reason';

  @override
  String get reasonFraud => 'Fraud or scam';

  @override
  String get reasonSpam => 'Spam';

  @override
  String get reasonInappropriate => 'Inappropriate content';

  @override
  String get reasonWrongInfo => 'Wrong information';

  @override
  String get reasonOther => 'Other';

  @override
  String get reportNoteLabel => 'Anything else? (optional)';

  @override
  String get reportSubmit => 'Submit report';

  @override
  String get reportSubmitted => 'Thanks — an admin will review this shortly.';

  @override
  String get reportFailed => 'Could not submit the report.';

  @override
  String get reportCannotSelf => 'You cannot report yourself.';

  @override
  String get adminReportsTab => 'Reports';

  @override
  String get adminReportsOpen => 'Open';

  @override
  String get adminReportsResolved => 'Resolved';

  @override
  String get adminReportsDismissed => 'Dismissed';

  @override
  String adminReportAbout(String target) {
    return 'About: $target';
  }

  @override
  String adminReportedBy(String name) {
    return 'Reported by $name';
  }

  @override
  String get adminDismiss => 'Dismiss';

  @override
  String get adminResolveNoAction => 'Resolve — no action';

  @override
  String get adminTakeAction => 'Take action';

  @override
  String get adminResolveDialogTitle => 'Resolve report';

  @override
  String get adminResolveNoteLabel => 'Resolution note (optional)';

  @override
  String get adminReportResolved => 'Report resolved.';

  @override
  String get adminReportDismissed => 'Report dismissed.';

  @override
  String get adminNoOpenReports => 'No open reports.';

  @override
  String get adminNoResolvedReports => 'No resolved reports.';

  @override
  String get adminNoDismissedReports => 'No dismissed reports.';

  @override
  String get noMessagesYet => 'No conversations yet.';

  @override
  String get noMessagesYetSub =>
      'When a buyer contacts you about a listing, it will appear here.';

  @override
  String get noMessagesYetBuyerSub =>
      'Tap \"Message broker\" on any listing to start a conversation.';

  @override
  String get sendMessagePlaceholder => 'Write a message…';

  @override
  String get sendMessage => 'Send';

  @override
  String get cannotStartConversation => 'Could not start conversation.';

  @override
  String get cannotLoadMessages => 'Could not load messages.';

  @override
  String get cannotSendMessage => 'Could not send.';

  @override
  String conversationWith(String title) {
    return 'About: $title';
  }

  @override
  String get yourInbox => 'Your inbox';

  @override
  String get messagesTooltip => 'Messages';

  @override
  String get analyticsTitle => 'Your analytics';

  @override
  String get analyticsViews7d => 'Views (7 days)';

  @override
  String get analyticsViews30d => 'Views (30 days)';

  @override
  String get analyticsMessages7d => 'Messages (7 days)';

  @override
  String get analyticsAvgRating => 'Average rating';

  @override
  String get analyticsChartLabel => 'Views — last 30 days';

  @override
  String get analyticsPerListing => 'Per listing (this week)';

  @override
  String get analyticsError => 'Couldn\'t load your analytics.';

  @override
  String get analyticsEmpty =>
      'No data yet — share your listings to start seeing views.';

  @override
  String get pdplConsent =>
      'I consent to Wasit processing my GOEIC number and registration document for identity verification, under the Privacy Policy and Egypt\'s Personal Data Protection Law (151/2020).';

  @override
  String get signupTermsNotice =>
      'By signing up you agree to our Terms and Privacy Policy.';

  @override
  String get termsLink => 'Terms';

  @override
  String get privacyLink => 'Privacy Policy';

  @override
  String get brandTagline => 'Officially verified properties';

  @override
  String get clear => 'Clear';

  @override
  String get copiedToClipboard => 'Copied.';

  @override
  String get currencyEgp => 'EGP';

  @override
  String get currencyEgpPerMonth => 'EGP / month';

  @override
  String get unitM2 => 'm²';

  @override
  String get areaLabelShort => 'Area';

  @override
  String get typeLabelShort => 'Type';

  @override
  String get detailsCta => 'Details';

  @override
  String get brokerLicensedLabel => 'Licensed broker';

  @override
  String listingRef(int id) {
    return 'Ref. #$id';
  }

  @override
  String get listingSaved => 'Saved to your list.';

  @override
  String get listingUnsaved => 'Removed from your saved list.';

  @override
  String get listingSaveFailed => 'Couldn’t update your saved list.';

  @override
  String get listingSaveAction => 'Save this listing';

  @override
  String get listingUnsaveAction => 'Remove from saved';

  @override
  String get browseSearchHint => 'Search by district, city, or listing number…';

  @override
  String browseVerifiedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count verified listings',
      one: '1 verified listing',
      zero: 'No verified listings match',
    );
    return '$_temp0';
  }

  @override
  String get filtersAdvanced => 'Advanced filters';

  @override
  String get sortLabel => 'Sort';

  @override
  String get sortNewest => 'Newest';

  @override
  String get sortPriceAsc => 'Price: low to high';

  @override
  String get sortPriceDesc => 'Price: high to low';

  @override
  String get sortAreaDesc => 'Largest area';

  @override
  String get emptySearchTitle => 'Nothing matched that search';

  @override
  String get emptySearchSub =>
      'Try fewer words, a district name, or the listing number.';

  @override
  String get listingAuditTitle => 'Property audit';

  @override
  String brokerRatingTag(String avg, int count) {
    return '$avg from $count ratings';
  }

  @override
  String get paneDocuments => 'Documents';

  @override
  String get paneDescription => 'Description';

  @override
  String get paneBroker => 'Broker';

  @override
  String get noDescription =>
      'The broker hasn’t written a description for this property.';

  @override
  String get brokerUnavailable =>
      'Broker details are unavailable for this listing.';

  @override
  String get viewTrustFile => 'View trust file';

  @override
  String get viewOnMap => 'Map';

  @override
  String get openInMaps => 'Open in Maps';

  @override
  String get mapOpenFailed => 'Could not open a map app.';

  @override
  String get locationSectionTitle => 'Location the broker pinned';

  @override
  String get brokerTrustMetrics => 'Trust indicators';

  @override
  String brokerGoeicChip(String number) {
    return 'GOEIC #$number';
  }

  @override
  String brokerMemberSince(String date) {
    return 'On Wasit since $date';
  }

  @override
  String brokerLiveListings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count live listings',
      one: '1 live listing',
      zero: 'No live listings',
    );
    return '$_temp0';
  }

  @override
  String get brokerLiveListingsLabel => 'Live listings';

  @override
  String get brokerAdminChecked => 'Reviewed by our team';

  @override
  String get brokerRatedThreads => 'Buyer ratings';

  @override
  String get brokerMetricsHonestNote =>
      'Ratings come only from buyers who actually messaged this broker through the app. Verification means we checked their GOEIC registration document — it is not a guarantee of any individual deal.';

  @override
  String brokerTabListings(int count) {
    return 'Listings ($count)';
  }

  @override
  String brokerTabReviews(int count) {
    return 'Reviews ($count)';
  }

  @override
  String get brokerNoListings => 'This broker has no live listings right now.';

  @override
  String get myListingsSubtitle =>
      'Manage your portfolio, verification and reach.';

  @override
  String get portfolioPerformanceTitle => 'This week';

  @override
  String get seeDetails => 'Details';

  @override
  String get statViews7d => 'Views (7 days)';

  @override
  String get statInquiries7d => 'Inquiries (7 days)';

  @override
  String get statLiveListings => 'Live listings';

  @override
  String bucketLive(int count) {
    return 'Live ($count)';
  }

  @override
  String bucketExpired(int count) {
    return 'Needs confirming ($count)';
  }

  @override
  String bucketArchived(int count) {
    return 'Archived ($count)';
  }

  @override
  String get bucketEmptyExpired => 'Nothing waiting on you';

  @override
  String get bucketEmptyExpiredSub =>
      'Listings appear here once they pass 30 days without a confirmation.';

  @override
  String get bucketEmptyArchived => 'Nothing archived';

  @override
  String get bucketEmptyArchivedSub =>
      'Sold and hidden listings are kept here.';

  @override
  String get whyVerificationTitle => 'Why the verified badge matters';

  @override
  String get whyVerificationBody =>
      'Buyers only see listings from brokers whose GOEIC registration our team has checked. Keep your documents current and your listings stay in the feed.';

  @override
  String get manageListing => 'Manage';

  @override
  String metricViews(int count) {
    return '$count views';
  }

  @override
  String metricInquiries(int count) {
    return '$count inquiries this week';
  }

  @override
  String get listingStatusLive => 'Live';

  @override
  String get listingStatusExpiring => 'Expiring';

  @override
  String get listingStatusExpired => 'Expired';

  @override
  String get listingStatusSold => 'Sold';

  @override
  String get listingStatusHidden => 'Hidden';

  @override
  String get inboxTitle => 'Conversations';

  @override
  String get inboxSearchHint => 'Search by name, property, or listing number…';

  @override
  String inboxFilterAll(int count) {
    return 'All ($count)';
  }

  @override
  String inboxFilterUnread(int count) {
    return 'Unread ($count)';
  }

  @override
  String get inboxTrustTitle => 'Conversations stay on the record';

  @override
  String get inboxTrustBody =>
      'Every thread is tied to a listing and to identified accounts, so what was agreed can be traced later.';

  @override
  String get inboxPrivacyNote =>
      'Your conversations are visible only to you and the other party.';

  @override
  String get inboxNoMatches => 'No conversation matches that.';

  @override
  String get threadNoMessagesYet => 'No messages yet';

  @override
  String get safetyGuidanceTitle => 'Before you pay anything';

  @override
  String get safetyNoCashTitle => 'No cash outside a contract';

  @override
  String get safetyNoCashBody =>
      'Never hand over a deposit without a signed, registered contract.';

  @override
  String get safetyCheckDeedTitle => 'Check the deed yourself';

  @override
  String get safetyCheckDeedBody =>
      'Confirm the title at the notary office before any payment.';

  @override
  String get threadTitle => 'Conversation';

  @override
  String get viewListing => 'View listing';

  @override
  String get threadSecurityNote =>
      'This conversation is kept on the record between two identified Wasit accounts. Wasit does not read it, and it is not end-to-end encrypted.';

  @override
  String get quickReplyBuyerViewing => 'Can I view the property this week?';

  @override
  String get quickReplyBuyerDocs => 'Which ownership documents are ready?';

  @override
  String get quickReplyBuyerPrice => 'Is the price negotiable?';

  @override
  String get quickReplyBrokerViewing =>
      'The property is available for viewing — which day suits you?';

  @override
  String get quickReplyBrokerDocs =>
      'The registered contract and deed are ready for review.';

  @override
  String get quickReplyBrokerPrice =>
      'Tell me your offer and I will pass it to the owner.';

  @override
  String get createListingSubtitle => 'Publish a property for verified buyers';

  @override
  String get stepBack => 'Back';

  @override
  String get stepContinue => 'Continue';

  @override
  String stepCounter(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get stepType => 'Type';

  @override
  String get stepLocation => 'Location';

  @override
  String get stepSpecs => 'Details';

  @override
  String get stepPhotos => 'Photos';

  @override
  String get stepReview => 'Review';

  @override
  String get listingTitleHint => 'e.g. Panoramic apartment, Fifth Settlement';

  @override
  String get listingDescriptionHint =>
      'Finishing, view, what is included — the things buyers ask about first.';

  @override
  String get listingDistrictHint => 'e.g. Fifth Settlement, Zayed Dunes';

  @override
  String get listingFloorHint => 'e.g. 4 — leave empty for a villa or land';

  @override
  String get selectGovernorate => 'Choose a governorate';

  @override
  String get selectCity => 'Choose a city';

  @override
  String get selectGovernorateFirst => 'Choose the governorate first.';

  @override
  String get selectCityFirst => 'Choose or type the city.';

  @override
  String get cityOther => 'Another city…';

  @override
  String get cityOtherHint => 'Type the city name';

  @override
  String get mapPinTitle => 'Map pin';

  @override
  String get mapPinBody =>
      'Buyers use this to see where the property actually is. Stand at the property and tap the button, or paste the coordinates.';

  @override
  String get photosStepHint =>
      'The first photo becomes the cover in search results. Wide daylight shots of the main rooms work best.';

  @override
  String get coverPhoto => 'Cover';

  @override
  String get documentsAfterPublishTitle => 'Ownership documents come next';

  @override
  String get documentsAfterPublishBody =>
      'Once the listing is published, open it and attach the deed and clearance certificates — they attach to the listing itself.';

  @override
  String get publishExpiryNote =>
      'Listings stay in the feed for 30 days. Confirm the property is still available before then and it keeps running.';

  @override
  String get locationPermissionDenied => 'Location permission denied.';

  @override
  String locationReadFailed(String error) {
    return 'Could not read location: $error';
  }

  @override
  String photoPickFailed(String error) {
    return 'Could not pick photos: $error';
  }

  @override
  String get adminConsoleTitle => 'Compliance desk';

  @override
  String get adminConsoleHeading => 'Verification & compliance';

  @override
  String get adminConsoleSubtitle =>
      'Everything waiting on a decision, in one queue.';

  @override
  String get kpiBrokersLabel => 'Broker verification';

  @override
  String get kpiBrokersHint => 'GOEIC documents awaiting review';

  @override
  String get kpiListingsLabel => 'Flagged listings';

  @override
  String get kpiListingsHint => 'Possible duplicate photos';

  @override
  String get kpiDocumentsLabel => 'Property documents';

  @override
  String get kpiDocumentsHint => 'Deeds and clearances to check';

  @override
  String get kpiReportsLabel => 'Reports';

  @override
  String get kpiReportsHint => 'Open complaints from users';

  @override
  String get openFile => 'Open file';

  @override
  String get goeicNumberLabel => 'GOEIC number';

  @override
  String get imageAttached => 'Image';
}
