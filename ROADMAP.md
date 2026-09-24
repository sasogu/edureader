# Hoja de ruta de EduReader

Este documento sirve para retomar el desarrollo después de una pausa. Prioriza
mejoras útiles para la lectura y registra el estado conocido de la aplicación.

## Estado actual

- Biblioteca local e importación de EPUB.
- Lectura EPUB con Readium, guardado del progreso y subrayados/notas.
- Exportación y sincronización de anotaciones con FreeWise.
- Índice del EPUB para saltar a capítulos y secciones.
- Ajuste persistente del tamaño de letra y modo oscuro para la app y el EPUB.
- Modo pantalla completa con control para salir y restauración de las barras
  del sistema al abandonar el lector.
- Marcadores por libro con nombre opcional, restauración de posición y borrado
  independiente del progreso automático y de las anotaciones.
- Búsqueda en EPUB con resultados por capítulo, fragmento de contexto y salto
  directo a la coincidencia en Android/iOS.
- Navegación por porcentaje del progreso total del libro, en saltos del 1 %.
- Falta probar búsqueda, marcadores, progreso y pantalla completa en el
  teléfono. La última APK `arm64-v8a` todavía no incluye búsqueda ni progreso.

## Pendiente, por prioridad

### 1. Personalización de lectura

Ampliar los controles existentes con interlineado, márgenes y un tono sepia,
manteniendo tamaño de letra y modo oscuro. Guardar las preferencias entre
sesiones y comprobar su efecto en distintos EPUB.

**Comprobación:** cambiar cada ajuste, abrir otro libro y confirmar que se
mantiene; comprobar que el modo claro y oscuro siguen siendo legibles.

### 2. Accesibilidad y pantallas grandes

Revisar TalkBack/VoiceOver, etiquetas accesibles, contraste y áreas táctiles.
Adaptar biblioteca, índice y controles para tabletas y orientación horizontal.

**Comprobación:** completar las acciones principales con lector de pantalla y
probar el lector en teléfono, tableta y apaisado.

### 3. Lectura en voz alta

Integrar los controles TTS de Readium: iniciar/pausar, avanzar y retroceder,
velocidad y seguimiento del texto, si la voz y el EPUB lo permiten.

**Comprobación:** probar con la app en segundo plano, pantalla bloqueada y un
EPUB con estructura y voces compatibles; documentar las limitaciones.

### 4. Organización de la biblioteca

Mostrar portadas y permitir buscar, ordenar y agrupar libros. Mantener el
almacenamiento local y no borrar archivos al reorganizar la vista.

**Comprobación:** importar varios EPUB, ordenar y filtrar; cerrar y volver a
abrir la app para confirmar que la biblioteca permanece intacta.

## Notas técnicas para retomar

- Flutter gestiona interfaz, temas, navegación y adaptación de pantalla.
- Readium gestiona EPUB, índice, búsqueda, locators, preferencias de lectura y
  varias capacidades de navegación. En la versión integrada, la búsqueda está
  disponible en Android/iOS, pero no en web.
- Mantener la arquitectura ARM64: publicar y probar el APK
  `app-arm64-v8a-release.apk`.
- Antes de entregar una función: ejecutar `flutter analyze` y `flutter test`,
  generar la APK ARM64 y probar el flujo correspondiente en el teléfono.
- El estado Git puede contener cambios aún sin commit; comprobar `git status`
  antes de continuar o limpiar nada.
