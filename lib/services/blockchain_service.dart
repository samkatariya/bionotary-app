import 'package:flutter_web3/flutter_web3.dart';
import 'package:crypto/crypto.dart';

class BlockchainService {
  static const String contractAddress =
      "0x4ed3E045C6Bf294d0934fb5f2199334d7075c903";

  static const String contractAbi = '''
[
  {
    "inputs": [
      {"internalType": "bytes32","name": "docHash","type": "bytes32"},
      {"internalType": "bytes32","name": "userHash","type": "bytes32"}
    ],
    "name": "notarize",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
]
''';

  static Future<String> notarize({
    required String docHashHex,
    required String walletAddress,
  }) async {
    if (!Ethereum.isSupported || ethereum == null) {
      throw Exception("MetaMask not detected");
    }

    // Ensure Sepolia
    final chainId = await ethereum!.getChainId();
    if (chainId != 11155111) {
      // Sepolia chain ID as int
      throw Exception("Please switch MetaMask to Sepolia");
    }

    // Request account access if needed
    final accounts = await ethereum!.requestAccount();
    if (accounts.isEmpty) {
      throw Exception("No wallet account connected");
    }

    final provider = Web3Provider(ethereum!);
    final signer = provider.getSigner();

    final contract = Contract(contractAddress, Interface(contractAbi), signer);

    // Clean 0x prefix if present
    final cleanedDocHash =
        docHashHex.startsWith("0x") ? docHashHex.substring(2) : docHashHex;
    final String docHashBytes32 = "0x$cleanedDocHash";

    final userHashHex = sha256.convert(walletAddress.codeUnits).toString();
    final cleanedUserHash =
        userHashHex.startsWith("0x") ? userHashHex.substring(2) : userHashHex;
    final String userHashBytes32 = "0x$cleanedUserHash";

    try {
      final tx = await contract.send("notarize", [
        docHashBytes32,
        userHashBytes32,
      ]);
      return tx.hash;
    } catch (e, stack) {
      print("ERROR: $e");
      print("STACK: $stack");
      rethrow;
    }
  }
}
