import 'dart:collection';
import 'dart:convert';

import 'package:dhipl_flutter/config/app_dependencies.dart';
import 'package:dhipl_flutter/config/session_expiration_toast.dart';
import 'package:dhipl_flutter/main.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:toastification/toastification.dart';

// --- (Data Models - Kept from previous response) ---

// Custom class to hold the data for a single field difference
class DiffRow {
  final String itemKey;
  final String fieldKey;
  final int mainItemIndex;
  final int? subItemIndex;
  final int oldMainItemIndex;
  final int? oldSubItemIndex;
  final dynamic oldValue;
  final dynamic newValue;
  bool isReverted;
  bool isChanged;

  DiffRow(this.oldMainItemIndex, this.oldSubItemIndex, {
    required this.itemKey,
    required this.fieldKey,
    required this.mainItemIndex,
    this.subItemIndex,
    required this.oldValue,
    required this.newValue,
    required this.isReverted,
    required this.isChanged,
  });
}

// Class to hold a unique item/sub-item and all its field differences
class GroupedDiffItem {
  final String itemKey;
  final int mainItemIndex;
  final int? subItemIndex;
  final List<DiffRow> fieldDifferences;

  // New property for row-wise revert state
  bool get isReverted => fieldDifferences.every((r) => r.isReverted);
  bool get isChanged => fieldDifferences.any((r) => r.isChanged);

  GroupedDiffItem({
    required this.itemKey,
    required this.mainItemIndex,
    this.subItemIndex,
    required this.fieldDifferences,
  });

  @override
  String toString() {
    return "mainItemIndex: $mainItemIndex, subItemIndex: $subItemIndex, key: $itemKey";
  }
}

// --- (Main Dialog Widget) ---

class BoqReuploadDialog extends StatefulWidget {
  final int project;
  final PlatformFile file;
  final Map<String, dynamic> oldBoq;
  final Map<String, dynamic> newBoq;

  const BoqReuploadDialog({
    Key? key,
    required this.oldBoq,
    required this.newBoq,
    required this.project,
    required this.file,
  }) : super(key: key);

  @override
  _BoqReuploadDialogState createState() => _BoqReuploadDialogState();
}

class _BoqReuploadDialogState extends State<BoqReuploadDialog> {
  // A flat list of all differences (field-wise)
  List<DiffRow> allDiffRows = [];
  // The final list of items/sub-items to display (row-wise revertible)
  List<GroupedDiffItem> groupedItems = [];
  bool _isLoading = false;

  late Map<String, dynamic> currentBoq;

  late Map<int, GroupedDiffItem> mainGroupMap;
  late Map<String, GroupedDiffItem> subGroupMap;

  final List<String> _comparisonSubFields = const ['tender_sub_item', 'tender_item_long', 'rate', 'required_quantity', 'unit_of_measure'];
  final List<String> _comparisonMainFields = const ['tender_item', 'tender_item_long', 'rate', 'order_quantity', 'unit_of_measure'];

  // Keys to ignore during comparison (extended from original)
  final _ignoredKeys = const [
    'status', 'id', 'boq_file_id', 'main_line_item_id', 'version', 'createdAt',
    'updatedAt', 'deletedAt', 'created_by', 'updated_by', 'deleted_by',
    'created_by_user', 'total_work_done_amount', 'total_extra_work_amount',
    'file_name', 'username', 'full_name', 'versions',
    'data', // tender_item fields are used for name, not comparison here
  ];

  Map<String, bool> notRemovableSubItems = {};
  Map<String, bool> notRemovableMainItems = {};

  @override
  void initState() {
    super.initState();
    // Deep copy for mutable state
    final newBoqData = widget.newBoq['data'] as Map<String, dynamic>;
    currentBoq = Map<String, dynamic>.from(widget.newBoq);
    currentBoq['data'] = _deepCopyData(newBoqData);

    notRemovableSubItems = Map.fromEntries(((widget.oldBoq['data']?['subItemMap'] ?? widget.oldBoq['subItemMap']) as Map<dynamic, dynamic>).entries.map((e) => MapEntry(e.key.toString(), e.value as bool)).toList());
    notRemovableMainItems = Map.fromEntries(((widget.oldBoq['data']?['mainItemMap'] ?? widget.oldBoq['mainItemMap']) as Map<dynamic, dynamic>).entries.map((e) => MapEntry(e.key.toString(), e.value as bool)).toList());
    _compareBoqs();
    _groupDiffRows();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _autoRevertNonRemovableItems();
    });
  }

  // Utility to recursively deep copy the mutable parts of the BOQ data
  Map<String, dynamic> _deepCopyData(Map<String, dynamic> source) {
    final target = Map<String, dynamic>.from(source);
    if (target.containsKey('mainItems')) {
      target['mainItems'] = List<dynamic>.from(
        (source['mainItems'] as List<dynamic>).map((mainItem) {
          final newItem = Map<String, dynamic>.from(mainItem as Map<String, dynamic>);
          if (newItem.containsKey('subItems')) {
            newItem['subItems'] = List<dynamic>.from(
              (mainItem['subItems'] as List<dynamic>).map((subItem) => Map<String, dynamic>.from(subItem as Map<String, dynamic>)),
            );
          }
          return newItem;
        }),
      );
    }
    return target;
  }

  // Utility to get the mainItems list from a BOQ map
  List<dynamic> _getMainItems(Map<String, dynamic> boq) {
    return boq['data']?['mainItems'] as List? ?? boq['mainItems'] as List? ?? [];
  }

  // Utility to ensure two values are compared correctly, handling nulls/types
  bool _areDifferent(dynamic oldVal, dynamic newVal) {
    if (oldVal == null && newVal == null) return false;
    if (oldVal == null || newVal == null) return true;
    return oldVal.toString() != newVal.toString();
  }

// --- PERFECT SOLUTION: Map Names → Position Queues ---
  void _compareBoqs() {
    allDiffRows.clear();

    final oldItems = _getMainItems(widget.oldBoq);
    final newItems = _getMainItems(currentBoq);

    // **STEP 1: Build Position Maps (Queues for duplicates)**
    final oldMainMap = _buildPositionMap(oldItems, 'tender_item');
    final newMainMap = _buildPositionMap(newItems, 'tender_item');

    // **STEP 2: Match in NEW list order (preserves UI flow)**
    int displayIndex = 0;
    for (int newIdx = 0; newIdx < newItems.length; newIdx++) {
      final newItem = newItems[newIdx] as Map<String, dynamic>;
      final itemName = newItem['tender_item']?.toString() ?? 'Item $newIdx';

      // Find matching OLD position (if available)
      final oldPositions = oldMainMap[itemName];
      int? matchedOldIdx;
      if (oldPositions != null && oldPositions.isNotEmpty) {
        matchedOldIdx = oldPositions.removeFirst(); // Take first available
      }

      final oldItem = matchedOldIdx != null ? oldItems[matchedOldIdx] as Map<String, dynamic>? : null;

      // 🏷️ TAG: Mark if this item is ADDED (no old match)
      if (oldItem == null) {
        newItem['__diff_status'] = 'ADDED';
      } else {
        newItem['__diff_status'] = 'EXISTING';
      }

      _compareMainItem(oldItem, newItem, displayIndex++, itemName);
    }

    // **STEP 3: Handle REMOVED items (leftover old positions)**
    for (final entry in oldMainMap.entries) {
      for (final oldIdx in entry.value) {
        final oldItem = oldItems[oldIdx] as Map<String, dynamic>;
        final itemName = oldItem['tender_item']?.toString() ?? 'Item $oldIdx';
        _compareMainItem(oldItem, null, displayIndex++, itemName);
      }
    }

    _syncRevertState();
  }

