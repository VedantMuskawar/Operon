import 'package:flutter/material.dart';

import '../../../../core/models/dm_template.dart';

class DmTemplateRuntimeContext {
  DmTemplateRuntimeContext({
    required Map<String, String> fields,
    List<Map<String, String>> lineItems = const [],
  })  : fields = fields.map(
          (key, value) => MapEntry(key.toLowerCase(), value),
        ),
        lineItems = lineItems
            .map(
              (row) => row.map(
                (key, value) => MapEntry(key.toLowerCase(), value),
              ),
            )
            .toList();

  final Map<String, String> fields;
  final List<Map<String, String>> lineItems;

  String? resolve(
    String? key, {
    Map<String, String>? row,
  }) {
    if (key == null) return null;
    final normalized = key.trim().toLowerCase();
    if (row != null) {
      if (normalized.startsWith('line.')) {
        final rowKey = normalized.substring(5);
        final value = row[rowKey];
        if (value != null && value.isNotEmpty) {
          return value;
        }
      }
      final rowValue = row[normalized];
      if (rowValue != null && rowValue.isNotEmpty) {
        return rowValue;
      }
    }

    final value = fields[normalized];
    return value != null && value.isNotEmpty ? value : null;
  }

  String renderText(
    String template, {
    String? binding,
    bool uppercase = false,
    Map<String, String>? row,
  }) {
    var output = template;

    if (binding != null) {
      final bound = resolve(binding, row: row);
      if (bound != null) {
        output = bound;
      }
    }

    final placeholderRegex = RegExp(r'{{\s*([^}]+)\s*}}');
    output = output.replaceAllMapped(placeholderRegex, (match) {
      final key = match.group(1);
      final value = resolve(key, row: row);
      return value ?? '';
    });

    if (uppercase) {
      output = output.toUpperCase();
    }

    return output;
  }
}

class DmTemplatePreviewCanvas extends StatelessWidget {
  const DmTemplatePreviewCanvas({
    super.key,
    required this.template,
    required this.runtimeContext,
    this.invertColors = false,
    this.showGrid = false,
    this.canvasKey,
  });

  final DmTemplate template;
  final DmTemplateRuntimeContext runtimeContext;
  final bool invertColors;
  final bool showGrid;
  final GlobalKey? canvasKey;

  static const List<double> _inversionMatrix = <double>[
    -1, 0, 0, 0, 255, //
    0, -1, 0, 0, 255, //
    0, 0, -1, 0, 255, //
    0, 0, 0, 1, 0,
  ];

