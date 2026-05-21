import 'package:flutter/material.dart';

void main() {
  runApp(const SAUHApp());
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
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 12),
            ],
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
                      MaterialPageRoute(
                        builder: (_) => const DashboardPage(),
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

class Patient {
  final String name;
  final int age;
  final String room;
  final String status;
  final int heartRate;
  final double temperature;
  final int oxygen;

  Patient({
    required this.name,
    required this.age,
    required this.room,
    required this.status,
    required this.heartRate,
    required this.temperature,
    required this.oxygen,
  });
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
  ),
  Patient(
    name: 'Ana Costa',
    age: 45,
    room: 'U08',
    status: 'Normal',
    heartRate: 78,
    temperature: 36.7,
    oxygen: 98,
  ),
  Patient(
    name: 'Carlos Mendes',
    age: 59,
    room: 'U15',
    status: 'Atenção',
    heartRate: 122,
    temperature: 37.9,
    oxygen: 93,
  ),
];

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  Color getStatusColor(String status) {
    if (status == 'Crítico') return Colors.red;
    if (status == 'Atenção') return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final criticalCount =
        patients.where((patient) => patient.status == 'Crítico').length;

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
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                InfoCard(title: 'Pacientes', value: '${patients.length}'),
                InfoCard(title: 'Críticos', value: '$criticalCount'),
                InfoCard(title: 'Alertas', value: '$criticalCount'),
              ],
            ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Lista de Pacientes',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: patients.length,
                itemBuilder: (context, index) {
                  final patient = patients[index];

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
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PatientDetailsPage(patient: patient),
                          ),
                        );
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

class InfoCard extends StatelessWidget {
  final String title;
  final String value;

  const InfoCard({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Text(title),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PatientDetailsPage extends StatelessWidget {
  final Patient patient;

  const PatientDetailsPage({
    super.key,
    required this.patient,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(patient.name),
      ),
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
          ],
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
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