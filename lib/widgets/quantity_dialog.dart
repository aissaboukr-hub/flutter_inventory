import 'package:flutter/material.dart';
import 'package:flutter_inventory/models/product.dart';
import 'package:flutter_inventory/theme/app_theme.dart';

class QuantityDialog extends StatefulWidget {
  final Product product;

  const QuantityDialog({super.key, required this.product});

  @override
  State<QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<QuantityDialog> {
  final _ctrl = TextEditingController(text: '1');
  double _quantity = 1;
  bool _isValid = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _validate(String value) {
    final v = double.tryParse(value);
    setState(() {
      _isValid = v != null;
      if (v != null) _quantity = v;
    });
  }

  void _increment() {
    setState(() {
      _quantity++;
      _ctrl.text = _quantity % 1 == 0 ? _quantity.toInt().toString() : _quantity.toStringAsFixed(2);
    });
  }

  void _decrement() {
    setState(() {
      _quantity--;
      _ctrl.text = _quantity % 1 == 0 ? _quantity.toInt().toString() : _quantity.toStringAsFixed(2);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.qr_code_scanner, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Produit trouvé', style: TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          Text(widget.product.designation,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          Text('Code: ${widget.product.code}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Saisir la quantité', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: _decrement,
                icon: const Icon(Icons.remove_circle_outline, size: 32, color: AppTheme.errorColor),
              ),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  textAlign: TextAlign.center,
                  autofocus: true,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    errorText: _isValid ? null : 'Valeur invalide',
                    hintText: '0',
                  ),
                  onChanged: _validate,
                  onSubmitted: (_) {
                    if (_isValid) Navigator.pop(context, _quantity);
                  },
                ),
              ),
              IconButton(
                onPressed: _increment,
                icon: const Icon(Icons.add_circle_outline, size: 32, color: AppTheme.secondaryColor),
              ),
            ],
          ),
          if (_quantity < 0)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.warningColor, size: 16),
                  SizedBox(width: 8),
                  Text('Quantité négative → correction d\'inventaire',
                      style: TextStyle(fontSize: 11, color: AppTheme.warningColor)),
                ],
              ),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton.icon(
          onPressed: _isValid ? () => Navigator.pop(context, _quantity) : null,
          icon: const Icon(Icons.check),
          label: const Text('Valider'),
        ),
      ],
    );
  }
}
