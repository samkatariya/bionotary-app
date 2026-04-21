import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:crypto/crypto.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'services/wallet_service.dart';
import 'services/blockchain_service.dart';
import 'services/api_service.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const BioNotaryApp());
}

class BioNotaryApp extends StatelessWidget {
  const BioNotaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BioNotary',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _hasToken;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final has = await ApiService.hasToken();
    if (mounted) setState(() => _hasToken = has);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasToken == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_hasToken == false) {
      return LoginScreen(onLoginSuccess: _checkAuth);
    }
    return BioNotaryHomePage(onLogout: (_) => _checkAuth());
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLoginSuccess});

  final Future<void> Function() onLoginSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _registerMode = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_registerMode) {
        final phoneTrim = _phoneController.text.trim();
        await ApiService.register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          phone: phoneTrim.isEmpty ? null : phoneTrim,
        );
        if (!mounted) return;
        setState(() {
          _registerMode = false;
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created. You can log in now.')),
        );
        return;
      }

      final res = await ApiService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      if (res['token'] != null) {
        await widget.onLoginSuccess();
        if (mounted) {
          setState(() => _loading = false);
        }
      } else {
        setState(() {
          _loading = false;
          _error = res['message']?.toString() ?? 'Login failed';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _fingerprintLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService.fingerprintLogin();
      if (!mounted) return;
      if (res['token'] != null) {
        await widget.onLoginSuccess();
        if (mounted) setState(() => _loading = false);
      } else {
        setState(() {
          _loading = false;
          _error = res['message']?.toString() ?? 'Fingerprint login failed';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'BioNotary',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(value: false, label: Text('Log in')),
                    ButtonSegment<bool>(value: true, label: Text('Register')),
                  ],
                  selected: {_registerMode},
                  onSelectionChanged: (s) {
                    setState(() {
                      _registerMode = s.first;
                      _error = null;
                    });
                  },
                ),
                const SizedBox(height: 24),
                if (_registerMode) ...[
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Full name'),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                if (_registerMode) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone (optional)',
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child:
                      _loading
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Text(_registerMode ? 'Create account' : 'Log in'),
                ),
                if (!_registerMode) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _fingerprintLogin,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Log in with fingerprint'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BioNotaryHomePage extends StatefulWidget {
  const BioNotaryHomePage({super.key, required this.onLogout});

  final void Function(BuildContext context) onLogout;

  @override
  State<BioNotaryHomePage> createState() => _BioNotaryHomePageState();
}

class _BioNotaryHomePageState extends State<BioNotaryHomePage> {
  List<_SelectedFile> _uploadedFiles = const [];

  static const double _wideBreakpoint = 1000; // three columns
  static const double _tabletBreakpoint = 700; // two columns

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    widget.onLogout(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('BioNotary'),
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
            icon: const Icon(Icons.fingerprint),
            tooltip: 'Enroll fingerprint',
            onPressed: () async {
              try {
                await ApiService.enrollFingerprint();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fingerprint enrolled')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Enroll failed: $e')));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'My Documents',
            onPressed:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const DashboardScreen(),
                  ),
                ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;

            if (width >= _wideBreakpoint) {
              return _ThreeColumnLayout(
                left: const ApplicantDetailsCard(),
                center: UploadDocumentsCard(
                  onFilesChanged:
                      (files) => setState(() => _uploadedFiles = files),
                ),
                right: VerifyIntegrityCard(uploadedFiles: _uploadedFiles),
              );
            }

            if (width >= _tabletBreakpoint) {
              return _TwoColumnLayout(
                left: const ApplicantDetailsCard(),
                right: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    UploadDocumentsCard(
                      onFilesChanged:
                          (files) => setState(() => _uploadedFiles = files),
                    ),
                    const SizedBox(height: 16),
                    VerifyIntegrityCard(uploadedFiles: _uploadedFiles),
                  ],
                ),
              );
            }

            return _SingleColumnLayout(
              children: [
                const ApplicantDetailsCard(),
                UploadDocumentsCard(
                  onFilesChanged:
                      (files) => setState(() => _uploadedFiles = files),
                ),
                VerifyIntegrityCard(uploadedFiles: _uploadedFiles),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ThreeColumnLayout extends StatelessWidget {
  const _ThreeColumnLayout({
    required this.left,
    required this.center,
    required this.right,
  });

  final Widget left;
  final Widget center;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 16),
          Expanded(child: center),
          const SizedBox(width: 16),
          Expanded(child: right),
        ],
      ),
    );
  }
}

