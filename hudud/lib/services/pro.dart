import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/settings.dart';

/// Hudud Pro, sold as a Google Play / App Store subscription.
///
/// Create the products `hudud_pro_monthly` and `hudud_pro_yearly` in Play
/// Console (Monetize → Subscriptions) before the paywall can sell anything.
class ProService extends ChangeNotifier {
  ProService(this._settings, this._prefs);

  static const monthly = 'hudud_pro_monthly';
  static const yearly = 'hudud_pro_yearly';
  static const ids = {monthly, yearly};

  final Settings _settings;
  final SharedPreferences _prefs;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool _available = false;
  bool get storeAvailable => _available;

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  bool _busy = false;
  bool get busy => _busy;

  String? _error;
  String? get error => _error;

  bool get _owned => _prefs.getBool('proOwned') ?? false;

  bool get isPro => _owned || _settings.proPreview;

  static Future<ProService> start(Settings settings) async {
    final service = ProService(settings, await SharedPreferences.getInstance());
    settings.addListener(service.notifyListeners);
    unawaited(service._init());
    return service;
  }

  Future<void> _init() async {
    try {
      _available = await _iap.isAvailable();
      if (!_available) return;
      _sub = _iap.purchaseStream.listen(_onPurchases, onError: (Object e) {
        _error = '$e';
        notifyListeners();
      });
      final response = await _iap.queryProductDetails(ids);
      _products = response.productDetails..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
      await _refreshOwnership();
    } catch (e) {
      debugPrint('Hudud Pro: store unavailable: $e');
      _available = false;
    }
    notifyListeners();
  }

  /// Asks the store which subscriptions are active right now, so a lapsed
  /// subscription switches Pro off. Offline, the saved answer stays.
  Future<void> _refreshOwnership() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      await _iap.restorePurchases();
      return;
    }
    final android = _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final response = await android.queryPastPurchases();
    if (response.error != null) return;
    final active = response.pastPurchases.any((p) =>
        ids.contains(p.productID) &&
        (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored));
    await _setOwned(active);
  }

  Future<void> _setOwned(bool owned) async {
    if (owned == _owned) return;
    await _prefs.setBool('proOwned', owned);
    notifyListeners();
  }

  Future<void> buy(ProductDetails product) async {
    _error = null;
    _busy = true;
    notifyListeners();
    try {
      await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
    } catch (e) {
      _error = '$e';
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> restore() async {
    _error = null;
    _busy = true;
    notifyListeners();
    try {
      await _iap.restorePurchases();
    } catch (e) {
      _error = '$e';
    }
    _busy = false;
    notifyListeners();
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (!ids.contains(p.productID)) continue;
      switch (p.status) {
        case PurchaseStatus.purchased || PurchaseStatus.restored:
          await _setOwned(true);
        case PurchaseStatus.error:
          _error = p.error?.message;
        case PurchaseStatus.pending || PurchaseStatus.canceled:
          break;
      }
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
    }
    _busy = purchases.any((p) => p.status == PurchaseStatus.pending);
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _settings.removeListener(notifyListeners);
    super.dispose();
  }
}
