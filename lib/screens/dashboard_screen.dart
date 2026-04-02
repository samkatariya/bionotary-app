import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../main.dart';
import 'package:url_launcher/url_launcher.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<dynamic>> _documents;
  bool _errorSnackBarShown = false;

  @override
  void initState() {
    super.initState();
    _documents = ApiService.getMyDocuments();
  }

  void _retry() {
    setState(() {
      _errorSnackBarShown = false;
      _documents = ApiService.getMyDocuments();
    });
  }

  Color _statusColor(String status) {
    if (status == "confirmed") return Colors.green;
    if (status == "pending") return Colors.orange;
    return Colors.grey;
  }

  Future<void> _openTx(String txHash) async {
    final url = Uri.parse("https://sepolia.etherscan.io/tx/$txHash");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _continueToApp() {
    // `DashboardScreen` is typically pushed from `BioNotaryHomePage`,
    // so popping returns the user to the app.
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    // Fallback for edge-cases where there's no route to pop.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const BioNotaryApp()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("My Documents"),
            FutureBuilder<String?>(
              future: ApiService.getStoredUserEmail(),
              builder: (context, snap) {
                final email = snap.data;
                return Text(
                  email != null && email.isNotEmpty
                      ? "Logged in as $email"
                      : "Not logged in",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () async {
              await ApiService.logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const BioNotaryApp()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _documents,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            if (!_errorSnackBarShown) {
              _errorSnackBarShown = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      snapshot.error.toString().replaceFirst('Exception: ', ''),
                    ),
                    action: SnackBarAction(label: 'Retry', onPressed: _retry),
                  ),
                );
              });
            }
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("No documents yet"),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _retry,
                    child: const Text("Retry load"),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () async {
                      // If we got here due to missing/invalid JWT, force
                      // re-authentication by going back to the app root.
                      await ApiService.logout();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const BioNotaryApp()),
                        (route) => false,
                      );
                    },
                    child: const Text("Continue to app"),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!;

          if (docs.isEmpty) {
            return const Center(child: Text("No documents yet"));
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index] as Map<String, dynamic>;
                    final status =
                        doc["notarization_status"] as String? ??
                        ((doc["transaction_hash"] != null &&
                                doc["transaction_hash"]
                                    .toString()
                                    .isNotEmpty)
                            ? "confirmed"
                            : "pending");

                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc["file_name"]?.toString() ?? "—",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Hash: ${doc["sha256_hash"] ?? "—"}",
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Text("Status: "),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusColor(status).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(color: _statusColor(status)),
                                  ),
                                ),
                              ],
                            ),
                            if (doc["transaction_hash"] != null &&
                                doc["transaction_hash"]
                                    .toString()
                                    .isNotEmpty) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () =>
                                    _openTx(doc["transaction_hash"].toString()),
                                child: const Text("View on Sepolia"),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: FilledButton(
                    onPressed: _continueToApp,
                    child: const Text("Continue to app"),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
