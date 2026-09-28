# Publicación en las tiendas

Material para Google Play y App Store. La app solo está en español, así que la ficha es `es-ES`.

## Contenido

| Ruta | Uso |
| --- | --- |
| `play/es-ES/` | Título, descripción breve y completa, notas de la versión (Play). |
| `appstore/es-ES/` | Nombre, subtítulo, texto promocional, descripción, palabras clave, novedades (App Store). |
| `screenshots/appstore/iphone-6.9/` | Capturas iPhone 6,9" (1320×2868). |
| `screenshots/appstore/ipad-13/` | Capturas iPad 13" (2064×2752). |
| `screenshots/play/phone/` | Capturas de teléfono para Play (1080×1920, proporción ≤ 2:1). |
| `screenshots/play/tablet/` | Capturas de tableta para Play (1536×2048, desde el iPad). |
| `graphics/feature-graphic.png` | Gráfico de funciones de Play (1024×500). |
| `graphics/icon-512.png` | Icono de Play (512×512). |

Las capturas se regeneran con `tool/store_screenshots.sh <carpeta-con-epubs>` en un Mac con los simuladores de Xcode. Para las de ejemplo se usaron EPUB de dominio público de Project Gutenberg. Después, `tool/store_assets.py` compone las de Play y los gráficos.

Política de privacidad (URL pública): https://github.com/sasogu/edureader/blob/master/PRIVACY.md
Soporte: https://github.com/sasogu/edureader/issues

## Google Play Console

1. Crear la app: EduReader, idioma predeterminado español (España), aplicación, gratuita.
2. Firma: activar **Play App Signing** y subir `build/app/outputs/bundle/release/app-release.aab`, firmado con la clave de subida (`android/key.properties`, que no está en el repositorio). Guarda una copia de la clave de subida.
3. Ficha de la tienda: copiar los textos de `play/es-ES/` y subir el icono, el gráfico de funciones y las capturas.
4. Categoría: **Libros y obras de consulta**. Correo de contacto: el tuyo. Sitio web: el repositorio.
5. Seguridad de los datos: **no se recogen ni se comparten datos**. Los envíos a Nextcloud y FreeWise van a servidores que configura el usuario, no al desarrollador. Cifrado en tránsito: sí (HTTPS). Sin opción para eliminar datos porque no hay cuenta.
6. Clasificación de contenido (IARC): categoría «Referencia, noticias o educación». Responder no a violencia, sexo, lenguaje, drogas, apuestas e interacción entre usuarios. Sin compras. Resultado esperado: PEGI 3.
7. Público objetivo: 13 años o más. Así se evitan los requisitos de la Familias Policy; es un lector genérico.
8. Anuncios: no. Acceso a la app: no requiere inicio de sesión.
9. **Servicio en primer plano** (`FOREGROUND_SERVICE_MEDIA_PLAYBACK`): tipo «Reproducción multimedia». Justificación: «La lectura en voz alta de libros continúa con la pantalla bloqueada o con la app en segundo plano, con controles de reproducción en la notificación». Puede pedir un vídeo corto: abrir un libro, Más opciones → Lectura en voz alta, bloquear la pantalla y mostrar la notificación.
10. `POST_NOTIFICATIONS`: se usa para la notificación de reproducción de la lectura en voz alta.
11. Pruebas: una cuenta personal nueva exige prueba cerrada con 12 testers durante 14 días antes de producción. Si la cuenta es de organización o antigua, se puede ir a producción directamente.

## App Store Connect

1. Nueva app: plataforma iOS, nombre «EduReader – Lector EPUB», idioma principal español (España), bundle ID `es.edutictac.edureader`, SKU `edureader`.
2. Categoría principal **Libros**, secundaria **Educación**.
3. Privacidad de la app: **Datos no recopilados**. URL de privacidad: la de arriba.
4. Clasificación por edades: todas las respuestas «Ninguno» / «No» → 4+.
5. Cumplimiento de exportación: ya declarado en `Info.plist` (`ITSAppUsesNonExemptEncryption = false`).
6. Precio: gratis. Disponibilidad: todos los países o los que quieras.
7. Versión: copiar los textos de `appstore/es-ES/` y subir las capturas de iPhone 6,9" y iPad 13" (App Store reescala a los tamaños pequeños).
8. Build: en el Mac, `git pull`, `flutter build ios --config-only`, y en Xcode abrir `ios/Runner.xcworkspace` → Product → Archive → Distribute App → App Store Connect.
9. Notas para la revisión: «No requiere cuenta. Para probar, importe cualquier EPUB desde Archivos. Nextcloud y FreeWise son opcionales y usan servidores del propio usuario».

## Antes de cada versión

- Subir `version` en `pubspec.yaml` (nombre y número de build).
- Actualizar `release_notes.txt` en ambas carpetas.
