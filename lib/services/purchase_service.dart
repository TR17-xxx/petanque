import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service de gestion des achats in-app (Google Play Billing).
class PurchaseService {
  static const proProductId = 'petanque_pro';
  static const pastisProductId = 'petanque_pastis';
  static const _proStatusKey = '@petanque/pro_status';

  /// Vérifie si le Google Play Store est disponible.
  static Future<bool> isPlayStoreAvailable() async {
    return await InAppPurchase.instance.isAvailable();
  }

  /// Charge les détails des produits depuis le Play Store.
  static Future<Map<String, ProductDetails>> loadProducts() async {
    final response = await InAppPurchase.instance.queryProductDetails(
      {proProductId, pastisProductId},
    );
    return {for (final p in response.productDetails) p.id: p};
  }

  /// Achète la version Pro (non-consommable).
  static Future<bool> buyPro(ProductDetails product) async {
    final param = PurchaseParam(productDetails: product);
    return InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
  }

  /// Achète un pastis (consommable / don).
  static Future<bool> buyPastis(ProductDetails product) async {
    final param = PurchaseParam(productDetails: product);
    return InAppPurchase.instance.buyConsumable(purchaseParam: param);
  }

  /// Restaure les achats (nouveau téléphone, réinstallation).
  static Future<void> restorePurchases() async {
    await InAppPurchase.instance.restorePurchases();
  }

  /// Sauvegarde le statut Pro en cache local.
  static Future<void> saveProStatus(bool isPro) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proStatusKey, isPro);
  }

  /// Charge le statut Pro depuis le cache local.
  static Future<bool> loadProStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_proStatusKey) ?? false;
  }
}
