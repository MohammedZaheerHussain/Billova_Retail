import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoyaltySettingsProvider extends ChangeNotifier {
  static const _kEnabled = 'loyalty_enabled';
  static const _kEarnRate = 'loyalty_earn_rate';    // points per ₹100
  static const _kRedeemValue = 'loyalty_redeem_value'; // ₹ per point
  static const _kMinRedeem = 'loyalty_min_redeem';  // min points to redeem

  bool _enabled = false;
  int _earnRate = 1;       // 1 point per ₹100
  double _redeemValue = 1; // ₹1 per point
  int _minRedeem = 50;     // minimum 50 points to redeem

  bool get isEnabled => _enabled;
  int get earnRate => _earnRate;
  double get redeemValue => _redeemValue;
  int get minRedeem => _minRedeem;

  /// Calculate points earned for a given sale amount
  int pointsForAmount(double amount) => (amount / 100 * _earnRate).floor();

  /// Calculate ₹ value of points
  double valueOfPoints(int points) => points * _redeemValue;

  LoyaltySettingsProvider() { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_kEnabled) ?? false;
    _earnRate = prefs.getInt(_kEarnRate) ?? 1;
    _redeemValue = prefs.getDouble(_kRedeemValue) ?? 1.0;
    _minRedeem = prefs.getInt(_kMinRedeem) ?? 50;
    notifyListeners();
  }

  Future<void> setEnabled(bool v) async {
    _enabled = v;
    (await SharedPreferences.getInstance()).setBool(_kEnabled, v);
    notifyListeners();
  }

  Future<void> setEarnRate(int v) async {
    _earnRate = v;
    (await SharedPreferences.getInstance()).setInt(_kEarnRate, v);
    notifyListeners();
  }

  Future<void> setRedeemValue(double v) async {
    _redeemValue = v;
    (await SharedPreferences.getInstance()).setDouble(_kRedeemValue, v);
    notifyListeners();
  }

  Future<void> setMinRedeem(int v) async {
    _minRedeem = v;
    (await SharedPreferences.getInstance()).setInt(_kMinRedeem, v);
    notifyListeners();
  }
}