class _TwoColumnLayout extends StatelessWidget {
  const _TwoColumnLayout({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 16),
          Expanded(child: right),
        ],
      ),
    );
  }
}

class _SingleColumnLayout extends StatelessWidget {
  const _SingleColumnLayout({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class ApplicantDetailsCard extends StatefulWidget {
  const ApplicantDetailsCard({super.key});

  @override
  State<ApplicantDetailsCard> createState() => _ApplicantDetailsCardState();
}

class _ApplicantDetailsCardState extends State<ApplicantDetailsCard> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _aadhaarController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _panController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _aadhaarController.dispose();
    _emailController.dispose();
    _panController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitApplicantDetails() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ApiService.saveApplicantDetails(
        firstName: _firstNameController.text.trim(),
        middleName: _middleNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        aadhaar: _aadhaarController.text.trim(),
        email: _emailController.text.trim(),
        pan: _panController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Applicant details saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving details: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Applicant Details',
      child: Form(
        key: _formKey,
      child: Column(
        children: [
          _TextFieldRow(
              fields: [
                _LabeledField(
                  label: 'First Name',
                  controller: _firstNameController,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                _LabeledField(
                  label: 'Middle Name (Optional)',
                  controller: _middleNameController,
                ),
            ],
          ),
          const SizedBox(height: 12),
            _LabeledField(
              label: 'Last Name',
              controller: _lastNameController,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
          const SizedBox(height: 12),
          _TextFieldRow(
              fields: [
                _LabeledField(
                  label: 'Aadhaar Number (12 Digits)',
                  controller: _aadhaarController,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.length != 12 || int.tryParse(s) == null) {
                      return 'Enter 12 digits';
                    }
                    return null;
                  },
                ),
                _LabeledField(
                  label: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty || !s.contains('@')) return 'Valid email required';
                    return null;
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          _TextFieldRow(
              fields: [
                _LabeledField(
                  label: 'PAN Card Number',
                  controller: _panController,
                ),
                _LabeledField(
                  label: 'Phone Number',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submitApplicantDetails,
                child:
                    _isSubmitting
                        ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Save Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UploadDocumentsCard extends StatefulWidget {
  const UploadDocumentsCard({super.key, required this.onFilesChanged});

  final void Function(List<_SelectedFile> files) onFilesChanged;

  @override
  State<UploadDocumentsCard> createState() => _UploadDocumentsCardState();
}

class _UploadDocumentsCardState extends State<UploadDocumentsCard> {
  static const int _maxFileBytes = 10 * 1024 * 1024;

  static String _fileExtensionToType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (ext == 'jpg' || ext == 'jpeg') return 'jpeg';
    if (ext == 'png') return 'png';
    return 'pdf';
  }

  Future<void> _notarizeLastFile() async {
    if (!kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sepolia notarization runs on web with MetaMask. Use Chrome / Flutter web for this step.',
          ),
        ),
      );
      return;
    }
    if (_selectedFiles.isEmpty) return;
    if (_walletAddress == null) return;

    setState(() => _isSending = true);

    try {
      final selectedFile = _selectedFiles.last;
      final hash = selectedFile.hashHex;
      final fileType = _fileExtensionToType(selectedFile.name);

      // 1. Create document in DB
      final docResponse = await ApiService.createDocument(
        fileName: selectedFile.name,
        fileType: fileType,
        fileSize: selectedFile.size,
        sha256: hash,
      );

      final documentId = docResponse['document']?['id']?.toString();
      if (documentId == null) {
        throw Exception('Backend did not return document id: $docResponse');
      }

      // 2. Call blockchain
      final txHash = await BlockchainService.notarize(
        docHashHex: hash,
        walletAddress: _walletAddress!,
      );

      setState(() => _txHash = txHash);

      // 3. Store notarization
      await ApiService.createNotarization(
        documentId: documentId,
        txHash: txHash,
        contractAddress: BlockchainService.contractAddress,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document notarized successfully on Sepolia'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
      ScaffoldMessenger.of(
        context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _connectWallet() async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Wallet connection for notarization is only available on web (MetaMask).',
          ),
        ),
      );
      return;
    }
    final address = await WalletService.connectWallet();

    if (!mounted) return;
    if (address == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("MetaMask not detected")));
      return;
    }

    setState(() {
      _walletAddress = address;
    });
  }

  List<_SelectedFile> _selectedFiles = const [];
  String? _walletAddress;
  String? _txHash;
  bool _isSending = false;

  Future<void> _pickFiles() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (!mounted) return;
    if (result != null && result.files.isNotEmpty) {
      final List<_SelectedFile> filesWithHashes = <_SelectedFile>[];
      final List<String> skipped = [];
      for (final PlatformFile f in result.files) {
        final List<int>? bytes = f.bytes;
        final int byteLen = bytes?.length ?? f.size;
        if (byteLen > _maxFileBytes) {
          skipped.add(f.name);
          continue;
        }
        final String hash =
            bytes == null ? 'N/A' : sha256.convert(bytes).toString();
        filesWithHashes.add(
          _SelectedFile(name: f.name, size: byteLen, hashHex: hash),
        );
      }
      if (skipped.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Skipped (>${_maxFileBytes ~/ (1024 * 1024)} MB): ${skipped.join(", ")}',
            ),
          ),
        );
      }
      setState(() => _selectedFiles = filesWithHashes);
      widget.onFilesChanged(_selectedFiles);
    }
  }

  void _removeAt(int index) {
    setState(() {
      final List<_SelectedFile> updated = List.of(_selectedFiles);
      updated.removeAt(index);
      _selectedFiles = updated;
    });
    widget.onFilesChanged(_selectedFiles);
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Upload Supporting Documents',
      subtitle:
          'Please upload your official documents for verification. Accepted formats: PDF, JPEG, PNG (Max file size: 10MB).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _DropZonePlaceholder(height: 140),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.center,
            child: FilledButton(
              onPressed: _pickFiles,
              child: const Text('Choose File'),
            ),
          ),
          const SizedBox(height: 12),
          if (_selectedFiles.isNotEmpty)
            _SelectedFilesList(files: _selectedFiles, onRemoveAt: _removeAt),
          const SizedBox(height: 16),
          if (kIsWeb) ...[
            if (_walletAddress == null)
              FilledButton(
                onPressed: _connectWallet,
                child: const Text("Connect MetaMask"),
              )
            else
              Text("Connected: $_walletAddress"),
            const SizedBox(height: 12),
            if (_selectedFiles.isNotEmpty)
              FilledButton(
                onPressed: _isSending ? null : _notarizeLastFile,
                child:
                    _isSending
                        ? const CircularProgressIndicator()
                        : const Text("Notarize on Sepolia"),
              ),
          ] else ...[
            Text(
              'Notarize on Sepolia: use the web app (MetaMask).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (_txHash != null) ...[
            const SizedBox(height: 8),
            SelectableText("Tx Hash: $_txHash"),
          ],
        ],
      ),
    );
  }
}

