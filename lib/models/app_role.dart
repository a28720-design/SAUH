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
    for (final role in AppRole.values) {
      if (role.id == value) return role;
    }
    return null;
  }
}

extension AppRoleList on Iterable<AppRole> {
  List<AppRole> get withoutSuperAdmin {
    return where((role) => role != AppRole.superAdmin).toList();
  }
}
