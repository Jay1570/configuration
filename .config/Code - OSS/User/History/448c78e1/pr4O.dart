// create_service_order.dart
import 'package:dhipl_flutter/config/actions_constants.dart';
import 'package:dhipl_flutter/config/app_dependencies.dart';
import 'package:dhipl_flutter/config/assets_path.dart';
import 'package:dhipl_flutter/config/session_expiration_toast.dart';
import 'package:dhipl_flutter/core/network/company_api_service.dart';
import 'package:dhipl_flutter/core/network/contractor_api_service.dart';
import 'package:dhipl_flutter/core/network/gst_api_service.dart';
import 'package:dhipl_flutter/core/network/po_api_service.dart';
import 'package:dhipl_flutter/core/network/project_api_service.dart';
import 'package:dhipl_flutter/core/network/so_api_service.dart';
import 'package:dhipl_flutter/data/models/contractor_model.dart';
import 'package:dhipl_flutter/data/models/gst_model.dart';
import 'package:dhipl_flutter/main.dart';
import 'package:dhipl_flutter/presentations/screens/masters/contractor/contractor_view_model.dart';
import 'package:dhipl_flutter/presentations/widget/contractor_dialog.dart';
import 'package:dhipl_flutter/presentations/widget/flat_dropdown.dart';
import 'package:dhipl_flutter/presentations/widget/flat_dropdown_2.dart';
import 'package:dhipl_flutter/presentations/widget/flat_dropdown_dialog.dart';
import 'package:dhipl_flutter/presentations/widget/non_claimable_chip.dart';
import 'package:dhipl_flutter/presentations/widget/so_preview_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';
import 'package:dhipl_flutter/presentations/screens/purchase_order/po_list.dart' as po;

class CreateServiceOrderScreen extends StatefulWidget {
  final int? project;

  const CreateServiceOrderScreen({Key? key, this.project}) : super(key: key);

  @override
  _CreateServiceOrderScreenState createState() => _CreateServiceOrderScreenState();
}

class _CreateServiceOrderScreenState extends State<CreateServiceOrderScreen> {
  List<Map<String, dynamic>> items = [];

  List<Map<String, TextEditingController>> controllers = [];

  List<Map<String, dynamic>> filteredItems = [];

  TextEditingController searchController = TextEditingController();

  List<po.ProjectMini> _allProjects = [];

  List<po.ProjectMini> _selectedProjects = [];

  ProjectModel? _project;

  late final UserProvider userProvider;
  late final AuthProvider authProvider;

  Map<String, bool> currentPermissions = {};
  bool isSuperAdmin = false;

  late List<ContractorModel> contractors;

  late List<ContractorTypeModel> contractorTypes;

  late List<GstModel> taxRates;

  final ScrollController _hCtrl = ScrollController();
  final ScrollController _vCtrl = ScrollController();

  bool _isLoading = false;

  // bool get canRequestQuotation => widget.project != null ? currentPermissions[getActivityId("request_quotation_for_po")] ?? isSuperAdmin : true;
  bool get canRaiseSO => widget.project != null ? currentPermissions[getActivityId("raise_so")] ?? isSuperAdmin : true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      authProvider = Provider.of<AuthProvider>(context, listen: false);
      userProvider = Provider.of<UserProvider>(context, listen: false);

      await fetchData();

      checkAndSetPermission();

