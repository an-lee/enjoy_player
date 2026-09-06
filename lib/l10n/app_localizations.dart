import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

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
    Locale('zh', 'CN'),
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Enjoy Player'**
  String get appTitle;

  /// No description provided for @libraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get libraryTitle;

  /// No description provided for @librarySourceLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get librarySourceLocal;

  /// No description provided for @librarySourceCloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get librarySourceCloud;

  /// No description provided for @librarySourceCloudEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get librarySourceCloudEyebrow;

  /// No description provided for @librarySourceSwitchSemantics.
  ///
  /// In en, this message translates to:
  /// **'Library source'**
  String get librarySourceSwitchSemantics;

  /// No description provided for @librarySourceToggleToCloud.
  ///
  /// In en, this message translates to:
  /// **'Switch to cloud'**
  String get librarySourceToggleToCloud;

  /// No description provided for @librarySourceToggleToLocal.
  ///
  /// In en, this message translates to:
  /// **'Switch to local'**
  String get librarySourceToggleToLocal;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTitle;

  /// No description provided for @homeRecentMedia.
  ///
  /// In en, this message translates to:
  /// **'Recent media'**
  String get homeRecentMedia;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No recent media'**
  String get homeEmptyTitle;

  /// No description provided for @homeContinuePracticing.
  ///
  /// In en, this message translates to:
  /// **'Continue practicing'**
  String get homeContinuePracticing;

  /// No description provided for @homeContinueProgressSemantics.
  ///
  /// In en, this message translates to:
  /// **'{percent} percent complete'**
  String homeContinueProgressSemantics(int percent);

  /// No description provided for @homeContinueOpenSemantics.
  ///
  /// In en, this message translates to:
  /// **'Continue practicing, {title}'**
  String homeContinueOpenSemantics(String title);

  /// No description provided for @homeEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Import media or drop a file here to start.'**
  String get homeEmptyHint;

  /// No description provided for @libraryTabAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get libraryTabAudio;

  /// No description provided for @libraryTabVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get libraryTabVideo;

  /// No description provided for @libraryEmptyAudioTitle.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find any audio'**
  String get libraryEmptyAudioTitle;

  /// No description provided for @libraryEmptyAudioHint.
  ///
  /// In en, this message translates to:
  /// **'Your library doesn\'t contain any audio content.'**
  String get libraryEmptyAudioHint;

  /// No description provided for @libraryEmptyVideoTitle.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find any videos'**
  String get libraryEmptyVideoTitle;

  /// No description provided for @libraryEmptyVideoHint.
  ///
  /// In en, this message translates to:
  /// **'Your library doesn\'t contain any video content.'**
  String get libraryEmptyVideoHint;

  /// No description provided for @librarySearchNoMatchesTitle.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get librarySearchNoMatchesTitle;

  /// No description provided for @librarySearchNoMatchesHint.
  ///
  /// In en, this message translates to:
  /// **'Nothing in your library matches this search.'**
  String get librarySearchNoMatchesHint;

  /// No description provided for @librarySearchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get librarySearchClear;

  /// No description provided for @libraryDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not remove this item. Try again.'**
  String get libraryDeleteFailed;

  /// No description provided for @transcriptAccessibilityTranscriptList.
  ///
  /// In en, this message translates to:
  /// **'Transcript'**
  String get transcriptAccessibilityTranscriptList;

  /// No description provided for @transcriptAccessibilityCue.
  ///
  /// In en, this message translates to:
  /// **'{time}. {snippet}'**
  String transcriptAccessibilityCue(String time, String snippet);

  /// No description provided for @transcriptAccessibilityCurrentLine.
  ///
  /// In en, this message translates to:
  /// **'Current playback line.'**
  String get transcriptAccessibilityCurrentLine;

  /// No description provided for @transcriptAccessibilityEchoRegion.
  ///
  /// In en, this message translates to:
  /// **'Echo practice region.'**
  String get transcriptAccessibilityEchoRegion;

  /// No description provided for @transcriptAccessibilityEchoCurrentLine.
  ///
  /// In en, this message translates to:
  /// **'Current echo line.'**
  String get transcriptAccessibilityEchoCurrentLine;

  /// No description provided for @transcriptLineRecordingCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 recording} other{{count} recordings}}'**
  String transcriptLineRecordingCount(int count);

  /// No description provided for @transcriptErrorFriendlyTitle.
  ///
  /// In en, this message translates to:
  /// **'Transcript unavailable'**
  String get transcriptErrorFriendlyTitle;

  /// No description provided for @transcriptErrorFriendlyHint.
  ///
  /// In en, this message translates to:
  /// **'Try choosing another subtitle track or importing a file.'**
  String get transcriptErrorFriendlyHint;

  /// No description provided for @transcriptFetchingSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Fetching subtitles…'**
  String get transcriptFetchingSubtitles;

  /// No description provided for @asrStatusExtracting.
  ///
  /// In en, this message translates to:
  /// **'Extracting audio…'**
  String get asrStatusExtracting;

  /// No description provided for @asrStatusUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading audio…'**
  String get asrStatusUploading;

  /// No description provided for @asrLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Spoken language'**
  String get asrLanguageTitle;

  /// No description provided for @asrLanguageAutoDetect.
  ///
  /// In en, this message translates to:
  /// **'Auto-detect language'**
  String get asrLanguageAutoDetect;

  /// No description provided for @asrStatusRecognizing.
  ///
  /// In en, this message translates to:
  /// **'Recognizing…'**
  String get asrStatusRecognizing;

  /// No description provided for @asrStatusPolling.
  ///
  /// In en, this message translates to:
  /// **'Transcribing…'**
  String get asrStatusPolling;

  /// No description provided for @asrStatusSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get asrStatusSaving;

  /// No description provided for @asrStatusSuccess.
  ///
  /// In en, this message translates to:
  /// **'Transcript ready'**
  String get asrStatusSuccess;

  /// No description provided for @asrStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get asrStatusCancelled;

  /// No description provided for @asrErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t generate transcript'**
  String get asrErrorGeneric;

  /// No description provided for @asrErrorFfmpegUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Audio extraction isn\'t available on this device'**
  String get asrErrorFfmpegUnavailable;

  /// No description provided for @asrErrorFfmpegUnavailableHint.
  ///
  /// In en, this message translates to:
  /// **'Install ffmpeg or use a different video file.'**
  String get asrErrorFfmpegUnavailableHint;

  /// No description provided for @asrErrorNoAudioTrack.
  ///
  /// In en, this message translates to:
  /// **'This file has no audio to transcribe'**
  String get asrErrorNoAudioTrack;

  /// No description provided for @asrErrorExtractionFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t extract audio. Please try again.'**
  String get asrErrorExtractionFailed;

  /// No description provided for @asrErrorFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This file is too large to transcribe'**
  String get asrErrorFileTooLarge;

  /// No description provided for @asrErrorUnsupportedSource.
  ///
  /// In en, this message translates to:
  /// **'This source isn\'t supported'**
  String get asrErrorUnsupportedSource;

  /// No description provided for @asrErrorUnsupportedMedia.
  ///
  /// In en, this message translates to:
  /// **'This audio format isn\'t supported for long transcription'**
  String get asrErrorUnsupportedMedia;

  /// No description provided for @asrErrorProviderTimeout.
  ///
  /// In en, this message translates to:
  /// **'Transcription timed out. Please try again.'**
  String get asrErrorProviderTimeout;

  /// No description provided for @asrErrorProviderRetryable.
  ///
  /// In en, this message translates to:
  /// **'Transcription failed. Please try again.'**
  String get asrErrorProviderRetryable;

  /// No description provided for @asrErrorByokMissing.
  ///
  /// In en, this message translates to:
  /// **'Set up your AI provider to generate a transcript'**
  String get asrErrorByokMissing;

  /// No description provided for @asrErrorByokMissingHint.
  ///
  /// In en, this message translates to:
  /// **'Open Settings → AI Providers to add credentials.'**
  String get asrErrorByokMissingHint;

  /// No description provided for @asrErrorCreditsExhausted.
  ///
  /// In en, this message translates to:
  /// **'You\'ve used all your Enjoy credits'**
  String get asrErrorCreditsExhausted;

  /// No description provided for @asrErrorCreditsExhaustedHint.
  ///
  /// In en, this message translates to:
  /// **'Upgrade your plan to keep generating transcripts.'**
  String get asrErrorCreditsExhaustedHint;

  /// No description provided for @asrErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection and retry.'**
  String get asrErrorNetwork;

  /// No description provided for @asrErrorNoSpeech.
  ///
  /// In en, this message translates to:
  /// **'No speech detected in this audio'**
  String get asrErrorNoSpeech;

  /// No description provided for @asrLongMediaConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'This may take a while'**
  String get asrLongMediaConfirmTitle;

  /// No description provided for @asrLongMediaConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Generating a transcript for {minutes} minutes of audio may take several minutes and consume significant credits. Continue?'**
  String asrLongMediaConfirmBody(int minutes);

  /// No description provided for @asrLongMediaConfirmContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get asrLongMediaConfirmContinue;

  /// No description provided for @asrLongMediaConfirmCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get asrLongMediaConfirmCancel;

  /// No description provided for @actionOpenFiles.
  ///
  /// In en, this message translates to:
  /// **'Open file(s)'**
  String get actionOpenFiles;

  /// No description provided for @actionImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get actionImport;

  /// No description provided for @importFromFile.
  ///
  /// In en, this message translates to:
  /// **'From file…'**
  String get importFromFile;

  /// No description provided for @importFromYoutube.
  ///
  /// In en, this message translates to:
  /// **'From YouTube URL…'**
  String get importFromYoutube;

  /// No description provided for @discoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discoverTitle;

  /// No description provided for @discoverBrowseAction.
  ///
  /// In en, this message translates to:
  /// **'Browse Discover'**
  String get discoverBrowseAction;

  /// No description provided for @discoverRecommendedHeading.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get discoverRecommendedHeading;

  /// No description provided for @discoverSubscriptionsHeading.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get discoverSubscriptionsHeading;

  /// No description provided for @discoverTimelineHeading.
  ///
  /// In en, this message translates to:
  /// **'Recent uploads'**
  String get discoverTimelineHeading;

  /// No description provided for @discoverSubscribeTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to channel'**
  String get discoverSubscribeTitle;

  /// No description provided for @discoverSubscribeHint.
  ///
  /// In en, this message translates to:
  /// **'Paste a YouTube channel URL or @handle.'**
  String get discoverSubscribeHint;

  /// No description provided for @discoverSubscribePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'https://www.youtube.com/@channel'**
  String get discoverSubscribePlaceholder;

  /// No description provided for @discoverSubscribeAction.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get discoverSubscribeAction;

  /// No description provided for @discoverSubscribed.
  ///
  /// In en, this message translates to:
  /// **'Subscribed to channel'**
  String get discoverSubscribed;

  /// No description provided for @discoverSubscribedLabel.
  ///
  /// In en, this message translates to:
  /// **'Subscribed'**
  String get discoverSubscribedLabel;

  /// No description provided for @discoverSubscribeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not subscribe to that channel.'**
  String get discoverSubscribeFailed;

  /// No description provided for @discoverUnsubscribeAction.
  ///
  /// In en, this message translates to:
  /// **'Unsubscribe'**
  String get discoverUnsubscribeAction;

  /// No description provided for @discoverUnsubscribed.
  ///
  /// In en, this message translates to:
  /// **'Unsubscribed from channel'**
  String get discoverUnsubscribed;

  /// No description provided for @discoverViewFeed.
  ///
  /// In en, this message translates to:
  /// **'View feed'**
  String get discoverViewFeed;

  /// No description provided for @discoverAddToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Add to library'**
  String get discoverAddToLibrary;

  /// No description provided for @discoverAddedToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Added to your library'**
  String get discoverAddedToLibrary;

  /// No description provided for @discoverAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not add this video.'**
  String get discoverAddFailed;

  /// No description provided for @discoverInLibrary.
  ///
  /// In en, this message translates to:
  /// **'In library'**
  String get discoverInLibrary;

  /// No description provided for @discoverPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get discoverPlay;

  /// No description provided for @discoverFeedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No videos in feed yet'**
  String get discoverFeedEmptyTitle;

  /// No description provided for @discoverFeedEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to a channel and refresh to load recent uploads.'**
  String get discoverFeedEmptyHint;

  /// No description provided for @discoverFeedErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load feed'**
  String get discoverFeedErrorTitle;

  /// No description provided for @discoverFeedErrorHint.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get discoverFeedErrorHint;

  /// No description provided for @discoverRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get discoverRetry;

  /// No description provided for @discoverRefreshPartialFailed.
  ///
  /// In en, this message translates to:
  /// **'Some channel feeds could not be refreshed.'**
  String get discoverRefreshPartialFailed;

  /// No description provided for @discoverRefreshPartialFailedDetail.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh {count, plural, one{1 channel} other{{count} channels}}: {names}'**
  String discoverRefreshPartialFailedDetail(int count, String names);

  /// No description provided for @discoverRefreshSingleFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh {name}.'**
  String discoverRefreshSingleFailed(Object name);

  /// No description provided for @discoverRecommendedLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load recommended channels.'**
  String get discoverRecommendedLoadFailed;

  /// No description provided for @discoverSubscriptionsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load subscriptions.'**
  String get discoverSubscriptionsLoadFailed;

  /// No description provided for @discoverNoSubscriptionsHint.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to a recommended channel or paste a channel URL.'**
  String get discoverNoSubscriptionsHint;

  /// No description provided for @discoverManageChannels.
  ///
  /// In en, this message translates to:
  /// **'Manage channels'**
  String get discoverManageChannels;

  /// No description provided for @discoverFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get discoverFilterAll;

  /// No description provided for @discoverYourChannelsHeading.
  ///
  /// In en, this message translates to:
  /// **'Your channels'**
  String get discoverYourChannelsHeading;

  /// No description provided for @discoverRecommendedAllSubscribed.
  ///
  /// In en, this message translates to:
  /// **'You are subscribed to all recommended channels.'**
  String get discoverRecommendedAllSubscribed;

  /// No description provided for @discoverSourceNotFound.
  ///
  /// In en, this message translates to:
  /// **'This YouTube source could not be found.'**
  String get discoverSourceNotFound;

  /// No description provided for @discoverSourceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This source is no longer available (deleted or private).'**
  String get discoverSourceUnavailable;

  /// No description provided for @discoverNetworkError.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Check your network and try again.'**
  String get discoverNetworkError;

  /// No description provided for @discoverWorkerError.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the feed server. Try again later.'**
  String get discoverWorkerError;

  /// No description provided for @discoverInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Could not read a valid YouTube URL. Try a channel, @handle, or playlist link.'**
  String get discoverInvalidUrl;

  /// No description provided for @discoverAlreadySubscribed.
  ///
  /// In en, this message translates to:
  /// **'Already subscribed to this source.'**
  String get discoverAlreadySubscribed;

  /// No description provided for @discoverSourceTypeChannel.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get discoverSourceTypeChannel;

  /// No description provided for @discoverSourceTypePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get discoverSourceTypePlaylist;

  /// No description provided for @youtubeImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import YouTube video'**
  String get youtubeImportTitle;

  /// No description provided for @youtubeImportHint.
  ///
  /// In en, this message translates to:
  /// **'Paste a YouTube link or video ID'**
  String get youtubeImportHint;

  /// No description provided for @youtubeImportInvalid.
  ///
  /// In en, this message translates to:
  /// **'Could not read a valid YouTube video ID.'**
  String get youtubeImportInvalid;

  /// No description provided for @youtubeImporting.
  ///
  /// In en, this message translates to:
  /// **'Adding video…'**
  String get youtubeImporting;

  /// No description provided for @youtubeBadge.
  ///
  /// In en, this message translates to:
  /// **'YouTube'**
  String get youtubeBadge;

  /// No description provided for @youtubeLoginTooltip.
  ///
  /// In en, this message translates to:
  /// **'YouTube account'**
  String get youtubeLoginTooltip;

  /// No description provided for @youtubeOpenInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get youtubeOpenInBrowser;

  /// No description provided for @youtubeLoginClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get youtubeLoginClose;

  /// No description provided for @youtubeLoginScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'YouTube sign-in'**
  String get youtubeLoginScreenTitle;

  /// No description provided for @youtubeLogout.
  ///
  /// In en, this message translates to:
  /// **'Sign out (clear cookies)'**
  String get youtubeLogout;

  /// No description provided for @youtubeLinuxUnavailable.
  ///
  /// In en, this message translates to:
  /// **'YouTube is not yet available on Linux — coming soon.'**
  String get youtubeLinuxUnavailable;

  /// Overlay when YouTube autoplay needs a user gesture or playback stopped immediately after play
  ///
  /// In en, this message translates to:
  /// **'Tap the video to play'**
  String get youtubeTapToPlayHint;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchHint;

  /// No description provided for @transportRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get transportRepeat;

  /// No description provided for @transportFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get transportFullscreen;

  /// No description provided for @transportExitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit fullscreen'**
  String get transportExitFullscreen;

  /// No description provided for @transportMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get transportMore;

  /// No description provided for @transportCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse player'**
  String get transportCollapse;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @importMedia.
  ///
  /// In en, this message translates to:
  /// **'Import media'**
  String get importMedia;

  /// No description provided for @importingMedia.
  ///
  /// In en, this message translates to:
  /// **'Importing media…'**
  String get importingMedia;

  /// No description provided for @importMediaFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not import this file.'**
  String get importMediaFailed;

  /// No description provided for @importUnsupportedFileType.
  ///
  /// In en, this message translates to:
  /// **'This file type isn’t supported. Choose an audio or video file.'**
  String get importUnsupportedFileType;

  /// No description provided for @noMediaYet.
  ///
  /// In en, this message translates to:
  /// **'No media yet'**
  String get noMediaYet;

  /// No description provided for @tapImportToAdd.
  ///
  /// In en, this message translates to:
  /// **'Import audio or video from the toolbar.'**
  String get tapImportToAdd;

  /// No description provided for @navMainLabel.
  ///
  /// In en, this message translates to:
  /// **'Primary navigation'**
  String get navMainLabel;

  /// No description provided for @miniPlayerMediaVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get miniPlayerMediaVideo;

  /// No description provided for @miniPlayerMediaAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get miniPlayerMediaAudio;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsAppearanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme follows your system settings.'**
  String get settingsAppearanceSubtitle;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// No description provided for @settingsAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enjoy Player — local transcripts and shadow reading.'**
  String get settingsAboutSubtitle;

  /// No description provided for @settingsThemeRowTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeRowTitle;

  /// No description provided for @settingsThemeDarkLocked.
  ///
  /// In en, this message translates to:
  /// **'Follows your system appearance.'**
  String get settingsThemeDarkLocked;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @previousLine.
  ///
  /// In en, this message translates to:
  /// **'Previous line'**
  String get previousLine;

  /// No description provided for @nextLine.
  ///
  /// In en, this message translates to:
  /// **'Next line'**
  String get nextLine;

  /// No description provided for @replayLine.
  ///
  /// In en, this message translates to:
  /// **'Replay line'**
  String get replayLine;

  /// No description provided for @echoMode.
  ///
  /// In en, this message translates to:
  /// **'Echo mode'**
  String get echoMode;

  /// No description provided for @exitEchoMode.
  ///
  /// In en, this message translates to:
  /// **'Exit echo mode'**
  String get exitEchoMode;

  /// No description provided for @transcript.
  ///
  /// In en, this message translates to:
  /// **'Transcript'**
  String get transcript;

  /// No description provided for @transcriptNowReading.
  ///
  /// In en, this message translates to:
  /// **'Now reading'**
  String get transcriptNowReading;

  /// No description provided for @playerTranscriptResizeHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to resize the transcript panel'**
  String get playerTranscriptResizeHint;

  /// No description provided for @importSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import subtitle'**
  String get importSubtitle;

  /// No description provided for @noTranscript.
  ///
  /// In en, this message translates to:
  /// **'No transcript yet'**
  String get noTranscript;

  /// No description provided for @importSrtOrVtt.
  ///
  /// In en, this message translates to:
  /// **'Import an .srt or .vtt file.'**
  String get importSrtOrVtt;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @playerOpenGenericError.
  ///
  /// In en, this message translates to:
  /// **'Could not open this item.'**
  String get playerOpenGenericError;

  /// No description provided for @playbackRateTimes.
  ///
  /// In en, this message translates to:
  /// **'{rate}x'**
  String playbackRateTimes(String rate);

  /// No description provided for @speed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get speed;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @transportMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get transportMute;

  /// No description provided for @transportUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get transportUnmute;

  /// No description provided for @repeatNone.
  ///
  /// In en, this message translates to:
  /// **'Repeat off'**
  String get repeatNone;

  /// No description provided for @repeatSegment.
  ///
  /// In en, this message translates to:
  /// **'Repeat segment'**
  String get repeatSegment;

  /// No description provided for @settingsPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Player preferences will appear here.'**
  String get settingsPlaceholder;

  /// No description provided for @subtitles.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get subtitles;

  /// No description provided for @subtitlesPrimary.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get subtitlesPrimary;

  /// No description provided for @subtitlesTranslation.
  ///
  /// In en, this message translates to:
  /// **'Translation (optional)'**
  String get subtitlesTranslation;

  /// No description provided for @subtitlesNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get subtitlesNone;

  /// No description provided for @subtitlesNotSelected.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get subtitlesNotSelected;

  /// No description provided for @subtitlesImportFile.
  ///
  /// In en, this message translates to:
  /// **'Import subtitle file…'**
  String get subtitlesImportFile;

  /// No description provided for @subtitlesDeleteTrack.
  ///
  /// In en, this message translates to:
  /// **'Delete track'**
  String get subtitlesDeleteTrack;

  /// No description provided for @importSubtitleSuccess.
  ///
  /// In en, this message translates to:
  /// **'Subtitle imported'**
  String get importSubtitleSuccess;

  /// No description provided for @noTranscriptHint.
  ///
  /// In en, this message translates to:
  /// **'Add a subtitle file, extract embedded captions, or create an AI transcript.'**
  String get noTranscriptHint;

  /// No description provided for @noTranscriptHintRemote.
  ///
  /// In en, this message translates to:
  /// **'Cloud captions load automatically when available. Open the CC menu to refresh.'**
  String get noTranscriptHintRemote;

  /// No description provided for @transcriptEmptyExtract.
  ///
  /// In en, this message translates to:
  /// **'Extract'**
  String get transcriptEmptyExtract;

  /// No description provided for @transcriptEmptyAddSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add subtitle'**
  String get transcriptEmptyAddSubtitle;

  /// No description provided for @transcriptEmptyGenerate.
  ///
  /// In en, this message translates to:
  /// **'AI transcript'**
  String get transcriptEmptyGenerate;

  /// No description provided for @subtitlesGenerate.
  ///
  /// In en, this message translates to:
  /// **'AI transcript'**
  String get subtitlesGenerate;

  /// No description provided for @subtitlesRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Re-generate transcript'**
  String get subtitlesRegenerate;

  /// No description provided for @subtitlesExtractEmbedded.
  ///
  /// In en, this message translates to:
  /// **'Extract embedded subtitles'**
  String get subtitlesExtractEmbedded;

  /// No description provided for @subtitlesRefreshCloud.
  ///
  /// In en, this message translates to:
  /// **'Refresh transcripts from cloud'**
  String get subtitlesRefreshCloud;

  /// No description provided for @subtitlesImportLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitle language'**
  String get subtitlesImportLanguageTitle;

  /// No description provided for @subtitlesImportLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'BCP-47 code (e.g. en, zh-TW). Use und if unknown.'**
  String get subtitlesImportLanguageHint;

  /// No description provided for @subtitlesImportLanguageFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Language code'**
  String get subtitlesImportLanguageFieldLabel;

  /// No description provided for @subtitlesProviderOfficial.
  ///
  /// In en, this message translates to:
  /// **'Official'**
  String get subtitlesProviderOfficial;

  /// No description provided for @subtitlesProviderAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get subtitlesProviderAuto;

  /// No description provided for @subtitlesProviderAi.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get subtitlesProviderAi;

  /// No description provided for @subtitlesProviderUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get subtitlesProviderUser;

  /// No description provided for @subtitlesAutoTranslate.
  ///
  /// In en, this message translates to:
  /// **'Auto translate'**
  String get subtitlesAutoTranslate;

  /// No description provided for @subtitlesAutoTranslateLanguageChip.
  ///
  /// In en, this message translates to:
  /// **'To {language}'**
  String subtitlesAutoTranslateLanguageChip(String language);

  /// No description provided for @subtitlesAutoTranslateRetranslateLine.
  ///
  /// In en, this message translates to:
  /// **'Re-translate this line'**
  String get subtitlesAutoTranslateRetranslateLine;

  /// No description provided for @subtitlesAutoTranslateBlockedStalePrimary.
  ///
  /// In en, this message translates to:
  /// **'The primary subtitle changed. Auto translate will rebuild from the new primary.'**
  String get subtitlesAutoTranslateBlockedStalePrimary;

  /// No description provided for @subtitlesAutoTranslateLineFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t translate this line'**
  String get subtitlesAutoTranslateLineFailed;

  /// No description provided for @subtitlesAutoTranslatePendingLine.
  ///
  /// In en, this message translates to:
  /// **'Translating…'**
  String get subtitlesAutoTranslatePendingLine;

  /// No description provided for @subtitlesAutoTranslateBlockedSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Sign in to use auto translate.'**
  String get subtitlesAutoTranslateBlockedSignedOut;

  /// No description provided for @subtitlesAutoTranslateBlockedSameLanguage.
  ///
  /// In en, this message translates to:
  /// **'Auto translate is not needed when your native language matches the primary subtitle.'**
  String get subtitlesAutoTranslateBlockedSameLanguage;

  /// No description provided for @subtitlesAutoTranslateBlockedNoPrimary.
  ///
  /// In en, this message translates to:
  /// **'Choose a primary subtitle first.'**
  String get subtitlesAutoTranslateBlockedNoPrimary;

  /// No description provided for @subtitlesAutoTranslateBlockedCredits.
  ///
  /// In en, this message translates to:
  /// **'Not enough credits to translate. Check your subscription.'**
  String get subtitlesAutoTranslateBlockedCredits;

  /// No description provided for @subtitlesExtractNoTracks.
  ///
  /// In en, this message translates to:
  /// **'No embedded subtitle tracks in this file (only video and audio). If you have a separate .srt or .vtt, use Import file.'**
  String get subtitlesExtractNoTracks;

  /// No description provided for @subtitlesExtractedCount.
  ///
  /// In en, this message translates to:
  /// **'Extracted {count} subtitle track(s).'**
  String subtitlesExtractedCount(int count);

  /// No description provided for @subtitlesRefreshDone.
  ///
  /// In en, this message translates to:
  /// **'Transcripts updated from cloud.'**
  String get subtitlesRefreshDone;

  /// No description provided for @subtitlesNoPlayableUri.
  ///
  /// In en, this message translates to:
  /// **'Could not resolve a playable file for this item.'**
  String get subtitlesNoPlayableUri;

  /// No description provided for @expandEchoBackward.
  ///
  /// In en, this message translates to:
  /// **'Expand echo backward'**
  String get expandEchoBackward;

  /// No description provided for @expandEchoForward.
  ///
  /// In en, this message translates to:
  /// **'Expand echo forward'**
  String get expandEchoForward;

  /// No description provided for @shrinkEchoBackward.
  ///
  /// In en, this message translates to:
  /// **'Shrink echo backward'**
  String get shrinkEchoBackward;

  /// No description provided for @shrinkEchoForward.
  ///
  /// In en, this message translates to:
  /// **'Shrink echo forward'**
  String get shrinkEchoForward;

  /// No description provided for @shadowReadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Shadow reading'**
  String get shadowReadingTitle;

  /// No description provided for @shadowReadingHint.
  ///
  /// In en, this message translates to:
  /// **'Practice speaking along this segment. Record your voice and compare pitch with the reference.'**
  String get shadowReadingHint;

  /// No description provided for @shadowReadingReferenceSnippet.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get shadowReadingReferenceSnippet;

  /// No description provided for @pitchContourTitle.
  ///
  /// In en, this message translates to:
  /// **'Pitch contour'**
  String get pitchContourTitle;

  /// No description provided for @pitchContourError.
  ///
  /// In en, this message translates to:
  /// **'Could not analyze pitch for this segment.'**
  String get pitchContourError;

  /// No description provided for @pitchContourWaveform.
  ///
  /// In en, this message translates to:
  /// **'Waveform'**
  String get pitchContourWaveform;

  /// No description provided for @pitchContourReference.
  ///
  /// In en, this message translates to:
  /// **'Reference pitch'**
  String get pitchContourReference;

  /// No description provided for @pitchContourUser.
  ///
  /// In en, this message translates to:
  /// **'Your pitch'**
  String get pitchContourUser;

  /// No description provided for @pitchContourAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing pitch…'**
  String get pitchContourAnalyzing;

  /// No description provided for @shadowRecordingExisting.
  ///
  /// In en, this message translates to:
  /// **'Saved takes'**
  String get shadowRecordingExisting;

  /// No description provided for @shadowRecordingEmpty.
  ///
  /// In en, this message translates to:
  /// **'No recordings for this segment yet.'**
  String get shadowRecordingEmpty;

  /// No description provided for @shadowRecordingTake.
  ///
  /// In en, this message translates to:
  /// **'Take'**
  String get shadowRecordingTake;

  /// No description provided for @shadowRecordingPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get shadowRecordingPlay;

  /// No description provided for @shadowRecordingPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get shadowRecordingPause;

  /// No description provided for @shadowRecordingChooseTake.
  ///
  /// In en, this message translates to:
  /// **'Switch take'**
  String get shadowRecordingChooseTake;

  /// No description provided for @shadowRecordingDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get shadowRecordingDelete;

  /// No description provided for @shadowRecordingDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this take?'**
  String get shadowRecordingDeleteConfirmTitle;

  /// No description provided for @shadowRecordingDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'{takeLabel} will be permanently deleted. This cannot be undone.'**
  String shadowRecordingDeleteConfirmMessage(String takeLabel);

  /// No description provided for @shadowRecordingRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get shadowRecordingRecord;

  /// No description provided for @shadowRecordingStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get shadowRecordingStop;

  /// No description provided for @shadowRecordingMicDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is required to record.'**
  String get shadowRecordingMicDenied;

  /// Save failed after recording stopped; reason is a short technical detail.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save recording: {reason}'**
  String shadowRecordingSaveFailed(String reason);

  /// Header for the AI provider settings section.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get settingsSectionAi;

  /// Subtitle under the AI settings section header.
  ///
  /// In en, this message translates to:
  /// **'Choose Enjoy AI or bring your own API keys.'**
  String get settingsSectionAiHint;

  /// Settings tile title for AI provider configuration.
  ///
  /// In en, this message translates to:
  /// **'AI providers'**
  String get settingsAiProvidersTileTitle;

  /// Settings tile subtitle for AI provider configuration.
  ///
  /// In en, this message translates to:
  /// **'Enjoy AI by default, or use your own keys per feature'**
  String get settingsAiProvidersTileSubtitle;

  /// Screen title for AI provider settings.
  ///
  /// In en, this message translates to:
  /// **'AI providers'**
  String get settingsAiProvidersTitle;

  /// Screen subtitle for AI provider settings.
  ///
  /// In en, this message translates to:
  /// **'Configure how Enjoy Player calls AI for each feature.'**
  String get settingsAiProvidersSubtitle;

  /// Privacy notice on the AI providers settings screen.
  ///
  /// In en, this message translates to:
  /// **'API keys are stored securely on this device only and are never synced to Enjoy cloud.'**
  String get settingsAiProvidersPrivacyNotice;

  /// Label when a modality uses Enjoy cloud AI.
  ///
  /// In en, this message translates to:
  /// **'Enjoy AI'**
  String get settingsAiProvidersEnjoyAi;

  /// Label when a modality uses BYOK credentials.
  ///
  /// In en, this message translates to:
  /// **'Your API key'**
  String get settingsAiProvidersByok;

  /// Card title for LLM-backed features (chat, translation, dictionary).
  ///
  /// In en, this message translates to:
  /// **'Language models'**
  String get settingsAiProvidersModalityLlm;

  /// Card subtitle for LLM modality.
  ///
  /// In en, this message translates to:
  /// **'Chat, translation, dictionary, and contextual translation'**
  String get settingsAiProvidersModalityLlmHint;

  /// Card title for ASR modality.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition'**
  String get settingsAiProvidersModalityAsr;

  /// Card subtitle for ASR modality.
  ///
  /// In en, this message translates to:
  /// **'Transcribe audio to text'**
  String get settingsAiProvidersModalityAsrHint;

  /// Card title for TTS modality.
  ///
  /// In en, this message translates to:
  /// **'Text-to-speech'**
  String get settingsAiProvidersModalityTts;

  /// Card subtitle for TTS modality.
  ///
  /// In en, this message translates to:
  /// **'Synthesize spoken audio from text'**
  String get settingsAiProvidersModalityTtsHint;

  /// Card title for pronunciation assessment modality.
  ///
  /// In en, this message translates to:
  /// **'Pronunciation assessment'**
  String get settingsAiProvidersModalityAssessment;

  /// Card subtitle for assessment modality.
  ///
  /// In en, this message translates to:
  /// **'Score shadow-reading takes with Azure Speech'**
  String get settingsAiProvidersModalityAssessmentHint;

  /// Label for LLM protocol spec selector.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get settingsAiProvidersLlmSpecLabel;

  /// OpenAI-compatible LLM protocol spec option.
  ///
  /// In en, this message translates to:
  /// **'OpenAI-compatible'**
  String get settingsAiProvidersLlmSpecOpenAi;

  /// Anthropic-compatible LLM protocol spec option.
  ///
  /// In en, this message translates to:
  /// **'Anthropic-compatible'**
  String get settingsAiProvidersLlmSpecAnthropic;

  /// Google-compatible LLM protocol spec option.
  ///
  /// In en, this message translates to:
  /// **'Google-compatible'**
  String get settingsAiProvidersLlmSpecGoogle;

  /// Label for BYOK provider preset chips.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get settingsAiProvidersPresetsLabel;

  /// BYOK base URL field label.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get settingsAiProvidersBaseUrlLabel;

  /// BYOK base URL field hint.
  ///
  /// In en, this message translates to:
  /// **'https://api.example.com/v1'**
  String get settingsAiProvidersBaseUrlHint;

  /// BYOK API key field label.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get settingsAiProvidersApiKeyLabel;

  /// Hint when a BYOK key is already stored.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to keep saved key'**
  String get settingsAiProvidersApiKeyExistingHint;

  /// Tooltip to reveal BYOK API key field.
  ///
  /// In en, this message translates to:
  /// **'Show API key'**
  String get settingsAiProvidersShowApiKey;

  /// Tooltip to mask BYOK API key field.
  ///
  /// In en, this message translates to:
  /// **'Hide API key'**
  String get settingsAiProvidersHideApiKey;

  /// BYOK model field label.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get settingsAiProvidersModelLabel;

  /// Button to list models from OpenAI-compatible endpoint.
  ///
  /// In en, this message translates to:
  /// **'Fetch models'**
  String get settingsAiProvidersFetchModels;

  /// Dropdown label for fetched OpenAI-compatible models.
  ///
  /// In en, this message translates to:
  /// **'Fetched models'**
  String get settingsAiProvidersFetchedModelsLabel;

  /// Error when OpenAI-compatible model list fails.
  ///
  /// In en, this message translates to:
  /// **'Could not fetch models. Check base URL and API key.'**
  String get settingsAiProvidersFetchModelsFailed;

  /// Message when model list is empty.
  ///
  /// In en, this message translates to:
  /// **'No models returned from this endpoint.'**
  String get settingsAiProvidersFetchModelsEmpty;

  /// Save BYOK settings button.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settingsAiProvidersSave;

  /// Success notice after saving BYOK settings.
  ///
  /// In en, this message translates to:
  /// **'AI provider settings saved.'**
  String get settingsAiProvidersSaveSuccess;

  /// Remove BYOK credentials action.
  ///
  /// In en, this message translates to:
  /// **'Remove BYOK'**
  String get settingsAiProvidersRemoveByok;

  /// Confirm dialog title for removing BYOK.
  ///
  /// In en, this message translates to:
  /// **'Remove BYOK credentials?'**
  String get settingsAiProvidersRemoveByokTitle;

  /// Confirm dialog body for removing BYOK.
  ///
  /// In en, this message translates to:
  /// **'This deletes the saved API key on this device and reverts the feature to Enjoy AI.'**
  String get settingsAiProvidersRemoveByokBody;

  /// Success notice after removing BYOK.
  ///
  /// In en, this message translates to:
  /// **'BYOK credentials removed.'**
  String get settingsAiProvidersRemoveByokSuccess;

  /// Cancel action in BYOK dialogs.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsAiProvidersCancel;

  /// Placeholder for modalities not yet configurable in UI.
  ///
  /// In en, this message translates to:
  /// **'BYOK configuration for this feature is coming soon.'**
  String get settingsAiProvidersComingSoon;

  /// Label for Azure Speech subscription key field in assessment BYOK form
  ///
  /// In en, this message translates to:
  /// **'Azure subscription key'**
  String get settingsAiProvidersSpeechSubscriptionKeyLabel;

  /// Label for Azure Speech region field in assessment BYOK form
  ///
  /// In en, this message translates to:
  /// **'Azure region'**
  String get settingsAiProvidersSpeechRegionLabel;

  /// Hint for Azure Speech region field
  ///
  /// In en, this message translates to:
  /// **'eastus'**
  String get settingsAiProvidersSpeechRegionHint;

  /// Label for ASR/TTS BYOK vendor selector
  ///
  /// In en, this message translates to:
  /// **'Vendor'**
  String get settingsAiProvidersSpeechKindLabel;

  /// OpenAI-compatible Whisper option for speech BYOK
  ///
  /// In en, this message translates to:
  /// **'OpenAI Whisper'**
  String get settingsAiProvidersSpeechKindOpenAi;

  /// Azure Speech option for speech BYOK
  ///
  /// In en, this message translates to:
  /// **'Azure Speech'**
  String get settingsAiProvidersSpeechKindAzure;

  /// Label for Whisper model field in ASR BYOK form
  ///
  /// In en, this message translates to:
  /// **'Whisper model'**
  String get settingsAiProvidersSpeechWhisperModelLabel;

  /// Hint for Whisper model field
  ///
  /// In en, this message translates to:
  /// **'whisper-1'**
  String get settingsAiProvidersSpeechWhisperModelHint;

  /// Label for OpenAI-compatible TTS model field
  ///
  /// In en, this message translates to:
  /// **'TTS model'**
  String get settingsAiProvidersSpeechTtsModelLabel;

  /// Hint for OpenAI-compatible TTS model field
  ///
  /// In en, this message translates to:
  /// **'tts-1'**
  String get settingsAiProvidersSpeechTtsModelHint;

  /// Placeholder shown when a BYOK API key is saved but hidden
  ///
  /// In en, this message translates to:
  /// **'••••••••••••'**
  String get settingsAiProvidersApiKeySavedMask;

  /// Button to replace a saved BYOK API key
  ///
  /// In en, this message translates to:
  /// **'Edit key'**
  String get settingsAiProvidersApiKeyEdit;

  /// Runtime error when BYOK modality has no secure key
  ///
  /// In en, this message translates to:
  /// **'BYOK is selected for {modality}, but no API key is saved on this device.'**
  String byokNotConfiguredMessage(String modality);

  /// Hint to open AI provider settings after BYOK misconfiguration
  ///
  /// In en, this message translates to:
  /// **'Open Settings → AI providers to add your key.'**
  String get byokNotConfiguredOpenSettings;

  /// BYOK validation: missing API key.
  ///
  /// In en, this message translates to:
  /// **'API key is required.'**
  String get byokValidationApiKeyRequired;

  /// BYOK validation: missing base URL.
  ///
  /// In en, this message translates to:
  /// **'Base URL is required.'**
  String get byokValidationBaseUrlRequired;

  /// BYOK validation: URL guard failure.
  ///
  /// In en, this message translates to:
  /// **'Base URL must be a public HTTPS endpoint.'**
  String get byokValidationBaseUrlInvalid;

  /// BYOK validation: missing model.
  ///
  /// In en, this message translates to:
  /// **'Model is required.'**
  String get byokValidationModelRequired;

  /// BYOK validation: missing Azure region.
  ///
  /// In en, this message translates to:
  /// **'Azure region is required.'**
  String get byokValidationRegionRequired;

  /// BYOK validation: missing LLM spec or speech kind.
  ///
  /// In en, this message translates to:
  /// **'Protocol configuration is incomplete.'**
  String get byokValidationApiSpecRequired;

  /// BYOK validation: assessment must use Azure Speech.
  ///
  /// In en, this message translates to:
  /// **'Assessment BYOK requires Azure Speech.'**
  String get byokValidationAzureKindRequired;

  /// Header for the recording settings section.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get settingsSectionRecording;

  /// Subtitle under the recording section header.
  ///
  /// In en, this message translates to:
  /// **'Microphone used for shadow-reading takes.'**
  String get settingsSectionRecordingHint;

  /// Header for the transcript settings section.
  ///
  /// In en, this message translates to:
  /// **'Transcript'**
  String get settingsSectionTranscript;

  /// Subtitle under the transcript section header.
  ///
  /// In en, this message translates to:
  /// **'Options for practice transcript timing.'**
  String get settingsSectionTranscriptHint;

  /// Settings switch title for opt-in Craft timeline enrichment.
  ///
  /// In en, this message translates to:
  /// **'Enrich Craft word timings'**
  String get settingsTranscriptEnrichmentTitle;

  /// Settings switch subtitle explaining Craft timeline enrichment.
  ///
  /// In en, this message translates to:
  /// **'When on, Craft save stores word and phone times from on-device alignment. Off (default) keeps today’s synthesis line timings.'**
  String get settingsTranscriptEnrichmentSubtitle;

  /// Settings switch title for opt-in karaoke word highlight in the transcript panel.
  ///
  /// In en, this message translates to:
  /// **'Highlight current word'**
  String get settingsTranscriptKaraokeTitle;

  /// Settings switch subtitle explaining karaoke word highlight.
  ///
  /// In en, this message translates to:
  /// **'Highlight the spoken word when word timings exist.'**
  String get settingsTranscriptKaraokeSubtitle;

  /// Settings switch title for opt-in stored IPA overlay on transcript words.
  ///
  /// In en, this message translates to:
  /// **'Show pronunciation (IPA)'**
  String get settingsTranscriptIpaOverlayTitle;

  /// Settings switch subtitle explaining stored IPA overlay.
  ///
  /// In en, this message translates to:
  /// **'Show IPA under words; tap to play.'**
  String get settingsTranscriptIpaOverlaySubtitle;

  /// Section title for karaoke and IPA toggles in the subtitle track picker.
  ///
  /// In en, this message translates to:
  /// **'Transcript display'**
  String get transcriptDisplaySettingsTitle;

  /// Hint when IPA toggle is unavailable because the transcript has no phones.
  ///
  /// In en, this message translates to:
  /// **'Generate pronunciation first.'**
  String get transcriptIpaUnavailableHint;

  /// Hint when karaoke is off because the primary track has no timed words.
  ///
  /// In en, this message translates to:
  /// **'Generate word timings first.'**
  String get transcriptKaraokeUnavailableHint;

  /// Hint when karaoke stays off for YouTube or other non-extractable media.
  ///
  /// In en, this message translates to:
  /// **'Karaoke needs word timings from a local file.'**
  String get transcriptKaraokeUnavailableRemoteHint;

  /// CC-sheet tile title to align words + IPA from this item's local audio.
  ///
  /// In en, this message translates to:
  /// **'Generate word timings and pronunciation'**
  String get transcriptEnrichOwnedTitle;

  /// CC-sheet tile subtitle for owned-media transcript enrichment.
  ///
  /// In en, this message translates to:
  /// **'Uses this item\'s audio. Playback stays available.'**
  String get transcriptEnrichOwnedSubtitle;

  /// CC-sheet tile title to phonemize YouTube captions without downloading video.
  ///
  /// In en, this message translates to:
  /// **'Generate pronunciation'**
  String get transcriptEnrichYoutubeTitle;

  /// CC-sheet tile subtitle for YouTube IPA-only enrichment.
  ///
  /// In en, this message translates to:
  /// **'Karaoke stays unavailable. The video is not downloaded.'**
  String get transcriptEnrichYoutubeSubtitle;

  /// Busy enrich tile title that cancels an in-flight run.
  ///
  /// In en, this message translates to:
  /// **'Cancel generation'**
  String get transcriptEnrichCancel;

  /// Enrich tile title after a failed run.
  ///
  /// In en, this message translates to:
  /// **'Try generating again'**
  String get transcriptEnrichRetry;

  /// Inline error on the enrich tile after failure or cancel.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t generate. Tap to try again.'**
  String get transcriptEnrichFailed;

  /// Busy enrich tile subtitle before the first cue reports progress.
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get transcriptEnrichWorking;

  /// Busy enrich tile subtitle while aligning cues on a long transcript.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total}'**
  String transcriptEnrichProgress(int completed, int total);

  /// Title of the microphone picker tile in settings.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get settingsRecordingMicTitle;

  /// Subtitle of the mic tile when auto-picking. The label is the resolved device.
  ///
  /// In en, this message translates to:
  /// **'Auto · {label}'**
  String settingsRecordingMicAuto(String label);

  /// Subtitle of the mic tile when auto-picking and no devices were enumerated yet.
  ///
  /// In en, this message translates to:
  /// **'Auto · system default'**
  String get settingsRecordingMicAutoNoDevice;

  /// Subtitle / empty state when the OS reports no input devices.
  ///
  /// In en, this message translates to:
  /// **'No microphones detected'**
  String get settingsRecordingMicEmpty;

  /// Menu/dialog option that lets the heuristic pick the first non-virtual device.
  ///
  /// In en, this message translates to:
  /// **'Auto (skip virtual mics)'**
  String get settingsRecordingMicAutoOption;

  /// Title of the modal dialog used to pick a recording input device.
  ///
  /// In en, this message translates to:
  /// **'Choose microphone'**
  String get settingsRecordingMicDialogTitle;

  /// Warning shown right after a take when the captured WAV has no signal energy (e.g. Windows captured a virtual loopback device).
  ///
  /// In en, this message translates to:
  /// **'No microphone signal detected. Open Settings → Recording to pick a different microphone.'**
  String get shadowRecordingSilentWarning;

  /// No description provided for @shadowRecordingPlaybackFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t play this take.'**
  String get shadowRecordingPlaybackFailed;

  /// Shown while recording after elapsed time exceeds the reference segment duration.
  ///
  /// In en, this message translates to:
  /// **'+{seconds}s over target'**
  String shadowRecordingOverTarget(String seconds);

  /// Accessibility label for the live recording progress while shadow-reading against a target duration.
  ///
  /// In en, this message translates to:
  /// **'{elapsed} seconds elapsed of {target} seconds target'**
  String shadowRecordingElapsedSemantics(String elapsed, String target);

  /// Visible live recording progress against a target duration (elapsed / target).
  ///
  /// In en, this message translates to:
  /// **'{elapsed} s / {target} s'**
  String shadowRecordingElapsedCountdown(String elapsed, String target);

  /// Visible live recording progress with no target duration.
  ///
  /// In en, this message translates to:
  /// **'{elapsed} s'**
  String shadowRecordingElapsedSeconds(String elapsed);

  /// Reason shown when a just-recorded file is missing from disk after stopping.
  ///
  /// In en, this message translates to:
  /// **'Recording file was not found.'**
  String get shadowRecordingFileNotFound;

  /// No description provided for @hotkeysTitle.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get hotkeysTitle;

  /// No description provided for @hotkeysHintFooter.
  ///
  /// In en, this message translates to:
  /// **'Press Shift+/ (?) to open this list.'**
  String get hotkeysHintFooter;

  /// No description provided for @hotkeysCustomizedBadge.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get hotkeysCustomizedBadge;

  /// No description provided for @hotkeysSectionKeyboard.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get hotkeysSectionKeyboard;

  /// No description provided for @hotkeysResetBinding.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get hotkeysResetBinding;

  /// No description provided for @hotkeysResetAll.
  ///
  /// In en, this message translates to:
  /// **'Reset all shortcuts'**
  String get hotkeysResetAll;

  /// No description provided for @hotkeysResetAllConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset all shortcuts?'**
  String get hotkeysResetAllConfirmTitle;

  /// No description provided for @hotkeysResetAllConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This restores every shortcut to its default binding. Custom bindings cannot be undone.'**
  String get hotkeysResetAllConfirmMessage;

  /// No description provided for @hotkeysCaptureTitle.
  ///
  /// In en, this message translates to:
  /// **'Press new shortcut'**
  String get hotkeysCaptureTitle;

  /// No description provided for @hotkeysCaptureHint.
  ///
  /// In en, this message translates to:
  /// **'Press a key combination. Escape cancels.'**
  String get hotkeysCaptureHint;

  /// No description provided for @hotkeysConflictError.
  ///
  /// In en, this message translates to:
  /// **'That shortcut is already used.'**
  String get hotkeysConflictError;

  /// No description provided for @hotkeysScopeGlobal.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get hotkeysScopeGlobal;

  /// No description provided for @hotkeysScopePlayer.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get hotkeysScopePlayer;

  /// No description provided for @hotkeysScopeLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get hotkeysScopeLibrary;

  /// No description provided for @hotkeysScopeModal.
  ///
  /// In en, this message translates to:
  /// **'Modal'**
  String get hotkeysScopeModal;

  /// No description provided for @hotkeysDescHelp.
  ///
  /// In en, this message translates to:
  /// **'Show keyboard shortcuts'**
  String get hotkeysDescHelp;

  /// No description provided for @hotkeysDescSearch.
  ///
  /// In en, this message translates to:
  /// **'Open search'**
  String get hotkeysDescSearch;

  /// No description provided for @hotkeysDescSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get hotkeysDescSettings;

  /// No description provided for @hotkeysDescCraft.
  ///
  /// In en, this message translates to:
  /// **'Open Craft'**
  String get hotkeysDescCraft;

  /// No description provided for @hotkeysDescTogglePlay.
  ///
  /// In en, this message translates to:
  /// **'Play / Pause'**
  String get hotkeysDescTogglePlay;

  /// No description provided for @hotkeysDescToggleExpand.
  ///
  /// In en, this message translates to:
  /// **'Toggle player expand/collapse'**
  String get hotkeysDescToggleExpand;

  /// No description provided for @hotkeysDescToggleFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Toggle fullscreen'**
  String get hotkeysDescToggleFullscreen;

  /// No description provided for @hotkeysDescPrevLine.
  ///
  /// In en, this message translates to:
  /// **'Play previous line'**
  String get hotkeysDescPrevLine;

  /// No description provided for @hotkeysDescNextLine.
  ///
  /// In en, this message translates to:
  /// **'Play next line'**
  String get hotkeysDescNextLine;

  /// No description provided for @hotkeysDescReplayLine.
  ///
  /// In en, this message translates to:
  /// **'Replay current line'**
  String get hotkeysDescReplayLine;

  /// No description provided for @hotkeysDescToggleEchoMode.
  ///
  /// In en, this message translates to:
  /// **'Toggle Echo mode'**
  String get hotkeysDescToggleEchoMode;

  /// No description provided for @hotkeysDescToggleBlurPractice.
  ///
  /// In en, this message translates to:
  /// **'Toggle listening-focus (blur practice)'**
  String get hotkeysDescToggleBlurPractice;

  /// No description provided for @hotkeysDescToggleRecording.
  ///
  /// In en, this message translates to:
  /// **'Start/Stop recording'**
  String get hotkeysDescToggleRecording;

  /// No description provided for @hotkeysDescToggleAssessment.
  ///
  /// In en, this message translates to:
  /// **'Show/Hide pronunciation assessment'**
  String get hotkeysDescToggleAssessment;

  /// No description provided for @hotkeysDescTogglePitchContour.
  ///
  /// In en, this message translates to:
  /// **'Show/Hide pitch contour'**
  String get hotkeysDescTogglePitchContour;

  /// No description provided for @hotkeysDescPlayRecording.
  ///
  /// In en, this message translates to:
  /// **'Play/Pause recording'**
  String get hotkeysDescPlayRecording;

  /// No description provided for @hotkeysDescSlowDown.
  ///
  /// In en, this message translates to:
  /// **'Slow down playback speed'**
  String get hotkeysDescSlowDown;

  /// No description provided for @hotkeysDescSpeedUp.
  ///
  /// In en, this message translates to:
  /// **'Speed up playback speed'**
  String get hotkeysDescSpeedUp;

  /// No description provided for @hotkeysDescExpandEchoBackward.
  ///
  /// In en, this message translates to:
  /// **'Expand Echo region backward'**
  String get hotkeysDescExpandEchoBackward;

  /// No description provided for @hotkeysDescExpandEchoForward.
  ///
  /// In en, this message translates to:
  /// **'Expand Echo region forward'**
  String get hotkeysDescExpandEchoForward;

  /// No description provided for @hotkeysDescShrinkEchoBackward.
  ///
  /// In en, this message translates to:
  /// **'Shrink Echo region backward'**
  String get hotkeysDescShrinkEchoBackward;

  /// No description provided for @hotkeysDescShrinkEchoForward.
  ///
  /// In en, this message translates to:
  /// **'Shrink Echo region forward'**
  String get hotkeysDescShrinkEchoForward;

  /// No description provided for @hotkeysDescLibrarySearch.
  ///
  /// In en, this message translates to:
  /// **'Focus search'**
  String get hotkeysDescLibrarySearch;

  /// No description provided for @hotkeysDescCloseModal.
  ///
  /// In en, this message translates to:
  /// **'Close overlay, exit fullscreen, or cancel recording'**
  String get hotkeysDescCloseModal;

  /// No description provided for @hotkeysStubSearch.
  ///
  /// In en, this message translates to:
  /// **'Search is not available yet.'**
  String get hotkeysStubSearch;

  /// No description provided for @assessmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Pronunciation assessment'**
  String get assessmentTitle;

  /// No description provided for @assessmentDescription.
  ///
  /// In en, this message translates to:
  /// **'Detailed scoring for your reading.'**
  String get assessmentDescription;

  /// No description provided for @assessmentRun.
  ///
  /// In en, this message translates to:
  /// **'Run pronunciation assessment'**
  String get assessmentRun;

  /// No description provided for @assessmentView.
  ///
  /// In en, this message translates to:
  /// **'View pronunciation assessment'**
  String get assessmentView;

  /// No description provided for @assessmentReassess.
  ///
  /// In en, this message translates to:
  /// **'Re-assess'**
  String get assessmentReassess;

  /// No description provided for @assessmentOverallScore.
  ///
  /// In en, this message translates to:
  /// **'Overall score'**
  String get assessmentOverallScore;

  /// No description provided for @assessmentAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get assessmentAccuracy;

  /// No description provided for @assessmentCompleteness.
  ///
  /// In en, this message translates to:
  /// **'Completeness'**
  String get assessmentCompleteness;

  /// No description provided for @assessmentFluency.
  ///
  /// In en, this message translates to:
  /// **'Fluency'**
  String get assessmentFluency;

  /// No description provided for @assessmentProsody.
  ///
  /// In en, this message translates to:
  /// **'Prosody'**
  String get assessmentProsody;

  /// No description provided for @assessmentPronunciationAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Pronunciation analysis'**
  String get assessmentPronunciationAnalysis;

  /// No description provided for @assessmentAccuracyScore.
  ///
  /// In en, this message translates to:
  /// **'Accuracy score'**
  String get assessmentAccuracyScore;

  /// No description provided for @assessmentSyllables.
  ///
  /// In en, this message translates to:
  /// **'Syllables'**
  String get assessmentSyllables;

  /// No description provided for @assessmentPhonemes.
  ///
  /// In en, this message translates to:
  /// **'Phonemes'**
  String get assessmentPhonemes;

  /// No description provided for @assessmentNoRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording file is missing or empty.'**
  String get assessmentNoRecording;

  /// No description provided for @assessmentNoResultSummary.
  ///
  /// In en, this message translates to:
  /// **'No detailed scores are available for this take.'**
  String get assessmentNoResultSummary;

  /// No description provided for @assessmentRunFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t run assessment: {reason}'**
  String assessmentRunFailed(String reason);

  /// No description provided for @assessmentErrorTypeOmission.
  ///
  /// In en, this message translates to:
  /// **'Omission'**
  String get assessmentErrorTypeOmission;

  /// No description provided for @assessmentErrorTypeInsertion.
  ///
  /// In en, this message translates to:
  /// **'Insertion'**
  String get assessmentErrorTypeInsertion;

  /// No description provided for @assessmentErrorTypeMispronunciation.
  ///
  /// In en, this message translates to:
  /// **'Mispronunciation'**
  String get assessmentErrorTypeMispronunciation;

  /// No description provided for @assessmentErrorTypeUnexpectedBreak.
  ///
  /// In en, this message translates to:
  /// **'Unexpected break'**
  String get assessmentErrorTypeUnexpectedBreak;

  /// No description provided for @assessmentErrorTypeMissingBreak.
  ///
  /// In en, this message translates to:
  /// **'Missing break'**
  String get assessmentErrorTypeMissingBreak;

  /// No description provided for @assessmentErrorTypeMonotone.
  ///
  /// In en, this message translates to:
  /// **'Monotone'**
  String get assessmentErrorTypeMonotone;

  /// No description provided for @assessmentErrorTypeCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get assessmentErrorTypeCorrect;

  /// No description provided for @assessmentErrorExplOmission.
  ///
  /// In en, this message translates to:
  /// **'This word was expected but not detected.'**
  String get assessmentErrorExplOmission;

  /// No description provided for @assessmentErrorExplInsertion.
  ///
  /// In en, this message translates to:
  /// **'Extra word detected that wasn\'t in the reference.'**
  String get assessmentErrorExplInsertion;

  /// No description provided for @assessmentErrorExplMispronunciation.
  ///
  /// In en, this message translates to:
  /// **'This word may have been pronounced incorrectly.'**
  String get assessmentErrorExplMispronunciation;

  /// No description provided for @assessmentErrorExplUnexpectedBreak.
  ///
  /// In en, this message translates to:
  /// **'Unexpected pause detected before this word.'**
  String get assessmentErrorExplUnexpectedBreak;

  /// No description provided for @assessmentErrorExplMissingBreak.
  ///
  /// In en, this message translates to:
  /// **'Expected pause was not detected before this word.'**
  String get assessmentErrorExplMissingBreak;

  /// No description provided for @assessmentErrorExplMonotone.
  ///
  /// In en, this message translates to:
  /// **'Pitch variation was lower than expected.'**
  String get assessmentErrorExplMonotone;

  /// No description provided for @assessmentErrorExplCorrect.
  ///
  /// In en, this message translates to:
  /// **'No issues detected for this word.'**
  String get assessmentErrorExplCorrect;

  /// No description provided for @assessmentEmptyReference.
  ///
  /// In en, this message translates to:
  /// **'Reference text is empty.'**
  String get assessmentEmptyReference;

  /// No description provided for @assessmentInvalidStored.
  ///
  /// In en, this message translates to:
  /// **'Stored assessment data could not be read.'**
  String get assessmentInvalidStored;

  /// No description provided for @authSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Enjoy'**
  String get authSignInTitle;

  /// No description provided for @authSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync your library, track learning progress, and pick up where you left off.'**
  String get authSignInSubtitle;

  /// No description provided for @authSignInCta.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get authSignInCta;

  /// No description provided for @authContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authContinueWithGoogle;

  /// No description provided for @authContinueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get authContinueWithApple;

  /// No description provided for @authContinueWithEmail.
  ///
  /// In en, this message translates to:
  /// **'Continue with Email'**
  String get authContinueWithEmail;

  /// No description provided for @authOtherSignInOptions.
  ///
  /// In en, this message translates to:
  /// **'Other sign-in options'**
  String get authOtherSignInOptions;

  /// No description provided for @authOrDivider.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get authOrDivider;

  /// No description provided for @authEmailPrompt.
  ///
  /// In en, this message translates to:
  /// **'We will send a one-time code to your email.'**
  String get authEmailPrompt;

  /// No description provided for @authEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmailLabel;

  /// No description provided for @authEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get authEmailInvalid;

  /// No description provided for @authSendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get authSendOtp;

  /// No description provided for @authOtpTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter verification code'**
  String get authOtpTitle;

  /// No description provided for @authOtpSentTo.
  ///
  /// In en, this message translates to:
  /// **'Code sent to {email}'**
  String authOtpSentTo(String email);

  /// No description provided for @authOtpLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get authOtpLabel;

  /// Accessibility label for the 6-digit OTP input field.
  ///
  /// In en, this message translates to:
  /// **'One-time passcode'**
  String get authOtpInputSemantics;

  /// No description provided for @authVerifyOtp.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get authVerifyOtp;

  /// No description provided for @authOtpResend.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get authOtpResend;

  /// No description provided for @authOtpResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String authOtpResendIn(int seconds);

  /// No description provided for @authChangeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get authChangeEmail;

  /// No description provided for @authOtpResumeTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish signing in'**
  String get authOtpResumeTitle;

  /// No description provided for @authOtpResumeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the verification code sent to {email}'**
  String authOtpResumeSubtitle(String email);

  /// No description provided for @authOtpResumeAction.
  ///
  /// In en, this message translates to:
  /// **'Continue verification'**
  String get authOtpResumeAction;

  /// No description provided for @authWebSignInWaiting.
  ///
  /// In en, this message translates to:
  /// **'Complete sign-in in your browser…'**
  String get authWebSignInWaiting;

  /// No description provided for @authWaitingForApproval.
  ///
  /// In en, this message translates to:
  /// **'Finishing sign-in…'**
  String get authWaitingForApproval;

  /// No description provided for @authCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get authCancel;

  /// No description provided for @authSignedInSuccess.
  ///
  /// In en, this message translates to:
  /// **'Signed in successfully'**
  String get authSignedInSuccess;

  /// No description provided for @authReloadSignInPage.
  ///
  /// In en, this message translates to:
  /// **'Reload sign-in page'**
  String get authReloadSignInPage;

  /// No description provided for @authOpenInSystemBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in system browser'**
  String get authOpenInSystemBrowser;

  /// No description provided for @authSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get authSignOut;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh profile'**
  String get profileRefreshTooltip;

  /// No description provided for @profileFieldName.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get profileFieldName;

  /// No description provided for @profileFieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileFieldEmail;

  /// No description provided for @profileFieldEnjoyId.
  ///
  /// In en, this message translates to:
  /// **'Enjoy ID'**
  String get profileFieldEnjoyId;

  /// No description provided for @profileFieldMixinId.
  ///
  /// In en, this message translates to:
  /// **'Mixin ID'**
  String get profileFieldMixinId;

  /// No description provided for @profileMixinNotLinked.
  ///
  /// In en, this message translates to:
  /// **'Not linked'**
  String get profileMixinNotLinked;

  /// No description provided for @profileEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get profileEditTitle;

  /// No description provided for @profileEditEntry.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get profileEditEntry;

  /// No description provided for @profileEditEntryHint.
  ///
  /// In en, this message translates to:
  /// **'Username, avatar, and account IDs'**
  String get profileEditEntryHint;

  /// No description provided for @profileChangeAvatar.
  ///
  /// In en, this message translates to:
  /// **'Change avatar'**
  String get profileChangeAvatar;

  /// No description provided for @profileAvatarTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Avatar must be 2 MB or smaller'**
  String get profileAvatarTooLarge;

  /// No description provided for @profileAvatarUnsupportedType.
  ///
  /// In en, this message translates to:
  /// **'Avatar must be JPEG, PNG, or WebP'**
  String get profileAvatarUnsupportedType;

  /// No description provided for @profileAvatarEmpty.
  ///
  /// In en, this message translates to:
  /// **'Choose an image to upload'**
  String get profileAvatarEmpty;

  /// No description provided for @profileAvatarUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not upload avatar. Try again.'**
  String get profileAvatarUploadFailed;

  /// No description provided for @profileCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get profileCopied;

  /// No description provided for @profileFieldGoal.
  ///
  /// In en, this message translates to:
  /// **'Daily goal (minutes)'**
  String get profileFieldGoal;

  /// No description provided for @profileFieldLearningLanguage.
  ///
  /// In en, this message translates to:
  /// **'Learning language'**
  String get profileFieldLearningLanguage;

  /// No description provided for @profileFieldNativeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Native language'**
  String get profileFieldNativeLanguage;

  /// No description provided for @profileFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get profileFieldRequired;

  /// No description provided for @profileSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileSave;

  /// No description provided for @profileSaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get profileSaveSuccess;

  /// No description provided for @profileSubscriptionFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get profileSubscriptionFree;

  /// No description provided for @profileSubscriptionPro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get profileSubscriptionPro;

  /// No description provided for @profileCreditsAvailable.
  ///
  /// In en, this message translates to:
  /// **'Credits today: {available} / {limit}'**
  String profileCreditsAvailable(String available, String limit);

  /// No description provided for @profileStatTodayTitle.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get profileStatTodayTitle;

  /// No description provided for @profileStatWeekTitle.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get profileStatWeekTitle;

  /// No description provided for @profileStatMonthTitle.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get profileStatMonthTitle;

  /// No description provided for @profileSectionPractice.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get profileSectionPractice;

  /// No description provided for @profileSectionPracticeHint.
  ///
  /// In en, this message translates to:
  /// **'Synced practice time from your account'**
  String get profileSectionPracticeHint;

  /// No description provided for @profileCreditsUsageTile.
  ///
  /// In en, this message translates to:
  /// **'Credits usage'**
  String get profileCreditsUsageTile;

  /// No description provided for @profileCreditsUsageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View AI credits consumption from your account'**
  String get profileCreditsUsageSubtitle;

  /// No description provided for @profileSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profileSectionAccount;

  /// No description provided for @profileSectionAccountHint.
  ///
  /// In en, this message translates to:
  /// **'Daily credits and usage history'**
  String get profileSectionAccountHint;

  /// No description provided for @profileSectionPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get profileSectionPreferences;

  /// No description provided for @profileSectionPreferencesHint.
  ///
  /// In en, this message translates to:
  /// **'Daily goal and language settings'**
  String get profileSectionPreferencesHint;

  /// No description provided for @profileSignOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get profileSignOutConfirmTitle;

  /// No description provided for @profileSignOutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'You will need to sign in again to sync and use AI features.'**
  String get profileSignOutConfirmMessage;

  /// No description provided for @profileSubscriptionTile.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get profileSubscriptionTile;

  /// No description provided for @profileSubscriptionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View your plan and upgrade to Pro'**
  String get profileSubscriptionSubtitle;

  /// No description provided for @subscriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscriptionTitle;

  /// No description provided for @subscriptionDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage your subscription plan and Pro benefits.'**
  String get subscriptionDescription;

  /// No description provided for @subscriptionErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Failed to load subscription status'**
  String get subscriptionErrorLoading;

  /// No description provided for @subscriptionStatusCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription status'**
  String get subscriptionStatusCardTitle;

  /// No description provided for @subscriptionCurrentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current plan'**
  String get subscriptionCurrentPlan;

  /// No description provided for @subscriptionStatusTier.
  ///
  /// In en, this message translates to:
  /// **'Tier'**
  String get subscriptionStatusTier;

  /// No description provided for @subscriptionStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get subscriptionStatusActive;

  /// No description provided for @subscriptionActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get subscriptionActive;

  /// No description provided for @subscriptionInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get subscriptionInactive;

  /// No description provided for @subscriptionStatusExpiration.
  ///
  /// In en, this message translates to:
  /// **'Expiration'**
  String get subscriptionStatusExpiration;

  /// No description provided for @subscriptionNeverExpires.
  ///
  /// In en, this message translates to:
  /// **'Never expires'**
  String get subscriptionNeverExpires;

  /// No description provided for @subscriptionExpiresOn.
  ///
  /// In en, this message translates to:
  /// **'Expires on {date}'**
  String subscriptionExpiresOn(String date);

  /// No description provided for @subscriptionStatusCreditsLimit.
  ///
  /// In en, this message translates to:
  /// **'Daily credits limit'**
  String get subscriptionStatusCreditsLimit;

  /// No description provided for @subscriptionDailyCredits.
  ///
  /// In en, this message translates to:
  /// **'{count} credits'**
  String subscriptionDailyCredits(String count);

  /// No description provided for @subscriptionTierComparisonTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your plan'**
  String get subscriptionTierComparisonTitle;

  /// No description provided for @subscriptionTierFreeName.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get subscriptionTierFreeName;

  /// No description provided for @subscriptionTierFreeDescription.
  ///
  /// In en, this message translates to:
  /// **'Perfect for light usage'**
  String get subscriptionTierFreeDescription;

  /// No description provided for @subscriptionTierFreePrice.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get subscriptionTierFreePrice;

  /// No description provided for @subscriptionTierFreeDailyCredits.
  ///
  /// In en, this message translates to:
  /// **'1,000 credits/day'**
  String get subscriptionTierFreeDailyCredits;

  /// No description provided for @subscriptionTierLiteName.
  ///
  /// In en, this message translates to:
  /// **'Lite'**
  String get subscriptionTierLiteName;

  /// No description provided for @subscriptionTierLiteDescription.
  ///
  /// In en, this message translates to:
  /// **'For daily learners'**
  String get subscriptionTierLiteDescription;

  /// No description provided for @subscriptionTierLitePrice.
  ///
  /// In en, this message translates to:
  /// **'1.99 USD/month'**
  String get subscriptionTierLitePrice;

  /// No description provided for @subscriptionTierLiteDailyCredits.
  ///
  /// In en, this message translates to:
  /// **'12,000 credits/day (12× Free)'**
  String get subscriptionTierLiteDailyCredits;

  /// No description provided for @subscriptionTierProName.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get subscriptionTierProName;

  /// No description provided for @subscriptionTierProDescription.
  ///
  /// In en, this message translates to:
  /// **'For serious learners'**
  String get subscriptionTierProDescription;

  /// No description provided for @subscriptionTierProPrice.
  ///
  /// In en, this message translates to:
  /// **'9.99 USD/month'**
  String get subscriptionTierProPrice;

  /// No description provided for @subscriptionTierProDailyCredits.
  ///
  /// In en, this message translates to:
  /// **'60,000 credits/day (60× Free)'**
  String get subscriptionTierProDailyCredits;

  /// No description provided for @subscriptionFeatureTranslation.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get subscriptionFeatureTranslation;

  /// No description provided for @subscriptionFeatureSmartTranslation.
  ///
  /// In en, this message translates to:
  /// **'Smart translation'**
  String get subscriptionFeatureSmartTranslation;

  /// No description provided for @subscriptionFeatureDictionary.
  ///
  /// In en, this message translates to:
  /// **'Dictionary'**
  String get subscriptionFeatureDictionary;

  /// No description provided for @subscriptionFeatureAsr.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition'**
  String get subscriptionFeatureAsr;

  /// No description provided for @subscriptionFeatureTts.
  ///
  /// In en, this message translates to:
  /// **'Speech synthesis'**
  String get subscriptionFeatureTts;

  /// No description provided for @subscriptionFeatureAssessment.
  ///
  /// In en, this message translates to:
  /// **'Pronunciation assessment'**
  String get subscriptionFeatureAssessment;

  /// No description provided for @subscriptionFeaturePaidFlashcards.
  ///
  /// In en, this message translates to:
  /// **'Download vocabulary flashcards'**
  String get subscriptionFeaturePaidFlashcards;

  /// No description provided for @subscriptionFeaturePaidMoreComing.
  ///
  /// In en, this message translates to:
  /// **'More features coming'**
  String get subscriptionFeaturePaidMoreComing;

  /// No description provided for @subscriptionUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get subscriptionUpgrade;

  /// No description provided for @subscriptionUpgradeShort.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get subscriptionUpgradeShort;

  /// No description provided for @subscriptionRecommendedPlan.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get subscriptionRecommendedPlan;

  /// No description provided for @subscriptionExtend.
  ///
  /// In en, this message translates to:
  /// **'Extend subscription'**
  String get subscriptionExtend;

  /// No description provided for @subscriptionPurchaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase Pro subscription'**
  String get subscriptionPurchaseTitle;

  /// No description provided for @subscriptionPurchaseSelectDuration.
  ///
  /// In en, this message translates to:
  /// **'Select duration'**
  String get subscriptionPurchaseSelectDuration;

  /// No description provided for @subscriptionPurchaseDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get subscriptionPurchaseDuration;

  /// No description provided for @subscriptionPurchaseOneMonth.
  ///
  /// In en, this message translates to:
  /// **'1 month'**
  String get subscriptionPurchaseOneMonth;

  /// No description provided for @subscriptionPurchaseOneSeason.
  ///
  /// In en, this message translates to:
  /// **'1 season'**
  String get subscriptionPurchaseOneSeason;

  /// No description provided for @subscriptionPurchaseOneYear.
  ///
  /// In en, this message translates to:
  /// **'1 year'**
  String get subscriptionPurchaseOneYear;

  /// No description provided for @subscriptionPurchaseCustomDuration.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get subscriptionPurchaseCustomDuration;

  /// No description provided for @subscriptionPurchaseCustomMonthsLabel.
  ///
  /// In en, this message translates to:
  /// **'Number of months'**
  String get subscriptionPurchaseCustomMonthsLabel;

  /// No description provided for @subscriptionPurchaseCustomMonthsHint.
  ///
  /// In en, this message translates to:
  /// **'1–12'**
  String get subscriptionPurchaseCustomMonthsHint;

  /// No description provided for @subscriptionPurchaseCustomMonthsHelper.
  ///
  /// In en, this message translates to:
  /// **'Enter between 1 and 12 months'**
  String get subscriptionPurchaseCustomMonthsHelper;

  /// No description provided for @subscriptionPurchaseMonths.
  ///
  /// In en, this message translates to:
  /// **'{count} months'**
  String subscriptionPurchaseMonths(int count);

  /// No description provided for @subscriptionPurchasePaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get subscriptionPurchasePaymentMethod;

  /// No description provided for @subscriptionProcessorStripe.
  ///
  /// In en, this message translates to:
  /// **'Stripe'**
  String get subscriptionProcessorStripe;

  /// No description provided for @subscriptionProcessorMixin.
  ///
  /// In en, this message translates to:
  /// **'Cryptocurrency'**
  String get subscriptionProcessorMixin;

  /// No description provided for @subscriptionPaymentMethodCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get subscriptionPaymentMethodCard;

  /// No description provided for @subscriptionPaymentMethodWechat.
  ///
  /// In en, this message translates to:
  /// **'WeChat'**
  String get subscriptionPaymentMethodWechat;

  /// No description provided for @subscriptionPaymentMethodAlipay.
  ///
  /// In en, this message translates to:
  /// **'Alipay'**
  String get subscriptionPaymentMethodAlipay;

  /// No description provided for @subscriptionPaymentMethodGooglePay.
  ///
  /// In en, this message translates to:
  /// **'Google Pay'**
  String get subscriptionPaymentMethodGooglePay;

  /// No description provided for @subscriptionPaymentMethodUsdt.
  ///
  /// In en, this message translates to:
  /// **'USDT'**
  String get subscriptionPaymentMethodUsdt;

  /// No description provided for @subscriptionPaymentMethodUsdc.
  ///
  /// In en, this message translates to:
  /// **'USDC'**
  String get subscriptionPaymentMethodUsdc;

  /// No description provided for @subscriptionPaymentMethodBtc.
  ///
  /// In en, this message translates to:
  /// **'BTC'**
  String get subscriptionPaymentMethodBtc;

  /// No description provided for @subscriptionPaymentMethodEth.
  ///
  /// In en, this message translates to:
  /// **'ETH'**
  String get subscriptionPaymentMethodEth;

  /// No description provided for @subscriptionPaymentMethodDoge.
  ///
  /// In en, this message translates to:
  /// **'Doge'**
  String get subscriptionPaymentMethodDoge;

  /// No description provided for @subscriptionPaymentMethodAndMore.
  ///
  /// In en, this message translates to:
  /// **'and more'**
  String get subscriptionPaymentMethodAndMore;

  /// No description provided for @subscriptionTotalPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get subscriptionTotalPriceLabel;

  /// No description provided for @subscriptionTotalPrice.
  ///
  /// In en, this message translates to:
  /// **'{amount} USD'**
  String subscriptionTotalPrice(String amount);

  /// No description provided for @subscriptionContinueToPayment.
  ///
  /// In en, this message translates to:
  /// **'Continue to payment'**
  String get subscriptionContinueToPayment;

  /// No description provided for @subscriptionRedirectingToPayment.
  ///
  /// In en, this message translates to:
  /// **'Redirecting to payment…'**
  String get subscriptionRedirectingToPayment;

  /// No description provided for @subscriptionPaymentUrlMissing.
  ///
  /// In en, this message translates to:
  /// **'Payment URL not available'**
  String get subscriptionPaymentUrlMissing;

  /// No description provided for @subscriptionPaymentLaunchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open payment page'**
  String get subscriptionPaymentLaunchFailed;

  /// No description provided for @subscriptionPurchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed'**
  String get subscriptionPurchaseFailed;

  /// No description provided for @subscriptionMobilePurchaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Mobile purchase coming soon'**
  String get subscriptionMobilePurchaseTitle;

  /// No description provided for @subscriptionMobilePurchaseMessage.
  ///
  /// In en, this message translates to:
  /// **'In-app purchase on iOS and Android is not available yet. If you already have Pro from the web or desktop app, your status appears above.'**
  String get subscriptionMobilePurchaseMessage;

  /// No description provided for @subscriptionCreditsLimitMessage.
  ///
  /// In en, this message translates to:
  /// **'AI credits limit reached. Upgrade for higher limits.'**
  String get subscriptionCreditsLimitMessage;

  /// No description provided for @subscriptionViewPlans.
  ///
  /// In en, this message translates to:
  /// **'View plans'**
  String get subscriptionViewPlans;

  /// Celebration snackbar shown when the tier flips from Free to Pro.
  ///
  /// In en, this message translates to:
  /// **'You\'re now Pro — enjoy!'**
  String get subscriptionUpgradedToPro;

  /// Snackbars shown while polling for payment confirmation after returning from external checkout.
  ///
  /// In en, this message translates to:
  /// **'Verifying your upgrade…'**
  String get subscriptionVerifyingUpgrade;

  /// Shown when eager purchase polling times out without confirming Pro.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t confirm your upgrade yet — we\'ll keep checking in the background.'**
  String get subscriptionVerifyTimeout;

  /// No description provided for @creditsUsageTitle.
  ///
  /// In en, this message translates to:
  /// **'Credits usage'**
  String get creditsUsageTitle;

  /// No description provided for @creditsUsageDescription.
  ///
  /// In en, this message translates to:
  /// **'Records of credits checks on the Enjoy AI worker (UTC dates).'**
  String get creditsUsageDescription;

  /// No description provided for @creditsUsageStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get creditsUsageStartDate;

  /// No description provided for @creditsUsageEndDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get creditsUsageEndDate;

  /// No description provided for @creditsUsageServiceType.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get creditsUsageServiceType;

  /// No description provided for @creditsUsageClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get creditsUsageClearFilters;

  /// No description provided for @creditsUsageError.
  ///
  /// In en, this message translates to:
  /// **'Could not load usage'**
  String get creditsUsageError;

  /// No description provided for @creditsUsageErrorDescription.
  ///
  /// In en, this message translates to:
  /// **'Check your network and AI API base URL in Settings.'**
  String get creditsUsageErrorDescription;

  /// No description provided for @creditsUsageRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get creditsUsageRetry;

  /// No description provided for @creditsUsageNoRecords.
  ///
  /// In en, this message translates to:
  /// **'No records'**
  String get creditsUsageNoRecords;

  /// No description provided for @creditsUsageNoRecordsWithFilters.
  ///
  /// In en, this message translates to:
  /// **'Try changing or clearing filters.'**
  String get creditsUsageNoRecordsWithFilters;

  /// No description provided for @creditsUsageNoRecordsDescription.
  ///
  /// In en, this message translates to:
  /// **'Usage will appear here after you use AI features while signed in.'**
  String get creditsUsageNoRecordsDescription;

  /// No description provided for @creditsUsageTableDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get creditsUsageTableDate;

  /// No description provided for @creditsUsageTableTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get creditsUsageTableTime;

  /// No description provided for @creditsUsageTableService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get creditsUsageTableService;

  /// No description provided for @creditsUsageTableTier.
  ///
  /// In en, this message translates to:
  /// **'Tier'**
  String get creditsUsageTableTier;

  /// No description provided for @creditsUsageTableRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get creditsUsageTableRequired;

  /// No description provided for @creditsUsageTableUsedBefore.
  ///
  /// In en, this message translates to:
  /// **'Used before'**
  String get creditsUsageTableUsedBefore;

  /// No description provided for @creditsUsageTableUsedAfter.
  ///
  /// In en, this message translates to:
  /// **'Used after'**
  String get creditsUsageTableUsedAfter;

  /// No description provided for @creditsUsageTableStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get creditsUsageTableStatus;

  /// No description provided for @creditsUsageAllowed.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get creditsUsageAllowed;

  /// No description provided for @creditsUsageDenied.
  ///
  /// In en, this message translates to:
  /// **'Denied'**
  String get creditsUsageDenied;

  /// No description provided for @creditsUsagePageInfo.
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String creditsUsagePageInfo(int page);

  /// No description provided for @creditsUsageTotalRecords.
  ///
  /// In en, this message translates to:
  /// **'{count} shown'**
  String creditsUsageTotalRecords(int count);

  /// No description provided for @creditsUsagePrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get creditsUsagePrevious;

  /// No description provided for @creditsUsageNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get creditsUsageNext;

  /// No description provided for @creditsServiceTypeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get creditsServiceTypeAll;

  /// No description provided for @creditsServiceTypeTts.
  ///
  /// In en, this message translates to:
  /// **'TTS'**
  String get creditsServiceTypeTts;

  /// No description provided for @creditsServiceTypeAsr.
  ///
  /// In en, this message translates to:
  /// **'ASR'**
  String get creditsServiceTypeAsr;

  /// No description provided for @creditsServiceTypeTranslation.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get creditsServiceTypeTranslation;

  /// No description provided for @creditsServiceTypeLlm.
  ///
  /// In en, this message translates to:
  /// **'LLM'**
  String get creditsServiceTypeLlm;

  /// No description provided for @creditsServiceTypeAssessment.
  ///
  /// In en, this message translates to:
  /// **'Assessment'**
  String get creditsServiceTypeAssessment;

  /// No description provided for @settingsSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsSectionAccount;

  /// No description provided for @settingsSectionAccountHint.
  ///
  /// In en, this message translates to:
  /// **'Profile, subscription, and sign out'**
  String get settingsSectionAccountHint;

  /// No description provided for @settingsSectionSyncHint.
  ///
  /// In en, this message translates to:
  /// **'Upload queue, offline state, and manual sync'**
  String get settingsSectionSyncHint;

  /// No description provided for @settingsSectionAppearanceLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'Theme density, transcript font, and locale'**
  String get settingsSectionAppearanceLanguageHint;

  /// No description provided for @hotkeysSectionKeyboardHint.
  ///
  /// In en, this message translates to:
  /// **'Reference and customize shortcuts'**
  String get hotkeysSectionKeyboardHint;

  /// No description provided for @settingsSectionAdvancedHint.
  ///
  /// In en, this message translates to:
  /// **'API endpoints and experimental toggles'**
  String get settingsSectionAdvancedHint;

  /// No description provided for @settingsSectionDeveloperHint.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics and internal tooling'**
  String get settingsSectionDeveloperHint;

  /// No description provided for @settingsSectionAboutHint.
  ///
  /// In en, this message translates to:
  /// **'Version, licenses, and links'**
  String get settingsSectionAboutHint;

  /// No description provided for @settingsSectionSync.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync'**
  String get settingsSectionSync;

  /// No description provided for @syncSettingsTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync status'**
  String get syncSettingsTileTitle;

  /// No description provided for @syncSettingsTileSubtitleSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync library and recordings'**
  String get syncSettingsTileSubtitleSignedOut;

  /// No description provided for @syncSettingsTileSubtitleUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get syncSettingsTileSubtitleUpToDate;

  /// Subtitle on Settings → Sync status when there are queue items.
  ///
  /// In en, this message translates to:
  /// **'{retryable} waiting · {failed} failed'**
  String syncSettingsTileSubtitleCounts(int retryable, int failed);

  /// No description provided for @syncScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync status'**
  String get syncScreenTitle;

  /// No description provided for @syncScreenLastSyncLabel.
  ///
  /// In en, this message translates to:
  /// **'Last successful sync'**
  String get syncScreenLastSyncLabel;

  /// No description provided for @syncScreenLastSyncNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get syncScreenLastSyncNever;

  /// No description provided for @syncScreenStatRetryable.
  ///
  /// In en, this message translates to:
  /// **'Waiting to upload'**
  String get syncScreenStatRetryable;

  /// No description provided for @syncScreenStatFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed permanently'**
  String get syncScreenStatFailed;

  /// No description provided for @syncScreenSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncScreenSyncNow;

  /// No description provided for @syncScreenRetryFailed.
  ///
  /// In en, this message translates to:
  /// **'Retry failed items'**
  String get syncScreenRetryFailed;

  /// No description provided for @syncScreenSignedOutBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your Enjoy account to sync metadata across devices.'**
  String get syncScreenSignedOutBody;

  /// No description provided for @syncScreenGoSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get syncScreenGoSignIn;

  /// No description provided for @cloudScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get cloudScreenTitle;

  /// No description provided for @cloudTabAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get cloudTabAudio;

  /// No description provided for @cloudTabVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get cloudTabVideo;

  /// No description provided for @cloudSignedOutBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in to browse media saved to your Enjoy account.'**
  String get cloudSignedOutBody;

  /// No description provided for @cloudAddToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Add to library'**
  String get cloudAddToLibrary;

  /// No description provided for @cloudAlreadyInLibrary.
  ///
  /// In en, this message translates to:
  /// **'Already in library'**
  String get cloudAlreadyInLibrary;

  /// No description provided for @cloudAddedToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Added to your local library.'**
  String get cloudAddedToLibrary;

  /// No description provided for @cloudEmpty.
  ///
  /// In en, this message translates to:
  /// **'No items in this list.'**
  String get cloudEmpty;

  /// No description provided for @cloudHasMediaUrlHint.
  ///
  /// In en, this message translates to:
  /// **'Streams from your saved URL when opened.'**
  String get cloudHasMediaUrlHint;

  /// No description provided for @cloudNoMediaUrlHint.
  ///
  /// In en, this message translates to:
  /// **'No remote file URL — use Locate file in the player when you open this item.'**
  String get cloudNoMediaUrlHint;

  /// No description provided for @cloudRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh this tab'**
  String get cloudRefreshTooltip;

  /// No description provided for @cloudAddToLibraryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add to library'**
  String get cloudAddToLibraryTooltip;

  /// No description provided for @cloudEmptyAudioTitle.
  ///
  /// In en, this message translates to:
  /// **'No cloud audio yet'**
  String get cloudEmptyAudioTitle;

  /// No description provided for @cloudEmptyAudioSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Items you save while signed in will appear here.'**
  String get cloudEmptyAudioSubtitle;

  /// No description provided for @cloudEmptyVideoTitle.
  ///
  /// In en, this message translates to:
  /// **'No cloud video yet'**
  String get cloudEmptyVideoTitle;

  /// No description provided for @cloudEmptyVideoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Items you save while signed in will appear here.'**
  String get cloudEmptyVideoSubtitle;

  /// No description provided for @syncSnackSuccess.
  ///
  /// In en, this message translates to:
  /// **'Sync finished successfully.'**
  String get syncSnackSuccess;

  /// No description provided for @syncSnackIssues.
  ///
  /// In en, this message translates to:
  /// **'Sync finished: {synced} succeeded, {failed} failed.'**
  String syncSnackIssues(int synced, int failed);

  /// No description provided for @syncQueueDetails.
  ///
  /// In en, this message translates to:
  /// **'Queue details'**
  String get syncQueueDetails;

  /// No description provided for @syncQueueEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing in the queue.'**
  String get syncQueueEmpty;

  /// No description provided for @settingsSectionAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get settingsSectionAdvanced;

  /// No description provided for @settingsApiBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'API base URL'**
  String get settingsApiBaseUrl;

  /// No description provided for @settingsApiBaseUrlHint.
  ///
  /// In en, this message translates to:
  /// **'Example: https://enjoy.bot'**
  String get settingsApiBaseUrlHint;

  /// No description provided for @settingsApiBaseUrlSave.
  ///
  /// In en, this message translates to:
  /// **'Save API URL'**
  String get settingsApiBaseUrlSave;

  /// No description provided for @settingsAiApiBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'AI API base URL'**
  String get settingsAiApiBaseUrl;

  /// No description provided for @settingsAiApiBaseUrlHint.
  ///
  /// In en, this message translates to:
  /// **'Example: https://worker.enjoy.bot'**
  String get settingsAiApiBaseUrlHint;

  /// No description provided for @settingsAiApiBaseUrlSave.
  ///
  /// In en, this message translates to:
  /// **'Save AI API URL'**
  String get settingsAiApiBaseUrlSave;

  /// No description provided for @settingsAiApiBaseUrlUseDefault.
  ///
  /// In en, this message translates to:
  /// **'Use API URL'**
  String get settingsAiApiBaseUrlUseDefault;

  /// No description provided for @settingsAiApiBaseUrlCleared.
  ///
  /// In en, this message translates to:
  /// **'AI API now follows the main API URL.'**
  String get settingsAiApiBaseUrlCleared;

  /// No description provided for @settingsAccountSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get settingsAccountSignedOut;

  /// No description provided for @settingsAccountOpenProfile.
  ///
  /// In en, this message translates to:
  /// **'Open profile'**
  String get settingsAccountOpenProfile;

  /// No description provided for @settingsAccountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get settingsAccountSignIn;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error'**
  String get errorNetwork;

  /// No description provided for @errorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Session expired — please sign in again'**
  String get errorUnauthorized;

  /// No description provided for @communityActivity.
  ///
  /// In en, this message translates to:
  /// **'Community Activity'**
  String get communityActivity;

  /// No description provided for @communityToday.
  ///
  /// In en, this message translates to:
  /// **'Community Today'**
  String get communityToday;

  /// No description provided for @homeRecordingsToday.
  ///
  /// In en, this message translates to:
  /// **'Recordings'**
  String get homeRecordingsToday;

  /// No description provided for @homePracticeTime.
  ///
  /// In en, this message translates to:
  /// **'Practice Time'**
  String get homePracticeTime;

  /// No description provided for @homeActiveLearners.
  ///
  /// In en, this message translates to:
  /// **'Active Learners'**
  String get homeActiveLearners;

  /// Headline for how many people are learning in the community.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} person learning} other{{count} people learning}}'**
  String homePeopleLearning(int count);

  /// No description provided for @homeNoActiveUsers.
  ///
  /// In en, this message translates to:
  /// **'No active users'**
  String get homeNoActiveUsers;

  /// No description provided for @homeTodaysGoal.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Goal'**
  String get homeTodaysGoal;

  /// No description provided for @homeMinutes.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get homeMinutes;

  /// No description provided for @homeCompleted.
  ///
  /// In en, this message translates to:
  /// **'completed'**
  String get homeCompleted;

  /// No description provided for @homeGoalCompleted.
  ///
  /// In en, this message translates to:
  /// **'Goal completed! Great job!'**
  String get homeGoalCompleted;

  /// No description provided for @homeGoalAlmostThere.
  ///
  /// In en, this message translates to:
  /// **'Almost there! Keep going!'**
  String get homeGoalAlmostThere;

  /// No description provided for @homeGoalHalfway.
  ///
  /// In en, this message translates to:
  /// **'Halfway there! You can do it!'**
  String get homeGoalHalfway;

  /// No description provided for @homeGoalGoodStart.
  ///
  /// In en, this message translates to:
  /// **'Good start! Keep practicing!'**
  String get homeGoalGoodStart;

  /// No description provided for @homeGoalJustStarted.
  ///
  /// In en, this message translates to:
  /// **'Just started! Every minute counts!'**
  String get homeGoalJustStarted;

  /// No description provided for @homeGoalStartNow.
  ///
  /// In en, this message translates to:
  /// **'Start your practice now!'**
  String get homeGoalStartNow;

  /// No description provided for @mediaLocateTitle.
  ///
  /// In en, this message translates to:
  /// **'Locate media file'**
  String get mediaLocateTitle;

  /// No description provided for @mediaLocateBody.
  ///
  /// In en, this message translates to:
  /// **'This item was added on another device. Choose the same file on this computer. We verify it matches your library using a secure fingerprint.'**
  String get mediaLocateBody;

  /// No description provided for @mediaLocateChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get mediaLocateChooseFile;

  /// No description provided for @mediaLocateHashMismatch.
  ///
  /// In en, this message translates to:
  /// **'That file does not match this item. Make sure you selected the correct file.'**
  String get mediaLocateHashMismatch;

  /// No description provided for @mediaLocateExpectedSize.
  ///
  /// In en, this message translates to:
  /// **'Expected size: {sizeLabel}'**
  String mediaLocateExpectedSize(String sizeLabel);

  /// No description provided for @mediaLocateSizeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Expected size: unknown'**
  String get mediaLocateSizeUnknown;

  /// No description provided for @libraryDeleteMediaTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete from library?'**
  String get libraryDeleteMediaTitle;

  /// No description provided for @libraryDeleteMediaMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{title}\" from this device. This cannot be undone.'**
  String libraryDeleteMediaMessage(String title);

  /// No description provided for @libraryDeleteMediaTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete from library'**
  String get libraryDeleteMediaTooltip;

  /// No description provided for @libraryMediaDeleted.
  ///
  /// In en, this message translates to:
  /// **'Removed from library.'**
  String get libraryMediaDeleted;

  /// No description provided for @libraryDeleteMediaFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not remove this item.'**
  String get libraryDeleteMediaFailed;

  /// Tooltip/label shown on library items whose crafted audio is synced to cloud storage and playable from any signed-in device.
  ///
  /// In en, this message translates to:
  /// **'Synced to cloud'**
  String get cloudSyncBadgeSynced;

  /// Tooltip/label shown on crafted audios that have been queued for cloud upload but not yet completed (e.g. offline at save time).
  ///
  /// In en, this message translates to:
  /// **'Pending sync'**
  String get cloudSyncBadgePending;

  /// Tooltip/label shown on library items that have not been uploaded to cloud storage (e.g. imported user files, pre-feature crafted audios that have not yet been synced).
  ///
  /// In en, this message translates to:
  /// **'Local only'**
  String get cloudSyncBadgeLocalOnly;

  /// No description provided for @settingsSectionDeveloper.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get settingsSectionDeveloper;

  /// No description provided for @settingsAiPlaygroundTileTitle.
  ///
  /// In en, this message translates to:
  /// **'AI playground'**
  String get settingsAiPlaygroundTileTitle;

  /// No description provided for @settingsAiPlaygroundTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Exercise ASR, chat, translation, and dictionary APIs'**
  String get settingsAiPlaygroundTileSubtitle;

  /// No description provided for @aiPlaygroundTitle.
  ///
  /// In en, this message translates to:
  /// **'AI playground'**
  String get aiPlaygroundTitle;

  /// No description provided for @aiPlaygroundIntro.
  ///
  /// In en, this message translates to:
  /// **'Exercise AI modalities using Enjoy cloud or your BYOK credentials from Settings → AI providers. Translation and dictionary follow the LLM provider.'**
  String get aiPlaygroundIntro;

  /// No description provided for @aiPlaygroundActiveProviders.
  ///
  /// In en, this message translates to:
  /// **'Active providers'**
  String get aiPlaygroundActiveProviders;

  /// BYOK provider label with preset or vendor detail
  ///
  /// In en, this message translates to:
  /// **'BYOK · {detail}'**
  String aiPlaygroundProviderByokDetail(String detail);

  /// No description provided for @aiPlaygroundPickAudio.
  ///
  /// In en, this message translates to:
  /// **'Pick audio file'**
  String get aiPlaygroundPickAudio;

  /// No description provided for @aiPlaygroundTranscribe.
  ///
  /// In en, this message translates to:
  /// **'Transcribe'**
  String get aiPlaygroundTranscribe;

  /// No description provided for @aiPlaygroundChatSystem.
  ///
  /// In en, this message translates to:
  /// **'System (optional)'**
  String get aiPlaygroundChatSystem;

  /// No description provided for @aiPlaygroundChatUser.
  ///
  /// In en, this message translates to:
  /// **'User message'**
  String get aiPlaygroundChatUser;

  /// No description provided for @aiPlaygroundSendChat.
  ///
  /// In en, this message translates to:
  /// **'Send chat'**
  String get aiPlaygroundSendChat;

  /// No description provided for @aiPlaygroundTranslateSource.
  ///
  /// In en, this message translates to:
  /// **'Source language'**
  String get aiPlaygroundTranslateSource;

  /// No description provided for @aiPlaygroundTranslateTarget.
  ///
  /// In en, this message translates to:
  /// **'Target language'**
  String get aiPlaygroundTranslateTarget;

  /// No description provided for @aiPlaygroundTranslateText.
  ///
  /// In en, this message translates to:
  /// **'Text to translate'**
  String get aiPlaygroundTranslateText;

  /// No description provided for @aiPlaygroundTranslate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get aiPlaygroundTranslate;

  /// No description provided for @aiPlaygroundDictWord.
  ///
  /// In en, this message translates to:
  /// **'Word'**
  String get aiPlaygroundDictWord;

  /// No description provided for @aiPlaygroundDictSource.
  ///
  /// In en, this message translates to:
  /// **'Source language'**
  String get aiPlaygroundDictSource;

  /// No description provided for @aiPlaygroundDictTarget.
  ///
  /// In en, this message translates to:
  /// **'Target language'**
  String get aiPlaygroundDictTarget;

  /// No description provided for @aiPlaygroundDictLookup.
  ///
  /// In en, this message translates to:
  /// **'Dictionary lookup'**
  String get aiPlaygroundDictLookup;

  /// No description provided for @aiPlaygroundAssessmentReference.
  ///
  /// In en, this message translates to:
  /// **'Reference text (what you spoke)'**
  String get aiPlaygroundAssessmentReference;

  /// No description provided for @aiPlaygroundAssessmentLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language (e.g. en, en-US)'**
  String get aiPlaygroundAssessmentLanguage;

  /// No description provided for @aiPlaygroundAssess.
  ///
  /// In en, this message translates to:
  /// **'Run pronunciation assessment'**
  String get aiPlaygroundAssess;

  /// No description provided for @aiPlaygroundAssessmentTtsNote.
  ///
  /// In en, this message translates to:
  /// **'Enjoy TTS is not wired yet; configure TTS BYOK under AI providers for synthesis. Assessment uses the provider shown above.'**
  String get aiPlaygroundAssessmentTtsNote;

  /// No description provided for @aiPlaygroundOutput.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get aiPlaygroundOutput;

  /// No description provided for @aiPlaygroundClearOutput.
  ///
  /// In en, this message translates to:
  /// **'Clear output'**
  String get aiPlaygroundClearOutput;

  /// No description provided for @aiPlaygroundSectionAsr.
  ///
  /// In en, this message translates to:
  /// **'ASR'**
  String get aiPlaygroundSectionAsr;

  /// No description provided for @aiPlaygroundSectionChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get aiPlaygroundSectionChat;

  /// No description provided for @aiPlaygroundSectionTranslation.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get aiPlaygroundSectionTranslation;

  /// No description provided for @aiPlaygroundSectionDictionary.
  ///
  /// In en, this message translates to:
  /// **'Dictionary'**
  String get aiPlaygroundSectionDictionary;

  /// No description provided for @aiPlaygroundSectionTtsAssessment.
  ///
  /// In en, this message translates to:
  /// **'TTS / Assessment'**
  String get aiPlaygroundSectionTtsAssessment;

  /// No description provided for @youtubePasteFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get youtubePasteFromClipboard;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tune Enjoy to fit how you study.'**
  String get settingsSubtitle;

  /// No description provided for @settingsAuthLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t refresh your account. Check your connection and try again.'**
  String get settingsAuthLoadFailed;

  /// No description provided for @settingsSectionAppearanceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Appearance & Language'**
  String get settingsSectionAppearanceLanguage;

  /// No description provided for @settingsAppearanceTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsAppearanceTheme;

  /// No description provided for @settingsAppearanceThemeValue.
  ///
  /// In en, this message translates to:
  /// **'Dark · Cinematic'**
  String get settingsAppearanceThemeValue;

  /// No description provided for @settingsAppearanceThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsAppearanceThemeSystem;

  /// No description provided for @settingsAppearanceThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsAppearanceThemeLight;

  /// No description provided for @settingsAppearanceThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsAppearanceThemeDark;

  /// No description provided for @settingsAppearanceDisplayLanguage.
  ///
  /// In en, this message translates to:
  /// **'Display language'**
  String get settingsAppearanceDisplayLanguage;

  /// No description provided for @settingsAppearanceLearningLanguage.
  ///
  /// In en, this message translates to:
  /// **'Learning language'**
  String get settingsAppearanceLearningLanguage;

  /// No description provided for @settingsAppearanceNativeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Native language'**
  String get settingsAppearanceNativeLanguage;

  /// No description provided for @settingsAppearanceSyncedFromProfile.
  ///
  /// In en, this message translates to:
  /// **'Synced from your account profile'**
  String get settingsAppearanceSyncedFromProfile;

  /// No description provided for @settingsLanguageSubtitleSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Also updates your Enjoy profile when online.'**
  String get settingsLanguageSubtitleSignedIn;

  /// No description provided for @settingsLanguageSubtitleDeviceOnly.
  ///
  /// In en, this message translates to:
  /// **'Stored on this device until you sign in.'**
  String get settingsLanguageSubtitleDeviceOnly;

  /// No description provided for @settingsLanguageOptionEnUs.
  ///
  /// In en, this message translates to:
  /// **'English (United States)'**
  String get settingsLanguageOptionEnUs;

  /// No description provided for @settingsLanguageOptionEnGb.
  ///
  /// In en, this message translates to:
  /// **'English (United Kingdom)'**
  String get settingsLanguageOptionEnGb;

  /// No description provided for @settingsLanguageOptionJaJp.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get settingsLanguageOptionJaJp;

  /// No description provided for @settingsLanguageOptionKoKr.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get settingsLanguageOptionKoKr;

  /// No description provided for @settingsLanguageOptionEsEs.
  ///
  /// In en, this message translates to:
  /// **'Spanish (Spain)'**
  String get settingsLanguageOptionEsEs;

  /// No description provided for @settingsLanguageOptionEsMx.
  ///
  /// In en, this message translates to:
  /// **'Spanish (Mexico)'**
  String get settingsLanguageOptionEsMx;

  /// No description provided for @settingsLanguageOptionFrFr.
  ///
  /// In en, this message translates to:
  /// **'French (France)'**
  String get settingsLanguageOptionFrFr;

  /// No description provided for @settingsLanguageOptionFrCa.
  ///
  /// In en, this message translates to:
  /// **'French (Canada)'**
  String get settingsLanguageOptionFrCa;

  /// No description provided for @settingsLanguageOptionZhCn.
  ///
  /// In en, this message translates to:
  /// **'Chinese (Simplified, China)'**
  String get settingsLanguageOptionZhCn;

  /// No description provided for @settingsLearningLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Default for Discover and import suggestions.'**
  String get settingsLearningLanguageSubtitle;

  /// No description provided for @settingsLanguagePickerTitleLearning.
  ///
  /// In en, this message translates to:
  /// **'Learning language'**
  String get settingsLanguagePickerTitleLearning;

  /// No description provided for @mediaLanguageUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get mediaLanguageUnknown;

  /// No description provided for @mediaLanguagePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Content language'**
  String get mediaLanguagePickerTitle;

  /// No description provided for @mediaEditLanguage.
  ///
  /// In en, this message translates to:
  /// **'Edit language'**
  String get mediaEditLanguage;

  /// No description provided for @mediaLanguageUpdated.
  ///
  /// In en, this message translates to:
  /// **'Language updated.'**
  String get mediaLanguageUpdated;

  /// No description provided for @mediaLanguageUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update language.'**
  String get mediaLanguageUpdateFailed;

  /// No description provided for @assessmentUnavailableLanguage.
  ///
  /// In en, this message translates to:
  /// **'Pronunciation assessment is not available for this language.'**
  String get assessmentUnavailableLanguage;

  /// No description provided for @discoverLanguageFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All languages'**
  String get discoverLanguageFilterAll;

  /// No description provided for @discoverLanguageFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get discoverLanguageFilterLabel;

  /// No description provided for @settingsNativeMustDifferHint.
  ///
  /// In en, this message translates to:
  /// **'Must differ from your learning language.'**
  String get settingsNativeMustDifferHint;

  /// No description provided for @settingsLanguagePickerTitleDisplay.
  ///
  /// In en, this message translates to:
  /// **'Display language'**
  String get settingsLanguagePickerTitleDisplay;

  /// No description provided for @settingsLanguagePickerTitleNative.
  ///
  /// In en, this message translates to:
  /// **'Native language'**
  String get settingsLanguagePickerTitleNative;

  /// No description provided for @profileFieldDisplayLanguage.
  ///
  /// In en, this message translates to:
  /// **'Display language'**
  String get profileFieldDisplayLanguage;

  /// No description provided for @profileLearningLanguageReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Choose the language you are learning.'**
  String get profileLearningLanguageReadOnly;

  /// No description provided for @settingsKeyboardOpenCheatsheet.
  ///
  /// In en, this message translates to:
  /// **'Open shortcuts cheatsheet'**
  String get settingsKeyboardOpenCheatsheet;

  /// No description provided for @settingsKeyboardOpenCheatsheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse and customize every shortcut'**
  String get settingsKeyboardOpenCheatsheetSubtitle;

  /// No description provided for @settingsKeyboardCustomizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Customize shortcuts'**
  String get settingsKeyboardCustomizeTitle;

  /// No description provided for @hotkeysHelpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Press {key} anytime to open this list.'**
  String hotkeysHelpSubtitle(String key);

  /// No description provided for @hotkeysHelpSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search shortcuts'**
  String get hotkeysHelpSearchHint;

  /// No description provided for @hotkeysHelpEmpty.
  ///
  /// In en, this message translates to:
  /// **'No matching shortcuts'**
  String get hotkeysHelpEmpty;

  /// No description provided for @hotkeysHelpCustomize.
  ///
  /// In en, this message translates to:
  /// **'Customize shortcuts'**
  String get hotkeysHelpCustomize;

  /// No description provided for @hotkeysSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap a row to change. Press {key} anytime.'**
  String hotkeysSettingsSubtitle(String key);

  /// No description provided for @hotkeysFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Filter shortcuts'**
  String get hotkeysFilterHint;

  /// No description provided for @hotkeysResetTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reset this shortcut'**
  String get hotkeysResetTooltip;

  /// No description provided for @hotkeysEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Change shortcut'**
  String get hotkeysEditTooltip;

  /// No description provided for @settingsAboutMadeWithCare.
  ///
  /// In en, this message translates to:
  /// **'Made with care for language learners.'**
  String get settingsAboutMadeWithCare;

  /// No description provided for @settingsAboutVersion.
  ///
  /// In en, this message translates to:
  /// **'v{version}'**
  String settingsAboutVersion(String version);

  /// No description provided for @settingsAboutOpenSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Open source'**
  String get settingsAboutOpenSourceTitle;

  /// No description provided for @settingsAboutOpenSourceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View source code on GitHub'**
  String get settingsAboutOpenSourceSubtitle;

  /// No description provided for @settingsAboutContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact the developer'**
  String get settingsAboutContactTitle;

  /// No description provided for @settingsAboutContactSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send feedback or report a bug directly'**
  String get settingsAboutContactSubtitle;

  /// No description provided for @settingsAboutContactEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get settingsAboutContactEmailLabel;

  /// No description provided for @settingsAboutContactWeChatLabel.
  ///
  /// In en, this message translates to:
  /// **'WeChat'**
  String get settingsAboutContactWeChatLabel;

  /// No description provided for @settingsAboutContactMixinLabel.
  ///
  /// In en, this message translates to:
  /// **'Mixin'**
  String get settingsAboutContactMixinLabel;

  /// No description provided for @settingsAboutContactCopiedEmail.
  ///
  /// In en, this message translates to:
  /// **'Email copied to clipboard'**
  String get settingsAboutContactCopiedEmail;

  /// No description provided for @settingsAboutContactCopiedWeChat.
  ///
  /// In en, this message translates to:
  /// **'WeChat ID copied to clipboard'**
  String get settingsAboutContactCopiedWeChat;

  /// No description provided for @settingsAboutContactCopiedMixin.
  ///
  /// In en, this message translates to:
  /// **'Mixin ID copied to clipboard'**
  String get settingsAboutContactCopiedMixin;

  /// No description provided for @settingsDiagnosticsLoggingTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic logging'**
  String get settingsDiagnosticsLoggingTitle;

  /// No description provided for @settingsDiagnosticsLoggingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Record extra detail for YouTube, sync, and sign-in issues'**
  String get settingsDiagnosticsLoggingSubtitle;

  /// No description provided for @settingsDiagnosticsPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Logs stay on this device until you export them. Tokens and cookies are redacted.'**
  String get settingsDiagnosticsPrivacyNote;

  /// No description provided for @settingsDiagnosticsExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export diagnostic report'**
  String get settingsDiagnosticsExportTitle;

  /// No description provided for @settingsDiagnosticsExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save a zip of recent logs for support'**
  String get settingsDiagnosticsExportSubtitle;

  /// No description provided for @settingsDiagnosticsExportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic report saved.'**
  String get settingsDiagnosticsExportSuccess;

  /// No description provided for @settingsDiagnosticsExportError.
  ///
  /// In en, this message translates to:
  /// **'Could not export diagnostic report.'**
  String get settingsDiagnosticsExportError;

  /// No description provided for @settingsCheckForUpdatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get settingsCheckForUpdatesTitle;

  /// No description provided for @settingsCheckForUpdatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See if a newer direct-download build is available'**
  String get settingsCheckForUpdatesSubtitle;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailableTitle;

  /// No description provided for @updateAvailableBadgeSemantics.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailableBadgeSemantics;

  /// No description provided for @updateMandatoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get updateMandatoryTitle;

  /// No description provided for @updateVersionLine.
  ///
  /// In en, this message translates to:
  /// **'Installed {current} → {latest}'**
  String updateVersionLine(String current, String latest);

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get updateNow;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @updateDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get updateDismiss;

  /// No description provided for @updateCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get updateCancel;

  /// No description provided for @updateRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get updateRetry;

  /// No description provided for @updatePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing download…'**
  String get updatePreparing;

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading update… {percent}%'**
  String updateDownloading(int percent);

  /// No description provided for @updateVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying download…'**
  String get updateVerifying;

  /// No description provided for @updateOpeningInstaller.
  ///
  /// In en, this message translates to:
  /// **'Opening installer…'**
  String get updateOpeningInstaller;

  /// No description provided for @updateErrorDownload.
  ///
  /// In en, this message translates to:
  /// **'Download failed. Check your connection and try again.'**
  String get updateErrorDownload;

  /// No description provided for @updateErrorChecksum.
  ///
  /// In en, this message translates to:
  /// **'The download was corrupted. Please try again.'**
  String get updateErrorChecksum;

  /// No description provided for @updateErrorPermission.
  ///
  /// In en, this message translates to:
  /// **'Install permission was denied. Allow installs from this app in system settings, then retry.'**
  String get updateErrorPermission;

  /// No description provided for @updateErrorAlreadyRunning.
  ///
  /// In en, this message translates to:
  /// **'An update download is already in progress.'**
  String get updateErrorAlreadyRunning;

  /// No description provided for @updateErrorInstallation.
  ///
  /// In en, this message translates to:
  /// **'Could not open the installer. Please try again.'**
  String get updateErrorInstallation;

  /// No description provided for @updateErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Update failed. Please try again.'**
  String get updateErrorGeneric;

  /// No description provided for @updateUpToDate.
  ///
  /// In en, this message translates to:
  /// **'You\'re on the latest version.'**
  String get updateUpToDate;

  /// No description provided for @updateCheckOffline.
  ///
  /// In en, this message translates to:
  /// **'Could not check for updates. Check your connection.'**
  String get updateCheckOffline;

  /// No description provided for @updateStoreChannelHint.
  ///
  /// In en, this message translates to:
  /// **'This build is from TestFlight or the Play Store — updates are handled by the store.'**
  String get updateStoreChannelHint;

  /// No description provided for @lookupSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Look up'**
  String get lookupSheetTitle;

  /// No description provided for @lookupSectionTranslation.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get lookupSectionTranslation;

  /// No description provided for @lookupSectionContextualTranslation.
  ///
  /// In en, this message translates to:
  /// **'Contextual translation'**
  String get lookupSectionContextualTranslation;

  /// No description provided for @lookupSectionDictionary.
  ///
  /// In en, this message translates to:
  /// **'Definition'**
  String get lookupSectionDictionary;

  /// No description provided for @lookupLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get lookupLoading;

  /// No description provided for @lookupErrorRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get lookupErrorRetry;

  /// No description provided for @lookupEmpty.
  ///
  /// In en, this message translates to:
  /// **'No result.'**
  String get lookupEmpty;

  /// No description provided for @lookupLemma.
  ///
  /// In en, this message translates to:
  /// **'Lemma'**
  String get lookupLemma;

  /// No description provided for @lookupIpa.
  ///
  /// In en, this message translates to:
  /// **'IPA'**
  String get lookupIpa;

  /// No description provided for @lookupExamples.
  ///
  /// In en, this message translates to:
  /// **'Examples'**
  String get lookupExamples;

  /// No description provided for @lookupClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get lookupClose;

  /// No description provided for @lookupCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get lookupCopy;

  /// No description provided for @lookupCopySuccess.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get lookupCopySuccess;

  /// No description provided for @lookupTapToExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand to load'**
  String get lookupTapToExpand;

  /// No description provided for @lookupSourceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Source language'**
  String get lookupSourceLanguage;

  /// No description provided for @lookupTargetLanguage.
  ///
  /// In en, this message translates to:
  /// **'Target language'**
  String get lookupTargetLanguage;

  /// No description provided for @lookupSwapLanguages.
  ///
  /// In en, this message translates to:
  /// **'Swap languages'**
  String get lookupSwapLanguages;

  /// No description provided for @lookupPickSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose source language'**
  String get lookupPickSourceTitle;

  /// No description provided for @lookupPickTargetTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose target language'**
  String get lookupPickTargetTitle;

  /// No description provided for @lookupRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get lookupRefresh;

  /// No description provided for @lookupCloudRequiresSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in under Settings to use cloud dictionary, translation, and contextual translation.'**
  String get lookupCloudRequiresSignIn;

  /// No description provided for @lookupLanguageEnUs.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get lookupLanguageEnUs;

  /// No description provided for @lookupLanguageEnGb.
  ///
  /// In en, this message translates to:
  /// **'English (UK)'**
  String get lookupLanguageEnGb;

  /// No description provided for @lookupLanguageZhCn.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get lookupLanguageZhCn;

  /// No description provided for @lookupLanguageJaJp.
  ///
  /// In en, this message translates to:
  /// **'日本語'**
  String get lookupLanguageJaJp;

  /// No description provided for @lookupLanguageKoKr.
  ///
  /// In en, this message translates to:
  /// **'한국어'**
  String get lookupLanguageKoKr;

  /// No description provided for @lookupLanguageEsEs.
  ///
  /// In en, this message translates to:
  /// **'Español (España)'**
  String get lookupLanguageEsEs;

  /// No description provided for @lookupLanguageEsMx.
  ///
  /// In en, this message translates to:
  /// **'Español (México)'**
  String get lookupLanguageEsMx;

  /// No description provided for @lookupLanguageFrFr.
  ///
  /// In en, this message translates to:
  /// **'Français (France)'**
  String get lookupLanguageFrFr;

  /// No description provided for @lookupLanguageFrCa.
  ///
  /// In en, this message translates to:
  /// **'Français (Canada)'**
  String get lookupLanguageFrCa;

  /// No description provided for @lookupLanguageDeDe.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get lookupLanguageDeDe;

  /// No description provided for @lookupLanguageItIt.
  ///
  /// In en, this message translates to:
  /// **'Italiano'**
  String get lookupLanguageItIt;

  /// No description provided for @lookupLanguagePtBr.
  ///
  /// In en, this message translates to:
  /// **'Português (Brasil)'**
  String get lookupLanguagePtBr;

  /// No description provided for @lookupLanguagePtPt.
  ///
  /// In en, this message translates to:
  /// **'Português (Portugal)'**
  String get lookupLanguagePtPt;

  /// No description provided for @lookupLanguageRuRu.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get lookupLanguageRuRu;

  /// No description provided for @lookupSourceResetToLearning.
  ///
  /// In en, this message translates to:
  /// **'Source language reset to learning default'**
  String get lookupSourceResetToLearning;

  /// No description provided for @vocabularyAddToVocabulary.
  ///
  /// In en, this message translates to:
  /// **'Add to Vocabulary'**
  String get vocabularyAddToVocabulary;

  /// No description provided for @vocabularyAddContext.
  ///
  /// In en, this message translates to:
  /// **'Add Context'**
  String get vocabularyAddContext;

  /// No description provided for @vocabularyAlreadyInVocabulary.
  ///
  /// In en, this message translates to:
  /// **'Already in Vocabulary'**
  String get vocabularyAlreadyInVocabulary;

  /// No description provided for @vocabularyAdding.
  ///
  /// In en, this message translates to:
  /// **'Adding…'**
  String get vocabularyAdding;

  /// No description provided for @vocabularyRemoving.
  ///
  /// In en, this message translates to:
  /// **'Removing…'**
  String get vocabularyRemoving;

  /// No description provided for @vocabularyConfirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove from vocabulary?'**
  String get vocabularyConfirmDeleteTitle;

  /// No description provided for @vocabularyConfirmDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This deletes the word and all of its contexts.'**
  String get vocabularyConfirmDeleteBody;

  /// No description provided for @vocabularyCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get vocabularyCancel;

  /// No description provided for @vocabularyDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get vocabularyDelete;

  /// No description provided for @vocabularyTitle.
  ///
  /// In en, this message translates to:
  /// **'Vocabulary'**
  String get vocabularyTitle;

  /// No description provided for @vocabularyProfileEntry.
  ///
  /// In en, this message translates to:
  /// **'Vocabulary'**
  String get vocabularyProfileEntry;

  /// No description provided for @vocabularyProfileEntryHint.
  ///
  /// In en, this message translates to:
  /// **'Review saved words and flashcards'**
  String get vocabularyProfileEntryHint;

  /// No description provided for @vocabularyReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get vocabularyReview;

  /// No description provided for @vocabularyAllWords.
  ///
  /// In en, this message translates to:
  /// **'All Words'**
  String get vocabularyAllWords;

  /// No description provided for @vocabularyTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get vocabularyTotal;

  /// No description provided for @vocabularyDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get vocabularyDue;

  /// No description provided for @vocabularyStatusNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get vocabularyStatusNew;

  /// No description provided for @vocabularyStatusLearning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get vocabularyStatusLearning;

  /// No description provided for @vocabularyStatusReviewing.
  ///
  /// In en, this message translates to:
  /// **'Reviewing'**
  String get vocabularyStatusReviewing;

  /// No description provided for @vocabularyStatusMastered.
  ///
  /// In en, this message translates to:
  /// **'Mastered'**
  String get vocabularyStatusMastered;

  /// No description provided for @vocabularyNoWords.
  ///
  /// In en, this message translates to:
  /// **'No words yet'**
  String get vocabularyNoWords;

  /// No description provided for @vocabularyNoWordsDescription.
  ///
  /// In en, this message translates to:
  /// **'Select text in a transcript and choose Add to Vocabulary to start your word book.'**
  String get vocabularyNoWordsDescription;

  /// No description provided for @vocabularyNoDueItems.
  ///
  /// In en, this message translates to:
  /// **'Nothing due right now'**
  String get vocabularyNoDueItems;

  /// No description provided for @vocabularyNoDueItemsDescription.
  ///
  /// In en, this message translates to:
  /// **'You can still start a custom review of all words, by status, language, or a random set.'**
  String get vocabularyNoDueItemsDescription;

  /// No description provided for @vocabularyNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching words'**
  String get vocabularyNoMatches;

  /// No description provided for @vocabularyNoMatchesDescription.
  ///
  /// In en, this message translates to:
  /// **'Try a different search or clear the status and language filters.'**
  String get vocabularyNoMatchesDescription;

  /// No description provided for @vocabularyListLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load your vocabulary.'**
  String get vocabularyListLoadFailed;

  /// No description provided for @vocabularyCustomReview.
  ///
  /// In en, this message translates to:
  /// **'Custom review'**
  String get vocabularyCustomReview;

  /// No description provided for @vocabularySelectReviewItems.
  ///
  /// In en, this message translates to:
  /// **'Choose what to review'**
  String get vocabularySelectReviewItems;

  /// No description provided for @vocabularyReviewDueItems.
  ///
  /// In en, this message translates to:
  /// **'Due items'**
  String get vocabularyReviewDueItems;

  /// No description provided for @vocabularyReviewDueHint.
  ///
  /// In en, this message translates to:
  /// **'Words scheduled for today or earlier'**
  String get vocabularyReviewDueHint;

  /// No description provided for @vocabularyReviewAll.
  ///
  /// In en, this message translates to:
  /// **'All words'**
  String get vocabularyReviewAll;

  /// No description provided for @vocabularyReviewAllHint.
  ///
  /// In en, this message translates to:
  /// **'Review every word in your book'**
  String get vocabularyReviewAllHint;

  /// No description provided for @vocabularyReviewByStatus.
  ///
  /// In en, this message translates to:
  /// **'By status'**
  String get vocabularyReviewByStatus;

  /// No description provided for @vocabularyReviewByStatusHint.
  ///
  /// In en, this message translates to:
  /// **'Focus on new, learning, reviewing, or mastered'**
  String get vocabularyReviewByStatusHint;

  /// No description provided for @vocabularyReviewByLanguage.
  ///
  /// In en, this message translates to:
  /// **'By language'**
  String get vocabularyReviewByLanguage;

  /// No description provided for @vocabularyReviewByLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'Limit the session to one source language'**
  String get vocabularyReviewByLanguageHint;

  /// No description provided for @vocabularyReviewRandom.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get vocabularyReviewRandom;

  /// No description provided for @vocabularyReviewRandomHint.
  ///
  /// In en, this message translates to:
  /// **'Shuffle and take a short practice set'**
  String get vocabularyReviewRandomHint;

  /// No description provided for @vocabularyNumberOfWords.
  ///
  /// In en, this message translates to:
  /// **'Number of words'**
  String get vocabularyNumberOfWords;

  /// No description provided for @vocabularyQueueCount.
  ///
  /// In en, this message translates to:
  /// **'{count} words'**
  String vocabularyQueueCount(int count);

  /// No description provided for @vocabularyStartReview.
  ///
  /// In en, this message translates to:
  /// **'Start review'**
  String get vocabularyStartReview;

  /// No description provided for @vocabularyEmptyQueue.
  ///
  /// In en, this message translates to:
  /// **'No words match this selection.'**
  String get vocabularyEmptyQueue;

  /// No description provided for @vocabularyExitReview.
  ///
  /// In en, this message translates to:
  /// **'Exit review'**
  String get vocabularyExitReview;

  /// No description provided for @vocabularyHowWellDoYouKnow.
  ///
  /// In en, this message translates to:
  /// **'How well do you know this?'**
  String get vocabularyHowWellDoYouKnow;

  /// No description provided for @vocabularyDontKnow.
  ///
  /// In en, this message translates to:
  /// **'Don\'t Know'**
  String get vocabularyDontKnow;

  /// No description provided for @vocabularyKnow.
  ///
  /// In en, this message translates to:
  /// **'Know'**
  String get vocabularyKnow;

  /// No description provided for @vocabularyKnowWell.
  ///
  /// In en, this message translates to:
  /// **'Know Well'**
  String get vocabularyKnowWell;

  /// No description provided for @vocabularySkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get vocabularySkip;

  /// No description provided for @vocabularyUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get vocabularyUndo;

  /// No description provided for @vocabularyProgress.
  ///
  /// In en, this message translates to:
  /// **'{current} / {total}'**
  String vocabularyProgress(int current, int total);

  /// No description provided for @vocabularyRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} remaining'**
  String vocabularyRemaining(int count);

  /// No description provided for @vocabularyFlipBack.
  ///
  /// In en, this message translates to:
  /// **'Flip back'**
  String get vocabularyFlipBack;

  /// No description provided for @vocabularyReviewComplete.
  ///
  /// In en, this message translates to:
  /// **'Review complete'**
  String get vocabularyReviewComplete;

  /// No description provided for @vocabularyReviewCompleteDescription.
  ///
  /// In en, this message translates to:
  /// **'Nice work. Your ratings are saved.'**
  String get vocabularyReviewCompleteDescription;

  /// No description provided for @vocabularyDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get vocabularyDone;

  /// No description provided for @vocabularySearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search words'**
  String get vocabularySearchPlaceholder;

  /// No description provided for @vocabularyFilterStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get vocabularyFilterStatus;

  /// No description provided for @vocabularyFilterLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get vocabularyFilterLanguage;

  /// No description provided for @vocabularyFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get vocabularyFilterAll;

  /// No description provided for @vocabularyFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get vocabularyFilters;

  /// No description provided for @vocabularyContext.
  ///
  /// In en, this message translates to:
  /// **'Context'**
  String get vocabularyContext;

  /// No description provided for @vocabularyDictionary.
  ///
  /// In en, this message translates to:
  /// **'Dictionary'**
  String get vocabularyDictionary;

  /// No description provided for @vocabularyNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get vocabularyNotes;

  /// No description provided for @vocabularyNotesPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Notes coming soon'**
  String get vocabularyNotesPlaceholder;

  /// No description provided for @vocabularyNoContextAvailable.
  ///
  /// In en, this message translates to:
  /// **'No context available'**
  String get vocabularyNoContextAvailable;

  /// No description provided for @vocabularyDictionaryNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Dictionary not available offline'**
  String get vocabularyDictionaryNotAvailable;

  /// No description provided for @vocabularyOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get vocabularyOverdue;

  /// No description provided for @vocabularyToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get vocabularyToday;

  /// No description provided for @vocabularyTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get vocabularyTomorrow;

  /// No description provided for @vocabularyInDays.
  ///
  /// In en, this message translates to:
  /// **'In {days} days'**
  String vocabularyInDays(int days);

  /// No description provided for @vocabularyKeyboardShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Shortcuts: Space flip/back · 1/2/3 rate · ← previous · → skip · Esc exit'**
  String get vocabularyKeyboardShortcuts;

  /// No description provided for @vocabularyContextsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} contexts'**
  String vocabularyContextsCount(int count);

  /// No description provided for @vocabularyReviewsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} reviews'**
  String vocabularyReviewsCount(int count);

  /// No description provided for @vocabularyFlipHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to flip'**
  String get vocabularyFlipHint;

  /// No description provided for @vocabularyPronounce.
  ///
  /// In en, this message translates to:
  /// **'Pronounce'**
  String get vocabularyPronounce;

  /// No description provided for @vocabularyFlipHintShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Space to flip · 1 / 2 / 3 to rate'**
  String get vocabularyFlipHintShortcuts;

  /// No description provided for @vocabularyPlaySegment.
  ///
  /// In en, this message translates to:
  /// **'Play segment'**
  String get vocabularyPlaySegment;

  /// No description provided for @vocabularyOpenInPlayer.
  ///
  /// In en, this message translates to:
  /// **'Open in player'**
  String get vocabularyOpenInPlayer;

  /// No description provided for @vocabularyOpenInPlayerDescription.
  ///
  /// In en, this message translates to:
  /// **'Opening the player will end this review session. Your ratings so far are saved.'**
  String get vocabularyOpenInPlayerDescription;

  /// No description provided for @vocabularyShadowReading.
  ///
  /// In en, this message translates to:
  /// **'Shadow reading'**
  String get vocabularyShadowReading;

  /// No description provided for @vocabularyShadowReadingDescription.
  ///
  /// In en, this message translates to:
  /// **'Continue to the player for shadow reading? This ends the review session. Your ratings so far are saved.'**
  String get vocabularyShadowReadingDescription;

  /// No description provided for @vocabularyEchoReading.
  ///
  /// In en, this message translates to:
  /// **'Echo reading'**
  String get vocabularyEchoReading;

  /// No description provided for @vocabularyPracticeDismiss.
  ///
  /// In en, this message translates to:
  /// **'Close practice'**
  String get vocabularyPracticeDismiss;

  /// No description provided for @vocabularyPracticePause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get vocabularyPracticePause;

  /// No description provided for @vocabularyStatsExpand.
  ///
  /// In en, this message translates to:
  /// **'Show status breakdown'**
  String get vocabularyStatsExpand;

  /// No description provided for @vocabularyStatsCollapse.
  ///
  /// In en, this message translates to:
  /// **'Hide status breakdown'**
  String get vocabularyStatsCollapse;

  /// No description provided for @vocabularyPreviousContext.
  ///
  /// In en, this message translates to:
  /// **'Previous context'**
  String get vocabularyPreviousContext;

  /// No description provided for @vocabularyNextContext.
  ///
  /// In en, this message translates to:
  /// **'Next context'**
  String get vocabularyNextContext;

  /// No description provided for @vocabularyContextOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String vocabularyContextOfTotal(int current, int total);

  /// No description provided for @vocabularyContextualTranslation.
  ///
  /// In en, this message translates to:
  /// **'Contextual translation'**
  String get vocabularyContextualTranslation;

  /// No description provided for @vocabularyFetchDictionary.
  ///
  /// In en, this message translates to:
  /// **'Look up dictionary'**
  String get vocabularyFetchDictionary;

  /// No description provided for @vocabularyFetchContextual.
  ///
  /// In en, this message translates to:
  /// **'Translate context'**
  String get vocabularyFetchContextual;

  /// No description provided for @vocabularyFetching.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get vocabularyFetching;

  /// No description provided for @vocabularyAiUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sign in to use AI lookup'**
  String get vocabularyAiUnavailable;

  /// No description provided for @vocabularyAiFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load. Try again when online.'**
  String get vocabularyAiFetchFailed;

  /// No description provided for @vocabularyMediaUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Media actions unavailable for this context'**
  String get vocabularyMediaUnavailable;

  /// No description provided for @vocabularyMediaPlayFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not play this segment'**
  String get vocabularyMediaPlayFailed;

  /// No description provided for @vocabularyMediaOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open this media'**
  String get vocabularyMediaOpenFailed;

  /// No description provided for @vocabularyConfirmContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get vocabularyConfirmContinue;

  /// No description provided for @vocabularySourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get vocabularySourceLabel;

  /// No description provided for @vocabularyUnknownSource.
  ///
  /// In en, this message translates to:
  /// **'Unknown source'**
  String get vocabularyUnknownSource;

  /// No description provided for @vocabularyLocatorLabel.
  ///
  /// In en, this message translates to:
  /// **'{start}s · {duration}s'**
  String vocabularyLocatorLabel(String start, String duration);

  /// No description provided for @vocabularyExportToAnki.
  ///
  /// In en, this message translates to:
  /// **'Export to Anki'**
  String get vocabularyExportToAnki;

  /// No description provided for @vocabularyExportDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Export to Anki'**
  String get vocabularyExportDialogTitle;

  /// No description provided for @vocabularyExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get vocabularyExport;

  /// No description provided for @vocabularyNoItemsToExport.
  ///
  /// In en, this message translates to:
  /// **'No items to export'**
  String get vocabularyNoItemsToExport;

  /// No description provided for @vocabularyProRequired.
  ///
  /// In en, this message translates to:
  /// **'Pro required'**
  String get vocabularyProRequired;

  /// No description provided for @vocabularyProRequiredDescription.
  ///
  /// In en, this message translates to:
  /// **'Anki export is available on Enjoy Pro. Upgrade to export your vocabulary as Anki CSV cards.'**
  String get vocabularyProRequiredDescription;

  /// No description provided for @vocabularyUpgradeToPro.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get vocabularyUpgradeToPro;

  /// No description provided for @vocabularyExportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Vocabulary exported.'**
  String get vocabularyExportSuccess;

  /// No description provided for @vocabularyExportError.
  ///
  /// In en, this message translates to:
  /// **'Could not export vocabulary.'**
  String get vocabularyExportError;

  /// No description provided for @vocabularyExportCancelled.
  ///
  /// In en, this message translates to:
  /// **'Export cancelled.'**
  String get vocabularyExportCancelled;

  /// No description provided for @vocabularyExportSparseCacheHint.
  ///
  /// In en, this message translates to:
  /// **'Card backs are richer when dictionary and contextual translations were saved during review.'**
  String get vocabularyExportSparseCacheHint;

  /// No description provided for @vocabularyExportProgress.
  ///
  /// In en, this message translates to:
  /// **'Exporting…'**
  String get vocabularyExportProgress;

  /// No description provided for @authRequiredCloudFeaturesTitle.
  ///
  /// In en, this message translates to:
  /// **'Account required'**
  String get authRequiredCloudFeaturesTitle;

  /// No description provided for @practicePosterShareTooltip.
  ///
  /// In en, this message translates to:
  /// **'Share practice poster'**
  String get practicePosterShareTooltip;

  /// No description provided for @practicePosterPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Share your practice'**
  String get practicePosterPreviewTitle;

  /// No description provided for @practicePosterTagline.
  ///
  /// In en, this message translates to:
  /// **'Shadow reading'**
  String get practicePosterTagline;

  /// No description provided for @practicePosterStatTakes.
  ///
  /// In en, this message translates to:
  /// **'Takes'**
  String get practicePosterStatTakes;

  /// No description provided for @practicePosterStatSentences.
  ///
  /// In en, this message translates to:
  /// **'Sentences'**
  String get practicePosterStatSentences;

  /// No description provided for @practicePosterStatSpoken.
  ///
  /// In en, this message translates to:
  /// **'Spoken'**
  String get practicePosterStatSpoken;

  /// No description provided for @practicePosterQrHint.
  ///
  /// In en, this message translates to:
  /// **'Scan to download Enjoy Player\nplayer.enjoy.bot'**
  String get practicePosterQrHint;

  /// No description provided for @practicePosterShareAction.
  ///
  /// In en, this message translates to:
  /// **'Share poster'**
  String get practicePosterShareAction;

  /// No description provided for @practicePosterShareSuccess.
  ///
  /// In en, this message translates to:
  /// **'Poster shared.'**
  String get practicePosterShareSuccess;

  /// No description provided for @practicePosterSaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Poster saved.'**
  String get practicePosterSaveSuccess;

  /// No description provided for @practicePosterExportError.
  ///
  /// In en, this message translates to:
  /// **'Could not share practice poster.'**
  String get practicePosterExportError;

  /// No description provided for @practicePosterLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load practice data for this video.'**
  String get practicePosterLoadError;

  /// No description provided for @notFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get notFoundTitle;

  /// No description provided for @notFoundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find {uri}.'**
  String notFoundSubtitle(String uri);

  /// No description provided for @notFoundBackHome.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get notFoundBackHome;

  /// No description provided for @recoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Local data needs attention'**
  String get recoveryTitle;

  /// No description provided for @recoverySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enjoy Player could not open its local database. The most common cause is a partial update. Your data is still on disk; you can copy the error before continuing.'**
  String get recoverySubtitle;

  /// No description provided for @recoveryOpenLogs.
  ///
  /// In en, this message translates to:
  /// **'Open logs folder'**
  String get recoveryOpenLogs;

  /// No description provided for @recoveryOpenLogsError.
  ///
  /// In en, this message translates to:
  /// **'Could not open the logs folder.'**
  String get recoveryOpenLogsError;

  /// No description provided for @recoveryCopyError.
  ///
  /// In en, this message translates to:
  /// **'Copy error'**
  String get recoveryCopyError;

  /// No description provided for @recoveryCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Error details copied to clipboard.'**
  String get recoveryCopiedToClipboard;

  /// No description provided for @recoveryResetLibrary.
  ///
  /// In en, this message translates to:
  /// **'Reset local library'**
  String get recoveryResetLibrary;

  /// No description provided for @recoveryResetLibrarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Wipe the local database and start fresh. Your cloud library is not affected. A backup of the current state is written to the application support directory before the wipe.'**
  String get recoveryResetLibrarySubtitle;

  /// No description provided for @recoveryResetLibraryConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset local library?'**
  String get recoveryResetLibraryConfirmTitle;

  /// No description provided for @recoveryResetLibraryConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your local library, recordings, transcripts, and sync queue. The cloud library (if signed in) is preserved. A backup is written to the application support directory first.'**
  String get recoveryResetLibraryConfirmBody;

  /// No description provided for @recoveryResetLibraryConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Reset everything'**
  String get recoveryResetLibraryConfirmAction;

  /// No description provided for @recoveryResetLibraryBackupError.
  ///
  /// In en, this message translates to:
  /// **'Backup failed — the local database was not wiped. The error has been logged.'**
  String get recoveryResetLibraryBackupError;

  /// No description provided for @recoveryResetLibrarySuccess.
  ///
  /// In en, this message translates to:
  /// **'Local library reset. Reloading your data…'**
  String get recoveryResetLibrarySuccess;

  /// No description provided for @recoveryResetLibraryError.
  ///
  /// In en, this message translates to:
  /// **'Could not reset the local library.'**
  String get recoveryResetLibraryError;

  /// No description provided for @widgetErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get widgetErrorTitle;

  /// No description provided for @widgetErrorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This screen hit an unexpected error. You can copy the details below and try navigating elsewhere.'**
  String get widgetErrorSubtitle;

  /// No description provided for @settingsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search settings'**
  String get settingsSearchHint;

  /// No description provided for @settingsSearchNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching settings'**
  String get settingsSearchNoResultsTitle;

  /// No description provided for @settingsSearchNoResultsHint.
  ///
  /// In en, this message translates to:
  /// **'Try a different word, or clear your search to browse everything.'**
  String get settingsSearchNoResultsHint;

  /// No description provided for @settingsSearchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get settingsSearchClear;

  /// No description provided for @settingsSectionExpandSemantics.
  ///
  /// In en, this message translates to:
  /// **'Expand section'**
  String get settingsSectionExpandSemantics;

  /// No description provided for @settingsSectionCollapseSemantics.
  ///
  /// In en, this message translates to:
  /// **'Collapse section'**
  String get settingsSectionCollapseSemantics;

  /// No description provided for @settingsSectionNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get settingsSectionNeedsAttention;

  /// No description provided for @transcriptBlurDisplayTitle.
  ///
  /// In en, this message translates to:
  /// **'Hide transcript text'**
  String get transcriptBlurDisplayTitle;

  /// No description provided for @transcriptBlurToggleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Blur practice (focus on listening)'**
  String get transcriptBlurToggleTooltip;

  /// No description provided for @transcriptBlurToggleOn.
  ///
  /// In en, this message translates to:
  /// **'Listening-focus mode on'**
  String get transcriptBlurToggleOn;

  /// No description provided for @transcriptBlurToggleOff.
  ///
  /// In en, this message translates to:
  /// **'Listening-focus mode off'**
  String get transcriptBlurToggleOff;

  /// No description provided for @transcriptBlurEmptyTooltip.
  ///
  /// In en, this message translates to:
  /// **'No transcript lines to practice with'**
  String get transcriptBlurEmptyTooltip;

  /// No description provided for @transcriptBlurSemanticsOn.
  ///
  /// In en, this message translates to:
  /// **'Blur practice on. Tap or hover to reveal a line.'**
  String get transcriptBlurSemanticsOn;

  /// No description provided for @transcriptBlurSemanticsOff.
  ///
  /// In en, this message translates to:
  /// **'Blur practice off.'**
  String get transcriptBlurSemanticsOff;

  /// No description provided for @importCraftFromText.
  ///
  /// In en, this message translates to:
  /// **'Craft…'**
  String get importCraftFromText;

  /// No description provided for @homeCraftAction.
  ///
  /// In en, this message translates to:
  /// **'Craft'**
  String get homeCraftAction;

  /// No description provided for @craftHistoryTooltip.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get craftHistoryTooltip;

  /// No description provided for @craftHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Craft history'**
  String get craftHistoryTitle;

  /// No description provided for @craftHistoryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Craft items yet'**
  String get craftHistoryEmptyTitle;

  /// No description provided for @craftHistoryEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Create audio in Craft and it will show up here.'**
  String get craftHistoryEmptyHint;

  /// No description provided for @craftHistoryEmptyAction.
  ///
  /// In en, this message translates to:
  /// **'Start crafting'**
  String get craftHistoryEmptyAction;

  /// No description provided for @craftHistoryRemoveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove Craft record'**
  String get craftHistoryRemoveTooltip;

  /// No description provided for @craftHistoryRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Craft record?'**
  String get craftHistoryRemoveTitle;

  /// No description provided for @craftHistoryRemoveMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove the Craft record for \"{title}\". The practice audio stays in your library.'**
  String craftHistoryRemoveMessage(String title);

  /// No description provided for @craftHistoryRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get craftHistoryRemoveConfirm;

  /// No description provided for @craftHistoryRemoved.
  ///
  /// In en, this message translates to:
  /// **'Craft record removed'**
  String get craftHistoryRemoved;

  /// No description provided for @craftHistoryRemoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not remove this Craft record.'**
  String get craftHistoryRemoveFailed;

  /// No description provided for @craftEditUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This Craft item is no longer available.'**
  String get craftEditUnavailable;

  /// No description provided for @craftSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Craft audio from text'**
  String get craftSheetTitle;

  /// No description provided for @craftModeTranslateThenSpeak.
  ///
  /// In en, this message translates to:
  /// **'Translate then speak'**
  String get craftModeTranslateThenSpeak;

  /// No description provided for @craftModeSpeakDirectly.
  ///
  /// In en, this message translates to:
  /// **'Speak directly'**
  String get craftModeSpeakDirectly;

  /// No description provided for @craftSourceLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Source language'**
  String get craftSourceLanguageLabel;

  /// No description provided for @craftTargetLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Learning language'**
  String get craftTargetLanguageLabel;

  /// No description provided for @craftTextInputHint.
  ///
  /// In en, this message translates to:
  /// **'Paste or type text…'**
  String get craftTextInputHint;

  /// No description provided for @craftPasteFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get craftPasteFromClipboard;

  /// No description provided for @craftAction.
  ///
  /// In en, this message translates to:
  /// **'Craft'**
  String get craftAction;

  /// No description provided for @craftCraftingProgress.
  ///
  /// In en, this message translates to:
  /// **'Crafting your audio…'**
  String get craftCraftingProgress;

  /// No description provided for @craftEmptyTextHint.
  ///
  /// In en, this message translates to:
  /// **'Enter at least a sentence to craft.'**
  String get craftEmptyTextHint;

  /// No description provided for @craftSameLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'Looks like this is already in your learning language.'**
  String get craftSameLanguageHint;

  /// No description provided for @craftSameLanguageSwitch.
  ///
  /// In en, this message translates to:
  /// **'Speak directly'**
  String get craftSameLanguageSwitch;

  /// No description provided for @craftOfflineBanner.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Craft needs an internet connection.'**
  String get craftOfflineBanner;

  /// No description provided for @craftSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to use Craft'**
  String get craftSignInRequired;

  /// No description provided for @craftFailureTts.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t turn the text into audio. Check your TTS provider settings or try again.'**
  String get craftFailureTts;

  /// No description provided for @craftFailureTranslate.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t translate the text. Try again or switch to Speak directly.'**
  String get craftFailureTranslate;

  /// No description provided for @craftFailureSave.
  ///
  /// In en, this message translates to:
  /// **'The audio was generated but couldn\'t be saved. Free up space and try again.'**
  String get craftFailureSave;

  /// No description provided for @craftAlreadyInLibrary.
  ///
  /// In en, this message translates to:
  /// **'Already in your library'**
  String get craftAlreadyInLibrary;

  /// No description provided for @craftOpenExisting.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get craftOpenExisting;

  /// No description provided for @craftRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get craftRetry;

  /// No description provided for @craftOpenAiSettings.
  ///
  /// In en, this message translates to:
  /// **'Open AI settings'**
  String get craftOpenAiSettings;

  /// No description provided for @craftLengthCapNotice.
  ///
  /// In en, this message translates to:
  /// **'Crafted the first 5000 characters; the rest was not synthesized.'**
  String get craftLengthCapNotice;

  /// No description provided for @libraryProviderCraftBadge.
  ///
  /// In en, this message translates to:
  /// **'Craft'**
  String get libraryProviderCraftBadge;

  /// No description provided for @craftTtsSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Craft uses the TTS provider below.'**
  String get craftTtsSettingsHint;

  /// No description provided for @craftScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Craft'**
  String get craftScreenTitle;

  /// No description provided for @craftTranslateTool.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get craftTranslateTool;

  /// No description provided for @craftSynthesizeTool.
  ///
  /// In en, this message translates to:
  /// **'Synthesize'**
  String get craftSynthesizeTool;

  /// No description provided for @craftStyleLabel.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get craftStyleLabel;

  /// No description provided for @craftStyleLiteral.
  ///
  /// In en, this message translates to:
  /// **'Literal'**
  String get craftStyleLiteral;

  /// No description provided for @craftStyleNatural.
  ///
  /// In en, this message translates to:
  /// **'Natural'**
  String get craftStyleNatural;

  /// No description provided for @craftStyleCasual.
  ///
  /// In en, this message translates to:
  /// **'Casual'**
  String get craftStyleCasual;

  /// No description provided for @craftStyleFormal.
  ///
  /// In en, this message translates to:
  /// **'Formal'**
  String get craftStyleFormal;

  /// No description provided for @craftStyleSimplified.
  ///
  /// In en, this message translates to:
  /// **'Simplified'**
  String get craftStyleSimplified;

  /// No description provided for @craftStyleDetailed.
  ///
  /// In en, this message translates to:
  /// **'Detailed'**
  String get craftStyleDetailed;

  /// No description provided for @craftStyleCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get craftStyleCustom;

  /// No description provided for @craftCustomPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your custom translation prompt…'**
  String get craftCustomPromptHint;

  /// No description provided for @craftSwapLanguages.
  ///
  /// In en, this message translates to:
  /// **'Swap languages'**
  String get craftSwapLanguages;

  /// No description provided for @craftTranslateButton.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get craftTranslateButton;

  /// No description provided for @craftReTranslateButton.
  ///
  /// In en, this message translates to:
  /// **'Re-translate'**
  String get craftReTranslateButton;

  /// No description provided for @craftCopyTranslation.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get craftCopyTranslation;

  /// No description provided for @craftCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get craftCopiedToClipboard;

  /// No description provided for @craftTranslatedText.
  ///
  /// In en, this message translates to:
  /// **'Translated text'**
  String get craftTranslatedText;

  /// No description provided for @craftUseTranslatedText.
  ///
  /// In en, this message translates to:
  /// **'Use translated text'**
  String get craftUseTranslatedText;

  /// No description provided for @craftVoiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get craftVoiceLabel;

  /// No description provided for @craftNoVoicesForLanguage.
  ///
  /// In en, this message translates to:
  /// **'No voices available for this language.'**
  String get craftNoVoicesForLanguage;

  /// No description provided for @craftSynthesizeButton.
  ///
  /// In en, this message translates to:
  /// **'Synthesize'**
  String get craftSynthesizeButton;

  /// No description provided for @craftReSynthesizeButton.
  ///
  /// In en, this message translates to:
  /// **'Re-synthesize'**
  String get craftReSynthesizeButton;

  /// No description provided for @craftSaveToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Save to library'**
  String get craftSaveToLibrary;

  /// No description provided for @craftSavingProgress.
  ///
  /// In en, this message translates to:
  /// **'Saving to library…'**
  String get craftSavingProgress;

  /// No description provided for @craftPreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get craftPreviewLabel;

  /// No description provided for @craftSourceText.
  ///
  /// In en, this message translates to:
  /// **'Source text'**
  String get craftSourceText;

  /// No description provided for @craftSynthText.
  ///
  /// In en, this message translates to:
  /// **'Text to synthesize'**
  String get craftSynthText;

  /// No description provided for @craftModeExpress.
  ///
  /// In en, this message translates to:
  /// **'Express'**
  String get craftModeExpress;

  /// No description provided for @craftModeAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get craftModeAdvanced;

  /// No description provided for @craftStageCapture.
  ///
  /// In en, this message translates to:
  /// **'Capture'**
  String get craftStageCapture;

  /// No description provided for @craftStageRewrite.
  ///
  /// In en, this message translates to:
  /// **'Rewrite'**
  String get craftStageRewrite;

  /// No description provided for @craftStageAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get craftStageAudio;

  /// No description provided for @craftCaptureTitle.
  ///
  /// In en, this message translates to:
  /// **'Say what\'s on your mind'**
  String get craftCaptureTitle;

  /// No description provided for @craftCaptureSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap to record. Speak naturally in your language.'**
  String get craftCaptureSubtitle;

  /// No description provided for @craftCaptureStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get craftCaptureStop;

  /// No description provided for @craftCaptureCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get craftCaptureCancel;

  /// No description provided for @craftCaptureTypeInstead.
  ///
  /// In en, this message translates to:
  /// **'Type instead'**
  String get craftCaptureTypeInstead;

  /// Loading hint under the spinner while ASR runs after capture.
  ///
  /// In en, this message translates to:
  /// **'Transcribing…'**
  String get craftLoadingTranscribing;

  /// Loading hint under the spinner while the LLM rewrite runs.
  ///
  /// In en, this message translates to:
  /// **'Crafting…'**
  String get craftLoadingRewriting;

  /// Loading hint under the spinner while TTS synthesizes audio.
  ///
  /// In en, this message translates to:
  /// **'Generating audio…'**
  String get craftLoadingSynthesizing;

  /// No description provided for @craftRewriteYourWords.
  ///
  /// In en, this message translates to:
  /// **'Your words'**
  String get craftRewriteYourWords;

  /// No description provided for @craftRewriteTargetLabel.
  ///
  /// In en, this message translates to:
  /// **'In your target language'**
  String get craftRewriteTargetLabel;

  /// No description provided for @craftRewriteRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get craftRewriteRegenerate;

  /// No description provided for @craftRewriteReRecord.
  ///
  /// In en, this message translates to:
  /// **'Re-record'**
  String get craftRewriteReRecord;

  /// No description provided for @craftRewriteGenerateAudio.
  ///
  /// In en, this message translates to:
  /// **'Generate audio'**
  String get craftRewriteGenerateAudio;

  /// No description provided for @craftAudioPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get craftAudioPreview;

  /// Express audio-stage secondary CTA: save the preview to the library, then return to capture.
  ///
  /// In en, this message translates to:
  /// **'Save & say another'**
  String get craftAudioSaySomethingElse;

  /// Express audio-stage primary CTA: save the preview to the library and open the player.
  ///
  /// In en, this message translates to:
  /// **'Save & practice'**
  String get craftAudioPracticeNow;

  /// Inline reminder on the Express audio stage that TTS preview is in-memory until a save CTA is used.
  ///
  /// In en, this message translates to:
  /// **'Not saved yet. Leave now and this audio is discarded — it won’t appear in history.'**
  String get craftAudioUnsavedHint;

  /// Title for the leave/mode-switch confirm when Craft has an unsaved TTS preview.
  ///
  /// In en, this message translates to:
  /// **'Discard this audio?'**
  String get craftAudioDiscardTitle;

  /// Body for the leave/mode-switch confirm when Craft has an unsaved TTS preview.
  ///
  /// In en, this message translates to:
  /// **'Generated audio is only kept after you save. Leaving now discards it, and credits already used for this preview are not refunded.'**
  String get craftAudioDiscardMessage;

  /// Confirm action that drops the unsaved Craft TTS preview and continues navigation.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get craftAudioDiscardConfirm;

  /// No description provided for @craftSavedToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Saved to library'**
  String get craftSavedToLibrary;

  /// Once-per-session snackbar after Craft save that wrote solid synthesis cues; points to STT replace, not re-TTS.
  ///
  /// In en, this message translates to:
  /// **'If line timings look off, regenerate them with speech-to-text from the transcript panel.'**
  String get craftSolidTranscriptSttHint;

  /// No description provided for @craftStyleAuto.
  ///
  /// In en, this message translates to:
  /// **'✨ Auto'**
  String get craftStyleAuto;

  /// No description provided for @craftFailureAsr.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t hear you clearly. Try recording again.'**
  String get craftFailureAsr;

  /// No description provided for @craftFailureEmptyTranscript.
  ///
  /// In en, this message translates to:
  /// **'That was too short. Try speaking a bit longer.'**
  String get craftFailureEmptyTranscript;

  /// No description provided for @craftRecordingMicDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone access denied. Please enable it in settings.'**
  String get craftRecordingMicDenied;

  /// Generic fallback message when loading data fails in an unexpected way.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGenericLoadFailed;

  /// No description provided for @subscriptionAutoRenewTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-renew Pro'**
  String get subscriptionAutoRenewTitle;

  /// No description provided for @subscriptionAutoRenewMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get subscriptionAutoRenewMonthly;

  /// No description provided for @subscriptionAutoRenewYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get subscriptionAutoRenewYearly;

  /// No description provided for @subscriptionAutoRenewPriceMonth.
  ///
  /// In en, this message translates to:
  /// **'{amount} USD/month'**
  String subscriptionAutoRenewPriceMonth(String amount);

  /// No description provided for @subscriptionAutoRenewPriceYear.
  ///
  /// In en, this message translates to:
  /// **'{amount} USD/year'**
  String subscriptionAutoRenewPriceYear(String amount);

  /// No description provided for @subscriptionAutoRenewSubscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe with auto-renew'**
  String get subscriptionAutoRenewSubscribe;

  /// No description provided for @subscriptionAutoRenewOn.
  ///
  /// In en, this message translates to:
  /// **'Auto-renew on'**
  String get subscriptionAutoRenewOn;

  /// No description provided for @subscriptionAutoRenewOff.
  ///
  /// In en, this message translates to:
  /// **'Auto-renew off'**
  String get subscriptionAutoRenewOff;

  /// No description provided for @subscriptionAutoRenewIntervalMonth.
  ///
  /// In en, this message translates to:
  /// **'Monthly plan'**
  String get subscriptionAutoRenewIntervalMonth;

  /// No description provided for @subscriptionAutoRenewIntervalYear.
  ///
  /// In en, this message translates to:
  /// **'Yearly plan'**
  String get subscriptionAutoRenewIntervalYear;

  /// No description provided for @subscriptionAutoRenewProvider.
  ///
  /// In en, this message translates to:
  /// **'Billed via {provider}'**
  String subscriptionAutoRenewProvider(String provider);

  /// No description provided for @subscriptionAutoRenewCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel auto-renew'**
  String get subscriptionAutoRenewCancel;

  /// No description provided for @subscriptionAutoRenewCancelConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel auto-renew?'**
  String get subscriptionAutoRenewCancelConfirmTitle;

  /// No description provided for @subscriptionAutoRenewCancelConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'You keep Pro until {date}. You will not be charged again for this subscription.'**
  String subscriptionAutoRenewCancelConfirmMessage(String date);

  /// No description provided for @subscriptionAutoRenewCancelConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel auto-renew'**
  String get subscriptionAutoRenewCancelConfirmAction;

  /// No description provided for @subscriptionAutoRenewCancelKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep auto-renew'**
  String get subscriptionAutoRenewCancelKeep;

  /// No description provided for @subscriptionAutoRenewCancelSuccess.
  ///
  /// In en, this message translates to:
  /// **'Auto-renew canceled. Pro remains until {date}.'**
  String subscriptionAutoRenewCancelSuccess(String date);

  /// No description provided for @subscriptionAutoRenewCancelFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not cancel auto-renew. Try again.'**
  String get subscriptionAutoRenewCancelFailed;

  /// No description provided for @subscriptionAutoRenewConflict.
  ///
  /// In en, this message translates to:
  /// **'You already have an active auto-renew subscription.'**
  String get subscriptionAutoRenewConflict;

  /// No description provided for @subscriptionAutoRenewPlansUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Auto-renew plans are not available right now.'**
  String get subscriptionAutoRenewPlansUnavailable;

  /// No description provided for @subscriptionProMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re on Pro'**
  String get subscriptionProMemberTitle;

  /// No description provided for @subscriptionRenewsOn.
  ///
  /// In en, this message translates to:
  /// **'Renews on {date}'**
  String subscriptionRenewsOn(String date);

  /// No description provided for @subscriptionAccessUntil.
  ///
  /// In en, this message translates to:
  /// **'Access until {date}'**
  String subscriptionAccessUntil(String date);

  /// No description provided for @subscriptionAutoRenewEndingSoon.
  ///
  /// In en, this message translates to:
  /// **'Auto-renew is off — Pro continues until the date above'**
  String get subscriptionAutoRenewEndingSoon;

  /// No description provided for @subscriptionIncludedWithPro.
  ///
  /// In en, this message translates to:
  /// **'Included with Pro'**
  String get subscriptionIncludedWithPro;

  /// No description provided for @subscriptionPayOnceTitle.
  ///
  /// In en, this message translates to:
  /// **'Pay for months once'**
  String get subscriptionPayOnceTitle;

  /// No description provided for @subscriptionPayOnceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One-time prepaid months (no auto-renew)'**
  String get subscriptionPayOnceSubtitle;

  /// No description provided for @creditsPackagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Credits packages'**
  String get creditsPackagesTitle;

  /// No description provided for @creditsPackagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One-time permanent credits — not a subscription'**
  String get creditsPackagesSubtitle;

  /// No description provided for @creditsPackagePriceCredits.
  ///
  /// In en, this message translates to:
  /// **'{price} USD · {credits} permanent credits'**
  String creditsPackagePriceCredits(String price, String credits);

  /// No description provided for @creditsPackageBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy credits'**
  String get creditsPackageBuy;

  /// No description provided for @creditsPackageConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Buy credits package?'**
  String get creditsPackageConfirmTitle;

  /// No description provided for @creditsPackageConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Pay {price} USD for {credits} permanent credits. This does not change your subscription.'**
  String creditsPackageConfirmMessage(String price, String credits);

  /// No description provided for @creditsPackageConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Continue to payment'**
  String get creditsPackageConfirmAction;

  /// No description provided for @creditsPackageVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying your credits purchase…'**
  String get creditsPackageVerifying;

  /// No description provided for @creditsPackageVerifyTimeout.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t confirm credits yet — pull to refresh or check again shortly.'**
  String get creditsPackageVerifyTimeout;

  /// No description provided for @creditsPackagePurchaseSuccess.
  ///
  /// In en, this message translates to:
  /// **'Permanent credits updated.'**
  String get creditsPackagePurchaseSuccess;

  /// No description provided for @creditsPackagePurchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Credits package purchase failed'**
  String get creditsPackagePurchaseFailed;

  /// No description provided for @creditsPermanentAvailable.
  ///
  /// In en, this message translates to:
  /// **'{count} permanent credits available'**
  String creditsPermanentAvailable(String count);

  /// No description provided for @subscriptionCreditsLimitMessageWithPackages.
  ///
  /// In en, this message translates to:
  /// **'AI credits limit reached. Upgrade to Pro or buy a credits package to continue.'**
  String get subscriptionCreditsLimitMessageWithPackages;

  /// No description provided for @subscriptionViewPlansAndPackages.
  ///
  /// In en, this message translates to:
  /// **'View plans & packages'**
  String get subscriptionViewPlansAndPackages;

  /// No description provided for @creditsExhaustedDetailed.
  ///
  /// In en, this message translates to:
  /// **'This action needs {required} credits, but only {remaining} are left today.'**
  String creditsExhaustedDetailed(int required, int remaining);

  /// No description provided for @creditsExhaustedResets.
  ///
  /// In en, this message translates to:
  /// **'Credits reset at {time}.'**
  String creditsExhaustedResets(String time);

  /// No description provided for @byokProviderBillingMessage.
  ///
  /// In en, this message translates to:
  /// **'Your AI provider declined this request. Please check your provider\'s billing or plan.'**
  String get byokProviderBillingMessage;

  /// No description provided for @pronouncePlay.
  ///
  /// In en, this message translates to:
  /// **'Play pronunciation'**
  String get pronouncePlay;

  /// No description provided for @pronounceStop.
  ///
  /// In en, this message translates to:
  /// **'Stop pronunciation'**
  String get pronounceStop;

  /// No description provided for @pronounceLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading pronunciation…'**
  String get pronounceLoading;

  /// No description provided for @pronounceUnavailableLanguage.
  ///
  /// In en, this message translates to:
  /// **'Pronunciation unavailable for this language'**
  String get pronounceUnavailableLanguage;

  /// No description provided for @pronounceTextTooLong.
  ///
  /// In en, this message translates to:
  /// **'Text is too long to pronounce'**
  String get pronounceTextTooLong;

  /// No description provided for @pronounceFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t play pronunciation'**
  String get pronounceFailed;

  /// No description provided for @pronounceCreditsExhausted.
  ///
  /// In en, this message translates to:
  /// **'Not enough credits to generate pronunciation'**
  String get pronounceCreditsExhausted;

  /// No description provided for @pronounceSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to hear pronunciation'**
  String get pronounceSignInRequired;

  /// Tooltip for playing the full assessment take from the result dialog.
  ///
  /// In en, this message translates to:
  /// **'Play my recording'**
  String get assessmentPlayMyRecording;

  /// Tooltip while the assessment take is playing.
  ///
  /// In en, this message translates to:
  /// **'Stop my recording'**
  String get assessmentStopMyRecording;

  /// Tooltip when the take path is missing or the file cannot be read.
  ///
  /// In en, this message translates to:
  /// **'Recording file is unavailable'**
  String get assessmentRecordingUnavailable;

  /// Tooltip for playing the timed word clip from the learner take.
  ///
  /// In en, this message translates to:
  /// **'Play my recording of this word'**
  String get assessmentPlayMyClip;

  /// Tooltip while the word clip is playing.
  ///
  /// In en, this message translates to:
  /// **'Stop my recording of this word'**
  String get assessmentStopMyClip;

  /// Tooltip when word timing is missing, omitted, or zero duration.
  ///
  /// In en, this message translates to:
  /// **'No recording clip for this word'**
  String get assessmentClipUnavailable;

  /// No description provided for @subscriptionTierCatalogTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your plan'**
  String get subscriptionTierCatalogTitle;

  /// No description provided for @subscriptionTierCatalogDescription.
  ///
  /// In en, this message translates to:
  /// **'All tiers include the same AI features. Choose a credit allowance and billing cycle, then pick how you pay.'**
  String get subscriptionTierCatalogDescription;

  /// No description provided for @subscriptionTierCatalogRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get subscriptionTierCatalogRecommended;

  /// No description provided for @subscriptionTierCatalogChoosePro.
  ///
  /// In en, this message translates to:
  /// **'Choose Pro'**
  String get subscriptionTierCatalogChoosePro;

  /// No description provided for @subscriptionTierCatalogExtendPro.
  ///
  /// In en, this message translates to:
  /// **'Extend Pro'**
  String get subscriptionTierCatalogExtendPro;

  /// No description provided for @subscriptionTierCatalogChooseLite.
  ///
  /// In en, this message translates to:
  /// **'Choose Lite'**
  String get subscriptionTierCatalogChooseLite;

  /// No description provided for @subscriptionTierCatalogExtendLite.
  ///
  /// In en, this message translates to:
  /// **'Extend Lite'**
  String get subscriptionTierCatalogExtendLite;

  /// No description provided for @subscriptionTierCatalogNotSelected.
  ///
  /// In en, this message translates to:
  /// **'Downgrade is not available'**
  String get subscriptionTierCatalogNotSelected;

  /// No description provided for @subscriptionUpgradedToLite.
  ///
  /// In en, this message translates to:
  /// **'You\'re now Lite — enjoy!'**
  String get subscriptionUpgradedToLite;

  /// No description provided for @subscriptionTierCatalogSelectedInterval.
  ///
  /// In en, this message translates to:
  /// **'{amount} / {unit} — billed via Stripe'**
  String subscriptionTierCatalogSelectedInterval(String amount, String unit);

  /// No description provided for @subscriptionTierCatalogIntervalYearSavings.
  ///
  /// In en, this message translates to:
  /// **'Save {percent}%'**
  String subscriptionTierCatalogIntervalYearSavings(String percent);

  /// No description provided for @subscriptionTierCatalogPerMonth.
  ///
  /// In en, this message translates to:
  /// **'month'**
  String get subscriptionTierCatalogPerMonth;

  /// No description provided for @subscriptionTierCatalogPerYear.
  ///
  /// In en, this message translates to:
  /// **'year'**
  String get subscriptionTierCatalogPerYear;

  /// No description provided for @subscriptionPurchaseModalUnifiedTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how to pay for {tier} · {interval}'**
  String subscriptionPurchaseModalUnifiedTitle(String tier, String interval);

  /// No description provided for @subscriptionPurchaseModalUnifiedDescription.
  ///
  /// In en, this message translates to:
  /// **'Auto-renew keeps Pro access continuous and renews automatically. Pay once buys a fixed prepaid period with no auto-renew.'**
  String get subscriptionPurchaseModalUnifiedDescription;

  /// No description provided for @subscriptionPurchaseModalAutoRenewActiveWarning.
  ///
  /// In en, this message translates to:
  /// **'You already have an active auto-renew subscription. Cancel it to switch billing options.'**
  String get subscriptionPurchaseModalAutoRenewActiveWarning;

  /// No description provided for @subscriptionPurchaseModalOptionAutoRenew.
  ///
  /// In en, this message translates to:
  /// **'Auto-renew'**
  String get subscriptionPurchaseModalOptionAutoRenew;

  /// No description provided for @subscriptionPurchaseModalOptionAutoRenewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recommended — renews automatically. Cancel anytime.'**
  String get subscriptionPurchaseModalOptionAutoRenewSubtitle;

  /// No description provided for @subscriptionPurchaseModalOptionAutoRenewFootnote.
  ///
  /// In en, this message translates to:
  /// **'Billed via Stripe'**
  String get subscriptionPurchaseModalOptionAutoRenewFootnote;

  /// No description provided for @subscriptionPurchaseModalOptionPrepaid.
  ///
  /// In en, this message translates to:
  /// **'Pay once'**
  String get subscriptionPurchaseModalOptionPrepaid;

  /// No description provided for @subscriptionPurchaseModalOptionPrepaidSubtitle.
  ///
  /// In en, this message translates to:
  /// **'No auto-renew. Pay for a fixed period up front.'**
  String get subscriptionPurchaseModalOptionPrepaidSubtitle;

  /// No description provided for @subscriptionPurchaseModalOptionPrepaidFootnote.
  ///
  /// In en, this message translates to:
  /// **'One-time payment'**
  String get subscriptionPurchaseModalOptionPrepaidFootnote;

  /// No description provided for @subscriptionPurchaseModalSubscribeAutoRenewCta.
  ///
  /// In en, this message translates to:
  /// **'Subscribe with auto-renew'**
  String get subscriptionPurchaseModalSubscribeAutoRenewCta;

  /// No description provided for @subscriptionBalanceToCreditsTitle.
  ///
  /// In en, this message translates to:
  /// **'Convert balance to permanent credits'**
  String get subscriptionBalanceToCreditsTitle;

  /// No description provided for @subscriptionBalanceToCreditsDescriptionWithPreview.
  ///
  /// In en, this message translates to:
  /// **'Move your {usd} legacy balance to ~{credits} permanent credits on the credits page.'**
  String subscriptionBalanceToCreditsDescriptionWithPreview(
    String usd,
    String credits,
  );

  /// No description provided for @subscriptionBalanceToCreditsDescriptionEmpty.
  ///
  /// In en, this message translates to:
  /// **'Once you have a balance from prior deposits, convert it to permanent credits here.'**
  String get subscriptionBalanceToCreditsDescriptionEmpty;

  /// No description provided for @subscriptionBalanceToCreditsCta.
  ///
  /// In en, this message translates to:
  /// **'Convert to credits'**
  String get subscriptionBalanceToCreditsCta;

  /// No description provided for @subscriptionBalanceToCreditsComingSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'Balance transfer coming soon'**
  String get subscriptionBalanceToCreditsComingSoonTitle;

  /// No description provided for @subscriptionBalanceToCreditsComingSoonMessage.
  ///
  /// In en, this message translates to:
  /// **'You have {usd} in legacy balance. The transfer-to-credits flow is rolling out to the desktop app in a future update. Until then, manage your balance on the web app.'**
  String subscriptionBalanceToCreditsComingSoonMessage(String usd);

  /// No description provided for @onboardingTipSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingTipSkip;

  /// No description provided for @onboardingTipHomeImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import media'**
  String get onboardingTipHomeImportTitle;

  /// No description provided for @onboardingTipHomeImportBody.
  ///
  /// In en, this message translates to:
  /// **'Bring in a local file or YouTube video to practice with.'**
  String get onboardingTipHomeImportBody;

  /// No description provided for @onboardingTipHomeCraftTitle.
  ///
  /// In en, this message translates to:
  /// **'Craft'**
  String get onboardingTipHomeCraftTitle;

  /// No description provided for @onboardingTipHomeCraftBody.
  ///
  /// In en, this message translates to:
  /// **'Create practice audio from text when you do not have a video yet.'**
  String get onboardingTipHomeCraftBody;

  /// No description provided for @onboardingTipEmptyTranscriptLocalTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a transcript'**
  String get onboardingTipEmptyTranscriptLocalTitle;

  /// No description provided for @onboardingTipEmptyTranscriptLocalBody.
  ///
  /// In en, this message translates to:
  /// **'Extract subtitles from the file or import a subtitle file so you can practice line by line.'**
  String get onboardingTipEmptyTranscriptLocalBody;

  /// No description provided for @onboardingTipEmptyTranscriptYoutubeTitle.
  ///
  /// In en, this message translates to:
  /// **'Fetch transcript'**
  String get onboardingTipEmptyTranscriptYoutubeTitle;

  /// No description provided for @onboardingTipEmptyTranscriptYoutubeBody.
  ///
  /// In en, this message translates to:
  /// **'Pull captions for this YouTube video from the cloud to unlock practice.'**
  String get onboardingTipEmptyTranscriptYoutubeBody;

  /// No description provided for @onboardingTipEchoTitle.
  ///
  /// In en, this message translates to:
  /// **'Echo mode'**
  String get onboardingTipEchoTitle;

  /// No description provided for @onboardingTipEchoBody.
  ///
  /// In en, this message translates to:
  /// **'Turn on Echo to shadow each line and practice speaking along with the audio.'**
  String get onboardingTipEchoBody;

  /// No description provided for @onboardingTipRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Record yourself'**
  String get onboardingTipRecordTitle;

  /// No description provided for @onboardingTipRecordBody.
  ///
  /// In en, this message translates to:
  /// **'Record your voice on a line, then compare it with the original.'**
  String get onboardingTipRecordBody;

  /// No description provided for @onboardingTipAssessTitle.
  ///
  /// In en, this message translates to:
  /// **'Assess pronunciation'**
  String get onboardingTipAssessTitle;

  /// No description provided for @onboardingTipAssessBody.
  ///
  /// In en, this message translates to:
  /// **'After you record, check pronunciation feedback for that take.'**
  String get onboardingTipAssessBody;

  /// No description provided for @settingsResetProductTipsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset product tips'**
  String get settingsResetProductTipsTitle;

  /// No description provided for @settingsResetProductTipsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show Home and Player tips again as if you were new.'**
  String get settingsResetProductTipsSubtitle;

  /// No description provided for @settingsResetProductTipsConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset product tips?'**
  String get settingsResetProductTipsConfirmTitle;

  /// No description provided for @settingsResetProductTipsConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Tips for Craft, Import, transcripts, and practice will show again. Your library and account stay unchanged.'**
  String get settingsResetProductTipsConfirmBody;

  /// No description provided for @settingsResetProductTipsConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Reset tips'**
  String get settingsResetProductTipsConfirmAction;

  /// No description provided for @settingsResetProductTipsDone.
  ///
  /// In en, this message translates to:
  /// **'Product tips reset'**
  String get settingsResetProductTipsDone;

  /// No description provided for @transcriptEmptyFetchYoutube.
  ///
  /// In en, this message translates to:
  /// **'Fetch transcript'**
  String get transcriptEmptyFetchYoutube;
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
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'CN':
            return AppLocalizationsZhCn();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
