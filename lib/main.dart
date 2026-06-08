import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://mdhycsmxgaqnrvbqmazd.supabase.co',
    anonKey: 'sb_publishable_iNXLMuZS2kfpjg5_KI7lOw_LyiVvOhD',
  );

  final rememberSession = await loadRememberSessionPreference();

  if (!rememberSession && supabase.auth.currentSession != null) {
    await supabase.auth.signOut();
  }

  runApp(
    SAUHApp(
      initialRememberSession: rememberSession,
      startAuthenticated:
          rememberSession && supabase.auth.currentSession != null,
    ),
  );
}

final supabase = Supabase.instance.client;

File getSessionSettingsFile() {
  final baseDirectory =
      Platform.environment['APPDATA'] ??
      Platform.environment['LOCALAPPDATA'] ??
      Directory.current.path;
  final settingsDirectory = Directory(
    '$baseDirectory${Platform.pathSeparator}SAUH',
  );

  return File(
    '${settingsDirectory.path}${Platform.pathSeparator}settings.json',
  );
}

Future<bool> loadRememberSessionPreference() async {
  try {
    final settingsFile = getSessionSettingsFile();

    if (!await settingsFile.exists()) return false;

    final data = jsonDecode(await settingsFile.readAsString());
    return data is Map && data['remember_session'] == true;
  } catch (_) {
    return false;
  }
}

Future<void> saveRememberSessionPreference(bool rememberSession) async {
  final settingsFile = getSessionSettingsFile();
  await settingsFile.parent.create(recursive: true);
  await settingsFile.writeAsString(
    jsonEncode({'remember_session': rememberSession}),
  );
}

const sauhPrimary = Color(0xFF0B6BCB);
const sauhPrimaryDark = Color(0xFF084A8F);
const sauhAccent = Color(0xFF18A7A7);
const sauhBackground = Color(0xFFF4F8FC);
const sauhSurface = Colors.white;
const sauhText = Color(0xFF172033);

class SAUHApp extends StatelessWidget {
  final bool initialRememberSession;
  final bool startAuthenticated;

  const SAUHApp({
    super.key,
    this.initialRememberSession = false,
    this.startAuthenticated = false,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAUH',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: sauhPrimary,
          primary: sauhPrimary,
          secondary: sauhAccent,
          surface: sauhSurface,
        ),
        scaffoldBackgroundColor: sauhBackground,
        fontFamily: 'Segoe UI',
        appBarTheme: const AppBarTheme(
          backgroundColor: sauhPrimary,
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        cardTheme: CardThemeData(
          color: sauhSurface,
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.blueGrey.shade100),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: sauhPrimary, width: 1.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: sauhPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: sauhPrimary,
            side: const BorderSide(color: sauhPrimary),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: sauhAccent,
          foregroundColor: Colors.white,
        ),
      ),
      home: startAuthenticated
          ? const DashboardPage()
          : LoginPage(initialRememberSession: initialRememberSession),
    );
  }
}

class LoginPage extends StatefulWidget {
  final bool initialRememberSession;

  const LoginPage({super.key, this.initialRememberSession = false});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoggingIn = false;
  bool isCreatingAccount = false;
  late bool rememberSession;

