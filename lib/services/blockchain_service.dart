import 'package:crypto/crypto.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:flutter_web3/flutter_web3.dart';
import 'js_interop_stub.dart' as js_interop if (dart.library.js_interop) 'js_interop_web.dart';

class BlockchainService {
  /// Deployed notary **contract** (not a user wallet). Override per build:
  /// `flutter run --dart-define=BIONOTARY_CONTRACT_ADDRESS=0xYourContract`
  static const String contractAddress = String.fromEnvironment(
    'BIONOTARY_CONTRACT_ADDRESS',
    defaultValue: '0xCDa82472BD768156A5d961A0Ce61d9C93D4ffDA1',
  );

  /// Sepolia chain id (decimal).
  static const int sepoliaChainId = 11155111;

  /// `ethers.id('notarize(bytes32,bytes32)')` — must match the deployed contract.
  /// (The old value `0x4c0f4d72` does not match this Sepolia deployment.)
  static const String notarizeSelector = "0xe48a2630";

  static final RegExp _ethAddressRegex = RegExp(r'^0x[a-fA-F0-9]{40}$');

  static String _normalizeAddress(String raw, {required String label}) {
    var v = raw.trim();
    if ((v.startsWith('"') && v.endsWith('"')) ||
        (v.startsWith("'") && v.endsWith("'"))) {
      v = v.substring(1, v.length - 1).trim();
    }
    if (!_ethAddressRegex.hasMatch(v)) {
      throw FormatException('$label is not a valid Ethereum address: $raw');
    }
    return v;
  }

  /// Normalizes `eth_chainId` / `getChainId()` values (hex string, decimal string, int).
  static int parseChainId(dynamic raw) {
    if (raw == null) {
      throw FormatException('chainId was null');
    }
    if (raw is int) {
      return raw;
    }
    if (raw is BigInt) {
      return raw.toInt();
    }
    final s = raw.toString().trim();
    if (s.startsWith('0x') || s.startsWith('0X')) {
      return int.parse(s.substring(2), radix: 16);
    }
    return int.parse(s);
  }

  static Future<void> _ensureSepoliaChain() async {
    if (ethereum == null) {
      return;
    }
    Future<void> addSepolia() async {
      await ethereum!.walletAddChain(
        chainId: sepoliaChainId,
        chainName: 'Sepolia',
        nativeCurrency: CurrencyParams(
          name: 'Sepolia Ether',
          symbol: 'ETH',
          decimals: 18,
        ),
        rpcUrls: ['https://rpc.sepolia.org'],
        blockExplorerUrls: ['https://sepolia.etherscan.io'],
      );
      await ethereum!.walletSwitchChain(sepoliaChainId);
    }

    try {
      await ethereum!.walletSwitchChain(sepoliaChainId);
    } on EthereumUnrecognizedChainException catch (_) {
      await addSepolia();
    } on EthereumException catch (e) {
      if (e.code == 4902) {
        await addSepolia();
      } else {
        rethrow;
      }
    }
  }

  /// Second word of `notarize` calldata: SHA-256 of [walletAddress] using Dart
  /// [String.codeUnits] (UTF-16 code units; for ASCII `0x…` addresses this matches UTF-8 bytes).
  /// See `bionotary-backend/contracts/BioNotary.sol` for the on-chain record field.
  static String witnessBytes32Hex(String walletAddress) {
    final digest = sha256.convert(walletAddress.codeUnits).toString();
    return "0x$digest";
  }

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

    // Request account access first (needed before switch/add chain UX).
    final accounts = await ethereum!.requestAccount();
    print("ETH: accounts=$accounts");
    if (accounts.isEmpty) {
      throw Exception("No wallet account connected");
    }
    final selectedAddress = ethereum!.selectedAddress;
    final fromAddress = _normalizeAddress(
      accounts.first.toString(),
      label: 'wallet account',
    );
    final toAddress = _normalizeAddress(
      contractAddress,
      label: 'contract address',
    );
    print("ETH: selectedAddress=$selectedAddress");