// **HELPER: Build {name → [position1, position2, ...]} map**
  Map<String, Queue<int>> _buildPositionMap(List<dynamic> items, String key) {
    final map = <String, Queue<int>>{};
    for (int i = 0; i < items.length; i++) {
      final name = items[i][key]?.toString() ?? 'Item $i';
      map.putIfAbsent(name, () => Queue<int>()).add(i);
    }
    return map;
  }

// **HELPER: Compare single main item + sub-items**
  void _compareMainItem(Map<String, dynamic>? oldItem, Map<String, dynamic>? newItem, int displayIndex, String itemName) {
    // Main fields
    for (var field in _comparisonMainFields) {
      final oldValue = oldItem?[field];
      final newValue = newItem?[field];
      final isChanged = _areDifferent(oldValue, newValue);

      allDiffRows.add(DiffRow(
        itemKey: itemName,
        fieldKey: field,
        mainItemIndex: displayIndex,
        subItemIndex: null,
        oldValue: oldValue,
        newValue: newValue,
        isReverted: false,
        isChanged: isChanged,
      ));
    }

    // **SUB-ITEMS: Same logic!**
    final oldSubs = oldItem?['subItems']?.cast<Map<String, dynamic>>() ?? [];
    final newSubs = newItem?['subItems']?.cast<Map<String, dynamic>>() ?? [];

    final oldSubMap = _buildPositionMap(oldSubs, 'tender_sub_item');
    final newSubMap = _buildPositionMap(newSubs, 'tender_sub_item');

    int subDisplayIndex = 0;

    // Match new sub-items first
    for (int newSubIdx = 0; newSubIdx < newSubs.length; newSubIdx++) {
      final newSub = newSubs[newSubIdx] as Map<String, dynamic>;
      final subName = newSub['tender_sub_item']?.toString() ?? 'Sub $newSubIdx';

      final oldSubPositions = oldSubMap[subName];
      int? matchedOldSubIdx;
      if (oldSubPositions != null && oldSubPositions.isNotEmpty) {
        matchedOldSubIdx = oldSubPositions.removeFirst();
      }

      final oldSub = matchedOldSubIdx != null ? oldSubs[matchedOldSubIdx] as Map<String, dynamic>? : null;

      // 🏷️ TAG: Mark if this sub-item is ADDED (no old match)
      if (oldSub == null) {
        newSub['__diff_status'] = 'ADDED';
      } else {
        newSub['__diff_status'] = 'EXISTING';
      }

      _compareSubItem(oldSub, newSub, displayIndex, subDisplayIndex++, '$itemName > $subName');
    }

    // Handle removed sub-items
    for (final entry in oldSubMap.entries) {
      for (final oldSubIdx in entry.value) {
        final oldSub = oldSubs[oldSubIdx] as Map<String, dynamic>;
        final subName = oldSub['tender_sub_item']?.toString() ?? 'Sub $oldSubIdx';
        _compareSubItem(oldSub, null, displayIndex, subDisplayIndex++, '$itemName > $subName');
      }
    }
  }

// **HELPER: Compare single sub-item**
  void _compareSubItem(Map<String, dynamic>? oldSub, Map<String, dynamic>? newSub, int mainIdx, int subIdx, String fullKey) {
    for (var field in _comparisonSubFields) {
      final oldVal = oldSub?[field];
      final newVal = newSub?[field];
      final isChanged = _areDifferent(oldVal, newVal);

      allDiffRows.add(DiffRow(
        itemKey: fullKey,
        fieldKey: field,
        mainItemIndex: mainIdx,
        subItemIndex: subIdx,
        oldValue: oldVal,
        newValue: newVal,
        isReverted: false,
        isChanged: isChanged,
      ));
    }
  }

  bool _isMainItemRemoved(int mainItemIndex) {
    final mainItems = _getMainItems(currentBoq);

    // Check if main item is beyond current list (originally removed)
    if (mainItemIndex >= mainItems.length) {
      return true;
    }

    // Check if main item was reverted to removed state
    final mainItemGroup = groupedItems.firstWhere(
      (item) => item.mainItemIndex == mainItemIndex && item.subItemIndex == null,
      orElse: () => GroupedDiffItem(
        itemKey: '',
        mainItemIndex: -1,
        fieldDifferences: [],
      ),
    );

    if (mainItemGroup.mainItemIndex == -1) return false;

    // If all fields have null newValue, it was originally removed
    final wasOriginallyRemoved = mainItemGroup.fieldDifferences.every((r) => r.newValue == null);

    // If it was originally removed and is currently reverted, it's "restored" (not removed)
    if (wasOriginallyRemoved && mainItemGroup.isReverted) {
      return false;
    }

    // If it was originally removed and NOT reverted, it's still removed
    if (wasOriginallyRemoved && !mainItemGroup.isReverted) {
      return true;
    }

    return false;
  }

