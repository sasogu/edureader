# EduReader

Lector EPUB personal para iPad y Android. El proyecto nace con una prioridad
concreta: leer cómodamente, subrayar y conservar los subrayados en una base
local que después pueda sincronizarse con FreeWise.

## Estado

En marcha:

- Proyecto Flutter para Android e iOS.
- Biblioteca local persistente: los EPUB se copian al almacenamiento privado de la aplicación.
- Selector de archivos EPUB.
- Parseo de EPUB y apertura en el lector.
- Navegación por capítulos y controles básicos de lectura.
- Tema Material 3 y estructura separada por funcionalidades.

Siguiente vertical:

1. Mejorar la sincronización incremental y el control de duplicados.

La biblioteca persistida guarda una copia privada de cada EPUB dentro de la
aplicación y registra sus rutas con `shared_preferences`. El progreso de lectura
también se guarda por libro, capítulo y posición. El motor de lectura actual es
`flutter_readium`, con paginación horizontal real, selección de texto y
decoraciones persistentes. La integración queda aislada en
`features/reader/presentation/reader_page.dart`; el parser de EPUB anterior se
mantiene como puente temporal para la biblioteca y la exportación.

Los subrayados se guardan mediante el servicio local del lector y las notas se
conectan explícitamente desde EduReader. Ambos quedan asociados al libro y al
capítulo para preparar la futura exportación a FreeWise.

Desde la pantalla de lectura se pueden exportar las anotaciones del libro a
un CSV compatible con la importación de FreeWise. El archivo usa las columnas
Readwise/FreeWise y fechas ISO con zona horaria UTC.

La configuración permite guardar la URL de FreeWise y personalizar la lectura
con tamaño de letra, interlineado, márgenes y tono sepia. El modo oscuro se
aplica a la interfaz y al EPUB; sepia y oscuro son excluyentes. Los ajustes de
lectura se conservan entre sesiones y se pueden cambiar desde la biblioteca o
el propio lector.

Durante la lectura, el botón de índice abre la tabla de contenidos del EPUB y
permite saltar directamente a sus capítulos y secciones.

También se pueden guardar varios marcadores con nombre opcional por libro,
volver a cada punto y eliminarlos sin afectar al progreso automático ni a los
subrayados.

El lector permite buscar palabras y frases en el EPUB, consultar fragmentos y
abrir directamente cada coincidencia en Android e iOS.

El menú del lector también permite saltar por porcentaje a cualquier punto del
libro, además de la navegación por capítulos del índice.

El lector incluye controles iniciales de lectura en voz alta con Readium:
reproducir o pausar, avanzar o retroceder una frase y ajustar la velocidad. La
disponibilidad y el seguimiento del texto dependen de las voces del dispositivo
y de la estructura del EPUB.

También existe sincronización directa: el botón de nube envía el CSV al
endpoint de importación de FreeWise. La primera vez solicita la URL del
servidor y la guarda localmente. Las siguientes sincronizaciones son
incrementales y solo envían anotaciones posteriores a la última sincronización
correcta. Si falla la red, el intento queda pendiente.

La biblioteca ofrece sincronización manual con Nextcloud por WebDAV. Se
configura el servidor HTTPS, el usuario y una contraseña de aplicación; esta
última se guarda en el almacén seguro del sistema. EduReader sube y descarga
los EPUB, los deduplica por SHA-256 y sincroniza el localizador de lectura y los
marcadores, usando la última modificación cuando hay cambios en ambos
dispositivos. La sincronización de anotaciones y ajustes queda para una fase
posterior. La conexión todavía debe validarse con un servidor Nextcloud real.

La biblioteca permite filtrar por título o autor y ordenar por incorporación,
título o autor; estas operaciones solo cambian la vista y no alteran los EPUB.

La configuración nativa de Readium requiere Android con `minSdk 24`,
`FlutterFragmentActivity` y desugaring de la biblioteca estándar. En iOS se
incluyen los pods de Readium con despliegue mínimo en iOS 15. En web se carga
el adaptador `web/readiumReader.js` generado por `flutter_readium`.

El alcance inicial es deliberadamente solo EPUB. PDF, DRM, audiolibros y
funciones avanzadas quedan fuera hasta que el flujo básico sea sólido.

## Desarrollo

Requisitos: Flutter estable y Dart compatibles con `pubspec.yaml`.

```bash
cd edureader
flutter pub get
flutter test
flutter analyze
flutter run
```

### Probar en navegador

```bash
flutter run -d chrome
```

Para servir la compilación web desde otro dispositivo de la red:

```bash
python3 -m http.server 8080 --directory build/web --bind 0.0.0.0
```

Después abre `http://IP_DEL_SERVIDOR:8080`. El selector de archivos funciona
en el navegador, aunque la biblioteca web usa el almacenamiento del navegador
y no comparte los EPUB con Android o iOS.

### Probar en Android

El APK de depuración se genera con:

```bash
flutter build apk --debug
```

El archivo queda en `build/app/outputs/flutter-apk/app-debug.apk`. Se puede
copiar al teléfono e instalarlo, o ejecutar directamente:

```bash
flutter run -d android
```

## Arquitectura prevista

```text
lib/
├── app.dart
├── core/                  # tema, configuración y utilidades comunes
└── features/
    ├── library/           # libros, biblioteca y metadatos
    ├── reader/            # lector EPUB y anotaciones
    ├── highlights/        # subrayados y notas
    └── sync/              # FreeWise y copias WebDAV/Nextcloud
```

La aplicación debe funcionar primero sin cuenta ni servidor: los datos locales
son la fuente de verdad y la sincronización se añadirá como una cola opcional.

## Licencia

EduReader se distribuye bajo la licencia MIT. Consulta `LICENSE`.
