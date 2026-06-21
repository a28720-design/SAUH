import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

enum SimulationMode {
  normal,
  stress,
  critical,
  lowOxygen,
  fever,
  recovery,
  stopped,
}

class VitalSigns {
  final int heartRate;
  final int oxygen;
  final double temperature;
  final int systolicPressure;
  final int diastolicPressure;
  final int respiratoryRate;
  final String patientStatus;
  final String alertLevel;
  final DateTime measuredAt;

  const VitalSigns({
    required this.heartRate,
    required this.oxygen,
    required this.temperature,
    required this.systolicPressure,
    required this.diastolicPressure,
    required this.respiratoryRate,
    required this.patientStatus,
    required this.alertLevel,
    required this.measuredAt,
  });

  VitalSigns copyWith({
    int? heartRate,
    int? oxygen,
    double? temperature,
    int? systolicPressure,
    int? diastolicPressure,
    int? respiratoryRate,
    String? patientStatus,
    String? alertLevel,
    DateTime? measuredAt,
  }) {
    return VitalSigns(
      heartRate: heartRate ?? this.heartRate,
      oxygen: oxygen ?? this.oxygen,
      temperature: temperature ?? this.temperature,
      systolicPressure: systolicPressure ?? this.systolicPressure,
      diastolicPressure: diastolicPressure ?? this.diastolicPressure,
      respiratoryRate: respiratoryRate ?? this.respiratoryRate,
      patientStatus: patientStatus ?? this.patientStatus,
      alertLevel: alertLevel ?? this.alertLevel,
      measuredAt: measuredAt ?? this.measuredAt,
    );
  }

  Map<String, dynamic> toSupabaseMap(String patientName) {
    return {
      'patient_name': patientName,
      'heart_rate': heartRate,
      'oxygen': oxygen,
      'temperature': temperature,
      'systolic_pressure': systolicPressure,
      'diastolic_pressure': diastolicPressure,
      'respiratory_rate': respiratoryRate,
      'patient_status': patientStatus,
      'alert_level': alertLevel,
      'measured_at': measuredAt.toIso8601String(),
    };
  }
}

class SimulatorAlert {
  final String type;
  final String message;
  final String level;
  final DateTime createdAt;

  const SimulatorAlert({
    required this.type,
    required this.message,
    required this.level,
    required this.createdAt,
  });

