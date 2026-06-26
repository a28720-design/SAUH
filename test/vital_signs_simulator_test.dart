import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sauh/main.dart';
import 'package:sauh/services/auth_service.dart';
import 'package:sauh/vital_signs_simulator.dart';
import 'package:sauh/vital_signs_simulator_section.dart';

class RecordingPersistence implements VitalSignsPersistence {
  int savedVitalsCount = 0;
  final List<SimulatorAlert> savedAlerts = [];

  @override
  Future<void> saveAlert(String patientName, SimulatorAlert alert) async {
    savedAlerts.add(alert);
  }

  @override
  Future<void> saveVitals(String patientName, VitalSigns vitals) async {
    savedVitalsCount++;
  }
}

VitalSigns createVitals({
  int heartRate = 78,
  int oxygen = 98,
  double temperature = 36.7,
  int systolicPressure = 118,
  int diastolicPressure = 76,
  int respiratoryRate = 16,
}) {
  return VitalSigns(
    heartRate: heartRate,
    oxygen: oxygen,
    temperature: temperature,
    systolicPressure: systolicPressure,
    diastolicPressure: diastolicPressure,
    respiratoryRate: respiratoryRate,
    patientStatus: 'Normal',
    alertLevel: 'Normal',
    measuredAt: DateTime.now(),
  );
}

