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

1. Seleccionar texto y crear subrayados/notas propios de EduReader.
2. Exportar subrayados en un formato estable.
3. Sincronizar con FreeWise.

La biblioteca persistida guarda una copia privada de cada EPUB dentro de la
aplicación y registra sus rutas con `shared_preferences`. El progreso de lectura
también se guarda por libro, capítulo y posición. El motor de lectura actual es
`advanced_epub_reader`; su integración queda aislada en
`features/reader/presentation/reader_page.dart` para poder cambiarla sin
reorganizar la aplicación.

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
