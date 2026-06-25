# SAUH

Aplicação Flutter do Sistema de Apoio em Urgências Hospitalares, preparada para Windows, Android e iOS.

## Preparação

```bash
flutter pub get
flutter doctor -v
```

Configura um URL e uma chave Supabase válidos antes de testar funcionalidades cloud.

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