// Check if main item is newly added (exists in new but not old)
  bool _isMainItemAdded(int mainItemIndex) {
    final mainItemGroup = groupedItems.firstWhere(
      (item) => item.mainItemIndex == mainItemIndex && item.subItemIndex == null,
      orElse: () => GroupedDiffItem(
        itemKey: '',
        mainItemIndex: -1,
        fieldDifferences: [],
      ),
    );

    if (mainItemGroup.mainItemIndex == -1) return false;

    // If all fields have null oldValue, it was newly added
    return mainItemGroup.fieldDifferences.every((r) => r.oldValue == null);
  }

  bool _isMainItemReverted(int mainItemIndex) {
    final mainItemGroup = groupedItems.firstWhere(
      (item) => item.mainItemIndex == mainItemIndex && item.subItemIndex == null,
      orElse: () => GroupedDiffItem(
        itemKey: '',
        mainItemIndex: -1,
        fieldDifferences: [],
      ),
    );

    if (mainItemGroup.mainItemIndex == -1) return false;

    return mainItemGroup.isReverted;
  }

  bool _hasMainItemQuantityChange(int mainItemIndex) {
    final mainItemGroup = groupedItems.firstWhere(
      (item) => item.mainItemIndex == mainItemIndex && item.subItemIndex == null,
      orElse: () => GroupedDiffItem(
        itemKey: '',
        mainItemIndex: -1,
        fieldDifferences: [],
      ),
    );

    if (mainItemGroup.mainItemIndex == -1) return false;

    final qtyDiff = mainItemGroup.fieldDifferences.firstWhere(
      (r) => r.fieldKey == 'order_quantity',
      orElse: () => DiffRow(
        itemKey: '',
        fieldKey: 'order_quantity',
        mainItemIndex: -1,
        oldValue: null,
        newValue: null,
        isReverted: false,
        isChanged: false,
      ),
    );

    return qtyDiff.isChanged && !qtyDiff.isReverted;
  }

  // --- GROUPING LOGIC (ROW-WISE REVERT) ---
  void _groupDiffRows() {
    groupedItems.clear();
    final mainGroups = <int, GroupedDiffItem>{};
    final subGroups = <String, GroupedDiffItem>{};

    for (final row in allDiffRows) {
      final mainIdx = row.mainItemIndex;
      final subIdx = row.subItemIndex;
      final subKey = '${mainIdx}_${subIdx ?? "null"}';

      if (subIdx == null) {
        mainGroups.putIfAbsent(
          mainIdx,
          () => GroupedDiffItem(
            itemKey: row.itemKey.split('>').first.trim(),
            mainItemIndex: mainIdx,
            subItemIndex: null,
            fieldDifferences: [],
          ),
        );
        mainGroups[mainIdx]!.fieldDifferences.add(row);
      } else {
        subGroups.putIfAbsent(
          subKey,
          () => GroupedDiffItem(
            itemKey: row.itemKey.split('>').last.trim(),
            mainItemIndex: mainIdx,
            subItemIndex: subIdx,
            fieldDifferences: [],
          ),
        );
        subGroups[subKey]!.fieldDifferences.add(row);
      }
    }

    groupedItems = [
      ...mainGroups.values,
      ...subGroups.values,
    ];

    groupedItems.sort((a, b) {
      final mainCompare = a.mainItemIndex.compareTo(b.mainItemIndex);
      if (mainCompare != 0) return mainCompare;
      return (a.subItemIndex ?? -1).compareTo(b.subItemIndex ?? -1);
    });

    // ✅ Build lookup maps once
    mainGroupMap = {for (var g in groupedItems.where((x) => x.subItemIndex == null)) g.mainItemIndex: g};
    subGroupMap = {for (var g in groupedItems.where((x) => x.subItemIndex != null)) '${g.mainItemIndex}_${g.subItemIndex}': g};
  }

  void _autoRevertNonRemovableItems() {
    bool hasAutoReverted = false;
    print('🔍 DEBUG: Starting auto-revert. MainItems: ${notRemovableMainItems.length}, SubItems: ${notRemovableSubItems.length}');

    // AUTO-REVERT MAIN ITEMS (from OLD BOQ - reliable!)
    for (var item in groupedItems.where((i) => i.subItemIndex == null)) {
      if (_isItemRemoved(item)) {
        final itemId = _getOldBoqMainId(item.mainItemIndex);
        print('🔍 Main ${item.mainItemIndex}: ID=$itemId, NonRemovable=${notRemovableMainItems[itemId]}');

        if (itemId != null && notRemovableMainItems[itemId] == true) {
          _revertItemFields(item);
          hasAutoReverted = true;
          print('🔒 AUTO-REVERTED: Main ID=$itemId');
        }
      }
    }

    // 🚀 NEW: Track main items that need auto-revert due to sub-items
    final mainItemsToRevert = <int>{};

    final subItems = groupedItems.where((i) => i.subItemIndex != null);
    debugPrint("SubItems: $subItems");
    // AUTO-REVERT SUB ITEMS (from OLD BOQ - reliable!)
    for (var item in subItems) {
      if (_isItemRemoved(item)) {
        final subId = _getOldBoqSubId(item.mainItemIndex, item.subItemIndex!);
        final mainId = _getOldBoqMainId(item.mainItemIndex);
        print('🔍 Sub ${item.mainItemIndex}.${item.subItemIndex}: ID=$subId, NonRemovable=${notRemovableSubItems[subId]}');

        bool shouldRevertSub = false;

        if (subId != null && notRemovableSubItems[subId] == true) {
          // **SUB-ITEM is non-removable** → Revert sub-item
          _revertItemFields(item);
          hasAutoReverted = true;
          print('🔒 AUTO-REVERTED: Sub ID=$subId');
          shouldRevertSub = true;

          // 🚀 NEW: Mark MAIN ITEM for auto-revert too!
          mainItemsToRevert.add(item.mainItemIndex);
        }

        if (mainId != null && notRemovableMainItems[mainId] == true && !shouldRevertSub) {
          // **MAIN ITEM is non-removable** → Revert sub-item (cascade rule)
          _revertItemFields(item);
          hasAutoReverted = true;
          print('🔒 AUTO-REVERTED: Sub ID=$subId (main non-removable)');
          shouldRevertSub = true;

          // 🚀 NEW: Mark MAIN ITEM for auto-revert too!
          mainItemsToRevert.add(item.mainItemIndex);
        }
      }
    }

    // 🚀 NEW: AUTO-REVERT MAIN ITEMS triggered by SUB-ITEMS
    for (int mainIndex in mainItemsToRevert) {
      final mainItem = groupedItems.firstWhere(
        (item) => item.mainItemIndex == mainIndex && item.subItemIndex == null,
        orElse: () => GroupedDiffItem(itemKey: '', mainItemIndex: -1, fieldDifferences: []),
      );

      if (mainItem.mainItemIndex != -1 && _isItemRemoved(mainItem)) {
        _revertItemFields(mainItem);
        hasAutoReverted = true;
        print('🔒 AUTO-REVERTED: Main ID=${_getOldBoqMainId(mainIndex)} (triggered by sub-item)');
      }
    }

    if (hasAutoReverted) {
      setState(() {});
      Toast.display(
        type: ToastificationType.info,
        title: "Non-removable items were automatically restored",
      );
    }
  }

  // 👈 NEW: Get MAIN ID from OLD BOQ (reliable!)
  String? _getOldBoqMainId(int displayIndex) {
    final oldMainItems = _getMainItems(widget.oldBoq);
    if (displayIndex < oldMainItems.length) {
      return oldMainItems[displayIndex]['id']?.toString();
    }
    return null;
  }

// 👈 NEW: Get SUB ID from OLD BOQ (reliable!)
  String? _getOldBoqSubId(int mainDisplayIndex, int subDisplayIndex) {
    String? subItemId = null;
    final oldMainItems = _getMainItems(widget.oldBoq);
    if (mainDisplayIndex < oldMainItems.length) {
      final oldSubItems = oldMainItems[mainDisplayIndex]['subItems']?.cast<Map<String, dynamic>>() ?? [];
      if (subDisplayIndex < oldSubItems.length) {
        subItemId = oldSubItems[subDisplayIndex]['id']?.toString();
      }
    }
    debugPrint("SubItemId: $subItemId");
    return subItemId;
  }

