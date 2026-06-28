enum AppRole {
  superAdmin('super_admin', 'Administrador do Sistema'),
  adminHospital('admin_hospital', 'Coordenador da Urgência'),
  diretorClinico('diretor_clinico', 'Diretor Clínico da Urgência'),
  chefeEnfermagem('chefe_enfermagem', 'Chefe de Enfermagem'),
  medico('medico', 'Médico de Urgência'),
  enfermeiro('enfermeiro', 'Enfermeiro'),
  triagem('triagem', 'Profissional de Triagem'),
  tecnicoEmergencia('tecnico_emergencia', 'Técnico de Emergência'),
  administrativo('administrativo', 'Administrativo'),
  auxiliar('auxiliar', 'Assistente Operacional');

  final String id;
  final String label;

  const AppRole(this.id, this.label);

  static AppRole? fromId(String value) {
    final normalizedValue = value.trim();
    for (final role in AppRole.values) {
      if (role.id == normalizedValue) return role;
    }
    return null;
  }

  static AppRole? fromSupabaseCargo(String value) {
    final normalizedValue = value.trim().toLowerCase();
    return switch (normalizedValue) {
      'super_admin' || 'superadmin' || 'administrador' => AppRole.superAdmin,
      'admin' || 'admin_hospital' => AppRole.adminHospital,
      'diretor_clinico' => AppRole.diretorClinico,
      'chefe_enfermagem' => AppRole.chefeEnfermagem,
      'medico' || 'médico' => AppRole.medico,
      'enfermeiro' => AppRole.enfermeiro,
      'triagem' => AppRole.triagem,
      'tecnico' ||
      'técnico' ||
      'tecnico_emergencia' => AppRole.tecnicoEmergencia,
      'rececionista' || 'administrativo' => AppRole.administrativo,
      'auxiliar' => AppRole.auxiliar,
      _ => fromId(normalizedValue),
    };
  }
}

extension AppRoleList on Iterable<AppRole> {
  List<AppRole> get withoutSuperAdmin {
    return where((role) => role != AppRole.superAdmin).toList();
  }
}
