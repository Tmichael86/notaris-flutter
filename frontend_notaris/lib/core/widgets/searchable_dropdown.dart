import 'package:flutter/material.dart';

/// Reusable dropdown that automatically enables inline search
/// when the number of items is greater than 5.
///
/// Rules:
/// - <= 5 items: normal dropdown menu.
/// - > 5 items: dropdown menu with an inline search field.
class SearchableDropdown<T> extends StatefulWidget {
  final T? value;
  final List<T> items;
  final String label;
  final String hint;
  final ValueChanged<T?> onChanged;
  final String Function(T item)? itemLabel;
  final bool enabled;

  const SearchableDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label = '',
    this.hint = 'Pilih...',
    this.itemLabel,
    this.enabled = true,
  });

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  final LayerLink _layerLink = LayerLink();
  final TextEditingController _searchController = TextEditingController();
  OverlayEntry? _overlayEntry;

  bool get _isSearchable => widget.items.length > 5;

  String _label(T item) => widget.itemLabel?.call(item) ?? item.toString();

  @override
  void dispose() {
    _removeOverlay();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleDropdown() {
    if (!widget.enabled) return;
    if (_overlayEntry != null) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    _searchController.clear();

    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _removeOverlay,
              child: const SizedBox.expand(),
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            child: Material(
              color: Colors.white,
              elevation: 4,
              borderRadius: BorderRadius.circular(4),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: size.width,
                child: _DropdownMenu<T>(
                  items: widget.items,
                  value: widget.value,
                  searchable: _isSearchable,
                  searchController: _searchController,
                  itemLabel: _label,
                  onSelected: (value) {
                    widget.onChanged(value);
                    _removeOverlay();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() {});
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _searchController.clear();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final selectedText = widget.value == null ? null : _label(widget.value as T);

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleDropdown,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: widget.label.isEmpty ? null : widget.label,
            hintText: widget.hint,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            enabled: widget.enabled,
          ),
          isEmpty: selectedText == null,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selectedText ?? widget.hint,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selectedText == null ? Colors.grey.shade600 : Colors.black87,
                  ),
                ),
              ),
              Icon(
                _overlayEntry != null ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.grey.shade700,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownMenu<T> extends StatefulWidget {
  final List<T> items;
  final T? value;
  final bool searchable;
  final TextEditingController searchController;
  final String Function(T item) itemLabel;
  final ValueChanged<T?> onSelected;

  const _DropdownMenu({
    required this.items,
    required this.value,
    required this.searchable,
    required this.searchController,
    required this.itemLabel,
    required this.onSelected,
  });

  @override
  State<_DropdownMenu<T>> createState() => _DropdownMenuState<T>();
}

class _DropdownMenuState<T> extends State<_DropdownMenu<T>> {
  late List<T> _filteredItems;

  @override
  void initState() {
    super.initState();
    _filteredItems = List<T>.from(widget.items);
    widget.searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_filterItems);
    super.dispose();
  }

  void _filterItems() {
    final query = widget.searchController.text.trim().toLowerCase();
    setState(() {
      _filteredItems = widget.items
          .where((item) => widget.itemLabel(item).toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 320),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.searchable) ...[
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: widget.searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Cari...',
                  prefixIcon: Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const Divider(height: 1),
          ],
          Flexible(
            child: _filteredItems.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: Text('Data tidak ditemukan')),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      final selected = item == widget.value;

                      return InkWell(
                        onTap: () => widget.onSelected(item),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.itemLabel(item),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (selected) const Icon(Icons.check, size: 18),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
