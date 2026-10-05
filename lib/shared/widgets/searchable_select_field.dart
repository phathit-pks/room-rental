import 'package:flutter/material.dart';

/// A form field that opens a dialog with a search box to pick one of [items].
/// Passing `onChanged: null` disables it, like [DropdownButtonFormField].
class SearchableSelectField extends FormField<String> {
  SearchableSelectField({
    super.key,
    required String label,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
    super.initialValue,
    super.validator,
  }) : super(
         enabled: onChanged != null,
         builder: (field) {
           final state = field as _SearchableSelectFieldState;
           final value = state.value;
           return InkWell(
             borderRadius: BorderRadius.circular(16),
             onTap: onChanged == null
                 ? null
                 : () async {
                     final selected = await showDialog<String>(
                       context: state.context,
                       builder: (_) =>
                           _SearchDialog(title: label, items: items),
                     );
                     if (selected == null) return;
                     state.didChange(selected);
                     onChanged(selected);
                   },
             child: InputDecorator(
               isEmpty: value == null,
               decoration: InputDecoration(
                 labelText: label,
                 enabled: onChanged != null,
                 errorText: state.errorText,
                 suffixIcon: const Icon(Icons.arrow_drop_down),
               ),
               child: value == null
                   ? null
                   : Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
             ),
           );
         },
       );

  @override
  FormFieldState<String> createState() => _SearchableSelectFieldState();
}

class _SearchableSelectFieldState extends FormFieldState<String> {
  @override
  void didUpdateWidget(SearchableSelectField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      setValue(widget.initialValue);
    }
  }
}

class _SearchDialog extends StatefulWidget {
  const _SearchDialog({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final matches = query.isEmpty
        ? widget.items
        : widget.items
              .where((item) => item.toLowerCase().contains(query))
              .toList();

    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 420,
        height: 440,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'พิมพ์เพื่อค้นหา',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: matches.isEmpty
                  ? const Center(child: Text('ไม่พบรายการ'))
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) => ListTile(
                        title: Text(matches[index]),
                        onTap: () => Navigator.pop(context, matches[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
      ],
    );
  }
}