// Check if item is REMOVED (all newValue = null)
  bool _isItemRemoved(GroupedDiffItem item) {
    return item.fieldDifferences.every((r) => r.newValue == null);
  }

  // Checks the current value in `currentBoq` against the original `oldValue`
  void _syncRevertState() {
    for (var row in allDiffRows) {
      final currentValue = _getCurrentValue(row);
      row.isReverted = row.isChanged && (currentValue?.toString() == row.oldValue?.toString());
      print('Sync row ${row.itemKey}.${row.fieldKey}: isChanged=${row.isChanged}, isReverted=${row.isReverted}, old=${row.oldValue}, current=$currentValue');
    }
  }

  Map<String, dynamic> _makeRestoredMarker(int mainIndex, [int? subIndex]) {
    return {
      '__restored_from_diff': {
        'mainIndex': mainIndex,
        if (subIndex != null) 'subIndex': subIndex,
        'ts': DateTime.now().millisecondsSinceEpoch, // small extra tie-breaker
      }
    };
  }

  void _undoRevert(GroupedDiffItem item) {
    // Don't allow sub-item undo if main item is removed
    if (item.subItemIndex != null) {
      if (_isMainItemRemoved(item.mainItemIndex)) {
        Toast.display(
          type: ToastificationType.warning,
          title: "Cannot undo sub-item when main item is removed",
        );
        return;
      }

      // NEW RULE: Don't allow sub-item undo if main item is ADDED and still REVERTED
      // User must undo the main item first
      if (_isMainItemAdded(item.mainItemIndex) && _isMainItemReverted(item.mainItemIndex)) {
        Toast.display(
          type: ToastificationType.warning,
          title: "Please undo the main item first before undoing its sub-items",
        );
        return;
      }
    }

    setState(() {
      final mainItems = _getMainItems(currentBoq);
      final mainItemIndex = item.mainItemIndex;
      final subItemIndex = item.subItemIndex;

      // Helper to find restored main item by marker
      int _findRestoredMainIndex() {
        final markerIndex = mainItems.indexWhere((m) {
          if (m is Map && m.containsKey('__restored_from_diff')) {
            final marker = m['__restored_from_diff'];
            return marker is Map && marker['mainIndex'] == mainItemIndex;
          }
          return false;
        });
        if (markerIndex != -1) return markerIndex;

        // Fallback: try to find by tender_item name
        final tenderName = item.fieldDifferences.firstWhere((r) => r.fieldKey == 'tender_item', orElse: () => item.fieldDifferences.first).oldValue?.toString();
        if (tenderName != null) {
          final idx = mainItems.indexWhere((m) => m is Map && m['tender_item']?.toString() == tenderName);
          if (idx != -1) return idx;
        }

        // Final fallback: if original index still valid
        if (mainItemIndex < mainItems.length) return mainItemIndex;
        return -1;
      }

      if (subItemIndex == null) {
        // MAIN ITEM UNDO
        final isRemovedMain = item.fieldDifferences.every((r) => r.newValue == null);
        final isAddedMain = item.fieldDifferences.every((r) => r.oldValue == null);

        // NEW: If this is an ADDED main item undo, also undo all its sub-items
        if (isAddedMain) {
          final effectiveMainIdx = mainItemIndex;

          if (effectiveMainIdx < mainItems.length) {
            // Undo main item
            for (var row in item.fieldDifferences) {
              (mainItems[effectiveMainIdx] as Map<String, dynamic>)[row.fieldKey] = row.newValue;
              row.isReverted = false;
            }

            // CASCADE: Undo ALL reverted sub-items of this added main item
            final mainItem = mainItems[effectiveMainIdx] as Map<String, dynamic>;
            mainItem['__reverted_from_diff'] = false;
            final subItems = (mainItem['subItems'] as List<dynamic>?) ?? <dynamic>[];

            final subItemsToUndo = groupedItems.where((subItem) => subItem.mainItemIndex == mainItemIndex && subItem.subItemIndex != null && subItem.isReverted).toList();

            for (var subItem in subItemsToUndo) {
              if (subItem.subItemIndex! < subItems.length) {
                for (var row in subItem.fieldDifferences) {
                  (subItems[subItem.subItemIndex!] as Map<String, dynamic>)[row.fieldKey] = row.newValue;
                  row.isReverted = false;
                }
              }
            }
          }

          currentBoq['data']['mainItems'] = mainItems;
          // Don't call _syncRevertState() - we manually updated the flags
          return;
        }

        // Check if this is a quantity change undo - cascade to sub-items
        final qtyField = item.fieldDifferences.firstWhere(
          (r) => r.fieldKey == 'order_quantity',
          orElse: () => DiffRow(
            itemKey: '',
            fieldKey: 'order_quantity',
            mainItemIndex: -1,
            oldValue: null,
            newValue: null,
            isReverted: false,
            isChanged: false,
          ),
        );

        if (qtyField.mainItemIndex != -1 && qtyField.isChanged && !isRemovedMain) {
          // This is quantity change undo - also undo reverted sub-items
          final effectiveMainIdx = mainItemIndex;

          if (effectiveMainIdx < mainItems.length) {
            // Undo main item
            for (var row in item.fieldDifferences) {
              (mainItems[effectiveMainIdx] as Map<String, dynamic>)[row.fieldKey] = row.newValue;
              row.isReverted = false;
            }

            // CASCADE: Undo all reverted sub-items (only changed ones)
            final mainItem = mainItems[effectiveMainIdx] as Map<String, dynamic>;
            final subItems = (mainItem['subItems'] as List<dynamic>?) ?? <dynamic>[];

            final subItemsToUndo = groupedItems
                .where((subItem) =>
                    subItem.mainItemIndex == mainItemIndex &&
                    subItem.subItemIndex != null &&
                    subItem.isReverted &&
                    subItem.isChanged &&
                    // Only undo changed sub-items, not added/removed ones
                    subItem.fieldDifferences.any((r) => r.oldValue != null && r.newValue != null))
                .toList();

            for (var subItem in subItemsToUndo) {
              if (subItem.subItemIndex! < subItems.length) {
                for (var row in subItem.fieldDifferences) {
                  (subItems[subItem.subItemIndex!] as Map<String, dynamic>)[row.fieldKey] = row.newValue;
                  row.isReverted = false;
                }
              }
            }
          }

          currentBoq['data']['mainItems'] = mainItems;
          // Don't call _syncRevertState() - we manually updated the flags
          return;
        }

        // Regular removed main item undo
        if (isRemovedMain) {
          final restoreIdx = _findRestoredMainIndex();
          if (restoreIdx != -1) {
            mainItems.removeAt(restoreIdx);
            print('Undo: removed restored main item at index $restoreIdx');

            // Mark all field rows as not reverted
            for (var row in item.fieldDifferences) {
              row.isReverted = false;
            }
          } else {
            print('Undo: could not find restored main item to remove');
          }
        } else {
          // Regular undo for modified main fields
          final effectiveMainIdx = mainItemIndex;

          if (effectiveMainIdx < mainItems.length) {
            for (var row in item.fieldDifferences) {
              (mainItems[effectiveMainIdx] as Map<String, dynamic>)[row.fieldKey] = row.newValue;
              row.isReverted = false;
            }
          }
        }
      } else {
        // SUB-ITEM UNDO
        final isRemovedSub = item.fieldDifferences.every((r) => r.newValue == null);
        final isAddedSub = item.fieldDifferences.every((r) => r.oldValue == null);

        final effectiveMainIdx = mainItemIndex;
        final mainItem = effectiveMainIdx < mainItems.length ? mainItems[effectiveMainIdx] as Map<String, dynamic> : null;

        if (mainItem != null) {
          final subItems = (mainItem['subItems'] as List<dynamic>?) ?? <dynamic>[];

          if (isRemovedSub) {
            // Find and remove restored sub-item
            final restoreSubIdx = subItems.indexWhere((s) {
              if (s is Map && s.containsKey('__restored_from_diff')) {
                final marker = s['__restored_from_diff'];
                return marker is Map && marker['mainIndex'] == mainItemIndex && marker['subIndex'] == subItemIndex;
              }
              return false;
            });

            if (restoreSubIdx != -1) {
              subItems.removeAt(restoreSubIdx);
              print('Undo: removed restored sub-item at index $restoreSubIdx');

              // Mark all field rows as not reverted
              for (var row in item.fieldDifferences) {
                print("$row");
                row.isReverted = false;
              }
            } else {
              // Fallback: try to find by tender_sub_item name
              final tenderSub = item.fieldDifferences.firstWhere((r) => r.fieldKey == 'tender_sub_item', orElse: () => item.fieldDifferences.first).oldValue?.toString();
              if (tenderSub != null) {
                final idx = subItems.indexWhere((s) => s is Map && s['tender_sub_item']?.toString() == tenderSub);
                if (idx != -1) {
                  subItems.removeAt(idx);
                  print('Undo fallback: removed restored sub-item by name at index $idx');

                  for (var row in item.fieldDifferences) {
                    print("$row");
                    row.isReverted = false;
                  }
                }
              }
            }
          } else if (isAddedSub) {
            // Undo added sub-item - restore newValue
            if (subItemIndex < subItems.length) {
              for (var row in item.fieldDifferences) {
                (subItems[subItemIndex] as Map<String, dynamic>)[row.fieldKey] = row.newValue;
                row.isReverted = false;
              }
            }

            final subItem = subItems[subItemIndex] as Map<String, dynamic>;
            subItem['__reverted_from_diff'] = false;
          } else {
            // Regular modified sub-item: restore newValue
            if (subItemIndex < subItems.length) {
              for (var row in item.fieldDifferences) {
                (subItems[subItemIndex] as Map<String, dynamic>)[row.fieldKey] = row.newValue;
                row.isReverted = false;
              }
            }
          }
          print("742");
          mainItem['subItems'] = subItems;
          print("744");
        }
      }

      currentBoq['data']['mainItems'] = mainItems;
      print("749");
      // Don't call _syncRevertState() - we manually set isReverted flags above
    });
  }

  void _revertChange(GroupedDiffItem item) {
    setState(() {
      // If reverting a NEWLY ADDED main item, also revert all its sub-items
      if (item.subItemIndex == null) {
        final isAddedMain = item.fieldDifferences.every((r) => r.oldValue == null);

        if (isAddedMain) {
          // Revert main item
          _revertItemFields(item);

          // CASCADE: Revert ALL sub-items of this added main item
          final subItemsToRevert = groupedItems.where((subItem) => subItem.mainItemIndex == item.mainItemIndex && subItem.subItemIndex != null && !subItem.isReverted).toList();

          for (var subItem in subItemsToRevert) {
            _revertItemFields(subItem);
          }

          return;
        }

        // If reverting main item quantity change, also revert changed sub-items
        final qtyField = item.fieldDifferences.firstWhere(
          (r) => r.fieldKey == 'order_quantity',
          orElse: () => DiffRow(
            itemKey: '',
            fieldKey: 'order_quantity',
            mainItemIndex: -1,
            oldValue: null,
            newValue: null,
            isReverted: false,
            isChanged: false,
          ),
        );

        // Check if this is a quantity change
        if (qtyField.mainItemIndex != -1 && qtyField.isChanged) {
          // Revert main item
          _revertItemFields(item);

          // CASCADE: Revert all sub-items (only CHANGED ones, not added/removed)
          final subItemsToRevert = groupedItems
              .where((subItem) =>
                  subItem.mainItemIndex == item.mainItemIndex &&
                  subItem.subItemIndex != null &&
                  !subItem.isReverted &&
                  subItem.isChanged &&
                  // Only revert changed sub-items, not added/removed ones
                  subItem.fieldDifferences.any((r) => r.oldValue != null && r.newValue != null))
              .toList();

          for (var subItem in subItemsToRevert) {
            _revertItemFields(subItem);
          }

          return;
        }
      }

      // Regular revert for non-quantity changes and non-added items
      _revertItemFields(item);
    });
  }

  void _revertAllChanges() {
    setState(() {
      for (var item in groupedItems.where((i) => !i.isReverted)) {
        _revertItemFields(item);
      }
    });
  }

  void _revertItemFields(GroupedDiffItem item) {
    final mainItems = _getMainItems(currentBoq);
    final oldMainItems = _getMainItems(widget.oldBoq);
    final mainItemIndex = item.mainItemIndex;
    final subItemIndex = item.subItemIndex;
    final status = _getDiffStatus(item);
    debugPrint("SubItemIndex :- $subItemIndex");

    // Handle main item restoration (removed main item)
    if (mainItemIndex >= mainItems.length && mainItemIndex < oldMainItems.length) {
      final oldItemCopy = Map<String, dynamic>.from(oldMainItems[mainItemIndex]);
      if (oldItemCopy.containsKey('subItems')) {
        oldItemCopy['subItems'] = List<dynamic>.from(
          (oldItemCopy['subItems'] as List<dynamic>).map(
            (subItem) => Map<String, dynamic>.from(subItem as Map<String, dynamic>),
          ),
        );
      }

      // Attach marker so undo can find this restored object later
      oldItemCopy.addAll(_makeRestoredMarker(mainItemIndex));

      // Extend list up to mainItemIndex - 1 with empty maps if necessary
      while (mainItems.length < mainItemIndex) {
        mainItems.add(<String, dynamic>{});
      }

      if (mainItemIndex == mainItems.length) {
        mainItems.add(oldItemCopy);
      } else {
        mainItems[mainItemIndex] = oldItemCopy;
      }

      print('Restored main item at index $mainItemIndex: ${mainItems[mainItemIndex]}');
    }

    // Update main item fields (existing or just restored)
    if (subItemIndex == null) {
      if (mainItemIndex < mainItems.length) {
        final mainItem = mainItems[mainItemIndex] as Map<String, dynamic>;
        final isAddedMain = item.fieldDifferences.every((r) => r.oldValue == null);

        for (var row in item.fieldDifferences) {
          final oldValue = row.oldValue;
          mainItem[row.fieldKey] = oldValue ?? row.newValue;
          row.isReverted = true;
        }

        // 🟢 Attach marker for reverted ADDED main item
        if (isAddedMain) {
          mainItem['__reverted_from_diff'] = true;
          print('Attached __reverted_from_diff marker to added main item $mainItemIndex');
        }
      }
    } else {
      // Handle sub-item restoration
      if (mainItemIndex < mainItems.length) {
        final mainItem = mainItems[mainItemIndex] as Map<String, dynamic>;
        final subItems = (mainItem['subItems'] as List<dynamic>?) ?? <dynamic>[];
        final oldSubItems = (oldMainItems.length > mainItemIndex) ? (oldMainItems[mainItemIndex] as Map<String, dynamic>)['subItems'] as List<dynamic>? ?? [] : [];

        // If sub-item was removed, create and attach marker directly
        if (subItemIndex >= subItems.length && subItemIndex < oldSubItems.length) {
          final oldSubItemCopy = Map<String, dynamic>.from(oldSubItems[subItemIndex]);
          // attach marker
          oldSubItemCopy.addAll(_makeRestoredMarker(mainItemIndex, subItemIndex));
          subItems.add(oldSubItemCopy);
          mainItem['subItems'] = subItems;
          print('Restored removed sub-item at index $subItemIndex for main item $mainItemIndex: ${subItems.last}');
        }
        try {
          if (status == "REMOVED" && !(subItemIndex >= subItems.length && subItemIndex < oldSubItems.length)) {
            final oldSubItemCopy = Map<String, dynamic>.from(oldSubItems[subItemIndex]);
            oldSubItemCopy.addAll(_makeRestoredMarker(mainItemIndex, subItemIndex));
            subItems[subItemIndex] = oldSubItemCopy;
            mainItem['subItems'] = subItems;
          }
        } catch (_) {}

        // Update sub-item fields
        if (subItemIndex < subItems.length) {
          final subItem = subItems[subItemIndex] as Map<String, dynamic>;
          final isAddedSub = item.fieldDifferences.every((r) => r.oldValue == null);

          for (var row in item.fieldDifferences) {
            final oldValue = row.oldValue;
            subItem[row.fieldKey] = oldValue ?? row.newValue;
            row.isReverted = true;
          }

          // 🟢 Attach marker for reverted ADDED sub-item
          if (isAddedSub) {
            subItem['__reverted_from_diff'] = true;
            print('Attached __reverted_from_diff marker to added sub-item $subItemIndex of main $mainItemIndex');
          }
        }
        mainItem['subItems'] = subItems;
      }
    }

    currentBoq['data']['mainItems'] = mainItems;
    print('Updated currentBoq: ${currentBoq['data']['mainItems'].length} items');
  }

  // Helper to get the current value from the currentBoq state
  dynamic _getCurrentValue(DiffRow row) {
    final mainItems = _getMainItems(currentBoq);

    // --- Extend mainItems if needed ---
    if (row.mainItemIndex >= mainItems.length) {
      final missing = row.mainItemIndex - mainItems.length + 1;
      print('⚙️ Extending mainItems by $missing placeholder(s) for index ${row.mainItemIndex}');
      for (int i = 0; i < missing; i++) {
        mainItems.add(<String, dynamic>{});
      }
      currentBoq['data']['mainItems'] = mainItems;
    }

    final currentItem = mainItems[row.mainItemIndex] as Map<String, dynamic>;

    // --- Ensure subItems list exists ---
    if (row.subItemIndex != null) {
      if (!currentItem.containsKey('subItems') || currentItem['subItems'] == null) {
        currentItem['subItems'] = <Map<String, dynamic>>[];
      }

      final subItems = currentItem['subItems'] as List<dynamic>;

      // Extend subItems if needed
      if (row.subItemIndex! >= subItems.length) {
        final missingSubs = row.subItemIndex! - subItems.length + 1;
        print('⚙️ Extending subItems by $missingSubs placeholder(s) for mainItem ${row.mainItemIndex}');
        for (int i = 0; i < missingSubs; i++) {
          subItems.add(<String, dynamic>{});
        }
        currentItem['subItems'] = subItems;
      }

      final subItem = currentItem['subItems'][row.subItemIndex!] as Map<String, dynamic>;
      final value = subItem[row.fieldKey];
      return value;
    }

    // Main item value
    final value = currentItem[row.fieldKey];
    return value;
  }

