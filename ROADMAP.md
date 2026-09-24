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
- Falta probar búsqueda, marcadores, progreso, pantalla completa y los nuevos
  ajustes de lectura en el teléfono. No se ha generado una APK en esta sesión.

## Pendiente, por prioridad

### 1. Accesibilidad y pantallas grandes (en curso)

La biblioteca ahora usa una lista desplazable en teléfonos y una cuadrícula en
pantallas anchas, con un límite de ancho para aprovechar mejor tabletas. Los
paneles de índice, búsqueda y marcadores también limitan su ancho en pantallas
grandes. Los deslizadores de apariencia y navegación anuncian con TalkBack/
VoiceOver qué valor controlan y su unidad. Falta probar TalkBack/VoiceOver,
contraste, áreas táctiles y el resto de vistas en orientación horizontal.

**Comprobación:** completar las acciones principales con lector de pantalla y
probar el lector en teléfono, tableta y apaisado.

### 2. Lectura en voz alta (implementación inicial)

El menú del lector abre controles Readium para iniciar/pausar, avanzar o
retroceder una frase y ajustar la velocidad. La disponibilidad de voz y el
seguimiento dependen del sistema y del EPUB.

**Pendiente de comprobar en el teléfono:** voces disponibles, seguimiento del
texto, app en segundo plano y pantalla bloqueada; documentar limitaciones.

### 3. Organización de la biblioteca (en curso)

La biblioteca permite buscar por título o autor y ordenar por incorporación,
título o autor. Falta añadir portadas y agrupación. Estas operaciones solo
reorganizan la vista y no modifican los archivos locales.

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
  generar la APK ARM64 solo cuando se solicite y probar el flujo correspondiente
  en el teléfono.
- El estado Git puede contener cambios aún sin commit; comprobar `git status`
  antes de continuar o limpiar nada.
