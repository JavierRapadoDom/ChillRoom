// lib/services/purchase_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Servicio de compras in-app (Google Play Billing / App Store)
/// - Gestiona consulta de productos, escuchas del purchaseStream y flujo de compra.
/// - Diseñado para consumibles: swipes_10, swipes_30, swipes_50, swipes_100, swipes_200.
/// - 'buy(productId)' devuelve true si la compra se completa correctamente.
class PurchaseService {
  PurchaseService._internal() {
    _init();
  }
  static final PurchaseService instance = PurchaseService._internal();

  /// IDs de producto configurados en Google Play Console / App Store Connect
  static const Set<String> _kProductIds = {
    'swipes_10',
    'swipes_30',
    'swipes_50',
    'swipes_100',
    'swipes_200',
  };

  final InAppPurchase _iap = InAppPurchase.instance;

  /// Mapa de ProductDetails para acceso rápido por productId
  final Map<String, ProductDetails> _products = {};

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Completer que espera el resultado de UNA compra en curso
  Completer<bool>? _purchaseCompleter;

  /// Últimos detalles de compra, útil para debug/restauraciones
  List<PurchaseDetails> _lastPurchases = [];

  bool _productsLoaded = false;
  bool _isBuying = false;

  // ─────────────────────────────────────────────────────────────
  // Inicialización
  // ─────────────────────────────────────────────────────────────
  Future<void> _init() async {
    // Suscribirse al stream global de compras
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (e, st) {
        // Si hay un error de stream, falla cualquier compra pendiente
        _completePurchaseIfWaiting(false);
      },
    );

    // Cargar catálogo
    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final available = await _iap.isAvailable();
      if (!available) {
        // En dispositivos no soportados (desktop/web) devolverá false
        debugPrint('[IAP] Tienda no disponible');
        return;
      }

      final resp = await _iap.queryProductDetails(_kProductIds);
      if (resp.error != null) {
        debugPrint('[IAP] Error al consultar productos: ${resp.error}');
        return;
      }

      if (resp.productDetails.isEmpty) {
        debugPrint('[IAP] Sin productos disponibles (¿IDs mal configurados?)');
        return;
      }

      _products.clear();
      for (final p in resp.productDetails) {
        _products[p.id] = p;
      }
      _productsLoaded = true;
      debugPrint('[IAP] Productos cargados: ${_products.keys.join(', ')}');
    } catch (e, st) {
      debugPrint('[IAP] Excepción consultando productos: $e\n$st');
    }
  }

  /// Reintenta cargar los productos si aún no están.
  Future<void> ensureProductsLoaded() async {
    if (!_productsLoaded) {
      await _loadProducts();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Compra
  // ─────────────────────────────────────────────────────────────
  /// Inicia la compra de un consumible por productId.
  /// Devuelve `true` si la compra se completa (PurchaseStatus.purchased).
  Future<bool> buy(String productId) async {
    if (_isBuying) {
      debugPrint('[IAP] Ya hay una compra en curso');
      return false;
    }

    try {
      final available = await _iap.isAvailable();
      if (!available) {
        debugPrint('[IAP] Tienda no disponible');
        return false;
      }

      await ensureProductsLoaded();
      final details = _products[productId];
      if (details == null) {
        debugPrint('[IAP] ProductDetails no encontrado para $productId');
        return false;
      }

      _isBuying = true;
      _purchaseCompleter = Completer<bool>();

      final param = PurchaseParam(productDetails: details);

      // Consumible: usar buyConsumable (Android autoConsume=true por defecto).
      // En iOS igualmente se completa y no queda como no-consumido.
      await _iap.buyConsumable(purchaseParam: param, autoConsume: true);

      // Espera el resultado del stream
      final result = await _purchaseCompleter!.future
          .timeout(const Duration(minutes: 5), onTimeout: () => false);

      return result;
    } catch (e, st) {
      debugPrint('[IAP] Excepción en buy($productId): $e\n$st');
      _completePurchaseIfWaiting(false);
      return false;
    } finally {
      _isBuying = false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Purchase Stream Handler
  // ─────────────────────────────────────────────────────────────
  void _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    _lastPurchases = purchases;

    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
        // Esperando… no hacemos nada especial
          debugPrint('[IAP] Purchase pendiente: ${p.productID}');
          break;

        case PurchaseStatus.error:
          debugPrint('[IAP] Error en compra ${p.productID}: ${p.error}');
          _completePurchaseIfWaiting(false);
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
        // 🔒 Aquí deberías verificar el recibo en tu servidor (recomendado).
          final verified = await _verifyPurchase(p);
          if (verified) {
            _completePurchaseIfWaiting(true);
            // Completar la transacción (iOS lo necesita, Android también por seguridad)
            if (p.pendingCompletePurchase) {
              await _iap.completePurchase(p);
            }
          } else {
            _completePurchaseIfWaiting(false);
            if (p.pendingCompletePurchase) {
              await _iap.completePurchase(p);
            }
          }
          break;

        case PurchaseStatus.canceled:
          debugPrint('[IAP] Usuario canceló ${p.productID}');
          _completePurchaseIfWaiting(false);
          break;
      }
    }
  }

  /// Verificación “dummy” en cliente.
  /// En producción, valida el recibo en tu servidor antes de dar crédito.
  Future<bool> _verifyPurchase(PurchaseDetails p) async {
    // TODO: Integrar verificación en servidor:
    // - Android: firma y purchaseToken contra Google Play Developer API
    // - iOS: recibo contra App Store
    // Por ahora devolvemos true para pruebas internas.
    return true;
  }

  void _completePurchaseIfWaiting(bool ok) {
    if (_purchaseCompleter != null && !_purchaseCompleter!.isCompleted) {
      _purchaseCompleter!.complete(ok);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Limpieza
  // ─────────────────────────────────────────────────────────────
  Future<void> dispose() async {
    await _subscription?.cancel();
  }

  // ─────────────────────────────────────────────────────────────
  // Helpers (opcionales)
  // ─────────────────────────────────────────────────────────────
  /// Acceso a los ProductDetails (precio local, título, etc.)
  ProductDetails? product(String id) => _products[id];

  /// Lista de productos ordenados por precio si lo deseas
  List<ProductDetails> get allProducts => _products.values.toList();
}
