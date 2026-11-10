import 'package:flutter/material.dart';

import '../../domain/inventory_rules.dart';
import '../../domain/models.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Una caja física: dueño, unidades restantes (barra real, no decorativa) y caducidad.
class BoxTile extends StatelessWidget {
  final Box box;
  final Product product;
  final Profile? owner;
  final VoidCallback? onTap;
  const BoxTile({super.key, required this.box, required this.product, this.owner, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.sign;
    final today = dateOnly(DateTime.now());
    final expired = isExpired(box, today);
    final soon = !expired && box.expiresOn.difference(today).inDays <= 30;
    final ratio = box.unitsInitial <= 0 ? 0.0 : (box.unitsLeft / box.unitsInitial).clamp(0.0, 1.0);
    final barColor = owner == null ? t.inkSoft : zoneOn(context, Color(owner!.color));
    return Panel(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: owner == null
                    ? Row(
                        children: [
                          Icon(Icons.groups_2_outlined, size: 20, color: t.inkSoft),
                          const SizedBox(width: 8),
                          Text('Compartida', style: context.text.labelLarge!.copyWith(color: t.inkSoft)),
                        ],
                      )
                    : ProfileTag(owner!),
              ),
              Text(
                '${fmtUnits(box.unitsLeft)} / ${fmtUnits(box.unitsInitial)}',
                style: numerals(context.text.titleMedium!),
              ),
              const SizedBox(width: 4),
              Text(product.unit == 'ml' ? 'ml' : 'pzas', style: context.text.bodySmall),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: t.rule,
              color: expired ? t.danger : barColor,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                expired ? Icons.block_rounded : Icons.event_rounded,
                size: 18,
                color: expired ? t.danger : (soon ? t.caution : t.inkSoft),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${daysUntilLabel(box.expiresOn, today)} · ${fmtDateShort(box.expiresOn)}',
                  style: numerals(
                    context.text.labelMedium!.copyWith(color: expired ? t.danger : (soon ? t.caution : t.inkSoft)),
                  ),
                ),
              ),
              if (box.lot != null && box.lot!.isNotEmpty) Text('Lote ${box.lot}', style: context.text.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
