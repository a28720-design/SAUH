import 'package:flutter/material.dart';

import 'vital_signs_simulator.dart';

class VitalSignsSimulatorSection extends StatefulWidget {
  final String patientName;
  final VitalSigns initialVitals;
  final VitalSignsPersistence? persistence;
  final ValueChanged<VitalSigns>? onVitalsChanged;
  final ValueChanged<SimulatorAlert>? onAlertCreated;

  const VitalSignsSimulatorSection({
    super.key,
    required this.patientName,
    required this.initialVitals,
    this.persistence,
    this.onVitalsChanged,
    this.onAlertCreated,
  });

  @override
  State<VitalSignsSimulatorSection> createState() =>
      _VitalSignsSimulatorSectionState();
}

class _VitalSignsSimulatorSectionState
    extends State<VitalSignsSimulatorSection> {
  late final TextEditingController _commandController;
  late final VitalSignsSimulator _simulator;
  final List<VitalSigns> _history = [];

  @override
  void initState() {
    super.initState();
    _commandController = TextEditingController();
    _simulator = VitalSignsSimulator(
      patientName: widget.patientName,
      initialVitals: widget.initialVitals,
      persistence: widget.persistence,
      onAlertCreated: widget.onAlertCreated,
    )..addListener(_handleSimulatorChanged);
    _history.add(widget.initialVitals);
  }

  @override
  void dispose() {
    _simulator
      ..removeListener(_handleSimulatorChanged)
      ..dispose();
    _commandController.dispose();
    super.dispose();
  }

  void _handleSimulatorChanged() {
    _history.add(_simulator.vitals);
    if (_history.length > 40) {
      _history.removeAt(0);
    }
    widget.onVitalsChanged?.call(_simulator.vitals);
    if (mounted) setState(() {});
  }

  void _sendCommand() {
    _simulator.processSimulationCommand(_commandController.text);
    _commandController.clear();
  }

  void _setMode(SimulationMode mode) {
    _simulator.setMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    final vitals = _simulator.vitals;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.monitor_heart, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Simulador Inteligente de Sinais Vitais',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commandController,
                    decoration: const InputDecoration(
                      labelText: 'Comando tipo IA',
                      hintText: 'Ex: simula febre',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendCommand(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: const Text('Enviar comando'),
                  onPressed: _sendCommand,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
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
                  label: 'Critico',
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
                  label: 'Falta de Oxigenio',
                  mode: SimulationMode.lowOxygen,
                  currentMode: _simulator.mode,
                  onPressed: _setMode,
                ),
                _ModeButton(
                  label: 'Recuperacao',
                  mode: SimulationMode.recovery,
                  currentMode: _simulator.mode,
                  onPressed: _setMode,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.stop_circle),
                  label: const Text('Parar'),
                  onPressed: () => _setMode(SimulationMode.stopped),
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
                    label: 'Ultima acao do bot',
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
                  label: 'Oxigenio',
                  value: '${vitals.oxygen}%',
                  danger: vitals.oxygen < 90,
                ),
                _VitalChip(
                  icon: Icons.thermostat,
                  label: 'Temperatura',
                  value: '${vitals.temperature.toStringAsFixed(1)} C',
                  danger: vitals.temperature > 38.5,
                ),
                _VitalChip(
                  icon: Icons.bloodtype,
                  label: 'Pressao',
                  value:
                      '${vitals.systolicPressure}/${vitals.diastolicPressure}',
                  danger: vitals.systolicPressure < 90,
                ),
                _VitalChip(
                  icon: Icons.waves,
                  label: 'Respiracao',
                  value: '${vitals.respiratoryRate} rpm',
                  danger: vitals.respiratoryRate > 28,
                ),
                _VitalChip(
                  icon: Icons.health_and_safety,
                  label: 'Estado',
                  value: vitals.patientStatus,
                  danger: vitals.alertLevel == 'Critico',
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 190,
              child: _VitalsTrendChart(history: _history),
            ),
            if (_simulator.latestAlert != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  'Alerta automatico: ${_simulator.latestAlert!.message}',
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
        border: Border.all(color: Colors.blueGrey.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Evolucao em tempo real',
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
                _LegendDot(color: Colors.blue, label: 'Oxigenio'),
                _LegendDot(color: Colors.deepOrange, label: 'Temperatura'),
                _LegendDot(color: Colors.purple, label: 'Sistolica'),
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

  const _LegendDot({
    required this.color,
    required this.label,
  });

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
      ..color = Colors.blueGrey.withOpacity(0.14)
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
      final normalized =
          ((values[i] - minValue) / (maxValue - minValue))
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
        ? FilledButton(
            onPressed: () => onPressed(mode),
            child: Text(label),
          )
        : OutlinedButton(
            onPressed: () => onPressed(mode),
            child: Text(label),
          );
  }
}

class _StatusLine extends StatelessWidget {
  final String label;
  final String value;

  const _StatusLine({
    required this.label,
    required this.value,
  });

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
        border: Border.all(color: color.withOpacity(0.35)),
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
