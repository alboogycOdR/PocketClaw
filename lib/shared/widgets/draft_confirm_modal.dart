/// Reusable modal dialog for confirming consequential Paperclip actions
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';

// ── Risk Level ──

enum RiskLevel { low, medium, high }

// ── Modal Widget ──

class DraftConfirmModal extends StatelessWidget {
  final String title;
  final String preview;
  final String riskSummary;
  final RiskLevel riskLevel;
  final VoidCallback onApprove;
  final VoidCallback onCancel;

  const DraftConfirmModal({
    super.key,
    required this.title,
    required this.preview,
    required this.riskSummary,
    required this.riskLevel,
    required this.onApprove,
    required this.onCancel,
  });

  // Not const — PocketClawTheme accents resolve through the active
  // palette, which is mutable across theme switches.
  static Color get _lowColor => PocketClawTheme.success;
  static Color get _mediumColor => PocketClawTheme.warning;
  static Color get _highColor => PocketClawTheme.lobsterRed;

  Color get _riskColor => switch (riskLevel) {
        RiskLevel.low => _lowColor,
        RiskLevel.medium => _mediumColor,
        RiskLevel.high => _highColor,
      };

  String get _riskLabel => switch (riskLevel) {
        RiskLevel.low => 'Low',
        RiskLevel.medium => 'Medium',
        RiskLevel.high => 'High',
      };

  /// Shows the modal and returns true if approved, false if cancelled.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String preview,
    required String riskSummary,
    RiskLevel riskLevel = RiskLevel.medium,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DraftConfirmModal(
        title: title,
        preview: preview,
        riskSummary: riskSummary,
        riskLevel: riskLevel,
        onApprove: () => Navigator.of(ctx).pop(true),
        onCancel: () => Navigator.of(ctx).pop(false),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: PocketClawTheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: _riskColor, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: PocketClawTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withAlpha(80),
              ),
            ),
            child: SingleChildScrollView(
              child: Text(
                preview,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Risk summary
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _riskColor.withAlpha(38),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _riskColor, width: 1),
                ),
                child: Text(
                  _riskLabel,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _riskColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  riskSummary,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: Text(
            'Cancel',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white54,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: onApprove,
          style: ElevatedButton.styleFrom(
            backgroundColor: _lowColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            'Approve',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
