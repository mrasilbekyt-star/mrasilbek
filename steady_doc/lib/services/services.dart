import '../game/session.dart';
import '../painting/art.dart';

/// What every screen needs besides settings: feedback and artwork.
class Services {
  const Services({required this.feedback, required this.art});

  final FeedbackSink feedback;
  final ArtAssets art;
}
