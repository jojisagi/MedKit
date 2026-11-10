import 'package:flutter/material.dart';

import '../../data/dose_repository.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Varias tomas del mismo medicamento (p. ej. dos personas): elegir de quién es.
Future<DoseDetail?> showPendingPicker(BuildContext context, List<DoseDetail> options) =>
    showModalBottomSheet<DoseDetail>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
              child: Text('¿De quién es esta toma?', style: c.text.headlineSmall),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                '${options.first.product.name} está pendiente para varias personas.',
                style: c.text.bodyMedium,
              ),
            ),
            for (final d in options)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                leading: ProfileAvatar(d.profile),
                title: Text(d.profile.name),
                subtitle: Text(
                  '${doseLabel(d.product, d.treatment.dose)} · ${fmtTime(d.dose.scheduledAt)}',
                  style: numerals(c.text.bodyMedium!),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(c, d),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