    await _ensureSepoliaChain();

    // Prefer raw eth_chainId — flutter_web3 getChainId() can mis-parse hex strings.
    final chainIdAfter = parseChainId(await ethereum!.request('eth_chainId'));
    print("ETH: chainId after ensureSepolia=$chainIdAfter");
    if (chainIdAfter != sepoliaChainId) {
      throw Exception(
        "MetaMask must use Sepolia (chainId $sepoliaChainId); currently $chainIdAfter",
      );
    }

    final cleaned = docHashHex.startsWith("0x") ? docHashHex : "0x$docHashHex";
    final userHash = witnessBytes32Hex(walletAddress);

    // Build the calldata: selector + docHash + witness (bytes32)
    final calldata = notarizeSelector +
        cleaned.substring(2).padLeft(64, '0') +
        userHash.substring(2).padLeft(64, '0');
    print("ETH: contractAddress=$contractAddress");
    print("ETH: normalized from=$fromAddress");
    print("ETH: normalized to=$toAddress");
    print("ETH: calldata startsWith 0x=${calldata.startsWith("0x")}");
    print("ETH: calldata length=${calldata.length}");
    print(
      "ETH: calldata preview=${calldata.length > 18 ? '${calldata.substring(0, 12)}...${calldata.substring(calldata.length - 6)}' : calldata}",
    );

    // Only keys MetaMask expects; pass a clean object for JS interop.
    final txMap = <String, String>{
      'from': fromAddress,
      'to': toAddress,
      'data': calldata,
      'value': '0x0',
    };
    String? estimateGasErrorText;
    Object? estimateGasError;

    try {
      print("ETH: sending eth_sendTransaction...");

      try {
        // Fresh object per RPC call — MetaMask may mutate the param object.
        final gas = await ethereum!.request(
          "eth_estimateGas",
          [js_interop.jsify(txMap)],
        );
        print("ETH: estimateGas OK result=$gas");
      } catch (e, stack) {
        estimateGasError = e;
        estimateGasErrorText = "$e";
        print("ETH: estimateGas ERROR: $e");
        print("ETH: estimateGas STACK: $stack");
      }

      final sendParam = js_interop.jsify(txMap);
      final result = await ethereum!.request(
        "eth_sendTransaction",
        [sendParam],
      );
      print("ETH: eth_sendTransaction result=$result");
      return result.toString();
    } catch (e, stack) {
      final stage = estimateGasError != null && estimateGasErrorText != null
          ? "eth_sendTransaction (after estimateGas failed)"
          : "eth_sendTransaction";
      final msg = StringBuffer()
        ..writeln("MetaMask $stage failed: $e")
        ..writeln("--- compare stages ---")
        ..writeln(
          estimateGasError != null
              ? "[eth_estimateGas] failed: $estimateGasErrorText"
              : "[eth_estimateGas] OK (no error captured)",
        )
        ..writeln("[eth_sendTransaction] failed: $e")
        ..writeln("--- context ---")
        ..writeln("chainIdAfter=$chainIdAfter (expected $sepoliaChainId)")
        ..writeln("selectedAddress=$selectedAddress")
        ..writeln("txMap=$txMap")
        ..writeln("calldataLen=${calldata.length}")
        ..writeln("stack=$stack");
      print(msg.toString());
      throw Exception(msg.toString());
    }
  }

  /// Android: Sepolia notarization is only supported via the **web** app with MetaMask.
  /// WalletConnect is not wired end-to-end; use `flutter build web` and open in Chrome.
  static Future<String> _notarizeAndroid(
    String docHashHex,
    String walletAddress,
  ) async {
    throw UnsupportedError(
      'Sepolia notarization requires the web build with MetaMask. '
      'Run `flutter run -d chrome` or deploy the web app; Android WalletConnect is not enabled.',
    );
  }
}
