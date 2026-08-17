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
  String get roleBuyer => 'Buyer / Renter';

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
}