  @override
  Widget build(BuildContext context) {
    final canvas = RepaintBoundary(
      key: canvasKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: AspectRatio(
              aspectRatio: _pageAspectRatio(),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _parseColor(
                        template.backgroundColor ?? '#FFFFFFFF',
                        fallback: Colors.white,
                      ) ??
                      Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: LayoutBuilder(
                    builder: (context, innerConstraints) {
                      final size = Size(
                        innerConstraints.maxWidth,
                        innerConstraints.maxHeight,
                      );
                      final elements = [...template.elements]
                        ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

                      return Stack(
                        children: [
                          if (showGrid)
                            const Positioned.fill(
                              child: IgnorePointer(
                                child: _PreviewGridPainter(),
                              ),
                            ),
                          ...elements.map(
                            (element) =>
                                _buildPositionedElement(element, size),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    if (!invertColors) {
      return canvas;
    }

    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(_inversionMatrix),
      child: canvas,
    );
  }

  Widget _buildPositionedElement(
    DmTemplateElement element,
    Size canvasSize,
  ) {
    final left = element.x * canvasSize.width;
    final top = element.y * canvasSize.height;
    final width = element.width * canvasSize.width;
    final height = element.height * canvasSize.height;

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: _buildElement(element),
    );
  }

  Widget _buildElement(DmTemplateElement element) {
    switch (element.type) {
      case DmTemplateElementType.text:
        return _TextElementPreview(
          element: element,
          runtimeContext: runtimeContext,
        );
      case DmTemplateElementType.image:
        return _ImageElementPreview(element: element);
      case DmTemplateElementType.table:
        return _TableElementPreview(
          element: element,
          runtimeContext: runtimeContext,
        );
      case DmTemplateElementType.shape:
        return _ShapeElementPreview(element: element);
      case DmTemplateElementType.barcode:
        return const _PlaceholderElementPreview(
          icon: Icons.line_weight,
          label: 'Barcode',
        );
      case DmTemplateElementType.qr:
        return const _PlaceholderElementPreview(
          icon: Icons.qr_code,
          label: 'QR Code',
        );
    }
  }

  double _pageAspectRatio() {
    final size = template.pageSize == DmTemplatePageSize.a4
        ? const Size(210, 297)
        : const Size(148, 210);
    return template.orientation == DmTemplateOrientation.portrait
        ? size.width / size.height
        : size.height / size.width;
  }

  static Color? _parseColor(
    String? value, {
    Color? fallback,
  }) {
    if (value == null || value.isEmpty) return fallback;
    var hex = value.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    if (hex.length != 8) return fallback;
    final intValue = int.tryParse(hex, radix: 16);
    if (intValue == null) return fallback;
    return Color(intValue);
  }
}

class _PreviewGridPainter extends StatelessWidget {
  const _PreviewGridPainter();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GridPainter(),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 24.0;
    final paint = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 1;

    for (double x = spacing; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TextElementPreview extends StatelessWidget {
  const _TextElementPreview({
    required this.element,
    required this.runtimeContext,
  });

  final DmTemplateElement element;
  final DmTemplateRuntimeContext runtimeContext;

  @override
  Widget build(BuildContext context) {
    final data = element.data;
    final templateText = data['text'] as String? ?? '';
    final binding = data['binding'] as String?;
    final fontSize = (data['fontSize'] as num?)?.toDouble() ?? 16;
    final fontWeight = _fontWeightFromString(data['fontWeight'] as String?);
    final color = DmTemplatePreviewCanvas._parseColor(
          data['color'] as String?,
          fallback: const Color(0xFF111827),
        ) ??
        const Color(0xFF111827);
    final textAlign = _textAlignFromString(data['textAlign'] as String?);
    final uppercase = data['uppercase'] == true;
    final padding = (data['padding'] as num?)?.toDouble() ?? 8;
    final backgroundColor = DmTemplatePreviewCanvas._parseColor(
          data['backgroundColor'] as String?,
          fallback: Colors.transparent,
        ) ??
        Colors.transparent;

    final renderedText = runtimeContext.renderText(
      templateText,
      binding: binding,
      uppercase: uppercase,
    );

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.all(padding),
      child: Align(
        alignment: _alignmentFromTextAlign(textAlign),
        child: Text(
          renderedText,
          textAlign: textAlign,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
          ),
        ),
      ),
    );
  }

  static TextAlign _textAlignFromString(String? value) {
    switch (value) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      default:
        return TextAlign.left;
    }
  }

  static Alignment _alignmentFromTextAlign(TextAlign align) {
    switch (align) {
      case TextAlign.center:
        return Alignment.center;
      case TextAlign.right:
        return Alignment.centerRight;
      case TextAlign.left:
      default:
        return Alignment.centerLeft;
    }
  }

  static FontWeight _fontWeightFromString(String? weight) {
    switch (weight) {
      case 'bold':
        return FontWeight.bold;
      case 'w600':
        return FontWeight.w600;
      case 'w500':
        return FontWeight.w500;
      default:
        return FontWeight.normal;
    }
  }
}

class _ImageElementPreview extends StatelessWidget {
  const _ImageElementPreview({required this.element});

  final DmTemplateElement element;

  @override
  Widget build(BuildContext context) {
    final imageUrl = element.data['imageUrl'] as String? ?? '';
    final fit = element.data['fit'] as String? ?? 'contain';
    final boxFit = _boxFitFromString(fit);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(
          color: Colors.black.withOpacity(0.08),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: imageUrl.isEmpty
          ? const _PlaceholderElementPreview(
              icon: Icons.image_outlined,
              label: 'Logo / Image',
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                fit: boxFit,
              ),
            ),
    );
  }

  static BoxFit _boxFitFromString(String value) {
    switch (value) {
      case 'cover':
        return BoxFit.cover;
      case 'fill':
        return BoxFit.fill;
      case 'contain':
      default:
        return BoxFit.contain;
    }
  }
}

class _TableElementPreview extends StatelessWidget {
  const _TableElementPreview({
    required this.element,
    required this.runtimeContext,
  });

  final DmTemplateElement element;
  final DmTemplateRuntimeContext runtimeContext;

  @override
  Widget build(BuildContext context) {
    final data = element.data;
    final rowsCount = (data['rows'] as num?)?.toInt() ?? 6;
    final columnsCount = (data['columns'] as num?)?.toInt() ?? 4;
    final showHeader = data['showHeader'] as bool? ?? true;
    final showBorders = data['showBorders'] as bool? ?? true;
    final headerLabels =
        (data['headerLabels'] as List?)?.cast<String>() ??
            const ['Description', 'Qty', 'Rate', 'Amount'];
    final headerBinding =
        (data['headerBinding'] as List?)?.cast<String>() ??
            const ['line.description', 'line.quantity', 'line.rate', 'line.amount'];
    final textColor = DmTemplatePreviewCanvas._parseColor(
          data['textColor'] as String?,
          fallback: const Color(0xFF111827),
        ) ??
        const Color(0xFF111827);
    final headerColor = DmTemplatePreviewCanvas._parseColor(
          data['headerColor'] as String?,
          fallback: const Color(0xFF1D4ED8),
        ) ??
        const Color(0xFF1D4ED8);
    final headerTextColor = DmTemplatePreviewCanvas._parseColor(
          data['headerTextColor'] as String?,
          fallback: Colors.white,
        ) ??
        Colors.white;

    final tableBorder = showBorders
        ? TableBorder.all(
            color: Colors.black.withOpacity(0.2),
            width: 1,
          )
        : TableBorder(
            horizontalInside: BorderSide(
              color: Colors.black.withOpacity(0.1),
              width: 0.6,
            ),
          );

    final rows = runtimeContext.lineItems.isEmpty
        ? List.generate(rowsCount, (index) => <String, String>{
              'description': '—',
              'quantity': '',
              'rate': '',
              'amount': '',
            })
        : runtimeContext.lineItems;

    final renderedRows = rows.take(rowsCount).toList();
    final remaining = rowsCount - renderedRows.length;
    if (remaining > 0) {
      renderedRows.addAll(
        List.generate(
          remaining,
          (_) => <String, String>{
            'description': '',
            'quantity': '',
            'rate': '',
            'amount': '',
          },
        ),
      );
    }

    final columnWidths = <int, TableColumnWidth>{
      for (int column = 0; column < columnsCount; column++)
        column: FlexColumnWidth(column == 0 ? 2 : 1),
    };

    final tableRows = <TableRow>[];

    if (showHeader) {
      tableRows.add(
        TableRow(
          decoration: BoxDecoration(color: headerColor),
          children: [
            for (int column = 0; column < columnsCount; column++)
              _tableCell(
                headerLabels.length > column
                    ? headerLabels[column]
                    : 'Column ${column + 1}',
                headerTextColor,
                bold: true,
                align: column == 0 ? TextAlign.left : TextAlign.center,
              ),
          ],
        ),
      );
    }

    for (var index = 0; index < renderedRows.length; index++) {
      final row = renderedRows[index];
      tableRows.add(
        TableRow(
          decoration: BoxDecoration(
            color: index.isOdd ? Colors.white : const Color(0xFFF8FAFC),
          ),
          children: [
            for (int column = 0; column < columnsCount; column++)
              _tableCell(
                _resolveTableCellValue(
                  runtimeContext: runtimeContext,
                  row: row,
                  binding: headerBinding.length > column
                      ? headerBinding[column]
                      : null,
                  fallbackLabel: headerLabels.length > column
                      ? headerLabels[column]
                      : null,
                ),
                textColor,
                align: column == 0 ? TextAlign.left : TextAlign.center,
              ),
          ],
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.black.withOpacity(0.1),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Table(
          border: tableBorder,
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: columnWidths,
          children: tableRows,
        ),
      ),
    );
  }

  Widget _tableCell(
    String label,
    Color color, {
    bool bold = false,
    TextAlign align = TextAlign.center,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 10,
        horizontal: 8,
      ),
      child: Text(
        label,
        textAlign: align,
        style: TextStyle(
          color: color,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }
}

String _resolveTableCellValue({
  required DmTemplateRuntimeContext runtimeContext,
  required Map<String, String> row,
  String? binding,
  String? fallbackLabel,
}) {
  String? value;
  if (binding != null) {
    value = runtimeContext.resolve(binding, row: row);
  }

  if ((value == null || value.isEmpty) && fallbackLabel != null) {
    final normalizedLabel = fallbackLabel
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '')
        .trim();
    if (normalizedLabel.isNotEmpty) {
      value = runtimeContext.resolve('line.$normalizedLabel', row: row) ??
          runtimeContext.resolve(normalizedLabel, row: row) ??
          row[normalizedLabel];
    }
  }

  value ??= row['value'] ?? '';

  return value.isEmpty ? '' : value;
}

class _ShapeElementPreview extends StatelessWidget {
  const _ShapeElementPreview({required this.element});

  final DmTemplateElement element;

  @override
  Widget build(BuildContext context) {
    final fillColor = DmTemplatePreviewCanvas._parseColor(
          element.data['fillColor'] as String?,
          fallback: const Color(0xFFE2E8F0),
        ) ??
        const Color(0xFFE2E8F0);
    final borderColor = DmTemplatePreviewCanvas._parseColor(
          element.data['borderColor'] as String?,
          fallback: Colors.transparent,
        ) ??
        Colors.transparent;
    final borderWidth = (element.data['borderWidth'] as num?)?.toDouble() ?? 0.0;
    final radius = (element.data['cornerRadius'] as num?)?.toDouble() ?? 8.0;

    return Container(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
      ),
    );
  }
}

class _PlaceholderElementPreview extends StatelessWidget {
  const _PlaceholderElementPreview({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.black12,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.black45),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

