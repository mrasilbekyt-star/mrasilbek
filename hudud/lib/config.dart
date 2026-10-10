/// Public settings of the online services. None of these are secrets.
///
/// Fill them in after setting up the services (see README → "Login"), or
/// pass them at build time: `--dart-define=TELEGRAM_BOT=HududBot`.
abstract final class Config {
  /// The Telegram bot that confirms phone numbers, without the @.
  static const telegramBot = String.fromEnvironment('TELEGRAM_BOT');

  /// Where the Telegram login worker runs, e.g. `https://hudud-auth.example.workers.dev`.
  static const authServer = String.fromEnvironment('AUTH_SERVER');

  static bool get telegramReady => telegramBot.isNotEmpty && authServer.isNotEmpty;
}
