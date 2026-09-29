// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'EduReader';

  @override
  String get library => 'Biblioteca';

  @override
  String booksCount(int count) {
    return '$count EPUB';
  }

  @override
  String get emptyLibraryTitle => 'Tu biblioteca está vacía';

  @override
  String get emptyLibraryBody =>
      'EduReader empieza centrado en EPUB, lectura cómoda y subrayados que podremos enviar a FreeWise.';

  @override
  String get chooseEpub => 'Elegir un EPUB';

  @override
  String get addEpub => 'Añadir otro EPUB';

  @override
  String get settings => 'Ajustes';

  @override
  String get nextcloudSync => 'Sincronización Nextcloud';

  @override
  String get searchLibrary => 'Buscar en la biblioteca';

  @override
  String get searchTitleOrAuthor => 'Título o autor';

  @override
  String get filterTags => 'Filtrar por etiquetas';

  @override
  String get multiTagFilterHint =>
      'Al elegir varias, se muestran los libros que tienen todas.';

  @override
  String get clear => 'Limpiar';

  @override
  String get sortBy => 'Ordenar por';

  @override
  String get recentlyAdded => 'Añadidos recientemente';

  @override
  String get sortTitle => 'Título';

  @override
  String get sortAuthor => 'Autor';

  @override
  String get noBooks => 'La biblioteca está vacía.';

  @override
  String noBooksMatch(String query) {
    return 'No hay libros que coincidan con «$query».';
  }

  @override
  String get editTags => 'Editar etiquetas';

  @override
  String get deleteBook => 'Eliminar libro';

  @override
  String get tagsForBook => 'Etiquetas del libro';

  @override
  String get newTag => 'Nueva etiqueta';

  @override
  String get addTag => 'Añadir etiqueta';

  @override
  String get noTags => 'Este libro todavía no tiene etiquetas.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get configuration => 'Configuración';

  @override
  String get freewiseServerUrl => 'URL del servidor FreeWise';

  @override
  String get freewiseUrlHint => 'https://freewise.example.com';

  @override
  String get includeScheme => 'Incluye http:// o https://';

  @override
  String get darkMode => 'Modo oscuro';

  @override
  String get sepiaTone => 'Tono sepia';

  @override
  String get justifyText => 'Justificar texto';

  @override
  String get justifyHint =>
      'Alinea el texto a ambos márgenes cuando el EPUB lo permita.';

  @override
  String fontSize(int value) {
    return 'Tamaño de letra · $value%';
  }

  @override
  String lineHeight(String value) {
    return 'Interlineado · $value';
  }

  @override
  String margins(int value) {
    return 'Márgenes · $value%';
  }

  @override
  String fontSizeSemantics(int value) {
    return 'Tamaño de letra: $value por ciento';
  }

  @override
  String lineHeightSemantics(String value) {
    return 'Interlineado: $value';
  }

  @override
  String marginsSemantics(int value) {
    return 'Márgenes: $value por ciento';
  }

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Automático (idioma del dispositivo)';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageCatalan => 'Català';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsSaved => 'Configuración guardada.';

  @override
  String get nextcloudConnect => 'Conectar con Nextcloud';

  @override
  String get nextcloudUrl => 'URL de Nextcloud';

  @override
  String get username => 'Usuario';

  @override
  String get appPassword => 'Contraseña de aplicación';

  @override
  String get keepPassword => 'Déjala vacía para conservar la guardada.';

  @override
  String get createPassword => 'Créala desde Seguridad en Nextcloud.';

  @override
  String get secureStorage =>
      'La contraseña se guarda cifrada en el almacenamiento seguro del dispositivo.';

  @override
  String get httpsRequired => 'Usa una URL segura que empiece por https://.';

  @override
  String get usernameRequired => 'Indica el usuario de Nextcloud.';

  @override
  String get passwordRequired => 'Indica una contraseña de aplicación.';

  @override
  String get nextcloudSaved => 'Conexión de Nextcloud guardada.';

  @override
  String get syncLibrary => 'Sincronizar biblioteca';

  @override
  String get configureNextcloud => 'Configurar Nextcloud';

  @override
  String get syncNoChanges =>
      'Biblioteca, lectura y subrayados sincronizados con Nextcloud.';

  @override
  String syncCounts(int uploaded, int downloaded) {
    return 'Nextcloud: $uploaded EPUB enviados, $downloaded recibidos.';
  }

  @override
  String syncFailed(String error) {
    return 'No se pudo sincronizar con Nextcloud: $error';
  }

  @override
  String get readerAppearance => 'Apariencia de lectura';

  @override
  String get tableOfContents => 'Índice del libro';

  @override
  String get tocMissing => 'Este EPUB no incluye un índice.';

  @override
  String get closeToc => 'Cerrar índice';

  @override
  String get sectionOpenFailed => 'No se pudo abrir esa sección.';

  @override
  String get searchInBook => 'Buscar en el libro';

  @override
  String get searchTerm => 'Palabra o frase';

  @override
  String get search => 'Buscar';

  @override
  String searchNoResults(String query) {
    return 'No hay resultados para «$query».';
  }

  @override
  String searchFailed(String error) {
    return 'No se pudo buscar en el EPUB: $error';
  }

  @override
  String get searchResults => 'Resultados de búsqueda';

  @override
  String searchResultsCount(String query, int count) {
    return '«$query» · $count resultados';
  }

  @override
  String get closeResults => 'Cerrar resultados';

  @override
  String get chapter => 'Capítulo';

  @override
  String get searchResultFailed => 'No se pudo abrir ese resultado.';

  @override
  String get goToPosition => 'Ir a una posición';

  @override
  String bookProgress(int value) {
    return 'Progreso del libro: $value%';
  }

  @override
  String get go => 'Ir';

  @override
  String get progressFailed => 'No se pudo ir a esa posición.';

  @override
  String get currentPositionUnknown => 'Aún no se conoce la posición actual.';

  @override
  String get moreOptions => 'Más opciones';

  @override
  String get close => 'Cerrar';

  @override
  String get readAloud => 'Lectura en voz alta';

  @override
  String get exportAnnotations => 'Exportar anotaciones';

  @override
  String get syncFreewise => 'Sincronizar con FreeWise';

  @override
  String get addBookmark => 'Añadir marcador';

  @override
  String get bookmarkName => 'Nombre (opcional)';

  @override
  String get bookmarkExample => 'Por ejemplo, “Capítulo favorito”';

  @override
  String get bookmarkSaved => 'Marcador guardado.';

  @override
  String bookmarkSaveFailed(String error) {
    return 'No se pudo guardar el marcador: $error';
  }

  @override
  String get addBookmarkHere => 'Añadir marcador aquí';

  @override
  String get closeBookmarks => 'Cerrar marcadores';

  @override
  String get noBookmarks => 'Todavía no has guardado marcadores.';

  @override
  String get deleteBookmark => 'Eliminar marcador';

  @override
  String bookmarkDeleteFailed(String error) {
    return 'No se pudo eliminar el marcador: $error';
  }

  @override
  String get bookmarkOpenFailed => 'No se pudo abrir ese marcador.';

  @override
  String get restoreHighlightsFailed =>
      'No se pudieron mostrar los subrayados guardados.';

  @override
  String get highlightColorFailed =>
      'No se pudo guardar el color del subrayado.';

  @override
  String highlightSaveFailed(String error) {
    return 'No se pudo guardar el subrayado: $error';
  }

  @override
  String get deleteHighlight => 'Eliminar subrayado';

  @override
  String get delete => 'Eliminar';

  @override
  String get highlightDeleted => 'Subrayado eliminado.';

  @override
  String get addNote => 'Añadir nota';

  @override
  String get noteHint => 'Escribe una nota';

  @override
  String get saveAndSync => 'Guardar y sincronizar';

  @override
  String get configureFreewise => 'Configurar FreeWise';

  @override
  String get freewiseUrl => 'URL del servidor';

  @override
  String get noNewAnnotations => 'No hay anotaciones nuevas para sincronizar.';

  @override
  String get annotationsSent => 'Anotaciones enviadas a FreeWise.';

  @override
  String annotationsExported(int count) {
    return '$count anotaciones exportadas a CSV.';
  }

  @override
  String freewiseSyncFailed(String error) {
    return 'No se pudo sincronizar con FreeWise: $error';
  }

  @override
  String get fullscreen => 'Pantalla completa';

  @override
  String get exitFullscreen => 'Salir de pantalla completa';

  @override
  String get readerToc => 'Índice del libro';

  @override
  String get readerBookmarks => 'Marcadores';

  @override
  String get readerBookmarksAndHighlights => 'Marcadores y subrayados';

  @override
  String get savedHighlightsTab => 'Subrayados';

  @override
  String get noSavedHighlights => 'Todavía no has guardado subrayados.';

  @override
  String get savedHighlightFallback => 'Fragmento subrayado';

  @override
  String get readerSearch => 'Buscar en el libro';

  @override
  String get readerMore => 'Más opciones';

  @override
  String get chooseColor => 'Elegir color';

  @override
  String get saving => 'Guardando…';

  @override
  String get previousSentence => 'Frase anterior';

  @override
  String get pause => 'Pausar';

  @override
  String get play => 'Reproducir';

  @override
  String get nextSentence => 'Frase siguiente';

  @override
  String get readingSpeed => 'Velocidad de lectura';

  @override
  String get closeReadAloud => 'Cerrar lectura en voz alta';

  @override
  String speedValue(String value) {
    return 'Velocidad de lectura: $value veces';
  }

  @override
  String get highlightColorTitle => 'Color del subrayado';

  @override
  String get underlineAction => 'Subrayar';

  @override
  String get underlineStyle => 'Subrayado';

  @override
  String get highlightStyle => 'Fondo de color';

  @override
  String get colorYellow => 'Amarillo';

  @override
  String get colorGreen => 'Verde';

  @override
  String get colorBlue => 'Azul';

  @override
  String get colorPink => 'Rosa';

  @override
  String get colorOrange => 'Naranja';

  @override
  String readerError(String error) {
    return 'No se ha podido abrir el EPUB con Readium: $error';
  }

  @override
  String get readerPathMissing => 'El EPUB no tiene una ruta local disponible.';

  @override
  String applyPreferencesFailed(String error) {
    return 'No se pudieron aplicar los ajustes: $error';
  }

  @override
  String savePositionFailed(String error) {
    return 'No se pudo guardar la posición actual: $error';
  }

  @override
  String deleteBookConfirmation(String title) {
    return '«$title» se eliminará de este dispositivo y de Nextcloud. Esta acción no se puede deshacer.';
  }

  @override
  String get remoteBookRemoved =>
      'Este libro se eliminó desde otro dispositivo.';

  @override
  String get bookDeleted => 'Libro eliminado de este dispositivo y Nextcloud.';

  @override
  String get apply => 'Aplicar';

  @override
  String get confirmDeleteHighlight => '¿Eliminar este subrayado?';

  @override
  String readAloudFailed(String error) {
    return 'No se pudo iniciar la lectura en voz alta: $error';
  }

  @override
  String readAloudSkipFailed(String error) {
    return 'No se pudo avanzar en la lectura: $error';
  }

  @override
  String readAloudSpeedFailed(String error) {
    return 'No se pudo cambiar la velocidad: $error';
  }

  @override
  String get annotationsSynced => 'Nuevas anotaciones sincronizadas.';

  @override
  String automaticSyncFailed(String error) {
    return 'No se pudo sincronizar automáticamente: $error';
  }

  @override
  String bookmarkPoint(int value) {
    return 'Punto $value';
  }

  @override
  String get copy => 'Copiar';

  @override
  String get authorUnknown => 'Autor desconocido';

  @override
  String get epubPathMissing => 'No se ha podido obtener la ruta del EPUB.';

  @override
  String epubOpenFailed(String error) {
    return 'No se ha podido abrir el EPUB: $error';
  }

  @override
  String get waitForSync =>
      'Espera a que termine la sincronización antes de eliminar.';

  @override
  String deleteBookFailed(String error) {
    return 'No se pudo eliminar el libro: $error';
  }

  @override
  String saveTagsFailed(String error) {
    return 'No se pudieron guardar las etiquetas: $error';
  }

  @override
  String saveConnectionFailed(String error) {
    return 'No se pudo guardar la conexión: $error';
  }

  @override
  String loadSettingsFailed(String error) {
    return 'No se pudo cargar la configuración: $error';
  }

  @override
  String saveSettingsFailed(String error) {
    return 'No se pudo guardar la configuración: $error';
  }

  @override
  String get invalidFreewiseUrl =>
      'Introduce una URL válida que empiece por http:// o https://.';

  @override
  String get nextcloudUrlHint => 'https://nube.ejemplo.com';

  @override
  String get savedNotesTab => 'Notas';

  @override
  String get noSavedNotes => 'Todavía no has guardado notas.';
}
