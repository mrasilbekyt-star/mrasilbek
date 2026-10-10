import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../app.dart';
import '../services/pro.dart';
import 'theme.dart';
import 'widgets.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  String _selected = ProService.yearly;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.settings.strings;
    final pro = app.pro;
    final products = {for (final p in pro.products) p.id: p};
    final chosen = products[_selected] ?? (products.isEmpty ? null : products.values.first);

    final features = [
      (Icons.palette_rounded, s.proSkins),
      (Icons.layers_rounded, s.proHeatmap),
      (Icons.emoji_events_rounded, s.proRecords),
      (Icons.file_download_rounded, s.proGpx),
      (Icons.auto_awesome_rounded, s.proCards),
      (Icons.shield_rounded, s.proSoon),
    ];

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.8),
                  radius: 1.2,
                  colors: [const Color(0xFFFF8A3D).withValues(alpha: 0.28), Palette.background],
                ),
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                ),
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      gradient: Palette.proGradient,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: const Color(0xFFFF8A3D).withValues(alpha: 0.6), blurRadius: 40)],
                    ),
                    child: const Icon(Icons.workspace_premium_rounded, size: 54, color: Palette.background),
                  ),
                ),
                const SizedBox(height: 18),
                Center(child: Text(s.proTitle, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900))),
                const SizedBox(height: 8),
                Text(s.proSubtitle,
                    textAlign: TextAlign.center, style: const TextStyle(color: Palette.muted, fontSize: 15, height: 1.4)),
                const SizedBox(height: 24),
                for (final (icon, text) in features)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Palette.surfaceHigh, borderRadius: BorderRadius.circular(12)),
                          child: Icon(icon, color: Palette.gold, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),
                const SizedBox(height: 22),
                if (pro.isPro)
                  Glass(
                    child: Row(
                      children: [
                        const ProTag(),
                        const SizedBox(width: 12),
                        Expanded(child: Text(s.youArePro, style: const TextStyle(fontWeight: FontWeight.w800))),
                      ],
                    ),
                  )
                else if (!pro.storeAvailable || products.isEmpty)
                  Glass(child: Text(s.storeUnavailable, style: const TextStyle(color: Palette.muted, height: 1.4)))
                else ...[
                  for (final id in [ProService.yearly, ProService.monthly])
                    if (products[id] != null)
                      _Plan(
                        product: products[id]!,
                        period: id == ProService.yearly ? s.perYear : s.perMonth,
                        badge: id == ProService.yearly ? s.bestValue : null,
                        selected: chosen?.id == id,
                        onTap: () => setState(() => _selected = id),
                      ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 58,
                    child: DecoratedBox(
                      decoration: BoxDecoration(gradient: Palette.proGradient, borderRadius: BorderRadius.circular(18)),
                      child: TextButton(
                        onPressed: pro.busy || chosen == null ? null : () => pro.buy(chosen),
                        child: pro.busy
                            ? const CircularProgressIndicator(color: Palette.background)
                            : Text(s.subscribe,
                                style: const TextStyle(color: Palette.background, fontSize: 18, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                ],
                if (pro.error != null) ...[
                  const SizedBox(height: 10),
                  Text(pro.error!, style: const TextStyle(color: Palette.danger, fontSize: 12)),
                ],
                const SizedBox(height: 8),
                TextButton(onPressed: pro.busy ? null : pro.restore, child: Text(s.restore)),
                Text(s.subscriptionTerms,
                    textAlign: TextAlign.center, style: const TextStyle(color: Palette.muted, fontSize: 11, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Plan extends StatelessWidget {
  const _Plan({required this.product, required this.period, required this.selected, required this.onTap, this.badge});

  final ProductDetails product;
  final String period;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Palette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? Palette.gold : Palette.line, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: selected ? Palette.gold : Palette.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.price, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    Text(period, style: const TextStyle(color: Palette.muted)),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(gradient: Palette.proGradient, borderRadius: BorderRadius.circular(8)),
                  child: Text(badge!,
                      style: const TextStyle(color: Palette.background, fontSize: 10, fontWeight: FontWeight.w900)),
                ),
            ],
          ),
        ),
      );
}
