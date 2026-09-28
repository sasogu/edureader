# Hoja de ruta de EduReader

Este documento sirve para retomar el desarrollo después de una pausa. Prioriza
mejoras útiles para la lectura y registra el estado conocido de la aplicación.

## Estado actual

- Biblioteca local e importación de EPUB.
- La biblioteca muestra una sola acción contextual para añadir libros: elegir
  EPUB cuando está vacía y añadir otro EPUB cuando ya contiene libros. Se
  eliminó el botón flotante duplicado.
- Lectura EPUB con Readium, guardado del progreso y subrayados/notas.
- Exportación y sincronización de anotaciones con FreeWise.
- Índice del EPUB para saltar a capítulos y secciones.
- Ajuste persistente del tamaño de letra y modo oscuro para la app y el EPUB.
- Personalización persistente del EPUB: tono sepia, interlineado y márgenes,
  además del tamaño de letra; oscuro y sepia son modos excluyentes.
- Modo pantalla completa con control para salir y restauración de las barras
  del sistema al abandonar el lector.
- Marcadores por libro con nombre opcional, restauración de posición y borrado
  independiente del progreso automático y de las anotaciones.
- Búsqueda en EPUB con resultados por capítulo, fragmento de contexto y salto
  directo a la coincidencia en Android/iOS.
- Navegación por porcentaje del progreso total del libro, en saltos del 1 %.
- Controles iniciales de lectura en voz alta con Readium: reproducción/pausa,
  salto de frase y velocidad ajustable.
- Sincronización manual Nextcloud/WebDAV implementada: EPUB por SHA-256,
  localizador y marcadores; contraseña de aplicación en almacenamiento seguro.
- Verificación de código tras la sincronización: `flutter analyze` limpio y
  `flutter test` con 9 pruebas aprobadas, incluida subida WebDAV y persistencia
  del localizador.
- `flutter analyze` limpio y `flutter test` con 9 pruebas aprobadas tras
  eliminar el botón duplicado de importación; se añadió una prueba de regresión.
- APK release `arm64-v8a` generada el 2026-09-25; incluye Nextcloud, el arreglo
  de pantalla completa y la acción única para añadir libros. Artefacto:
  `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (~26 MB).
  Falta probar búsqueda, marcadores, progreso,
  personalización, TTS y sincronización en el teléfono.
- Confirmado en el teléfono (2026-09-27): al entrar y salir de pantalla
  completa se conserva la posición de lectura.
- Sincronización Nextcloud validada con un servidor real en Android e iPad
  (2026-09-27, tras corregir la ruta duplicada `EduReader/EduReader`).
- Sincronización automática por libro al abrirlo y al cerrarlo (1.0.2+9):
  al entrar solo trae la posición, sin subir el EPUB; al salir publica el
  estado y sube el libro si falta. Los errores se ignoran en silencio.
- Sincronización también al pasar a segundo plano con un libro abierto
  (1.0.2+10): guarda la posición y la publica en Nextcloud.
- Portadas en la biblioteca (1.0.2+11): miniatura en la lista del móvil y
  estantería de portadas en pantallas anchas. Extractor propio por OPF
  (EPUB 3 `cover-image`, EPUB 2 `meta cover`) con caché en disco.

## Pendiente, por prioridad

### 1. Validar sincronización Nextcloud en dispositivos (pendiente)

La primera fase está implementada: sincronización manual y automática por
libro de EPUB, localizador y marcadores, ya probada con una cuenta real. Falta
comprobar el paso de la posición entre dos dispositivos con la sincronización
automática. La política actual usa la marca de última
modificación por libro; no hay bloqueo/ETag del manifiesto para escrituras
simultáneas, así que ese caso aún puede perder una actualización. Los borrados
no se propagan y los reintentos son manuales.

**Prueba de aceptación:** configurar URL HTTPS, usuario y contraseña de
aplicación; subir un libro desde un dispositivo y descargarlo en otro; probar
progreso, marcadores, credenciales incorrectas, desconexión durante subida y
reintento. No copiar credenciales a Git ni a registros.

### 2. Accesibilidad y pantallas grandes (en curso)

La biblioteca ahora usa una lista desplazable en teléfonos y una cuadrícula en
pantallas anchas, con un límite de ancho para aprovechar mejor tabletas. Los
paneles de índice, búsqueda y marcadores también limitan su ancho en pantallas
grandes. Los deslizadores de apariencia y navegación anuncian con TalkBack/
VoiceOver qué valor controlan y su unidad. Falta probar TalkBack/VoiceOver,
contraste, áreas táctiles y el resto de vistas en orientación horizontal.

**Comprobación:** completar las acciones principales con lector de pantalla y
probar el lector en teléfono, tableta y apaisado.

### 3. Lectura en voz alta (implementación inicial)

El menú del lector inicia la lectura y muestra un minirreproductor flotante
(iniciar/pausar, avanzar o retroceder una frase, velocidad y cerrar) que deja
seguir usando el libro y se puede arrastrar arriba o abajo. La disponibilidad de voz y el
seguimiento dependen del sistema y del EPUB.

**Pendiente de comprobar en el teléfono:** voces disponibles, seguimiento del
texto, app en segundo plano y pantalla bloqueada; documentar limitaciones.

### 4. Organización de la biblioteca (en curso)

La biblioteca permite buscar por título o autor y ordenar por incorporación,
título o autor. Falta añadir portadas y agrupación. Estas operaciones solo
reorganizan la vista y no modifican los archivos locales.

**Comprobación:** importar varios EPUB, ordenar y filtrar; cerrar y volver a
abrir la app para confirmar que la biblioteca permanece intacta.

### 5. Ampliar sincronización entre dispositivos

Después de validar la fase inicial, mejorar resolución de conflictos y reintentos;
añadir sincronización de anotaciones y preferencias. Mantener independiente la
exportación de anotaciones a FreeWise y conservar por ahora la política segura
de no propagar borrados.

## Notas técnicas para retomar

- Flutter gestiona interfaz, temas, navegación y adaptación de pantalla.
- Readium gestiona EPUB, índice, búsqueda, locators, preferencias de lectura y
  varias capacidades de navegación. En la versión integrada, la búsqueda está
  disponible en Android/iOS, pero no en web.
- Mantener la arquitectura ARM64: publicar y probar el APK
  `app-arm64-v8a-release.apk`.
- Antes de entregar una función: ejecutar `flutter analyze` y `flutter test`,
  generar la APK ARM64 solo cuando se solicite y probar el flujo correspondiente
  en el teléfono.
- Estado al guardar esta nota (2026-09-27): versión 1.0.2+6 preparada para
  App Store; Linux es la referencia y el Mac se sincroniza desde aquí.
