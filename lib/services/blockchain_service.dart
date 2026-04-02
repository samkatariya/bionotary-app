import 'package:crypto/crypto.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

// Platform-specific imports
import 'package:flutter_web3/flutter_web3.dart' if (dart.library.html) 'package:flutter_web3/flutter_web3.dart';
import 'mobile_wallet_service.dart';
import 'js_interop_stub.dart' as js_interop if (dart.library.html) 'js_interop_web.dart';

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
    print("ETH: current chainId=$chainId");
    if (chainId != 11155111) {
      throw Exception("Please switch MetaMask to Sepolia");
    }

    // Request account access if needed
    final accounts = await ethereum!.requestAccount();
    print("ETH: accounts=$accounts");
    if (accounts.isEmpty) {
      throw Exception("No wallet account connected");
    }
    final selectedAddress = ethereum!.selectedAddress;
    print("ETH: selectedAddress=$selectedAddress");

    // Ensure MetaMask is switched to Sepolia (0xaa36a7)
    final switchChainParam = js_interop.jsify(<String, dynamic>{
      "chainId": "0xaa36a7",
    });
    await ethereum!.request(
      "wallet_switchEthereumChain",
      [
        switchChainParam
      ],
    );
    final chainIdAfter = await ethereum!.getChainId();
    print("ETH: chainId after switch=$chainIdAfter");

    final cleaned = docHashHex.startsWith("0x") ? docHashHex : "0x$docHashHex";
    final userHashHex = sha256.convert(walletAddress.codeUnits).toString();
    final userHash = "0x$userHashHex";

    // Build the calldata: selector + docHash + userHash
    final calldata = notarizeSelector +
        cleaned.substring(2).padLeft(64, '0') +
        userHash.substring(2).padLeft(64, '0');
    print("ETH: contractAddress=$contractAddress");
    print("ETH: calldata startsWith 0x=${calldata.startsWith("0x")}");
    print("ETH: calldata length=${calldata.length}");
    print("ETH: calldata preview=${calldata.length > 18 ? '${calldata.substring(0, 12)}...${calldata.substring(calldata.length - 6)}' : calldata}");

    final txObject = <String, dynamic>{
      "to": contractAddress,
      "data": calldata,
    };

    Object? estimateGasError;

    try {
      // Send transaction via eth_sendTransaction JSON-RPC.
      // Use the same ethereum!.request(...) signature as wallet_switchEthereumChain above
      // to avoid payload shape mismatches.
      print("ETH: sending eth_sendTransaction...");

      // Log estimateGas first; if params shape is wrong, you'll see it here too.
      try {
        // Build a fresh JS object per RPC call.
        // JS objects are passed by reference and MetaMask may mutate it.
        final gasParam = js_interop.jsify(txObject);
        final gas = await ethereum!.request(
          "eth_estimateGas",
          [
            gasParam,
          ],
        );
        print("ETH: estimateGas result=$gas");
      } catch (e, stack) {
        print("ETH: estimateGas ERROR: $e");
        print("ETH: estimateGas STACK: $stack");
        estimateGasError = e;
      }

      // Build a fresh JS object per RPC call (do not reuse across calls).
      final sendParam = js_interop.jsify(txObject);
      final result = await ethereum!.request(
        "eth_sendTransaction",
        [
          sendParam
        ],
      );
      print("ETH: eth_sendTransaction result=$result");
      return result.toString();
    } catch (e, stack) {
      // Include the payload in the thrown error so you can see it in the app UI
      // even if console/terminal logs are not visible.
      final msg = StringBuffer()
        ..writeln("MetaMask eth_sendTransaction failed: $e")
        ..writeln("chainId=$chainId")
        ..writeln("chainIdAfter=$chainIdAfter")
        ..writeln("selectedAddress=$selectedAddress")
        ..writeln("txObject=$txObject")
        ..writeln("calldataLen=${calldata.length}")
        ..writeln("estimateGasError=$estimateGasError")
        ..writeln("stack=$stack");
      print(msg.toString());
      throw Exception(msg.toString());
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
