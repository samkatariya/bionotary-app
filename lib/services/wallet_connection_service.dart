import 'dart:io';
import 'package:flutter/foundation.dart';
import 'mobile_wallet_service.dart';

/// Unified wallet connection service for Web and Mobile
/// Automatically selects the appropriate backend based on platform
class WalletConnectionService {
  static String? _cachedAddress;

  /// Initialize wallet connection (platform-aware)
  static Future<void> init({String? wcProjectId}) async {
    if (!kIsWeb && Platform.isAndroid) {
      // Mobile: Initialize WalletConnect
      await MobileWalletService.init(
        wcProjectId: wcProjectId ?? 'YOUR_WALLETCONNECT_PROJECT_ID',
      );
    }
    // Web: No initialization needed (MetaMask is injected)
  }

  /// Connect wallet (platform-aware)
  static Future<String> connectWallet() async {
    if (kIsWeb) {
      // Web: MetaMask is already available
      return 'web_connected';
    } else if (Platform.isAndroid) {
      // Mobile: Use WalletConnect
      await MobileWalletService.connect();
      _cachedAddress = MobileWalletService.walletAddress;
      return _cachedAddress ?? 'mobile_connected';
    }
    throw UnsupportedError('Platform not supported');
  }

  /// Get connected wallet address
  static String? getWalletAddress() {
    if (kIsWeb) {
      // Web: Will be provided by MetaMask
      return _cachedAddress;
    } else if (Platform.isAndroid) {
      // Mobile: From WalletConnect
      return MobileWalletService.walletAddress;
    }
    return null;
  }

  /// Check if wallet is connected
  static bool isConnected() {
    if (kIsWeb) {
      return _cachedAddress != null;
    } else if (Platform.isAndroid) {
      return MobileWalletService.isConnected;
    }
    return false;
  }

  /// Disconnect wallet
  static Future<void> disconnectWallet() async {
    if (kIsWeb) {
      _cachedAddress = null;
    } else if (Platform.isAndroid) {
      await MobileWalletService.disconnect();
    }
  }

  /// Set wallet address (for web platform)
  static void setWalletAddress(String address) {
    _cachedAddress = address;
  }
}
