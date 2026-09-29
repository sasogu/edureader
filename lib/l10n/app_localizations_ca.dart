// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Catalan Valencian (`ca`).
class AppLocalizationsCa extends AppLocalizations {
  AppLocalizationsCa([String locale = 'ca']) : super(locale);

  @override
  String get appTitle => 'EduReader';

  @override
  String get library => 'Biblioteca';

  @override
  String booksCount(int count) {
    return '$count EPUB';
  }

  @override
  String get emptyLibraryTitle => 'La biblioteca és buida';

  @override
  String get emptyLibraryBody =>
      'EduReader se centra en els EPUB, una lectura còmoda i els subratllats que podrem enviar a FreeWise.';

  @override
  String get chooseEpub => 'Tria un EPUB';

  @override
  String get addEpub => 'Afegeix un altre EPUB';

  @override
  String get settings => 'Configuració';

  @override
  String get nextcloudSync => 'Sincronització amb Nextcloud';

  @override
  String get searchLibrary => 'Cerca a la biblioteca';

  @override
  String get searchTitleOrAuthor => 'Títol o autor';

  @override
  String get filterTags => 'Filtra per etiquetes';

  @override
  String get multiTagFilterHint =>
      'Si en tries diverses, es mostraran els llibres que les tinguin totes.';

  @override
  String get clear => 'Neteja';

  @override
  String get sortBy => 'Ordena per';

  @override
  String get recentlyAdded => 'Afegits recentment';

  @override
  String get sortTitle => 'Títol';

  @override
  String get sortAuthor => 'Autor';

  @override
  String get noBooks => 'La biblioteca és buida.';

  @override
  String noBooksMatch(String query) {
    return 'No hi ha cap llibre que coincideixi amb «$query».';
  }

  @override
  String get editTags => 'Edita les etiquetes';

  @override
  String get deleteBook => 'Elimina el llibre';

  @override
  String get tagsForBook => 'Etiquetes del llibre';

  @override
  String get newTag => 'Etiqueta nova';

  @override
  String get addTag => 'Afegeix una etiqueta';

  @override
  String get noTags => 'Aquest llibre encara no té etiquetes.';

  @override
  String get cancel => 'Cancel·la';

  @override
  String get save => 'Desa';

  @override
  String get configuration => 'Configuració';

  @override
  String get freewiseServerUrl => 'URL del servidor FreeWise';

  @override
  String get freewiseUrlHint => 'https://freewise.example.com';

  @override
  String get includeScheme => 'Inclou http:// o https://';

  @override
  String get darkMode => 'Mode fosc';

  @override
  String get sepiaTone => 'To sèpia';

  @override
  String get justifyText => 'Justifica el text';

  @override
  String get justifyHint =>
      'Alinea el text als dos marges quan l’EPUB ho permeti.';

  @override
  String fontSize(int value) {
    return 'Mida de la lletra · $value%';
  }

  @override
  String lineHeight(String value) {
    return 'Interlineat · $value';
  }

  @override
  String margins(int value) {
    return 'Marges · $value%';
  }

  @override
  String fontSizeSemantics(int value) {
    return 'Mida de la lletra: $value per cent';
  }

  @override
  String lineHeightSemantics(String value) {
    return 'Interlineat: $value';
  }

  @override
  String marginsSemantics(int value) {
    return 'Marges: $value per cent';
  }

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Automàtic (idioma del dispositiu)';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageCatalan => 'Català';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsSaved => 'S’ha desat la configuració.';

  @override
  String get nextcloudConnect => 'Connecta amb Nextcloud';

  @override
  String get nextcloudUrl => 'URL de Nextcloud';

  @override
  String get username => 'Usuari';

  @override
  String get appPassword => 'Contrasenya d’aplicació';

  @override
  String get keepPassword =>
      'Deixa-la buida per conservar la que ja està desada.';

  @override
  String get createPassword => 'Crea-la a l’apartat Seguretat de Nextcloud.';

  @override
  String get secureStorage =>
      'La contrasenya es desa xifrada a l’emmagatzematge segur del dispositiu.';

  @override
  String get httpsRequired =>
      'Fes servir una URL segura que comenci per https://.';

  @override
  String get usernameRequired => 'Indica l’usuari de Nextcloud.';

  @override
  String get passwordRequired => 'Indica una contrasenya d’aplicació.';

  @override
  String get nextcloudSaved => 'S’ha desat la connexió amb Nextcloud.';

