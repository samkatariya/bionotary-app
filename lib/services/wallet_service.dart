import 'package:flutter_web3/flutter_web3.dart';

class WalletService {
  static bool get isSupported => Ethereum.isSupported;

  static Future<String?> connectWallet() async {
    if (!isSupported) return null;

    final accounts = await ethereum!.requestAccount();
    return accounts.isNotEmpty ? accounts.first : null;
  }

  static String? get currentAccount => ethereum?.selectedAddress;
}
