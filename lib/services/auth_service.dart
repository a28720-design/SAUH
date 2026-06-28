import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_role.dart';
import '../models/app_user.dart';
import 'hospital_service.dart';
import 'permission_service.dart';
import 'supabase_account_service.dart';

class AuthResult {
  final AppUser? user;
  final String? error;

  const AuthResult.success(this.user) : error = null;
  const AuthResult.failure(this.error) : user = null;

  bool get isSuccess => user != null;
}

class AuthService {
  final List<AppUser> _users = [
    AppUser(
      userId: 'u-super',
      name: 'Administrador SAUH',
      email: 'super@sauh.pt',
      role: AppRole.superAdmin,
      hospitalId: null,
      department: 'Sistema',
      createdBy: 'seed',
    ),
    AppUser(
      userId: 'u-admin-central',
      name: 'Direção Hospital Central',
      email: 'admin@hospitalcentral.pt',
      role: AppRole.adminHospital,
      hospitalId: 'hospital-central',
      department: 'Administração',
      createdBy: 'u-super',
    ),
    AppUser(
      userId: 'u-medico-central',
      name: 'Dra. Ana Martins',
      email: 'medico@hospitalcentral.pt',
      role: AppRole.medico,
      hospitalId: 'hospital-central',
      department: 'Urgência',
      createdBy: 'u-admin-central',
    ),
    AppUser(
      userId: 'u-enfermeiro-central',
      name: 'Enf. Rui Costa',
      email: 'enfermeiro@hospitalcentral.pt',
      role: AppRole.enfermeiro,
      hospitalId: 'hospital-central',
      department: 'Observação',
      createdBy: 'u-admin-central',
    ),
    AppUser(
      userId: 'u-triagem-central',
      name: 'Téc. Marta Lopes',
      email: 'triagem@hospitalcentral.pt',
      role: AppRole.triagem,
      hospitalId: 'hospital-central',
      department: 'Triagem',
      createdBy: 'u-admin-central',
    ),
    AppUser(
      userId: 'u-chefe-enfermagem-central',
      name: 'Enf. Chefe Helena Ferreira',
      email: 'chefe.enfermagem@hospitalcentral.pt',
      role: AppRole.chefeEnfermagem,
      hospitalId: 'hospital-central',
      department: 'Urgência',
      createdBy: 'u-admin-central',
    ),
  ];

  final Map<String, String> _passwords = {
    'super@sauh.pt': 'admin123',
    'admin@hospitalcentral.pt': 'admin123',
    'medico@hospitalcentral.pt': 'admin123',
    'enfermeiro@hospitalcentral.pt': 'admin123',
    'triagem@hospitalcentral.pt': 'admin123',
    'chefe.enfermagem@hospitalcentral.pt': 'admin123',
  };

  AppUser? currentUser;
  bool _usingSupabaseAccounts = false;

  List<AppUser> get users => List.unmodifiable(_users);
  bool get usingSupabaseAccounts => _usingSupabaseAccounts;

  AuthResult signIn(String email, String password) {
    final normalizedEmail = email.trim().toLowerCase();
    AppUser? user;
    for (final candidate in _users) {
      if (candidate.email.toLowerCase() == normalizedEmail) {
        user = candidate;
        break;
      }
    }

    if (user == null || _passwords[normalizedEmail] != password) {
      return const AuthResult.failure('Email ou palavra-passe inválidos.');
    }
    final validationError = _validateActiveUser(user);
    if (validationError != null) return AuthResult.failure(validationError);

    currentUser = user;
    return AuthResult.success(user);
  }

  Future<AuthResult> signInWithSupabaseOrLocal(
    SupabaseClient client,
    String email,
    String password,
  ) async {
    final normalizedEmail = email.trim().toLowerCase();

    try {
      await client.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );
    } on AuthException catch (error) {
      final fallback = signIn(email, password);
      if (fallback.isSuccess) return fallback;
      return AuthResult.failure('Erro no Supabase: ${error.message}');
    } catch (_) {
      return signIn(email, password);
    }