  @override
  String get syncLibrary => 'Sincronitza la biblioteca';

  @override
  String get configureNextcloud => 'Configura Nextcloud';

  @override
  String get syncNoChanges =>
      'S’han sincronitzat la biblioteca, la lectura i els subratllats amb Nextcloud.';

  @override
  String syncCounts(int uploaded, int downloaded) {
    return 'Nextcloud: $uploaded EPUB enviats, $downloaded rebuts.';
  }

  @override
  String syncFailed(String error) {
    return 'No s’ha pogut sincronitzar amb Nextcloud: $error';
  }

  @override
  String get readerAppearance => 'Aparença de lectura';

  @override
  String get tableOfContents => 'Índex del llibre';

  @override
  String get tocMissing => 'Aquest EPUB no inclou cap índex.';

  @override
  String get closeToc => 'Tanca l’índex';

  @override
  String get sectionOpenFailed => 'No s’ha pogut obrir aquesta secció.';

  @override
  String get searchInBook => 'Cerca al llibre';

  @override
  String get searchTerm => 'Paraula o frase';

  @override
  String get search => 'Cerca';

  @override
  String searchNoResults(String query) {
    return 'No hi ha resultats per a «$query».';
  }

  @override
  String searchFailed(String error) {
    return 'No s’ha pogut cercar a l’EPUB: $error';
  }

  @override
  String get searchResults => 'Resultats de cerca';

  @override
  String searchResultsCount(String query, int count) {
    return '«$query» · $count resultats';
  }

  @override
  String get closeResults => 'Tanca els resultats';

  @override
  String get chapter => 'Capítol';

  @override
  String get searchResultFailed => 'No s’ha pogut obrir aquest resultat.';

  @override
  String get goToPosition => 'Ves a una posició';

  @override
  String bookProgress(int value) {
    return 'Progrés del llibre: $value%';
  }

  @override
  String get go => 'Ves-hi';

  @override
  String get progressFailed => 'No s’ha pogut anar a aquesta posició.';

  @override
  String get currentPositionUnknown => 'Encara no es coneix la posició actual.';

  @override
  String get moreOptions => 'Més opcions';

  @override
  String get close => 'Tanca';

  @override
  String get readAloud => 'Lectura en veu alta';

  @override
  String get exportAnnotations => 'Exporta les anotacions';

  @override
  String get syncFreewise => 'Sincronitza amb FreeWise';

  @override
  String get addBookmark => 'Afegeix un marcador';

  @override
  String get bookmarkName => 'Nom (opcional)';

  @override
  String get bookmarkExample => 'Per exemple, «Capítol preferit»';

  @override
  String get bookmarkSaved => 'S’ha desat el marcador.';

  @override
  String bookmarkSaveFailed(String error) {
    return 'No s’ha pogut desar el marcador: $error';
  }

  @override
  String get addBookmarkHere => 'Afegeix un marcador aquí';

  @override
  String get closeBookmarks => 'Tanca els marcadors';

  @override
  String get noBookmarks => 'Encara no has desat cap marcador.';

  @override
  String get deleteBookmark => 'Elimina el marcador';

  @override
  String bookmarkDeleteFailed(String error) {
    return 'No s’ha pogut eliminar el marcador: $error';
  }

  @override
  String get bookmarkOpenFailed => 'No s’ha pogut obrir aquest marcador.';

  @override
  String get restoreHighlightsFailed =>
      'No s’han pogut mostrar els subratllats desats.';

  @override
  String get highlightColorFailed =>
      'No s’ha pogut desar el color del subratllat.';

  @override
  String highlightSaveFailed(String error) {
    return 'No s’ha pogut desar el subratllat: $error';
  }

  @override
  String get deleteHighlight => 'Elimina el subratllat';

  @override
  String get delete => 'Elimina';

  @override
  String get highlightDeleted => 'S’ha eliminat el subratllat.';

  @override
  String get addNote => 'Afegeix una nota';

  @override
  String get noteHint => 'Escriu una nota';

  @override
  String get saveAndSync => 'Desa i sincronitza';

  @override
  String get configureFreewise => 'Configura FreeWise';

  @override
  String get freewiseUrl => 'URL del servidor';

  @override
  String get noNewAnnotations => 'No hi ha anotacions noves per sincronitzar.';

  @override
  String get annotationsSent => 'S’han enviat les anotacions a FreeWise.';

  @override
  String annotationsExported(int count) {
    return 'S’han exportat $count anotacions a CSV.';
  }

