import 'package:crypto/crypto.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

// Platform-specific imports
import 'package:flutter_web3/flutter_web3.dart' if (dart.library.html) 'package:flutter_web3/flutter_web3.dart';
import 'dart:js_util' as js_util;
import 'mobile_wallet_service.dart';

class BlockchainService {
  static const String contractAddress =
      "0xCDa82472BD768156A5d961A0Ce61d9C93D4ffDA1";

  // Function selector for notarize(bytes32,bytes32) = 0x4c0f4d72
  static const String notarizeSelector = "0x4c0f4d72";

  /// Notarize a document on the blockchain (cross-platform)
  static Future<String> notarize({
    required String docHashHex,
    required String walletAddress,
  }) async {
    if (kIsWeb) {
      // Web: Use flutter_web3 with MetaMask
      return _notarizeWeb(docHashHex, walletAddress);
    } else if (Platform.isAndroid) {
      // Android: Use WalletConnect
      return _notarizeAndroid(docHashHex, walletAddress);
    } else {
      throw UnsupportedError('Platform not supported');
    }
  }

  /// Web implementation using MetaMask (flutter_web3)
  static Future<String> _notarizeWeb(
    String docHashHex,
    String walletAddress,
  ) async {
    if (!Ethereum.isSupported || ethereum == null) {
      throw Exception("MetaMask not detected");
    }

    // Ensure Sepolia
    final chainId = await ethereum!.getChainId();
    if (chainId != 11155111) {
      throw Exception("Please switch MetaMask to Sepolia");
    }

    // Request account access if needed
    final accounts = await ethereum!.requestAccount();
    if (accounts.isEmpty) {
      throw Exception("No wallet account connected");
    }

    // Ensure MetaMask is switched to Sepolia (0xaa36a7)
    await ethereum!.request(
      "wallet_switchEthereumChain",
      [
        {"chainId": "0xaa36a7"}
      ],
    );

    final cleaned = docHashHex.startsWith("0x") ? docHashHex : "0x$docHashHex";
    final userHashHex = sha256.convert(walletAddress.codeUnits).toString();
    final userHash = "0x$userHashHex";

    // Build the calldata: selector + docHash + userHash
    final calldata = notarizeSelector +
        cleaned.substring(2).padLeft(64, '0') +
        userHash.substring(2).padLeft(64, '0');

    try {
      // Get current account
      final account = accounts.first;

      // Send transaction via eth_sendTransaction JSON-RPC
      final promise = js_util.callMethod(
        ethereum!,
        'request',
        [
          {
            "method": "eth_sendTransaction",
            "params": [
              {
                "from": account,
                "to": contractAddress,
                "data": calldata,
                "value": "0x0",
              }
            ],
          }
        ],
      );

      // Convert promise to future with immediate string coercion
      final result = await js_util.promiseToFuture(promise);
      return result.toString();
    } catch (e, stack) {
      print("Web Notarize ERROR: $e");
      print("STACK: $stack");
      rethrow;
    }
  }

  /// Android implementation using WalletConnect
  static Future<String> _notarizeAndroid(
    String docHashHex,
    String walletAddress,
  ) async {
    if (!MobileWalletService.isConnected) {
      throw Exception("WalletConnect not connected. Connect wallet first.");
    }

    final cleaned = docHashHex.startsWith("0x") ? docHashHex : "0x$docHashHex";
    final userHashHex = sha256.convert(walletAddress.codeUnits).toString();
    final userHash = "0x$userHashHex";

    // Build the calldata: selector + docHash + userHash
    final calldata = notarizeSelector +
        cleaned.substring(2).padLeft(64, '0') +
        userHash.substring(2).padLeft(64, '0');

    try {
      final txHash = await MobileWalletService.sendTransaction(
        to: contractAddress,
        data: calldata,
        value: '0x0',
      );
      return txHash;
    } catch (e, stack) {
      print("Android Notarize ERROR: $e");
      print("STACK: $stack");
      rethrow;
    }
  }
}
