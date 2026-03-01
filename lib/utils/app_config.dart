/// Configuration de build.
///
/// Build GitHub (par défaut) :
///   flutter build apk --release
///
/// Build Play Store :
///   flutter build appbundle --release --dart-define=PLAY_STORE=true
class AppConfig {
  static const isPlayStore =
      bool.fromEnvironment('PLAY_STORE', defaultValue: false);
}