  @override
  String freewiseSyncFailed(String error) {
    return 'No s’ha pogut sincronitzar amb FreeWise: $error';
  }

  @override
  String get fullscreen => 'Pantalla completa';

  @override
  String get exitFullscreen => 'Surt de la pantalla completa';

  @override
  String get readerToc => 'Índex del llibre';

  @override
  String get readerBookmarks => 'Marcadors';

  @override
  String get readerSearch => 'Cerca al llibre';

  @override
  String get readerMore => 'Més opcions';

  @override
  String get chooseColor => 'Tria el color';

  @override
  String get saving => 'S’està desant…';

  @override
  String get previousSentence => 'Frase anterior';

  @override
  String get pause => 'Pausa';

  @override
  String get play => 'Reprodueix';

  @override
  String get nextSentence => 'Frase següent';

  @override
  String get readingSpeed => 'Velocitat de lectura';

  @override
  String get closeReadAloud => 'Tanca la lectura en veu alta';

  @override
  String speedValue(String value) {
    return 'Velocitat de lectura: $value vegades';
  }

  @override
  String get highlightColorTitle => 'Color del subratllat';

  @override
  String get underlineAction => 'Subratlla';

  @override
  String get colorYellow => 'Groc';

  @override
  String get colorGreen => 'Verd';

  @override
  String get colorBlue => 'Blau';

  @override
  String get colorPink => 'Rosa';

  @override
  String get colorOrange => 'Taronja';

  @override
  String readerError(String error) {
    return 'No s’ha pogut obrir l’EPUB amb Readium: $error';
  }

  @override
  String get readerPathMissing => 'L’EPUB no té cap ruta local disponible.';

  @override
  String applyPreferencesFailed(String error) {
    return 'No s’han pogut aplicar els ajustos: $error';
  }

  @override
  String savePositionFailed(String error) {
    return 'No s’ha pogut desar la posició actual: $error';
  }

  @override
  String deleteBookConfirmation(String title) {
    return '«$title» s’eliminarà d’aquest dispositiu i de Nextcloud. Aquesta acció no es pot desfer.';
  }

  @override
  String get remoteBookRemoved =>
      'Aquest llibre s’ha eliminat des d’un altre dispositiu.';

  @override
  String get bookDeleted =>
      'S’ha eliminat el llibre d’aquest dispositiu i de Nextcloud.';

  @override
  String get apply => 'Aplica';

  @override
  String get confirmDeleteHighlight => 'Vols eliminar aquest subratllat?';

  @override
  String readAloudFailed(String error) {
    return 'No s’ha pogut iniciar la lectura en veu alta: $error';
  }

  @override
  String readAloudSkipFailed(String error) {
    return 'No s’ha pogut avançar en la lectura: $error';
  }

  @override
  String readAloudSpeedFailed(String error) {
    return 'No s’ha pogut canviar la velocitat: $error';
  }

  @override
  String get annotationsSynced => 'S’han sincronitzat anotacions noves.';

  @override
  String automaticSyncFailed(String error) {
    return 'No s’ha pogut sincronitzar automàticament: $error';
  }

  @override
  String bookmarkPoint(int value) {
    return 'Punt $value';
  }

  @override
  String get copy => 'Copia';

  @override
  String get authorUnknown => 'Autor desconegut';

  @override
  String get epubPathMissing => 'No s’ha pogut obtenir la ruta de l’EPUB.';

  @override
  String epubOpenFailed(String error) {
    return 'No s’ha pogut obrir l’EPUB: $error';
  }

  @override
  String get waitForSync =>
      'Espera que acabi la sincronització abans d’eliminar-lo.';

  @override
  String deleteBookFailed(String error) {
    return 'No s’ha pogut eliminar el llibre: $error';
  }

  @override
  String saveTagsFailed(String error) {
    return 'No s’han pogut desar les etiquetes: $error';
  }

  @override
  String saveConnectionFailed(String error) {
    return 'No s’ha pogut desar la connexió: $error';
  }

  @override
  String loadSettingsFailed(String error) {
    return 'No s’ha pogut carregar la configuració: $error';
  }

  @override
  String saveSettingsFailed(String error) {
    return 'No s’ha pogut desar la configuració: $error';
  }

  @override
  String get invalidFreewiseUrl =>
      'Introdueix una URL vàlida que comenci per http:// o https://.';

  @override
  String get nextcloudUrlHint => 'https://nuv.example.cat';
}