// Simplified _prepareApiRequest using tags
  Map<String, dynamic> _prepareApiRequest() {
    final newMainItems = _getMainItems(currentBoq).cast<Map<String, dynamic>>();
    final oldMainItems = _getMainItems(widget.oldBoq).cast<Map<String, dynamic>>();

    final oldMainByName = <String, Map<String, dynamic>>{};
    final oldMainById = <int, Map<String, dynamic>>{};
    for (var oldItem in oldMainItems) {
      final name = oldItem['tender_item']?.toString() ?? '';
      final id = oldItem['id'] as int?;
      if (name.isNotEmpty) {
        oldMainByName[name] = Map<String, dynamic>.from(oldItem);
      }
      if (id != null) {
        oldMainById[id] = Map<String, dynamic>.from(oldItem);
      }
    }

    final oldMainMap = _buildPositionMap(oldMainItems, 'tender_item');
    final finalMainItems = <Map<String, dynamic>>[];

    for (int newIdx = 0; newIdx < newMainItems.length; newIdx++) {
      final newItem = Map<String, dynamic>.from(newMainItems[newIdx]);
      final itemName = newItem['tender_item']?.toString() ?? 'Item $newIdx';
      final mainId = newItem['id'] as int?;

      // 🏷️ Check the tag we added during comparison
      final diffStatus = newItem['__diff_status']?.toString();
      final revertStatus = newItem['__reverted_from_diff'] as bool?;
      final isAddedMain = diffStatus == 'ADDED';

      debugPrint("${newItem['tender_item']} is added :- $isAddedMain");
      debugPrint("${newItem['tender_item']} is diffstatus :- ${newItem['__diff_status']}");
      debugPrint("${newItem['tender_item']} is reverted :- $revertStatus");

      final mainGroup = mainGroupMap[newIdx]!;

      final isRemovedMain = mainGroup.mainItemIndex != -1 && mainGroup.fieldDifferences.every((r) => r.newValue == null);
      final isRevertedRemovedMain = isRemovedMain && mainGroup.isReverted;

      // 🚫 RULE 1: Skip removed + not reverted
      if (isRemovedMain && !mainGroup.isReverted) continue;

      // 🚫 RULE 2: Skip added + reverted
      if (isAddedMain && revertStatus == true) continue;

      // ⚙️ RULE 3: Populate old fields for:
      // - Existing items (!isAddedMain)
      // - Reverted removed items (isRevertedRemovedMain)
      Map<String, dynamic> matchingOldItem = <String, dynamic>{};
      if (!isAddedMain) {
        // Try to match by ID first (most reliable)
        if (mainId != null && oldMainById.containsKey(mainId)) {
          matchingOldItem = Map<String, dynamic>.from(oldMainById[mainId]!);
        } else {
          // Fallback to position-based matching
          final tempQueue = Queue<int>.from(oldMainMap[itemName]?.toList() ?? []);
          if (tempQueue.isNotEmpty) {
            final idx = tempQueue.removeFirst();
            matchingOldItem = Map<String, dynamic>.from(oldMainItems[idx]);
          } else if (oldMainByName.containsKey(itemName)) {
            matchingOldItem = Map<String, dynamic>.from(oldMainByName[itemName]!);
          }
        }

        if (matchingOldItem.isNotEmpty) {
          for (var key in matchingOldItem.keys) {
            if (!newItem.containsKey(key) || newItem[key] == null) {
              newItem[key] = matchingOldItem[key];
            }
          }
        }
      }

      // 🧹 Clean metadata for:
      // - Newly added items (isAddedMain)
      // - Reverted removed items (isRevertedRemovedMain) - they get old data BUT no IDs
      if (isAddedMain) {
        for (var key in ['id', 'boq_file_id', 'createdAt', 'updatedAt', 'deletedAt', '__diff_status']) {
          newItem.remove(key);
        }
      }

      // 🔽 Handle Sub-Items
      final newSubItems = (newItem['subItems'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final oldSubItems = (matchingOldItem['subItems'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

      // Build old sub-item lookup by name and ID
      final oldSubByName = <String, Map<String, dynamic>>{};
      final oldSubById = <int, Map<String, dynamic>>{};
      for (var oldSub in oldSubItems) {
        final subName = oldSub['tender_sub_item']?.toString() ?? '';
        final subId = oldSub['id'] as int?;
        if (subName.isNotEmpty) {
          oldSubByName[subName] = Map<String, dynamic>.from(oldSub);
        }
        if (subId != null) {
          oldSubById[subId] = Map<String, dynamic>.from(oldSub);
        }
      }

      final oldSubMap = _buildPositionMap(oldSubItems, 'tender_sub_item');
      final finalSubItems = <Map<String, dynamic>>[];

      for (int newSubIdx = 0; newSubIdx < newSubItems.length; newSubIdx++) {
        final newSub = Map<String, dynamic>.from(newSubItems[newSubIdx]);
        final subName = newSub['tender_sub_item']?.toString() ?? 'Sub $newSubIdx';
        final subId = newSub['id'] as int?;

        // 🏷️ Check the tag we added during comparison
        final subDiffStatus = newSub['__diff_status']?.toString();
        final revertStatus = newSub['__reverted_from_diff'] as bool?;
        final isAddedSub = subDiffStatus == 'ADDED';

        final subGroup = subGroupMap['${newIdx}_$newSubIdx']!;

        final isRemovedSub = subGroup.mainItemIndex != -1 && subGroup.fieldDifferences.every((r) => r.newValue == null);
        final isRevertedRemovedSub = isRemovedSub && subGroup.isReverted;

        // 🚫 RULE 1: Skip removed + not reverted
        if (isRemovedSub && !subGroup.isReverted) continue;

        // 🚫 RULE 2: Skip added + reverted
        if (isAddedSub && revertStatus == true) continue;

        // ⚙️ RULE 3: Populate old data for:
        // - Existing items (!isAddedSub)
        // - Reverted removed items (isRevertedRemovedSub)
        Map<String, dynamic> matchingOldSub = <String, dynamic>{};
        if (!isAddedSub || isRevertedRemovedSub) {
          // Try to match by ID first (most reliable)
          if (subId != null && oldSubById.containsKey(subId)) {
            matchingOldSub = Map<String, dynamic>.from(oldSubById[subId]!);
          } else {
            // Fallback to position-based name matching
            final tempSubQueue = Queue<int>.from(oldSubMap[subName]?.toList() ?? []);
            if (tempSubQueue.isNotEmpty) {
              final idx = tempSubQueue.removeFirst();
              matchingOldSub = Map<String, dynamic>.from(oldSubItems[idx]);
            } else if (oldSubByName.containsKey(subName)) {
              matchingOldSub = Map<String, dynamic>.from(oldSubByName[subName]!);
            }
          }

          // Only populate if we found a valid match
          if (matchingOldSub.isNotEmpty) {
            for (var key in matchingOldSub.keys) {
              if (!newSub.containsKey(key) || newSub[key] == null) {
                newSub[key] = matchingOldSub[key];
              }
            }
          }
        }

        // 🧹 Clean metadata for:
        // - Newly added items (isAddedSub)
        // - Reverted removed items (isRevertedRemovedSub) - they get old data BUT no IDs
        if (isAddedSub) {
          for (var key in ['id', 'main_line_item_id', 'createdAt', 'updatedAt', 'deletedAt', '__diff_status', '__reverted_from_diff']) {
            newSub.remove(key);
          }
        }

        // 🪝 Link sub to main ONLY if:
        // - Sub-item is existing (not new, not reverted removed)
        // - Main item has an ID
        if (!isAddedSub && newItem.containsKey('id') && newItem['id'] != null) {
          newSub['main_line_item_id'] = newItem['id'];
        }

        // Only add non-empty sub-items with meaningful data
        if (newSub.isNotEmpty && newSub.containsKey('tender_sub_item')) {
          finalSubItems.add(newSub);
        }
      }

      newItem['subItems'] = finalSubItems;

      // Clean __diff_status from final output
      newItem.remove('__diff_status');
      newItem.remove('__reverted_from_diff');

      // Only add main items that have the required field
      if (newItem.containsKey('tender_item')) {
        finalMainItems.add(newItem);
      }
    }

    final boqData = {
      'file_name': widget.newBoq['data']?['file_name'] ?? 'Tender Version',
      'mainItems': finalMainItems,
    };

    final requestBody = {
      'project_id': widget.project,
      'boq_data': boqData,
    };

    return requestBody;
  }

  Future<void> _handleReupload() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // Prepare the API response
      final apiRequestBody = _prepareApiRequest();

      // // Simulate API call (replace with actual API call)
      final response = await BoqApiService.reuploadBoqFile(
        file: widget.file,
        body: apiRequestBody,
      );
      debugPrint("${jsonEncode(apiRequestBody)}");

      if (response.statusCode == 401) {
        throw UnauthorizedException();
      }

      if (response.statusCode != 200 && response.statusCode != 201) {
        final json = jsonDecode(response.body);

        if (json['validation_error'] is String) {
          Toast.display(type: ToastificationType.error, title: json['validation_error']);
          setState(() {
            _isLoading = false;
          });
          return;
        }
        final List errors = json['validation_error'] ?? [];

        Toast.display(type: ToastificationType.error, title: "Validation failed");
        setState(() {
          _isLoading = false;
        });
        if (errors.isNotEmpty) {
          BoqUploadHelper.showValidationErrorsDialog(context, errors);
        }
        return;
      }

      final json = jsonDecode(response.body);

      Toast.display(title: json['message'], type: ToastificationType.success);

      globalNavigatorKey.currentContext!.pop();
    } on UnauthorizedException catch (_) {
      await SessionManager().handleSessionExpiration(context);
    } catch (e) {
      if (mounted) {
        Toast.display(title: "$e", type: ToastificationType.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasChanges = groupedItems.isNotEmpty;
    final fileName = widget.newBoq['data']?['file_name'] ?? 'Unknown File';

    final totalRowsWithDiffs = groupedItems.where((i) => i.isChanged).length;
    final revertedRows = groupedItems.where((i) => i.isReverted && i.isChanged).length;
    final remainingRows = totalRowsWithDiffs - revertedRows;

    return AlertDialog(
      backgroundColor: ColorConstants.pageBackground,
      title: const Row(
        children: [
          Icon(Icons.compare_arrows, color: Colors.blue),
          SizedBox(width: 8),
          Text('Tender Reupload'),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              'File: $fileName',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // --- Summary and Revert All Button ---
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _statusLegend(Colors.green.shade700, 'Added'),
                      const SizedBox(width: 20),
                      _statusLegend(Colors.red.shade700, 'Removed'),
                      const SizedBox(width: 20),
                      _statusLegend(Colors.blue.shade700, 'Changed'),
                      const SizedBox(width: 20),
                      _statusLegend(Colors.grey.shade700, 'Unchanged'),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'Total Items Changed: $totalRowsWithDiffs | Reverted: $revertedRows | Remaining: $remainingRows',
                        style: TextStyle(fontWeight: FontWeight.w600, color: remainingRows > 0 ? Colors.red.shade700 : Colors.green.shade700),
                      ),
                      // const SizedBox(width: 20),
                      // ElevatedButton.icon(
                      //   onPressed: remainingRows > 0 ? _revertAllChanges : null,
                      //   icon: const Icon(Icons.undo),
                      //   label: const Text('Undo All Changes'),
                      //   style: ElevatedButton.styleFrom(
                      //     backgroundColor: remainingRows > 0 ? Colors.orange.shade100 : Colors.grey.shade300,
                      //     foregroundColor: remainingRows > 0 ? Colors.orange.shade900 : Colors.grey.shade700,
                      //   ),
                      // ),
                    ],
                  ),
                ],
              ),
            ),

            // --- Diff Table (Scrollable) ---
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : hasChanges
                      ? _buildGitStyleSplitDiff()
                      : const Center(child: Text('No changes detected between the BOQ versions.', style: TextStyle(fontSize: 16))),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: hasChanges ? _handleReupload : null,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Confirm Reupload'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildGitStyleSplitDiff() {
    // Dynamic fields based on FIRST item type
    final firstItem = groupedItems.firstOrNull;
    final isSubTable = firstItem?.subItemIndex != null;
    final fieldsMain = _comparisonMainFields.where((f) => f != 'tender_item_long').toList();
    final fieldsSub = _comparisonSubFields.where((f) => f != 'tender_item_long').toList();
    final fields = isSubTable ? fieldsSub : fieldsMain;

    String getDisplayName(String key) {
      switch (key) {
        case 'tender_item':
          return isSubTable ? 'Sub Item' : 'Item Name';
        case 'tender_item_long':
          return 'Description';
        case 'rate':
          return 'Rate';
        case 'order_quantity':
          return isSubTable ? 'Required Qty' : 'Order Qty';
        case 'unit_of_measure':
          return 'UOM';
        case 'tender_sub_item':
          return 'Sub Item';
        case 'required_quantity':
          return 'Required Qty';
        default:
          return key;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalController = ScrollController();
        final verticalController = ScrollController();
        const borderColor = Color(0xFFcbc5d1);

        return Scrollbar(
          controller: horizontalController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: horizontalController,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Column(
                children: [
                  // Sticky header (Dynamic!)
                  ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Table(
                      border: const TableBorder(
                        top: BorderSide(width: 1, color: borderColor),
                        left: BorderSide(width: 1, color: borderColor),
                        bottom: BorderSide(width: 1, color: borderColor),
                        verticalInside: BorderSide(width: 1, color: borderColor),
                        horizontalInside: BorderSide(width: 1, color: borderColor),
                      ),
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      columnWidths: const {
                        0: FlexColumnWidth(3),
                        1: FlexColumnWidth(1),
                        2: FlexColumnWidth(1),
                        3: FlexColumnWidth(1),
                        4: FlexColumnWidth(1),
                        5: FlexColumnWidth(3),
                        6: FlexColumnWidth(1),
                        7: FlexColumnWidth(1),
                        8: FlexColumnWidth(1),
                      },
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(color: Color(0xFFECECEC)),
                          children: [
                            // Old BOQ headers (red)
                            ...fields.map(
                              (f) => Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  getDisplayName(f),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                                ),
                              ),
                            ),
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                            // New BOQ headers (green)
                            ...fields.map(
                              (f) => Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  getDisplayName(f),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Scrollable body
                  Expanded(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: SingleChildScrollView(
                        controller: verticalController,
                        scrollDirection: Axis.vertical,
                        child: Table(
                          border: const TableBorder(
                            left: BorderSide(width: 1, color: borderColor),
                            bottom: BorderSide(width: 1, color: borderColor),
                            verticalInside: BorderSide(width: 1, color: borderColor),
                            horizontalInside: BorderSide(width: 1, color: borderColor),
                          ),
                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                          columnWidths: const {
                            0: FlexColumnWidth(3),
                            1: FlexColumnWidth(1),
                            2: FlexColumnWidth(1),
                            3: FlexColumnWidth(1),
                            4: FlexColumnWidth(1),
                            5: FlexColumnWidth(3),
                            6: FlexColumnWidth(1),
                            7: FlexColumnWidth(1),
                            8: FlexColumnWidth(1),
                          },
                          children: [
                            for (var item in groupedItems) _buildMergedDiffRow(item),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  TableRow _buildMergedDiffRow(GroupedDiffItem item) {
    final status = _getDiffStatus(item);
    final rowColor = _getRowColor(status);
    final isSubItem = item.subItemIndex != null;
    final fieldsMain = _comparisonMainFields.where((f) => f != 'tender_item_long').toList();
    final fieldsSub = _comparisonSubFields.where((f) => f != 'tender_item_long').toList();
    final fields = isSubItem ? fieldsSub : fieldsMain;
    final fontWeight = isSubItem ? FontWeight.normal : FontWeight.bold;

    // Check if sub-item should be disabled
    final isSubItemDisabled = isSubItem && (_isMainItemRemoved(item.mainItemIndex) || (_hasMainItemQuantityChange(item.mainItemIndex) && (status != 'ADDED' && status != 'REMOVED' && status != 'UNCHANGED')));

    List<Widget> cells = [];

    // Old BOQ values
    for (final field in fields) {
      final diff = item.fieldDifferences.firstWhere(
        (r) => r.fieldKey == field,
        orElse: () => DiffRow(
          itemKey: item.itemKey,
          fieldKey: field,
          mainItemIndex: item.mainItemIndex,
          subItemIndex: item.subItemIndex,
          oldValue: null,
          newValue: null,
          isReverted: true,
          isChanged: false,
        ),
      );

      Widget content = Text(
        diff.oldValue?.toString() ?? '',
        style: TextStyle(
          fontWeight: fontWeight,
          color: isSubItemDisabled ? Colors.grey.shade400 : (diff.isChanged ? Colors.red.shade700 : Colors.grey.shade700),
        ),
      );

      // Tooltip for name fields
      final nameField = isSubItem ? 'tender_sub_item' : 'tender_item';
      if (field == nameField) {
        final desc = item.fieldDifferences
            .firstWhere(
              (r) => r.fieldKey == 'tender_item_long',
              orElse: () => DiffRow(
                itemKey: item.itemKey,
                fieldKey: 'tender_item_long',
                mainItemIndex: item.mainItemIndex,
                subItemIndex: item.subItemIndex,
                oldValue: null,
                newValue: null,
                isReverted: true,
                isChanged: false,
              ),
            )
            .oldValue;
        content = Tooltip(message: desc?.toString() ?? '', child: content);
      }

      cells.add(Padding(padding: const EdgeInsets.all(8.0), child: content));
    }

    // Action column
    cells.add(Padding(
      padding: const EdgeInsets.all(6.0),
      child: Center(
        child: !item.isChanged
            ? const SizedBox.shrink()
            : isSubItemDisabled
                ? const Icon(Icons.block, color: Colors.grey, size: 16)
                : status == 'REMOVED' && _isNonRemovableDisabled(item) // 👈 NEW CHECK
                    ? Tooltip(
                        message: "Non-removable item",
                        child: const Icon(Icons.lock, color: Colors.grey, size: 16),
                      )
                    : item.isReverted
                        ? IconButton(
                            tooltip: "Undo",
                            icon: const Icon(Icons.undo, color: Colors.orange, size: 16),
                            onPressed: () => _undoRevert(item),
                          )
                        : IconButton(
                            tooltip: "Revert",
                            icon: const Icon(Icons.redo, color: Colors.blue, size: 16),
                            onPressed: () => _revertChange(item),
                          ),
      ),
    ));

    // New BOQ values
    for (final field in fields) {
      final diff = item.fieldDifferences.firstWhere(
        (r) => r.fieldKey == field,
        orElse: () => DiffRow(
          itemKey: item.itemKey,
          fieldKey: field,
          mainItemIndex: item.mainItemIndex,
          subItemIndex: item.subItemIndex,
          oldValue: null,
          newValue: null,
          isReverted: true,
          isChanged: false,
        ),
      );

      final currentValue = _getCurrentValue(diff);
      Widget content = Text(
        currentValue?.toString() ?? (diff.isReverted ? diff.oldValue?.toString() ?? '' : ''),
        style: TextStyle(
          fontWeight: fontWeight,
          color: isSubItemDisabled ? Colors.grey.shade400 : (diff.isChanged ? Colors.green.shade700 : Colors.grey.shade700),
          decoration: diff.isReverted && status == 'ADDED' ? TextDecoration.lineThrough : null,
        ),
      );

      // Tooltip for name fields
      final nameField = isSubItem ? 'tender_sub_item' : 'tender_item';
      if (field == nameField) {
        final desc = item.fieldDifferences
            .firstWhere(
              (r) => r.fieldKey == 'tender_item_long',
              orElse: () => DiffRow(
                itemKey: item.itemKey,
                fieldKey: 'tender_item_long',
                mainItemIndex: item.mainItemIndex,
                subItemIndex: item.subItemIndex,
                oldValue: null,
                newValue: null,
                isReverted: true,
                isChanged: false,
              ),
            )
            .newValue;
        content = Tooltip(message: desc?.toString() ?? '', child: content);
      }

      cells.add(Padding(padding: const EdgeInsets.all(8.0), child: content));
    }

    return TableRow(
      decoration: BoxDecoration(
        color: isSubItemDisabled ? Colors.grey.shade200 : rowColor,
      ),
      children: cells,
    );
  }

  // --- Utility Functions for Diff ---
  String _getDiffStatus(GroupedDiffItem item) {
    final hasOld = item.fieldDifferences.any((r) => r.oldValue != null);
    final hasNew = item.fieldDifferences.any((r) => r.newValue != null);
    if (!hasOld) return 'ADDED';
    if (!hasNew) return 'REMOVED';
    if (item.fieldDifferences.any((r) => r.isChanged)) return 'CHANGED';
    return 'UNCHANGED';
  }

  Color _getRowColor(String status) {
    switch (status) {
      case 'ADDED':
        return Colors.green.shade50;
      case 'REMOVED':
        return Colors.red.shade50;
      case 'CHANGED':
        return Colors.blue.shade50;
      case 'UNCHANGED':
        return Colors.grey.shade100;
      default:
        return Colors.white;
    }
  }

  Widget _statusLegend(Color color, String status) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            color: color,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          status,
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  // Check if item should have DISABLED revert button
  bool _isNonRemovableDisabled(GroupedDiffItem item) {
    if (item.subItemIndex == null) {
      String? mainId;
      bool hasSubNonRemovable = false;
      final oldMainItems = _getMainItems(widget.oldBoq);
      if (item.mainItemIndex < oldMainItems.length) {
        final mainItem = oldMainItems[item.mainItemIndex];
        mainId = mainItem['id']?.toString();
        final oldSubItems = mainItem['subItems']?.cast<Map<String, dynamic>>() ?? [];
        for (final sub in oldSubItems) {
          final subId = sub['id']?.toString();
          if (subId != null && notRemovableSubItems[subId] == true) {
            hasSubNonRemovable = true;
            break;
          }
        }
      }
      final isMainNonRemovable = mainId != null && notRemovableMainItems[mainId] == true;
      return isMainNonRemovable || hasSubNonRemovable;
    }
    final id = _getOldBoqSubId(item.mainItemIndex, item.subItemIndex!);
    final mainId = _getOldBoqMainId(item.mainItemIndex);
    final sub = id != null && notRemovableSubItems[id] == true;
    final main = mainId != null && notRemovableMainItems[mainId] == true;
    return sub || main;
  }
}
