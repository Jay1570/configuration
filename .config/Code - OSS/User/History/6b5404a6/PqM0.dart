import 'package:dhipl_flutter/config/actions_constants.dart';
import 'package:dhipl_flutter/presentations/screens/dashboard/shared/drawer_menu_item.dart';

/// Returns the full, permission-filtered left-nav / More list for the app.
/// - `currentPermissions`: map of activityId -> hasPermission
/// - `isSuperAdmin`: if true, bypasses permission checks
List<DrawerMenuItem> buildAllowedMenus({
  required Map<String, bool> currentPermissions,
  required bool isSuperAdmin,
}) {
  // Define all possible menus once.
  final allMenus = <DrawerMenuItem>[
    DrawerMenuItem(
      title: 'Dashboard',
      icon: 'dashboard_icon.png',
      index: 0,
      activityId: getActivityId("show_dashboard"),
    ),
    DrawerMenuItem(
      title: 'Projects',
      icon: 'project_icon.png',
      index: 1,
      activityId: getActivityId("show_project"),
    ),
    DrawerMenuItem(
      title: 'Purchase Requests',
      icon: 'purchase_request.png',
      index: 15,
      activityId: getActivityId("show_pr"),
    ),
    DrawerMenuItem(
      title: 'Purchase Orders',
      icon: 'purchase_order.png',
      index: 16,
      activityId: getActivityId("show_po"),
    ),
    DrawerMenuItem(
      title: 'Labour Requests',
      icon: 'labour_request.png',
      index: 20,
      activityId: getActivityId("show_lr"),
    ),
      DrawerMenuItem(
      index: 24,
      title: 'Service Orders',
      icon: 'so_icon.png', // Using existing PO icon
      activityId: getActivityId("show_so"),
    ),
    DrawerMenuItem(
      title: 'Work Orders',
      icon: 'work_order.png',
      index: 23,
      activityId: getActivityId("show_wo"),
    ),
    // DrawerMenuItem(
    //   title: 'Non-Claimable List',
    //   icon: 'returnable.png',
    //   index: 25,
    //   activityId: getActivityId("show_wo"),
    //  ),
    DrawerMenuItem(
      title: 'Inventory',
      icon: 'inventoryIcon.png',
      index: 22,
      activityId: getActivityId("view_inventory"),
    ),
    // DrawerMenuItem(
    //   title: 'Returnable',
    //   icon: 'returnable.png',
    //   index: 25,
    //   activityId: getActivityId("show_wo"),
    // ),
    // DrawerMenuItem(
    //   title: 'Stock Transfer',
    //   icon: 'stockTransferTileIcon.png',
    //   index: 26,
    //   activityId: getActivityId("show_wo"),
    // ),
    DrawerMenuItem(
      title: 'Users',
      icon: 'users_icon.png',
      index: 2,
      activityId: getActivityId("show_users"),
    ),
    DrawerMenuItem(
      title: 'Permissions',
      icon: 'permissions.png',
      index: 10,
      activityId: getActivityId("show_permissions"),
    ),
    DrawerMenuItem(
      title: 'Notifications',
      icon: 'notification_permission.png',
      index: 14,
      activityId: getActivityId("show_permissions"),
    ),
    DrawerMenuItem(
      title: 'Masters',
      icon: 'dashboard_icon.png',
      index: 4,
      activityId: getActivityId("show_masters"),
      subItems: [
        DrawerMenuItem(title: 'Entities', icon: '', index: 4, activityId: getActivityId("show_entities")),
        DrawerMenuItem(title: 'Clients', icon: '', index: 3, activityId: getActivityId("show_clients")),
        DrawerMenuItem(title: 'Roles', icon: '', index: 5, activityId: getActivityId("show_roles")),
        DrawerMenuItem(title: 'Contractor Types', icon: '', index: 6, activityId: getActivityId("show_contractor_types")),
        DrawerMenuItem(title: 'Contractors', icon: '', index: 7, activityId: getActivityId("show_contractors")),
        DrawerMenuItem(title: 'Units', icon: '', index: 9, activityId: getActivityId("show_units")),
        DrawerMenuItem(title: 'Material Types', icon: '', index: 11, activityId: getActivityId("show_material_types")),
        DrawerMenuItem(title: 'Materials', icon: '', index: 8, activityId: getActivityId("show_materials")),
        DrawerMenuItem(title: 'Activity Groups', icon: '', index: 12, activityId: getActivityId("show_activity_groups")),
        DrawerMenuItem(title: 'Activities', icon: '', index: 13, activityId: getActivityId("show_activities")),
        DrawerMenuItem(title: 'Vendor Specialty', icon: '', index: 18, activityId: getActivityId("show_vendors")),
        DrawerMenuItem(title: 'Vendors', icon: '', index: 17, activityId: getActivityId("show_vendors")),
        DrawerMenuItem(title: 'GST Rates', icon: '', index: 19, activityId: getActivityId("show_gst_rates")),
      ],
    ),
  ];

  // Filter using permissions.
  final filtered = <DrawerMenuItem>[];

  final alwaysVisible = {
    "Dashboard",
    "Projects",
    "Notifications",
    "Purchase Requests",
    "Purchase Orders",
    "Labour Requests",
    "Work Orders",
    "Service Orders",
  };
  for (final item in allMenus) {
    // Always show these top-level modules
    if (alwaysVisible.contains(item.title)) {
      filtered.add(item);
      continue;
    }

    if (item.title == 'Masters') {
      final allowedSubs = item.subItems.where((sub) {
        return isSuperAdmin || (currentPermissions[sub.activityId] ?? false);
      }).toList();

      if (allowedSubs.isNotEmpty) {
        filtered.add(DrawerMenuItem(
          title: item.title,
          icon: item.icon,
          index: item.index,
          activityId: item.activityId,
          subItems: allowedSubs,
        ));
      }
      continue;
    }

    if (isSuperAdmin || (currentPermissions[item.activityId] ?? false)) {
      filtered.add(item);
    }
  }

  return filtered;
}
