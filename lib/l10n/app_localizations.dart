import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ca.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

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
    Locale('ca'),
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'EduReader'**
  String get appTitle;

  /// No description provided for @library.
  ///
  /// In es, this message translates to:
  /// **'Biblioteca'**
  String get library;

  /// No description provided for @booksCount.
  ///
  /// In es, this message translates to:
  /// **'{count} EPUB'**
  String booksCount(int count);

  /// No description provided for @emptyLibraryTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu biblioteca está vacía'**
  String get emptyLibraryTitle;

  /// No description provided for @emptyLibraryBody.
  ///
  /// In es, this message translates to:
  /// **'EduReader empieza centrado en EPUB, lectura cómoda y subrayados que podremos enviar a FreeWise.'**
  String get emptyLibraryBody;

  /// No description provided for @chooseEpub.
  ///
  /// In es, this message translates to:
  /// **'Elegir un EPUB'**
  String get chooseEpub;

  /// No description provided for @addEpub.
  ///
  /// In es, this message translates to:
  /// **'Añadir otro EPUB'**
  String get addEpub;

  /// No description provided for @settings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settings;

  /// No description provided for @nextcloudSync.
  ///
  /// In es, this message translates to:
  /// **'Sincronización Nextcloud'**
  String get nextcloudSync;

  /// No description provided for @searchLibrary.
  ///
  /// In es, this message translates to:
  /// **'Buscar en la biblioteca'**
  String get searchLibrary;

  /// No description provided for @searchTitleOrAuthor.
  ///
  /// In es, this message translates to:
  /// **'Título o autor'**
  String get searchTitleOrAuthor;

  /// No description provided for @filterTags.
  ///
  /// In es, this message translates to:
  /// **'Filtrar por etiquetas'**
  String get filterTags;

  /// No description provided for @multiTagFilterHint.
  ///
  /// In es, this message translates to:
  /// **'Al elegir varias, se muestran los libros que tienen todas.'**
  String get multiTagFilterHint;

  /// No description provided for @clear.
  ///
  /// In es, this message translates to:
  /// **'Limpiar'**
  String get clear;

  /// No description provided for @sortBy.
  ///
  /// In es, this message translates to:
  /// **'Ordenar por'**
  String get sortBy;

  /// No description provided for @recentlyAdded.
  ///
  /// In es, this message translates to:
  /// **'Añadidos recientemente'**
  String get recentlyAdded;

  /// No description provided for @sortTitle.
  ///
  /// In es, this message translates to:
  /// **'Título'**
  String get sortTitle;

  /// No description provided for @sortAuthor.
  ///
  /// In es, this message translates to:
  /// **'Autor'**
  String get sortAuthor;

  /// No description provided for @noBooks.
  ///
  /// In es, this message translates to:
  /// **'La biblioteca está vacía.'**
  String get noBooks;

  /// No description provided for @noBooksMatch.
  ///
  /// In es, this message translates to:
  /// **'No hay libros que coincidan con «{query}».'**
  String noBooksMatch(String query);

  /// No description provided for @editTags.
  ///
  /// In es, this message translates to:
  /// **'Editar etiquetas'**
  String get editTags;

  /// No description provided for @deleteBook.
  ///
  /// In es, this message translates to:
  /// **'Eliminar libro'**
  String get deleteBook;

  /// No description provided for @tagsForBook.
  ///
  /// In es, this message translates to:
  /// **'Etiquetas del libro'**
  String get tagsForBook;

  /// No description provided for @newTag.
  ///
  /// In es, this message translates to:
  /// **'Nueva etiqueta'**
  String get newTag;

  /// No description provided for @addTag.
  ///
  /// In es, this message translates to:
  /// **'Añadir etiqueta'**
  String get addTag;

  /// No description provided for @noTags.
  ///
  /// In es, this message translates to:
  /// **'Este libro todavía no tiene etiquetas.'**
  String get noTags;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get save;

  /// No description provided for @configuration.
  ///
  /// In es, this message translates to:
  /// **'Configuración'**
  String get configuration;

  /// No description provided for @freewiseServerUrl.
  ///
  /// In es, this message translates to:
  /// **'URL del servidor FreeWise'**
  String get freewiseServerUrl;

  /// No description provided for @freewiseUrlHint.
  ///
  /// In es, this message translates to:
  /// **'https://freewise.example.com'**
  String get freewiseUrlHint;

  /// No description provided for @includeScheme.
  ///
  /// In es, this message translates to:
  /// **'Incluye http:// o https://'**
  String get includeScheme;

  /// No description provided for @darkMode.
  ///
  /// In es, this message translates to:
  /// **'Modo oscuro'**
  String get darkMode;

  /// No description provided for @sepiaTone.
  ///
  /// In es, this message translates to:
  /// **'Tono sepia'**
  String get sepiaTone;

  /// No description provided for @justifyText.
  ///
  /// In es, this message translates to:
  /// **'Justificar texto'**
  String get justifyText;

  /// No description provided for @justifyHint.
  ///
  /// In es, this message translates to:
  /// **'Alinea el texto a ambos márgenes cuando el EPUB lo permita.'**
  String get justifyHint;

  /// No description provided for @fontSize.
  ///
  /// In es, this message translates to:
  /// **'Tamaño de letra · {value}%'**
  String fontSize(int value);

  /// No description provided for @lineHeight.
  ///
  /// In es, this message translates to:
  /// **'Interlineado · {value}'**
  String lineHeight(String value);

  /// No description provided for @margins.
  ///
  /// In es, this message translates to:
  /// **'Márgenes · {value}%'**
  String margins(int value);

  /// No description provided for @fontSizeSemantics.
  ///
  /// In es, this message translates to:
  /// **'Tamaño de letra: {value} por ciento'**
  String fontSizeSemantics(int value);

  /// No description provided for @lineHeightSemantics.
  ///
  /// In es, this message translates to:
  /// **'Interlineado: {value}'**
  String lineHeightSemantics(String value);

  /// No description provided for @marginsSemantics.
  ///
  /// In es, this message translates to:
  /// **'Márgenes: {value} por ciento'**
  String marginsSemantics(int value);

  /// No description provided for @language.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In es, this message translates to:
  /// **'Automático (idioma del dispositivo)'**
  String get languageSystem;

  /// No description provided for @languageSpanish.
  ///
  /// In es, this message translates to:
  /// **'Español'**
  String get languageSpanish;

  /// No description provided for @languageCatalan.
  ///
  /// In es, this message translates to:
  /// **'Català'**
  String get languageCatalan;

  /// No description provided for @languageEnglish.
  ///
  /// In es, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @settingsSaved.
  ///
  /// In es, this message translates to:
  /// **'Configuración guardada.'**
  String get settingsSaved;

  /// No description provided for @nextcloudConnect.
  ///
  /// In es, this message translates to:
  /// **'Conectar con Nextcloud'**
  String get nextcloudConnect;

  /// No description provided for @nextcloudUrl.
  ///
  /// In es, this message translates to:
  /// **'URL de Nextcloud'**
  String get nextcloudUrl;

  /// No description provided for @username.
  ///
  /// In es, this message translates to:
  /// **'Usuario'**
  String get username;

  /// No description provided for @appPassword.
  ///
  /// In es, this message translates to:
  /// **'Contraseña de aplicación'**
  String get appPassword;

  /// No description provided for @keepPassword.
  ///
  /// In es, this message translates to:
  /// **'Déjala vacía para conservar la guardada.'**
  String get keepPassword;

  /// No description provided for @createPassword.
  ///
  /// In es, this message translates to:
  /// **'Créala desde Seguridad en Nextcloud.'**
  String get createPassword;

  /// No description provided for @secureStorage.
  ///
  /// In es, this message translates to:
  /// **'La contraseña se guarda cifrada en el almacenamiento seguro del dispositivo.'**
  String get secureStorage;

  /// No description provided for @httpsRequired.
  ///
  /// In es, this message translates to:
  /// **'Usa una URL segura que empiece por https://.'**
  String get httpsRequired;

  /// No description provided for @usernameRequired.
  ///
  /// In es, this message translates to:
  /// **'Indica el usuario de Nextcloud.'**
  String get usernameRequired;

  /// No description provided for @passwordRequired.
  ///
  /// In es, this message translates to:
  /// **'Indica una contraseña de aplicación.'**
  String get passwordRequired;

  /// No description provided for @nextcloudSaved.
  ///
  /// In es, this message translates to:
  /// **'Conexión de Nextcloud guardada.'**
  String get nextcloudSaved;

  /// No description provided for @syncLibrary.
  ///
  /// In es, this message translates to:
  /// **'Sincronizar biblioteca'**
  String get syncLibrary;

  /// No description provided for @configureNextcloud.
  ///
  /// In es, this message translates to:
  /// **'Configurar Nextcloud'**
  String get configureNextcloud;

  /// No description provided for @syncNoChanges.
  ///
  /// In es, this message translates to:
  /// **'Biblioteca, lectura y subrayados sincronizados con Nextcloud.'**
  String get syncNoChanges;

  /// No description provided for @syncCounts.
  ///
  /// In es, this message translates to:
  /// **'Nextcloud: {uploaded} EPUB enviados, {downloaded} recibidos.'**
  String syncCounts(int uploaded, int downloaded);

  /// No description provided for @syncFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo sincronizar con Nextcloud: {error}'**
  String syncFailed(String error);

  /// No description provided for @readerAppearance.
  ///
  /// In es, this message translates to:
  /// **'Apariencia de lectura'**
  String get readerAppearance;

  /// No description provided for @tableOfContents.
  ///
  /// In es, this message translates to:
  /// **'Índice del libro'**
  String get tableOfContents;

  /// No description provided for @tocMissing.
  ///
  /// In es, this message translates to:
  /// **'Este EPUB no incluye un índice.'**
  String get tocMissing;

  /// No description provided for @closeToc.
  ///
  /// In es, this message translates to:
  /// **'Cerrar índice'**
  String get closeToc;

  /// No description provided for @sectionOpenFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir esa sección.'**
  String get sectionOpenFailed;

  /// No description provided for @searchInBook.
  ///
  /// In es, this message translates to:
  /// **'Buscar en el libro'**
  String get searchInBook;

  /// No description provided for @searchTerm.
  ///
  /// In es, this message translates to:
  /// **'Palabra o frase'**
  String get searchTerm;

  /// No description provided for @search.
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get search;

  /// No description provided for @searchNoResults.
  ///
  /// In es, this message translates to:
  /// **'No hay resultados para «{query}».'**
  String searchNoResults(String query);

  /// No description provided for @searchFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo buscar en el EPUB: {error}'**
  String searchFailed(String error);

  /// No description provided for @searchResults.
  ///
  /// In es, this message translates to:
  /// **'Resultados de búsqueda'**
  String get searchResults;

  /// No description provided for @searchResultsCount.
  ///
  /// In es, this message translates to:
  /// **'«{query}» · {count} resultados'**
  String searchResultsCount(String query, int count);

  /// No description provided for @closeResults.
  ///
  /// In es, this message translates to:
  /// **'Cerrar resultados'**
  String get closeResults;

  /// No description provided for @chapter.
  ///
  /// In es, this message translates to:
  /// **'Capítulo'**
  String get chapter;

  /// No description provided for @searchResultFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir ese resultado.'**
  String get searchResultFailed;

  /// No description provided for @goToPosition.
  ///
  /// In es, this message translates to:
  /// **'Ir a una posición'**
  String get goToPosition;

  /// No description provided for @bookProgress.
  ///
  /// In es, this message translates to:
  /// **'Progreso del libro: {value}%'**
  String bookProgress(int value);

  /// No description provided for @go.
  ///
  /// In es, this message translates to:
  /// **'Ir'**
  String get go;

  /// No description provided for @progressFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo ir a esa posición.'**
  String get progressFailed;

  /// No description provided for @currentPositionUnknown.
  ///
  /// In es, this message translates to:
  /// **'Aún no se conoce la posición actual.'**
  String get currentPositionUnknown;

  /// No description provided for @moreOptions.
  ///
  /// In es, this message translates to:
  /// **'Más opciones'**
  String get moreOptions;

  /// No description provided for @close.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get close;

  /// No description provided for @readAloud.
  ///
  /// In es, this message translates to:
  /// **'Lectura en voz alta'**
  String get readAloud;

  /// No description provided for @exportAnnotations.
  ///
  /// In es, this message translates to:
  /// **'Exportar anotaciones'**
  String get exportAnnotations;

  /// No description provided for @syncFreewise.
  ///
  /// In es, this message translates to:
  /// **'Sincronizar con FreeWise'**
  String get syncFreewise;

  /// No description provided for @addBookmark.
  ///
  /// In es, this message translates to:
  /// **'Añadir marcador'**
  String get addBookmark;

  /// No description provided for @bookmarkName.
  ///
  /// In es, this message translates to:
  /// **'Nombre (opcional)'**
  String get bookmarkName;

  /// No description provided for @bookmarkExample.
  ///
  /// In es, this message translates to:
  /// **'Por ejemplo, “Capítulo favorito”'**
  String get bookmarkExample;

  /// No description provided for @bookmarkSaved.
  ///
  /// In es, this message translates to:
  /// **'Marcador guardado.'**
  String get bookmarkSaved;

  /// No description provided for @bookmarkSaveFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar el marcador: {error}'**
  String bookmarkSaveFailed(String error);

  /// No description provided for @addBookmarkHere.
  ///
  /// In es, this message translates to:
  /// **'Añadir marcador aquí'**
  String get addBookmarkHere;

  /// No description provided for @closeBookmarks.
  ///
  /// In es, this message translates to:
  /// **'Cerrar marcadores'**
  String get closeBookmarks;

  /// No description provided for @noBookmarks.
  ///
  /// In es, this message translates to:
  /// **'Todavía no has guardado marcadores.'**
  String get noBookmarks;

  /// No description provided for @deleteBookmark.
  ///
  /// In es, this message translates to:
  /// **'Eliminar marcador'**
  String get deleteBookmark;

  /// No description provided for @bookmarkDeleteFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo eliminar el marcador: {error}'**
  String bookmarkDeleteFailed(String error);

  /// No description provided for @bookmarkOpenFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir ese marcador.'**
  String get bookmarkOpenFailed;

  /// No description provided for @restoreHighlightsFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron mostrar los subrayados guardados.'**
  String get restoreHighlightsFailed;

  /// No description provided for @highlightColorFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar el color del subrayado.'**
  String get highlightColorFailed;

  /// No description provided for @highlightSaveFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar el subrayado: {error}'**
  String highlightSaveFailed(String error);

  /// No description provided for @deleteHighlight.
  ///
  /// In es, this message translates to:
  /// **'Eliminar subrayado'**
  String get deleteHighlight;

  /// No description provided for @delete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get delete;

  /// No description provided for @highlightDeleted.
  ///
  /// In es, this message translates to:
  /// **'Subrayado eliminado.'**
  String get highlightDeleted;

  /// No description provided for @addNote.
  ///
  /// In es, this message translates to:
  /// **'Añadir nota'**
  String get addNote;

  /// No description provided for @noteHint.
  ///
  /// In es, this message translates to:
  /// **'Escribe una nota'**
  String get noteHint;

  /// No description provided for @saveAndSync.
  ///
  /// In es, this message translates to:
  /// **'Guardar y sincronizar'**
  String get saveAndSync;

  /// No description provided for @configureFreewise.
  ///
  /// In es, this message translates to:
  /// **'Configurar FreeWise'**
  String get configureFreewise;

  /// No description provided for @freewiseUrl.
  ///
  /// In es, this message translates to:
  /// **'URL del servidor'**
  String get freewiseUrl;

  /// No description provided for @noNewAnnotations.
  ///
  /// In es, this message translates to:
  /// **'No hay anotaciones nuevas para sincronizar.'**
  String get noNewAnnotations;

  /// No description provided for @annotationsSent.
  ///
  /// In es, this message translates to:
  /// **'Anotaciones enviadas a FreeWise.'**
  String get annotationsSent;

  /// No description provided for @annotationsExported.
  ///
  /// In es, this message translates to:
  /// **'{count} anotaciones exportadas a CSV.'**
  String annotationsExported(int count);

  /// No description provided for @freewiseSyncFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo sincronizar con FreeWise: {error}'**
  String freewiseSyncFailed(String error);

  /// No description provided for @fullscreen.
  ///
  /// In es, this message translates to:
  /// **'Pantalla completa'**
  String get fullscreen;

  /// No description provided for @exitFullscreen.
  ///
  /// In es, this message translates to:
  /// **'Salir de pantalla completa'**
  String get exitFullscreen;

  /// No description provided for @readerToc.
  ///
  /// In es, this message translates to:
  /// **'Índice del libro'**
  String get readerToc;

  /// No description provided for @readerBookmarks.
  ///
  /// In es, this message translates to:
  /// **'Marcadores'**
  String get readerBookmarks;

  /// No description provided for @readerSearch.
  ///
  /// In es, this message translates to:
  /// **'Buscar en el libro'**
  String get readerSearch;

  /// No description provided for @readerMore.
  ///
  /// In es, this message translates to:
  /// **'Más opciones'**
  String get readerMore;

  /// No description provided for @chooseColor.
  ///
  /// In es, this message translates to:
  /// **'Elegir color'**
  String get chooseColor;

  /// No description provided for @saving.
  ///
  /// In es, this message translates to:
  /// **'Guardando…'**
  String get saving;

  /// No description provided for @previousSentence.
  ///
  /// In es, this message translates to:
  /// **'Frase anterior'**
  String get previousSentence;

  /// No description provided for @pause.
  ///
  /// In es, this message translates to:
  /// **'Pausar'**
  String get pause;

  /// No description provided for @play.
  ///
  /// In es, this message translates to:
  /// **'Reproducir'**
  String get play;

  /// No description provided for @nextSentence.
  ///
  /// In es, this message translates to:
  /// **'Frase siguiente'**
  String get nextSentence;

  /// No description provided for @readingSpeed.
  ///
  /// In es, this message translates to:
  /// **'Velocidad de lectura'**
  String get readingSpeed;

  /// No description provided for @closeReadAloud.
  ///
  /// In es, this message translates to:
  /// **'Cerrar lectura en voz alta'**
  String get closeReadAloud;

  /// No description provided for @speedValue.
  ///
  /// In es, this message translates to:
  /// **'Velocidad de lectura: {value} veces'**
  String speedValue(String value);

  /// No description provided for @highlightColorTitle.
  ///
  /// In es, this message translates to:
  /// **'Color del subrayado'**
  String get highlightColorTitle;

  /// No description provided for @underlineAction.
  ///
  /// In es, this message translates to:
  /// **'Subrayar'**
  String get underlineAction;

  /// No description provided for @colorYellow.
  ///
  /// In es, this message translates to:
  /// **'Amarillo'**
  String get colorYellow;

  /// No description provided for @colorGreen.
  ///
  /// In es, this message translates to:
  /// **'Verde'**
  String get colorGreen;

  /// No description provided for @colorBlue.
  ///
  /// In es, this message translates to:
  /// **'Azul'**
  String get colorBlue;

  /// No description provided for @colorPink.
  ///
  /// In es, this message translates to:
  /// **'Rosa'**
  String get colorPink;

  /// No description provided for @colorOrange.
  ///
  /// In es, this message translates to:
  /// **'Naranja'**
  String get colorOrange;

  /// No description provided for @readerError.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido abrir el EPUB con Readium: {error}'**
  String readerError(String error);

  /// No description provided for @readerPathMissing.
  ///
  /// In es, this message translates to:
  /// **'El EPUB no tiene una ruta local disponible.'**
  String get readerPathMissing;

  /// No description provided for @applyPreferencesFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron aplicar los ajustes: {error}'**
  String applyPreferencesFailed(String error);

  /// No description provided for @savePositionFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar la posición actual: {error}'**
  String savePositionFailed(String error);

  /// No description provided for @deleteBookConfirmation.
  ///
  /// In es, this message translates to:
  /// **'«{title}» se eliminará de este dispositivo y de Nextcloud. Esta acción no se puede deshacer.'**
  String deleteBookConfirmation(String title);

  /// No description provided for @remoteBookRemoved.
  ///
  /// In es, this message translates to:
  /// **'Este libro se eliminó desde otro dispositivo.'**
  String get remoteBookRemoved;

  /// No description provided for @bookDeleted.
  ///
  /// In es, this message translates to:
  /// **'Libro eliminado de este dispositivo y Nextcloud.'**
  String get bookDeleted;

  /// No description provided for @apply.
  ///
  /// In es, this message translates to:
  /// **'Aplicar'**
  String get apply;

  /// No description provided for @confirmDeleteHighlight.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar este subrayado?'**
  String get confirmDeleteHighlight;

  /// No description provided for @readAloudFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo iniciar la lectura en voz alta: {error}'**
  String readAloudFailed(String error);

  /// No description provided for @readAloudSkipFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo avanzar en la lectura: {error}'**
  String readAloudSkipFailed(String error);

  /// No description provided for @readAloudSpeedFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cambiar la velocidad: {error}'**
  String readAloudSpeedFailed(String error);

  /// No description provided for @annotationsSynced.
  ///
  /// In es, this message translates to:
  /// **'Nuevas anotaciones sincronizadas.'**
  String get annotationsSynced;

  /// No description provided for @automaticSyncFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo sincronizar automáticamente: {error}'**
  String automaticSyncFailed(String error);

  /// No description provided for @bookmarkPoint.
  ///
  /// In es, this message translates to:
  /// **'Punto {value}'**
  String bookmarkPoint(int value);

  /// No description provided for @copy.
  ///
  /// In es, this message translates to:
  /// **'Copiar'**
  String get copy;

  /// No description provided for @authorUnknown.
  ///
  /// In es, this message translates to:
  /// **'Autor desconocido'**
  String get authorUnknown;

  /// No description provided for @epubPathMissing.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido obtener la ruta del EPUB.'**
  String get epubPathMissing;

  /// No description provided for @epubOpenFailed.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido abrir el EPUB: {error}'**
  String epubOpenFailed(String error);

  /// No description provided for @waitForSync.
  ///
  /// In es, this message translates to:
  /// **'Espera a que termine la sincronización antes de eliminar.'**
  String get waitForSync;

  /// No description provided for @deleteBookFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo eliminar el libro: {error}'**
  String deleteBookFailed(String error);

  /// No description provided for @saveTagsFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron guardar las etiquetas: {error}'**
  String saveTagsFailed(String error);

  /// No description provided for @saveConnectionFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar la conexión: {error}'**
  String saveConnectionFailed(String error);

  /// No description provided for @loadSettingsFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar la configuración: {error}'**
  String loadSettingsFailed(String error);

  /// No description provided for @saveSettingsFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar la configuración: {error}'**
  String saveSettingsFailed(String error);

  /// No description provided for @invalidFreewiseUrl.
  ///
  /// In es, this message translates to:
  /// **'Introduce una URL válida que empiece por http:// o https://.'**
  String get invalidFreewiseUrl;

  /// No description provided for @nextcloudUrlHint.
  ///
  /// In es, this message translates to:
  /// **'https://nube.ejemplo.com'**
  String get nextcloudUrlHint;
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
      <String>['ca', 'en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ca':
      return AppLocalizationsCa();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
