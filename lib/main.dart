import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:crypto/crypto.dart';
import 'dart:async';
import 'services/wallet_service.dart';
import 'services/blockchain_service.dart';

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
      home: const BioNotaryHomePage(),
    );
  }
}

class BioNotaryHomePage extends StatefulWidget {
  const BioNotaryHomePage({super.key});

  @override
  State<BioNotaryHomePage> createState() => _BioNotaryHomePageState();
}

class _BioNotaryHomePageState extends State<BioNotaryHomePage> {
  List<_SelectedFile> _uploadedFiles = const [];

  static const double _wideBreakpoint = 1000; // three columns
  static const double _tabletBreakpoint = 700; // two columns

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BioNotary')),
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

class ApplicantDetailsCard extends StatelessWidget {
  const ApplicantDetailsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Applicant Details',
      child: Column(
        children: [
          _TextFieldRow(
            fields: const [
              _LabeledField(label: 'First Name'),
              _LabeledField(label: 'Middle Name (Optional)'),
            ],
          ),
          const SizedBox(height: 12),
          const _LabeledField(label: 'Last Name'),
          const SizedBox(height: 12),
          _TextFieldRow(
            fields: const [
              _LabeledField(label: 'Aadhaar Number (12 Digits)'),
              _LabeledField(label: 'Email'),
            ],
          ),
          const SizedBox(height: 12),
          _TextFieldRow(
            fields: const [
              _LabeledField(label: 'PAN Card Number'),
              _LabeledField(label: 'Phone Number'),
            ],
          ),
        ],
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
  Future<void> _notarizeLastFile() async {
    if (_selectedFiles.isEmpty) return;
    if (_walletAddress == null) return;

    setState(() => _isSending = true);

    try {
      final hash = _selectedFiles.last.hashHex;

      final tx = await BlockchainService.notarize(
        docHashHex: hash,
        walletAddress: _walletAddress!,
      );

      setState(() {
        _txHash = tx;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    setState(() => _isSending = false);
  }

  Future<void> _connectWallet() async {
    final address = await WalletService.connectWallet();

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
      for (final PlatformFile f in result.files) {
        final List<int>? bytes = f.bytes;
        final String hash =
            bytes == null ? 'N/A' : sha256.convert(bytes).toString();
        filesWithHashes.add(
          _SelectedFile(name: f.name, size: f.size, hashHex: hash),
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

  void _verify() {
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
      setState(() {
        _isSuccess = matches;
        _bannerMessage =
            matches
                ? 'Document Verified Successfully! The hashes match.'
                : 'Verification failed. The hashes do not match.';
        _bannerVisible = true;
      });
    }

    Future.delayed(const Duration(seconds: 3), () {
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
  const _LabeledField({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return TextFormField(decoration: InputDecoration(labelText: label));
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
