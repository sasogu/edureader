import 'package:flutter/material.dart';

/// Velocidad real del motor de voz que se muestra como «1.0×». La velocidad
/// nativa de las voces resulta demasiado rápida para seguir la lectura.
const ttsBaseRate = 0.8;

/// Convierte la velocidad elegida por el usuario en la que recibe Readium.
double ttsEngineRate(double speed) => speed * ttsBaseRate;

/// Controles flotantes de la lectura en voz alta. No bloquean el libro: se
/// puede pasar página, subrayar o abrir menús mientras sigue leyendo.
class ReadAloudMiniPlayer extends StatefulWidget {
  const ReadAloudMiniPlayer({
    required this.isPlaying,
    required this.isBusy,
    required this.speed,
    required this.onTogglePlayback,
    required this.onSkip,
    required this.onSpeedChanged,
    required this.onClose,
    this.onMove,
    super.key,
  });

  final bool isPlaying;
  final bool isBusy;
  final double speed;
  final VoidCallback onTogglePlayback;
  final ValueChanged<bool> onSkip;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onClose;

  /// Se llama al arrastrar el reproductor hacia arriba (true) o hacia abajo
  /// (false), para no tapar el texto que se quiere leer.
  final ValueChanged<bool>? onMove;

  @override
  State<ReadAloudMiniPlayer> createState() => _ReadAloudMiniPlayerState();
}

class _ReadAloudMiniPlayerState extends State<ReadAloudMiniPlayer> {
  bool _showSpeed = false;
  late double _speed = widget.speed;

  @override
  void didUpdateWidget(ReadAloudMiniPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.speed != widget.speed) _speed = widget.speed;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onVerticalDragEnd: widget.onMove == null
          ? null
          : (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity.abs() > 100) widget.onMove!(velocity < 0);
            },
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Material(
          elevation: 6,
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 8),
                    Icon(
                      Icons.record_voice_over_outlined,
                      color: colors.primary,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Frase anterior',
                      onPressed: () => widget.onSkip(false),
                      icon: const Icon(Icons.skip_previous),
                    ),
                    IconButton.filled(
                      tooltip: widget.isPlaying ? 'Pausar' : 'Reproducir',
                      onPressed: widget.isBusy ? null : widget.onTogglePlayback,
                      icon: Icon(
                        widget.isPlaying ? Icons.pause : Icons.play_arrow,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Frase siguiente',
                      onPressed: () => widget.onSkip(true),
                      icon: const Icon(Icons.skip_next),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() => _showSpeed = !_showSpeed),
                      child: Text(
                        '${_speed.toStringAsFixed(1)}×',
                        semanticsLabel: 'Velocidad de lectura',
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar lectura en voz alta',
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                if (_showSpeed)
                  Slider(
                    value: _speed,
                    min: 0.5,
                    max: 2,
                    divisions: 15,
                    label: '${_speed.toStringAsFixed(1)}×',
                    semanticFormatterCallback: (value) =>
                        'Velocidad de lectura: ${value.toStringAsFixed(1)} veces',
                    onChanged: (value) => setState(() => _speed = value),
                    onChangeEnd: widget.onSpeedChanged,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
