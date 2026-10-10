import 'package:flutter/material.dart';

import '../app.dart';
import '../services/auth.dart';
import 'theme.dart';

/// Sign in with Google or with a phone number through Telegram, or try the
/// app as a guest.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.popWhenDone = false});

  /// Opened from the settings rather than at start.
  final bool popWhenDone;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? _busy;
  String? _error;

  Future<void> _run(String which, Future<void> Function() action) async {
    final s = AppScope.read(context).settings.strings;
    setState(() {
      _busy = which;
      _error = null;
    });
    try {
      await action();
      if (mounted && widget.popWhenDone) Navigator.of(context).pop();
    } on SignInException catch (e) {
      if (!mounted) return;
      setState(() => _error = switch (e.error) {
            SignInError.cancelled => null,
            SignInError.notConfigured => s.signInNotReady,
            SignInError.network => s.noInternet,
            SignInError.failed => s.signInFailed,
          });
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.settings.strings;
    final auth = app.auth;
    final color = app.skin;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.7),
                  radius: 1.1,
                  colors: [color.withValues(alpha: 0.22), Palette.background],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.popWhenDone)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                    ),
                  const Spacer(),
                  Text('HUDUD',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 8)),
                  const SizedBox(height: 24),
                  Text(s.signInTitle,
                      textAlign: TextAlign.center, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  Text(s.signInText,
                      textAlign: TextAlign.center, style: const TextStyle(color: Palette.muted, fontSize: 15, height: 1.45)),
                  const Spacer(),
                  _SignInButton(
                    label: s.withGoogle,
                    background: Colors.white,
                    foreground: const Color(0xFF1F1F1F),
                    leading: const _GoogleMark(),
                    busy: _busy == 'google',
                    onTap: _busy != null || !auth.available ? null : () => _run('google', auth.signInWithGoogle),
                  ),
                  const SizedBox(height: 12),
                  _SignInButton(
                    label: _busy == 'telegram' ? s.waitingTelegram : s.withTelegram,
                    background: const Color(0xFF229ED9),
                    foreground: Colors.white,
                    leading: const Icon(Icons.send_rounded, color: Colors.white),
                    busy: _busy == 'telegram',
                    onTap: _busy != null || !auth.telegramAvailable ? null : () => _run('telegram', auth.signInWithTelegram),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    auth.available ? s.telegramHint : s.signInNotReady,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Palette.muted, fontSize: 12, height: 1.4),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Palette.danger)),
                  ],
                  const SizedBox(height: 8),
                  if (!widget.popWhenDone)
                    TextButton(
                      onPressed: _busy != null ? null : auth.continueAsGuest,
                      child: Text(s.later, style: const TextStyle(fontSize: 16, color: Palette.muted)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.leading,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Widget leading;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null && !busy ? 0.45 : 1,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: SizedBox(
              height: 56,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  busy
                      ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: foreground))
                      : leading,
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: foreground, fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Google's four-color "G", drawn so no image asset is needed.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 22,
        height: 22,
        child: CustomPaint(painter: _GPainter()),
      );
}

class _GPainter extends CustomPainter {
  const _GPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(2.5);
    final stroke = size.width * 0.2;
    Paint p(Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = c;
    const deg = 3.14159265 / 180;
    canvas.drawArc(rect, -40 * deg, -100 * deg, false, p(const Color(0xFFEA4335)));
    canvas.drawArc(rect, -140 * deg, -90 * deg, false, p(const Color(0xFFFBBC05)));
    canvas.drawArc(rect, 130 * deg, -100 * deg, false, p(const Color(0xFF34A853)));
    canvas.drawArc(rect, 30 * deg, -70 * deg, false, p(const Color(0xFF4285F4)));
    canvas.drawLine(rect.center, Offset(rect.right + stroke / 2, rect.center.dy), p(const Color(0xFF4285F4)));
  }

  @override
  bool shouldRepaint(_GPainter old) => false;
}
