import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://mdhycsmxgaqnrvbqmazd.supabase.co/rest/v1/',
    anonKey: 'sb_publishable_iNXLMuZS2kfpjg5_KI7lOw_LyiVvOhD',
  );

  runApp(const SAUHApp());
}

final supabase = Supabase.instance.client;

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

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FF),
      body: Center(
        child: Container(
          width: 350,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_hospital, size: 60, color: Colors.blue),
              const SizedBox(height: 10),
              const Text(
                'SAUH',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),
              const Text('Sistema de Apoio em Urgências Hospitalares'),
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
                  child: const Text('Entrar'),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const DashboardPage()),
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

class ClinicalRecord {
  final String description;
  final String dateTime;

  ClinicalRecord({required this.description, required this.dateTime});
}

class Medication {
  final String name;
  final String time;
  bool administered;

  Medication({
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

final patients = [
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

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final searchController = TextEditingController();
  String searchText = '';
  bool isLoading = false;
  @override
  void initState() {
    super.initState();
    loadPatientsFromSupabase();
  }

  Future<void> loadPatientsFromSupabase() async {
    setState(() {
      isLoading = true;
    });

    try {
      final patientRows = await supabase
          .from('patients')
          .select()
          .order('created_at', ascending: true);

      final loadedPatients = <Patient>[];

      for (final patientData in patientRows) {
        final patientId = patientData['id'];

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

        final patient = Patient(
          id: patientData['id'],
          name: patientData['name'],
          age: patientData['age'],
          room: patientData['room'],
          status: patientData['status'],
          heartRate: patientData['heart_rate'],
          temperature: (patientData['temperature'] as num).toDouble(),
          oxygen: patientData['oxygen'],
          medications: medicationRows.map<Medication>((medicationData) {
            return Medication(
              name: medicationData['name'],
              time: medicationData['time'],
              administered: medicationData['administered'],
            );
          }).toList(),
          history: historyRows.map<ClinicalRecord>((historyData) {
            return ClinicalRecord(
              description: historyData['description'],
              dateTime: historyData['date_time'],
            );
          }).toList(),
        );

        loadedPatients.add(patient);
      }

      patients.clear();
      patients.addAll(loadedPatients);
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao carregar dados: $error')));
    }

    setState(() {
      isLoading = false;
    });
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
    final filteredPatients = patients.where((patient) {
      final search = searchText.toLowerCase();

      return patient.name.toLowerCase().contains(search) ||
          patient.room.toLowerCase().contains(search) ||
          patient.status.toLowerCase().contains(search);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('SAUH - Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
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

          setState(() {});
        },
      ),

      body: Container(
        color: const Color(0xFFF3F7FB),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
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

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Alertas Recentes',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
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

                    const SizedBox(height: 20),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Lista de Pacientes',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        labelText: 'Pesquisar paciente, quarto ou estado',
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

                    Expanded(
                      child: ListView.builder(
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
                              trailing: Text(
                                patient.status,
                                style: TextStyle(
                                  color: getStatusColor(patient.status),
                                  fontWeight: FontWeight.bold,
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
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.symmetric(horizontal: 6),
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
        history: [
          ClinicalRecord(
            description: 'Paciente adicionado manualmente.',
            dateTime: getCurrentDateTime(),
          ),
        ],
      );

      patients.add(newPatient);

      await supabase.from('clinical_history').insert({
        'patient_id': insertedPatient['id'],
        'description': 'Paciente adicionado manualmente.',
        'date_time': getCurrentDateTime(),
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
  @override
  Widget build(BuildContext context) {
    final patient = widget.patient;

    return Scaffold(
      appBar: AppBar(title: Text(patient.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            InfoRow(label: 'Idade', value: '${patient.age} anos'),
            InfoRow(label: 'Quarto', value: patient.room),
            InfoRow(label: 'Estado', value: patient.status),

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
                                    onPressed: () {
                                      setState(() {
                                        medication.administered = true;

                                        patient.history.add(
                                          ClinicalRecord(
                                            description:
                                                'Medicação administrada: ${medication.name}.',
                                            dateTime: getCurrentDateTime(),
                                          ),
                                        );
                                      });

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${medication.name} administrado com sucesso.',
                                          ),
                                        ),
                                      );
                                    },
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

  void updateVitals() {
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

    Navigator.pop(context);
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

  void addMedication() {
    if (nameController.text.isEmpty || timeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preenche todos os campos.')),
      );
      return;
    }

    widget.patient.medications.add(
      Medication(
        name: nameController.text,
        time: timeController.text,
        administered: administered,
      ),
    );

    widget.patient.history.add(
      ClinicalRecord(
        description:
            'Nova medicação adicionada: ${nameController.text} às ${timeController.text}. Estado inicial: ${administered ? 'Administrado' : 'Pendente'}.',
        dateTime: getCurrentDateTime(),
      ),
    );

    Navigator.pop(context);
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
