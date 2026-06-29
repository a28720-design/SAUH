import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/app_role.dart';
import 'models/app_user.dart';
import 'models/hospital.dart';
import 'services/auth_service.dart';
import 'services/hospital_service.dart';
import 'services/permission_service.dart';
import 'services/supabase_account_service.dart';
import 'vital_signs_simulator.dart';
import 'vital_signs_simulator_section.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://mdhycsmxgaqnrvbqmazd.supabase.co',
    anonKey: 'sb_publishable_iNXLMuZS2kfpjg5_KI7lOw_LyiVvOhD',
  );
  await clearExpiredSupabaseSession();

  runApp(const SAUHApp());
}

final supabase = Supabase.instance.client;
const sauhLogoAsset = 'assets/images/3.png';
const sauhDrawerLogoAsset = 'assets/images/4.png';

Future<void> clearExpiredSupabaseSession() async {
  final session = supabase.auth.currentSession;
  if (session == null || !session.isExpired) return;

  try {
    await supabase.auth.signOut(scope: SignOutScope.local);
  } catch (error) {
    debugPrint('Sessão Supabase expirada removida localmente: $error');
  }
}

class SAUHApp extends StatelessWidget {
  const SAUHApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAUH',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LoginPage(),
    );
  }
}

Widget dashboardForUser(AppUser user) {
  return switch (user.role) {
    AppRole.superAdmin => const SuperAdminDashboard(),
    AppRole.adminHospital => const AdminHospitalDashboard(),
    AppRole.diretorClinico => const DiretorClinicoDashboard(),
    AppRole.chefeEnfermagem => const ChefeEnfermagemDashboard(),
    AppRole.medico => const MedicoDashboard(),
    AppRole.enfermeiro => const EnfermeiroDashboard(),
    AppRole.triagem => const TriagemDashboard(),
    AppRole.tecnicoEmergencia => const TecnicoEmergenciaDashboard(),
    AppRole.administrativo => const AdministrativoDashboard(),
    AppRole.auxiliar => const AuxiliarDashboard(),
  };
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    setState(() {
      isLoading = true;
    });

    final result = await authService.signInWithSupabaseOrLocal(
      supabase,
      emailController.text,
      passwordController.text,
    );

    if (!mounted) return;
    setState(() {
      isLoading = false;
    });

    if (!result.isSuccess) {
      final message = result.error ?? 'Não foi possível iniciar sessão.';
      if (message.toLowerCase().contains('inativ') ||
          message.toLowerCase().contains('hospital')) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AccessDeniedPage(reason: message)),
        );
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    final user = result.user!;
    syncAccountProfileFromUser(user);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => dashboardForUser(user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FF),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                ),
                child: Center(
                  child: Container(
                    width: 350,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 12),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          sauhLogoAsset,
                          width: 280,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 25),

                        TextField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(height: 15),

                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Palavra-passe',
                            border: OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : login,
                            child: Text(isLoading ? 'A entrar...' : 'Entrar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ClinicalRecord {
  final String description;
  final String dateTime;

  ClinicalRecord({required this.description, required this.dateTime});
}

class AccountProfile {
  String userId = '';
  String name = '';
  String email = '';
  String phone = '';
  String role = '';
  String hospitalId = '';
  String professionalId = '';
  String department = '';
  String avatarUrl = '';
}

final accountProfile = AccountProfile();

void syncAccountProfileFromUser(AppUser user) {
  accountProfile
    ..userId = user.userId
    ..name = user.name
    ..email = user.email
    ..role = user.role.label
    ..hospitalId = user.hospitalId ?? ''
    ..department = user.department;
}

AppUser? get currentAppUser => authService.currentUser;

Hospital? get currentHospital {
  return hospitalService.byId(currentAppUser?.hospitalId);
}

String defaultHospitalId() {
  return currentAppUser?.hospitalId ?? 'hospital-central';
}

bool hasPermission(AppPermission permission) {
  return PermissionService.can(currentAppUser, permission);
}

String? currentSupabaseAuthUserId() {
  try {
    return Supabase.instance.client.auth.currentUser?.id;
  } catch (_) {
    return null;
  }
}

enum MedicationStatus { pending, administered, overdue }

class Medication {
  String? id;
  String? patientId;
  String name;
  String time;
  String dose;
  String responsibleProfessional;
  MedicationStatus status;

  Medication({
    this.id,
    this.patientId,
    required this.name,
    required this.time,
    this.dose = 'Não indicada',
    this.responsibleProfessional = 'Por atribuir',
    required bool administered,
  }) : status = administered
           ? MedicationStatus.administered
           : MedicationStatus.pending;

  bool get administered => status == MedicationStatus.administered;

  set administered(bool value) {
    status = value ? MedicationStatus.administered : MedicationStatus.pending;
  }

  MedicationStatus statusAt(DateTime now) {
    if (administered) return MedicationStatus.administered;

    final parts = time.split(':');
    if (parts.length != 2) return MedicationStatus.pending;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return MedicationStatus.pending;
    }

    final scheduledAt = DateTime(now.year, now.month, now.day, hour, minute);
    return now.isAfter(scheduledAt)
        ? MedicationStatus.overdue
        : MedicationStatus.pending;
  }
}

String medicationStatusLabel(MedicationStatus status) {
  return switch (status) {
    MedicationStatus.pending => 'Pendente',
    MedicationStatus.administered => 'Administrado',
    MedicationStatus.overdue => 'Atrasado',
  };
}

Color medicationStatusColor(MedicationStatus status) {
  return switch (status) {
    MedicationStatus.pending => Colors.orange,
    MedicationStatus.administered => Colors.green,
    MedicationStatus.overdue => Colors.red,
  };
}

class Patient {
  final String? id;
  final String name;
  final int age;
  final String room;
  String hospitalId;
  String healthNumber;
  String careStatus;
  String status;
  int heartRate;
  double temperature;
  int oxygen;
  int systolicPressure;
  int diastolicPressure;
  int respiratoryRate;
  String alertLevel;
  String gender;
  String contact;
  String admissionReason;
  final List<String> symptoms;
  final List<String> allergies;
  String usualMedication;
  String medicalHistory;
  String triageLevel;
  String medicalNotes;
  String? medicoResponsavelAuthUserId;
  String? createdByAuthUserId;
  bool active;
  final List<Medication> medications;
  final List<ClinicalRecord> history;

  Patient({
    this.id,
    required this.name,
    required this.age,
    required this.room,
    this.hospitalId = 'hospital-central',
    this.healthNumber = 'Não indicado',
    this.careStatus = 'Em observação',
    required this.status,
    required this.heartRate,
    required this.temperature,
    required this.oxygen,
    this.systolicPressure = 118,
    this.diastolicPressure = 76,
    this.respiratoryRate = 16,
    this.alertLevel = 'Normal',
    this.gender = 'Não indicado',
    this.contact = 'Não indicado',
    this.admissionReason = 'Avaliação clínica',
    List<String>? symptoms,
    List<String>? allergies,
    this.usualMedication = 'Não indicada',
    this.medicalHistory = 'Sem antecedentes registados',
    this.triageLevel = 'Amarelo',
    this.medicalNotes = 'Sem observações registadas',
    this.medicoResponsavelAuthUserId,
    this.createdByAuthUserId,
    this.active = true,
    required this.medications,
    required this.history,
  }) : symptoms = symptoms ?? [],
       allergies = allergies ?? [];
}

List<String> medicationAllergyMatches(Patient patient, Medication medication) {
  final medicationName = medication.name.toLowerCase();
  return patient.allergies.where((allergy) {
    final normalizedAllergy = allergy.toLowerCase().trim();
    return normalizedAllergy.isNotEmpty &&
        (medicationName.contains(normalizedAllergy) ||
            normalizedAllergy.contains(medicationName));
  }).toList();
}

class PatientVitalSignsPersistence implements VitalSignsPersistence {
  final Patient patient;
  final SupabaseClient client;

  const PatientVitalSignsPersistence({
    required this.patient,
    required this.client,
  });

  @override
  Future<void> saveVitals(String patientName, VitalSigns vitals) async {
    if (patient.id == null) return;

    await _runWithValidSession(() async {
      await client
          .from('patients')
          .update({
            'estado_clinico': vitals.patientStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', patient.id!);
    });
  }

  @override
  Future<void> saveAlert(String patientName, SimulatorAlert alert) async {
    if (patient.id == null) return;

    await _runWithValidSession(() async {
      await client.from('clinical_history').insert({
        'patient_id': patient.id,
        'description':
            'Alerta automático. Motivo: ${alert.message}. Nível: ${alert.level}.',
        'date_time': formatExactDateTime(alert.createdAt),
      });
    });
  }

  Future<void> saveAlertConfirmation(
    SimulatorAlert alert,
    String professional,
    DateTime confirmedAt,
  ) async {
    if (patient.id == null) return;

    await _runWithValidSession(() async {
      await client.from('clinical_history').insert({
        'patient_id': patient.id,
        'description':
            'Alerta confirmado por $professional. Motivo: ${alert.message}.',
        'date_time': formatExactDateTime(confirmedAt),
      });
    });
  }

  Future<void> _runWithValidSession(Future<void> Function() operation) async {
    try {
      await operation();
    } on PostgrestException catch (error) {
      if (error.code != 'PGRST303') rethrow;

      try {
        await client.auth.signOut(scope: SignOutScope.local);
      } catch (signOutError) {
        debugPrint('Erro ao limpar sessão Supabase: $signOutError');
      }
      await operation();
    }
  }
}

String getCurrentDateTime() {
  final now = DateTime.now();

  return '${now.day.toString().padLeft(2, '0')}/'
      '${now.month.toString().padLeft(2, '0')}/'
      '${now.year} '
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}';
}

String formatExactDateTime(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}:'
      '${value.second.toString().padLeft(2, '0')}';
}

String currentProfessionalName() {
  final localName = accountProfile.name.trim();
  if (localName.isNotEmpty) return localName;

  final user = supabase.auth.currentUser;
  final metadataName =
      user?.userMetadata?['full_name']?.toString().trim() ?? '';
  if (metadataName.isNotEmpty) return metadataName;
  if ((user?.email ?? '').isNotEmpty) return user!.email!;
  return 'Profissional SAUH';
}

final patients = <Patient>[];

List<Patient> visiblePatientsForCurrentUser() {
  final user = currentAppUser;
  if (user == null) return const [];
  final authUserId = currentSupabaseAuthUserId();
  if (user.role == AppRole.superAdmin || user.role == AppRole.adminHospital) {
    return patients;
  }
  if (!hasPermission(AppPermission.viewPatients) &&
      !hasPermission(AppPermission.viewLimitedData)) {
    return const [];
  }
  final hospitalPatients = patients
      .where((patient) => patient.hospitalId == user.hospitalId)
      .toList();
  if (user.role == AppRole.medico && authUserId != null) {
    return hospitalPatients
        .where((patient) => patient.medicoResponsavelAuthUserId == authUserId)
        .toList();
  }
  return hospitalPatients;
}

bool canUsePatient(Patient patient, AppPermission permission) {
  final user = currentAppUser;
  final authUserId = currentSupabaseAuthUserId();
  if ((user?.role == AppRole.superAdmin ||
          user?.role == AppRole.adminHospital) &&
      PermissionService.can(user, permission)) {
    return true;
  }
  if (user?.role == AppRole.medico &&
      authUserId != null &&
      patient.medicoResponsavelAuthUserId != authUserId) {
    return false;
  }
  return hasPermission(permission) &&
      PermissionService.canAccessHospital(user, patient.hospitalId);
}

bool canDeletePatient(Patient patient) {
  return canUsePatient(patient, AppPermission.deletePatient);
}

bool canDeleteMedication(Patient patient) {
  return canUsePatient(patient, AppPermission.deleteMedication);
}

