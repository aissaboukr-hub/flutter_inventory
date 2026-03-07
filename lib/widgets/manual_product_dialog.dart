import 'package:flutter/material.dart';
import 'package:flutter_inventory/theme/app_theme.dart';

class ManualProductDialog extends StatefulWidget {
  final String? prefillBarcode;

  const ManualProductDialog({super.key, this.prefillBarcode});

  @override
  State<ManualProductDialog> createState() => _ManualProductDialogState();
}

class _ManualProductDialogState extends State<ManualProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeCtrl;
  late final TextEditingController _designationCtrl;
  late final TextEditingController _barcodeCtrl;
  final _qtyCtrl = TextEditingController(text: '1');
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController();
    _designationCtrl = TextEditingController();
    _barcodeCtrl = TextEditingController(text: widget.prefillBarcode ?? '');
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _designationCtrl.dispose();
    _barcodeCtrl.dispose();
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, {
        'code': _codeCtrl.text.trim(),
        'designation': _designationCtrl.text.trim(),
        'barcode': _barcodeCtrl.text.trim(),
        'quantity': double.tryParse(_qtyCtrl.text) ?? 1.0,
        'note': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.add_box_outlined, color: AppTheme.warningColor),
          SizedBox(width: 8),
          Text('Ajout manuel'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _designationCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Désignation *',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => v == null || v.trim().isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Code produit',
                  prefixIcon: Icon(Icons.tag),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _barcodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Code-barres',
                  prefixIcon: Icon(Icons.qr_code),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(
                  labelText: 'Quantité *',
                  prefixIcon: Icon(Icons.numbers),
                ),
                validator: (v) {
                  if (v == null || double.tryParse(v) == null) return 'Valeur invalide';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (optionnel)',
                  prefixIcon: Icon(Icons.note_outlined),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.add),
          label: const Text('Ajouter'),
        ),
      ],
    );
  }
}