void main() {
  test('mapa da urgência apresenta cinco salas operacionais', () {
    final rooms = buildEmergencyRooms([
      Patient(
        name: 'Estável',
        age: 30,
        room: 'U01',
        careStatus: 'Estável',
        status: 'Normal',
        heartRate: 75,
        temperature: 36.7,
        oxygen: 98,
        medications: [],
        history: [],
      ),
      Patient(
        name: 'Crítico',
        age: 70,
        room: 'U03',
        careStatus: 'Crítico',
        status: 'Crítico',
        heartRate: 145,
        temperature: 39,
        oxygen: 88,
        medications: [],
        history: [],
      ),
    ]);

    expect(rooms, hasLength(5));
    expect(rooms.map((room) => room.name), containsAll(['Sala 1', 'Sala 5']));
    expect(rooms[2].status, 'Paciente crítico');
    expect(rooms[3].status, 'Livre');
  });

  test('pesquisa pacientes por utente e aplica filtros clínicos', () {
    final critical = Patient(
      name: 'Maria Crítica',
      healthNumber: '123 456 789',
      age: 70,
      room: 'Sala 3',
      careStatus: 'Crítico',
      status: 'Crítico',
      heartRate: 145,
      temperature: 39,
      oxygen: 88,
      medications: [],
      history: [],
    );
    final waiting = Patient(
      name: 'João Espera',
      healthNumber: '987 654 321',
      age: 40,
      room: 'Sala 5',
      careStatus: 'A aguardar médico',
      status: 'Normal',
      heartRate: 75,
      temperature: 36.7,
      oxygen: 98,
      medications: [
        Medication(name: 'Analgesia', time: '23:59', administered: false),
      ],
      history: [],
    );

    expect(filterPatients(source: [critical, waiting], query: '123456789'), [
      critical,
    ]);
    expect(
      filterPatients(source: [critical, waiting], query: '', onlyWaiting: true),
      [waiting],
    );
    expect(
      filterPatients(
        source: [critical, waiting],
        query: '',
        onlyCritical: true,
      ),
      [critical],
    );
  });

  test('classifica automaticamente medicação pendente e atrasada', () {
    final medication = Medication(
      name: 'Paracetamol',
      dose: '1 g',
      time: '10:00',
      administered: false,
    );

    expect(
      medication.statusAt(DateTime(2026, 1, 1, 9, 30)),
      MedicationStatus.pending,
    );
    expect(
      medication.statusAt(DateTime(2026, 1, 1, 10, 30)),
      MedicationStatus.overdue,
    );

    medication.administered = true;
    expect(
      medication.statusAt(DateTime(2026, 1, 1, 11)),
      MedicationStatus.administered,
    );
  });

  test('modo crítico altera os sinais de forma progressiva', () {
    final initialVitals = createVitals();
    final simulator = VitalSignsSimulator(
      patientName: 'Paciente',
      initialVitals: initialVitals,
      interval: const Duration(days: 1),
    );

    simulator.setMode(SimulationMode.critical);

    expect(simulator.vitals.heartRate, greaterThan(initialVitals.heartRate));
    expect(simulator.vitals.oxygen, lessThan(initialVitals.oxygen));
    expect(
      simulator.vitals.temperature,
      greaterThan(initialVitals.temperature),
    );
    expect(
      simulator.vitals.systolicPressure,
      lessThan(initialVitals.systolicPressure),
    );

    simulator.dispose();
  });

  test('interpreta os comandos de simulação pedidos', () {
    final simulator = VitalSignsSimulator(
      patientName: 'Paciente',
      interval: const Duration(days: 1),
    );
    final commands = <String, SimulationMode>{
      'mete o paciente em estado crítico': SimulationMode.critical,
      'simula febre': SimulationMode.fever,
      'simula falta de oxigénio': SimulationMode.lowOxygen,
      'normaliza o paciente': SimulationMode.normal,
      'recuperação': SimulationMode.recovery,
      'para a simulação': SimulationMode.stopped,
      'inicia simulação': SimulationMode.normal,
    };

    for (final command in commands.entries) {
      simulator.processSimulationCommand(command.key);
      expect(simulator.mode, command.value, reason: command.key);
    }

    simulator.dispose();
  });

  test('aplica cooldown aos alertas automáticos', () async {
    final persistence = RecordingPersistence();
    final createdAlerts = <SimulatorAlert>[];
    final simulator = VitalSignsSimulator(
      patientName: 'Paciente',
      persistence: persistence,
      initialVitals: createVitals(
        heartRate: 140,
        oxygen: 88,
        temperature: 39,
        systolicPressure: 85,
      ),
      interval: const Duration(days: 1),
      alertCooldown: const Duration(minutes: 1),
      onAlertCreated: createdAlerts.add,
    );

    simulator.setMode(SimulationMode.critical);
    await pumpEventQueue();
    simulator.setMode(SimulationMode.critical);
    await pumpEventQueue();

    expect(createdAlerts, hasLength(4));
    expect(persistence.savedAlerts, hasLength(4));

    simulator.dispose();
  });

  test('limita a persistência dos sinais vitais', () async {
    final persistence = RecordingPersistence();
    final simulator = VitalSignsSimulator(
      patientName: 'Paciente',
      persistence: persistence,
      interval: const Duration(days: 1),
      persistenceInterval: const Duration(seconds: 5),
    );

    simulator.setMode(SimulationMode.normal);
    await pumpEventQueue();
    simulator.setMode(SimulationMode.stress);
    await pumpEventQueue();

    expect(persistence.savedVitalsCount, 1);

    simulator.dispose();
  });

  testWidgets('mostra os controlos e sinais vitais do simulador', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VitalSignsSimulatorSection(
              patientName: 'Paciente',
              initialVitals: createVitals(),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Paciente'), findsOneWidget);
    expect(find.text('Simulador Inteligente de Sinais Vitais'), findsNothing);
    expect(find.text('Iniciar Simulação'), findsOneWidget);
    expect(find.text('Comando tipo IA'), findsNothing);
    expect(find.text('Enviar comando'), findsNothing);
    expect(find.text('Nível de Alerta'), findsOneWidget);
    expect(find.text('Silenciar 2 min'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mostra motivo, hora e profissional que confirma o alerta', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VitalSignsSimulatorSection(
              patientName: 'Paciente crítico',
              professionalName: 'Dra. Teste',
              initialVitals: createVitals(
                heartRate: 140,
                oxygen: 88,
                temperature: 39,
                systolicPressure: 85,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('Motivo:'), findsOneWidget);
    expect(find.textContaining('Hora exata:'), findsOneWidget);
    expect(find.text('Confirmar alerta'), findsOneWidget);

    await tester.ensureVisible(find.text('Confirmar alerta'));
    await tester.pump();
    await tester.tap(find.text('Confirmar alerta'));
    await tester.pump();

    expect(find.text('Confirmado por: Dra. Teste'), findsOneWidget);
  });

  testWidgets('menu lateral apresenta as páginas principais', (tester) async {
    final login = authService.signIn('admin@hospitalcentral.pt', 'admin123');
    syncAccountProfileFromUser(login.user!);
    addTearDown(authService.signOut);

    final scaffoldKey = GlobalKey<ScaffoldState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          key: scaffoldKey,
          appBar: AppBar(),
          drawer: const SAUHDrawer(currentPage: 'Painel'),
        ),
      ),
    );

    scaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();

    expect(find.text('Painel'), findsOneWidget);
    expect(find.text('Pacientes'), findsOneWidget);
    expect(find.text('Mapa da Urgência'), findsOneWidget);
    expect(find.text('Alertas'), findsOneWidget);
    expect(find.text('Adicionar Paciente'), findsOneWidget);
    expect(find.text('Editar Conta'), findsOneWidget);
    expect(find.text('Sair'), findsOneWidget);
  });

  testWidgets('ficha do paciente apresenta informação clínica completa', (
    tester,
  ) async {
    final login = authService.signIn('admin@hospitalcentral.pt', 'admin123');
    syncAccountProfileFromUser(login.user!);
    addTearDown(authService.signOut);

    await tester.binding.setSurfaceSize(const Size(1200, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final patient = Patient(
      name: 'Paciente Teste',
      age: 52,
      room: 'U01',
      status: 'Atenção',
      heartRate: 105,
      temperature: 37.8,
      oxygen: 94,
      gender: 'Feminino',
      contact: '910 000 000',
      admissionReason: 'Dor abdominal',
      symptoms: ['Dor', 'Náuseas'],
      allergies: ['Penicilina'],
      usualMedication: 'Medicação habitual',
      medicalHistory: 'Hipertensão',
      triageLevel: 'Amarelo',
      medicalNotes: 'Em observação.',
      medications: [
        Medication(
          name: 'Penicilina',
          dose: '500 mg',
          time: '08:00',
          responsibleProfessional: 'Enf. Teste',
          administered: false,
        ),
      ],
      history: [
        ClinicalRecord(
          description: 'Paciente registado.',
          dateTime: '01/01/2026 10:00',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: PatientDetailsPage(patient: patient)),
    );

    expect(find.text('Dados pessoais'), findsOneWidget);
    expect(find.text('Admissão e triagem'), findsOneWidget);
    expect(find.text('Informação clínica'), findsOneWidget);
    expect(find.text('Sinais vitais atuais'), findsOneWidget);
    expect(find.text('Observações da equipa médica'), findsOneWidget);
    expect(find.text('Histórico de alterações'), findsOneWidget);
    expect(find.text('Editar Ficha Clínica'), findsOneWidget);
    expect(
      find.text('Atenção: este paciente tem alergia registada a Penicilina.'),
      findsOneWidget,
    );
    expect(find.text('Dose: 500 mg'), findsOneWidget);
    expect(find.textContaining('Estado:'), findsOneWidget);
  });
}
