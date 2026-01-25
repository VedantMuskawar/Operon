import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// PDF building utilities for common formatting and styling
class PdfBuilder {
  /// Format currency with ₹ symbol (fallback to "Rs" if font doesn't support it)
  static String formatCurrency(double amount) {
    // Use "Rs" instead of ₹ to avoid font issues
    // If needed, can be changed back with proper font support
    return 'Rs. ${amount.toStringAsFixed(2)}';
  }

  /// Format date in a readable format
  static String formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  /// Format date as DD/MM/YYYY
  static String formatDateDDMMYYYY(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  /// Format date with time
  static String formatDateTime(DateTime date) {
    final dateStr = formatDate(date);
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$dateStr, $hour:$minute $period';
  }

  /// Create a horizontal divider
  static pw.Widget divider({
    PdfColor? color,
    double thickness = 1.0,
    double margin = 8.0,
  }) {
    return pw.Container(
      margin: pw.EdgeInsets.symmetric(vertical: margin),
      height: thickness,
      color: color ?? PdfColors.grey300,
    );
  }

  /// Create a section title
  static pw.Widget sectionTitle(
    String text, {
    double fontSize = 16,
    PdfColor? color,
  }) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: fontSize,
        fontWeight: pw.FontWeight.bold,
        color: color ?? PdfColors.black,
      ),
    );
  }

  /// Create a label-value pair
  static pw.Widget labelValue({
    required String label,
    required String value,
    double labelFontSize = 12,
    double valueFontSize = 12,
    PdfColor? labelColor,
    PdfColor? valueColor,
    pw.FontWeight? valueWeight,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: labelFontSize,
            color: labelColor ?? PdfColors.grey700,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: valueFontSize,
              fontWeight: valueWeight ?? pw.FontWeight.normal,
              color: valueColor ?? PdfColors.black,
            ),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }

  /// Load image from URL or bytes
  static Future<pw.Image?> loadImage(
    dynamic source, {
    double? width,
    double? height,
  }) async {
    try {
      Uint8List? bytes;
      
      if (source is String) {
        // URL - for web, we'll need to fetch it
        // This will be handled by the calling code
        return null;
      } else if (source is Uint8List) {
        bytes = source;
      } else {
        return null;
      }

      // bytes is guaranteed to be non-null here if we reach this point

      final image = pw.MemoryImage(bytes);
      return pw.Image(
        image,
        width: width,
        height: height,
        fit: pw.BoxFit.contain,
      );
    } catch (e) {
      return null;
    }
  }

  /// Create a table header row
  static List<pw.Widget> tableHeaderRow(
    List<String> headers, {
    PdfColor? backgroundColor,
    PdfColor? textColor,
    double fontSize = 11,
  }) {
    return headers
        .map(
          (header) => pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              color: backgroundColor ?? PdfColors.grey200,
              border: pw.Border.all(color: PdfColors.grey400),
            ),
            child: pw.Text(
              header,
              style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight: pw.FontWeight.bold,
                color: textColor ?? PdfColors.black,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
        )
        .toList();
  }

  /// Create a table data row
  static List<pw.Widget> tableDataRow(
    List<String> cells, {
    PdfColor? backgroundColor,
    PdfColor? textColor,
    double fontSize = 10,
    List<pw.TextAlign>? alignments,
  }) {
    return cells
        .asMap()
        .entries
        .map(
          (entry) => pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              color: backgroundColor,
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Text(
              entry.value,
              style: pw.TextStyle(
                fontSize: fontSize,
                color: textColor ?? PdfColors.black,
              ),
              textAlign: alignments != null && entry.key < alignments.length
                  ? alignments[entry.key]
                  : pw.TextAlign.left,
            ),
          ),
        )
        .toList();
  }
}