class VerifyIntegrityCard extends StatefulWidget {
  const VerifyIntegrityCard({super.key, required this.uploadedFiles});

  final List<_SelectedFile> uploadedFiles;

  @override
  State<VerifyIntegrityCard> createState() => _VerifyIntegrityCardState();
}

class _VerifyIntegrityCardState extends State<VerifyIntegrityCard> {
  String? _actualHash;
  bool _bannerVisible = false;
  bool _isSuccess = false;
  String _bannerMessage = '';

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickActualFileAndHash() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.any,
    );
    if (!mounted) return;
    if (result != null && result.files.isNotEmpty) {
      final PlatformFile file = result.files.first;
      final List<int>? bytes = file.bytes;
      setState(() {
        _actualHash = bytes == null ? null : sha256.convert(bytes).toString();
      });
    }
  }

  Future<void> _verify() async {
    final String? expected =
        widget.uploadedFiles.isNotEmpty
            ? widget.uploadedFiles.last.hashHex.toLowerCase()
            : null;
    final String? actual = _actualHash?.toLowerCase();
    if (expected == null || actual == null) {
      setState(() {
        _isSuccess = false;
        _bannerMessage =
            widget.uploadedFiles.isEmpty
                ? 'Please upload a file first in Upload Supporting Documents.'
                : 'Please choose a file to verify.';
        _bannerVisible = true;
      });
    } else {
      final bool matches = expected == actual;
      String msg =
          matches
              ? 'Document Verified Successfully! The hashes match.'
              : 'Verification failed. The hashes do not match.';
      if (matches && actual != 'n/a') {
        try {
          final reg = await ApiService.lookupDocumentByHash(actual);
          if (reg != null) {
            final tx = reg['transaction_hash']?.toString();
            if (tx != null && tx.isNotEmpty) {
              msg += ' Registered on server with on-chain tx.';
            } else {
              msg += ' Registered on server (not yet anchored on-chain).';
            }
          }
        } catch (_) {
          /* optional server check */
        }
      }
      setState(() {
        _isSuccess = matches;
        _bannerMessage = msg;
        _bannerVisible = true;
      });
    }

    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _bannerVisible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Verify Document Integrity',
      subtitle:
          'Upload your official documents to validate their hash (Max file size: 15MB).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _DropZonePlaceholder(height: 140),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('File to verify'),
                    Text(
                      _actualHash == null
                          ? 'No file selected'
                          : 'SHA-256: $_actualHash',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _pickActualFileAndHash,
                child: const Text('Choose File'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.uploadedFiles.isNotEmpty)
            Text(
              'Latest uploaded hash: ${widget.uploadedFiles.last.hashHex}',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (widget.uploadedFiles.isEmpty)
            Text(
              'No uploaded files yet.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _verify,
            child: const Text('Verify Document'),
          ),
          const SizedBox(height: 12),
          _SuccessBanner(
            visible: _bannerVisible,
            success: _isSuccess,
            message: _bannerMessage,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
              ),
            ],
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _TextFieldRow extends StatelessWidget {
  const _TextFieldRow({required this.fields});

  final List<Widget> fields;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 520;
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < fields.length; i++) ...[
                fields[i],
                if (i != fields.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: fields[0]),
            const SizedBox(width: 12),
            Expanded(child: fields[1]),
          ],
        );
      },
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    this.controller,
    this.keyboardType,
    this.validator,
  });

  final String label;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
      validator: validator,
    );
  }
}

