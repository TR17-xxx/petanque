import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:petanque_score/services/purchase_service.dart';
import 'package:petanque_score/utils/app_config.dart';

/// Provider réactif pour l'état des achats in-app.
class PurchaseProvider extends ChangeNotifier {
  bool _isPro = false;
  bool _isPlayStoreAvailable = false;
  bool _loading = true;
  String? _errorMessage;
  Map<String, ProductDetails> _products = {};
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool get isPro => _isPro;
  bool get isPlayStoreAvailable => _isPlayStoreAvailable;
  bool get loading => _loading;
  String? get errorMessage => _errorMessage;
  ProductDetails? get proProduct => _products[PurchaseService.proProductId];
  ProductDetails? get pastisProduct => _products[PurchaseService.pastisProductId];

  PurchaseProvider() {
    _init();
  }

  Future<void> _init() async {
    // 1. Charge le cache local (rapide, offline-first)
    _isPro = await PurchaseService.loadProStatus();
    notifyListeners();

    // 2. Build GitHub (APK sideloadé) → Pro gratuit
    _isPlayStoreAvailable = AppConfig.isPlayStore;

    // 3. Pas Play Store → Pro offert
    if (!_isPlayStoreAvailable) {
      _isPro = true;
      await PurchaseService.saveProStatus(true);
      _loading = false;
      notifyListeners();
      return;
    }

    // 4. Écoute le stream d'achats
    _subscription = InAppPurchase.instance.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (_) {},
    );

    // 5. Charge les produits
    try {
      _products = await PurchaseService.loadProducts();
    } catch (_) {
      // Produits non disponibles — on continue sans
    }

    // 6. Restaure les achats précédents
    try {
      await PurchaseService.restorePurchases();
    } catch (_) {
      // Erreur de restauration — le cache local fait office de fallback
    }

    _loading = false;
    notifyListeners();
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        if (purchase.productID == PurchaseService.proProductId) {
          _isPro = true;
          PurchaseService.saveProStatus(true);
          notifyListeners();
        }
        // Finalise l'achat (obligatoire Google Play)
        if (purchase.pendingCompletePurchase) {
          InAppPurchase.instance.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.error) {
        _errorMessage = 'Erreur lors de l\'achat. Réessayez.';
        notifyListeners();
        // Reset le message après affichage
        Future.delayed(const Duration(seconds: 3), () {
          _errorMessage = null;
          notifyListeners();
        });
      }
    }
  }

  /// Achète la version Pro.
  Future<void> buyPro() async {
    if (proProduct == null) return;
    await PurchaseService.buyPro(proProduct!);
  }

  /// Achète un pastis (don).
  Future<void> buyPastis() async {
    if (pastisProduct == null) return;
    await PurchaseService.buyPastis(pastisProduct!);
  }

  /// Restaure les achats manuellement.
  Future<void> restore() async {
    if (!_isPlayStoreAvailable) return;
    try {
      await PurchaseService.restorePurchases();
    } catch (_) {
      _errorMessage = 'Impossible de restaurer les achats.';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