  Map<String, dynamic> toSupabaseMap(String patientName) {
    return {
      'patient_name': patientName,
      'alert_type': type,
      'message': message,
      'level': level,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

abstract class VitalSignsPersistence {
  Future<void> saveVitals(String patientName, VitalSigns vitals);

  Future<void> saveAlert(String patientName, SimulatorAlert alert);
}

class LocalDemoVitalSignsPersistence implements VitalSignsPersistence {
  final List<Map<String, dynamic>> savedVitals = [];
  final List<Map<String, dynamic>> savedAlerts = [];

  @override
  Future<void> saveVitals(String patientName, VitalSigns vitals) async {
    savedVitals.add(vitals.toSupabaseMap(patientName));
  }

  @override
  Future<void> saveAlert(String patientName, SimulatorAlert alert) async {
    savedAlerts.add(alert.toSupabaseMap(patientName));
  }
}

class SupabaseVitalSignsPersistence implements VitalSignsPersistence {
  final dynamic client;

  const SupabaseVitalSignsPersistence(this.client);

  @override
  Future<void> saveVitals(String patientName, VitalSigns vitals) async {
    final payload = vitals.toSupabaseMap(patientName);
    await client.from('vitals_current').upsert(
          payload,
          onConflict: 'patient_name',
        );
    await client.from('vitals').insert(payload);
  }

  @override
  Future<void> saveAlert(String patientName, SimulatorAlert alert) async {
    await client.from('alerts').insert(alert.toSupabaseMap(patientName));
  }
}

class VitalSignsSimulator extends ChangeNotifier {
  VitalSignsSimulator({
    required this.patientName,
    VitalSignsPersistence? persistence,
    ValueChanged<SimulatorAlert>? onAlertCreated,
    Duration interval = const Duration(seconds: 2),
    Duration alertCooldown = const Duration(seconds: 20),
    VitalSigns? initialVitals,
  })  : _persistence = persistence ?? LocalDemoVitalSignsPersistence(),
        _onAlertCreated = onAlertCreated,
        _interval = interval,
        _alertCooldown = alertCooldown,
        _vitals = initialVitals ??
            VitalSigns(
              heartRate: 78,
              oxygen: 98,
              temperature: 36.7,
              systolicPressure: 118,
              diastolicPressure: 76,
              respiratoryRate: 16,
              patientStatus: 'Normal',
              alertLevel: 'Normal',
              measuredAt: DateTime.now(),
            );

  final String patientName;
  final VitalSignsPersistence _persistence;
  final ValueChanged<SimulatorAlert>? _onAlertCreated;
  final Duration _interval;
  final Duration _alertCooldown;
  final Random _random = Random();
  final Map<String, DateTime> _lastAlertByType = {};

  Timer? _timer;
  SimulationMode _mode = SimulationMode.stopped;
  String _lastBotAction = 'Simulacao parada. Escreve ou escolhe um modo.';
  VitalSigns _vitals;
  SimulatorAlert? _latestAlert;
  String? _lastPersistenceError;

  SimulationMode get mode => _mode;
  VitalSigns get vitals => _vitals;
  String get lastBotAction => _lastBotAction;
  SimulatorAlert? get latestAlert => _latestAlert;
  String? get lastPersistenceError => _lastPersistenceError;
  bool get isRunning => _timer?.isActive ?? false;

  void start([SimulationMode mode = SimulationMode.normal]) {
    setMode(mode);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _mode = SimulationMode.stopped;
    _lastBotAction = 'Simulacao parada.';
    notifyListeners();
  }

  void setMode(SimulationMode mode) {
    _mode = mode;
    _lastBotAction = _messageForMode(mode);

    if (mode == SimulationMode.stopped) {
      stop();
      return;
    }

    _timer ??= Timer.periodic(_interval, (_) => _tick());
    _tick();
  }

  void processSimulationCommand(String command) {
    final normalized = command.toLowerCase().trim();

    if (normalized.isEmpty) {
      _lastBotAction = 'Escreve um comando para o simulador.';
      notifyListeners();
      return;
    }

    if (_containsAny(normalized, ['critico', 'em estado critico'])) {
      setMode(SimulationMode.critical);
    } else if (_containsAny(
      normalized,
      ['falta de oxigenio', 'baixo oxigenio', 'hipoxia'],
    )) {
      setMode(SimulationMode.lowOxygen);
    } else if (_containsAny(normalized, ['febre', 'temperatura alta'])) {
      setMode(SimulationMode.fever);
    } else if (_containsAny(normalized, ['stress', 'estresse', 'ansiedade'])) {
      setMode(SimulationMode.stress);
    } else if (_containsAny(normalized, ['recuperacao', 'recuperar'])) {
      setMode(SimulationMode.recovery);
    } else if (_containsAny(normalized, ['normaliza', 'normal', 'estabiliza'])) {
      setMode(SimulationMode.normal);
    } else if (_containsAny(normalized, ['para', 'parar', 'pausa', 'stop'])) {
      setMode(SimulationMode.stopped);
    } else if (_containsAny(
      normalized,
      ['inicia', 'comeca', 'arranca', 'simulacao'],
    )) {
      setMode(SimulationMode.normal);
    } else {
      _lastBotAction = 'Nao reconheci o comando. Mantive o modo ${modeLabel(_mode)}.';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    final nextVitals = switch (_mode) {
      SimulationMode.normal => _normalVitals(),
      SimulationMode.stress => _stressVitals(),
      SimulationMode.critical => _criticalVitals(),
      SimulationMode.lowOxygen => _lowOxygenVitals(),
      SimulationMode.fever => _feverVitals(),
      SimulationMode.recovery => _recoveryVitals(),
      SimulationMode.stopped => _vitals,
    };

    _vitals = _withStatusAndAlertLevel(nextVitals);
    notifyListeners();

    await _saveVitals();
    await _createAutomaticAlerts();
  }

  Future<void> _saveVitals() async {
    try {
      await _persistence.saveVitals(patientName, _vitals);
      _lastPersistenceError = null;
    } catch (error) {
      _lastPersistenceError = 'Erro ao guardar sinais vitais: $error';
      debugPrint(_lastPersistenceError);
      notifyListeners();
    }
  }

  VitalSigns _normalVitals() {
    return _vitals.copyWith(
      heartRate: _range(65, 90),
      oxygen: _range(96, 99),
      temperature: _doubleRange(36.3, 37.2),
      systolicPressure: _range(110, 125),
      diastolicPressure: _range(70, 85),
      respiratoryRate: _range(12, 18),
      measuredAt: DateTime.now(),
    );
  }

  VitalSigns _stressVitals() {
    return _vitals.copyWith(
      heartRate: _range(90, 120),
      oxygen: _range(94, 98),
      temperature: _doubleRange(37.1, 38.0),
      systolicPressure: _range(125, 145),
      diastolicPressure: _range(82, 94),
      respiratoryRate: _range(18, 26),
      measuredAt: DateTime.now(),
    );
  }

  VitalSigns _criticalVitals() {
    return _vitals.copyWith(
      heartRate: _moveTowards(_vitals.heartRate, _range(130, 160), 6),
      oxygen: _moveTowards(_vitals.oxygen, _range(82, 90), 3),
      temperature: _moveDoubleTowards(_vitals.temperature, _doubleRange(38.5, 40.0), 0.25),
      systolicPressure: _moveTowards(_vitals.systolicPressure, _range(76, 92), 5),
      diastolicPressure: _moveTowards(_vitals.diastolicPressure, _range(45, 62), 4),
      respiratoryRate: _moveTowards(_vitals.respiratoryRate, _range(26, 34), 3),
      measuredAt: DateTime.now(),
    );
  }

  VitalSigns _lowOxygenVitals() {
    return _vitals.copyWith(
      heartRate: _moveTowards(_vitals.heartRate, _range(105, 140), 5),
      oxygen: _moveTowards(_vitals.oxygen, _range(84, 89), 3),
      temperature: _moveDoubleTowards(_vitals.temperature, _doubleRange(36.8, 37.8), 0.15),
      systolicPressure: _moveTowards(_vitals.systolicPressure, _range(100, 122), 3),
      diastolicPressure: _moveTowards(_vitals.diastolicPressure, _range(65, 82), 3),
      respiratoryRate: _moveTowards(_vitals.respiratoryRate, _range(24, 32), 3),
      measuredAt: DateTime.now(),
    );
  }

  VitalSigns _feverVitals() {
    return _vitals.copyWith(
      heartRate: _moveTowards(_vitals.heartRate, _range(88, 118), 4),
      oxygen: _moveTowards(_vitals.oxygen, _range(94, 98), 2),
      temperature: _moveDoubleTowards(_vitals.temperature, _doubleRange(38.5, 40.0), 0.25),
      systolicPressure: _moveTowards(_vitals.systolicPressure, _range(112, 132), 3),
      diastolicPressure: _moveTowards(_vitals.diastolicPressure, _range(72, 88), 3),
      respiratoryRate: _moveTowards(_vitals.respiratoryRate, _range(18, 25), 2),
      measuredAt: DateTime.now(),
    );
  }

  VitalSigns _recoveryVitals() {
    final recovered = _vitals.copyWith(
      heartRate: _moveTowards(_vitals.heartRate, 78, 4),
      oxygen: _moveTowards(_vitals.oxygen, 98, 2),
      temperature: _moveDoubleTowards(_vitals.temperature, 36.8, 0.2),
      systolicPressure: _moveTowards(_vitals.systolicPressure, 118, 4),
      diastolicPressure: _moveTowards(_vitals.diastolicPressure, 76, 3),
      respiratoryRate: _moveTowards(_vitals.respiratoryRate, 16, 2),
      measuredAt: DateTime.now(),
    );

    final isStable = (recovered.heartRate - 78).abs() <= 2 &&
        (recovered.oxygen - 98).abs() <= 1 &&
        (recovered.temperature - 36.8).abs() <= 0.2 &&
        recovered.systolicPressure >= 110;

    if (isStable) {
      _mode = SimulationMode.normal;
      _lastBotAction = 'Paciente recuperado e estabilizado.';
    }

    return recovered;
  }

  VitalSigns _withStatusAndAlertLevel(VitalSigns vitals) {
    if (vitals.heartRate > 130 ||
        vitals.oxygen < 90 ||
        vitals.temperature > 38.5 ||
        vitals.systolicPressure < 90) {
      return vitals.copyWith(patientStatus: 'Critico', alertLevel: 'Critico');
    }

    if (vitals.heartRate > 110 ||
        vitals.oxygen < 95 ||
        vitals.temperature > 37.5 ||
        vitals.respiratoryRate > 24) {
      return vitals.copyWith(patientStatus: 'Atencao', alertLevel: 'Atencao');
    }

    if (_mode == SimulationMode.recovery) {
      return vitals.copyWith(patientStatus: 'Em recuperacao', alertLevel: 'Atencao');
    }

    return vitals.copyWith(patientStatus: 'Normal', alertLevel: 'Normal');
  }

  Future<void> _createAutomaticAlerts() async {
    var createdAlert = false;
    final rules = <SimulatorAlert>[
      if (_vitals.heartRate > 130)
        SimulatorAlert(
          type: 'heart_rate',
          message: 'Batimentos acima de 130 bpm: ${_vitals.heartRate} bpm',
          level: 'Critico',
          createdAt: DateTime.now(),
        ),
      if (_vitals.oxygen < 90)
        SimulatorAlert(
          type: 'oxygen',
          message: 'Oxigenio abaixo de 90%: ${_vitals.oxygen}%',
          level: 'Critico',
          createdAt: DateTime.now(),
        ),
      if (_vitals.temperature > 38.5)
        SimulatorAlert(
          type: 'temperature',
          message: 'Temperatura acima de 38.5 C: ${_vitals.temperature.toStringAsFixed(1)} C',
          level: 'Critico',
          createdAt: DateTime.now(),
        ),
      if (_vitals.systolicPressure < 90)
        SimulatorAlert(
          type: 'systolic_pressure',
          message: 'Pressao sistolica abaixo de 90: ${_vitals.systolicPressure} mmHg',
          level: 'Critico',
          createdAt: DateTime.now(),
        ),
    ];

    for (final alert in rules) {
      final last = _lastAlertByType[alert.type];
      final canSend = last == null || DateTime.now().difference(last) >= _alertCooldown;
      if (!canSend) continue;

      _lastAlertByType[alert.type] = alert.createdAt;
      _latestAlert = alert;
      createdAlert = true;
      _onAlertCreated?.call(alert);
      await _saveAlert(alert);
    }

    if (createdAlert) notifyListeners();
  }

  Future<void> _saveAlert(SimulatorAlert alert) async {
    try {
      await _persistence.saveAlert(patientName, alert);
      _lastPersistenceError = null;
    } catch (error) {
      _lastPersistenceError = 'Erro ao guardar alerta: $error';
      debugPrint(_lastPersistenceError);
    }
  }

  bool _containsAny(String command, List<String> terms) {
    final asciiCommand = _stripAccents(command);
    return terms.any((term) => asciiCommand.contains(_stripAccents(term)));
  }

  String _messageForMode(SimulationMode mode) {
    return switch (mode) {
      SimulationMode.normal => 'Paciente normalizado.',
      SimulationMode.stress => 'A simular stress fisiologico.',
      SimulationMode.critical => 'Paciente colocado em estado critico.',
      SimulationMode.lowOxygen => 'A simular falta de oxigenio.',
      SimulationMode.fever => 'A simular febre progressiva.',
      SimulationMode.recovery => 'A iniciar recuperacao gradual.',
      SimulationMode.stopped => 'Simulacao parada.',
    };
  }

  static String modeLabel(SimulationMode mode) {
    return switch (mode) {
      SimulationMode.normal => 'Normal',
      SimulationMode.stress => 'Stress',
      SimulationMode.critical => 'Critico',
      SimulationMode.lowOxygen => 'Falta de Oxigenio',
      SimulationMode.fever => 'Febre',
      SimulationMode.recovery => 'Recuperacao',
      SimulationMode.stopped => 'Parado',
    };
  }

  int _range(int min, int max) => min + _random.nextInt(max - min + 1);

  double _doubleRange(double min, double max) {
    return double.parse((min + _random.nextDouble() * (max - min)).toStringAsFixed(1));
  }

  int _moveTowards(int current, int target, int maxStep) {
    if (current == target) return target;
    final direction = target > current ? 1 : -1;
    final distance = (target - current).abs();
    final step = min(distance, 1 + _random.nextInt(maxStep));
    return current + direction * step;
  }

  double _moveDoubleTowards(double current, double target, double maxStep) {
    final direction = target > current ? 1 : -1;
    final distance = (target - current).abs();
    if (distance <= maxStep) return double.parse(target.toStringAsFixed(1));
    final step = 0.1 + _random.nextDouble() * maxStep;
    return double.parse((current + direction * step).toStringAsFixed(1));
  }

  String _stripAccents(String value) {
    return value
        .replaceAll(RegExp('[\\u00e1\\u00e0\\u00e2\\u00e3\\u00e4]'), 'a')
        .replaceAll(RegExp('[\\u00e9\\u00e8\\u00ea\\u00eb]'), 'e')
        .replaceAll(RegExp('[\\u00ed\\u00ec\\u00ee\\u00ef]'), 'i')
        .replaceAll(RegExp('[\\u00f3\\u00f2\\u00f4\\u00f5\\u00f6]'), 'o')
        .replaceAll(RegExp('[\\u00fa\\u00f9\\u00fb\\u00fc]'), 'u')
        .replaceAll('\u00e7', 'c');
  }
}