  @override
  void initState() {
    super.initState();
    rememberSession = widget.initialRememberSession;
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> loginWithSupabase() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preenche o email e a palavra-passe.')),
      );
      return;
    }

    setState(() {
      isLoggingIn = true;
    });

    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (response.user == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Login inválido.')));
        return;
      }

      await saveRememberSessionPreference(rememberSession);
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    } on AuthException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro de autenticação: ${error.message}')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao iniciar sessão: $error')));
    } finally {
      if (mounted) {
        setState(() {
          isLoggingIn = false;
        });
      }
    }
  }

  Future<void> createAccountWithSupabase() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preenche o email e a palavra-passe.')),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A palavra-passe deve ter pelo menos 6 caracteres.'),
        ),
      );
      return;
    }

    setState(() {
      isLoggingIn = true;
    });

    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (response.user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível criar a conta.')),
        );
        return;
      }

      if (response.session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Conta criada. Confirma o email antes de iniciar sessão.',
            ),
          ),
        );

        setState(() {
          isCreatingAccount = false;
        });
        return;
      }

      await saveRememberSessionPreference(rememberSession);
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    } on AuthException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao criar conta: ${error.message}')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao criar conta: $error')));
    } finally {
      if (mounted) {
        setState(() {
          isLoggingIn = false;
        });
      }
    }
  }

  void toggleAuthMode() {
    setState(() {
      isCreatingAccount = !isCreatingAccount;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: 430,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueGrey.withAlpha(32),
                    blurRadius: 30,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        colors: [sauhPrimary, sauhAccent],
                      ),
                    ),
                    child: const Icon(
                      Icons.local_hospital,
                      size: 46,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'SAUH',
                    style: TextStyle(
                      color: sauhText,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sistema de Apoio em Urgências Hospitalares',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 28),

                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),

                  const SizedBox(height: 15),

                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Palavra-passe',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: rememberSession,
                        onChanged: isLoggingIn
                            ? null
                            : (value) {
                                setState(() {
                                  rememberSession = value ?? false;
                                });
                              },
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Manter sessão iniciada',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Entrar automaticamente da próxima vez.',
                                style: TextStyle(
                                  color: Colors.blueGrey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoggingIn
                          ? null
                          : isCreatingAccount
                          ? createAccountWithSupabase
                          : loginWithSupabase,
                      child: isLoggingIn
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(isCreatingAccount ? 'Criar conta' : 'Entrar'),
                    ),
                  ),

                  const SizedBox(height: 10),

                  TextButton(
                    onPressed: isLoggingIn ? null : toggleAuthMode,
                    child: Text(
                      isCreatingAccount ? 'Já tenho conta' : 'Criar nova conta',
                    ),
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

class ClinicalRecord {
  final String description;
  final String dateTime;

  ClinicalRecord({required this.description, required this.dateTime});
}

class Medication {
  final String? id;
  final String name;
  final String time;
  bool administered;

  Medication({
    this.id,
    required this.name,
    required this.time,
    required this.administered,
  });
}

class Patient {
  final String? id;
  final String name;
  final int age;
  final String room;
  String status;
  int heartRate;
  double temperature;
  int oxygen;
  final List<Medication> medications;
  final List<ClinicalRecord> history;

  Patient({
    this.id,
    required this.name,
    required this.age,
    required this.room,
    required this.status,
    required this.heartRate,
    required this.temperature,
    required this.oxygen,
    required this.medications,
    required this.history,
  });
}

String getCurrentDateTime() {
  final now = DateTime.now();

  return '${now.day.toString().padLeft(2, '0')}/'
      '${now.month.toString().padLeft(2, '0')}/'
      '${now.year} '
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}';
}

final patients = <Patient>[];

final mockPatients = [
  Patient(
    name: 'João Silva',
    age: 67,
    room: 'U12',
    status: 'Crítico',
    heartRate: 145,
    temperature: 39.0,
    oxygen: 88,
    medications: [
      Medication(name: 'Paracetamol', time: '08:00', administered: false),
      Medication(name: 'Aspirina', time: '12:00', administered: true),
    ],
    history: [
      ClinicalRecord(
        description: 'Paciente registado no sistema.',
        dateTime: 'Registo inicial',
      ),
    ],
  ),
  Patient(
    name: 'Ana Costa',
    age: 45,
    room: 'U08',
    status: 'Normal',
    heartRate: 78,
    temperature: 36.7,
    oxygen: 98,
    medications: [
      Medication(name: 'Ibuprofeno', time: '10:00', administered: true),
    ],
    history: [
      ClinicalRecord(
        description: 'Paciente registado no sistema.',
        dateTime: 'Registo inicial',
      ),
    ],
  ),
  Patient(
    name: 'Carlos Mendes',
    age: 59,
    room: 'U15',
    status: 'Atenção',
    heartRate: 122,
    temperature: 37.9,
    oxygen: 93,
    medications: [
      Medication(name: 'Insulina', time: '09:00', administered: false),
    ],
    history: [
      ClinicalRecord(
        description: 'Paciente registado no sistema.',
        dateTime: 'Registo inicial',
      ),
    ],
  ),
];

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

List<PatientAlert> generateAlerts() {
  final alerts = <PatientAlert>[];

  for (final patient in patients) {
    if (patient.heartRate > 140 || patient.heartRate < 50) {
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

    if (patient.temperature > 38.5 || patient.temperature < 35) {
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

    for (final medication in patient.medications) {
      if (!medication.administered) {
        alerts.add(
          PatientAlert(
            patientName: patient.name,
            message:
                'Medicação pendente: ${medication.name} às ${medication.time}',
            level: 'Atenção',
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

int parseIntValue(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double parseDoubleValue(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse((value?.toString() ?? '').replaceAll(',', '.')) ??
      fallback;
}

bool parseBoolValue(dynamic value) {
  if (value is bool) return value;
  return value?.toString().toLowerCase() == 'true';
}

String parseTextValue(dynamic value, {String fallback = ''}) {
  return value?.toString() ?? fallback;
}

String currentUserDisplayName() {
  final user = supabase.auth.currentUser;
  final metadata = user?.userMetadata ?? <String, dynamic>{};
  final fullName = parseTextValue(metadata['full_name']).trim();

  if (fullName.isNotEmpty) return fullName;
  return user?.email ?? 'Utilizador autenticado';
}

String currentUserRole() {
  final metadata =
      supabase.auth.currentUser?.userMetadata ?? <String, dynamic>{};
  final role = parseTextValue(metadata['role']).trim();
  return role.isEmpty ? 'Profissional de saúde' : role;
}

bool canEditClinicalData() {
  return !currentUserRole().toLowerCase().contains('observador');
}

String auditDescription(String description) {
  return '${currentUserDisplayName()} (${currentUserRole()}): $description';
}

int patientPriority(Patient patient) {
  if (patient.status == 'Crítico') return 0;
  if (patient.status == 'Atenção') return 1;
  return 2;
}

String calculateManchesterTriage(Patient patient) {
  if (patient.status == 'Crítico' ||
      patient.heartRate > 140 ||
      patient.heartRate < 50 ||
      patient.oxygen < 90 ||
      patient.temperature > 38.5 ||
      patient.temperature < 35) {
    return 'Vermelho';
  }

  if (patient.status == 'Atenção' ||
      patient.heartRate > 120 ||
      patient.oxygen < 95 ||
      patient.temperature > 37.5) {
    return 'Laranja';
  }

  if (patient.medications.any((medication) => !medication.administered)) {
    return 'Amarelo';
  }

  return 'Verde';
}

Color getTriageColor(String triage) {
  if (triage == 'Vermelho') return Colors.red;
  if (triage == 'Laranja') return Colors.orange;
  if (triage == 'Amarelo') return Colors.amber;
  return Colors.green;
}

String clinicalRecordCategory(ClinicalRecord record) {
  final description = record.description.toLowerCase();

  if (description.contains('sinais vitais')) return 'Sinais vitais';
  if (description.contains('medicação') || description.contains('medica')) {
    return 'Medicação';
  }
  if (description.contains('nota clínica') || description.contains('nota')) {
    return 'Notas';
  }
  if (description.contains('paciente')) return 'Paciente';

  return 'Outros';
}

Medication medicationFromSupabase(Map<String, dynamic> data) {
  return Medication(
    id: parseTextValue(data['id']),
    name: parseTextValue(data['name']),
    time: parseTextValue(data['time']),
    administered: parseBoolValue(data['administered']),
  );
}

ClinicalRecord clinicalRecordFromSupabase(Map<String, dynamic> data) {
  return ClinicalRecord(
    description: parseTextValue(data['description']),
    dateTime: parseTextValue(data['date_time']),
  );
}

Patient patientFromSupabase(
  Map<String, dynamic> data,
  List<Medication> medications,
  List<ClinicalRecord> history,
) {
  final heartRate = parseIntValue(data['heart_rate']);
  final temperature = parseDoubleValue(data['temperature']);
  final oxygen = parseIntValue(data['oxygen']);
  final storedStatus = parseTextValue(data['status']);

  return Patient(
    id: parseTextValue(data['id']),
    name: parseTextValue(data['name']),
    age: parseIntValue(data['age']),
    room: parseTextValue(data['room']),
    status: storedStatus.isEmpty
        ? calculatePatientStatus(heartRate, temperature, oxygen)
        : storedStatus,
    heartRate: heartRate,
    temperature: temperature,
    oxygen: oxygen,
    medications: medications,
    history: history,
  );
}

class PageBackground extends StatelessWidget {
  final Widget child;

  const PageBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8FBFF), Color(0xFFEAF4FF)],
        ),
      ),
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const SectionTitle({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Icon(icon, color: sauhPrimary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: sauhText,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const StatusPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
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
  final searchController = TextEditingController();
  String searchText = '';
  String selectedStatusFilter = 'Todos';
  bool isLoading = false;
  String? loadError;
  RealtimeChannel? patientsChannel;
  RealtimeChannel? medicationsChannel;
  RealtimeChannel? historyChannel;

  @override
  void initState() {
    super.initState();
    loadPatientsFromSupabase();
    subscribeToRealtimeUpdates();
  }

  @override
  void dispose() {
    if (patientsChannel != null) {
      supabase.removeChannel(patientsChannel!);
    }
    if (medicationsChannel != null) {
      supabase.removeChannel(medicationsChannel!);
    }
    if (historyChannel != null) {
      supabase.removeChannel(historyChannel!);
    }
    searchController.dispose();
    super.dispose();
  }

  void subscribeToRealtimeUpdates() {
    patientsChannel = supabase
        .channel('sauh-patients-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'patients',
          callback: (_) {
            if (mounted) loadPatientsFromSupabase(showLoading: false);
          },
        )
        .subscribe();

    medicationsChannel = supabase
        .channel('sauh-medications-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'medications',
          callback: (_) {
            if (mounted) loadPatientsFromSupabase(showLoading: false);
          },
        )
        .subscribe();

    historyChannel = supabase
        .channel('sauh-history-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'clinical_history',
          callback: (_) {
            if (mounted) loadPatientsFromSupabase(showLoading: false);
          },
        )
        .subscribe();
  }

  Future<void> loadPatientsFromSupabase({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        isLoading = true;
        loadError = null;
      });
    }

    try {
      final patientRows = await supabase
          .from('patients')
          .select()
          .order('created_at', ascending: false);

      final loadedPatients = <Patient>[];

      for (final patientRow in patientRows) {
        final patientData = Map<String, dynamic>.from(patientRow);
        final patientId = parseTextValue(patientData['id']);

        final medicationRows = await supabase
            .from('medications')
            .select()
            .eq('patient_id', patientId)
            .order('created_at', ascending: false);

        final historyRows = await supabase
            .from('clinical_history')
            .select()
            .eq('patient_id', patientId)
            .order('created_at', ascending: false);

        final medications = medicationRows
            .map(
              (medicationRow) => medicationFromSupabase(
                Map<String, dynamic>.from(medicationRow),
              ),
            )
            .toList();

        final history = historyRows
            .map(
              (historyRow) => clinicalRecordFromSupabase(
                Map<String, dynamic>.from(historyRow),
              ),
            )
            .toList();

        loadedPatients.add(
          patientFromSupabase(patientData, medications, history),
        );
      }

      if (!mounted) return;

      setState(() {
        patients
          ..clear()
          ..addAll(loadedPatients);
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        loadError = 'Erro ao carregar pacientes da cloud: $error';
      });
    }
  }

  Color getStatusColor(String status) {
    if (status == 'Crítico') return Colors.red;
    if (status == 'Atenção') return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final criticalCount = patients
        .where((patient) => patient.status == 'Crítico')
        .length;

    final alerts = generateAlerts();
    final filteredPatients =
        patients.where((patient) {
          final search = searchText.toLowerCase();
          final matchesStatus =
              selectedStatusFilter == 'Todos' ||
              patient.status == selectedStatusFilter;

          final matchesSearch =
              patient.name.toLowerCase().contains(search) ||
              patient.room.toLowerCase().contains(search) ||
              patient.status.toLowerCase().contains(search) ||
              calculateManchesterTriage(patient).toLowerCase().contains(search);

          return matchesStatus && matchesSearch;
        }).toList()..sort((first, second) {
          final priorityCompare = patientPriority(
            first,
          ).compareTo(patientPriority(second));
          if (priorityCompare != 0) return priorityCompare;
          return first.room.compareTo(second.room);
        });

    return Scaffold(
      appBar: AppBar(
        title: const Text('SAUH - Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Editar conta',
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await saveRememberSessionPreference(false);
              await supabase.auth.signOut();
              if (!context.mounted) return;

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Adicionar Paciente'),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddPatientPage()),
          );

          await loadPatientsFromSupabase();
        },
      ),

      body: PageBackground(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  InfoCard(
                    title: 'Pacientes',
                    value: '${patients.length}',
                    icon: Icons.people,
                    color: Colors.blue,
                  ),
                  InfoCard(
                    title: 'Críticos',
                    value: '$criticalCount',
                    icon: Icons.emergency,
                    color: Colors.red,
                  ),
                  InfoCard(
                    title: 'Alertas',
                    value: '${alerts.length}',
                    icon: Icons.warning,
                    color: Colors.orange,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              const SectionTitle(
                title: 'Alertas Recentes',
                icon: Icons.notifications_active,
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
                              trailing: StatusPill(
                                label: alert.level,
                                color: alert.level == 'Crítico'
                                    ? Colors.red
                                    : Colors.orange,
                              ),
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 20),

              const SectionTitle(
                title: 'Lista de Pacientes',
                icon: Icons.groups,
              ),

              TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  labelText: 'Pesquisar paciente, quarto, estado ou triagem',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    searchText = value;
                  });
                },
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedStatusFilter,
                      decoration: const InputDecoration(
                        labelText: 'Filtrar por estado',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                        DropdownMenuItem(
                          value: 'Normal',
                          child: Text('Normal'),
                        ),
                        DropdownMenuItem(
                          value: 'Atenção',
                          child: Text('Atenção'),
                        ),
                        DropdownMenuItem(
                          value: 'Crítico',
                          child: Text('Crítico'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedStatusFilter = value ?? 'Todos';
                        });
                      },
                    ),
                  ),

                  const SizedBox(width: 10),

                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Atualizar'),
                    onPressed: () {
                      loadPatientsFromSupabase();
                    },
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : loadError != null
                    ? Center(child: Text(loadError!))
                    : filteredPatients.isEmpty
                    ? const Center(
                        child: Text('Não existem pacientes para mostrar.'),
                      )
                    : ListView.builder(
                        itemCount: filteredPatients.length,
                        itemBuilder: (context, index) {
                          final patient = filteredPatients[index];

                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: getStatusColor(patient.status),
                              ),
                              title: Text(patient.name),
                              subtitle: Text('Quarto: ${patient.room}'),
                              trailing: StatusPill(
                                label:
                                    '${patient.status} · ${calculateManchesterTriage(patient)}',
                                color: getTriageColor(
                                  calculateManchesterTriage(patient),
                                ),
                              ),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        PatientDetailsPage(patient: patient),
                                  ),
                                );

                                setState(() {});
                              },
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
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withAlpha(170)],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(42),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(45),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),

            const SizedBox(width: 14),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),

                const SizedBox(height: 6),

                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
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
    loadUserProfile();
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

  void loadUserProfile() {
    final user = supabase.auth.currentUser;
    final metadata = user?.userMetadata ?? <String, dynamic>{};

    nameController.text = parseTextValue(metadata['full_name']);
    emailController.text = user?.email ?? '';
    phoneController.text = parseTextValue(metadata['phone']);
    roleController.text = parseTextValue(metadata['role']);
    professionalIdController.text = parseTextValue(metadata['professional_id']);
    departmentController.text = parseTextValue(metadata['department']);
    avatarUrlController.text = parseTextValue(metadata['avatar_url']);
  }

  bool isValidImageUrl(String value) {
    if (value.trim().isEmpty) return true;
    final uri = Uri.tryParse(value.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  Future<void> saveUserProfile() async {
    final user = supabase.auth.currentUser;
    final email = emailController.text.trim();
    final newPassword = newPasswordController.text;
    final avatarUrl = avatarUrlController.text.trim();

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Não existe sessão ativa.')));
      return;
    }

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
          content: Text('A imagem de perfil deve ser um URL http ou https.'),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await supabase.auth.updateUser(
        UserAttributes(
          email: email == user.email ? null : email,
          password: newPassword.isEmpty ? null : newPassword,
          data: {
            'full_name': nameController.text.trim(),
            'phone': phoneController.text.trim(),
            'role': roleController.text.trim(),
            'professional_id': professionalIdController.text.trim(),
            'department': departmentController.text.trim(),
            'avatar_url': avatarUrl,
          },
        ),
      );

      if (!mounted) return;

      newPasswordController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conta atualizada com sucesso.')),
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

  @override
  Widget build(BuildContext context) {
    final avatarUrl = avatarUrlController.text.trim();
    final avatarImage = isValidImageUrl(avatarUrl) && avatarUrl.isNotEmpty
        ? NetworkImage(avatarUrl)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Conta')),
      body: PageBackground(
        child: Center(
          child: SizedBox(
            width: 520,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: ListView(
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor: Colors.blue.shade100,
                          backgroundImage: avatarImage,
                          child: avatarImage == null
                              ? const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.blue,
                                )
                              : null,
                        ),
                      ),

                      const SizedBox(height: 20),

                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome completo',
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
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Telemóvel',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextField(
                        controller: roleController,
                        decoration: const InputDecoration(
                          labelText: 'Função',
                          hintText: 'Ex: Médico, Enfermeiro',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextField(
                        controller: professionalIdController,
                        decoration: const InputDecoration(
                          labelText: 'N.º profissional',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextField(
                        controller: departmentController,
                        decoration: const InputDecoration(
                          labelText: 'Serviço / Departamento',
                          hintText: 'Ex: Urgência, Pediatria',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextField(
                        controller: avatarUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Imagem de perfil (URL)',
                          hintText: 'https://exemplo.com/foto.png',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          setState(() {});
                        },
                      ),

                      const SizedBox(height: 12),

                      TextField(
                        controller: newPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Nova palavra-passe (opcional)',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: isSaving
                              ? const Text('A guardar...')
                              : const Text('Guardar Conta'),
                          onPressed: isSaving ? null : saveUserProfile,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
  final ageController = TextEditingController();
  final roomController = TextEditingController();
  final heartRateController = TextEditingController();
  final temperatureController = TextEditingController();
  final oxygenController = TextEditingController();

  String selectedStatus = 'Normal';

  Future<void> addPatient() async {
    if (nameController.text.isEmpty ||
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
    final record = ClinicalRecord(
      description: auditDescription('Paciente adicionado manualmente.'),
      dateTime: getCurrentDateTime(),
    );

    try {
      final insertedPatient = await supabase
          .from('patients')
          .insert({
            'name': nameController.text,
            'age': age,
            'room': roomController.text,
            'status': status,
            'heart_rate': heartRate,
            'temperature': temperature,
            'oxygen': oxygen,
          })
          .select()
          .single();

      final newPatient = Patient(
        id: insertedPatient['id'],
        name: nameController.text,
        age: age,
        room: roomController.text,
        status: status,
        heartRate: heartRate,
        temperature: temperature,
        oxygen: oxygen,
        medications: [],
        history: [record],
      );

      patients.add(newPatient);

      await supabase.from('clinical_history').insert({
        'patient_id': insertedPatient['id'],
        'description': record.description,
        'date_time': record.dateTime,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paciente guardado na cloud.')),
      );

      Navigator.pop(context);
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao guardar paciente: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar Paciente')),
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
                labelText: 'Quarto',
                border: OutlineInputBorder(),
              ),
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
  Future<void> confirmMedication(Patient patient, Medication medication) async {
    final patientId = patient.id;
    final medicationId = medication.id;

    if (patientId == null || patientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paciente sem id da cloud.')),
      );
      return;
    }

    if (medicationId == null || medicationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medicação sem id da cloud.')),
      );
      return;
    }

    final record = ClinicalRecord(
      description: auditDescription(
        'Medicação administrada: ${medication.name}.',
      ),
      dateTime: getCurrentDateTime(),
    );

    try {
      await supabase
          .from('medications')
          .update({'administered': true})
          .eq('id', medicationId);

      await supabase.from('clinical_history').insert({
        'patient_id': patientId,
        'description': record.description,
        'date_time': record.dateTime,
      });

      if (!mounted) return;

      setState(() {
        medication.administered = true;
        patient.history.add(record);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${medication.name} administrado com sucesso.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao confirmar medicação: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = widget.patient;
    final canEdit = canEditClinicalData();
    final triage = calculateManchesterTriage(patient);

    return Scaffold(
      appBar: AppBar(title: Text(patient.name)),
      body: PageBackground(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: getTriageColor(triage).withAlpha(35),
                        child: Icon(
                          Icons.personal_injury,
                          color: getTriageColor(triage),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              patient.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Idade: ${patient.age} anos · Quarto: ${patient.room}',
                            ),
                          ],
                        ),
                      ),
                      StatusPill(label: triage, color: getTriageColor(triage)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

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

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.monitor_heart),
                  label: const Text('Atualizar Sinais Vitais'),
                  onPressed: canEdit
                      ? () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  UpdateVitalsPage(patient: patient),
                            ),
                          );

                          setState(() {});
                        }
                      : null,
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

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.description),
                  label: const Text('Ver Resumo Clínico'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PatientReportPage(patient: patient),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),

              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.note_add),
                  label: const Text('Adicionar Nota Clínica'),
                  onPressed: canEdit
                      ? () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AddClinicalNotePage(patient: patient),
                            ),
                          );

                          setState(() {});
                        }
                      : null,
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  const Text(
                    'Medicação',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar'),
                    onPressed: canEdit
                        ? () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AddMedicationPage(patient: patient),
                              ),
                            );

                            setState(() {});
                          }
                        : null,
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Expanded(
                child: patient.medications.isEmpty
                    ? const Center(
                        child: Text('Este paciente ainda não tem medicação.'),
                      )
                    : ListView.builder(
                        itemCount: patient.medications.length,
                        itemBuilder: (context, index) {
                          final medication = patient.medications[index];

                          return Card(
                            child: ListTile(
                              leading: Icon(
                                medication.administered
                                    ? Icons.check_circle
                                    : Icons.pending_actions,
                                color: medication.administered
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              title: Text(medication.name),
                              subtitle: Text('Horário: ${medication.time}'),
                              trailing: medication.administered
                                  ? const Text(
                                      'Administrado',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : ElevatedButton(
                                      onPressed: canEdit
                                          ? () {
                                              confirmMedication(
                                                patient,
                                                medication,
                                              );
                                            }
                                          : null,
                                      child: const Text('Confirmar'),
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

    final newHeartRate = int.tryParse(heartRateController.text);
    final newTemperature = double.tryParse(
      temperatureController.text.replaceAll(',', '.'),
    );
    final newOxygen = int.tryParse(oxygenController.text);

    if (newHeartRate == null || newTemperature == null || newOxygen == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verifica os valores numéricos.')),
      );
      return;
    }

    final patientId = widget.patient.id;

    if (patientId == null || patientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paciente sem id da cloud.')),
      );
      return;
    }

    final newStatus = calculatePatientStatus(
      newHeartRate,
      newTemperature,
      newOxygen,
    );

    final record = ClinicalRecord(
      description: auditDescription(
        'Sinais vitais atualizados: FC $newHeartRate bpm, Temp $newTemperature ºC, Oxigénio $newOxygen%. Estado: $newStatus.',
      ),
      dateTime: getCurrentDateTime(),
    );

    try {
      await supabase
          .from('patients')
          .update({
            'heart_rate': newHeartRate,
            'temperature': newTemperature,
            'oxygen': newOxygen,
            'status': newStatus,
          })
          .eq('id', patientId);

      await supabase.from('clinical_history').insert({
        'patient_id': patientId,
        'description': record.description,
        'date_time': record.dateTime,
      });

      widget.patient.heartRate = newHeartRate;
      widget.patient.temperature = newTemperature;
      widget.patient.oxygen = newOxygen;
      widget.patient.status = newStatus;
      widget.patient.history.add(record);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar sinais vitais: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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

  const AddMedicationPage({super.key, required this.patient});

  @override
  State<AddMedicationPage> createState() => _AddMedicationPageState();
}

class _AddMedicationPageState extends State<AddMedicationPage> {
  final nameController = TextEditingController();
  final timeController = TextEditingController();

  bool administered = false;

  Future<void> addMedication() async {
    if (nameController.text.isEmpty || timeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preenche todos os campos.')),
      );
      return;
    }

    final patientId = widget.patient.id;

    if (patientId == null || patientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paciente sem id da cloud.')),
      );
      return;
    }

    final record = ClinicalRecord(
      description: auditDescription(
        'Nova medicação adicionada: ${nameController.text} às ${timeController.text}. Estado inicial: ${administered ? 'Administrado' : 'Pendente'}.',
      ),
      dateTime: getCurrentDateTime(),
    );

    try {
      final insertedMedication = await supabase
          .from('medications')
          .insert({
            'patient_id': patientId,
            'name': nameController.text,
            'time': timeController.text,
            'administered': administered,
          })
          .select()
          .single();

      await supabase.from('clinical_history').insert({
        'patient_id': patientId,
        'description': record.description,
        'date_time': record.dateTime,
      });

      widget.patient.medications.add(
        Medication(
          id: parseTextValue(insertedMedication['id']),
          name: nameController.text,
          time: timeController.text,
          administered: administered,
        ),
      );

      widget.patient.history.add(record);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao guardar medicação: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar Medicação')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nome do medicamento',
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
                label: const Text('Guardar Medicação'),
                onPressed: addMedication,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PatientReportPage extends StatelessWidget {
  final Patient patient;

  const PatientReportPage({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    final pendingMedications = patient.medications
        .where((medication) => !medication.administered)
        .toList();
    final latestHistory = patient.history.reversed.take(5).toList();
    final triage = calculateManchesterTriage(patient);

    return Scaffold(
      appBar: AppBar(title: Text('Resumo Clínico - ${patient.name}')),
      body: PageBackground(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InfoRow(label: 'Idade', value: '${patient.age} anos'),
                      InfoRow(label: 'Quarto', value: patient.room),
                      InfoRow(label: 'Estado', value: patient.status),
                      InfoRow(label: 'Triagem Manchester', value: triage),
                    ],
                  ),
                ),
              ),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sinais vitais',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Frequência cardíaca: ${patient.heartRate} bpm'),
                      Text('Temperatura: ${patient.temperature} ºC'),
                      Text('Oxigénio: ${patient.oxygen}%'),
                    ],
                  ),
                ),
              ),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Medicação pendente',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (pendingMedications.isEmpty)
                        const Text('Sem medicação pendente.')
                      else
                        ...pendingMedications.map(
                          (medication) =>
                              Text('${medication.name} às ${medication.time}'),
                        ),
                    ],
                  ),
                ),
              ),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Últimos registos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (latestHistory.isEmpty)
                        const Text('Sem histórico clínico.')
                      else
                        ...latestHistory.map(
                          (record) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '${record.dateTime} - ${record.description}',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddClinicalNotePage extends StatefulWidget {
  final Patient patient;

  const AddClinicalNotePage({super.key, required this.patient});

  @override
  State<AddClinicalNotePage> createState() => _AddClinicalNotePageState();
}

class _AddClinicalNotePageState extends State<AddClinicalNotePage> {
  final noteController = TextEditingController();
  bool isSaving = false;

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  Future<void> saveNote() async {
    final patientId = widget.patient.id;
    final note = noteController.text.trim();

    if (patientId == null || patientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paciente sem id da cloud.')),
      );
      return;
    }

    if (note.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Escreve a nota clínica.')));
      return;
    }

    final record = ClinicalRecord(
      description: auditDescription('Nota clínica: $note'),
      dateTime: getCurrentDateTime(),
    );

    setState(() {
      isSaving = true;
    });

    try {
      await supabase.from('clinical_history').insert({
        'patient_id': patientId,
        'description': record.description,
        'date_time': record.dateTime,
      });

      widget.patient.history.add(record);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao guardar nota clínica: $error')),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar Nota Clínica')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: noteController,
              minLines: 6,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'Nota clínica',
                hintText: 'Regista observações relevantes do paciente.',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: isSaving
                    ? const Text('A guardar...')
                    : const Text('Guardar Nota'),
                onPressed: isSaving ? null : saveNote,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ClinicalHistoryPage extends StatefulWidget {
  final Patient patient;

  const ClinicalHistoryPage({super.key, required this.patient});

  @override
  State<ClinicalHistoryPage> createState() => _ClinicalHistoryPageState();
}

class _ClinicalHistoryPageState extends State<ClinicalHistoryPage> {
  String selectedCategory = 'Todos';

  @override
  Widget build(BuildContext context) {
    final filteredHistory = widget.patient.history.where((record) {
      return selectedCategory == 'Todos' ||
          clinicalRecordCategory(record) == selectedCategory;
    }).toList();
    final reversedHistory = filteredHistory.reversed.toList();

    return Scaffold(
      appBar: AppBar(title: Text('Histórico - ${widget.patient.name}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Filtrar histórico',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                DropdownMenuItem(
                  value: 'Sinais vitais',
                  child: Text('Sinais vitais'),
                ),
                DropdownMenuItem(value: 'Medicação', child: Text('Medicação')),
                DropdownMenuItem(value: 'Notas', child: Text('Notas')),
                DropdownMenuItem(value: 'Paciente', child: Text('Paciente')),
                DropdownMenuItem(value: 'Outros', child: Text('Outros')),
              ],
              onChanged: (value) {
                setState(() {
                  selectedCategory = value ?? 'Todos';
                });
              },
            ),

            const SizedBox(height: 12),

            Expanded(
              child: reversedHistory.isEmpty
                  ? const Center(
                      child: Text('Ainda não existe histórico clínico.'),
                    )
                  : ListView.builder(
                      itemCount: reversedHistory.length,
                      itemBuilder: (context, index) {
                        final record = reversedHistory[index];
                        final category = clinicalRecordCategory(record);

                        return Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.history,
                              color: Colors.blue,
                            ),
                            title: Text(record.description),
                            subtitle: Text('${record.dateTime} · $category'),
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

class InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const InfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(value),
      ],
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: ListTile(
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: sauhPrimary.withAlpha(24),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: sauhPrimary),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          trailing: Text(
            value,
            style: const TextStyle(
              color: sauhText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