      searchController.addListener(_filterItems);
      userProvider.addListener(checkAndSetPermission);
    });
  }

  void checkAndSetPermission() {
    setState(() {
      _isLoading = true;
    });
    final roleId = authProvider.user?.role?.id;
    Map<String, bool> newPermissions = {};
    if (roleId != 1 && (userProvider.permissions.isEmpty)) {
      return;
    }
    if (widget.project != null) {
      if (roleId == 1) {
        isSuperAdmin = true;
        newPermissions[getActivityId("create_so")] = true;
        newPermissions[getActivityId("raise_so")] = true;
        newPermissions[getActivityId("request_quotation_for_so")] = true;
        newPermissions[getActivityId("add_contractor")] = true;
        newPermissions[getActivityId("add_contractor_type")] = true;
      } else if (_project != null) {
        isSuperAdmin = false;
        final roles = (_project!.rawJson['roles'] as List?)?.cast<String>() ?? [];
        for (final r in roles) {
          final rolePermissions = userProvider.permissions[r] ?? {};
          for (final entry in rolePermissions.entries) {
            newPermissions[entry.key] = (newPermissions[entry.key] ?? false) || entry.value;
          }
        }
      }

      final canCreate = newPermissions[getActivityId("create_so")] ?? false;
      if (!canCreate && !isSuperAdmin) {
        final url = widget.project == null ? '/service-orders' : '/projects/service-order/${widget.project}';
        SessionManager().handleNoPermission(url);
      }
    }
    if (mounted) {
      setState(() {
        currentPermissions = newPermissions;
        isSuperAdmin = roleId == 1;
        _isLoading = false;
      });
    }
  }

  Future<void> fetchData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      contractors = await ContractorApiService().fetchContractors();
      contractorTypes = await ContractorApiService().fetchContractorTypes();
      taxRates = await GSTApiService().fetchGSTs();
      taxRates.insert(0, const GstModel(id: 0, rate: 0, createdBy: null, createdAt: null));

      // Fake projects list for dropdown when widget.project == null.
      if (_allProjects.isEmpty) {
        _allProjects = await PoApiService().fetchProjectsDropdown();
      }

      if (widget.project != null) {
        // If project provided, emulate fetching the project
        final p = await ProjectApiService().getProjectById(widget.project!);
        setState(() {
          _project = p;
        });
      }

      Map<String, dynamic> body = {
        'filter': {},
      };

      if (widget.project != null) {
        body['project_id'] = widget.project;
      }

      final response = await SoApiService().fetchCreateSoItems(body: body);

      List<Map<String, dynamic>> apiItems = [];

      final List<dynamic> data = response['data'];

      apiItems = data.asMap().entries.map((entry) {
        final index = entry.key;
        final value = entry.value;
        final labour = value['labour_request_items'] as Map<String, dynamic>;
        final main = labour['main_item'] as Map<String, dynamic>;
        final sub = labour['sub_item'] as Map<String, dynamic>;
        final contractor = labour['contractor'] as Map<String, dynamic>?;

        // Unique row identifier (you can use labour['id'] or generate one)
        final int lrItemId = labour['id'] as int;

        return <String, dynamic>{
          'lrItemId': lrItemId,
          'srNo': index + 1, // sequential number
          'projectName': value['project']['project_name'] ?? '',
          'item': sub['tender_sub_item'] ?? '', // was tenderSubItem
          'mainItem': main['tender_item'],
          'boq_main_item_id': main['id'],
          'boq_sub_item_id': sub['id'],
          'soNo': value['lr_no'] ?? '', // was prNo
          'prType': 1, // keep your default
          'unit': sub['unit_of_measure'] ?? '',
          'preferredMake': '-',
          'contractor': contractor?['contractor_name'] ?? '',
          'preferredContractorId': contractor?['id'] ?? '',
          'contractorType': '',
          'lrQty': (labour['lr_qty'] as num?)?.toDouble() ?? 0.0,
          'remainingLrQty': (labour['remaining_qty'] as num?)?.toDouble() ?? 0.0,
          'soQty': 0.0,
          'soRate': '0',
          'gst': null,
          'gstType': null,
          'total': 0.0,
          'remark': labour['remarks'] ?? '-',
          'selected': false,
          'projectId': value['project_id']?.toString() ?? '',
          'contractorTypes': <dynamic>[],
          'contractors': <dynamic>[],
          'availableContractors': contractors,
          'cashDiscount': 0.0,
          'specialDiscount': 0.0,
          'errors': <String, String?>{},
        };
      }).toList();

      controllers = apiItems.map((item) {
        return {
          'soRate': TextEditingController(text: item['soRate'].toString()),
          'soQty': TextEditingController(text: item['soQty'].toString()),
          'cashDiscount': TextEditingController(text: item['cashDiscount'].toString()),
          'specialDiscount': TextEditingController(text: item['specialDiscount'].toString()),
        };
      }).toList();

      setState(() {
        items = apiItems;
        filteredItems = List.from(items);
      });
    } on UnauthorizedException catch (_) {
      await SessionManager().handleSessionExpiration(context);
    } catch (e) {
      _showError("$e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    userProvider.removeListener(checkAndSetPermission);
    searchController.dispose();
    for (var ctrlMap in controllers) {
      ctrlMap['soRate']!.dispose();
      ctrlMap['soQty']!.dispose();
      ctrlMap['cashDiscount']!.dispose();
      ctrlMap['specialDiscount']!.dispose();
    }
    super.dispose();
  }

  void _filterItems() {
    String search = searchController.text.toLowerCase();
    setState(() {
      filteredItems = items.where((item) {
        bool matchSearch = item.values.any((v) => v.toString().toLowerCase().contains(search));
        bool matchProject = false;
        if (widget.project == null) {
          matchProject = _selectedProjects.isEmpty || _selectedProjects.any((p) => p.id.toString() == item['projectId']);
        } else {
          matchProject = true;
        }
        return matchSearch && matchProject;
      }).toList();
    });
  }

  void _updateTotal(int filteredIdx) {
    var item = filteredItems[filteredIdx];
    double qty = item['soQty'];
    double rate = double.tryParse(item['soRate'].toString().replaceAll(',', '')) ?? 0;
    double specialDisc = (double.tryParse(item['specialDiscount'].toString()) ?? 0) / 100;
    double amount = qty * rate;
    double taxAmount = amount + (amount * ((item['gst'] as GstModel?)?.rate ?? 0) / 100);
    double total = taxAmount - (taxAmount * specialDisc);
    item['total'] = total;
    setState(() {});
  }

  bool? get _headerValue {
    if (items.isEmpty) return false;
    final all = items.every((e) => e['selected'] && e['remainingLrQty'] > 0);
    final none = items.every((e) => !e['selected'] || e['remainingLrQty'] <= 0);
    if (all) return true;
    if (none) return false;
    return null;
  }

  bool get _anySelected {
    return items.any((e) => e['selected'] && e['remainingLrQty'] >= 0);
  }

  Future<void> onAddContractors(BuildContext context, String contractor) async {
    try {
      await showDialog(
        context: context,
        builder: (context) => ContractorDialog(
          mode: ContractorDialogMode.create,
          provider: Provider.of<ContractorViewModel>(this.context, listen: false),
          permissions: currentPermissions,
          isSuperAdmin: isSuperAdmin,
          name: contractor,
        ),
      );

      contractors = await ContractorApiService().fetchContractors();

      setState(() {});
    } on UnauthorizedException catch (_) {
      if (mounted) {
        await SessionManager().handleSessionExpiration(context);
      }
    } catch (e) {
      Toast.display(
        type: ToastificationType.error,
        title: "$e",
      );
    } finally {
      CustomLoader.hide();
    }
  }

  Future<void> onAddContractorType(BuildContext context, String contractorspecialty) async {
    try {
      await showDialog(
        context: context,
        builder: (context) => const ContractorTypeDialog(
          mode: ContractorTypeDialogMode.create,
        ),
      );

      contractorTypes = await ContractorApiService().fetchContractorTypes();

      setState(() {});
    } on UnauthorizedException catch (_) {
      if (mounted) {
        await SessionManager().handleSessionExpiration(context);
      }
    } catch (e) {
      Toast.display(
        type: ToastificationType.error,
        title: "$e",
      );
    } finally {
      CustomLoader.hide();
    }
  }

  // Future<void> onRequestQuotationClick() async {
  //   bool hasError = false;
  //   for (var item in items.where((e) => e['selected'] && e['remainingLrQty'] >= 0)) {
  //     item['errors'] = {};
  //     final contractorsSelected = (item['contractors'] ?? []) as List;
  //     if (contractorsSelected.isEmpty) {
  //       item['errors']['contractors'] = "Select at least one contractor";
  //       hasError = true;
  //     }
  //     final soQty = item['soQty'] ?? 0.0;
  //     if (soQty <= 0) {
  //       item['errors']['soQty'] = "SO Qty must be > 0";
  //       hasError = true;
  //     }
  //   }
  //   setState(() {});
  //   if (hasError) {
  //     _showError("Please fix the highlighted errors.");
  //     return;
  //   }

  //   try {
  //     setState(() {
  //       _isLoading = true;
  //     });
  //     final requestBody = {
  //       'items': items
  //           .where((e) => e['selected'] && e['remainingLrQty'] >= 0)
  //           .map((item) => {
  //                 'lr_item_id': item['lrItemId'],
  //                 'quantity': item['soQty'],
  //                 'contractor_ids': (item['contractors'] as List).map((contractor) => (contractor as ContractorModel).id).toList(),
  //               })
  //           .toList(),
  //     };

  //     final response = await PoApiService().requestQuotationPO(body: requestBody);
  //     _showSuccess(response['message'] ?? "Request Quotation created successfully!");

  //     await fetchData();
  //   } on UnauthorizedException catch (_) {
  //     await SessionManager().handleSessionExpiration(context);
  //   } catch (e) {
  //     _showError("Failed to create quotation: $e");
  //   } finally {
  //     setState(() {
  //       _isLoading = false;
  //     });
  //   }
  // }

  Future<void> onRaiseSOClick() async {
    bool hasError = false;
    Set<String> contractorIds = {};
    Set<String> projectIds = {};
    Set<int?> gstTypes = {};
    ContractorModel? contractor;

    int invalidItemCount = 0;
    for (var item in items.where((e) => e['selected'] && e['remainingLrQty'] > 0)) {
      item['errors'] = {};
      final contractorsSelected = (item['contractors'] ?? []) as List;
      if (contractorsSelected.isEmpty) {
        item['errors']['contractors'] = "Contractor is required";
        hasError = true;
      } else if (contractorsSelected.length > 1) {
        item['errors']['contractors'] = "Only 1 contractor is allowed";
        hasError = true;
      } else {
        contractor = contractorsSelected.first as ContractorModel?;
        if (contractor != null) contractorIds.add(contractor.id.toString());
      }

      // Project validation
      final projectId = item['projectId'];
      if (projectId == null) {
        item['errors']['project'] = "Project is required";
        hasError = true;
      } else {
        projectIds.add(projectId);
      }

      // SO Rate validation
      final soRate = double.tryParse(item['soRate'].toString().replaceAll(',', '')) ?? 0;
      if (soRate <= 0) {
        item['errors']['soRate'] = "SO Rate must be > 0";
        hasError = true;
      }

      final soQty = (item['soQty'] ?? 0.0) as num;
      if (soQty <= 0) {
        item['errors']['soQty'] = "SO Qty must be > 0";
        hasError = true;
      }

      final discount = (item['specialDiscount'] ?? 0.0) as num;
      if (discount < 0) {
        item['errors']['specialDiscount'] = "Discount must be >= 0";
        hasError = true;
      }

      if (discount >= 100) {
        item['errors']['specialDiscount'] = "Discount must be < 100";
        hasError = true;
      }

      final remainingQty = double.tryParse(item['remainingLrQty'].toString()) ?? 0;
      if (soQty > remainingQty) {
        invalidItemCount++;
      }

      gstTypes.add(item['gstType']);
    }

    setState(() {}); // refresh UI with error states

    if (projectIds.length > 1) {
      _showError("All items must belong to the same project.");
      return;
    }

    if (contractorIds.length > 1) {
      _showError("All items must have the same contractor.");
      return;
    }

    if (gstTypes.contains(1) && gstTypes.contains(2)) {
      _showError("All items must have same type of GST.");
      return;
    }

    if (hasError) {
      _showError("Please fix the highlighted errors.");
      return;
    }

    final bool? proceed = invalidItemCount > 0
        ? await ConfirmationDialog.show(
            context: context,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'SO Quantity Exceeding',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'SO Quantity is exceeding remaining LR Quantity for $invalidItemCount ${invalidItemCount > 1 ? "items" : "item"}. Are you sure you want to continue?',
                  textAlign: TextAlign.left,
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ],
            ),
            onConfirm: () {},
            confirmText: 'Confirm',
            cancelText: 'Cancel',
            confirmButtonColor: Colors.red,
            cancelButtonColor: Colors.white,
            confirmButtonTextColor: Colors.white,
            cancelButtonTextColor: Colors.black,
          )
        : true;

    if (proceed != true) {
      return;
    }

    // Open Preview Dialog (re-using the original PO preview widget but passing SO data)
    _openSOPreviewDialog(context, items.where((e) => e['selected']).toList(), contractor!, projectIds.first);
  }

  void _showError(String message) {
    Toast.display(
      title: message,
      type: ToastificationType.error,
    );
  }

  void _showSuccess(String message) {
    Toast.display(
      title: message,
      type: ToastificationType.success,
    );
  }

  Widget _buildHeader(BuildContext context) {
    if (widget.project == null) {
      return Row(
        // General "Create SO" header
        children: [
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: SearchField(
                      controller: searchController,
                      hint: "Search...",
                      onChanged: (v) => _filterItems(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: SizedBox(
                      height: 44,
                      child: FlatDropdownDialog<po.ProjectMini>(
                        items: _allProjects,
                        selectedValues: _selectedProjects,
                        onChanged: (selected) {
                          setState(() {
                            _selectedProjects = selected;
                            _filterItems();
                          });
                        },
                        hintText: "All Projects",
                        itemLabelBuilder: (project) => project.projectName,
                        dialogTitle: "Select Projects",
                        isSingleSelection: false,
                        canClear: true,
                        type: "Projects",
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 90),
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedProjects = [];
                            searchController.clear();
                            _filterItems();
                          });
                        },
                        style: AppButtonStyles.primaryButtonStyle(
                          borderRadius: 10,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          overrideBorderRadius: true,
                        ),
                        child: Text(
                          "Clear",
                          style: AppButtonStyles.primaryButtonTextStyle.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // if (canRequestQuotation) ...[
                //   Flexible(
                //     flex: 16,
                //     child: ConstrainedBox(
                //       constraints: const BoxConstraints(maxWidth: 200, minHeight: 44),
                //       child: ElevatedButton(
                //         onPressed: _anySelected ? onRequestQuotationClick : null,
                //         style: AppButtonStyles.primaryButtonStyle(
                //           borderRadius: 8,
                //           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                //         ),
                //         child: Text(
                //           "Request Quotation",
                //           style: AppButtonStyles.primaryButtonTextStyle.copyWith(
                //             fontWeight: FontWeight.w600,
                //             fontSize: 14,
                //             height: 1.6,
                //           ),
                //         ),
                //       ),
                //     ),
                //   ),
                //   const SizedBox(width: 8),
                // ],
                if (canRaiseSO)
                  Flexible(
                    flex: 10,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200, minHeight: 44),
                      child: ElevatedButton(
                        onPressed: _anySelected ? onRaiseSOClick : null,
                        style: AppButtonStyles.primaryButtonStyle(
                          borderRadius: 8,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        child: Text(
                          "Raise SO",
                          style: AppButtonStyles.primaryButtonTextStyle.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }
    // Project-specific "Create SO" header
    return Row(
      children: [
        Expanded(
          flex: 20,
          child: Row(
            children: [
              Flexible(
                flex: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: SearchField(
                    controller: searchController,
                    hint: "Search...",
                    onChanged: (v) => _filterItems(),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 25,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _project?.projectName ?? '',
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.bold.copyWith(
                  fontSize: 29.03,
                  height: 1.6,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Service Order No: ${_project?.workOrderNo ?? ''}',
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.medium.copyWith(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Client: ${_project?.clientName ?? ''}',
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.bold.copyWith(
                  fontSize: 19.54,
                  height: 1.6,
                  color: ColorConstants.customAvatarBackground,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // if (canRequestQuotation) ...[
              //   Flexible(
              //     flex: 16,
              //     child: ConstrainedBox(
              //       constraints: const BoxConstraints(maxWidth: 200, minHeight: 44),
              //       child: ElevatedButton(
              //         onPressed: _anySelected ? onRequestQuotationClick : null,
              //         style: AppButtonStyles.primaryButtonStyle(
              //           borderRadius: 8,
              //           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              //         ),
              //         child: Text(
              //           "Request Quotation",
              //           style: AppButtonStyles.primaryButtonTextStyle.copyWith(
              //             fontWeight: FontWeight.w600,
              //             fontSize: 14,
              //             height: 1.6,
              //           ),
              //         ),
              //       ),
              //     ),
              //   ),
              //   const SizedBox(width: 8),
              // ],
              if (canRaiseSO)
                Flexible(
                  flex: 10,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150, minHeight: 44),
                    child: ElevatedButton(
                      onPressed: _anySelected ? onRaiseSOClick : null,
                      style: AppButtonStyles.primaryButtonStyle(
                        borderRadius: 8,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      child: Text(
                        "Raise SO",
                        style: AppButtonStyles.primaryButtonTextStyle.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Create Service Order'),
      //   centerTitle: true,
      // ),
      backgroundColor: ColorConstants.pageBackground,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: EdgeInsets.fromLTRB(16, isMobile ? 10 : 16, 16, 16),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildHeader(context),
                  const SizedBox(height: 8),
                  const Divider(height: 1, thickness: 1),
                  filteredItems.isEmpty
                      ? Expanded(
                          child: Center(
                            child: Lottie.asset(
                              getAnimationPath('no_data_available.json'),
                            ),
                          ),
                        )
                      : Expanded(child: LayoutBuilder(builder: (context, constraints) {
                          return _buildResponsiveTable(context, constraints);
                        })),
                ],
              ),
            ),
    );
  }

  Widget _buildResponsiveTable(BuildContext context, BoxConstraints constraints) {
    final double totalBaseWidth = _headerConfig.fold(0.0, (sum, config) => sum + (config['width'] as double));
    final double scaleFactor = totalBaseWidth < constraints.maxWidth ? constraints.maxWidth / totalBaseWidth : 1;
    final double tableWidth = totalBaseWidth * scaleFactor;

    return Scrollbar(
      controller: _hCtrl,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _hCtrl,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: tableWidth,
          child: Column(
            children: [
              _buildTableHeader(context, scaleFactor),
              _buildTableBody(context, scaleFactor),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _headerConfig {
    const double wCheckbox = 60.0;
    const double wSrNo = 50.0;
    const double wProjectName = 200.0;
    const double wMainItem = 200.0; // was tenderSubItem
    const double wSubItem = 200.0; // was tenderSubItem
    const double wSoNo = 250.0; // was prNo
    const double wUnit = 80.0;
    const double wContractor = 180.0; // was contractor
    const double wSoRate = 150.0; // was poRate
    const double wLrQty = 100.0; // was prQty
    const double wRemainingLrQty = 150.0; // was remainingPrQty
    const double wSoQty = 150.0;
    const double wCGST = 100.0;
    const double wSGST = 100.0;
    const double wIGST = 100.0; // was poQty
    const double wTotal = 150.0;
    const double wRemark = 200.0;

    return [
      {'width': wCheckbox, 'title': '#', 'isCheckbox': true},
      {'width': wSrNo, 'title': '#', 'center': true},
      if (widget.project == null) {'width': wProjectName, 'title': 'Project Name'},
      {'width': wMainItem, 'title': 'Tender Main Item'},
      {'width': wSubItem, 'title': 'Tender Sub Item'},
      {'width': wUnit, 'title': 'Unit', 'center': true},
      {'width': wSoNo, 'title': 'LR No.', 'center': true},
      {'width': wContractor, 'title': 'Preferred Contractor', 'center': true, 'padding': const EdgeInsets.symmetric(horizontal: 4, vertical: 8)},
      {'width': wContractor, 'title': 'Contractor', 'center': true, 'padding': const EdgeInsets.symmetric(horizontal: 4, vertical: 8)},
      {'width': wSoRate, 'title': 'SO Rate', 'center': true},
      {'width': wLrQty, 'title': 'LR Qty', 'center': true},
      {'width': wRemainingLrQty, 'title': 'Remaining LR Qty', 'center': true},
      {'width': wSoQty, 'title': 'SO Qty', 'center': true},
      {'width': wCGST, 'title': 'CGST', 'center': true},
      {'width': wSGST, 'title': 'SGST', 'center': true},
      {'width': wIGST, 'title': 'IGST', 'center': true},
      {'width': wTotal, 'title': 'Total', 'center': true},
      {'width': wRemark, 'title': 'Remark', 'center': true},
    ];
  }

  Widget _buildTableHeader(BuildContext context, double scaleFactor) {
    const headerBg = Color(0xFFF5F5F5);
    const borderColor = Color(0xFFcbc5d1);

    Widget headerCell(String title, {bool center = false, EdgeInsetsGeometry? padding}) {
      return Container(
        alignment: center ? Alignment.center : Alignment.centerLeft,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          title,
          textAlign: center ? TextAlign.center : TextAlign.left,
          style: AppTextStyle.semiBold.copyWith(
            color: const Color(0xFF17264F),
            fontSize: 16,
          ),
        ),
      );
    }

    return DataTable(
      headingRowHeight: 56,
      dataRowHeight: 0,
      horizontalMargin: 0,
      columnSpacing: 0,
      headingRowColor: MaterialStateProperty.all(headerBg),
      border: const TableBorder(
        top: BorderSide(width: 1, color: borderColor),
        left: BorderSide(width: 1, color: borderColor),
        right: BorderSide(width: 1, color: borderColor),
        bottom: BorderSide(width: 1, color: borderColor),
        verticalInside: BorderSide(width: 1, color: borderColor),
      ),
      columns: _headerConfig.map((config) {
        final width = (config['width'] as double) * scaleFactor;
        if (config['isCheckbox'] == true) {
          return DataColumn(
            label: SizedBox(
              width: width,
              child: checkboxCell(
                context: context,
                value: _headerValue,
                tristate: true,
                onChanged: (v) {
                  setState(() {
                    for (var e in items) {
                      if (e['remainingLrQty'] > 0) {
                        e['selected'] = v ?? false;
                        e['errors'] = <String, String?>{};
                      }
                    }
                  });
                },
                readOnly: false,
              ),
            ),
          );
        }
        return DataColumn(
          label: SizedBox(width: width, child: headerCell(config['title'] as String, center: config['center'] ?? false, padding: config['padding'] as EdgeInsets?)),
        );
      }).toList(),
      rows: const [],
    );
  }

  Widget _buildTableBody(BuildContext context, double scaleFactor) {
    const borderColor = Color(0xFFcbc5d1);
    const altRowColor = Color(0xFFF0F4FF);

    return Expanded(
      child: ScrollbarTheme(
        data: ScrollbarThemeData(
          thumbColor: MaterialStateProperty.all(Colors.grey.shade700),
          trackColor: MaterialStateProperty.all(Colors.grey.shade400),
          trackBorderColor: MaterialStateProperty.all(Colors.grey.shade600),
        ),
        child: Scrollbar(
          controller: _vCtrl,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _vCtrl,
            scrollDirection: Axis.vertical,
            child: DataTable(
              border: const TableBorder(
                top: BorderSide(width: 1, color: borderColor),
                left: BorderSide(width: 1, color: borderColor),
                right: BorderSide(width: 1, color: borderColor),
                bottom: BorderSide(width: 1, color: borderColor),
                verticalInside: BorderSide(width: 1, color: borderColor),
              ),
              headingRowHeight: 0,
              horizontalMargin: 0,
              columnSpacing: 0,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 70,
              columns: _headerConfig.map((config) {
                return DataColumn(label: SizedBox(width: (config['width'] as double) * scaleFactor));
              }).toList(),
              rows: filteredItems.asMap().entries.map((entry) {
                final filteredIdx = entry.key;
                final item = entry.value;
                final originalIdx = items.indexOf(item);
                bool hasError = (item['errors'] as Map<dynamic, dynamic>).isNotEmpty;
                final isDisabled = item['remainingLrQty'] <= 0;
                final message = isDisabled ? "SO is already created for this LR item" : null;
                final bgColor = filteredIdx.isEven ? Colors.white : altRowColor;
                int index = 1;

                return DataRow(
                  color: MaterialStateProperty.all(isDisabled ? Colors.grey[300] : (hasError ? const Color(0xFFFFEFC2) : bgColor)),
                  cells: [
                    DataCell(
                      // Checkbox
                      SizedBox(
                        width: (_headerConfig.firstWhere((c) => c['isCheckbox'] == true, orElse: () => {'width': 60.0})['width'] as double) * scaleFactor,
                        child: checkboxCell(
                          isDisabled: isDisabled,
                          message: message,
                          context: context,
                          value: item['selected'],
                          tristate: false,
                          onChanged: isDisabled
                              ? null
                              : (v) => setState(() {
                                    item['selected'] = v;
                                    item['errors'] = {};
                                  }),
                          readOnly: isDisabled,
                          hasError: hasError,
                        ),
                      ),
                    ),
                    DataCell(
                      // SrNo
                      buildCellWidget(
                        isDisabled: isDisabled,
                        message: message,
                        context: context,
                        width: (_headerConfig[index++]['width'] as double) * scaleFactor,
                        mainContent: Text(
                          item['srNo'].toString(),
                          textAlign: TextAlign.center,
                        ),
                        hasError: hasError,
                      ),
                    ),
                    if (widget.project == null)
                      DataCell(
                        // Project Name
                        buildCellWidget(
                          isDisabled: isDisabled,
                          message: message,
                          context: context,
                          width: (_headerConfig[index++]['width'] as double) * scaleFactor,
                          mainContent: Text(item['projectName']),
                          hasError: hasError,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          centerContent: false,
                        ),
                      ),
                    DataCell(
                      buildCellWidget(
                        // Item
                        isDisabled: isDisabled,
                        message: message,
                        context: context,
                        width: (_headerConfig[index++]['width'] as double) * scaleFactor,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainContent: Tooltip(
                          message: item['mainItem'],
                          child: Text(
                            item['mainItem'],
                            textAlign: TextAlign.left,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        hasError: hasError,
                        centerContent: false,
                      ),
                    ),
                    DataCell(
                      buildCellWidget(
                        // Item
                        isDisabled: isDisabled,
                        message: message,
                        context: context,
                        width: (_headerConfig[index++]['width'] as double) * scaleFactor,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainContent: Tooltip(
                          message: item['item'],
                          child: Text(
                            item['item'],
                            textAlign: TextAlign.left,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        hasError: hasError,
                        centerContent: false,
                      ),
                    ),
                    DataCell(
                      buildCellWidget(
                        // Unit
                        isDisabled: isDisabled,
                        message: message,
                        context: context,
                        width: (_headerConfig[index++]['width'] as double) * scaleFactor,
                        mainContent: Text(
                          item['unit'],
                          textAlign: TextAlign.center,
                        ),
                        hasError: hasError,
                      ),
                    ),
                    DataCell(
                      buildCellWidget(
                        // SO No.
                        isDisabled: isDisabled,
                        message: message,
                        context: context,
                        width: (_headerConfig[index++]['width'] as double) * scaleFactor,
                        mainContent: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (item['prType'] == 2)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 4.0),
                                child: NonClaimableChip(),
                              ),
                            Text(item['soNo'], textAlign: TextAlign.center),
                          ],
                        ),
                        hasError: hasError,
                      ),
                    ),
                    DataCell(
                      buildCellWidget(
                        // Item
                        isDisabled: isDisabled,
                        message: message,
                        context: context,
                        width: (_headerConfig[index++]['width'] as double) * scaleFactor,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainContent: Tooltip(
                          message: item['contractor'],
                          child: Text(
                            item['contractor'],
                            textAlign: TextAlign.left,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        hasError: hasError,
                        centerContent: false,
                      ),
                    ),
                    DataCell(
                      buildCellWidget(
                        // Contractor
                        isDisabled: isDisabled,
                        message: message,
                        context: context,
                        width: (_headerConfig[index++]['width'] as double) * scaleFactor,
                        mainContent: ConstrainedBox(
                          constraints: const BoxConstraints.tightFor(height: 40),
                          child: FlatDropdownDialog<ContractorModel>(
                            readOnly: !item['selected'] || isDisabled,
                            items: (item['availableContractors'] ?? contractors).cast<ContractorModel>(),
                            selectedValues: (item['contractors'] ?? []).cast<ContractorModel>(),
                            onChanged: (selectedContractors) {
                              setState(() {
                                item['contractors'] = selectedContractors;
                                item['errors'].remove('contractors');
                              });
                            },
                            hintText: "Contractors",
                            itemLabelBuilder: (v) => "${v.name} (${v.entities})",
                            dialogTitle: "Select Contractors",
                            isSingleSelection: true,
                            canClear: true,
                            type: "Contractors",
                            fontSize: 14,
                            iconSize: 16,
                          ),
                        ),
                        errorText: item['errors']?['contractors'],
                        hasError: hasError,
                      ),
                    ),
                    DataCell(
                      buildCellWidget(
                        // SO Rate
                        isDisabled: isDisabled,
                        message: message,
                        context: context,
                        width: (_headerConfig[index++]['width'] as double) * scaleFactor,
                        mainContent: _buildTextFieldCell(
                          controller: controllers[originalIdx]['soRate']!,
                          onChanged: (val) {
                            item['soRate'] = val;
                            _updateTotal(filteredIdx);
                          },
                          readOnly: !item['selected'] || isDisabled,
                          inputFormatters: [
                            IndianGroupingInputFormatter(),
                          ],
                        ),
                        errorText: item['errors']['soRate'],
                        hasError: hasError,
                      ),
                    ),
                    DataCell(
                      buildCellWidget(
                        // LR Qty
                        isDisabled: isDisabled,
                        message: message,
                        context: context,
                        width: (_headerConfig[index++]['width'] as double) * scaleFactor,
                        mainContent: Text((item['lrQty'] as double).toStringAsFixed(2), textAlign: TextAlign.center),
                        hasError: hasError,
                      ),
                    ),
                    DataCell(
                      buildCellWidget(
                        // Remaining LR Qty
                        isDisabled: isDisabled,
                        message: message,
                        context: context,
                        width: (_headerConfig[index++]['width'] as double) * scaleFactor,
                        mainContent: Text((item['remainingLrQty'] as double).toStringAsFixed(2), textAlign: TextAlign.center),
                        hasError: hasError,
                      ),
                    ),
                    DataCell(
                      buildCellWidget(
                        // SO Qty
                        isDisabled: isDisabled,
                        message: message,
                        context: context,
                        width: (_headerConfig[index++]['width'] as double) * scaleFactor,
                        mainContent: _buildTextFieldCell(
                          controller: controllers[originalIdx]['soQty']!,
                          onChanged: (val) {
                            item['soQty'] = double.tryParse(val ?? '') ?? 0.0;
                            _updateTotal(filteredIdx);
                            item['errors'].remove('soQty');
                          },
                          readOnly: !item['selected'] || isDisabled,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
                          ],
                        ),
                        errorText: item['errors']?['soQty'],
                        hasError: hasError,
                      ),
                    ),
                    DataCell(
                      buildCellWidget(
                        // CGST
                        isDisabled: isDisabled,
                        message: message,
                        context: context,
                        width: (_headerConfig[index++]['width'] as double) * scaleFactor,
                        mainContent: ConstrainedBox(
                          constraints: const BoxConstraints.tightFor(height: 40),
                          child: FlatDropdown2<GstModel>(
                            readOnly: !item['selected'] || isDisabled,
                            items: taxRates,
                            selectedValue: item['gstType'] == 1 ? item['gst'] : null,
                            onChanged: (v) {
                              setState(() {
                                item['gst'] = v;
                                item['gstType'] = 1;
                              });
                              _updateTotal(filteredIdx);
                            },
                            hintText: "Select CGST",
                            itemLabelBuilder: (g) => (g.rate / 2).toString(),
                            itemValueBuilder: (g) => g.id == 0 ? "Select CGST" : (g.rate / 2).toString(),
                            overrideBorderRadius: true,
                            fontSize: 14,
                            iconSize: 16,
                          ),
                        ),
                        hasError: hasError,
                      ),
                    ),
                    DataCell(
                      buildCellWidget(
                        // SGST
                        isDisabled: isDisabled,
                        message: message,
                        context: context,
                        width: (_headerConfig[index++]['width'] as double) * scaleFactor,
                        mainContent: ConstrainedBox(
                          constraints: const BoxConstraints.tightFor(height: 40),
                          child: FlatDropdown2<GstModel>(
                            readOnly: !item['selected'] || isDisabled,
                            items: taxRates,
                            selectedValue: item['gstType'] == 1 ? item['gst'] : null,
                            onChanged: (v) {
                              setState(() {
                                item['gst'] = v;
                                item['gstType'] = 1;
                              });
                              _updateTotal(filteredIdx);
                            },
                            hintText: "Select SGST",
                            itemLabelBuilder: (g) => (g.rate / 2).toString(),
                            itemValueBuilder: (g) => g.id == 0 ? "Select SGST" : (g.rate / 2).toString(),
                            overrideBorderRadius: true,
                            fontSize: 14,
                            iconSize: 16,
                          ),
                        ),
                        hasError: hasError,
                      ),
                    ),
                    DataCell(
                      buildCellWidget(
                        // IGST
                        isDisabled: isDisabled,
                        message: message,
                        context: context,
                        width: (_headerConfig[index++]['width'] as double) * scaleFactor,
                        mainContent: ConstrainedBox(
                          constraints: const BoxConstraints.tightFor(height: 40),
                          child: FlatDropdown2<GstModel>(
                            readOnly: !item['selected'] || isDisabled,
                            items: taxRates,
                            selectedValue: item['gstType'] == 2 ? item['gst'] : null,
                            onChanged: (v) {
                              setState(() {
                                item['gst'] = v;
                                item['gstType'] = 2;
                              });
                              _updateTotal(filteredIdx);
                            },
                            hintText: "Select IGST",
                            itemLabelBuilder: (g) => g.rate.toString(),
                            itemValueBuilder: (g) => g.id == 0 ? "Select IGST" : g.rate.toString(),
                            overrideBorderRadius: true,
                            fontSize: 14,
                            iconSize: 16,
                          ),
                        ),
                        hasError: hasError,
                      ),
                    ),
                    DataCell(
                      buildCellWidget(
                        // Total
                        isDisabled: isDisabled,
                        message: message,
                        context: context,
                        width: (_headerConfig[index++]['width'] as double) * scaleFactor,
                        mainContent: Text(FormatHelper.tryFormatNum(item['total']), textAlign: TextAlign.center),
                        hasError: hasError,
                      ),
                    ),
                    DataCell(
                      buildCellWidget(
                        // Remark
                        isDisabled: isDisabled,
                        message: message,
                        context: context,
                        width: (_headerConfig[index++]['width'] as double) * scaleFactor,
                        mainContent: Tooltip(
                          message: item['remark'],
                          child: Text(
                            item['remark'].isEmpty ? '-' : item['remark'],
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        hasError: hasError,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildCellWidget({
    required BuildContext context,
    required double width,
    required Widget mainContent,
    String? errorText,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    TextAlign textAlign = TextAlign.center,
    bool hasError = false,
    bool centerContent = true,
    bool isDisabled = false,
    String? message,
  }) {
    Widget widget = SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: crossAxisAlignment,
          children: [
            mainContent,
            if (errorText != null || hasError)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  errorText ?? '',
                  style: const TextStyle(color: Color(0xFF4E0904), fontSize: 12),
                  textAlign: textAlign,
                ),
              ),
          ],
        ),
      ),
    );

    if (centerContent) {
      widget = Center(child: widget);
    }

    if (message != null) {
      widget = Tooltip(message: message, child: widget);
    }

    return widget;
  }

  Widget _buildTextFieldCell({
    required TextEditingController controller,
    required void Function(String?) onChanged,
    bool readOnly = false,
    List<TextInputFormatter> inputFormatters = const [],
  }) {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints.tightFor(width: 90, height: 40),
        child: TextField(
          controller: controller,
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          style: AppTextStyle.medium.copyWith(
            fontSize: 14,
            height: 1.0,
            color: const Color(0xFF25213B),
          ),
          readOnly: readOnly,
          decoration: InputDecoration(
            isDense: false,
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(width: 0.95, color: Color(0xFFAEAEAE)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(width: 0.95, color: Color(0xFFAEAEAE)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(width: 0.95, color: Color(0xFFAEAEAE)),
            ),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: inputFormatters,
          onChanged: !readOnly ? onChanged : null,
        ),
      ),
    );
  }

  Widget checkboxCell({
    required BuildContext context,
    required bool? value, // <- nullable
    required ValueChanged<bool?>? onChanged,
    bool tristate = false, // <- NEW
    bool readOnly = false,
    bool hasError = false,
    bool isDisabled = false,
    String? message,
  }) {
    final themed = Theme.of(context).copyWith(
      checkboxTheme: Theme.of(context).checkboxTheme.copyWith(
            side: MaterialStateBorderSide.resolveWith(
              (states) => const BorderSide(color: Color(0xFFC0C0C0), width: 1),
            ),
          ),
    );

    final box = Checkbox(
      value: value,
      tristate: tristate,
      onChanged: readOnly ? null : onChanged,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );

    Widget widget = Center(
      child: SizedBox(
        width: 40,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Theme(data: themed, child: box),
            if (hasError)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  '',
                  style: TextStyle(color: Color(0xFF4E0904), fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );

    if (message != null) {
      widget = Tooltip(
        message: message,
        child: widget,
      );
    }

    return widget;
  }

  Future<void> _openSOPreviewDialog(
    BuildContext context,
    List<Map<String, dynamic>> items,
    ContractorModel contractor,
    String projectId,
  ) async {
    final _formKey = GlobalKey<FormState>();

    // ── Controllers (required fields) ─────────────────────────────────────
    final typeWorkCtrl = TextEditingController();
    final durationWorkPctCtrl = TextEditingController();
    final afterCompletionPctCtrl = TextEditingController();
    final retentionPctCtrl = TextEditingController();
    final concernPersonCtrl = TextEditingController();
    final locationCtrl = TextEditingController();

    // ── Dates ─────────────────────────────────────────────────────────────
    DateTime? workStartDate;
    DateTime? proposedCompletionDate;

    // ── 1. Build **API-only** items (exactly what the backend expects) ───
    final apiItems = items.map((item) {
      final qty = item['soQty'] as double? ?? 0.0;
      final rate = double.tryParse(item['soRate'].toString().replaceAll(',', '')) ?? 0.0;
      final gstModel = item['gst'] as GstModel?;
      final gstRate = gstModel?.rate ?? 0.0;
      final specialDisc = double.tryParse(item['specialDiscount'].toString()) ?? 0.0;

      final baseAmount = qty * rate * (1 - specialDisc / 100);
      final taxAmount = baseAmount * (gstRate / 100);
      final totalAmount = baseAmount + taxAmount;

      return {
        'lr_item_id': item['lrItemId'],
        'boq_main_item_id': item['boq_main_item_id'],
        'boq_sub_item_id': item['boq_sub_item_id'],
        'so_qty': qty,
        'so_rate': rate,
        'gst_id': gstModel?.id,
        'gst_type': item['gstType'],
        'total_amount': totalAmount,
        // 'remarks': item['remark'] ?? '-',
        'contractor_id': contractor.id,
        'preferred_contractor_id': item['preferredContractorId'],
      };
    }).toList();

    // ── 2. Build **preview-only** items (adds description, CGST/SGST, etc.) ─
    List<Map<String, dynamic>> _buildPreviewItems() {
      return items.asMap().entries.map((e) {
        final idx = e.key + 1; // 1-based serial number
        final item = e.value;
        final qty = item['soQty'] as double? ?? 0.0;
        final rate = double.tryParse(item['soRate'].toString().replaceAll(',', '')) ?? 0.0;
        final gstModel = item['gst'] as GstModel?;
        final gstRate = gstModel?.rate ?? 0.0;

        final base = qty * rate;
        final tax = base * gstRate / 100;
        final totalAmount = base + tax;

        // Pull UI-only data from the original `items` list (same index)
        final src = items[e.key];

        return {
          // --- API fields (kept for safety) ---
          'lr_item_id': item['lrItemId'],
          'boq_main_item_id': item['boq_main_item_id'],
          'boq_sub_item_id': item['boq_sub_item_id'],
          'so_qty': qty,
          'so_rate': rate,
          'gst_id': gstModel?.id,
          'gst_type': item['gstType'],
          'total_amount': totalAmount,
          'remarks': item['remark'] ?? '-',
          'contractor_id': contractor.id,
          'preferred_contractor_id': contractor.id,
          'slNo': src['slNo']?.toString() ?? '$idx',
          'mainDescription': src['mainItem']?.toString() ?? '',
          'subDescription': src['item']?.toString() ?? '',
          'qty': qty,
          'per': src['unit']?.toString() ?? '',
          'rate': rate,
          'lrNo': item['soNo'],
          'cgst': item['gstType'] == null || item['gstType'] == 1 ? (gstRate / 2).toStringAsFixed(2) : '',
          'sgst': item['gstType'] == null || item['gstType'] == 1 ? (gstRate / 2).toStringAsFixed(2) : '',
          'igst': item['gstType'] == 2 ? gstRate.toStringAsFixed(2) : '',
          'cgstAmount': item['gstType'] == 1 ? (tax / 2) : 0.0,
          'sgstAmount': item['gstType'] == 1 ? (tax / 2) : 0.0,
          'igstAmount': item['gstType'] == 2 ? tax : 0.0,
          'amount': base,
        };
      }).toList();
    }

    // Initial preview list
    var previewItems = _buildPreviewItems();

    final Map<String, dynamic> entry = items.firstWhere((entry) => entry['gst_type'] != null, orElse: () => {});

    final int gstType = entry['gstType'] ?? 1;

    // ── Totals (unchanged) ───────────────────────────────────────────────
    double getSubtotal() => apiItems.fold(0.0, (s, i) => s + (i['so_qty'] * i['so_rate']));

    double getTotalTax() => apiItems.fold(0.0, (sum, i) {
          final base = i['so_qty'] * i['so_rate'];
          final gstId = i['gst_id'] as int?;
          final rate = gstId != null ? taxRates.firstWhere((t) => t.id == gstId, orElse: () => const GstModel(id: 0, rate: 0, createdBy: null, createdAt: null)).rate : 0.0;
          return sum + (base * rate / 100);
        });

    // ── Load project & company ───────────────────────────────────────────
    ProjectModel? project;
    if (_project == null) {
      project = await ProjectApiService().getProjectById(int.parse(projectId));
    } else {
      project = _project;
    }
    final entity = await CompanyApiService().fetchCompanyById(int.parse(project!.rawJson['company_id'].toString()));

    // ── GST type (1 = intra-state, 2 = inter-state) ───────────────────────
    // final int gstType = (project!.stateCode == contractor.stateCode) ? 1 : 2;

    // // ── CGST / SGST / IGST totals for preview ─────────────────────────────
    // double cgstTax = 0, sgstTax = 0, igstTax = 0;
    // for (final i in apiItems) {
    //   final base = i['so_qty'] * i['so_rate'];
    //   final gstRate = (i['gst_id'] != null)
    //       ? taxRates.firstWhere((t) => t.id == i['gst_id']).rate
    //       : 0.0;
    //   if (gstType == 1) {
    //     cgstTax += base * (gstRate / 2) / 100;
    //     sgstTax += base * (gstRate / 2) / 100;
    //   } else {
    //     igstTax += base * gstRate / 100;
    //   }
    // }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isLoading = false;

        // ── Submit (uses **apiItems** only) ───────────────────────────────
        Future<void> submitSO() async {
          if (!_formKey.currentState!.validate()) return;

          if (workStartDate == null || proposedCompletionDate == null) {
            return;
          }

          if (proposedCompletionDate != null && proposedCompletionDate!.isBefore(workStartDate!)) {
            return;
          }

          if (proposedCompletionDate!.isBefore(workStartDate!)) return;

          setState(() => isLoading = true);
          try {
            final requestBody = {
              'project_id': int.parse(projectId),
              'type_work': typeWorkCtrl.text.trim(),
              'duration_work_percentage': double.tryParse(durationWorkPctCtrl.text) ?? 0.0,
              'after_completion_percentage': double.tryParse(afterCompletionPctCtrl.text) ?? 0.0,
              'retention_percentage': double.tryParse(retentionPctCtrl.text) ?? 0.0,
              'concern_person': concernPersonCtrl.text.trim().isEmpty ? null : concernPersonCtrl.text.trim(),
              'location': locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
              'work_start_date': workStartDate?.toIso8601String(),
              'proposed_completion_date': proposedCompletionDate?.toIso8601String(),
              'total_amount_without_tax': getSubtotal(),
              'tax_amount': getTotalTax(),
              'total_amount_with_tax': getSubtotal() + getTotalTax(),
              'so_items': apiItems, // ← ONLY API fields
            };

            final response = await SoApiService().createSO(body: requestBody);
            _showSuccess(response['message'] ?? 'SO created successfully!');

            final url = widget.project == null ? '/service-orders' : '/projects/service-order/${widget.project}';
            globalNavigatorKey.currentContext?.pop();
            globalNavigatorKey.currentContext?.go(url);
          } on UnauthorizedException catch (_) {
            await SessionManager().handleSessionExpiration(context);
          } catch (e) {
            _showError("Failed to create SO: $e");
          } finally {
            setState(() => isLoading = false);
          }
        }

        // ── Dialog UI ─────────────────────────────────────────────────────
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            // Rebuild preview whenever any form field changes
            void rebuild() {
              previewItems = _buildPreviewItems(); // refresh UI-only fields
              setDialogState(() {});
            }

            // Listen to every controller
            typeWorkCtrl.addListener(rebuild);
            concernPersonCtrl.addListener(rebuild);
            locationCtrl.addListener(rebuild);
            durationWorkPctCtrl.addListener(rebuild);
            afterCompletionPctCtrl.addListener(rebuild);
            retentionPctCtrl.addListener(rebuild);

            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: Stack(
                children: [
                  Container(
                    width: MediaQuery.of(context).size.width * 0.95,
                    height: MediaQuery.of(context).size.height * 0.9,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        // ────── LEFT – FORM ─────────────────────────────────────
                        Container(
                          width: 350,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8),
                              bottomLeft: Radius.circular(8),
                            ),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(20),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // ----- Keep all your existing _build* calls -----
                                        _buildInputField(
                                          controller: typeWorkCtrl,
                                          label: "Type of Work",
                                          hint: "e.g., Civil, Electrical, Plumbing",
                                          validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                                          isRequired: true,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildInputField(
                                          controller: concernPersonCtrl,
                                          label: "Concern Person",
                                          hint: "Name of contact person",
                                          validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                                          isRequired: true,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildInputField(
                                          controller: locationCtrl,
                                          label: "Location",
                                          hint: "Site / Work location",
                                          validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                                          isRequired: true,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildDateField(
                                          label: "Work Start Date",
                                          selectedDate: workStartDate,
                                          onDateSelected: (date) {
                                            setDialogState(() {
                                              workStartDate = date;
                                              if (proposedCompletionDate != null && proposedCompletionDate!.isBefore(date!)) {
                                                proposedCompletionDate = null;
                                              }
                                              rebuild();
                                            });
                                          },
                                          validator: (date) => date == null ? 'Required' : null,
                                          isRequired: true,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildDateField(
                                          label: "Proposed Completion Date",
                                          selectedDate: proposedCompletionDate,
                                          onDateSelected: (date) {
                                            setDialogState(() {
                                              proposedCompletionDate = date;
                                              rebuild();
                                            });
                                          },
                                          validator: (date) {
                                            if (date == null) return 'Required';
                                            if (workStartDate == null) return 'Select Work Start Date first';
                                            if (date.isBefore(workStartDate!)) return 'Must be after Work Start Date';
                                            return null;
                                          },
                                          isRequired: true,
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Icon(Icons.account_balance_wallet, size: 20, color: Colors.green[700]),
                                            const SizedBox(width: 8),
                                            Text("Payment Terms", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        _buildNumericInputField(
                                          controller: durationWorkPctCtrl,
                                          label: "Duration Work (%)",
                                          hint: "0.00",
                                          isRequired: true,
                                          validator: (v) {
                                            if (v == null || v.isEmpty) return 'Required';
                                            final val = double.tryParse(v);
                                            if (val == null) return 'Invalid number';
                                            if (val < 0 || val > 100) return 'Must be 0–100';
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        _buildNumericInputField(
                                          controller: afterCompletionPctCtrl,
                                          label: "After Completion (%)",
                                          hint: "0.00",
                                          isRequired: true,
                                          validator: (v) {
                                            if (v == null || v.isEmpty) return 'Required';
                                            final val = double.tryParse(v);
                                            if (val == null) return 'Invalid number';
                                            if (val < 0 || val > 100) return 'Must be 0–100';
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        _buildNumericInputField(
                                          controller: retentionPctCtrl,
                                          label: "Retention (%)",
                                          hint: "0.00",
                                          isRequired: true,
                                          validator: (v) {
                                            if (v == null || v.isEmpty) return 'Required';
                                            final val = double.tryParse(v);
                                            if (val == null) return 'Invalid number';
                                            if (val < 0 || val > 100) return 'Must be 0–100';
                                            return null;
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // ────── BUTTONS ─────────────────────────────────────
                              Container(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      height: 48,
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.check_circle, size: 18),
                                        label: const Text("Create SO"),
                                        onPressed: isLoading ? null : submitSO,
                                        style: AppButtonStyles.primaryButtonStyle(),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 48,
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.close, size: 18),
                                        label: const Text("Cancel"),
                                        onPressed: isLoading ? null : () => Navigator.of(ctx).pop(),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.grey[700],
                                          side: BorderSide(color: Colors.grey[300]!),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ────── RIGHT – LIVE PREVIEW ─────────────────────────────
                        Expanded(
                          child: SOPreviewWidget(
                            termsAndConditions: '',
                            soNo: '',
                            soDate: '',
                            projectId: project!.id.toString(),
                            concernPerson: concernPersonCtrl.text.trim(),
                            soItems: previewItems,
                            contractor: contractor,
                            project: project!,
                            entity: entity,
                            subtotal: getSubtotal(),
                            totalTax: getTotalTax(),
                            grandTotal: getSubtotal() + getTotalTax(),
                            typeOfWork: typeWorkCtrl.text.trim(),
                            siteLocation: locationCtrl.text.trim(),
                            siteIncharge: concernPersonCtrl.text.trim(),
                            workStartDate: workStartDate != null ? FormatHelper.formatDateIST(workStartDate!.toIso8601String()) : '',
                            proposedCompletionDate: proposedCompletionDate != null ? FormatHelper.formatDateIST(proposedCompletionDate!.toIso8601String()) : '',
                            gstType: gstType,
                            cgstTax: gstType == 1 ? getTotalTax() / 2 : 0,
                            sgstTax: gstType == 1 ? getTotalTax() / 2 : 0,
                            igstTax: gstType == 2 ? getTotalTax() : 0,
                            showPDFPreview: false,
                            durationWorkPct: double.tryParse(durationWorkPctCtrl.text) ?? 0,
                            afterCompletionPct: double.tryParse(afterCompletionPctCtrl.text) ?? 0,
                            retentionPct: double.tryParse(retentionPctCtrl.text) ?? 0,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Loading overlay
                  if (isLoading)
                    Container(
                      color: Colors.black54,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? selectedDate,
    required Function(DateTime?) onDateSelected,
    String? Function(DateTime?)? validator,
    bool isRequired = false,
  }) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: globalNavigatorKey.currentContext!,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime(2100),
        );
        if (date != null) {
          onDateSelected(date);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          label: RichText(text: text)
          ),
          suffixIcon: const Icon(Icons.calendar_today),
          border: const OutlineInputBorder(),
          errorText: validator?.call(selectedDate),
        ),
        child: Text(
          selectedDate == null ? 'Select date' : DateFormat('dd/MM/yyyy').format(selectedDate),
          style: TextStyle(
            color: selectedDate == null ? Colors.grey[600] : null,
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    Function(String)? onChanged,
    String? hint,
    String? Function(String?)? validator,
    int maxLines = 1,
    required bool isRequired,
    List<TextInputFormatter> inputFormatters = const <TextInputFormatter>[],
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            if (isRequired)
              Text(
                ' *',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.red[700],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          validator: validator,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            errorStyle: TextStyle(color: Colors.red[700], fontSize: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF6C6A6A), width: 1.09),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF6C6A6A), width: 1.09),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF6C6A6A), width: 1.09),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.red[700]!, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.red[700]!, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: Colors.white,
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required Widget child,
    required bool isRequired,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            if (isRequired)
              Text(
                ' *',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.red[700],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildNumericInputField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? prefixIcon,
    Function(String)? onChanged,
    String? Function(String?)? validator,
    required bool isRequired,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            if (isRequired)
              Text(
                ' *',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.red[700],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
            IndianGroupingInputFormatter(),
          ],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onChanged,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: Colors.grey[500]) : null,
            errorStyle: TextStyle(color: Colors.red[700], fontSize: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF6C6A6A), width: 1.09),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF6C6A6A), width: 1.09),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF6C6A6A), width: 1.09),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.red[700]!, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.red[700]!, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: Colors.white,
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }
}
