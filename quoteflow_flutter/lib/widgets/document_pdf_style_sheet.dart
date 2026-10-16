import 'package:flutter/material.dart';
import '../../models/document.dart';
import '../../services/pdf_service.dart';

/// Result of the per-document PDF style sheet. A null field means "use the
/// organization's default" for that aspect.
class PdfStyleResult {
  final String? pdfTheme;
  final String? logoPosition;
  final String? tableStyle;

  const PdfStyleResult({this.pdfTheme, this.logoPosition, this.tableStyle});
}

/// Bottom sheet letting the user override the PDF theme, logo position and
/// table style for a single document, with a live preview.
class DocumentPdfStyleSheet extends StatefulWidget {
  final QuoteflowDocument doc;

  const DocumentPdfStyleSheet({super.key, required this.doc});

  @override
  State<DocumentPdfStyleSheet> createState() => _DocumentPdfStyleSheetState();
}

class _DocumentPdfStyleSheetState extends State<DocumentPdfStyleSheet> {
  String? _theme;
  String? _position;
  String? _table;

  @override
  void initState() {
    super.initState();
    _theme = widget.doc.pdfTheme;
    _position = widget.doc.logoPosition;
    _table = widget.doc.tableStyle;
  }

  Color _accent(String id) {
    switch (id) {
      case 'modern':
        return const Color(0xFF1e293b);
      case 'minimal':
        return const Color(0xFF64748b);
      case 'bold':
        return const Color(0xFFdc2626);
      case 'elegant':
        return const Color(0xFF1f3a57);
      case 'boutique':
      case 'editorial':
      case 'ledger': return const Color(0xFF292929);
      case 'contractor': return const Color(0xFFFF8900);
      case 'studio': return const Color(0xFFEC6033);
      case 'fresh':
        return const Color(0xFF0d9488);
      default:
        return const Color(0xFFf97316);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effTheme = _theme ?? 'classic';
    final right = _position == 'right';
    final effTable = effectiveTableStyle(effTheme, _table);
    final accent = _accent(effTheme);
    final headerBg = (effTable == 'striped' || effTable == 'bordered')
        ? accent
        : null;
    final zebraBg = effTable == 'striped'
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.6)
        : null;
    final borderColor = scheme.outlineVariant;

    Widget miniRow(
      List<String> cells, {
      Color? bg,
      Color? text,
      bool header = false,
      bool underline = true,
    }) {
      return Container(
        decoration: BoxDecoration(
          color: bg,
          border: effTable == 'bordered'
              ? Border.all(color: borderColor, width: 0.5)
              : Border(
                  bottom: underline
                      ? BorderSide(color: borderColor, width: 0.5)
                      : BorderSide.none,
                ),
        ),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: header ? 5 : 4),
        child: Row(
          children: [
            for (final (i, c) in cells.indexed)
              Expanded(
                flex: i == 0 ? 3 : 1,
                child: Text(
                  c,
                  textAlign: i == 0 ? TextAlign.left : TextAlign.right,
                  style: TextStyle(
                    fontSize: header ? 7 : 9,
                    color: text ?? scheme.onSurface,
                    fontWeight: header ? FontWeight.w600 : FontWeight.w400,
                    letterSpacing: header ? 1 : 0,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    Widget titleCol() => Column(
      crossAxisAlignment: right
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Text(
          widget.doc.type.label.toUpperCase(),
          style: TextStyle(
            fontSize: 7,
            letterSpacing: 1.5,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          widget.doc.docNumber,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
      ],
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Document PDF style',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Overrides the company PDF settings for ${widget.doc.docNumber} only.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            // Live preview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2C2C2E)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (right) ...[
                        Expanded(child: titleCol()),
                        const SizedBox(width: 10),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ] else ...[
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: titleCol()),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  miniRow(
                    ['DESCRIPTION', 'QTY', 'AMOUNT'],
                    bg: headerBg,
                    text: headerBg != null
                        ? Colors.white
                        : scheme.onSurfaceVariant,
                    header: true,
                    underline: headerBg == null && effTable != 'minimal',
                  ),
                  miniRow([
                    'Consulting services',
                    '1',
                    '\$1,200.00',
                  ], bg: zebraBg),
                  miniRow(['Travel expenses', '2', '\$50.00']),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 8,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '\$1,250.00',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Theme',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Company default'),
                  selected: _theme == null,
                  onSelected: (_) => setState(() => _theme = null),
                ),
                for (final id in pdfThemeIds)
                  ChoiceChip(
                    label: Text(pdfThemeLabel(id)),
                    selected: _theme == id,
                    onSelected: (_) => setState(() => _theme = id),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            Text(
              'Logo position',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Company default'),
                  selected: _position == null,
                  onSelected: (_) => setState(() => _position = null),
                ),
                ChoiceChip(
                  label: const Text('Left'),
                  selected: _position == 'left',
                  onSelected: (_) => setState(() => _position = 'left'),
                ),
                ChoiceChip(
                  label: const Text('Right'),
                  selected: _position == 'right',
                  onSelected: (_) => setState(() => _position = 'right'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text(
              'Table style',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Company default'),
                  selected: _table == null,
                  onSelected: (_) => setState(() => _table = null),
                ),
                for (final id in tableStyleIds.where((i) => i != 'auto'))
                  ChoiceChip(
                    label: Text(tableStyleLabel(id)),
                    selected: _table == id,
                    onSelected: (_) => setState(() => _table = id),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  PdfStyleResult(
                    pdfTheme: _theme,
                    logoPosition: _position,
                    tableStyle: _table,
                  ),
                ),
                child: const Text('Apply style'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
