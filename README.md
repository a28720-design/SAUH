# SAUH

Aplicação Flutter do Sistema de Apoio em Urgências Hospitalares, preparada para Windows, Android e iOS.

## Preparação

```bash
flutter pub get
flutter doctor -v
```

Configura um URL e uma chave Supabase válidos antes de testar funcionalidades cloud.

O template visual do email de verificação do Supabase está em `docs/supabase_email_templates/`.

## Android

Liga um dispositivo com depuração USB ou inicia um emulador Android e executa:

```bash
flutter devices
flutter run -d <android-device-id>
flutter build apk --debug
```

O identificador Android é `pt.sauh.app`. Antes de publicar na Play Store, configura uma chave de assinatura de release em `android/app/build.gradle.kts`.

## iOS

O desenvolvimento e build iOS exigem macOS com Xcode e CocoaPods:

```bash
flutter pub get
cd ios
pod install
cd ..
flutter run -d <ios-device-id>
flutter build ios
```

O Bundle Identifier é `pt.sauh.app`. No Xcode, seleciona a equipa Apple Developer em **Runner > Signing & Capabilities** antes de executar num iPhone real.

## Qualidade

```bash
flutter analyze
flutter test
```

## Login, permissões e contas persistentes

A app usa Supabase Auth para login real e a tabela `public.app_users` para guardar o perfil profissional, cargo, hospital, departamento e estado ativo/inativo. Assim, as contas criadas continuam disponíveis depois de reiniciar o projeto.

Para ativar a persistência de contas:

1. Executa `supabase_accounts.sql` no SQL Editor do Supabase.
2. Executa `supabase_patients.sql` para criar a tabela de pacientes e as policies RLS.
3. Publica a função Edge: `supabase functions deploy manage-account`.
4. Garante que a função tem a secret `SUPABASE_SERVICE_ROLE_KEY` configurada no projeto Supabase.
5. Cria o primeiro utilizador em **Authentication > Users**.
6. Usa o bloco de bootstrap no fim de `supabase_accounts.sql` para associar esse utilizador ao cargo `super_admin`.
7. Entra na app com essa conta e usa **Gestão de Contas** para criar, pesquisar, editar, ativar e desativar contas profissionais.

A service role key nunca deve ficar no Flutter. A app chama apenas a função `manage-account`, e a função faz as operações administrativas no Supabase.
