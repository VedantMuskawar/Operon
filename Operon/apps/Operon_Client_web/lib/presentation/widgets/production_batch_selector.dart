import 'package:core_models/core_models.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

class ProductionBatchSelector extends StatelessWidget {
  const ProductionBatchSelector({
    super.key,
    required this.organizationId,
    required this.repository,
    this.selectedTemplateId,
    this.onTemplateSelected,
    this.onCustomSelected,
  });

  final String organizationId;
  final ProductionBatchTemplatesRepository repository;
  final String? selectedTemplateId;
  final ValueChanged<ProductionBatchTemplate>? onTemplateSelected;
  final VoidCallback? onCustomSelected;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductionBatchTemplate>>(
      future: repository.fetchBatchTemplates(organizationId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 40,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AuthColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Error loading templates: ${snapshot.error}',
              style: const TextStyle(color: AuthColors.error),
            ),
          );
        }

        final templates = snapshot.data ?? [];

        if (templates.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'No batch templates available',
                style: TextStyle(color: AuthColors.textSub),
              ),
              const SizedBox(height: 8),
              DashButton(
                label: 'Select Employees Manually',
                icon: Icons.person_add,
                onPressed: onCustomSelected,
                variant: DashButtonVariant.text,
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Batch Template',
              style: TextStyle(
                color: AuthColors.textMain,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedTemplateId,
              decoration: InputDecoration(
                filled: true,
                fillColor: AuthColors.textMainWithOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AuthColors.textMainWithOpacity(0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AuthColors.textMainWithOpacity(0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AuthColors.primary,
                    width: 2,
                  ),
                ),
              ),
              dropdownColor: AuthColors.surface,
              style: const TextStyle(color: AuthColors.textMain),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Select a template...'),
                ),
                ...templates.map((template) {
                  return DropdownMenuItem<String>(
                    value: template.batchId,
                    child: Text(
                      '${template.name} (${template.employeeIds.length} employee${template.employeeIds.length != 1 ? 's' : ''})',
                      style: const TextStyle(color: AuthColors.textMain),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ],
              onChanged: (value) {
                if (value != null) {
                  final template = templates.firstWhere(
                    (t) => t.batchId == value,
                  );
                  onTemplateSelected?.call(template);
                }
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                DashButton(
                  label: 'Select Employees Manually',
                  icon: Icons.person_add,
                  onPressed: onCustomSelected,
                  variant: DashButtonVariant.text,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

