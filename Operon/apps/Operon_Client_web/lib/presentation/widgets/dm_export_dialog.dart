import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_ui/core_ui.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Dialog to export Delivery Memos: choose DM range or Date range,
/// then download an Excel file with all datatable columns.
class DmExportDialog extends StatefulWidget {
  const DmExportDialog({
    super.key,
    required this.organizationId,
    required this.repository,
  });

  final String organizationId;
  final DeliveryMemoRepository repository;

  @override
  State<DmExportDialog> createState() => _DmExportDialogState();
}

class _DmExportDialogState extends State<DmExportDialog> {
  String _rangeMode = 'dmRange';
  final _fromDmController = TextEditingController();
  final _toDmController = TextEditingController();
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _fromDmController.dispose();
    _toDmController.dispose();
    super.dispose();
  }

  static String _formatDmDateForExport(dynamic date) {
    if (date == null) return '—';
    try {
      DateTime dateTime;
      if (date is Timestamp) {
        dateTime = date.toDate();
      } else if (date is DateTime) {
        dateTime = date;
      } else {
        return '—';
      }
      const months = [
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
      return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
    } catch (_) {
      return '—';
    }
  }

  static List<CellValue> _dmToRow(Map<String, dynamic> dm) {
    final n = dm['dmNumber'] as int?;
    final id = dm['dmId'] as String? ?? '—';
    final dmCol = n != null ? 'DM-$n' : id;

    final clientName = dm['clientName'] as String? ?? '—';

    final items = dm['items'] as List<dynamic>? ?? [];
    final first =
        items.isNotEmpty ? items.first as Map<String, dynamic>? : null;
    final qty = (first?['fixedQuantityPerTrip'] ?? first?['quantity']) as num?;
    final fixedQty = qty != null ? qty.toString() : '—';

    final price =
        first != null ? (first['unitPrice'] as num?)?.toDouble() : null;
    final unitPrice =
        (price != null && price > 0) ? '₹${price.toStringAsFixed(2)}' : '—';

    final deliveryDate = _formatDmDateForExport(dm['scheduledDate']);

    final zone = dm['deliveryZone'] as Map<String, dynamic>?;
    String regionCity = '—';
    if (zone != null) {
      final region = zone['region'] as String? ?? '';
      final city =
          zone['city_name'] as String? ?? zone['city'] as String? ?? '';
      regionCity = [region, city].where((s) => s.isNotEmpty).join(', ');
      if (regionCity.isEmpty) regionCity = '—';
    }

    final vehicleNo = dm['vehicleNumber'] as String? ?? '—';

    final tp = dm['tripPricing'] as Map<String, dynamic>?;
    final totalVal =
        tp != null ? (tp['total'] as num?)?.toDouble() ?? 0.0 : 0.0;
    final total = totalVal > 0 ? '₹${totalVal.toStringAsFixed(2)}' : '—';

    return [
      TextCellValue(dmCol),
      TextCellValue(clientName),
      TextCellValue(fixedQty),
      TextCellValue(unitPrice),
      TextCellValue(deliveryDate),
      TextCellValue(regionCity),
      TextCellValue(vehicleNo),
      TextCellValue(total),
    ];
  }

  Future<void> _export() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<Map<String, dynamic>> list;
      if (_rangeMode == 'dateRange') {
        if (_dateFrom == null || _dateTo == null) {
          setState(() {
            _errorMessage = 'Select from and to date';
            _isLoading = false;
          });
          return;
        }
        if (_dateFrom!.isAfter(_dateTo!)) {
          setState(() {
            _errorMessage = 'From date must be before or equal to to date';
            _isLoading = false;
          });
          return;
        }
        final start =
            DateTime(_dateFrom!.year, _dateFrom!.month, _dateFrom!.day);
        final end =
            DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day, 23, 59, 59);
        list = await widget.repository
            .watchDeliveryMemos(
              organizationId: widget.organizationId,
              status: null,
              startDate: start,
              endDate: end,
              limit: null,
            )
            .first;
      } else {
        final fromStr = _fromDmController.text.trim();
        final toStr = _toDmController.text.trim();
        if (fromStr.isEmpty || toStr.isEmpty) {
          setState(() {
            _errorMessage = 'Enter from and to DM #';
            _isLoading = false;
          });
          return;
        }
        final fromNum = int.tryParse(fromStr);
        final toNum = int.tryParse(toStr);
        if (fromNum == null || toNum == null) {
          setState(() {
            _errorMessage = 'From and to must be numbers';
            _isLoading = false;
          });
          return;
        }
        if (fromNum > toNum) {
          setState(() {
            _errorMessage = 'From DM # must be less than or equal to To DM #';
            _isLoading = false;
          });
          return;
        }
        list = await widget.repository.getDeliveryMemosByDmNumberRange(
          organizationId: widget.organizationId,
          fromDmNumber: fromNum,
          toDmNumber: toNum,
        );
      }

      if (list.isEmpty) {
        setState(() {
          _errorMessage = 'No delivery memos in the selected range';
          _isLoading = false;
        });
        return;
      }

      final excel = Excel.createExcel();
      final sheet =
          excel.tables.isEmpty ? null : excel[excel.tables.keys.first];
      if (sheet == null) {
        setState(() {
          _errorMessage = 'Failed to create Excel sheet';
          _isLoading = false;
        });
        return;
      }

      sheet.appendRow([
        TextCellValue('DM'),
        TextCellValue('Client Name'),
        TextCellValue('FixedQuantity'),
        TextCellValue('Unit Price'),
        TextCellValue('Delivery Date'),
        TextCellValue('Region, City'),
        TextCellValue('Vehicle no.'),
        TextCellValue('Total'),
      ]);
      for (final dm in list) {
        sheet.appendRow(_dmToRow(dm));
      }

      final bytes = excel.save();
      if (bytes == null) {
        setState(() {
          _errorMessage = 'Failed to generate Excel file';
          _isLoading = false;
        });
        return;
      }

      final now = DateTime.now();
      final filename =
          'delivery-memos-export-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.xlsx';
      final blob = html.Blob([Uint8List.fromList(bytes)]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      (html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click());
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        Navigator.of(context).pop();
        DashSnackbar.show(context, message: 'Export downloaded');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Export failed: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF11111B),
      title: const Text(
        'Export Delivery Memos',
        style: TextStyle(color: Colors.white, fontSize: 18),
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select range',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              RadioListTile<String>(
                title: const Text(
                  'DM range',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                value: 'dmRange',
                groupValue: _rangeMode,
                onChanged: (v) => setState(() => _rangeMode = v!),
                activeColor: AuthColors.primary,
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
              RadioListTile<String>(
                title: const Text(
                  'Date range',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                value: 'dateRange',
                groupValue: _rangeMode,
                onChanged: (v) => setState(() => _rangeMode = v!),
                activeColor: AuthColors.primary,
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              if (_rangeMode == 'dmRange') ...[
                TextField(
                  controller: _fromDmController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'From DM #',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white38),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'[\n\r]')),
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _toDmController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'To DM #',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white38),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'[\n\r]')),
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
              ] else ...[
                ListTile(
                  title: const Text(
                    'From date',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  subtitle: Text(
                    _dateFrom != null
                        ? '${_dateFrom!.day}/${_dateFrom!.month}/${_dateFrom!.year}'
                        : 'Tap to select',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _dateFrom ??
                          DateTime.now().subtract(const Duration(days: 30)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _dateFrom = d);
                  },
                ),
                ListTile(
                  title: const Text(
                    'To date',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  subtitle: Text(
                    _dateTo != null
                        ? '${_dateTo!.day}/${_dateTo!.month}/${_dateTo!.year}'
                        : 'Tap to select',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _dateTo ?? DateTime.now(),
                      firstDate: _dateFrom ?? DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _dateTo = d);
                  },
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        DashButton(
          label: 'Cancel',
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          variant: DashButtonVariant.text,
        ),
        DashButton(
          label: 'Export',
          onPressed: _isLoading ? null : _export,
          isLoading: _isLoading,
        ),
      ],
    );
  }
}
