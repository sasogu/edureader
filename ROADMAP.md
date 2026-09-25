# Hoja de ruta de EduReader

Este documento sirve para retomar el desarrollo después de una pausa. Prioriza
mejoras útiles para la lectura y registra el estado conocido de la aplicación.

## Estado actual

- Biblioteca local e importación de EPUB.
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
- APK release `arm64-v8a` generada el 2026-09-25; incluye Nextcloud y el arreglo
  de pantalla completa. Falta probar búsqueda, marcadores, progreso,
  personalización, TTS, pantalla completa y sincronización en el teléfono.

## Pendiente, por prioridad

### 1. Confirmar restauración de lectura al alternar pantalla completa

El lector ahora mantiene el mismo árbol de widgets al ocultar/mostrar la barra
de sistema, actualiza el localizador inicial al avanzar y espera a que se guarde
la posición antes de cambiar de modo. Falta reproducir en el teléfono el caso
reportado: entrar y salir de pantalla completa sin volver al inicio del libro.

### 2. Validar sincronización Nextcloud en dispositivos (pendiente)

La primera fase está implementada: sincronización manual de EPUB, localizador
y marcadores. Falta configurar una cuenta real desde la app y validar la misma
biblioteca en dos dispositivos. La política actual usa la marca de última
modificación por libro; no hay bloqueo/ETag del manifiesto para escrituras
simultáneas, así que ese caso aún puede perder una actualización. Los borrados
no se propagan y los reintentos son manuales.

**Prueba de aceptación:** configurar URL HTTPS, usuario y contraseña de
aplicación; subir un libro desde un dispositivo y descargarlo en otro; probar
progreso, marcadores, credenciales incorrectas, desconexión durante subida y
reintento. No copiar credenciales a Git ni a registros.

### 3. Accesibilidad y pantallas grandes (en curso)

La biblioteca ahora usa una lista desplazable en teléfonos y una cuadrícula en
pantallas anchas, con un límite de ancho para aprovechar mejor tabletas. Los
paneles de índice, búsqueda y marcadores también limitan su ancho en pantallas
grandes. Los deslizadores de apariencia y navegación anuncian con TalkBack/
VoiceOver qué valor controlan y su unidad. Falta probar TalkBack/VoiceOver,
contraste, áreas táctiles y el resto de vistas en orientación horizontal.

**Comprobación:** completar las acciones principales con lector de pantalla y
probar el lector en teléfono, tableta y apaisado.

### 4. Lectura en voz alta (implementación inicial)

El menú del lector abre controles Readium para iniciar/pausar, avanzar o
retroceder una frase y ajustar la velocidad. La disponibilidad de voz y el
seguimiento dependen del sistema y del EPUB.

**Pendiente de comprobar en el teléfono:** voces disponibles, seguimiento del
texto, app en segundo plano y pantalla bloqueada; documentar limitaciones.

### 5. Organización de la biblioteca (en curso)

La biblioteca permite buscar por título o autor y ordenar por incorporación,
título o autor. Falta añadir portadas y agrupación. Estas operaciones solo
reorganizan la vista y no modifican los archivos locales.

**Comprobación:** importar varios EPUB, ordenar y filtrar; cerrar y volver a
abrir la app para confirmar que la biblioteca permanece intacta.

### 6. Ampliar sincronización entre dispositivos

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
- Estado Git al guardar esta nota: limpio. Comprobar `git status` antes de
  continuar o limpiar nada.
