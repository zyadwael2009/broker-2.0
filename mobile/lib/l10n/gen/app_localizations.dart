import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
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
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n? of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n);
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

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
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Wasit'**
  String get appTitle;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email (optional)'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get logout;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @roleBuyer.
  ///
  /// In en, this message translates to:
  /// **'Buyer / Renter'**
  String get roleBuyer;

  /// No description provided for @roleBroker.
  ///
  /// In en, this message translates to:
  /// **'Broker'**
  String get roleBroker;

  /// No description provided for @loginPromptRegister.
  ///
  /// In en, this message translates to:
  /// **'Don\'\'t have an account? Register'**
  String get loginPromptRegister;

  /// No description provided for @registerPromptLogin.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get registerPromptLogin;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordStep1Sub.
  ///
  /// In en, this message translates to:
  /// **'Enter the phone number on your account. We\'\'ll send you a 6-digit code.'**
  String get forgotPasswordStep1Sub;

  /// No description provided for @forgotPasswordStep2Sub.
  ///
  /// In en, this message translates to:
  /// **'Enter the code we sent to your phone plus a new password.'**
  String get forgotPasswordStep2Sub;

  /// No description provided for @forgotPasswordSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get forgotPasswordSendCode;

  /// No description provided for @forgotPasswordConfirmReset.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get forgotPasswordConfirmReset;

  /// No description provided for @forgotPasswordSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password reset. Sign in with your new password.'**
  String get forgotPasswordSuccess;

  /// No description provided for @verifyPhoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your phone'**
  String get verifyPhoneTitle;

  /// No description provided for @verifyPhoneSub.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {phone}. Enter it to verify your account.'**
  String verifyPhoneSub(String phone);

  /// No description provided for @verifyPhoneCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get verifyPhoneCodeLabel;

  /// No description provided for @verifyPhoneConfirm.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyPhoneConfirm;

  /// No description provided for @verifyPhoneResend.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get verifyPhoneResend;

  /// No description provided for @verifyPhoneResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String verifyPhoneResendIn(int seconds);

  /// No description provided for @verifyPhoneSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get verifyPhoneSkip;

  /// No description provided for @verifyPhoneSuccess.
  ///
  /// In en, this message translates to:
  /// **'Phone verified.'**
  String get verifyPhoneSuccess;

  /// No description provided for @verifyBannerText.
  ///
  /// In en, this message translates to:
  /// **'Verify your phone number to secure your account.'**
  String get verifyBannerText;

  /// No description provided for @verifyBannerCta.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyBannerCta;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'\'t match.'**
  String get passwordsDoNotMatch;

  /// No description provided for @codeIncorrect.
  ///
  /// In en, this message translates to:
  /// **'That code is incorrect or has expired.'**
  String get codeIncorrect;

  /// No description provided for @phoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number.'**
  String get phoneRequired;

  /// No description provided for @passwordMin8.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordMin8;

  /// No description provided for @namePleaseEnter.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get namePleaseEnter;

  /// No description provided for @phoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid phone number'**
  String get phoneInvalid;

  /// No description provided for @brokerDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Brokers start as unverified. Submit your GOEIC registration proof in the next step so an admin can review it. Only verified brokers show the trust badge on their listings.'**
  String get brokerDisclaimer;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Theme: system'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Theme: light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Theme: dark'**
  String get themeDark;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'Language: English'**
  String get languageEnglish;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'Language: العربية'**
  String get languageArabic;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Language: system'**
  String get languageSystem;

  /// No description provided for @verifyTitle.
  ///
  /// In en, this message translates to:
  /// **'My verification'**
  String get verifyTitle;

  /// No description provided for @verifyMyStatus.
  ///
  /// In en, this message translates to:
  /// **'My verification'**
  String get verifyMyStatus;

  /// No description provided for @verifyStatusVerifiedHeading.
  ///
  /// In en, this message translates to:
  /// **'Verified broker'**
  String get verifyStatusVerifiedHeading;

  /// No description provided for @verifyStatusPendingHeading.
  ///
  /// In en, this message translates to:
  /// **'Awaiting review'**
  String get verifyStatusPendingHeading;

  /// No description provided for @verifyStatusRejectedHeading.
  ///
  /// In en, this message translates to:
  /// **'Submission rejected'**
  String get verifyStatusRejectedHeading;

  /// No description provided for @verifyStatusPendingSub.
  ///
  /// In en, this message translates to:
  /// **'An admin will review your submission shortly.'**
  String get verifyStatusPendingSub;

  /// No description provided for @verifyStatusRejectedSub.
  ///
  /// In en, this message translates to:
  /// **'Update your document and submit again below.'**
  String get verifyStatusRejectedSub;

  /// No description provided for @verifyStatusVerifiedSubDated.
  ///
  /// In en, this message translates to:
  /// **'Verified on {date}. Your listings show a Verified badge.'**
  String verifyStatusVerifiedSubDated(String date);

  /// No description provided for @verifyStatusVerifiedSubUndated.
  ///
  /// In en, this message translates to:
  /// **'Your listings show a Verified badge.'**
  String get verifyStatusVerifiedSubUndated;

  /// No description provided for @reviewerNote.
  ///
  /// In en, this message translates to:
  /// **'REVIEWER NOTE'**
  String get reviewerNote;

  /// No description provided for @goeicField.
  ///
  /// In en, this message translates to:
  /// **'GOEIC registration number'**
  String get goeicField;

  /// No description provided for @goeicHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. EG-2024-08841'**
  String get goeicHint;

  /// No description provided for @registrationDetails.
  ///
  /// In en, this message translates to:
  /// **'Registration details'**
  String get registrationDetails;

  /// No description provided for @updateRegistration.
  ///
  /// In en, this message translates to:
  /// **'Update your registration'**
  String get updateRegistration;

  /// No description provided for @chooseDocument.
  ///
  /// In en, this message translates to:
  /// **'Choose registration document'**
  String get chooseDocument;

  /// No description provided for @documentAllowed.
  ///
  /// In en, this message translates to:
  /// **'PDF, JPG, PNG, or WEBP · max 20 MB'**
  String get documentAllowed;

  /// No description provided for @tapToReplace.
  ///
  /// In en, this message translates to:
  /// **'{size} · tap to replace'**
  String tapToReplace(String size);

  /// No description provided for @resubmitDocuments.
  ///
  /// In en, this message translates to:
  /// **'Resubmit documents'**
  String get resubmitDocuments;

  /// No description provided for @submitForReview.
  ///
  /// In en, this message translates to:
  /// **'Submit for review'**
  String get submitForReview;

  /// No description provided for @submitNewDocuments.
  ///
  /// In en, this message translates to:
  /// **'Submit new documents'**
  String get submitNewDocuments;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @verifyPickDocument.
  ///
  /// In en, this message translates to:
  /// **'Please select a registration document.'**
  String get verifyPickDocument;

  /// No description provided for @verifySubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted. An admin will review shortly.'**
  String get verifySubmitted;

  /// No description provided for @verifySubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Submission failed.'**
  String get verifySubmitFailed;

  /// No description provided for @verifyHonestNote.
  ///
  /// In en, this message translates to:
  /// **'Verification confirms your GOEIC registration was reviewed by our team. It does not replace independent legal verification.'**
  String get verifyHonestNote;

  /// No description provided for @myListings.
  ///
  /// In en, this message translates to:
  /// **'My listings'**
  String get myListings;

  /// No description provided for @browseListings.
  ///
  /// In en, this message translates to:
  /// **'Browse listings'**
  String get browseListings;

  /// No description provided for @newListing.
  ///
  /// In en, this message translates to:
  /// **'New listing'**
  String get newListing;

  /// No description provided for @priceTransparency.
  ///
  /// In en, this message translates to:
  /// **'Price transparency'**
  String get priceTransparency;

  /// No description provided for @unverifiedRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Your submission was rejected.'**
  String get unverifiedRejectedTitle;

  /// No description provided for @unverifiedNotYetTitle.
  ///
  /// In en, this message translates to:
  /// **'You need to be verified to post listings.'**
  String get unverifiedNotYetTitle;

  /// No description provided for @unverifiedRejectedSub.
  ///
  /// In en, this message translates to:
  /// **'Open your verification screen to review the reviewer\'\'s note and resubmit.'**
  String get unverifiedRejectedSub;

  /// No description provided for @unverifiedNotYetSub.
  ///
  /// In en, this message translates to:
  /// **'Submit your GOEIC registration document so our team can verify you. Only verified brokers can post listings — this is how buyers know they can trust you.'**
  String get unverifiedNotYetSub;

  /// No description provided for @openVerification.
  ///
  /// In en, this message translates to:
  /// **'Open verification'**
  String get openVerification;

  /// No description provided for @noListingsYet.
  ///
  /// In en, this message translates to:
  /// **'No listings yet'**
  String get noListingsYet;

  /// No description provided for @noListingsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap \"New listing\" to post your first property.'**
  String get noListingsHint;

  /// No description provided for @listingTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get listingTitle;

  /// No description provided for @listingDescription.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get listingDescription;

  /// No description provided for @listingPrice.
  ///
  /// In en, this message translates to:
  /// **'Price (EGP)'**
  String get listingPrice;

  /// No description provided for @listingArea.
  ///
  /// In en, this message translates to:
  /// **'Area (m²)'**
  String get listingArea;

  /// No description provided for @listingPropertyType.
  ///
  /// In en, this message translates to:
  /// **'Property type'**
  String get listingPropertyType;

  /// No description provided for @listingKindLabel.
  ///
  /// In en, this message translates to:
  /// **'Sale or rent'**
  String get listingKindLabel;

  /// No description provided for @listingKindSale.
  ///
  /// In en, this message translates to:
  /// **'For sale'**
  String get listingKindSale;

  /// No description provided for @listingKindRent.
  ///
  /// In en, this message translates to:
  /// **'For rent'**
  String get listingKindRent;

  /// No description provided for @listingBedrooms.
  ///
  /// In en, this message translates to:
  /// **'Bedrooms'**
  String get listingBedrooms;

  /// No description provided for @listingBathrooms.
  ///
  /// In en, this message translates to:
  /// **'Bathrooms'**
  String get listingBathrooms;

  /// No description provided for @listingFloor.
  ///
  /// In en, this message translates to:
  /// **'Floor'**
  String get listingFloor;

  /// No description provided for @listingCompound.
  ///
  /// In en, this message translates to:
  /// **'Compound'**
  String get listingCompound;

  /// No description provided for @listingCompoundHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Palm Hills, Rehab'**
  String get listingCompoundHint;

  /// No description provided for @listingFurnishedLabel.
  ///
  /// In en, this message translates to:
  /// **'Furnished'**
  String get listingFurnishedLabel;

  /// No description provided for @listingFurnishedYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get listingFurnishedYes;

  /// No description provided for @listingFurnishedNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get listingFurnishedNo;

  /// No description provided for @listingFurnishedUnspecified.
  ///
  /// In en, this message translates to:
  /// **'Unspecified'**
  String get listingFurnishedUnspecified;

  /// No description provided for @listingDeliveryLabel.
  ///
  /// In en, this message translates to:
  /// **'Delivery status'**
  String get listingDeliveryLabel;

  /// No description provided for @listingDeliveryUnspecified.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get listingDeliveryUnspecified;

  /// No description provided for @listingDeliveryReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to move in'**
  String get listingDeliveryReady;

  /// No description provided for @listingDeliveryUnderConstruction.
  ///
  /// In en, this message translates to:
  /// **'Under construction'**
  String get listingDeliveryUnderConstruction;

  /// No description provided for @filtersLabel.
  ///
  /// In en, this message translates to:
  /// **'FILTERS'**
  String get filtersLabel;

  /// No description provided for @filterAnyGov.
  ///
  /// In en, this message translates to:
  /// **'Any governorate'**
  String get filterAnyGov;

  /// No description provided for @filterAnyCity.
  ///
  /// In en, this message translates to:
  /// **'Any city'**
  String get filterAnyCity;

  /// No description provided for @filterBedroomsAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get filterBedroomsAny;

  /// No description provided for @filterPriceMin.
  ///
  /// In en, this message translates to:
  /// **'Min price'**
  String get filterPriceMin;

  /// No description provided for @filterPriceMax.
  ///
  /// In en, this message translates to:
  /// **'Max price'**
  String get filterPriceMax;

  /// No description provided for @filterApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get filterApply;

  /// No description provided for @filterReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get filterReset;

  /// No description provided for @shareWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Share on WhatsApp'**
  String get shareWhatsApp;

  /// No description provided for @whatsappOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open WhatsApp.'**
  String get whatsappOpenFailed;

  /// No description provided for @referralTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite fellow brokers'**
  String get referralTitle;

  /// No description provided for @referralShareText.
  ///
  /// In en, this message translates to:
  /// **'Join me on Wasit — the verified brokers platform for Egyptian real estate.'**
  String get referralShareText;

  /// No description provided for @referralCopied.
  ///
  /// In en, this message translates to:
  /// **'Referral link copied.'**
  String get referralCopied;

  /// No description provided for @referralJoinedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} joined'**
  String referralJoinedCount(int count);

  /// No description provided for @listingGovernorate.
  ///
  /// In en, this message translates to:
  /// **'Governorate'**
  String get listingGovernorate;

  /// No description provided for @listingCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get listingCity;

  /// No description provided for @listingDistrict.
  ///
  /// In en, this message translates to:
  /// **'District (optional)'**
  String get listingDistrict;

  /// No description provided for @listingLat.
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get listingLat;

  /// No description provided for @listingLng.
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get listingLng;

  /// No description provided for @useMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get useMyLocation;

  /// No description provided for @photosLabel.
  ///
  /// In en, this message translates to:
  /// **'PHOTOS'**
  String get photosLabel;

  /// No description provided for @locationLabel.
  ///
  /// In en, this message translates to:
  /// **'LOCATION'**
  String get locationLabel;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addPhoto;

  /// No description provided for @publishListing.
  ///
  /// In en, this message translates to:
  /// **'Publish listing'**
  String get publishListing;

  /// No description provided for @listingCreated.
  ///
  /// In en, this message translates to:
  /// **'Listing created.'**
  String get listingCreated;

  /// No description provided for @listingCreatedPartial.
  ///
  /// In en, this message translates to:
  /// **'Listing created — but only {uploaded} of {total} photo(s) uploaded ({reason}).'**
  String listingCreatedPartial(int uploaded, int total, String reason);

  /// No description provided for @createFailed.
  ///
  /// In en, this message translates to:
  /// **'Create failed: {reason}'**
  String createFailed(String reason);

  /// No description provided for @atLeastOnePhoto.
  ///
  /// In en, this message translates to:
  /// **'Add at least one photo of the property.'**
  String get atLeastOnePhoto;

  /// No description provided for @coordsRequired.
  ///
  /// In en, this message translates to:
  /// **'Add coordinates or tap \"Use my location\".'**
  String get coordsRequired;

  /// No description provided for @titleMin3.
  ///
  /// In en, this message translates to:
  /// **'At least 3 characters'**
  String get titleMin3;

  /// No description provided for @priceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid price'**
  String get priceInvalid;

  /// No description provided for @areaRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter area'**
  String get areaRequired;

  /// No description provided for @duplicatePhotoNote.
  ///
  /// In en, this message translates to:
  /// **'Photos matching another listing may be flagged for admin review. Upload your own photos of the actual property.'**
  String get duplicatePhotoNote;

  /// No description provided for @propertyApartment.
  ///
  /// In en, this message translates to:
  /// **'Apartment'**
  String get propertyApartment;

  /// No description provided for @propertyHouse.
  ///
  /// In en, this message translates to:
  /// **'House'**
  String get propertyHouse;

  /// No description provided for @propertyVilla.
  ///
  /// In en, this message translates to:
  /// **'Villa'**
  String get propertyVilla;

  /// No description provided for @propertyLand.
  ///
  /// In en, this message translates to:
  /// **'Land'**
  String get propertyLand;

  /// No description provided for @propertyCommercial.
  ///
  /// In en, this message translates to:
  /// **'Commercial'**
  String get propertyCommercial;

  /// No description provided for @statusVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get statusVerified;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get statusRejected;

  /// No description provided for @adminVerified.
  ///
  /// In en, this message translates to:
  /// **'Admin verified'**
  String get adminVerified;

  /// No description provided for @awaitingReview.
  ///
  /// In en, this message translates to:
  /// **'Awaiting review'**
  String get awaitingReview;

  /// No description provided for @selfReported.
  ///
  /// In en, this message translates to:
  /// **'Self-reported'**
  String get selfReported;

  /// No description provided for @notProvided.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get notProvided;

  /// No description provided for @priceLabel.
  ///
  /// In en, this message translates to:
  /// **'PRICE'**
  String get priceLabel;

  /// No description provided for @areaLabel.
  ///
  /// In en, this message translates to:
  /// **'AREA'**
  String get areaLabel;

  /// No description provided for @typeLabel.
  ///
  /// In en, this message translates to:
  /// **'TYPE'**
  String get typeLabel;

  /// No description provided for @aboutLabel.
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get aboutLabel;

  /// No description provided for @brokerLabel.
  ///
  /// In en, this message translates to:
  /// **'BROKER'**
  String get brokerLabel;

  /// No description provided for @propertyDocuments.
  ///
  /// In en, this message translates to:
  /// **'PROPERTY DOCUMENTS'**
  String get propertyDocuments;

  /// No description provided for @stillAvailable.
  ///
  /// In en, this message translates to:
  /// **'Still available'**
  String get stillAvailable;

  /// No description provided for @callBroker.
  ///
  /// In en, this message translates to:
  /// **'Call broker'**
  String get callBroker;

  /// No description provided for @buyerCallDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'This app assists with verification. Always confirm ownership and title with a lawyer or the notary office before paying anything.'**
  String get buyerCallDisclaimer;

  /// No description provided for @confirmedStillAvailable.
  ///
  /// In en, this message translates to:
  /// **'Marked as still available.'**
  String get confirmedStillAvailable;

  /// No description provided for @confirmFailed.
  ///
  /// In en, this message translates to:
  /// **'Confirm failed.'**
  String get confirmFailed;

  /// No description provided for @deleteListingTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete listing?'**
  String get deleteListingTitle;

  /// No description provided for @deleteListingBody.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone. Photos will also be removed.'**
  String get deleteListingBody;

  /// No description provided for @deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed.'**
  String get deleteFailed;

  /// No description provided for @noDialer.
  ///
  /// In en, this message translates to:
  /// **'No phone dialer available on this device.'**
  String get noDialer;

  /// No description provided for @dialerOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the dialer.'**
  String get dialerOpenFailed;

  /// No description provided for @postedOn.
  ///
  /// In en, this message translates to:
  /// **'Posted {date}'**
  String postedOn(String date);

  /// No description provided for @postedRecently.
  ///
  /// In en, this message translates to:
  /// **'Posted recently'**
  String get postedRecently;

  /// No description provided for @docsTitleDeed.
  ///
  /// In en, this message translates to:
  /// **'Title deed registered at notary'**
  String get docsTitleDeed;

  /// No description provided for @docsNoLiens.
  ///
  /// In en, this message translates to:
  /// **'No liens or disputes'**
  String get docsNoLiens;

  /// No description provided for @docsTaxClearance.
  ///
  /// In en, this message translates to:
  /// **'Tax clearance'**
  String get docsTaxClearance;

  /// No description provided for @docsHonestNote.
  ///
  /// In en, this message translates to:
  /// **'Verification confirms our admin reviewed the document — it does not replace a lawyer or the notary office. Self-reported entries have no verification behind them.'**
  String get docsHonestNote;

  /// No description provided for @uploadProof.
  ///
  /// In en, this message translates to:
  /// **'Upload proof'**
  String get uploadProof;

  /// No description provided for @replaceProof.
  ///
  /// In en, this message translates to:
  /// **'Replace proof document'**
  String get replaceProof;

  /// No description provided for @uploadProofSub.
  ///
  /// In en, this message translates to:
  /// **'An admin will review it before verifying.'**
  String get uploadProofSub;

  /// No description provided for @iHaveThisNoProof.
  ///
  /// In en, this message translates to:
  /// **'I have this — no proof yet'**
  String get iHaveThisNoProof;

  /// No description provided for @iHaveThisNoProofSub.
  ///
  /// In en, this message translates to:
  /// **'Shown to buyers as \"self-reported by the broker\".'**
  String get iHaveThisNoProofSub;

  /// No description provided for @docSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Uploaded. An admin will review it shortly.'**
  String get docSubmitted;

  /// No description provided for @docSelfReported.
  ///
  /// In en, this message translates to:
  /// **'Marked as self-reported.'**
  String get docSelfReported;

  /// No description provided for @docCleared.
  ///
  /// In en, this message translates to:
  /// **'Cleared.'**
  String get docCleared;

  /// No description provided for @actionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed.'**
  String get actionFailed;

  /// No description provided for @adminTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get adminTitle;

  /// No description provided for @brokersTab.
  ///
  /// In en, this message translates to:
  /// **'Brokers'**
  String get brokersTab;

  /// No description provided for @flaggedTab.
  ///
  /// In en, this message translates to:
  /// **'Flagged'**
  String get flaggedTab;

  /// No description provided for @docsTab.
  ///
  /// In en, this message translates to:
  /// **'Docs'**
  String get docsTab;

  /// No description provided for @filterPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get filterPending;

  /// No description provided for @filterVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get filterVerified;

  /// No description provided for @filterRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get filterRejected;

  /// No description provided for @noPendingBrokers.
  ///
  /// In en, this message translates to:
  /// **'No pending brokers — inbox zero.'**
  String get noPendingBrokers;

  /// No description provided for @noVerifiedBrokers.
  ///
  /// In en, this message translates to:
  /// **'No verified brokers yet.'**
  String get noVerifiedBrokers;

  /// No description provided for @noRejectedBrokers.
  ///
  /// In en, this message translates to:
  /// **'No rejected submissions.'**
  String get noRejectedBrokers;

  /// No description provided for @noFlagged.
  ///
  /// In en, this message translates to:
  /// **'No flagged listings.'**
  String get noFlagged;

  /// No description provided for @noPendingDocs.
  ///
  /// In en, this message translates to:
  /// **'No documents to review.'**
  String get noPendingDocs;

  /// No description provided for @rejectionReasonTitle.
  ///
  /// In en, this message translates to:
  /// **'Rejection reason'**
  String get rejectionReasonTitle;

  /// No description provided for @rejectionReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Explain what needs fixing — the broker will see this.'**
  String get rejectionReasonHint;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @brokerVerified.
  ///
  /// In en, this message translates to:
  /// **'Broker verified.'**
  String get brokerVerified;

  /// No description provided for @brokerRejected.
  ///
  /// In en, this message translates to:
  /// **'Broker rejected.'**
  String get brokerRejected;

  /// No description provided for @documentVerified.
  ///
  /// In en, this message translates to:
  /// **'Document verified.'**
  String get documentVerified;

  /// No description provided for @documentRejected.
  ///
  /// In en, this message translates to:
  /// **'Document rejected.'**
  String get documentRejected;

  /// No description provided for @approveFailed.
  ///
  /// In en, this message translates to:
  /// **'Approve failed.'**
  String get approveFailed;

  /// No description provided for @rejectFailed.
  ///
  /// In en, this message translates to:
  /// **'Reject failed.'**
  String get rejectFailed;

  /// No description provided for @unflag.
  ///
  /// In en, this message translates to:
  /// **'Unflag'**
  String get unflag;

  /// No description provided for @listingUnflagged.
  ///
  /// In en, this message translates to:
  /// **'Listing unflagged.'**
  String get listingUnflagged;

  /// No description provided for @unflagFailed.
  ///
  /// In en, this message translates to:
  /// **'Unflag failed.'**
  String get unflagFailed;

  /// No description provided for @goeicShort.
  ///
  /// In en, this message translates to:
  /// **'GOEIC no.'**
  String get goeicShort;

  /// No description provided for @lastUpdate.
  ///
  /// In en, this message translates to:
  /// **'Last update'**
  String get lastUpdate;

  /// No description provided for @previousRejectionReason.
  ///
  /// In en, this message translates to:
  /// **'PREVIOUS REJECTION REASON'**
  String get previousRejectionReason;

  /// No description provided for @registrationDocument.
  ///
  /// In en, this message translates to:
  /// **'REGISTRATION DOCUMENT'**
  String get registrationDocument;

  /// No description provided for @tapToOpen.
  ///
  /// In en, this message translates to:
  /// **'Tap to open in system viewer'**
  String get tapToOpen;

  /// No description provided for @brokerHasNotUploaded.
  ///
  /// In en, this message translates to:
  /// **'Broker has not uploaded yet'**
  String get brokerHasNotUploaded;

  /// No description provided for @noDocumentSubmitted.
  ///
  /// In en, this message translates to:
  /// **'No document submitted'**
  String get noDocumentSubmitted;

  /// No description provided for @couldNotOpenDocument.
  ///
  /// In en, this message translates to:
  /// **'Could not open document: {reason}'**
  String couldNotOpenDocument(String reason);

  /// No description provided for @duplicateSuspected.
  ///
  /// In en, this message translates to:
  /// **'Duplicate suspected'**
  String get duplicateSuspected;

  /// No description provided for @duplicateOf.
  ///
  /// In en, this message translates to:
  /// **'Duplicate of #{id}'**
  String duplicateOf(int id);

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @submittedRelative.
  ///
  /// In en, this message translates to:
  /// **'Submitted {when}'**
  String submittedRelative(String when);

  /// No description provided for @medianPricePerM2.
  ///
  /// In en, this message translates to:
  /// **'MEDIAN PRICE / m²'**
  String get medianPricePerM2;

  /// No description provided for @rangeLabel.
  ///
  /// In en, this message translates to:
  /// **'RANGE'**
  String get rangeLabel;

  /// No description provided for @middle50Label.
  ///
  /// In en, this message translates to:
  /// **'MIDDLE 50%'**
  String get middle50Label;

  /// No description provided for @listingsLabel.
  ///
  /// In en, this message translates to:
  /// **'LISTINGS'**
  String get listingsLabel;

  /// No description provided for @notEnoughListings.
  ///
  /// In en, this message translates to:
  /// **'Not enough listings match these filters.'**
  String get notEnoughListings;

  /// No description provided for @medianTrendTitle.
  ///
  /// In en, this message translates to:
  /// **'MEDIAN TREND — LAST 12 MONTHS'**
  String get medianTrendTitle;

  /// No description provided for @notEnoughMonthly.
  ///
  /// In en, this message translates to:
  /// **'Not enough monthly data yet — need at least two months with 2+ listings each.'**
  String get notEnoughMonthly;

  /// No description provided for @marketHonest.
  ///
  /// In en, this message translates to:
  /// **'Asking prices from verified brokers on this app, plus sold listings when reported. This is a market signal, not a valuation service — always confirm with a professional appraisal before you commit.'**
  String get marketHonest;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @expiryExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired · tap to reconfirm'**
  String get expiryExpired;

  /// No description provided for @expiryDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'Expires in {days}d'**
  String expiryDaysLeft(int days);

  /// No description provided for @expiryActive.
  ///
  /// In en, this message translates to:
  /// **'Active · {days} days left'**
  String expiryActive(int days);

  /// No description provided for @emptyBrowseTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching listings'**
  String get emptyBrowseTitle;

  /// No description provided for @emptyBrowseSub.
  ///
  /// In en, this message translates to:
  /// **'Try a different property type, or check back later.'**
  String get emptyBrowseSub;

  /// No description provided for @welcomeName.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}'**
  String welcomeName(String name);

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @messageBroker.
  ///
  /// In en, this message translates to:
  /// **'Message broker'**
  String get messageBroker;

  /// No description provided for @rateBroker.
  ///
  /// In en, this message translates to:
  /// **'Rate this broker'**
  String get rateBroker;

  /// No description provided for @rateBrokerSub.
  ///
  /// In en, this message translates to:
  /// **'How was your interaction so far?'**
  String get rateBrokerSub;

  /// No description provided for @rateStars.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 star} other{{count} stars}}'**
  String rateStars(int count);

  /// No description provided for @rateNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Share a note (optional)'**
  String get rateNoteLabel;

  /// No description provided for @rateNoteHint.
  ///
  /// In en, this message translates to:
  /// **'What went well, or what could improve?'**
  String get rateNoteHint;

  /// No description provided for @rateSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit rating'**
  String get rateSubmit;

  /// No description provided for @rateSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Thanks — your rating is public on the broker\'s profile.'**
  String get rateSubmitted;

  /// No description provided for @rateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not submit rating.'**
  String get rateFailed;

  /// No description provided for @rateEditMine.
  ///
  /// In en, this message translates to:
  /// **'Update my rating'**
  String get rateEditMine;

  /// No description provided for @rateRemoveMine.
  ///
  /// In en, this message translates to:
  /// **'Remove my rating'**
  String get rateRemoveMine;

  /// No description provided for @reviewsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviewsTitle;

  /// No description provided for @noReviewsYet.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet.'**
  String get noReviewsYet;

  /// No description provided for @basedOnRatings.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Based on 1 rating} other{Based on {count} ratings}}'**
  String basedOnRatings(int count);

  /// No description provided for @brokerProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Broker'**
  String get brokerProfileTitle;

  /// No description provided for @reportListing.
  ///
  /// In en, this message translates to:
  /// **'Report listing'**
  String get reportListing;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @shareLink.
  ///
  /// In en, this message translates to:
  /// **'Copy share link'**
  String get shareLink;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied to clipboard'**
  String get linkCopied;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @sharePublicProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Your public profile link'**
  String get sharePublicProfileTitle;

  /// No description provided for @sharePublicProfileCopied.
  ///
  /// In en, this message translates to:
  /// **'Public profile link copied'**
  String get sharePublicProfileCopied;

  /// No description provided for @reportBroker.
  ///
  /// In en, this message translates to:
  /// **'Report broker'**
  String get reportBroker;

  /// No description provided for @reportReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reportReason;

  /// No description provided for @reasonFraud.
  ///
  /// In en, this message translates to:
  /// **'Fraud or scam'**
  String get reasonFraud;

  /// No description provided for @reasonSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam'**
  String get reasonSpam;

  /// No description provided for @reasonInappropriate.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate content'**
  String get reasonInappropriate;

  /// No description provided for @reasonWrongInfo.
  ///
  /// In en, this message translates to:
  /// **'Wrong information'**
  String get reasonWrongInfo;

  /// No description provided for @reasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reasonOther;

  /// No description provided for @reportNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Anything else? (optional)'**
  String get reportNoteLabel;

  /// No description provided for @reportSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get reportSubmit;

  /// No description provided for @reportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Thanks — an admin will review this shortly.'**
  String get reportSubmitted;

  /// No description provided for @reportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not submit the report.'**
  String get reportFailed;

  /// No description provided for @reportCannotSelf.
  ///
  /// In en, this message translates to:
  /// **'You cannot report yourself.'**
  String get reportCannotSelf;

  /// No description provided for @adminReportsTab.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get adminReportsTab;

  /// No description provided for @adminReportsOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get adminReportsOpen;

  /// No description provided for @adminReportsResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get adminReportsResolved;

  /// No description provided for @adminReportsDismissed.
  ///
  /// In en, this message translates to:
  /// **'Dismissed'**
  String get adminReportsDismissed;

  /// No description provided for @adminReportAbout.
  ///
  /// In en, this message translates to:
  /// **'About: {target}'**
  String adminReportAbout(String target);

  /// No description provided for @adminReportedBy.
  ///
  /// In en, this message translates to:
  /// **'Reported by {name}'**
  String adminReportedBy(String name);

  /// No description provided for @adminDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get adminDismiss;

  /// No description provided for @adminResolveNoAction.
  ///
  /// In en, this message translates to:
  /// **'Resolve — no action'**
  String get adminResolveNoAction;

  /// No description provided for @adminTakeAction.
  ///
  /// In en, this message translates to:
  /// **'Take action'**
  String get adminTakeAction;

  /// No description provided for @adminResolveDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Resolve report'**
  String get adminResolveDialogTitle;

  /// No description provided for @adminResolveNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Resolution note (optional)'**
  String get adminResolveNoteLabel;

  /// No description provided for @adminReportResolved.
  ///
  /// In en, this message translates to:
  /// **'Report resolved.'**
  String get adminReportResolved;

  /// No description provided for @adminReportDismissed.
  ///
  /// In en, this message translates to:
  /// **'Report dismissed.'**
  String get adminReportDismissed;

  /// No description provided for @adminNoOpenReports.
  ///
  /// In en, this message translates to:
  /// **'No open reports.'**
  String get adminNoOpenReports;

  /// No description provided for @adminNoResolvedReports.
  ///
  /// In en, this message translates to:
  /// **'No resolved reports.'**
  String get adminNoResolvedReports;

  /// No description provided for @adminNoDismissedReports.
  ///
  /// In en, this message translates to:
  /// **'No dismissed reports.'**
  String get adminNoDismissedReports;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet.'**
  String get noMessagesYet;

  /// No description provided for @noMessagesYetSub.
  ///
  /// In en, this message translates to:
  /// **'When a buyer contacts you about a listing, it will appear here.'**
  String get noMessagesYetSub;

  /// No description provided for @noMessagesYetBuyerSub.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Message broker\" on any listing to start a conversation.'**
  String get noMessagesYetBuyerSub;

  /// No description provided for @sendMessagePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Write a message…'**
  String get sendMessagePlaceholder;

  /// No description provided for @sendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendMessage;

  /// No description provided for @cannotStartConversation.
  ///
  /// In en, this message translates to:
  /// **'Could not start conversation.'**
  String get cannotStartConversation;

  /// No description provided for @cannotLoadMessages.
  ///
  /// In en, this message translates to:
  /// **'Could not load messages.'**
  String get cannotLoadMessages;

  /// No description provided for @cannotSendMessage.
  ///
  /// In en, this message translates to:
  /// **'Could not send.'**
  String get cannotSendMessage;

  /// No description provided for @conversationWith.
  ///
  /// In en, this message translates to:
  /// **'About: {title}'**
  String conversationWith(String title);

  /// No description provided for @yourInbox.
  ///
  /// In en, this message translates to:
  /// **'Your inbox'**
  String get yourInbox;

  /// No description provided for @messagesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messagesTooltip;

  /// No description provided for @analyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your analytics'**
  String get analyticsTitle;

  /// No description provided for @analyticsViews7d.
  ///
  /// In en, this message translates to:
  /// **'Views (7 days)'**
  String get analyticsViews7d;

  /// No description provided for @analyticsViews30d.
  ///
  /// In en, this message translates to:
  /// **'Views (30 days)'**
  String get analyticsViews30d;

  /// No description provided for @analyticsMessages7d.
  ///
  /// In en, this message translates to:
  /// **'Messages (7 days)'**
  String get analyticsMessages7d;

  /// No description provided for @analyticsAvgRating.
  ///
  /// In en, this message translates to:
  /// **'Average rating'**
  String get analyticsAvgRating;

  /// No description provided for @analyticsChartLabel.
  ///
  /// In en, this message translates to:
  /// **'Views — last 30 days'**
  String get analyticsChartLabel;

  /// No description provided for @analyticsPerListing.
  ///
  /// In en, this message translates to:
  /// **'Per listing (this week)'**
  String get analyticsPerListing;

  /// No description provided for @analyticsError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your analytics.'**
  String get analyticsError;

  /// No description provided for @analyticsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No data yet — share your listings to start seeing views.'**
  String get analyticsEmpty;

  /// No description provided for @pdplConsent.
  ///
  /// In en, this message translates to:
  /// **'I consent to Wasit processing my GOEIC number and registration document for identity verification, under the Privacy Policy and Egypt\'s Personal Data Protection Law (151/2020).'**
  String get pdplConsent;

  /// No description provided for @signupTermsNotice.
  ///
  /// In en, this message translates to:
  /// **'By signing up you agree to our Terms and Privacy Policy.'**
  String get signupTermsNotice;

  /// No description provided for @termsLink.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get termsLink;

  /// No description provided for @privacyLink.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyLink;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppL10nAr();
    case 'en':
      return AppL10nEn();
  }

  throw FlutterError(
      'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
