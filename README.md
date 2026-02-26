# BioNotary (UI only)

Responsive Flutter UI for a blockchain-backed document notarization concept. This commit includes UI only (no blockchain or file handling yet) and is designed to run on mobile and web. The layout adapts between three columns (desktop), two columns (tablet), and stacked sections (mobile).

## Run

```bash
flutter pub get
flutter run -d chrome   # Web
flutter run             # Mobile (choose a device)
```

## Structure

- `lib/main.dart`: Implements three sections
  - Applicant Details
  - Upload Supporting Documents (drop zone + list placeholders)
  - Verify Document Integrity (drop zone + hash input + success banner placeholder)

## Notes

- The current UI uses placeholders for file picking, drag & drop, and hash verification. Logic will be added later.
- Breakpoints: 1000px (desktop 3-col), 700px (tablet 2-col), below 700px (mobile).

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
