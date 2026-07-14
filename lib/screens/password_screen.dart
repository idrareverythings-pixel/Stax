import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/deck_provider.dart';
import '../services/pdf_service.dart';

class PasswordScreen extends StatefulWidget {
  const PasswordScreen({super.key});

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final _passwordCtrl = TextEditingController();
  bool _allowPrinting = true;
  bool _allowCopy = false;
  bool _working = false;

  Future<void> _apply(BuildContext context) async {
    if (_passwordCtrl.text.trim().length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Use at least 4 characters')),
      );
      return;
    }
    setState(() => _working = true);
    final deck = context.read<DeckProvider>();

    try {
      final merged = await deck.exportMerged();
      final protected = await PdfService.protect(
        sourceBytes: merged,
        userPassword: _passwordCtrl.text.trim(),
        allowPrinting: _allowPrinting,
        allowCopyContent: _allowCopy,
      );
      final file = await PdfService.saveToTempFile(protected, 'stax-protected.pdf');
      if (context.mounted) {
        await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'Password-protected with Stax'));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Password protect')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anyone opening this PDF will need this password. The document is encrypted with AES-256.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Open password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow printing'),
              value: _allowPrinting,
              onChanged: (v) => setState(() => _allowPrinting = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow copying text/images'),
              value: _allowCopy,
              onChanged: (v) => setState(() => _allowCopy = v),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _working ? null : () => _apply(context),
                child: _working
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Protect & share'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