    try {
      final profile = await supabaseAccountService.currentProfile(client);
      if (profile == null) {
        await client.auth.signOut(scope: SignOutScope.local);
        return const AuthResult.failure(
          'Conta autenticada, mas sem perfil profissional no Supabase.',
        );
      }

      final validationError = _validateActiveUser(profile);
      if (validationError != null) {
        await client.auth.signOut(scope: SignOutScope.local);
        return AuthResult.failure(validationError);
      }

      _usingSupabaseAccounts = true;
      upsertUser(profile);
      currentUser = profile;
      return AuthResult.success(profile);
    } catch (error) {
      await client.auth.signOut(scope: SignOutScope.local);
      return AuthResult.failure(
        'Login validado, mas não foi possível carregar o perfil profissional: $error',
      );
    }
  }

  void signOut() {
    currentUser = null;
  }

  void upsertUser(AppUser user) {
    final index = _users.indexWhere((item) => item.userId == user.userId);
    if (index == -1) {
      _users.add(user);
    } else {
      _users[index] = user;
    }
    if (currentUser?.userId == user.userId) {
      currentUser = user;
    }
  }

  void setSupabaseAccountSnapshot(List<AppUser> remoteUsers, AppUser actor) {
    if (remoteUsers.isEmpty) return;
    _usingSupabaseAccounts = true;

    if (actor.role == AppRole.superAdmin) {
      _users
        ..clear()
        ..addAll(remoteUsers);
    } else {
      _users.removeWhere((user) => user.hospitalId == actor.hospitalId);
      _users.addAll(remoteUsers);
    }

    final signedUser = currentUser;
    if (signedUser == null) return;
    for (final user in _users) {
      if (user.userId == signedUser.userId) {
        currentUser = user;
        return;
      }
    }
    _users.add(signedUser);
  }

  String? _validateActiveUser(AppUser user) {
    if (!user.active) {
      return 'Conta inativa. Contacte o administrador.';
    }
    final hospital = hospitalService.byId(user.hospitalId);
    if (user.requiresHospital && (hospital == null || !hospital.active)) {
      return 'Hospital inativo ou não encontrado.';
    }
    return null;
  }

  List<AppUser> usersVisibleTo(AppUser? actor) {
    if (actor == null) return const [];
    if (actor.role == AppRole.superAdmin) return users;
    if (actor.role == AppRole.adminHospital) {
      return _users
          .where((user) => user.hospitalId == actor.hospitalId)
          .toList();
    }
    return const [];
  }

  AppUser createUser({
    required AppUser creator,
    required String name,
    required String email,
    required String temporaryPassword,
    required AppRole role,
    required String department,
    required bool active,
    String? hospitalId,
  }) {
    if (!PermissionService.canCreateRole(creator, role)) {
      throw StateError('Sem permissão para criar este cargo.');
    }
    final normalizedEmail = email.trim().toLowerCase();
    if (_users.any((user) => user.email.toLowerCase() == normalizedEmail)) {
      throw StateError('Já existe uma conta com este email.');
    }
    if (temporaryPassword.length < 6) {
      throw StateError(
        'A palavra-passe temporária deve ter pelo menos 6 caracteres.',
      );
    }

    final resolvedHospitalId = role == AppRole.superAdmin
        ? null
        : creator.role == AppRole.adminHospital
        ? creator.hospitalId
        : hospitalId;

    if (role != AppRole.superAdmin && resolvedHospitalId == null) {
      throw StateError('Este cargo tem de estar associado a um hospital.');
    }

    final user = AppUser(
      userId: 'u-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      email: normalizedEmail,
      role: role,
      hospitalId: resolvedHospitalId,
      active: active,
      department: department,
      createdBy: creator.userId,
    );
    _users.add(user);
    _passwords[normalizedEmail] = temporaryPassword;
    return user;
  }

  List<AppRole> editableRolesFor(AppUser actor, AppUser target) {
    if (!PermissionService.can(actor, AppPermission.manageUsers)) {
      return const [];
    }
    if (actor.role == AppRole.superAdmin) {
      return AppRole.values;
    }
    if (actor.role == AppRole.adminHospital &&
        actor.hospitalId == target.hospitalId &&
        target.role != AppRole.superAdmin &&
        target.role != AppRole.adminHospital) {
      return const [
        AppRole.diretorClinico,
        AppRole.chefeEnfermagem,
        AppRole.medico,
        AppRole.enfermeiro,
        AppRole.triagem,
        AppRole.tecnicoEmergencia,
        AppRole.administrativo,
        AppRole.auxiliar,
      ];
    }
    return const [];
  }

  void updateUser({
    required AppUser actor,
    required AppUser target,
    required String name,
    required String email,
    required AppRole role,
    required String? hospitalId,
    required String department,
    required bool active,
    String? newPassword,
  }) {
    final editableRoles = editableRolesFor(actor, target);
    if (editableRoles.isEmpty || !editableRoles.contains(role)) {
      throw StateError('Sem permissão para editar esta conta.');
    }
    if (actor.role == AppRole.adminHospital &&
        actor.hospitalId != target.hospitalId) {
      throw StateError('Não pode editar utilizadores de outro hospital.');
    }
    if (actor.userId == target.userId && (!active || role != actor.role)) {
      throw StateError(
        'Não podes desativar a tua própria conta nem alterar o teu cargo.',
      );
    }

    final trimmedName = name.trim();
    final normalizedEmail = email.trim().toLowerCase();
    final trimmedDepartment = department.trim().isEmpty
        ? 'Não definido'
        : department.trim();
    if (trimmedName.isEmpty || normalizedEmail.isEmpty) {
      throw StateError('Nome e email sao obrigatorios.');
    }
    final duplicatedEmail = _users.any(
      (user) =>
          user.userId != target.userId &&
          user.email.toLowerCase() == normalizedEmail,
    );
    if (duplicatedEmail) {
      throw StateError('Ja existe uma conta com este email.');
    }

    final resolvedHospitalId = role == AppRole.superAdmin
        ? null
        : actor.role == AppRole.adminHospital
        ? actor.hospitalId
        : hospitalId;
    if (role != AppRole.superAdmin && resolvedHospitalId == null) {
      throw StateError('Este cargo tem de estar associado a um hospital.');
    }

    final password = newPassword?.trim() ?? '';
    if (password.isNotEmpty && password.length < 6) {
      throw StateError(
        'A nova palavra-passe deve ter pelo menos 6 caracteres.',
      );
    }

    final oldEmail = target.email.toLowerCase();
    target
      ..name = trimmedName
      ..email = normalizedEmail
      ..role = role
      ..hospitalId = resolvedHospitalId
      ..department = trimmedDepartment
      ..active = active;

    if (oldEmail != normalizedEmail) {
      final oldPassword = _passwords.remove(oldEmail);
      if (oldPassword != null) {
        _passwords[normalizedEmail] = oldPassword;
      }
    }

    if (password.isNotEmpty) {
      _passwords[normalizedEmail] = password;
    }

    if (currentUser?.userId == target.userId) {
      currentUser = target;
    }
  }

  void setUserActive(AppUser actor, AppUser target, bool active) {
    if (!PermissionService.can(actor, AppPermission.manageUsers)) {
      throw StateError('Sem permissão para gerir utilizadores.');
    }
    if (actor.role == AppRole.adminHospital &&
        actor.hospitalId != target.hospitalId) {
      throw StateError('Não pode alterar utilizadores de outro hospital.');
    }
    if (target.role == AppRole.superAdmin && actor.role != AppRole.superAdmin) {
      throw StateError('Só o super admin pode alterar esta conta.');
    }
    target.active = active;
  }
}

final authService = AuthService();
