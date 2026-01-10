import 'package:flutter/material.dart';
import '../models/menu_item.dart';
import 'package:lucide_icons/lucide_icons.dart';

class MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const MenuItemCard({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  // Helper to map string icon names to IconData
  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'pizza': return LucideIcons.pizza;
      case 'utensils': return LucideIcons.utensils;
      case 'sandwich': return LucideIcons.sandwich;
      case 'coffee': return LucideIcons.coffee;
      default: return LucideIcons.utensils;
    }
  }

  // Helper to parse color strings (simplified mapping)
  Color _getColor(String colorClass) {
    if (colorClass.contains('orange')) return Colors.orange.shade100;
    if (colorClass.contains('yellow')) return Colors.yellow.shade100;
    if (colorClass.contains('amber')) return Colors.amber.shade100;
    if (colorClass.contains('red')) return Colors.red.shade100;
    if (colorClass.contains('green')) return Colors.green.shade100;
    if (colorClass.contains('stone')) return Colors.grey.shade300;
    return Colors.blue.shade100;
  }

  Color _getTextColor(String colorClass) {
     if (colorClass.contains('orange')) return Colors.orange.shade900;
     if (colorClass.contains('yellow')) return Colors.yellow.shade900;
     if (colorClass.contains('amber')) return Colors.amber.shade900;
     if (colorClass.contains('red')) return Colors.red.shade900;
     if (colorClass.contains('green')) return Colors.green.shade900;
     if (colorClass.contains('stone')) return Colors.grey.shade800;
     return Colors.blue.shade900;
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _getColor(item.color);
    final textColor = _getTextColor(item.color);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? bgColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? textColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: bgColor.withOpacity(0.5),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.5) : bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIcon(item.icon),
                color: textColor,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: Text(
                item.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isSelected ? textColor : Colors.grey.shade800,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