String _stringFromMap(
  Map<String, dynamic> row,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = row[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

String? _nullableStringFromMap(Map<String, dynamic> row, List<String> keys) {
  final value = _stringFromMap(row, keys);
  return value.isEmpty ? null : value;
}

int _intFromMap(
  Map<String, dynamic> row,
  List<String> keys, {
  required int fallback,
}) {
  final value = _stringFromMap(row, keys);
  return int.tryParse(value) ?? fallback;
}

double _doubleFromMap(
  Map<String, dynamic> row,
  List<String> keys, {
  required double fallback,
}) {
  final value = _stringFromMap(row, keys).replaceAll(',', '.');
  return double.tryParse(value) ?? fallback;
}

bool _boolFromMap(
  Map<String, dynamic> row,
  List<String> keys, {
  required bool fallback,
}) {
  for (final key in keys) {
    final value = row[key];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
  }
  return fallback;
}

Patient patientFromSupabaseMap(
  Map<String, dynamic> row, {
  List<Medication> medications = const [],
  List<ClinicalRecord> history = const [],
}) {
  final hospitalValue = _nullableStringFromMap(row, [
    'hospital',
    'hospital_id',
  ]);
  final hospitalId =
      hospitalService.normalizeHospitalId(hospitalValue) ??
      hospitalValue ??
      defaultHospitalId();
  final status = _stringFromMap(row, [
    'estado_clinico',
    'status',
  ], fallback: 'Normal');

  return Patient(
    id: _nullableStringFromMap(row, ['id']),
    name: _stringFromMap(row, ['nome', 'name'], fallback: 'Sem nome'),
    age: _intFromMap(row, ['idade', 'age'], fallback: 0),
    room: _stringFromMap(row, [
      'cama',
      'sala',
      'room',
      'departamento',
    ], fallback: 'Cama por atribuir'),
    hospitalId: hospitalId,
    healthNumber: _stringFromMap(row, [
      'numero_processo',
      'health_number',
    ], fallback: 'Não indicado'),
    careStatus: _stringFromMap(row, [
      'estado_assistencial',
      'care_status',
      'prioridade',
    ], fallback: 'Em observação'),
    status: status,
    heartRate: _intFromMap(row, ['heart_rate'], fallback: 78),
    temperature: _doubleFromMap(row, ['temperature'], fallback: 36.7),
    oxygen: _intFromMap(row, ['oxygen'], fallback: 98),
    gender: _stringFromMap(row, ['genero'], fallback: 'Não indicado'),
    admissionReason: _stringFromMap(row, [
      'motivo_entrada',
    ], fallback: 'Avaliação clínica'),
    triageLevel: _stringFromMap(row, ['prioridade'], fallback: 'Amarelo'),
    medicoResponsavelAuthUserId: _nullableStringFromMap(row, [
      'medico_responsavel_auth_user_id',
    ]),
    createdByAuthUserId: _nullableStringFromMap(row, [
      'created_by_auth_user_id',
    ]),
    active: _boolFromMap(row, ['ativo'], fallback: true),
    medications: medications,
    history: history,
  );
}

Medication medicationFromSupabaseMap(Map<String, dynamic> row) {
  return Medication(
    id: _nullableStringFromMap(row, ['id']),
    patientId: _nullableStringFromMap(row, ['patient_id']),
    name: _stringFromMap(row, ['name', 'nome'], fallback: 'Medicação'),
    time: _stringFromMap(row, ['time', 'hora'], fallback: '00:00'),
    dose: _stringFromMap(row, ['dose'], fallback: 'Não indicada'),
    responsibleProfessional: _stringFromMap(row, [
      'responsible_professional',
      'profissional_responsavel',
    ], fallback: 'Por atribuir'),
    administered: _boolFromMap(row, [
      'administered',
      'administrado',
    ], fallback: false),
  );
}

Map<String, dynamic> medicationToSupabaseMap(
  Medication medication, {
  required String patientId,
  bool includeCreator = false,
}) {
  final data = <String, dynamic>{
    'patient_id': patientId,
    'name': medication.name.trim(),
    'dose': medication.dose.trim(),
    'time': medication.time.trim(),
    'responsible_professional': medication.responsibleProfessional.trim(),
    'administered': medication.administered,
  };
  if (includeCreator) {
    final authUserId = currentSupabaseAuthUserId();
    if (authUserId != null && authUserId.isNotEmpty) {
      data['created_by_auth_user_id'] = authUserId;
    }
  }
  return data;
}

Future<List<Patient>> fetchPatientsFromSupabase() async {
  final patientRows = await supabase
      .from('patients')
      .select()
      .eq('ativo', true)
      .order('created_at', ascending: false);

  final loadedPatients = <Patient>[];
  for (final row in patientRows) {
    final patientId = row['id'];
    final medicationRows = await supabase
        .from('medications')
        .select()
        .eq('patient_id', patientId)
        .order('created_at', ascending: true);
    final historyRows = await supabase
        .from('clinical_history')
        .select()
        .eq('patient_id', patientId)
        .order('created_at', ascending: true);

    loadedPatients.add(
      patientFromSupabaseMap(
        row,
        medications: medicationRows
            .map<Medication>(medicationFromSupabaseMap)
            .toList(),
        history: historyRows.map<ClinicalRecord>((historyData) {
          return ClinicalRecord(
            description:
                historyData['description']?.toString() ?? 'Registo clínico',
            dateTime: historyData['date_time']?.toString() ?? '',
          );
        }).toList(),
      ),
    );
  }
  return loadedPatients;
}

Future<void> refreshPatientsCacheFromSupabase() async {
  final loadedPatients = await fetchPatientsFromSupabase();
  patients
    ..clear()
    ..addAll(loadedPatients);
}

Future<void> deletePatientFromSupabase(Patient patient) async {
  if (!canDeletePatient(patient)) {
    throw StateError('Sem permissão para apagar este paciente.');
  }
  if (patient.id == null || patient.id!.isEmpty) {
    throw StateError('Paciente sem ID Supabase.');
  }

  await supabase.from('patients').delete().eq('id', patient.id!);
  patients.removeWhere((item) => item.id == patient.id);
}

Future<void> updatePatientRecordInSupabase(Patient patient) async {
  if (patient.id == null || patient.id!.isEmpty) return;

  await supabase
      .from('patients')
      .update({
        'numero_processo': patient.healthNumber,
        'genero': patient.gender,
        'motivo_entrada': patient.admissionReason,
        'estado_clinico': patient.status,
        'prioridade': patient.careStatus,
        'departamento': patient.room,
        'ativo': patient.active,
      })
      .eq('id', patient.id!);
}

Future<Medication> insertMedicationInSupabase(
  Patient patient,
  Medication medication,
) async {
  if (patient.id == null || patient.id!.isEmpty) {
    throw StateError('Paciente sem ID Supabase.');
  }

  final insertedMedication = await supabase
      .from('medications')
      .insert(
        medicationToSupabaseMap(
          medication,
          patientId: patient.id!,
          includeCreator: true,
        ),
      )
      .select()
      .single();

  return medicationFromSupabaseMap(insertedMedication);
}

Future<void> updateMedicationInSupabase(
  Patient patient,
  Medication medication,
) async {
  if (patient.id == null || patient.id!.isEmpty) {
    throw StateError('Paciente sem ID Supabase.');
  }
  if (medication.id == null || medication.id!.isEmpty) return;

  await supabase
      .from('medications')
      .update(medicationToSupabaseMap(medication, patientId: patient.id!))
      .eq('id', medication.id!)
      .eq('patient_id', patient.id!);
}

Future<void> deleteMedicationFromSupabase(
  Patient patient,
  Medication medication,
) async {
  if (!canDeleteMedication(patient)) {
    throw StateError('Sem permissão para apagar medicação.');
  }
  if (patient.id == null || patient.id!.isEmpty) {
    throw StateError('Paciente sem ID Supabase.');
  }
  if (medication.id == null || medication.id!.isEmpty) {
    throw StateError('Medicação sem ID Supabase.');
  }

  await supabase
      .from('medications')
      .delete()
      .eq('id', medication.id!)
      .eq('patient_id', patient.id!);
  patient.medications.removeWhere((item) => item.id == medication.id);
}

class PatientAlert {
  final String patientName;
  final String message;
  final String level;

  PatientAlert({
    required this.patientName,
    required this.message,
    required this.level,
  });
}

class ClinicalAlertRecord {
  final Patient patient;
  final SimulatorAlert alert;
  DateTime? confirmedAt;
  String? confirmedBy;

  ClinicalAlertRecord({required this.patient, required this.alert});

  bool get isConfirmed => confirmedAt != null;
}

final clinicalAlertRecords = <ClinicalAlertRecord>[];

List<PatientAlert> generateAlerts() {
  final alerts = <PatientAlert>[];
  final now = DateTime.now();

  for (final patient in visiblePatientsForCurrentUser()) {
    if (patient.heartRate > 140) {
      alerts.add(
        PatientAlert(
          patientName: patient.name,
          message: 'Frequência cardíaca crítica: ${patient.heartRate} bpm',
          level: 'Crítico',
        ),
      );
    } else if (patient.heartRate > 120) {
      alerts.add(
        PatientAlert(
          patientName: patient.name,
          message: 'Frequência cardíaca elevada: ${patient.heartRate} bpm',
          level: 'Atenção',
        ),
      );
    }

    if (patient.oxygen < 90) {
      alerts.add(
        PatientAlert(
          patientName: patient.name,
          message: 'Oxigénio crítico: ${patient.oxygen}%',
          level: 'Crítico',
        ),
      );
    } else if (patient.oxygen < 95) {
      alerts.add(
        PatientAlert(
          patientName: patient.name,
          message: 'Oxigénio abaixo do normal: ${patient.oxygen}%',
          level: 'Atenção',
        ),
      );
    }

    if (patient.temperature > 38.5) {
      alerts.add(
        PatientAlert(
          patientName: patient.name,
          message: 'Temperatura elevada: ${patient.temperature} ºC',
          level: 'Crítico',
        ),
      );
    } else if (patient.temperature > 37.5) {
      alerts.add(
        PatientAlert(
          patientName: patient.name,
          message: 'Febre ligeira: ${patient.temperature} ºC',
          level: 'Atenção',
        ),
      );
    }

    if (patient.systolicPressure < 90) {
      alerts.add(
        PatientAlert(
          patientName: patient.name,
          message:
              'Pressão sistólica perigosa: ${patient.systolicPressure} mmHg',
          level: 'Crítico',
        ),
      );
    }

    for (final medication in patient.medications) {
      final medicationStatus = medication.statusAt(now);
      if (medicationStatus == MedicationStatus.overdue) {
        alerts.add(
          PatientAlert(
            patientName: patient.name,
            message:
                'Medicação atrasada: ${medication.name} ${medication.dose} estava prevista para ${medication.time}',
            level: 'Crítico',
          ),
        );
      } else if (medicationStatus == MedicationStatus.pending) {
        alerts.add(
          PatientAlert(
            patientName: patient.name,
            message:
                'Medicação pendente: ${medication.name} ${medication.dose} às ${medication.time}',
            level: 'Atenção',
          ),
        );
      }

      final allergyMatches = medicationAllergyMatches(patient, medication);
      if (allergyMatches.isNotEmpty) {
        alerts.add(
          PatientAlert(
            patientName: patient.name,
            message:
                'Risco de alergia: ${medication.name} corresponde a ${allergyMatches.join(', ')}',
            level: 'Crítico',
          ),
        );
      }
    }
  }

  return alerts;
}

String calculatePatientStatus(int heartRate, double temperature, int oxygen) {
  if (heartRate > 140 ||
      heartRate < 50 ||
      oxygen < 90 ||
      temperature > 38.5 ||
      temperature < 35) {
    return 'Crítico';
  }

  if (heartRate > 120 || oxygen < 95 || temperature > 37.5) {
    return 'Atenção';
  }

  return 'Normal';
}

Color patientStatusColor(String status) {
  if (status == 'Crítico') return Colors.red;
  if (status == 'Atenção' || status == 'Em recuperação') {
    return Colors.orange;
  }
  return Colors.green;
}

bool isCriticalPatient(Patient patient) {
  return patient.status == 'Crítico' || patient.alertLevel == 'Crítico';
}

bool hasPendingMedication(Patient patient, DateTime now) {
  return patient.medications.any(
    (medication) => medication.statusAt(now) != MedicationStatus.administered,
  );
}

bool hasActivePatientAlert(Patient patient, DateTime now) {
  if (patient.heartRate > 120 ||
      patient.oxygen < 95 ||
      patient.temperature > 37.5 ||
      patient.systolicPressure < 90) {
    return true;
  }

  return patient.medications.any((medication) {
    return medication.statusAt(now) != MedicationStatus.administered ||
        medicationAllergyMatches(patient, medication).isNotEmpty;
  });
}

List<Patient> filterPatients({
  required Iterable<Patient> source,
  required String query,
  bool onlyCritical = false,
  bool onlyWaiting = false,
  bool onlyPendingMedication = false,
  bool onlyActiveAlerts = false,
  DateTime? now,
}) {
  final normalizedQuery = query.toLowerCase().trim();
  final compactQuery = normalizedQuery.replaceAll(' ', '');
  final referenceTime = now ?? DateTime.now();

  return source.where((patient) {
    final healthNumber = patient.healthNumber.toLowerCase();
    final matchesQuery =
        normalizedQuery.isEmpty ||
        patient.name.toLowerCase().contains(normalizedQuery) ||
        healthNumber.contains(normalizedQuery) ||
        healthNumber.replaceAll(' ', '').contains(compactQuery) ||
        patient.room.toLowerCase().contains(normalizedQuery) ||
        patient.status.toLowerCase().contains(normalizedQuery) ||
        patient.careStatus.toLowerCase().contains(normalizedQuery);
    if (!matchesQuery) return false;
    if (onlyCritical && !isCriticalPatient(patient)) return false;
    if (onlyWaiting &&
        !patient.careStatus.toLowerCase().contains('aguardar') &&
        !patient.careStatus.toLowerCase().contains('espera')) {
      return false;
    }
    if (onlyPendingMedication &&
        !hasPendingMedication(patient, referenceTime)) {
      return false;
    }
    if (onlyActiveAlerts && !hasActivePatientAlert(patient, referenceTime)) {
      return false;
    }
    return true;
  }).toList();
}

class EmergencyRoomData {
  final String name;
  final String status;
  final Patient? patient;
  final Color color;
  final IconData icon;

  const EmergencyRoomData({
    required this.name,
    required this.status,
    required this.patient,
    required this.color,
    required this.icon,
  });
}

List<EmergencyRoomData> buildEmergencyRooms(Iterable<Patient> source) {
  final available = source.toList();

  Patient? takePatient(bool Function(Patient patient) predicate) {
    final index = available.indexWhere(predicate);
    if (index < 0) return null;
    return available.removeAt(index);
  }

  final stable = takePatient(
    (patient) => patient.status == 'Normal' || patient.careStatus == 'Estável',
  );
  final observation = takePatient(
    (patient) =>
        patient.careStatus == 'Em observação' || patient.status == 'Atenção',
  );
  final critical = takePatient(isCriticalPatient);
  final waiting = takePatient(
    (patient) =>
        patient.careStatus.toLowerCase().contains('aguardar') ||
        patient.careStatus.toLowerCase().contains('espera'),
  );

  return [
    EmergencyRoomData(
      name: 'Cama 1',
      status: 'Paciente estável',
      patient: stable,
      color: Colors.green,
      icon: Icons.check_circle,
    ),
    EmergencyRoomData(
      name: 'Cama 2',
      status: 'Paciente em observação',
      patient: observation,
      color: Colors.orange,
      icon: Icons.visibility,
    ),
    EmergencyRoomData(
      name: 'Cama 3',
      status: 'Paciente crítico',
      patient: critical,
      color: Colors.red,
      icon: Icons.emergency,
    ),
    const EmergencyRoomData(
      name: 'Cama 4',
      status: 'Livre',
      patient: null,
      color: Colors.blue,
      icon: Icons.bed,
    ),
    EmergencyRoomData(
      name: 'Cama 5',
      status: 'A aguardar médico',
      patient: waiting,
      color: Colors.amber,
      icon: Icons.hourglass_top,
    ),
  ];
}

class EmergencyMapSection extends StatelessWidget {
  final ValueChanged<Patient>? onPatientSelected;

  const EmergencyMapSection({super.key, this.onPatientSelected});

  @override
  Widget build(BuildContext context) {
    final rooms = buildEmergencyRooms(visiblePatientsForCurrentUser());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mapa da Urgência',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final room in rooms)
              SizedBox(
                width: 220,
                child: Card(
                  color: room.color.withValues(alpha: 0.12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: room.patient == null || onPatientSelected == null
                        ? null
                        : () => onPatientSelected!(room.patient!),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(room.icon, color: room.color, size: 30),
                          const SizedBox(height: 10),
                          Text(
                            room.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            room.status,
                            style: TextStyle(
                              color: room.color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(room.patient?.name ?? 'Sem paciente atribuído'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class SAUHDrawer extends StatelessWidget {
  final String currentPage;

  const SAUHDrawer({super.key, required this.currentPage});

  void _replacePage(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final user = currentAppUser;
    final canViewPatients =
        hasPermission(AppPermission.viewPatients) ||
        hasPermission(AppPermission.viewLimitedData);

    return Drawer(
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              DrawerHeader(
                child: Center(
                  child: Image.asset(
                    sauhDrawerLogoAsset,
                    width: 220,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              ListTile(
                selected: currentPage == 'Painel',
                leading: const Icon(Icons.dashboard),
                title: const Text('Painel'),
                onTap: () => _replacePage(
                  context,
                  user == null ? const LoginPage() : dashboardForUser(user),
                ),
              ),
              if (hasPermission(AppPermission.viewPatients))
                ListTile(
                  selected: currentPage == 'Simuladores',
                  leading: const Icon(Icons.monitor_heart),
                  title: const Text('Simuladores'),
                  onTap: () => _replacePage(context, const DashboardPage()),
                ),
              if (canViewPatients)
                ListTile(
                  selected: currentPage == 'Pacientes',
                  leading: const Icon(Icons.people),
                  title: const Text('Pacientes'),
                  onTap: () => _replacePage(context, const PatientsPage()),
                ),
              ListTile(
                selected: currentPage == 'Mapa da Urgência',
                leading: const Icon(Icons.map),
                title: const Text('Mapa da Urgência'),
                onTap: () => _replacePage(context, const EmergencyMapPage()),
              ),
              if (hasPermission(AppPermission.viewPatients))
                ListTile(
                  selected: currentPage == 'Alertas',
                  leading: const Icon(Icons.warning),
                  title: const Text('Alertas'),
                  onTap: () => _replacePage(context, const AlertsPage()),
                ),
              if (hasPermission(AppPermission.createPatient))
                ListTile(
                  selected: currentPage == 'Adicionar Paciente',
                  leading: const Icon(Icons.person_add),
                  title: const Text('Adicionar Paciente'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddPatientPage()),
                    );
                  },
                ),
              if (hasPermission(AppPermission.registerHospital))
                ListTile(
                  selected: currentPage == 'Registar Hospital',
                  leading: const Icon(Icons.add_business),
                  title: const Text('Registar Hospital'),
                  onTap: () =>
                      _replacePage(context, const RegisterHospitalPage()),
                ),
              if (hasPermission(AppPermission.manageUsers))
                ListTile(
                  selected: currentPage == 'Gestão de Contas',
                  leading: const Icon(Icons.admin_panel_settings),
                  title: const Text('Gestão de Contas'),
                  onTap: () =>
                      _replacePage(context, const AccountManagementPage()),
                ),
              if (hasPermission(AppPermission.createUsers))
                ListTile(
                  selected: currentPage == 'Criar Conta',
                  leading: const Icon(Icons.person_add_alt_1),
                  title: const Text('Criar Conta'),
                  onTap: () => _replacePage(context, const CreateUserPage()),
                ),
              ListTile(
                selected: currentPage == 'Editar Conta',
                leading: const Icon(Icons.manage_accounts),
                title: const Text('Editar Conta'),
                onTap: () => _replacePage(context, const ProfilePage()),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sair'),
                onTap: () {
                  authService.signOut();
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (_) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AccessDeniedPage extends StatelessWidget {
  final String reason;

  const AccessDeniedPage({
    super.key,
    this.reason = 'A tua conta não tem permissão para aceder a esta área.',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FB),
      body: Center(
        child: SizedBox(
          width: 520,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock, size: 60, color: Colors.red),
                  const SizedBox(height: 12),
                  const Text(
                    'Acesso negado',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(reason, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.login),
                    label: const Text('Voltar ao login'),
                    onPressed: () {
                      authService.signOut();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                        (_) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RoleDashboardShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Widget> actions;
  final List<Widget> sections;

  const RoleDashboardShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.actions = const [],
    this.sections = const [],
  });

  @override
  Widget build(BuildContext context) {
    final user = currentAppUser;
    if (user == null || !user.active) {
      return const AccessDeniedPage(
        reason: 'Sessão inválida ou conta inativa.',
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      drawer: const SAUHDrawer(currentPage: 'Painel'),
      body: Container(
        color: const Color(0xFFF3F7FB),
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withAlpha(35),
                      radius: 30,
                      child: Icon(icon, color: color, size: 34),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text('${user.role.label} • ${user.department}'),
                          Text(
                            currentHospital?.name ?? 'Acesso global SAUH',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            if (actions.isNotEmpty)
              Wrap(spacing: 12, runSpacing: 12, children: actions),
            if (sections.isNotEmpty) ...[
              const SizedBox(height: 18),
              ...sections,
            ],
          ],
        ),
      ),
    );
  }
}

class DashboardActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget page;

  const DashboardActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.page,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withAlpha(35),
            child: Icon(icon, color: color),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(subtitle),
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => page),
            );
          },
        ),
      ),
    );
  }
}

class SuperAdminDashboard extends StatelessWidget {
  const SuperAdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    if (!hasPermission(AppPermission.registerHospital)) {
      return const AccessDeniedPage();
    }

    final activeHospitals = hospitalService.hospitals
        .where((hospital) => hospital.active)
        .length;

    return RoleDashboardShell(
      title: 'Painel Super Admin',
      subtitle:
          'Gestão global do sistema SAUH: hospitais, administradores e estado geral.',
      icon: Icons.security,
      color: Colors.deepPurple,
      actions: const [
        DashboardActionCard(
          title: 'Registar hospital',
          subtitle: 'Criar nova unidade hospitalar',
          icon: Icons.add_business,
          color: Colors.blue,
          page: RegisterHospitalPage(),
        ),
        DashboardActionCard(
          title: 'Criar coordenador',
          subtitle: 'Associar coordenador à urgência',
          icon: Icons.person_add_alt_1,
          color: Colors.green,
          page: CreateUserPage(),
        ),
        DashboardActionCard(
          title: 'Gestão de contas',
          subtitle: 'Criar e editar contas profissionais',
          icon: Icons.admin_panel_settings,
          color: Colors.orange,
          page: AccountManagementPage(),
        ),
        DashboardActionCard(
          title: 'Simuladores',
          subtitle: 'Monitorizar sinais vitais em tempo real',
          icon: Icons.monitor_heart,
          color: Colors.red,
          page: DashboardPage(),
        ),
      ],
      sections: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 220,
              child: InfoCard(
                title: 'Hospitais',
                value: '${hospitalService.hospitals.length}',
                icon: Icons.local_hospital,
                color: Colors.blue,
              ),
            ),
            SizedBox(
              width: 220,
              child: InfoCard(
                title: 'Ativos',
                value: '$activeHospitals',
                icon: Icons.check_circle,
                color: Colors.green,
              ),
            ),
            SizedBox(
              width: 220,
              child: InfoCard(
                title: 'Contas',
                value: '${authService.users.length}',
                icon: Icons.people,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Hospitais registados',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        for (final hospital in hospitalService.hospitals)
          Card(
            child: SwitchListTile(
              value: hospital.active,
              title: Text(hospital.name),
              subtitle: Text(
                '${hospital.hospitalCode} • ${hospital.address} • ${hospital.contact}',
              ),
              secondary: const Icon(Icons.local_hospital),
              onChanged: (value) {
                hospitalService.setHospitalActive(hospital.hospitalId, value);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SuperAdminDashboard(),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class AdminHospitalDashboard extends StatelessWidget {
  const AdminHospitalDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    if (!hasPermission(AppPermission.manageHospital)) {
      return const AccessDeniedPage();
    }

    final userCount = authService.usersVisibleTo(currentAppUser).length;
    final patientCount = visiblePatientsForCurrentUser().length;
    final alertCount = generateAlerts().length;

    return RoleDashboardShell(
      title: 'Painel Coordenador da Urgência',
      subtitle:
          'Gestão da urgência: profissionais, pacientes, camas e visão operacional.',
      icon: Icons.local_hospital,
      color: Colors.blue,
      actions: const [
        DashboardActionCard(
          title: 'Criar utilizador',
          subtitle: 'Criar cargos da equipa de urgência',
          icon: Icons.person_add_alt_1,
          color: Colors.green,
          page: CreateUserPage(),
        ),
        DashboardActionCard(
          title: 'Gerir utilizadores',
          subtitle: 'Ativar/desativar profissionais',
          icon: Icons.admin_panel_settings,
          color: Colors.orange,
          page: AccountManagementPage(),
        ),
        DashboardActionCard(
          title: 'Dashboard clínico',
          subtitle: 'Pacientes, simuladores e alertas',
          icon: Icons.dashboard,
          color: Colors.blue,
          page: DashboardPage(),
        ),
      ],
      sections: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 220,
              child: InfoCard(
                title: 'Profissionais',
                value: '$userCount',
                icon: Icons.people,
                color: Colors.blue,
              ),
            ),
            SizedBox(
              width: 220,
              child: InfoCard(
                title: 'Pacientes',
                value: '$patientCount',
                icon: Icons.personal_injury,
                color: Colors.green,
              ),
            ),
            SizedBox(
              width: 220,
              child: InfoCard(
                title: 'Alertas',
                value: '$alertCount',
                icon: Icons.warning,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        EmergencyMapSection(
          onPatientSelected: (patient) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PatientDetailsPage(patient: patient),
              ),
            );
          },
        ),
      ],
    );
  }
}

class MedicoDashboard extends StatelessWidget {
  const MedicoDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    if (!hasPermission(AppPermission.viewPatients)) {
      return const AccessDeniedPage();
    }
    return const RoleDashboardShell(
      title: 'Painel Médico',
      subtitle:
          'Consulta fichas clínicas, valida medicação, confirma alertas críticos e acompanha evolução.',
      icon: Icons.medical_services,
      color: Colors.red,
      actions: [
        DashboardActionCard(
          title: 'Pacientes',
          subtitle: 'Abrir lista e ficha clínica',
          icon: Icons.people,
          color: Colors.blue,
          page: PatientsPage(),
        ),
        DashboardActionCard(
          title: 'Alertas',
          subtitle: 'Ver alertas clínicos ativos',
          icon: Icons.warning,
          color: Colors.orange,
          page: AlertsPage(),
        ),
        DashboardActionCard(
          title: 'Monitorização',
          subtitle: 'Abrir sinais vitais em tempo real',
          icon: Icons.monitor_heart,
          color: Colors.green,
          page: DashboardPage(),
        ),
      ],
    );
  }
}

class DiretorClinicoDashboard extends StatelessWidget {
  const DiretorClinicoDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    if (!hasPermission(AppPermission.viewPatients)) {
      return const AccessDeniedPage();
    }
    return const RoleDashboardShell(
      title: 'Painel Diretor Clínico',
      subtitle:
          'Supervisão clínica da urgência, validação de decisões críticas, medicação e acompanhamento global.',
      icon: Icons.supervisor_account,
      color: Colors.deepPurple,
      actions: [
        DashboardActionCard(
          title: 'Simuladores',
          subtitle: 'Monitorizar sinais vitais em tempo real',
          icon: Icons.monitor_heart,
          color: Colors.red,
          page: DashboardPage(),
        ),
        DashboardActionCard(
          title: 'Pacientes',
          subtitle: 'Consultar e editar fichas clínicas',
          icon: Icons.people,
          color: Colors.blue,
          page: PatientsPage(),
        ),
        DashboardActionCard(
          title: 'Alertas',
          subtitle: 'Confirmar alertas críticos',
          icon: Icons.warning,
          color: Colors.orange,
          page: AlertsPage(),
        ),
      ],
    );
  }
}

class EnfermeiroDashboard extends StatelessWidget {
  const EnfermeiroDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    if (!hasPermission(AppPermission.viewPatients)) {
      return const AccessDeniedPage();
    }
    return const RoleDashboardShell(
      title: 'Painel Enfermeiro',
      subtitle:
          'Atualiza sinais vitais, regista medicação administrada, observa pacientes e confirma alertas vistos.',
      icon: Icons.health_and_safety,
      color: Colors.teal,
      actions: [
        DashboardActionCard(
          title: 'Pacientes',
          subtitle: 'Atualizar sinais e medicação',
          icon: Icons.people,
          color: Colors.blue,
          page: PatientsPage(),
        ),
        DashboardActionCard(
          title: 'Alertas',
          subtitle: 'Confirmar alertas vistos',
          icon: Icons.notification_important,
          color: Colors.orange,
          page: AlertsPage(),
        ),
        DashboardActionCard(
          title: 'Monitorização',
          subtitle: 'Ver simuladores vitais',
          icon: Icons.monitor_heart,
          color: Colors.green,
          page: DashboardPage(),
        ),
      ],
    );
  }
}

class ChefeEnfermagemDashboard extends StatelessWidget {
  const ChefeEnfermagemDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    if (!hasPermission(AppPermission.viewPatients)) {
      return const AccessDeniedPage();
    }
    return const RoleDashboardShell(
      title: 'Painel Chefe de Enfermagem',
      subtitle:
          'Coordenação da equipa de enfermagem, acompanhamento de sinais vitais, medicação e alertas.',
      icon: Icons.health_and_safety,
      color: Colors.teal,
      actions: [
        DashboardActionCard(
          title: 'Simuladores',
          subtitle: 'Acompanhar sinais vitais em tempo real',
          icon: Icons.monitor_heart,
          color: Colors.green,
          page: DashboardPage(),
        ),
        DashboardActionCard(
          title: 'Pacientes',
          subtitle: 'Atualizar sinais, medicação e observações',
          icon: Icons.people,
          color: Colors.blue,
          page: PatientsPage(),
        ),
        DashboardActionCard(
          title: 'Alertas',
          subtitle: 'Confirmar alertas vistos',
          icon: Icons.notification_important,
          color: Colors.orange,
          page: AlertsPage(),
        ),
      ],
    );
  }
}

class TecnicoEmergenciaDashboard extends StatelessWidget {
  const TecnicoEmergenciaDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    if (!hasPermission(AppPermission.viewPatients)) {
      return const AccessDeniedPage();
    }
    return const RoleDashboardShell(
      title: 'Painel Técnico de Emergência',
      subtitle:
          'Apoio operacional na urgência, sinais vitais, alertas e encaminhamento rápido.',
      icon: Icons.emergency,
      color: Colors.red,
      actions: [
        DashboardActionCard(
          title: 'Simuladores',
          subtitle: 'Acompanhar sinais vitais',
          icon: Icons.monitor_heart,
          color: Colors.green,
          page: DashboardPage(),
        ),
        DashboardActionCard(
          title: 'Pacientes',
          subtitle: 'Atualizar acompanhamento',
          icon: Icons.people,
          color: Colors.blue,
          page: PatientsPage(),
        ),
      ],
    );
  }
}

class AdministrativoDashboard extends StatelessWidget {
  const AdministrativoDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    if (!hasPermission(AppPermission.viewPatients)) {
      return const AccessDeniedPage();
    }
    return const RoleDashboardShell(
      title: 'Painel Administrativo',
      subtitle:
          'Registo administrativo, criação inicial de fichas e acompanhamento de camas/listas.',
      icon: Icons.assignment_ind,
      color: Colors.blueGrey,
      actions: [
        DashboardActionCard(
          title: 'Nova ficha',
          subtitle: 'Registar entrada do paciente',
          icon: Icons.person_add,
          color: Colors.green,
          page: AddPatientPage(),
        ),
        DashboardActionCard(
          title: 'Pacientes',
          subtitle: 'Pesquisar pacientes e camas',
          icon: Icons.people,
          color: Colors.blue,
          page: PatientsPage(),
        ),
      ],
    );
  }
}

class AuxiliarDashboard extends StatelessWidget {
  const AuxiliarDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    if (!hasPermission(AppPermission.viewPatients)) {
      return const AccessDeniedPage();
    }
    return const RoleDashboardShell(
      title: 'Painel Assistente Operacional',
      subtitle:
          'Acesso de apoio com visualização de pacientes, camas e estado assistencial.',
      icon: Icons.support_agent,
      color: Colors.brown,
      actions: [
        DashboardActionCard(
          title: 'Pacientes',
          subtitle: 'Consultar lista de pacientes',
          icon: Icons.people,
          color: Colors.blue,
          page: PatientsPage(),
        ),
        DashboardActionCard(
          title: 'Mapa da Urgência',
          subtitle: 'Ver camas e ocupação',
          icon: Icons.map,
          color: Colors.orange,
          page: EmergencyMapPage(),
        ),
      ],
    );
  }
}

class TriagemDashboard extends StatelessWidget {
  const TriagemDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    if (!hasPermission(AppPermission.createPatient)) {
      return const AccessDeniedPage();
    }
    return const RoleDashboardShell(
      title: 'Painel Triagem',
      subtitle:
          'Cria a ficha inicial do paciente, regista sintomas e define prioridade de triagem.',
      icon: Icons.fact_check,
      color: Colors.indigo,
      actions: [
        DashboardActionCard(
          title: 'Nova ficha',
          subtitle: 'Registar paciente na urgência',
          icon: Icons.person_add,
          color: Colors.green,
          page: AddPatientPage(),
        ),
        DashboardActionCard(
          title: 'Lista de espera',
          subtitle: 'Pesquisar pacientes em espera',
          icon: Icons.people,
          color: Colors.blue,
          page: PatientsPage(),
        ),
      ],
    );
  }
}

class RegisterHospitalPage extends StatefulWidget {
  const RegisterHospitalPage({super.key});

  @override
  State<RegisterHospitalPage> createState() => _RegisterHospitalPageState();
}

class _RegisterHospitalPageState extends State<RegisterHospitalPage> {
  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final contactController = TextEditingController();
  final codeController = TextEditingController();
  bool active = true;

  @override
  void dispose() {
    nameController.dispose();
    addressController.dispose();
    contactController.dispose();
    codeController.dispose();
    super.dispose();
  }

  void saveHospital() {
    if (!hasPermission(AppPermission.registerHospital)) return;
    if (nameController.text.trim().isEmpty ||
        addressController.text.trim().isEmpty ||
        contactController.text.trim().isEmpty ||
        codeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preenche todos os campos do hospital.')),
      );
      return;
    }

    hospitalService.registerHospital(
      name: nameController.text.trim(),
      address: addressController.text.trim(),
      contact: contactController.text.trim(),
      hospitalCode: codeController.text.trim(),
      active: active,
      createdBy: currentAppUser?.userId ?? 'local',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Hospital registado. Agora podes criar o coordenador da urgência.',
        ),
      ),
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CreateUserPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!hasPermission(AppPermission.registerHospital)) {
      return const AccessDeniedPage();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Registar Hospital')),
      drawer: const SAUHDrawer(currentPage: 'Registar Hospital'),
      body: Center(
        child: SizedBox(
          width: 640,
          child: Card(
            margin: const EdgeInsets.all(16),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Dados do hospital',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Morada',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contactController,
                  decoration: const InputDecoration(
                    labelText: 'Contacto',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'Código interno',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: active,
                  title: const Text('Hospital ativo'),
                  onChanged: (value) => setState(() => active = value),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar Hospital'),
                  onPressed: saveHospital,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AccountCargoOption {
  final String cargo;
  final String label;
  final AppRole role;

  const AccountCargoOption({
    required this.cargo,
    required this.label,
    required this.role,
  });
}

const accountCargoOptions = [
  AccountCargoOption(
    cargo: 'admin',
    label: 'Administrador',
    role: AppRole.adminHospital,
  ),
  AccountCargoOption(cargo: 'medico', label: 'Médico', role: AppRole.medico),
  AccountCargoOption(
    cargo: 'enfermeiro',
    label: 'Enfermeiro',
    role: AppRole.enfermeiro,
  ),
  AccountCargoOption(
    cargo: 'tecnico',
    label: 'Técnico',
    role: AppRole.tecnicoEmergencia,
  ),
  AccountCargoOption(
    cargo: 'rececionista',
    label: 'Rececionista',
    role: AppRole.administrativo,
  ),
  AccountCargoOption(
    cargo: 'triagem',
    label: 'Profissional de Triagem',
    role: AppRole.triagem,
  ),
];

class DoctorOption {
  final String authUserId;
  final String name;
  final String email;

  const DoctorOption({
    required this.authUserId,
    required this.name,
    required this.email,
  });

  String get label {
    final visibleName = name.trim().isEmpty ? 'Médico sem nome' : name.trim();
    final visibleEmail = email.trim();
    return visibleEmail.isEmpty ? visibleName : '$visibleName • $visibleEmail';
  }
}

Future<List<DoctorOption>> fetchActiveDoctorsFromSupabase({
  String? hospitalId,
}) async {
  dynamic query = supabase
      .from('app_users')
      .select('auth_user_id, nome, email, cargo, hospital, ativo')
      .eq('cargo', 'medico')
      .eq('ativo', true);

  final hospitalFilter = hospitalService.normalizeHospitalId(hospitalId);
  if (hospitalFilter != null) {
    query = query.eq('hospital', hospitalFilter);
  } else {
    final user = currentAppUser;
    if (user != null &&
        user.role != AppRole.superAdmin &&
        user.role != AppRole.adminHospital) {
      final hospitalValue = hospitalService.normalizeHospitalId(
        user.hospitalId,
      );
      if (hospitalValue != null) {
        query = query.eq('hospital', hospitalValue);
      }
    }
  }

  final rows = await query.order('nome');
  final doctors = <DoctorOption>[];
  for (final row in rows) {
    if (row is! Map<String, dynamic>) continue;
    final authUserId = _stringFromMap(row, ['auth_user_id']);
    if (authUserId.isEmpty) continue;
    doctors.add(
      DoctorOption(
        authUserId: authUserId,
        name: _stringFromMap(row, ['nome'], fallback: 'Médico'),
        email: _stringFromMap(row, ['email']),
      ),
    );
  }
  return doctors;
}

class CreateUserPage extends StatefulWidget {
  const CreateUserPage({super.key});

  @override
  State<CreateUserPage> createState() => _CreateUserPageState();
}

class _CreateUserPageState extends State<CreateUserPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final departmentController = TextEditingController();
  String? selectedCargo;
  String? selectedHospitalId;
  bool active = true;
  bool isSaving = false;

  List<AccountCargoOption> cargoOptionsFor(AppUser? creator) {
    return accountCargoOptions
        .where(
          (option) => PermissionService.canCreateRole(creator, option.role),
        )
        .toList();
  }

  AccountCargoOption? selectedCargoOption(List<AccountCargoOption> options) {
    for (final option in options) {
      if (option.cargo == selectedCargo) return option;
    }
    return null;
  }

  List<Hospital> get hospitalOptions => hospitalService.activeUniqueHospitals;

  String? validHospitalValue(String? value) {
    final normalizedValue = hospitalService.normalizeHospitalId(value);
    final options = hospitalOptions;
    if (normalizedValue != null &&
        options.any((hospital) => hospital.hospitalId == normalizedValue)) {
      return normalizedValue;
    }
    return options.isEmpty ? null : options.first.hospitalId;
  }

  @override
  void initState() {
    super.initState();
    final creator = currentAppUser;
    final options = cargoOptionsFor(creator);
    selectedCargo = options.isEmpty ? null : options.first.cargo;
    selectedHospitalId = validHospitalValue(creator?.hospitalId);
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    departmentController.dispose();
    super.dispose();
  }

  Future<void> createUser() async {
    final creator = currentAppUser;
    if (creator == null || !hasPermission(AppPermission.createUsers)) {
      return;
    }
    final cargoOptions = cargoOptionsFor(creator);
    final cargoOption = selectedCargoOption(cargoOptions);
    if (cargoOption == null ||
        selectedCargo == null ||
        selectedCargo!.trim().isEmpty ||
        nameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preenche nome, email, password e cargo.'),
        ),
      );
      return;
    }
    if (passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A password temporária deve ter pelo menos 6 caracteres.',
          ),
        ),
      );
      return;
    }
    final resolvedHospitalId = validHospitalValue(selectedHospitalId);
    if (cargoOption.role != AppRole.superAdmin && resolvedHospitalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleciona um hospital ativo antes de criar a conta.'),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });
    try {
      final user = await supabaseAccountService.createAccount(
        client: supabase,
        creator: creator,
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        temporaryPassword: passwordController.text,
        cargo: selectedCargo!,
        role: cargoOption.role,
        department: departmentController.text.trim().isEmpty
            ? 'Não definido'
            : departmentController.text.trim(),
        active: active,
        hospitalId: resolvedHospitalId,
      );
      authService.upsertUser(user);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Conta criada no Supabase: ${user.email}')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AccountManagementPage()),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final creator = currentAppUser;
    final cargoOptions = cargoOptionsFor(creator);
    final hospitals = hospitalOptions;
    if (selectedCargoOption(cargoOptions) == null && cargoOptions.isNotEmpty) {
      selectedCargo = cargoOptions.first.cargo;
    }
    selectedHospitalId = validHospitalValue(selectedHospitalId);

    if (creator == null ||
        !hasPermission(AppPermission.createUsers) ||
        cargoOptions.isEmpty) {
      return const AccessDeniedPage();
    }

    final canChooseHospital =
        creator.role == AppRole.superAdmin && hospitals.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Criar Conta')),
      drawer: const SAUHDrawer(currentPage: 'Criar Conta'),
      body: Center(
        child: SizedBox(
          width: 640,
          child: Card(
            margin: const EdgeInsets.all(16),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Conta profissional',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password temporária',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedCargo,
                  decoration: const InputDecoration(
                    labelText: 'Cargo',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final option in cargoOptions)
                      DropdownMenuItem(
                        value: option.cargo,
                        child: Text(option.label),
                      ),
                  ],
                  onChanged: (value) => setState(() => selectedCargo = value),
                ),
                const SizedBox(height: 12),
                if (canChooseHospital)
                  DropdownButtonFormField<String>(
                    initialValue: validHospitalValue(selectedHospitalId),
                    decoration: const InputDecoration(
                      labelText: 'Hospital',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final hospital in hospitals)
                        DropdownMenuItem(
                          value: hospital.hospitalId,
                          child: Text(
                            '${hospital.name} (${hospital.hospitalCode})',
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      setState(
                        () => selectedHospitalId = validHospitalValue(value),
                      );
                    },
                  )
                else
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Hospital',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(currentHospital?.name ?? 'Sem hospital'),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: departmentController,
                  decoration: const InputDecoration(
                    labelText: 'Departamento (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: active,
                  title: const Text('Conta ativa'),
                  onChanged: (value) => setState(() => active = value),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(isSaving ? 'A criar...' : 'Criar Conta'),
                  onPressed: isSaving ? null : createUser,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EditUserPage extends StatefulWidget {
  final AppUser user;

  const EditUserPage({super.key, required this.user});

  @override
  State<EditUserPage> createState() => _EditUserPageState();
}

class _EditUserPageState extends State<EditUserPage> {
  late final TextEditingController nameController;
  late final TextEditingController emailController;
  late final TextEditingController departmentController;
  late final TextEditingController passwordController;
  late AppRole selectedRole;
  late String? selectedHospitalId;
  late bool active;
  bool isSaving = false;

  List<Hospital> get hospitalOptions => hospitalService.activeUniqueHospitals;

  String? validHospitalValue(String? value) {
    final normalizedValue = hospitalService.normalizeHospitalId(value);
    final options = hospitalOptions;
    if (normalizedValue != null &&
        options.any((hospital) => hospital.hospitalId == normalizedValue)) {
      return normalizedValue;
    }
    return options.isEmpty ? null : options.first.hospitalId;
  }

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    nameController = TextEditingController(text: user.name);
    emailController = TextEditingController(text: user.email);
    departmentController = TextEditingController(text: user.department);
    passwordController = TextEditingController();
    selectedRole = user.role;
    selectedHospitalId = validHospitalValue(user.hospitalId);
    active = user.active;
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    departmentController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> saveUser() async {
    final actor = currentAppUser;
    if (actor == null) return;
    final resolvedHospitalId = selectedRole == AppRole.superAdmin
        ? null
        : validHospitalValue(selectedHospitalId);
    if (selectedRole != AppRole.superAdmin && resolvedHospitalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleciona um hospital ativo antes de guardar.'),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });
    try {
      final updatedUser = await supabaseAccountService.updateAccount(
        client: supabase,
        actor: actor,
        target: widget.user,
        name: nameController.text,
        email: emailController.text,
        role: selectedRole,
        hospitalId: resolvedHospitalId,
        department: departmentController.text,
        active: active,
        newPassword: passwordController.text,
      );
      authService.upsertUser(updatedUser);
      if (updatedUser.userId == actor.userId) {
        syncAccountProfileFromUser(updatedUser);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Conta atualizada: ${updatedUser.email}')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AccountManagementPage()),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = currentAppUser;
    if (actor == null || !hasPermission(AppPermission.manageUsers)) {
      return const AccessDeniedPage();
    }

    final editableRoles = authService.editableRolesFor(actor, widget.user);
    if (editableRoles.isEmpty) {
      return const AccessDeniedPage(
        reason: 'Sem permissão para editar esta conta.',
      );
    }
    if (!editableRoles.contains(selectedRole)) {
      selectedRole = editableRoles.first;
    }

    final canChooseHospital =
        actor.role == AppRole.superAdmin && selectedRole != AppRole.superAdmin;
    if (selectedRole == AppRole.superAdmin) {
      selectedHospitalId = null;
    } else {
      selectedHospitalId = validHospitalValue(selectedHospitalId);
    }
    final hospitals = hospitalOptions;

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Conta')),
      drawer: const SAUHDrawer(currentPage: 'Gestão de Contas'),
      body: Center(
        child: SizedBox(
          width: 680,
          child: Card(
            margin: const EdgeInsets.all(16),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Editar conta profissional',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AppRole>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Cargo',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final role in editableRoles)
                      DropdownMenuItem(value: role, child: Text(role.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedRole = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (selectedRole != AppRole.superAdmin)
                  if (canChooseHospital)
                    DropdownButtonFormField<String>(
                      initialValue: validHospitalValue(selectedHospitalId),
                      decoration: const InputDecoration(
                        labelText: 'Hospital',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final hospital in hospitals)
                          DropdownMenuItem(
                            value: hospital.hospitalId,
                            child: Text(
                              '${hospital.name} (${hospital.hospitalCode})',
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        setState(
                          () => selectedHospitalId = validHospitalValue(value),
                        );
                      },
                    )
                  else
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Hospital',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        hospitalService.byId(selectedHospitalId)?.name ??
                            currentHospital?.name ??
                            'Sem hospital',
                      ),
                    ),
                const SizedBox(height: 12),
                TextField(
                  controller: departmentController,
                  decoration: const InputDecoration(
                    labelText: 'Departamento (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nova password opcional',
                    helperText: 'Deixa vazio para manter a password atual.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: active,
                  title: const Text('Conta ativa'),
                  subtitle: const Text('Contas inativas não conseguem entrar.'),
                  onChanged: widget.user.userId == actor.userId
                      ? null
                      : (value) => setState(() => active = value),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: Text(isSaving ? 'A guardar...' : 'Guardar Alterações'),
                  onPressed: isSaving ? null : saveUser,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({super.key});

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  final searchController = TextEditingController();
  String searchText = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actor = currentAppUser;
    if (actor == null || !hasPermission(AppPermission.manageUsers)) {
      return const AccessDeniedPage();
    }

    final normalizedSearch = searchText.toLowerCase().trim();
    final sourceUsers = authService.usersVisibleTo(actor);
    final users = sourceUsers.where((user) {
      final hospital = hospitalService.byId(user.hospitalId);
      return normalizedSearch.isEmpty ||
          user.name.toLowerCase().contains(normalizedSearch) ||
          user.email.toLowerCase().contains(normalizedSearch) ||
          user.role.label.toLowerCase().contains(normalizedSearch) ||
          user.department.toLowerCase().contains(normalizedSearch) ||
          (hospital?.name.toLowerCase().contains(normalizedSearch) ?? false);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Gestão de Contas')),
      drawer: const SAUHDrawer(currentPage: 'Gestão de Contas'),
      floatingActionButton: hasPermission(AppPermission.createUsers)
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Criar Conta'),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateUserPage()),
                );
              },
            )
          : null,
      body: Container(
        color: const Color(0xFFF3F7FB),
        padding: const EdgeInsets.all(16),
        child: users.isEmpty
            ? const Center(child: Text('Sem utilizadores visíveis.'))
            : ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final hospital = hospitalService.byId(user.hospitalId);
                  return Card(
                    child: SwitchListTile(
                      value: user.active,
                      title: Text(user.name),
                      subtitle: Text(
                        '${user.email} • ${user.role.label} • ${hospital?.name ?? 'Global'}',
                      ),
                      secondary: Icon(
                        user.active ? Icons.verified_user : Icons.block,
                        color: user.active ? Colors.green : Colors.red,
                      ),
                      onChanged: user.userId == actor.userId
                          ? null
                          : (value) {
                              try {
                                authService.setUserActive(actor, user, value);
                                setState(() {});
                              } catch (error) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(error.toString())),
                                );
                              }
                            },
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class AccountManagementPage extends StatefulWidget {
  const AccountManagementPage({super.key});

  @override
  State<AccountManagementPage> createState() => _AccountManagementPageState();
}

class _AccountManagementPageState extends State<AccountManagementPage> {
  final searchController = TextEditingController();
  String searchText = '';
  bool isLoadingAccounts = false;
  String? accountsError;

  @override
  void initState() {
    super.initState();
    loadAccountsFromSupabase();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadAccountsFromSupabase() async {
    final actor = currentAppUser;
    if (actor == null || supabase.auth.currentUser == null) {
      setState(() {
        accountsError =
            'Sessão Supabase ausente. As contas locais não ficam permanentes.';
      });
      return;
    }

    setState(() {
      isLoadingAccounts = true;
      accountsError = null;
    });
    try {
      final users = await supabaseAccountService.loadVisibleAccounts(
        supabase,
        actor,
      );
      authService.setSupabaseAccountSnapshot(users, actor);
    } catch (error) {
      accountsError = error.toString();
    } finally {
      if (mounted) {
        setState(() {
          isLoadingAccounts = false;
        });
      }
    }
  }

  Future<void> setAccountActive(AppUser user, bool value) async {
    final actor = currentAppUser;
    if (actor == null) return;
    if (supabase.auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Inicia sessão com uma conta Supabase para guardar esta alteração.',
          ),
        ),
      );
      return;
    }

    try {
      final updatedUser = await supabaseAccountService.updateAccount(
        client: supabase,
        actor: actor,
        target: user,
        name: user.name,
        email: user.email,
        role: user.role,
        department: user.department,
        active: value,
        hospitalId: user.hospitalId,
      );
      authService.upsertUser(updatedUser);
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = currentAppUser;
    if (actor == null || !hasPermission(AppPermission.manageUsers)) {
      return const AccessDeniedPage();
    }

    final normalizedSearch = searchText.toLowerCase().trim();
    final sourceUsers = authService.usersVisibleTo(actor);
    final users = sourceUsers.where((user) {
      final hospital = hospitalService.byId(user.hospitalId);
      return normalizedSearch.isEmpty ||
          user.name.toLowerCase().contains(normalizedSearch) ||
          user.email.toLowerCase().contains(normalizedSearch) ||
          user.role.label.toLowerCase().contains(normalizedSearch) ||
          user.department.toLowerCase().contains(normalizedSearch) ||
          (hospital?.name.toLowerCase().contains(normalizedSearch) ?? false);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Gestão de Contas')),
      drawer: const SAUHDrawer(currentPage: 'Gestão de Contas'),
      floatingActionButton: hasPermission(AppPermission.createUsers)
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Criar Conta'),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateUserPage()),
                );
              },
            )
          : null,
      body: Container(
        color: const Color(0xFFF3F7FB),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.admin_panel_settings, size: 34),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Gestão de contas profissionais',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Criar, pesquisar, editar, ativar e desativar contas.',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${users.length}/${sourceUsers.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (isLoadingAccounts) const LinearProgressIndicator(),
            if (accountsError != null)
              Card(
                color: Colors.orange.shade50,
                child: ListTile(
                  leading: const Icon(Icons.cloud_off, color: Colors.orange),
                  title: const Text('Sincronização Supabase'),
                  subtitle: Text(accountsError!),
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                    onPressed: loadAccountsFromSupabase,
                  ),
                ),
              ),
            if (isLoadingAccounts || accountsError != null)
              const SizedBox(height: 12),
            TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText:
                    'Pesquisar por nome, email, cargo, hospital ou departamento',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) => setState(() => searchText = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: users.isEmpty
                  ? const Center(child: Text('Sem contas encontradas.'))
                  : ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final hospital = hospitalService.byId(user.hospitalId);
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: user.active
                                  ? Colors.green.shade100
                                  : Colors.red.shade100,
                              child: Icon(
                                user.active ? Icons.verified_user : Icons.block,
                                color: user.active ? Colors.green : Colors.red,
                              ),
                            ),
                            title: Text(user.name),
                            subtitle: Text(
                              '${user.email} • ${user.role.label} • ${hospital?.name ?? 'Global'} • ${user.department}',
                            ),
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Editar'),
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            EditUserPage(user: user),
                                      ),
                                    );
                                    if (mounted) setState(() {});
                                  },
                                ),
                                Switch(
                                  value: user.active,
                                  onChanged: user.userId == actor.userId
                                      ? null
                                      : (value) =>
                                            setAccountActive(user, value),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool isLoading = false;
  final List<int> simulatorPatientIndexes = [0, 1, 2];

  int get simulatorCount {
    final visiblePatients = visiblePatientsForCurrentUser();
    return visiblePatients.length < 3 ? visiblePatients.length : 3;
  }

  int patientIndexForSimulator(int simulatorIndex) {
    final visiblePatients = visiblePatientsForCurrentUser();
    final selectedIndex = simulatorPatientIndexes[simulatorIndex];
    if (selectedIndex >= 0 && selectedIndex < visiblePatients.length) {
      return selectedIndex;
    }
    return simulatorIndex < visiblePatients.length ? simulatorIndex : 0;
  }

  void selectSimulatorPatient(int simulatorIndex, int patientIndex) {
    final previousPatientIndex = patientIndexForSimulator(simulatorIndex);
    int? simulatorUsingPatient;

    for (var index = 0; index < simulatorCount; index++) {
      if (index != simulatorIndex &&
          patientIndexForSimulator(index) == patientIndex) {
        simulatorUsingPatient = index;
        break;
      }
    }

    setState(() {
      simulatorPatientIndexes[simulatorIndex] = patientIndex;
      if (simulatorUsingPatient != null) {
        simulatorPatientIndexes[simulatorUsingPatient] = previousPatientIndex;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    loadPatientsFromSupabase();
  }

  void updatePatientFromSimulator(Patient patient, VitalSigns vitals) {
    patient.heartRate = vitals.heartRate;
    patient.oxygen = vitals.oxygen;
    patient.temperature = vitals.temperature;
    patient.systolicPressure = vitals.systolicPressure;
    patient.diastolicPressure = vitals.diastolicPressure;
    patient.respiratoryRate = vitals.respiratoryRate;
    patient.status = vitals.patientStatus;
    patient.alertLevel = vitals.alertLevel;
    patient.careStatus = switch (vitals.patientStatus) {
      'Crítico' => 'Crítico',
      'Atenção' || 'Em recuperação' => 'Em observação',
      _ => 'Estável',
    };
  }

  void recordSimulatorAlert(Patient patient, SimulatorAlert alert) {
    final alreadyRegistered = clinicalAlertRecords.any(
      (record) =>
          identical(record.patient, patient) &&
          record.alert.type == alert.type &&
          record.alert.createdAt == alert.createdAt,
    );
    if (alreadyRegistered) return;

    clinicalAlertRecords.insert(
      0,
      ClinicalAlertRecord(patient: patient, alert: alert),
    );
    patient.history.add(
      ClinicalRecord(
        description:
            'Alerta automático. Motivo: ${alert.message}. Nível: ${alert.level}.',
        dateTime: formatExactDateTime(alert.createdAt),
      ),
    );
  }

  void confirmSimulatorAlert(Patient patient, SimulatorAlert alert) {
    final recordIndex = clinicalAlertRecords.indexWhere(
      (record) =>
          identical(record.patient, patient) &&
          record.alert.type == alert.type &&
          record.alert.createdAt == alert.createdAt,
    );
    if (recordIndex < 0 || clinicalAlertRecords[recordIndex].isConfirmed) {
      return;
    }

    final professional = currentProfessionalName();
    final confirmedAt = DateTime.now();
    final record = clinicalAlertRecords[recordIndex]
      ..confirmedAt = confirmedAt
      ..confirmedBy = professional;

    patient.history.add(
      ClinicalRecord(
        description:
            'Alerta confirmado por $professional. Motivo: ${alert.message}.',
        dateTime: formatExactDateTime(confirmedAt),
      ),
    );
    unawaited(
      persistAlertConfirmation(
        patient,
        record.alert,
        professional,
        confirmedAt,
      ),
    );
  }

  Future<void> persistAlertConfirmation(
    Patient patient,
    SimulatorAlert alert,
    String professional,
    DateTime confirmedAt,
  ) async {
    try {
      await PatientVitalSignsPersistence(
        patient: patient,
        client: supabase,
      ).saveAlertConfirmation(alert, professional, confirmedAt);
    } catch (error) {
      debugPrint('Erro ao guardar confirmação do alerta: $error');
    }
  }

  Future<void> loadPatientsFromSupabase() async {
    setState(() {
      isLoading = true;
    });

    try {
      await refreshPatientsCacheFromSupabase();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao carregar dados: $error')));
    }

    if (!mounted) return;
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!hasPermission(AppPermission.viewPatients)) {
      return const AccessDeniedPage(
        reason: 'Este cargo só tem acesso limitado aos dados.',
      );
    }

    final visiblePatients = visiblePatientsForCurrentUser();
    final criticalCount = visiblePatients
        .where((patient) => patient.status == 'Crítico')
        .length;

    final alerts = generateAlerts();
    final simulatorSlots = List.generate(simulatorCount, (simulatorIndex) {
      final patientIndex = patientIndexForSimulator(simulatorIndex);
      return (
        simulatorIndex: simulatorIndex,
        patientIndex: patientIndex,
        patient: visiblePatients[patientIndex],
      );
    });

    return Scaffold(
      appBar: AppBar(title: const Text('SAUH - Simuladores')),
      drawer: const SAUHDrawer(currentPage: 'Simuladores'),

      floatingActionButton: hasPermission(AppPermission.createPatient)
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Adicionar Paciente'),
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const AddPatientPage()),
                );
                if (created == true) {
                  await loadPatientsFromSupabase();
                } else if (mounted) {
                  setState(() {});
                }
              },
            )
          : null,

      body: Container(
        color: const Color(0xFFF3F7FB),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              if (isLoading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
              ],
              LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 10.0;
                  final columns = constraints.maxWidth < 600 ? 1 : 3;
                  final cardWidth =
                      (constraints.maxWidth - spacing * (columns - 1)) /
                      columns;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: InfoCard(
                          title: 'Pacientes',
                          value: '${visiblePatients.length}',
                          icon: Icons.people,
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: InfoCard(
                          title: 'Críticos',
                          value: '$criticalCount',
                          icon: Icons.emergency,
                          color: Colors.red,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: InfoCard(
                          title: 'Alertas',
                          value: '${alerts.length}',
                          icon: Icons.warning,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 20),

              EmergencyMapSection(
                onPatientSelected: (patient) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PatientDetailsPage(patient: patient),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              if (simulatorSlots.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Adiciona pacientes para iniciar a monitorização.',
                    ),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 12.0;
                    final columns = constraints.maxWidth >= 1350
                        ? 3
                        : constraints.maxWidth >= 900
                        ? 2
                        : 1;
                    final cardWidth =
                        (constraints.maxWidth - spacing * (columns - 1)) /
                        columns;

                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        for (final slot in simulatorSlots)
                          SizedBox(
                            width: cardWidth,
                            child: Column(
                              children: [
                                DropdownButtonFormField<int>(
                                  initialValue: slot.patientIndex,
                                  decoration: InputDecoration(
                                    labelText:
                                        'Paciente do monitor ${slot.simulatorIndex + 1}',
                                    border: const OutlineInputBorder(),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  items: [
                                    for (
                                      var patientIndex = 0;
                                      patientIndex < visiblePatients.length;
                                      patientIndex++
                                    )
                                      DropdownMenuItem(
                                        value: patientIndex,
                                        child: Text(
                                          '${visiblePatients[patientIndex].name} - ${visiblePatients[patientIndex].room}',
                                        ),
                                      ),
                                  ],
                                  onChanged: (patientIndex) {
                                    if (patientIndex == null) return;
                                    selectSimulatorPatient(
                                      slot.simulatorIndex,
                                      patientIndex,
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                VitalSignsSimulatorSection(
                                  key: ValueKey(
                                    '${slot.simulatorIndex}-${slot.patient.id ?? slot.patient.name}',
                                  ),
                                  patientName: slot.patient.name,
                                  professionalName: currentProfessionalName(),
                                  persistence: PatientVitalSignsPersistence(
                                    patient: slot.patient,
                                    client: supabase,
                                  ),
                                  initialVitals: VitalSigns(
                                    heartRate: slot.patient.heartRate,
                                    oxygen: slot.patient.oxygen,
                                    temperature: slot.patient.temperature,
                                    systolicPressure:
                                        slot.patient.systolicPressure,
                                    diastolicPressure:
                                        slot.patient.diastolicPressure,
                                    respiratoryRate:
                                        slot.patient.respiratoryRate,
                                    patientStatus: slot.patient.status,
                                    alertLevel: slot.patient.alertLevel,
                                    measuredAt: DateTime.now(),
                                  ),
                                  onVitalsChanged: (vitals) {
                                    setState(() {
                                      updatePatientFromSimulator(
                                        slot.patient,
                                        vitals,
                                      );
                                    });
                                  },
                                  onAlertCreated: (alert) {
                                    setState(() {
                                      recordSimulatorAlert(slot.patient, alert);
                                    });
                                  },
                                  onAlertConfirmed: (alert) {
                                    setState(() {
                                      confirmSimulatorAlert(
                                        slot.patient,
                                        alert,
                                      );
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),

              const SizedBox(height: 20),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Alertas Recentes',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                height: 160,
                child: alerts.isEmpty
                    ? const Center(child: Text('Sem alertas ativos.'))
                    : ListView.builder(
                        itemCount: alerts.length,
                        itemBuilder: (context, index) {
                          final alert = alerts[index];

                          return Card(
                            color: alert.level == 'Crítico'
                                ? Colors.red.shade100
                                : Colors.orange.shade100,
                            child: ListTile(
                              leading: Icon(
                                Icons.warning,
                                color: alert.level == 'Crítico'
                                    ? Colors.red
                                    : Colors.orange,
                              ),
                              title: Text(alert.patientName),
                              subtitle: Text(alert.message),
                              trailing: Text(
                                alert.level,
                                style: TextStyle(
                                  color: alert.level == 'Crítico'
                                      ? Colors.red
                                      : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmergencyMapPage extends StatelessWidget {
  const EmergencyMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa da Urgência')),
      drawer: const SAUHDrawer(currentPage: 'Mapa da Urgência'),
      body: Container(
        color: const Color(0xFFF3F7FB),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: EmergencyMapSection(
            onPatientSelected: (patient) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PatientDetailsPage(patient: patient),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class PatientsPage extends StatefulWidget {
  const PatientsPage({super.key});

  @override
  State<PatientsPage> createState() => _PatientsPageState();
}

class _PatientsPageState extends State<PatientsPage> {
  final searchController = TextEditingController();
  String searchText = '';
  bool onlyCritical = false;
  bool onlyWaiting = false;
  bool onlyPendingMedication = false;
  bool onlyActiveAlerts = false;
  bool isLoadingPatients = false;
  String? patientsError;

  @override
  void initState() {
    super.initState();
    loadPatients();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadPatients() async {
    setState(() {
      isLoadingPatients = true;
      patientsError = null;
    });
    try {
      await refreshPatientsCacheFromSupabase();
    } catch (error) {
      patientsError = error.toString();
    } finally {
      if (mounted) {
        setState(() {
          isLoadingPatients = false;
        });
      }
    }
  }

  Future<void> confirmDeletePatient(Patient patient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar paciente'),
        content: Text(
          'Tens a certeza que queres apagar ${patient.name}? Esta ação remove também a medicação associada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.delete_outline),
            label: const Text('Apagar'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await deletePatientFromSupabase(patient);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${patient.name} apagado com sucesso.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao apagar paciente: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredPatients = filterPatients(
      source: visiblePatientsForCurrentUser(),
      query: searchText,
      onlyCritical: onlyCritical,
      onlyWaiting: onlyWaiting,
      onlyPendingMedication: onlyPendingMedication,
      onlyActiveAlerts: onlyActiveAlerts,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Pacientes')),
      drawer: const SAUHDrawer(currentPage: 'Pacientes'),
      floatingActionButton: hasPermission(AppPermission.createPatient)
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Adicionar Paciente'),
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const AddPatientPage()),
                );
                if (created == true) {
                  await loadPatients();
                } else if (mounted) {
                  setState(() {});
                }
              },
            )
          : null,
      body: Container(
        color: const Color(0xFFF3F7FB),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText:
                    'Pesquisar por nome, número de utente, cama ou estado',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                setState(() {
                  searchText = value;
                });
              },
            ),
            const SizedBox(height: 10),
            if (isLoadingPatients) const LinearProgressIndicator(),
            if (patientsError != null)
              Card(
                color: Colors.orange.shade50,
                child: ListTile(
                  leading: const Icon(Icons.cloud_off, color: Colors.orange),
                  title: const Text('Sincronização de pacientes'),
                  subtitle: Text(patientsError!),
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                    onPressed: loadPatients,
                  ),
                ),
              ),
            if (isLoadingPatients || patientsError != null)
              const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Só pacientes críticos'),
                    selected: onlyCritical,
                    onSelected: (value) {
                      setState(() {
                        onlyCritical = value;
                      });
                    },
                  ),
                  FilterChip(
                    label: const Text('Só pacientes em espera'),
                    selected: onlyWaiting,
                    onSelected: (value) {
                      setState(() {
                        onlyWaiting = value;
                      });
                    },
                  ),
                  FilterChip(
                    label: const Text('Medicação pendente'),
                    selected: onlyPendingMedication,
                    onSelected: (value) {
                      setState(() {
                        onlyPendingMedication = value;
                      });
                    },
                  ),
                  FilterChip(
                    label: const Text('Alertas ativos'),
                    selected: onlyActiveAlerts,
                    onSelected: (value) {
                      setState(() {
                        onlyActiveAlerts = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filteredPatients.isEmpty
                  ? const Center(child: Text('Nenhum paciente encontrado.'))
                  : ListView.builder(
                      itemCount: filteredPatients.length,
                      itemBuilder: (context, index) {
                        final patient = filteredPatients[index];

                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: patientStatusColor(
                                patient.status,
                              ),
                            ),
                            title: Text(patient.name),
                            subtitle: Text(
                              'Utente: ${patient.healthNumber} • Cama: ${patient.room} • ${patient.careStatus}',
                            ),
                            trailing: Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  patient.status,
                                  style: TextStyle(
                                    color: patientStatusColor(patient.status),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (canDeletePatient(patient))
                                  IconButton(
                                    tooltip: 'Apagar paciente',
                                    icon: const Icon(Icons.delete_outline),
                                    color: Colors.red,
                                    onPressed: () =>
                                        confirmDeletePatient(patient),
                                  ),
                              ],
                            ),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PatientDetailsPage(patient: patient),
                                ),
                              );
                              if (mounted) setState(() {});
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final alerts = generateAlerts();
    final visiblePatients = visiblePatientsForCurrentUser();
    final registeredAlerts = clinicalAlertRecords
        .where((record) => visiblePatients.contains(record.patient))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Alertas')),
      drawer: const SAUHDrawer(currentPage: 'Alertas'),
      body: Container(
        color: const Color(0xFFF3F7FB),
        padding: const EdgeInsets.all(16),
        child: registeredAlerts.isNotEmpty
            ? ListView.builder(
                itemCount: registeredAlerts.length,
                itemBuilder: (context, index) {
                  final record = registeredAlerts[index];

                  return Card(
                    color: record.isConfirmed
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    child: ListTile(
                      leading: Icon(
                        record.isConfirmed
                            ? Icons.check_circle
                            : Icons.notification_important,
                        color: record.isConfirmed ? Colors.green : Colors.red,
                      ),
                      title: Text(record.patient.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Motivo: ${record.alert.message}'),
                          Text(
                            'Hora: ${formatExactDateTime(record.alert.createdAt)}',
                          ),
                          Text(
                            record.isConfirmed
                                ? 'Confirmado por ${record.confirmedBy} às ${formatExactDateTime(record.confirmedAt!)}'
                                : 'A aguardar confirmação clínica',
                          ),
                        ],
                      ),
                      trailing: Text(
                        record.isConfirmed ? 'Confirmado' : record.alert.level,
                        style: TextStyle(
                          color: record.isConfirmed ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              )
            : alerts.isEmpty
            ? const Center(child: Text('Sem alertas ativos.'))
            : ListView.builder(
                itemCount: alerts.length,
                itemBuilder: (context, index) {
                  final alert = alerts[index];
                  final isCritical = alert.level == 'Crítico';

                  return Card(
                    color: isCritical
                        ? Colors.red.shade100
                        : Colors.orange.shade100,
                    child: ListTile(
                      leading: Icon(
                        Icons.warning,
                        color: isCritical ? Colors.red : Colors.orange,
                      ),
                      title: Text(alert.patientName),
                      subtitle: Text(alert.message),
                      trailing: Text(
                        alert.level,
                        style: TextStyle(
                          color: isCritical ? Colors.red : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const InfoCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [color.withAlpha(217), color.withAlpha(153)],
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 36),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final roleController = TextEditingController();
  final professionalIdController = TextEditingController();
  final departmentController = TextEditingController();
  final avatarUrlController = TextEditingController();
  final newPasswordController = TextEditingController();
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    roleController.dispose();
    professionalIdController.dispose();
    departmentController.dispose();
    avatarUrlController.dispose();
    newPasswordController.dispose();
    super.dispose();
  }

  String metadataValue(
    Map<String, dynamic> metadata,
    String key,
    String fallback,
  ) {
    final value = metadata[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  void loadProfile() {
    final user = supabase.auth.currentUser;
    final metadata = user?.userMetadata ?? <String, dynamic>{};

    nameController.text = metadataValue(
      metadata,
      'full_name',
      accountProfile.name,
    );
    emailController.text = user?.email ?? accountProfile.email;
    phoneController.text = metadataValue(
      metadata,
      'phone',
      accountProfile.phone,
    );
    roleController.text = metadataValue(metadata, 'role', accountProfile.role);
    professionalIdController.text = metadataValue(
      metadata,
      'professional_id',
      accountProfile.professionalId,
    );
    departmentController.text = metadataValue(
      metadata,
      'department',
      accountProfile.department,
    );
    avatarUrlController.text = metadataValue(
      metadata,
      'avatar_url',
      accountProfile.avatarUrl,
    );
  }

  bool isValidImageUrl(String value) {
    if (value.trim().isEmpty) return true;
    final uri = Uri.tryParse(value.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  Future<void> saveProfile() async {
    final user = supabase.auth.currentUser;
    final email = emailController.text.trim();
    final avatarUrl = avatarUrlController.text.trim();
    final newPassword = newPasswordController.text;

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O email não pode ficar vazio.')),
      );
      return;
    }
    if (newPassword.isNotEmpty && newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A nova palavra-passe deve ter pelo menos 6 caracteres.',
          ),
        ),
      );
      return;
    }
    if (!isValidImageUrl(avatarUrl)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A imagem deve ser um URL http ou https.'),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    accountProfile
      ..name = nameController.text.trim()
      ..email = email
      ..phone = phoneController.text.trim()
      ..role = roleController.text.trim()
      ..professionalId = professionalIdController.text.trim()
      ..department = departmentController.text.trim()
      ..avatarUrl = avatarUrl;

    try {
      if (user != null) {
        await supabase.auth.updateUser(
          UserAttributes(
            email: email == user.email ? null : email,
            password: newPassword.isEmpty ? null : newPassword,
            data: {
              'full_name': accountProfile.name,
              'phone': accountProfile.phone,
              'role': accountProfile.role,
              'professional_id': accountProfile.professionalId,
              'department': accountProfile.department,
              'avatar_url': accountProfile.avatarUrl,
            },
          ),
        );
      }

      if (!mounted) return;
      newPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            user == null
                ? 'Perfil local atualizado com sucesso.'
                : 'Conta atualizada com sucesso.',
          ),
        ),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar conta: ${error.message}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar conta: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Widget profileField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? hintText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = avatarUrlController.text.trim();
    final avatarImage = avatarUrl.isNotEmpty && isValidImageUrl(avatarUrl)
        ? NetworkImage(avatarUrl)
        : null;
    final hasAuthenticatedAccount = supabase.auth.currentUser != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Conta')),
      drawer: const SAUHDrawer(currentPage: 'Editar Conta'),
      body: Container(
        color: const Color(0xFFF3F7FB),
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 560,
          child: Card(
            margin: const EdgeInsets.all(16),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.blue.shade100,
                    backgroundImage: avatarImage,
                    child: avatarImage == null
                        ? const Icon(Icons.person, size: 50, color: Colors.blue)
                        : null,
                  ),
                ),
                const SizedBox(height: 20),
                profileField(
                  controller: nameController,
                  label: 'Nome completo',
                ),
                const SizedBox(height: 12),
                profileField(
                  controller: emailController,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                profileField(
                  controller: phoneController,
                  label: 'Telemóvel',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                profileField(
                  controller: roleController,
                  label: 'Função',
                  hintText: 'Ex: Médico, Enfermeiro',
                ),
                const SizedBox(height: 12),
                profileField(
                  controller: professionalIdController,
                  label: 'N.º profissional',
                ),
                const SizedBox(height: 12),
                profileField(
                  controller: departmentController,
                  label: 'Serviço / Departamento',
                  hintText: 'Ex: Urgência, Pediatria',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: avatarUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Imagem de perfil (URL)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (hasAuthenticatedAccount) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nova palavra-passe (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: Text(isSaving ? 'A guardar...' : 'Guardar Conta'),
                  onPressed: isSaving ? null : saveProfile,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AddPatientPage extends StatefulWidget {
  const AddPatientPage({super.key});

  @override
  State<AddPatientPage> createState() => _AddPatientPageState();
}

class _AddPatientPageState extends State<AddPatientPage> {
  final nameController = TextEditingController();
  final healthNumberController = TextEditingController();
  final ageController = TextEditingController();
  final roomController = TextEditingController();
  final heartRateController = TextEditingController();
  final temperatureController = TextEditingController();
  final oxygenController = TextEditingController();

  String selectedStatus = 'Normal';
  String selectedCareStatus = 'Em observação';
  String? selectedHospitalId;
  List<DoctorOption> doctorOptions = const [];
  String? selectedDoctorAuthUserId;
  bool isLoadingDoctors = false;

  @override
  void initState() {
    super.initState();
    selectedHospitalId = initialPatientHospitalId();
    loadDoctors();
  }

  @override
  void dispose() {
    nameController.dispose();
    healthNumberController.dispose();
    ageController.dispose();
    roomController.dispose();
    heartRateController.dispose();
    temperatureController.dispose();
    oxygenController.dispose();
    super.dispose();
  }

  Future<void> loadDoctors() async {
    setState(() {
      isLoadingDoctors = true;
    });
    try {
      final doctors = await fetchActiveDoctorsFromSupabase(
        hospitalId: selectedHospitalId,
      );
      if (!mounted) return;
      setState(() {
        doctorOptions = doctors;
        if (!doctorOptions.any(
          (doctor) => doctor.authUserId == selectedDoctorAuthUserId,
        )) {
          selectedDoctorAuthUserId = doctorOptions.isEmpty
              ? null
              : doctorOptions.first.authUserId;
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar médicos: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoadingDoctors = false;
        });
      }
    }
  }

  String? initialPatientHospitalId() {
    final activeHospitals = hospitalService.activeUniqueHospitals;
    final currentHospital = hospitalService.normalizeHospitalId(
      currentAppUser?.hospitalId,
    );
    if (currentHospital != null &&
        activeHospitals.any(
          (hospital) => hospital.hospitalId == currentHospital,
        )) {
      return currentHospital;
    }
    return activeHospitals.isEmpty ? null : activeHospitals.first.hospitalId;
  }

  bool get canChoosePatientHospital {
    final role = currentAppUser?.role;
    return role == AppRole.superAdmin || role == AppRole.adminHospital;
  }

  void leaveAfterSave() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(true);
      return;
    }

    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const PatientsPage()),
    );
  }

  Future<void> addPatient() async {
    if (!hasPermission(AppPermission.createPatient)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sem permissão para criar pacientes.')),
      );
      return;
    }

    if (nameController.text.isEmpty ||
        healthNumberController.text.isEmpty ||
        ageController.text.isEmpty ||
        roomController.text.isEmpty ||
        heartRateController.text.isEmpty ||
        temperatureController.text.isEmpty ||
        oxygenController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preenche todos os campos.')),
      );
      return;
    }

    final age = int.tryParse(ageController.text);
    final heartRate = int.tryParse(heartRateController.text);
    final temperature = double.tryParse(
      temperatureController.text.replaceAll(',', '.'),
    );
    final oxygen = int.tryParse(oxygenController.text);

    if (age == null ||
        heartRate == null ||
        temperature == null ||
        oxygen == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verifica os valores numéricos.')),
      );
      return;
    }

    final status = calculatePatientStatus(heartRate, temperature, oxygen);
    final authUserId = supabase.auth.currentUser?.id;
    final hospitalId = hospitalService.normalizeHospitalId(selectedHospitalId);
    final medicoResponsavelAuthUserId = selectedDoctorAuthUserId?.trim();

    if (authUserId == null || authUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inicia sessão no Supabase antes de criar pacientes.'),
        ),
      );
      return;
    }

    if (hospitalId == null || hospitalId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A tua conta não tem hospital válido associado.'),
        ),
      );
      return;
    }

    if (medicoResponsavelAuthUserId == null ||
        medicoResponsavelAuthUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleciona o médico responsável.')),
      );
      return;
    }

    try {
      final insertedPatient = await supabase
          .from('patients')
          .insert({
            'nome': nameController.text.trim(),
            'idade': age,
            'genero': 'Não indicado',
            'numero_processo': healthNumberController.text.trim(),
            'motivo_entrada': 'Avaliação clínica',
            'estado_clinico': status,
            'prioridade': selectedCareStatus,
            'hospital': hospitalId,
            'departamento': roomController.text.trim(),
            'medico_responsavel_auth_user_id': medicoResponsavelAuthUserId,
            'created_by_auth_user_id': authUserId,
            'ativo': true,
          })
          .select()
          .single();

      final newPatient =
          patientFromSupabaseMap(
              insertedPatient,
              history: [
                ClinicalRecord(
                  description: 'Paciente adicionado manualmente.',
                  dateTime: getCurrentDateTime(),
                ),
              ],
            )
            ..heartRate = heartRate
            ..temperature = temperature
            ..oxygen = oxygen
            ..careStatus = selectedCareStatus;

      patients.add(newPatient);

      await supabase.from('clinical_history').insert({
        'patient_id': insertedPatient['id'],
        'description': 'Paciente adicionado manualmente.',
        'date_time': getCurrentDateTime(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paciente guardado no Supabase.')),
      );

      leaveAfterSave();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao guardar paciente: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!hasPermission(AppPermission.createPatient)) {
      return const AccessDeniedPage(
        reason: 'Este cargo não pode criar fichas de paciente.',
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar Paciente')),
      drawer: const SAUHDrawer(currentPage: 'Adicionar Paciente'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nome do paciente',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: healthNumberController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Número de utente',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Idade',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: roomController,
              decoration: const InputDecoration(
                labelText: 'Cama',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            if (canChoosePatientHospital)
              DropdownButtonFormField<String>(
                initialValue: selectedHospitalId,
                decoration: const InputDecoration(
                  labelText: 'Hospital',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final hospital in hospitalService.activeUniqueHospitals)
                    DropdownMenuItem(
                      value: hospital.hospitalId,
                      child: Text(
                        '${hospital.name} (${hospital.hospitalCode})',
                      ),
                    ),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedHospitalId = value;
                    selectedDoctorAuthUserId = null;
                    doctorOptions = const [];
                  });
                  loadDoctors();
                },
              )
            else
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Hospital',
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  hospitalService.byId(selectedHospitalId)?.name ??
                      'Hospital por atribuir',
                ),
              ),

            const SizedBox(height: 12),

            if (isLoadingDoctors) const LinearProgressIndicator(),
            DropdownButtonFormField<String>(
              initialValue: selectedDoctorAuthUserId,
              decoration: const InputDecoration(
                labelText: 'Médico responsável',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final doctor in doctorOptions)
                  DropdownMenuItem(
                    value: doctor.authUserId,
                    child: Text(doctor.label),
                  ),
              ],
              onChanged: doctorOptions.isEmpty
                  ? null
                  : (value) {
                      setState(() {
                        selectedDoctorAuthUserId = value;
                      });
                    },
            ),
            if (doctorOptions.isEmpty && !isLoadingDoctors)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Não existem médicos ativos disponíveis para este hospital.',
                  style: TextStyle(color: Colors.red),
                ),
              ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: selectedCareStatus,
              decoration: const InputDecoration(
                labelText: 'Estado assistencial',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Estável', child: Text('Estável')),
                DropdownMenuItem(
                  value: 'Em observação',
                  child: Text('Em observação'),
                ),
                DropdownMenuItem(value: 'Crítico', child: Text('Crítico')),
                DropdownMenuItem(
                  value: 'A aguardar médico',
                  child: Text('A aguardar médico'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedCareStatus = value;
                  });
                }
              },
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Estado',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Normal', child: Text('Normal')),
                DropdownMenuItem(value: 'Atenção', child: Text('Atenção')),
                DropdownMenuItem(value: 'Crítico', child: Text('Crítico')),
              ],
              onChanged: (value) {
                setState(() {
                  selectedStatus = value!;
                });
              },
            ),

            const SizedBox(height: 12),

            TextField(
              controller: heartRateController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Batimentos cardíacos',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: temperatureController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Temperatura',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: oxygenController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Oxigénio',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Guardar Paciente'),
              onPressed: addPatient,
            ),
          ],
        ),
      ),
    );
  }
}

class PatientDetailsPage extends StatefulWidget {
  final Patient patient;

  const PatientDetailsPage({super.key, required this.patient});

  @override
  State<PatientDetailsPage> createState() => _PatientDetailsPageState();
}

class _PatientDetailsPageState extends State<PatientDetailsPage> {
  Timer? medicationStatusTimer;

  @override
  void initState() {
    super.initState();
    medicationStatusTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    medicationStatusTimer?.cancel();
    super.dispose();
  }

  Future<void> confirmDeletePatientFromDetails(Patient patient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar paciente'),
        content: Text(
          'Tens a certeza que queres apagar ${patient.name}? Esta ação remove também a medicação associada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.delete_outline),
            label: const Text('Apagar'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await deletePatientFromSupabase(patient);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${patient.name} apagado com sucesso.')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao apagar paciente: $error')),
      );
    }
  }

  Future<void> confirmMedicationAdministration(
    Patient patient,
    Medication medication,
  ) async {
    final professional = currentProfessionalName();
    final previousResponsible = medication.responsibleProfessional;
    final wasAdministered = medication.administered;

    setState(() {
      medication
        ..administered = true
        ..responsibleProfessional = professional;
      patient.history.add(
        ClinicalRecord(
          description:
              'Medicação administrada: ${medication.name}, dose ${medication.dose}, por $professional.',
          dateTime: formatExactDateTime(DateTime.now()),
        ),
      );
    });

    try {
      await updateMedicationInSupabase(patient, medication);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${medication.name} administrado com sucesso.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        medication
          ..administered = wasAdministered
          ..responsibleProfessional = previousResponsible;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar medicação: $error')),
      );
    }
  }

  Future<void> confirmDeleteMedication(
    Patient patient,
    Medication medication,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar medicação'),
        content: Text(
          'Tens a certeza que queres apagar ${medication.name} da ficha de ${patient.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.delete_outline),
            label: const Text('Apagar'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await deleteMedicationFromSupabase(patient, medication);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${medication.name} apagado com sucesso.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao apagar medicação: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = widget.patient;
    if (!PermissionService.canAccessHospital(
          currentAppUser,
          patient.hospitalId,
        ) ||
        (!hasPermission(AppPermission.viewPatients) &&
            !hasPermission(AppPermission.viewLimitedData))) {
      return const AccessDeniedPage(
        reason: 'Este paciente não pertence ao teu hospital ou cargo.',
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(patient.name),
        actions: [
          if (canDeletePatient(patient))
            IconButton(
              tooltip: 'Apagar paciente',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => confirmDeletePatientFromDetails(patient),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            ClinicalSection(
              title: 'Dados pessoais',
              icon: Icons.badge,
              children: [
                InfoRow(label: 'Nome', value: patient.name),
                InfoRow(label: 'Número de utente', value: patient.healthNumber),
                InfoRow(label: 'Idade', value: '${patient.age} anos'),
                InfoRow(label: 'Género', value: patient.gender),
                InfoRow(label: 'Contacto', value: patient.contact),
                InfoRow(label: 'Cama', value: patient.room),
                InfoRow(
                  label: 'Estado assistencial',
                  value: patient.careStatus,
                ),
              ],
            ),

            ClinicalSection(
              title: 'Admissão e triagem',
              icon: Icons.emergency,
              children: [
                InfoRow(
                  label: 'Motivo de entrada',
                  value: patient.admissionReason,
                ),
                InfoRow(
                  label: 'Sintomas principais',
                  value: patient.symptoms.isEmpty
                      ? 'Sem sintomas registados'
                      : patient.symptoms.join(', '),
                ),
                InfoRow(label: 'Nível de triagem', value: patient.triageLevel),
                InfoRow(label: 'Estado atual', value: patient.status),
              ],
            ),

            ClinicalSection(
              title: 'Informação clínica',
              icon: Icons.medical_information,
              children: [
                InfoRow(
                  label: 'Alergias',
                  value: patient.allergies.isEmpty
                      ? 'Sem alergias conhecidas'
                      : patient.allergies.join(', '),
                ),
                InfoRow(
                  label: 'Medicação habitual',
                  value: patient.usualMedication,
                ),
                InfoRow(
                  label: 'Antecedentes médicos',
                  value: patient.medicalHistory,
                ),
              ],
            ),

            const Text(
              'Sinais vitais atuais',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            VitalCard(
              title: 'Batimentos Cardíacos',
              value: '${patient.heartRate} bpm',
              icon: Icons.favorite,
            ),

            VitalCard(
              title: 'Temperatura',
              value: '${patient.temperature} ºC',
              icon: Icons.thermostat,
            ),

            VitalCard(
              title: 'Oxigénio',
              value: '${patient.oxygen}%',
              icon: Icons.air,
            ),

            VitalCard(
              title: 'Pressão Arterial',
              value:
                  '${patient.systolicPressure}/${patient.diastolicPressure} mmHg',
              icon: Icons.bloodtype,
            ),

            VitalCard(
              title: 'Frequência Respiratória',
              value: '${patient.respiratoryRate} rpm',
              icon: Icons.waves,
            ),

            const SizedBox(height: 12),

            if (canUsePatient(patient, AppPermission.updateVitals))
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.monitor_heart),
                  label: const Text('Atualizar Sinais Vitais'),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UpdateVitalsPage(patient: patient),
                      ),
                    );

                    setState(() {});
                  },
                ),
              ),

            const SizedBox(height: 8),

            if (canUsePatient(patient, AppPermission.editPatientRecord))
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Editar Ficha Clínica'),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditPatientRecordPage(patient: patient),
                      ),
                    );
                    setState(() {});
                  },
                ),
              ),

            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.history),
                label: const Text('Ver Histórico Clínico'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClinicalHistoryPage(patient: patient),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            ClinicalSection(
              title: 'Observações da equipa médica',
              icon: Icons.note_alt,
              children: [Text(patient.medicalNotes)],
            ),

            Row(
              children: [
                const Text(
                  'Medicação',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (canUsePatient(patient, AppPermission.manageMedication))
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar'),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddMedicationPage(patient: patient),
                        ),
                      );

                      setState(() {});
                    },
                  ),
              ],
            ),

            const SizedBox(height: 10),

            if (patient.allergies.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Atenção: este paciente tem alergia registada a ${patient.allergies.join(', ')}.',
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            if (patient.medications.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Este paciente ainda não tem medicação.'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: patient.medications.length,
                itemBuilder: (context, index) {
                  final medication = patient.medications[index];
                  final medicationStatus = medication.statusAt(DateTime.now());
                  final allergyMatches = medicationAllergyMatches(
                    patient,
                    medication,
                  );
                  final statusColor = medicationStatusColor(medicationStatus);

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            medicationStatus == MedicationStatus.administered
                                ? Icons.check_circle
                                : medicationStatus == MedicationStatus.overdue
                                ? Icons.notification_important
                                : Icons.pending_actions,
                            color: statusColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  medication.name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text('Dose: ${medication.dose}'),
                                Text(
                                  'Hora de administração: ${medication.time}',
                                ),
                                Text(
                                  'Profissional responsável: ${medication.responsibleProfessional}',
                                ),
                                Text(
                                  'Estado: ${medicationStatusLabel(medicationStatus)}',
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (allergyMatches.isNotEmpty)
                                  Text(
                                    'Aviso de alergia: ${allergyMatches.join(', ')}',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (!medication.administered &&
                                  canUsePatient(
                                    patient,
                                    AppPermission.manageMedication,
                                  ))
                                ElevatedButton(
                                  onPressed: () =>
                                      confirmMedicationAdministration(
                                        patient,
                                        medication,
                                      ),
                                  child: const Text('Confirmar'),
                                ),
                              if (canUsePatient(
                                patient,
                                AppPermission.manageMedication,
                              ))
                                IconButton(
                                  tooltip: 'Editar medicação',
                                  icon: const Icon(Icons.edit),
                                  onPressed: () async {
                                    final saved = await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AddMedicationPage(
                                          patient: patient,
                                          medication: medication,
                                        ),
                                      ),
                                    );
                                    if (saved == true && mounted) {
                                      setState(() {});
                                    }
                                  },
                                ),
                              if (canDeleteMedication(patient))
                                IconButton(
                                  tooltip: 'Apagar medicação',
                                  color: Colors.red,
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => confirmDeleteMedication(
                                    patient,
                                    medication,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 20),

            ClinicalSection(
              title: 'Histórico de alterações',
              icon: Icons.history,
              children: [
                if (patient.history.isEmpty)
                  const Text('Sem alterações registadas.')
                else
                  for (final record in patient.history.reversed.take(5))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history, color: Colors.blue),
                      title: Text(record.description),
                      subtitle: Text(record.dateTime),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class EditPatientRecordPage extends StatefulWidget {
  final Patient patient;

  const EditPatientRecordPage({super.key, required this.patient});

  @override
  State<EditPatientRecordPage> createState() => _EditPatientRecordPageState();
}

class _EditPatientRecordPageState extends State<EditPatientRecordPage> {
  late final TextEditingController healthNumberController;
  late final TextEditingController genderController;
  late final TextEditingController contactController;
  late final TextEditingController admissionReasonController;
  late final TextEditingController symptomsController;
  late final TextEditingController allergiesController;
  late final TextEditingController usualMedicationController;
  late final TextEditingController medicalHistoryController;
  late final TextEditingController medicalNotesController;
  late String triageLevel;
  late String careStatus;

  static const triageLevels = [
    'Vermelho',
    'Laranja',
    'Amarelo',
    'Verde',
    'Azul',
  ];
  static const careStatuses = [
    'Estável',
    'Em observação',
    'Crítico',
    'A aguardar médico',
  ];

  @override
  void initState() {
    super.initState();
    final patient = widget.patient;
    healthNumberController = TextEditingController(text: patient.healthNumber);
    genderController = TextEditingController(text: patient.gender);
    contactController = TextEditingController(text: patient.contact);
    admissionReasonController = TextEditingController(
      text: patient.admissionReason,
    );
    symptomsController = TextEditingController(
      text: patient.symptoms.join(', '),
    );
    allergiesController = TextEditingController(
      text: patient.allergies.join(', '),
    );
    usualMedicationController = TextEditingController(
      text: patient.usualMedication,
    );
    medicalHistoryController = TextEditingController(
      text: patient.medicalHistory,
    );
    medicalNotesController = TextEditingController(text: patient.medicalNotes);
    triageLevel = triageLevels.contains(patient.triageLevel)
        ? patient.triageLevel
        : 'Amarelo';
    careStatus = careStatuses.contains(patient.careStatus)
        ? patient.careStatus
        : 'Em observação';
  }

  @override
  void dispose() {
    healthNumberController.dispose();
    genderController.dispose();
    contactController.dispose();
    admissionReasonController.dispose();
    symptomsController.dispose();
    allergiesController.dispose();
    usualMedicationController.dispose();
    medicalHistoryController.dispose();
    medicalNotesController.dispose();
    super.dispose();
  }

  List<String> parseList(String value) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<void> saveRecord() async {
    if (admissionReasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indica o motivo de entrada.')),
      );
      return;
    }

    final patient = widget.patient;
    patient
      ..healthNumber = healthNumberController.text.trim()
      ..gender = genderController.text.trim()
      ..contact = contactController.text.trim()
      ..admissionReason = admissionReasonController.text.trim()
      ..usualMedication = usualMedicationController.text.trim()
      ..medicalHistory = medicalHistoryController.text.trim()
      ..triageLevel = triageLevel
      ..careStatus = careStatus
      ..medicalNotes = medicalNotesController.text.trim();
    patient.symptoms
      ..clear()
      ..addAll(parseList(symptomsController.text));
    patient.allergies
      ..clear()
      ..addAll(parseList(allergiesController.text));
    patient.history.add(
      ClinicalRecord(
        description:
            'Ficha clínica atualizada por ${currentProfessionalName()}.',
        dateTime: formatExactDateTime(DateTime.now()),
      ),
    );

    try {
      await updatePatientRecordInSupabase(patient);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao guardar ficha no Supabase: $error')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  Widget recordField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    String? hintText,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: const OutlineInputBorder(),
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!canUsePatient(widget.patient, AppPermission.editPatientRecord)) {
      return const AccessDeniedPage(
        reason: 'Este cargo não pode editar fichas clínicas.',
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Ficha Clínica')),
      body: Center(
        child: SizedBox(
          width: 680,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              recordField(
                controller: healthNumberController,
                label: 'Número de utente',
              ),
              const SizedBox(height: 12),
              recordField(controller: genderController, label: 'Género'),
              const SizedBox(height: 12),
              recordField(controller: contactController, label: 'Contacto'),
              const SizedBox(height: 12),
              recordField(
                controller: admissionReasonController,
                label: 'Motivo de entrada',
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              recordField(
                controller: symptomsController,
                label: 'Sintomas principais',
                hintText: 'Separados por vírgulas',
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              recordField(
                controller: allergiesController,
                label: 'Alergias',
                hintText: 'Separadas por vírgulas',
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              recordField(
                controller: usualMedicationController,
                label: 'Medicação habitual',
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              recordField(
                controller: medicalHistoryController,
                label: 'Antecedentes médicos',
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: triageLevel,
                decoration: const InputDecoration(
                  labelText: 'Nível de triagem',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final level in triageLevels)
                    DropdownMenuItem(value: level, child: Text(level)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      triageLevel = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: careStatus,
                decoration: const InputDecoration(
                  labelText: 'Estado assistencial',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final status in careStatuses)
                    DropdownMenuItem(value: status, child: Text(status)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      careStatus = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              recordField(
                controller: medicalNotesController,
                label: 'Observações da equipa médica',
                maxLines: 4,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Guardar Ficha Clínica'),
                onPressed: saveRecord,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UpdateVitalsPage extends StatefulWidget {
  final Patient patient;

  const UpdateVitalsPage({super.key, required this.patient});

  @override
  State<UpdateVitalsPage> createState() => _UpdateVitalsPageState();
}

class _UpdateVitalsPageState extends State<UpdateVitalsPage> {
  late TextEditingController heartRateController;
  late TextEditingController temperatureController;
  late TextEditingController oxygenController;

  @override
  void initState() {
    super.initState();

    heartRateController = TextEditingController(
      text: widget.patient.heartRate.toString(),
    );

    temperatureController = TextEditingController(
      text: widget.patient.temperature.toString(),
    );

    oxygenController = TextEditingController(
      text: widget.patient.oxygen.toString(),
    );
  }

  Future<void> updateVitals() async {
    if (heartRateController.text.isEmpty ||
        temperatureController.text.isEmpty ||
        oxygenController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preenche todos os campos.')),
      );
      return;
    }

    final newHeartRate = int.parse(heartRateController.text);
    final newTemperature = double.parse(
      temperatureController.text.replaceAll(',', '.'),
    );
    final newOxygen = int.parse(oxygenController.text);

    widget.patient.heartRate = newHeartRate;
    widget.patient.temperature = newTemperature;
    widget.patient.oxygen = newOxygen;
    widget.patient.status = calculatePatientStatus(
      newHeartRate,
      newTemperature,
      newOxygen,
    );

    widget.patient.history.add(
      ClinicalRecord(
        description:
            'Sinais vitais atualizados: FC $newHeartRate bpm, Temp $newTemperature ºC, Oxigénio $newOxygen%. Estado: ${widget.patient.status}.',
        dateTime: getCurrentDateTime(),
      ),
    );

    try {
      await updatePatientRecordInSupabase(widget.patient);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao guardar sinais vitais: $error')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (!canUsePatient(widget.patient, AppPermission.updateVitals)) {
      return const AccessDeniedPage(
        reason: 'Este cargo não pode atualizar sinais vitais.',
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Atualizar Sinais Vitais')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: heartRateController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Batimentos cardíacos',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: temperatureController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Temperatura',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: oxygenController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Oxigénio',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Guardar Sinais Vitais'),
                onPressed: updateVitals,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddMedicationPage extends StatefulWidget {
  final Patient patient;
  final Medication? medication;

  const AddMedicationPage({super.key, required this.patient, this.medication});

  @override
  State<AddMedicationPage> createState() => _AddMedicationPageState();
}

class _AddMedicationPageState extends State<AddMedicationPage> {
  final nameController = TextEditingController();
  final doseController = TextEditingController();
  final timeController = TextEditingController();
  late final TextEditingController responsibleController;

  bool administered = false;
  bool isSaving = false;

  bool get isEditing => widget.medication != null;

  @override
  void initState() {
    super.initState();
    final medication = widget.medication;
    if (medication != null) {
      nameController.text = medication.name;
      doseController.text = medication.dose;
      timeController.text = medication.time;
      administered = medication.administered;
    }
    responsibleController = TextEditingController(
      text: medication?.responsibleProfessional ?? currentProfessionalName(),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    doseController.dispose();
    timeController.dispose();
    responsibleController.dispose();
    super.dispose();
  }

  List<String> get allergyMatches {
    final medicationName = nameController.text.toLowerCase();
    return widget.patient.allergies.where((allergy) {
      final normalizedAllergy = allergy.toLowerCase().trim();
      return normalizedAllergy.isNotEmpty &&
          medicationName.contains(normalizedAllergy);
    }).toList();
  }

  Future<void> saveMedication() async {
    if (nameController.text.isEmpty ||
        doseController.text.isEmpty ||
        timeController.text.isEmpty ||
        responsibleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preenche todos os campos.')),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      if (isEditing) {
        final medication = widget.medication!;
        medication
          ..name = nameController.text.trim()
          ..dose = doseController.text.trim()
          ..time = timeController.text.trim()
          ..responsibleProfessional = responsibleController.text.trim()
          ..administered = administered;

        await updateMedicationInSupabase(widget.patient, medication);
        widget.patient.history.add(
          ClinicalRecord(
            description:
                'Medicação editada: ${medication.name}, dose ${medication.dose}, às ${medication.time}, responsável ${medication.responsibleProfessional}.',
            dateTime: formatExactDateTime(DateTime.now()),
          ),
        );
      } else {
        final medication = Medication(
          name: nameController.text.trim(),
          dose: doseController.text.trim(),
          time: timeController.text.trim(),
          responsibleProfessional: responsibleController.text.trim(),
          administered: administered,
        );
        final savedMedication = await insertMedicationInSupabase(
          widget.patient,
          medication,
        );
        widget.patient.medications.add(savedMedication);
        widget.patient.history.add(
          ClinicalRecord(
            description:
                'Nova medicação adicionada: ${savedMedication.name}, dose ${savedMedication.dose}, às ${savedMedication.time}, responsável ${savedMedication.responsibleProfessional}. Estado inicial: ${administered ? 'Administrado' : 'Pendente'}.',
            dateTime: formatExactDateTime(DateTime.now()),
          ),
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao guardar medicação: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!canUsePatient(widget.patient, AppPermission.manageMedication)) {
      return const AccessDeniedPage(
        reason: 'Este cargo não pode gerir medicação.',
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Medicação' : 'Adicionar Medicação'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nome do medicamento',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: doseController,
              decoration: const InputDecoration(
                labelText: 'Dose',
                hintText: 'Ex: 500 mg',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: timeController,
              decoration: const InputDecoration(
                labelText: 'Horário',
                hintText: 'Ex: 08:00',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: responsibleController,
              decoration: const InputDecoration(
                labelText: 'Profissional responsável',
                border: OutlineInputBorder(),
              ),
            ),

            if (allergyMatches.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Atenção: este paciente tem alergia registada a ${allergyMatches.join(', ')}.',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            SwitchListTile(
              title: const Text('Já foi administrado?'),
              value: administered,
              onChanged: (value) {
                setState(() {
                  administered = value;
                });
              },
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: Text(isSaving ? 'A guardar...' : 'Guardar Medicação'),
                onPressed: isSaving ? null : saveMedication,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ClinicalHistoryPage extends StatelessWidget {
  final Patient patient;

  const ClinicalHistoryPage({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    final reversedHistory = patient.history.reversed.toList();

    return Scaffold(
      appBar: AppBar(title: Text('Histórico - ${patient.name}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: reversedHistory.isEmpty
            ? const Center(child: Text('Ainda não existe histórico clínico.'))
            : ListView.builder(
                itemCount: reversedHistory.length,
                itemBuilder: (context, index) {
                  final record = reversedHistory[index];

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.history, color: Colors.blue),
                      title: Text(record.description),
                      subtitle: Text(record.dateTime),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class ClinicalSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const ClinicalSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const InfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class VitalCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const VitalCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
