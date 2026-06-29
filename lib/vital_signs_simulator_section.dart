import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'vital_signs_simulator.dart';

class VitalSignsSimulatorSection extends StatefulWidget {
  final String patientName;
  final String professionalName;
  final VitalSigns initialVitals;
  final VitalSignsPersistence? persistence;
  final ValueChanged<VitalSigns>? onVitalsChanged;
  final ValueChanged<SimulatorAlert>? onAlertCreated;
  final ValueChanged<SimulatorAlert>? onAlertConfirmed;

  const VitalSignsSimulatorSection({
    super.key,
    required this.patientName,
    this.professionalName = 'Profissional SAUH',
    required this.initialVitals,
    this.persistence,
    this.onVitalsChanged,
    this.onAlertCreated,
    this.onAlertConfirmed,
  });

  @override
  State<VitalSignsSimulatorSection> createState() =>
      _VitalSignsSimulatorSectionState();
}

class _VitalSignsSimulatorSectionState
    extends State<VitalSignsSimulatorSection> {
  late final VitalSignsSimulator _simulator;
  final List<VitalSigns> _history = [];
  Timer? _muteTimer;
  DateTime? _mutedUntil;
  String? _lastAlertSignature;
  String? _confirmedAlertSignature;

  bool get isMuted => _mutedUntil?.isAfter(DateTime.now()) ?? false;

  @override
  void initState() {
    super.initState();
    _simulator = VitalSignsSimulator(
      patientName: widget.patientName,
      initialVitals: widget.initialVitals,
      persistence: widget.persistence,
      onAlertCreated: widget.onAlertCreated,
    )..addListener(_handleSimulatorChanged);
    _history.add(widget.initialVitals);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _simulator.start();
    });
  }

  @override
  void dispose() {
    _muteTimer?.cancel();
    _simulator
      ..removeListener(_handleSimulatorChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSimulatorChanged() {
    _history.add(_simulator.vitals);
    if (_history.length > 40) {
      _history.removeAt(0);
    }
    final alert = _simulator.latestAlert;
    if (alert != null) {
      final signature = _alertSignature(alert);
      if (_lastAlertSignature != signature) {
        _lastAlertSignature = signature;
        _confirmedAlertSignature = null;
        if (!isMuted) {
          unawaited(SystemSound.play(SystemSoundType.alert));
        }
      }
    }
    widget.onVitalsChanged?.call(_simulator.vitals);
    if (mounted) setState(() {});
  }

  void _setMode(SimulationMode mode) {
    _simulator.setMode(mode);
  }

  String _alertSignature(SimulatorAlert alert) {
    return '${alert.type}-${alert.createdAt.toIso8601String()}';
  }

  String _formatExactTime(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}:'
        '${value.second.toString().padLeft(2, '0')}';
  }

  void _toggleMute() {
    _muteTimer?.cancel();
    if (isMuted) {
      setState(() {
        _mutedUntil = null;
      });
      return;
    }

    final mutedUntil = DateTime.now().add(const Duration(minutes: 2));
    setState(() {
      _mutedUntil = mutedUntil;
    });
    _muteTimer = Timer(const Duration(minutes: 2), () {
      if (mounted) {
        setState(() {
          _mutedUntil = null;
        });
      }
    });
  }

  void _confirmLatestAlert() {
    final alert = _simulator.latestAlert;
    if (alert == null) return;

    setState(() {
      _confirmedAlertSignature = _alertSignature(alert);
    });
    widget.onAlertConfirmed?.call(alert);
  }

  @override
  Widget build(BuildContext context) {
    final vitals = _simulator.vitals;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.patientName,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Iniciar Simulação'),
                  onPressed: _simulator.isRunning
                      ? null
                      : () => _simulator.start(),
                ),
                _ModeButton(
                  label: 'Normal',
                  mode: SimulationMode.normal,
                  currentMode: _simulator.mode,
                  onPressed: _setMode,
                ),
                _ModeButton(
                  label: 'Stress',
                  mode: SimulationMode.stress,
                  currentMode: _simulator.mode,
                  onPressed: _setMode,
                ),
                _ModeButton(
                  label: 'Crítico',
                  mode: SimulationMode.critical,
                  currentMode: _simulator.mode,
                  onPressed: _setMode,
                ),
                _ModeButton(
                  label: 'Febre',
                  mode: SimulationMode.fever,
                  currentMode: _simulator.mode,
                  onPressed: _setMode,
                ),
                _ModeButton(
                  label: 'Falta de Oxigénio',
                  mode: SimulationMode.lowOxygen,
                  currentMode: _simulator.mode,
                  onPressed: _setMode,
                ),
                _ModeButton(
                  label: 'Recuperação',
                  mode: SimulationMode.recovery,
                  currentMode: _simulator.mode,
                  onPressed: _setMode,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.stop_circle),
                  label: const Text('Parar'),
                  onPressed: () => _setMode(SimulationMode.stopped),
                ),
                OutlinedButton.icon(
                  icon: Icon(isMuted ? Icons.volume_up : Icons.volume_off),
                  label: Text(isMuted ? 'Ativar som' : 'Silenciar 2 min'),
                  onPressed: _toggleMute,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatusLine(
                    label: 'Modo atual',
                    value: VitalSignsSimulator.modeLabel(_simulator.mode),
                  ),
                ),
                Expanded(
                  child: _StatusLine(
                    label: 'Última ação do bot',
                    value: _simulator.lastBotAction,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _VitalChip(
                  icon: Icons.favorite,
                  label: 'Batimentos',
                  value: '${vitals.heartRate} bpm',
                  danger: vitals.heartRate > 130,
                ),
                _VitalChip(
                  icon: Icons.air,
                  label: 'Oxigénio',
                  value: '${vitals.oxygen}%',
                  danger: vitals.oxygen < 90,
                ),
                _VitalChip(
                  icon: Icons.thermostat,
                  label: 'Temperatura',
                  value: '${vitals.temperature.toStringAsFixed(1)} ºC',
                  danger: vitals.temperature > 38.5,
                ),
                _VitalChip(
                  icon: Icons.bloodtype,
                  label: 'Pressão',
                  value:
                      '${vitals.systolicPressure}/${vitals.diastolicPressure}',
                  danger: vitals.systolicPressure < 90,
                ),
                _VitalChip(
                  icon: Icons.waves,
                  label: 'Respiração',
                  value: '${vitals.respiratoryRate} rpm',
                  danger: vitals.respiratoryRate > 28,
                ),
                _VitalChip(
                  icon: Icons.health_and_safety,
                  label: 'Estado',
                  value: vitals.patientStatus,
                  danger: vitals.alertLevel == 'Crítico',
                ),
                _VitalChip(
                  icon: Icons.notification_important,
                  label: 'Nível de Alerta',
                  value: vitals.alertLevel,
                  danger: vitals.alertLevel == 'Crítico',
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(height: 190, child: _VitalsTrendChart(history: _history)),
            if (_simulator.latestAlert != null) ...[
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final alert = _simulator.latestAlert!;
                  final isConfirmed =
                      _confirmedAlertSignature == _alertSignature(alert);

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alerta crítico',
                          style: TextStyle(
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('Motivo: ${alert.message}'),
                        Text(
                          'Hora exata: ${_formatExactTime(alert.createdAt)}',
                        ),
                        if (isMuted && _mutedUntil != null)
                          Text(
                            'Som silenciado até ${_formatExactTime(_mutedUntil!)}',
                          ),
                        if (isConfirmed)
                          Text(
                            'Confirmado por: ${widget.professionalName}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: Icon(
                            isConfirmed ? Icons.check_circle : Icons.done,
                          ),
                          label: Text(
                            isConfirmed
                                ? 'Alerta confirmado'
                                : 'Confirmar alerta',
                          ),
                          onPressed: isConfirmed ? null : _confirmLatestAlert,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            if (_simulator.lastPersistenceError != null) ...[
              const SizedBox(height: 12),
              Text(
                _simulator.lastPersistenceError!,
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VitalsTrendChart extends StatelessWidget {
  final List<VitalSigns> history;

  const _VitalsTrendChart({required this.history});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Evolução em tempo real',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: CustomPaint(
                painter: _VitalsTrendPainter(history),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 6),
            const Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _LegendDot(color: Colors.red, label: 'Batimentos'),
                _LegendDot(color: Colors.blue, label: 'Oxigénio'),
                _LegendDot(color: Colors.deepOrange, label: 'Temperatura'),
                _LegendDot(color: Colors.purple, label: 'Sistólica'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _VitalsTrendPainter extends CustomPainter {
  final List<VitalSigns> history;

  const _VitalsTrendPainter(this.history);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.blueGrey.withValues(alpha: 0.14)
      ..strokeWidth = 1;

    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (history.length < 2) return;

    _drawLine(
      canvas,
      size,
      values: history.map((vitals) => vitals.heartRate.toDouble()).toList(),
      minValue: 50,
      maxValue: 170,
      color: Colors.red,
    );
    _drawLine(
      canvas,
      size,
      values: history.map((vitals) => vitals.oxygen.toDouble()).toList(),
      minValue: 80,
      maxValue: 100,
      color: Colors.blue,
    );
    _drawLine(
      canvas,
      size,
      values: history.map((vitals) => vitals.temperature).toList(),
      minValue: 35,
      maxValue: 41,
      color: Colors.deepOrange,
    );
    _drawLine(
      canvas,
      size,
      values: history
          .map((vitals) => vitals.systolicPressure.toDouble())
          .toList(),
      minValue: 70,
      maxValue: 160,
      color: Colors.purple,
    );
  }

  void _drawLine(
    Canvas canvas,
    Size size, {
    required List<double> values,
    required double minValue,
    required double maxValue,
    required Color color,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    final count = values.length;

    for (var i = 0; i < count; i++) {
      final x = count == 1 ? 0.0 : size.width * i / (count - 1);
      final normalized = ((values[i] - minValue) / (maxValue - minValue))
          .clamp(0.0, 1.0)
          .toDouble();
      final y = size.height - normalized * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _VitalsTrendPainter oldDelegate) {
    return true;
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final SimulationMode mode;
  final SimulationMode currentMode;
  final ValueChanged<SimulationMode> onPressed;

  const _ModeButton({
    required this.label,
    required this.mode,
    required this.currentMode,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final selected = mode == currentMode;
    return selected
        ? FilledButton(onPressed: () => onPressed(mode), child: Text(label))
        : OutlinedButton(onPressed: () => onPressed(mode), child: Text(label));
  }
}

class _StatusLine extends StatelessWidget {
  final String label;
  final String value;

  const _StatusLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _VitalChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool danger;

  const _VitalChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.danger,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.red : Colors.blueGrey;
    return Container(
      width: 178,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12)),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
