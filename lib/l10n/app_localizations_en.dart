// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'EduReader';

  @override
  String get library => 'Library';

  @override
  String booksCount(int count) {
    return '$count EPUB';
  }

  @override
  String get emptyLibraryTitle => 'Your library is empty';

  @override
  String get emptyLibraryBody =>
      'EduReader focuses on EPUBs, comfortable reading, and highlights you can send to FreeWise.';

  @override
  String get chooseEpub => 'Choose an EPUB';

  @override
  String get addEpub => 'Add another EPUB';

  @override
  String get settings => 'Settings';

  @override
  String get nextcloudSync => 'Nextcloud sync';

  @override
  String get searchLibrary => 'Search library';

  @override
  String get searchTitleOrAuthor => 'Title or author';

  @override
  String get filterTags => 'Filter by tags';

  @override
  String get multiTagFilterHint =>
      'When you select several, books must have every selected tag.';

  @override
  String get clear => 'Clear';

  @override
  String get sortBy => 'Sort by';

  @override
  String get recentlyAdded => 'Recently added';

  @override
  String get sortTitle => 'Title';

  @override
  String get sortAuthor => 'Author';

  @override
  String get noBooks => 'Your library is empty.';

  @override
  String noBooksMatch(String query) {
    return 'No books match “$query”.';
  }

  @override
  String get editTags => 'Edit tags';

  @override
  String get deleteBook => 'Delete book';

  @override
  String get tagsForBook => 'Book tags';

  @override
  String get newTag => 'New tag';

  @override
  String get addTag => 'Add tag';

  @override
  String get noTags => 'This book has no tags yet.';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get configuration => 'Settings';

  @override
  String get freewiseServerUrl => 'FreeWise server URL';

  @override
  String get freewiseUrlHint => 'https://freewise.example.com';

  @override
  String get includeScheme => 'Include http:// or https://';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get sepiaTone => 'Sepia tone';

  @override
  String get justifyText => 'Justify text';

  @override
  String get justifyHint =>
      'Align text to both margins when the EPUB allows it.';

  @override
  String fontSize(int value) {
    return 'Font size · $value%';
  }

  @override
  String lineHeight(String value) {
    return 'Line spacing · $value';
  }

  @override
  String margins(int value) {
    return 'Margins · $value%';
  }

  @override
  String fontSizeSemantics(int value) {
    return 'Font size: $value percent';
  }

  @override
  String lineHeightSemantics(String value) {
    return 'Line spacing: $value';
  }

  @override
  String marginsSemantics(int value) {
    return 'Margins: $value percent';
  }

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'Automatic (device language)';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageCatalan => 'Català';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsSaved => 'Settings saved.';

  @override
  String get nextcloudConnect => 'Connect to Nextcloud';

  @override
  String get nextcloudUrl => 'Nextcloud URL';

  @override
  String get username => 'Username';

  @override
  String get appPassword => 'App password';

  @override
  String get keepPassword => 'Leave blank to keep the saved password.';

  @override
  String get createPassword => 'Create one under Security in Nextcloud.';

  @override
  String get secureStorage =>
      'The password is encrypted and stored securely on this device.';

  @override
  String get httpsRequired => 'Use a secure URL starting with https://.';

  @override
  String get usernameRequired => 'Enter your Nextcloud username.';

  @override
  String get passwordRequired => 'Enter an app password.';

  @override
  String get nextcloudSaved => 'Nextcloud connection saved.';

  @override
  String get syncLibrary => 'Sync library';

  @override
  String get configureNextcloud => 'Set up Nextcloud';

  @override
  String get syncNoChanges =>
      'Library, reading progress, and highlights synced with Nextcloud.';

  @override
  String syncCounts(int uploaded, int downloaded) {
    return 'Nextcloud: $uploaded EPUB uploaded, $downloaded received.';
  }

  @override
  String syncFailed(String error) {
    return 'Could not sync with Nextcloud: $error';
  }

  @override
  String get readerAppearance => 'Reading appearance';

  @override
  String get tableOfContents => 'Table of contents';

  @override
  String get tocMissing => 'This EPUB has no table of contents.';

  @override
  String get closeToc => 'Close table of contents';

  @override
  String get sectionOpenFailed => 'Could not open that section.';

  @override
  String get searchInBook => 'Search in book';

  @override
  String get searchTerm => 'Word or phrase';

  @override
  String get search => 'Search';

  @override
  String searchNoResults(String query) {
    return 'No results for “$query”.';
  }

  @override
  String searchFailed(String error) {
    return 'Could not search the EPUB: $error';
  }

  @override
  String get searchResults => 'Search results';

  @override
  String searchResultsCount(String query, int count) {
    return '“$query” · $count results';
  }

  @override
  String get closeResults => 'Close results';

  @override
  String get chapter => 'Chapter';

  @override
  String get searchResultFailed => 'Could not open that result.';

  @override
  String get goToPosition => 'Go to position';

  @override
  String bookProgress(int value) {
    return 'Book progress: $value%';
  }

  @override
  String get go => 'Go';

  @override
  String get progressFailed => 'Could not go to that position.';

  @override
  String get currentPositionUnknown =>
      'The current position is not available yet.';

  @override
  String get moreOptions => 'More options';

  @override
  String get close => 'Close';

  @override
  String get readAloud => 'Read aloud';

  @override
  String get exportAnnotations => 'Export annotations';

  @override
  String get syncFreewise => 'Sync with FreeWise';

  @override
  String get addBookmark => 'Add bookmark';

  @override
  String get bookmarkName => 'Name (optional)';

  @override
  String get bookmarkExample => 'For example, “Favorite chapter”';

  @override
  String get bookmarkSaved => 'Bookmark saved.';

  @override
  String bookmarkSaveFailed(String error) {
    return 'Could not save bookmark: $error';
  }

  @override
  String get addBookmarkHere => 'Add bookmark here';

  @override
  String get closeBookmarks => 'Close bookmarks';

  @override
  String get noBookmarks => 'You have not saved any bookmarks yet.';

  @override
  String get deleteBookmark => 'Delete bookmark';

  @override
  String bookmarkDeleteFailed(String error) {
    return 'Could not delete bookmark: $error';
  }

  @override
  String get bookmarkOpenFailed => 'Could not open that bookmark.';

  @override
  String get restoreHighlightsFailed => 'Could not show saved highlights.';

  @override
  String get highlightColorFailed => 'Could not save highlight color.';

  @override
  String highlightSaveFailed(String error) {
    return 'Could not save highlight: $error';
  }

  @override
  String get deleteHighlight => 'Delete highlight';

  @override
  String get delete => 'Delete';

  @override
  String get highlightDeleted => 'Highlight deleted.';

  @override
  String get addNote => 'Add note';

  @override
  String get noteHint => 'Write a note';

  @override
  String get saveAndSync => 'Save and sync';

  @override
  String get configureFreewise => 'Set up FreeWise';

  @override
  String get freewiseUrl => 'Server URL';

  @override
  String get noNewAnnotations => 'There are no new annotations to sync.';

  @override
  String get annotationsSent => 'Annotations sent to FreeWise.';

  @override
  String annotationsExported(int count) {
    return 'Exported $count annotations to CSV.';
  }

  @override
  String freewiseSyncFailed(String error) {
    return 'Could not sync with FreeWise: $error';
  }

  @override
  String get fullscreen => 'Full screen';

  @override
  String get exitFullscreen => 'Exit full screen';

  @override
  String get readerToc => 'Table of contents';

  @override
  String get readerBookmarks => 'Bookmarks';

  @override
  String get readerBookmarksAndHighlights => 'Bookmarks and highlights';

  @override
  String get savedHighlightsTab => 'Highlights';

  @override
  String get noSavedHighlights => 'You have not saved any highlights yet.';

  @override
  String get savedHighlightFallback => 'Highlighted passage';

  @override
  String get readerSearch => 'Search in book';

  @override
  String get readerMore => 'More options';

  @override
  String get chooseColor => 'Choose color';

  @override
  String get saving => 'Saving…';

  @override
  String get previousSentence => 'Previous sentence';

  @override
  String get pause => 'Pause';

  @override
  String get play => 'Play';

  @override
  String get nextSentence => 'Next sentence';

  @override
  String get readingSpeed => 'Reading speed';

  @override
  String get closeReadAloud => 'Close read aloud';

  @override
  String speedValue(String value) {
    return 'Reading speed: $value times';
  }

  @override
  String get highlightColorTitle => 'Highlight color';

  @override
  String get underlineAction => 'Highlight';

  @override
  String get underlineStyle => 'Underline';

  @override
  String get highlightStyle => 'Color background';

  @override
  String get colorYellow => 'Yellow';

  @override
  String get colorGreen => 'Green';

  @override
  String get colorBlue => 'Blue';

  @override
  String get colorPink => 'Pink';

  @override
  String get colorOrange => 'Orange';

  @override
  String readerError(String error) {
    return 'Could not open EPUB with Readium: $error';
  }

  @override
  String get readerPathMissing => 'The EPUB has no local file path.';

  @override
  String applyPreferencesFailed(String error) {
    return 'Could not apply reading settings: $error';
  }

  @override
  String savePositionFailed(String error) {
    return 'Could not save the current position: $error';
  }

  @override
  String deleteBookConfirmation(String title) {
    return '“$title” will be deleted from this device and Nextcloud. This cannot be undone.';
  }

  @override
  String get remoteBookRemoved => 'This book was deleted from another device.';

  @override
  String get bookDeleted => 'Book deleted from this device and Nextcloud.';

  @override
  String get apply => 'Apply';

  @override
  String get confirmDeleteHighlight => 'Delete this highlight?';

  @override
  String readAloudFailed(String error) {
    return 'Could not start read aloud: $error';
  }

  @override
  String readAloudSkipFailed(String error) {
    return 'Could not skip in the reading: $error';
  }

  @override
  String readAloudSpeedFailed(String error) {
    return 'Could not change the speed: $error';
  }

  @override
  String get annotationsSynced => 'New annotations synced.';

  @override
  String automaticSyncFailed(String error) {
    return 'Could not sync automatically: $error';
  }

  @override
  String bookmarkPoint(int value) {
    return 'Position $value';
  }

  @override
  String get copy => 'Copy';

  @override
  String get authorUnknown => 'Unknown author';

  @override
  String get epubPathMissing => 'Could not get the EPUB file path.';

  @override
  String epubOpenFailed(String error) {
    return 'Could not open the EPUB: $error';
  }

  @override
  String get waitForSync => 'Wait for syncing to finish before deleting.';

  @override
  String deleteBookFailed(String error) {
    return 'Could not delete the book: $error';
  }

  @override
  String saveTagsFailed(String error) {
    return 'Could not save tags: $error';
  }

  @override
  String saveConnectionFailed(String error) {
    return 'Could not save the connection: $error';
  }

  @override
  String loadSettingsFailed(String error) {
    return 'Could not load settings: $error';
  }

  @override
  String saveSettingsFailed(String error) {
    return 'Could not save settings: $error';
  }

  @override
  String get invalidFreewiseUrl =>
      'Enter a valid URL starting with http:// or https://.';

  @override
  String get nextcloudUrlHint => 'https://cloud.example.com';

  @override
  String get savedNotesTab => 'Notes';

  @override
  String get noSavedNotes => 'You have not saved any notes yet.';
}