class _DropZonePlaceholder extends StatelessWidget {
  const _DropZonePlaceholder({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey.shade400,
          style: BorderStyle.solid,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade50,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.cloud_upload_outlined, size: 36, color: Colors.grey),
            SizedBox(height: 8),
            Text('Drag & drop files here or click Choose File'),
          ],
        ),
      ),
    );
  }
}

class _SelectedFilesList extends StatelessWidget {
  const _SelectedFilesList({required this.files, required this.onRemoveAt});

  final List<_SelectedFile> files;
  final void Function(int index) onRemoveAt;

  String _prettySize(int bytes) {
    const int kb = 1024;
    const int mb = 1024 * 1024;
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    final Color border = Colors.grey.shade300;
    return Column(
      children: [
        for (int i = 0; i < files.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.insert_drive_file_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        files[i].name,
                        style: Theme.of(context).textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _prettySize(files[i].size),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'SHA-256: ${files[i].hashHex}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => onRemoveAt(i),
                  icon: const Icon(Icons.close),
                  tooltip: 'Remove',
                ),
              ],
            ),
          ),
          if (i != files.length - 1) Divider(height: 1, color: border),
        ],
      ],
    );
  }
}

class _SelectedFile {
  const _SelectedFile({
    required this.name,
    required this.size,
    required this.hashHex,
  });

  final String name;
  final int size;
  final String hashHex;
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({
    required this.visible,
    required this.success,
    required this.message,
  });

  final bool visible;
  final bool success;
  final String message;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final Color bg =
        success ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2);
    final Color border =
        success ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final Color icon =
        success ? const Color(0xFF059669) : const Color(0xFFB91C1C);
    final Color text =
        success ? const Color(0xFF065F46) : const Color(0xFF7F1D1D);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(success ? Icons.verified : Icons.error_outline, color: icon),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: text))),
        ],
      ),
    );
  }
}
