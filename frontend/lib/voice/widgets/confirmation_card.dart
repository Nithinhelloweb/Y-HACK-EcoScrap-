import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/voice_command.dart';

class ConfirmationCard extends StatelessWidget {
  final List<VoiceEntityItem> items;
  final double? weightKg;
  final String? executedAction;
  final Map<String, dynamic>? executedResult;
  final bool requiresConfirmation;
  final String? confirmationPrompt;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const ConfirmationCard({
    super.key,
    required this.items,
    this.weightKg,
    this.executedAction,
    this.executedResult,
    required this.requiresConfirmation,
    this.confirmationPrompt,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    if (items.isEmpty && !requiresConfirmation && executedAction == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: requiresConfirmation
              ? AppTheme.alertAmber.withValues(alpha: 0.8)
              : AppTheme.collectorColor.withValues(alpha: 0.4),
          width: requiresConfirmation ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    requiresConfirmation ? Icons.gavel_rounded : Icons.inventory_2_rounded,
                    size: 16,
                    color: requiresConfirmation ? AppTheme.alertAmber : AppTheme.collectorColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    requiresConfirmation ? 'Confirmation Required' : 'Extracted Entities',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: requiresConfirmation ? AppTheme.alertAmber : AppTheme.collectorColor,
                    ),
                  ),
                ],
              ),
              if (executedAction != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.collectorColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Action: $executedAction',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.collectorColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Extracted items list
          if (items.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: items.map((it) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black45 : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? AppTheme.borderSubtle : AppTheme.borderLight),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 13, color: AppTheme.collectorColor),
                      const SizedBox(width: 6),
                      Text(
                        '${it.quantity.toStringAsFixed(0)} × ${it.name}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.getTextPrimary(context),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            if (weightKg != null) ...[
              const SizedBox(height: 8),
              Text(
                'Estimated Weight: $weightKg kg',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getTextSecondary(context),
                ),
              ),
            ],
          ],

          // Confirmation Prompt (Consequential Action)
          if (requiresConfirmation && confirmationPrompt != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.alertAmber.withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.alertAmber.withValues(alpha: 0.3)),
              ),
              child: Text(
                confirmationPrompt!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.collectorColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    onPressed: onConfirm,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: BorderSide(color: AppTheme.getBorder(context)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.getTextPrimary(context))),
                    onPressed: onCancel,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
