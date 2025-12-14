import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dhipl_flutter/config/app_dependencies.dart';
import 'package:dhipl_flutter/config/assets_path.dart';
import 'package:dhipl_flutter/config/date_utils.dart';
import 'package:dhipl_flutter/config/service_order_constants.dart';
import 'package:dhipl_flutter/data/models/company_model.dart';
import 'package:dhipl_flutter/data/models/contractor_model.dart';
import 'package:dhipl_flutter/data/models/vendor_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:toastification/toastification.dart';
import 'package:universal_html/html.dart' as html;

class SOPreviewWidget extends StatelessWidget {
  final String soNo;
  final String soDate;
  final List<Map<String, dynamic>> soItems;
  final ContractorModel contractor;
  final String projectId;
  final double subtotal;
  final double totalTax;
  final double cgstTax;
  final double sgstTax;
  final double igstTax;
  final double grandTotal;
  final String? workOrderRef;
  final String typeOfWork;
  final String siteLocation;
  final String siteIncharge;
  final String concernPerson;
  final String workStartDate;
  final String proposedCompletionDate;
  final String termsAndConditions;
  final ProjectModel project;
  final CompanyModel entity;
  final bool showPDFPreview;
  final int gstType;
  final double durationWorkPct;
  final double afterCompletionPct;
  final double retentionPct;

  const SOPreviewWidget({
    Key? key,
    required this.soNo,
    required this.soDate,
    required this.soItems,
    required this.contractor,
    required this.projectId,
    required this.subtotal,
    required this.totalTax,
    required this.grandTotal,
    this.workOrderRef,
    required this.typeOfWork,
    required this.siteLocation,
    required this.siteIncharge,
    required this.concernPerson,
    required this.workStartDate,
    required this.proposedCompletionDate,
    required this.termsAndConditions,
    required this.gstType,
    required this.project,
    required this.entity,
    this.showPDFPreview = false,
    required this.cgstTax,
    required this.sgstTax,
    required this.igstTax,
    required this.durationWorkPct,
    required this.afterCompletionPct,
    required this.retentionPct,
  }) : super(key: key);

  List<Map<String, dynamic>> getTerms() {
    final List<Map<String, dynamic>> terms = [
      {"srNo": "", "description": "Scope of Work:", "_section": "", "_isSubheader": true},
      {"srNo": "1", "description": "Work must adhere to the scope detailed in the Work Order.", "_section": "Scope of Work:", "_subheader": null, "_isSubheader": false},
      {"srNo": "", "description": "Inclusive Rates:", "_section": "Scope of Work:", "_isSubheader": true},
      {"srNo": "a", "description": "Housekeeping is the ${contractor.name} responsibility.", "_section": "Scope of Work:", "_subheader": "Inclusive Rates:", "_isSubheader": false},
      {"srNo": "", "description": "Quality and Safety and Environment :", "_section": "", "_isSubheader": true},
      {"srNo": "1", "description": "All work must meet or exceed quality standards set by DHIPL PROJECTS PVT LTD.", "_section": "Quality and Safety and Environment :", "_subheader": null, "_isSubheader": false},
      {"srNo": "2", "description": "PPE and required equipment are the${contractor.name} responsibility on a debitable basis.", "_section": "Quality and Safety and Environment :", "_subheader": null, "_isSubheader": false},
      {"srNo": "3", "description": "Maintaining a harmonious working environment and adhering to safety guidelines is crucial.", "_section": "Quality and Safety and Environment :", "_subheader": null, "_isSubheader": false},
      {"srNo": "4", "description": "No consumption of gutka, tobacco, or cigarettes is allowed on-site.", "_section": "Quality and Safety and Environment :", "_subheader": null, "_isSubheader": false},
      {"srNo": "5", "description": "${contractor.name} must adhere to safety and security rules.", "_section": "Quality and Safety and Environment :", "_subheader": null, "_isSubheader": false},
      {"srNo": "6", "description": "Modern machinery and equipment should be used as required.", "_section": "Quality and Safety and Environment :", "_subheader": null, "_isSubheader": false},
      {"srNo": "7", "description": "${contractor.name} is responsible for handling problems or disputes among workers.", "_section": "Quality and Safety and Environment :", "_subheader": null, "_isSubheader": false},
      {"srNo": "", "description": "Documentation and Compliance:", "_section": "", "_isSubheader": true},
      {"srNo": "1", "description": "Regular housekeeping and cleanliness are expected.", "_section": "Documentation and Compliance:", "_subheader": null, "_isSubheader": false},
      {"srNo": "2", "description": "Equipment and machinery must be calibrated and in good working condition.", "_section": "Documentation and Compliance:", "_subheader": null, "_isSubheader": false},
      {"srNo": "3", "description": "The ${contractor.name} is responsible for understanding and adhering to drawings and documents.", "_section": "Documentation and Compliance:", "_subheader": null, "_isSubheader": false},
      {"srNo": "4", "description": "Compliance with all rules and regulations is mandatory.", "_section": "Documentation and Compliance:", "_subheader": null, "_isSubheader": false},
      {"srNo": "5", "description": "Weekly advances for all labourers (Both Department and contrator) will be deposited into their respective accounts, not into any contractors account.", "_section": "Documentation and Compliance:", "_subheader": null, "_isSubheader": false},
      {"srNo": "6", "description": "The PF component (Employee share, upto Rs. 1800) will be deducted from the salary of all labourers and debited to the respective contractors bill amount.", "_section": "Documentation and Compliance:", "_subheader": null, "_isSubheader": false},
      {"srNo": "", "description": "Termination and Dispute Resolution:", "_section": "", "_isSubheader": true},
      {"srNo": "1", "description": "DHIPL PROJECTS PVT LTD reserves the right to terminate the work order for breaches.", "_section": "Termination and Dispute Resolution:", "_subheader": null, "_isSubheader": false},
      {"srNo": "2", "description": "Disputes should be resolved amicably, with EIC as final authority.", "_section": "Termination and Dispute Resolution:", "_subheader": null, "_isSubheader": false},
      {"srNo": "", "description": "Mode Of Measurement", "_section": "", "_isSubheader": true},
      {"srNo": "1", "description": "The subcontractor's work is measured and verified, and quantities are paid only after approval by a  inspecting authority such as Micron Sanand Ahmedabad . The final approved quantity by Micron Sanand Ahmedabad (client) which will be paid to DHIPL shall be the final quantity for payment of contractor.", "_section": "Mode Of Measurement", "_subheader": null, "_isSubheader": false},
      {"srNo": "", "description": "Payment and Rates:", "_section": "", "_isSubheader": true},
      {"srNo": "1", "description": "${durationWorkPct}% payment against running bill.", "_section": "Payment and Rates:", "_subheader": null, "_isSubheader": false},
      {"srNo": "2", "description": "${afterCompletionPct}% payment will release after completion of work. ${retentionPct}% retention for one year.", "_section": "Payment and Rates:", "_subheader": null, "_isSubheader": false},
      {"srNo": "", "description": "Consumable Materials:", "_section": "", "_isSubheader": true},
      {"srNo": "1", "description": "Compliance with IS Code and/or to the Client Specification:", "_section": "Consumable Materials:", "_subheader": null, "_isSubheader": false},
      {"srNo": "2", "description": "Any shortfall in consumption will result into deduction, with a 25% additional cost to be recovered from ${contractor.name} invoice and any Rework must be done to meet the desired quality standards at the cost & ${contractor.name}.", "_section": "Consumable Materials:", "_subheader": null, "_isSubheader": false},
      {"srNo": "3", "description": "For any loss of free issue material more than the prescribed wastage limits including design wastage, Payment will be deducted @150% of material price at the time of reconciliation.", "_section": "Consumable Materials:", "_subheader": null, "_isSubheader": false},
      {"srNo": "4", "description": "Payment will be made on the 15th of each month based on measurements.", "_section": "Consumable Materials:", "_subheader": null, "_isSubheader": false},
      {"srNo": "5", "description": "Weekly expenses for labor if require will be paid directly into the${contractor.name} bank account.", "_section": "Consumable Materials:", "_subheader": null, "_isSubheader": false},
      {"srNo": "6", "description": "No cash payments will be made on-site.", "_section": "Consumable Materials:", "_subheader": null, "_isSubheader": false},
      {"srNo": "7", "description": "No due certificates for labor must be submitted monthly.", "_section": "Consumable Materials:", "_subheader": null, "_isSubheader": false},
      {"srNo": "8", "description": "Rates include various elements such as traveling, loading, unloading, safety equipment, hand tools, and machinery.", "_section": "Consumable Materials:", "_subheader": null, "_isSubheader": false},
      {"srNo": "", "description": "Miscellaneous:", "_section": "", "_isSubheader": true},
      {"srNo": "1", "description": "Documentation with DHIPL PROJECTS PVT LTD  site engineer signatures is required before claiming payment. No invoice shall excepted without details certified by EIC & required reconcilation of free as well as contractor own materials.", "_section": "Miscellaneous:", "_subheader": null, "_isSubheader": false},
      {"srNo": "2", "description": "Damages to client property will be charged to the ${contractor.name}.", "_section": "Miscellaneous:", "_subheader": null, "_isSubheader": false},
      {"srNo": "3", "description": "Passes issued to labor should be returned upon leaving the site or else missing cards will be charge Rs.100", "_section": "Miscellaneous:", "_subheader": null, "_isSubheader": false},
      {"srNo": "4", "description": "DHIPL shall not provide any accommodation or other for labours.", "_section": "Miscellaneous:", "_subheader": null, "_isSubheader": false},
      {"srNo": "5", "description": "The bill of ${contractor.name} (Contractor) will be paid only when he pays the salary to his employees for the same month and submits the documents and bank account details of the workers to DHIPL.", "_section": "Miscellaneous:", "_subheader": null, "_isSubheader": false},
      {"srNo": "6", "description": "DHIPL PROJECTS PVT LTD has the right to modify the scope of work as needed.", "_section": "Miscellaneous:", "_subheader": null, "_isSubheader": false}
    ];

    return terms;
  }

  Future<void> generateAndPrintPDF(BuildContext context) async {
    final pdf = await _generatePDF(context);
    final bytes = await pdf.save();

    Toast.display(
      title: 'Download Started',
      type: ToastificationType.info,
    );

    if (kIsWeb) {
      final blob = html.Blob([bytes]);
      final objectUrl = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: objectUrl)
        ..setAttribute('download', "DHIPL_SO_$soNo.pdf")
        ..click();
      html.Url.revokeObjectUrl(objectUrl);
      Toast.display(
        title: 'Download Completed',
        type: ToastificationType.success,
      );
    } else {
      final tempDir = await getTemporaryDirectory();
      if (tempDir == null) {
        Toast.display(
          title: 'Could not access temporary directory.',
          type: ToastificationType.error,
        );
        return;
      }
      final savePath = '${tempDir.path}/work-order.pdf';
      final file = File(savePath);
      await file.writeAsBytes(bytes);

      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done) {
        Toast.display(
          title: 'Could not open file: ${result.message}',
          type: ToastificationType.error,
        );
      } else {
        Toast.display(
          title: 'File opened successfully.',
          type: ToastificationType.success,
        );
      }
    }
  }

  Future<pw.Document> _generatePDF(BuildContext context) async {
    final pdf = pw.Document(version: PdfVersion.pdf_1_5, compress: true);
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();
    final logo = await rootBundle.load('assets/images/app_logo.png');
    final logoImage = pw.MemoryImage(logo.buffer.asUint8List());

    // Page 1: Fixed first page with SO details
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(14),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(logoImage, boldFont, font),
              pw.SizedBox(height: 5),
              _buildSODetails(font, boldFont),
              pw.SizedBox(height: 5),
              _buildContractorDetails(boldFont, font),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(4),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.only(
                    bottomLeft: pw.Radius.circular(2),
                    bottomRight: pw.Radius.circular(2),
                  ),
                ),
                child: _buildPdfDetailRow("Type Of Work", typeOfWork.isEmpty ? 'NA' : typeOfWork, font, boldFont),
              ),
              pw.SizedBox(height: 10),
              _buildProjectDetails(font, boldFont),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(4),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.only(
                    bottomLeft: pw.Radius.circular(2),
                    bottomRight: pw.Radius.circular(2),
                  ),
                ),
                child: _buildPdfDetailRow("Project Manager", "${project.rawJson['project_manager_dhipl'][0]['full_name']} - ${project.rawJson['project_manager_dhipl'][0]['contact_no']}", font, boldFont),
              ),
              pw.SizedBox(height: 10),
              _buildWorkEstimate(boldFont, font),
              pw.SizedBox(height: 10),
              _buildFirstPageConditions(font),
              pw.SizedBox(height: 10),
              _buildSignatureSection(boldFont, font),
            ],
          );
        },
      ),
    );

    // Pages 2+: Items table, T&C, and signature
    final columnFlex = [
      5,
      20,
      20,
      10,
      10,
      10,
      if (gstType == 1) 8,
      if (gstType == 1) 8,
      if (gstType == 2) 8,
      15,
    ];

    List<Map<String, dynamic>> processedItems = _processItemsWithWrapping(soItems);
    List<double> itemHeights = _calculateItemHeights(processedItems, font);

// Parse T&C from CSV (inject dynamics) // Adjust path
    List<Map<String, dynamic>> rawTerms = getTerms();

    List<Map<String, dynamic>> processedTerms = _processTermsWithWrapping(rawTerms);
    List<double> termHeights = _calculateTermHeights(processedTerms, font);

// Pagination: items + T&C together
    const double pageHeight = 841.89;
    const double margin = 14.0;
    const double headerHeight = 80.0;
    const double tableHeaderHeight = 15.0;
    // const double footerHeight = 120.0;
    const double availableSpace = pageHeight - (2 * margin) - headerHeight - tableHeaderHeight - 20; // Extra for dividers

// Combine all rows: items first, then terms
    List<Map<String, dynamic>> allRows = [...processedItems, ...processedTerms];
    List<double> allHeights = [...itemHeights, ...termHeights];
    List<bool> isItemRow = List.generate(processedItems.length, (_) => true) + List.generate(processedTerms.length, (_) => false);

    List<List<Map<String, dynamic>>> pagedRows = [];
    List<Map<String, dynamic>> currentPageRows = [];
    double currentHeight = 0;

    for (int i = 0; i < allRows.length; i++) {
      double h = allHeights[i];
      if (currentHeight + h > availableSpace && currentPageRows.isNotEmpty) {
        pagedRows.add(List.from(currentPageRows));
        currentPageRows.clear();
        currentHeight = 0;
      }
      currentPageRows.add(allRows[i]);
      currentHeight += h;
    }
    if (currentPageRows.isNotEmpty) pagedRows.add(currentPageRows);

// Generate pages
    for (int pageIndex = 0; pageIndex < pagedRows.length; pageIndex++) {
      final pageRows = pagedRows[pageIndex];
      final isLastPage = pageIndex == pagedRows.length - 1;
      final List<Map<String, dynamic>> pageItems = pageRows.where((row) => row.containsKey('qty')).toList();

      final List<Map<String, dynamic>> pageTerms = pageRows.where((row) => row.containsKey('description') && !row.containsKey('qty')).toList();

      final bool hasItems = pageItems.isNotEmpty;
      final bool hasTerms = pageTerms.isNotEmpty;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(14),
          build: (pw.Context context) {
            return pw.Column(
              children: [
                _buildHeader(logoImage, boldFont, font),
                pw.SizedBox(height: 10),

                if (pageIndex == 0) ...[
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(4),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                    child: pw.Center(
                      child: pw.Text(
                        "${project.projectName} $siteLocation",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, font: boldFont),
                      ),
                    ),
                  ),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(4),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                    child: _buildPdfDetailRow("Date", soDate.isEmpty ? 'NA' : soDate, font, boldFont, isRight: true),
                  ),
                ],
                // Items Table (if any on this page)
                if (hasItems) _buildItemsTable(pageItems, columnFlex, boldFont, font),
                if (hasTerms && hasItems) ...[
                  ..._buildTotalsRow(boldFont, font),
                  pw.SizedBox(height: 10),
                ],

                // T&C Table (starts right after items; if any on this page)
                if (hasTerms) ...[
                  if (hasItems) ...[
                    // Only add divider if both tables on same page
                    pw.SizedBox(height: 10),
                    pw.Divider(thickness: 0.1, height: 1, color: PdfColors.grey300),
                    pw.SizedBox(height: 10),
                  ],
                  _buildTermsTable(pageTerms, boldFont, font),
                ],
                pw.Spacer(),
                _buildSignatureFooter(boldFont, font),
              ],
            );
          },
        ),
      );
    }

    return pdf;
  }

  List<double> _calculateTermHeights(List<Map<String, dynamic>> items, pw.Font font) {
    const double baseRowHeight = 12.0;
    const double verticalPadding = 2.0;
    const double fontSize = 6.0;
    const double lineHeight = fontSize * 1.3;

    const double tableWidth = 567.28;
    final double totalFlex = 5 + 95;
    final double descWidth = (tableWidth * 95 / totalFlex) - 4;
    const double avgCharWidth = fontSize * 0.55;
    final int charsPerLine = (descWidth / avgCharWidth).floor();

    final List<double> heights = [];
    for (final item in items) {
      final String desc = item['description']?.toString() ?? '';
      final int lines = desc.isEmpty ? 1 : (desc.length / charsPerLine).ceil().clamp(1, 4);
      double h = baseRowHeight;
      if (lines > 1) h = (lineHeight * lines) + verticalPadding * 2;
      h += 2.0;
      heights.add(h);
    }
    return heights;
  }

  List<Map<String, dynamic>> _processTermsWithWrapping(List<Map<String, dynamic>> terms) {
    final List<Map<String, dynamic>> processed = [];
    // Reuse same geometry as before (fontSize 8.0, etc.)
    const double fontSize = 6.0;
    const double tableWidth = 567.28;
    final double totalFlex = 5 + 95;
    final double descWidth = (tableWidth * 95 / totalFlex) - 4;
    const double avgCharWidth = fontSize * 0.55;
    final int maxCharsPerLine = (descWidth / avgCharWidth).floor();
    const int maxLinesPerRow = 4;

    for (final term in terms) {
      if (term['_isSubheader'] == true) {
        // Subheader: special row, no splitting (bold, full width)
        processed.add(Map<String, dynamic>.from(term)..['_isSubheader'] = true);
        continue;
      }

      final String desc = term['description'] ?? '';
      final int linesNeeded = (desc.length / maxCharsPerLine).ceil().clamp(1, maxLinesPerRow);

      // Split desc into chunks (reuse your _splitTextIntoChunks)
      final List<String> chunks = _splitTextIntoChunks(desc, maxCharsPerLine * linesNeeded);
      while (chunks.length < linesNeeded) chunks.add('');

      for (int r = 0; r < linesNeeded; r++) {
        final Map<String, dynamic> newItem = Map<String, dynamic>.from(term);
        newItem['description'] = chunks[r];
        newItem['_isFirstOfGroup'] = r == 0;
        newItem['_isLastOfGroup'] = r == linesNeeded - 1;
        newItem['_isContinuation'] = r > 0;
        if (r > 0) newItem['srNo'] = '';
        processed.add(newItem);
      }
    }
    return processed;
  }

  pw.Widget _buildTermsTable(List<Map<String, dynamic>> terms, pw.Font boldFont, pw.Font font) {
    return pw.Table(
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.full,
      columnWidths: {0: pw.FlexColumnWidth(5), 1: pw.FlexColumnWidth(95)},
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE8EAF6)),
          children: [
            _buildPdfTableHeader('Sr No.', flex: 5, font: boldFont),
            _buildPdfTableHeader('Terms & Conditions', flex: 95, font: boldFont, textAlign: pw.TextAlign.left),
          ],
        ),
        // Rows
        ...terms.map((term) {
          final bool isSubheader = term['_isSubheader'] == true;
          final bool isCont = term['_isContinuation'] == true;
          if (isSubheader) {
            // Subheader: merge cells, bold, no border on cont
            return pw.TableRow(
              children: [
                _buildPdfTableCell('', flex: 5, font: font, isContinuation: isCont, boldFont: boldFont),
                _buildPdfTableCell(
                  term['description'].toString(),
                  flex: 95,
                  font: font,
                  textAlign: pw.TextAlign.left,
                  isDescription: true,
                  isContinuation: isCont,
                  isBold: true,
                  boldFont: boldFont,
                ),
              ],
            );
          }
          return pw.TableRow(
            children: [
              _buildPdfTableCell(term['srNo'].toString(), flex: 5, font: font, isContinuation: isCont, boldFont: boldFont),
              _buildPdfTableCell(
                term['description'].toString(),
                flex: 95,
                font: font,
                textAlign: pw.TextAlign.left,
                isDescription: true,
                isContinuation: isCont,
                boldFont: boldFont,
              ),
            ],
          );
        }),
      ],
    );
  }

  List<Map<String, dynamic>> _processItemsWithWrapping(List<Map<String, dynamic>> items) {
    final List<Map<String, dynamic>> processed = [];

    // ----- table geometry (same as in your original code) --------------------
    const double fontSize = 6.0;
    const double tableWidth = 567.28; // A4 width – 2*margin
    final double totalFlex = gstType == 1 ? 106 : 98;
    final double descriptionColumnWidth = (tableWidth * 20 / totalFlex) - 4; // 20-flex column
    const double avgCharWidth = fontSize * 0.55;
    final int maxCharsPerLine = (descriptionColumnWidth / avgCharWidth).floor();
    const int maxLinesPerRow = 4; // keep the same limit

    for (final item in items) {
      final String main = (item['mainDescription']?.toString() ?? '').trim();
      final String sub = (item['subDescription']?.toString() ?? '').trim();

      // split each column into exactly `rowsNeeded` chunks
      final List<String> mainChunks = _splitTextIntoChunks(main, maxCharsPerLine * maxLinesPerRow);
      final List<String> subChunks = _splitTextIntoChunks(sub, maxCharsPerLine * maxLinesPerRow);

      // // pad the shorter list so both have the same length
      while (mainChunks.length < subChunks.length) mainChunks.add('');
      while (subChunks.length < mainChunks.length) subChunks.add('');

      // -----------------------------------------------------------------------
      // Build one PDF-row per chunk (max 4 rows per original item)
      // -----------------------------------------------------------------------
      for (int r = 0; r < mainChunks.length; r++) {
        final Map<String, dynamic> newItem = Map<String, dynamic>.from(item);

        newItem['mainDescription'] = mainChunks[r];
        newItem['subDescription'] = subChunks[r];

        // flags for borders / continuation
        newItem['_isFirstOfGroup'] = r == 0;
        newItem['_isLastOfGroup'] = r == mainChunks.length - 1;
        newItem['_isContinuation'] = r > 0;

        // blank out the numeric columns on continuation rows
        if (r > 0) {
          newItem['slNo'] = '';
          newItem['qty'] = '';
          newItem['per'] = '';
          newItem['rate'] = '';
          newItem['cgst'] = '';
          newItem['cgstAmount'] = '';
          newItem['sgst'] = '';
          newItem['sgstAmount'] = '';
          newItem['igst'] = '';
          newItem['igstAmount'] = '';
          newItem['amount'] = '';
        }

        processed.add(newItem);
      }
    }

    return processed;
  }

  List<String> _splitTextIntoChunks(String text, int maxCharsPerChunk) {
    List<String> chunks = [];

    while (text.isNotEmpty) {
      if (text.length <= maxCharsPerChunk) {
        chunks.add(text);
        break;
      }

      int breakPoint = maxCharsPerChunk;

      for (int i = maxCharsPerChunk; i > maxCharsPerChunk - 50 && i > 0; i--) {
        if (text[i] == ' ' || text[i] == ',' || text[i] == '-') {
          breakPoint = i + 1;
          break;
        }
      }

      chunks.add(text.substring(0, breakPoint).trim());
      text = text.substring(breakPoint).trim();
    }

    return chunks;
  }

  List<double> _calculateItemHeights(List<Map<String, dynamic>> items, pw.Font font) {
    const double baseRowHeight = 12.0; // single-line height
    const double verticalPadding = 2.0;
    const double fontSize = 6.0;
    const double lineHeight = fontSize * 1.3;

    const double tableWidth = 567.28;
    final double totalFlex = gstType == 1 ? 106 : 98;
    final double descriptionColumnWidth = (tableWidth * 20 / totalFlex) - 4;
    const double avgCharWidth = fontSize * 0.55;
    final int charsPerLine = (descriptionColumnWidth / avgCharWidth).floor();

    final List<double> heights = [];

    for (final item in items) {
      final String main = item['mainDescription']?.toString() ?? '';
      final String sub = item['subDescription']?.toString() ?? '';

      final int mainLines = main.isEmpty ? 1 : (main.length / charsPerLine).ceil();
      final int subLines = sub.isEmpty ? 1 : (sub.length / charsPerLine).ceil();
      final int lines = max(mainLines, subLines).clamp(1, 4);

      double height = baseRowHeight;
      if (lines > 1) {
        height = (lineHeight * lines) + verticalPadding * 2;
      }
      height += 2.0; // tiny extra space (mirrors original code)
      heights.add(height);
    }
    return heights;
  }

  pw.Widget _buildHeader(pw.MemoryImage logoImage, pw.Font boldFont, pw.Font font) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      padding: const pw.EdgeInsets.all(12),
      decoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFF1B365D),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Expanded(flex: 10, child: pw.Image(logoImage, height: 60)),
          pw.Expanded(flex: 15, child: pw.SizedBox()),
          pw.Expanded(
            flex: 20,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  "DHIPL PROJECTS PVT. LTD. (${entity.name})\n${getIndianFinancialYear(poDate: soDate.isEmpty ? null : soDate)}",
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold, font: boldFont),
                  textAlign: pw.TextAlign.right,
                ),
                pw.SizedBox(height: 4),
                pw.Text(entity.address ?? 'NA', style: pw.TextStyle(color: PdfColors.white, fontSize: 7, font: font), textAlign: pw.TextAlign.right),
                pw.Text('GSTIN/UIN : ${entity.gst ?? 'NA'}', style: pw.TextStyle(color: PdfColors.white, fontSize: 7, font: font), textAlign: pw.TextAlign.right),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSODetails(pw.Font font, pw.Font boldFont) {
    return pw.Container(
      width: double.infinity,
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 1,
            child: _buildPdfDetailRowHeader("SO No", workOrderRef ?? soNo, font, boldFont),
          ),
          pw.Expanded(
            flex: 1,
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(
                "SERVICE ORDER",
                style: pw.TextStyle(fontSize: 10, color: PdfColors.black, font: boldFont),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ),
          pw.Expanded(
            flex: 1,
            child: _buildPdfDetailRowHeader("Date", soDate.isEmpty ? 'NA' : FormatHelper.formatDateIST(soDate), font, boldFont, isRight: true),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildProjectDetails(pw.Font font, pw.Font boldFont) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.only(
          topLeft: pw.Radius.circular(2),
          topRight: pw.Radius.circular(2),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.start,
        children: [
          _buildPdfDetailRow('Site', project.projectName, font, boldFont),
          _buildPdfDetailRow('Location', "${siteLocation.isEmpty ? 'NA' : siteLocation}\n${project.siteAddress}", font, boldFont),
          _buildPdfDetailRow('Site Incharge', "${project.rawJson['site_supervisor'][0]['full_name']} - ${project.rawJson['site_supervisor'][0]['contact_no']}", font, boldFont),
          _buildPdfDetailRow('Email', (project.rawJson['site_supervisor'][0]['email']?.isEmpty ?? true) ? 'NA' : project.rawJson['site_supervisor'][0]['email'], font, boldFont),
        ],
      ),
    );
  }

  pw.Widget _buildContractorDetails(pw.Font boldFont, pw.Font font) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.only(
          topLeft: pw.Radius.circular(2),
          topRight: pw.Radius.circular(2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.start,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.start,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("To,\n${contractor.name}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, font: boldFont)),
                pw.SizedBox(height: 2),
                pw.Text(contractor.address, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.normal)),
              ],
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.start,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildPdfDetailRow('LR Ref.', soItems.map((e) => e['lrNo'] ?? '').toSet().join(', '), font, boldFont),
                _buildPdfDetailRow('Concern Person', concernPerson, font, boldFont),
                _buildPdfDetailRow('Mobile', contractor.mobileNo.isEmpty ? 'NA' : contractor.mobileNo, font, boldFont),
                _buildPdfDetailRow('PAN No.', contractor.pan.isEmpty ? 'NA' : contractor.pan, font, boldFont),
                _buildPdfDetailRow('GST No.', contractor.gst == null || contractor.gst!.isEmpty ? 'NA' : contractor.pan, font, boldFont),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildWorkEstimate(pw.Font boldFont, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPdfDetailRow('Work to be start on as', workStartDate.isEmpty ? 'NA' : workStartDate, font, boldFont),
              _buildPdfDetailRow('Proposed Completion Date', proposedCompletionDate.isEmpty ? 'NA' : proposedCompletionDate, font, boldFont),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: pw.SizedBox()),
              pw.Flexible(
                child: pw.Container(
                  constraints: const pw.BoxConstraints(maxWidth: 175),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Center(child: pw.Text('WORK ESTIMATE', style: pw.TextStyle(fontSize: 8, font: boldFont))),
                      pw.Table(
                        border: pw.TableBorder.all(width: 0.1),
                        columnWidths: {
                          0: const pw.FlexColumnWidth(2),
                          1: const pw.FlexColumnWidth(1),
                        },
                        children: [
                          _buildEstimateRow('Total Value of Work', FormatHelper.tryFormatNum(subtotal.toString()), boldFont, isBold: true),
                          if (cgstTax > 0) _buildEstimateRow('Add CGST', FormatHelper.tryFormatNum(cgstTax), font),
                          if (sgstTax > 0) _buildEstimateRow('Add SGST', FormatHelper.tryFormatNum(sgstTax), font),
                          if (igstTax > 0) _buildEstimateRow('Add IGST', FormatHelper.tryFormatNum(igstTax), font),
                          _buildEstimateRow('Grand Total', FormatHelper.tryFormatNum(grandTotal.toString()), boldFont, isBold: true),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.TableRow _buildEstimateRow(String label, String value, pw.Font font, {bool isBold = false}) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(2),
          child: pw.Text(label, style: pw.TextStyle(fontSize: 7, font: font, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(2),
          child: pw.Text(value, style: pw.TextStyle(fontSize: 7, font: font, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal), textAlign: pw.TextAlign.right),
        ),
      ],
    );
  }

  pw.Widget _buildFirstPageConditions(pw.Font font) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.only(
          bottomLeft: pw.Radius.circular(2),
          bottomRight: pw.Radius.circular(2),
        ),
      ),
      child: pw.Text(firstPageCondition, style: pw.TextStyle(fontWeight: pw.FontWeight.normal, fontSize: 7, font: font)),
    );
  }

  pw.Widget _buildItemsTable(List<Map<String, dynamic>> items, List<int> columnFlex, pw.Font boldFont, pw.Font font) {
    final columnWidths = columnFlex.map((flex) => pw.FlexColumnWidth(flex.toDouble())).toList();
    return pw.Column(
      children: [
        pw.Table(
          border: const pw.TableBorder(bottom: pw.BorderSide(width: 0.1)),
          defaultVerticalAlignment: pw.TableCellVerticalAlignment.full,
          columnWidths: columnWidths.asMap(),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE8EAF6)),
              children: [
                _buildPdfTableHeader('Sr No.', flex: 5, font: boldFont),
                _buildPdfTableHeader('Main Item', flex: 20, font: boldFont, textAlign: pw.TextAlign.left),
                _buildPdfTableHeader('Sub Item', flex: 20, font: boldFont, textAlign: pw.TextAlign.left),
                _buildPdfTableHeader('Qty', flex: 10, font: boldFont),
                _buildPdfTableHeader('Per', flex: 10, font: boldFont),
                _buildPdfTableHeader('Rate', flex: 10, font: boldFont),
                if (gstType == 1) _buildPdfTableHeader('CGST', flex: 8, font: boldFont),
                if (gstType == 1) _buildPdfTableHeader('SGST', flex: 8, font: boldFont),
                if (gstType == 2) _buildPdfTableHeader('IGST', flex: 8, font: boldFont),
                _buildPdfTableHeader('Amount', flex: 15, font: boldFont, textAlign: pw.TextAlign.right),
              ],
            ),
            ...items.map((item) {
              bool isContinuation = item['_isContinuation'] == true;
              bool isFirstOfGroup = item['_isFirstOfGroup'] == true;
              bool isLastOfGroup = item['_isLastOfGroup'] == true;

              return pw.TableRow(
                children: [
                  _buildPdfTableCell(item['slNo'].toString(), flex: 5, font: font, isContinuation: isContinuation, isFirstOfGroup: isFirstOfGroup, isLastOfGroup: isLastOfGroup, boldFont: boldFont),
                  _buildPdfTableCell(item['mainDescription'].toString(), flex: 20, font: font, isDescription: true, textAlign: pw.TextAlign.left, isContinuation: isContinuation, isFirstOfGroup: isFirstOfGroup, isLastOfGroup: isLastOfGroup, boldFont: boldFont),
                  _buildPdfTableCell(item['subDescription'].toString(), flex: 20, font: font, isDescription: true, textAlign: pw.TextAlign.left, isContinuation: isContinuation, isFirstOfGroup: isFirstOfGroup, isLastOfGroup: isLastOfGroup, boldFont: boldFont),
                  _buildPdfTableCell(FormatHelper.tryFormatNum(item['qty']), flex: 10, font: font, isContinuation: isContinuation, isFirstOfGroup: isFirstOfGroup, isLastOfGroup: isLastOfGroup, boldFont: boldFont),
                  _buildPdfTableCell(item['per'].toString(), flex: 10, font: font, isContinuation: isContinuation, isFirstOfGroup: isFirstOfGroup, isLastOfGroup: isLastOfGroup, boldFont: boldFont),
                  _buildPdfTableCell(FormatHelper.tryFormatNum(item['rate']), flex: 10, font: font, isContinuation: isContinuation, isFirstOfGroup: isFirstOfGroup, isLastOfGroup: isLastOfGroup, boldFont: boldFont),
                  if (gstType == 1) _buildPdfTableCell("${item['cgst'].toString()}%\n₹ ${FormatHelper.tryFormatNum(item['cgstAmount'].toString())}", flex: 8, font: font, isContinuation: isContinuation, isFirstOfGroup: isFirstOfGroup, isLastOfGroup: isLastOfGroup, boldFont: boldFont),
                  if (gstType == 1) _buildPdfTableCell("${item['sgst'].toString()}%\n₹ ${FormatHelper.tryFormatNum(item['sgstAmount'].toString())}", flex: 8, font: font, isContinuation: isContinuation, isFirstOfGroup: isFirstOfGroup, isLastOfGroup: isLastOfGroup, boldFont: boldFont),
                  if (gstType == 2) _buildPdfTableCell("${item['igst'].toString()}%\n₹ ${FormatHelper.tryFormatNum(item['igstAmount'].toString())}", flex: 8, font: font, isContinuation: isContinuation, isFirstOfGroup: isFirstOfGroup, isLastOfGroup: isLastOfGroup, boldFont: boldFont),
                  _buildPdfTableCell(FormatHelper.tryFormatNum(item['amount']), flex: 15, font: boldFont, textAlign: pw.TextAlign.right, isContinuation: isContinuation, isFirstOfGroup: isFirstOfGroup, isLastOfGroup: isLastOfGroup, boldFont: boldFont),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  List<pw.Widget> _buildTotalsRow(pw.Font boldFont, pw.Font font) {
    return [
      pw.Container(
        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE8EAF6)),
        child: pw.Row(
          children: [
            pw.Expanded(flex: 105, child: pw.Container()),
            pw.Padding(
              padding: const pw.EdgeInsets.all(2),
              child: pw.Text("Taxable Amount", style: pw.TextStyle(fontSize: 6, font: boldFont), textAlign: pw.TextAlign.right),
            ),
          ],
        ),
      ),
      pw.Container(
        child: pw.Row(
          children: [
            pw.Expanded(flex: 105, child: pw.Container()),
            pw.Padding(
              padding: const pw.EdgeInsets.all(2),
              child: pw.Text(FormatHelper.tryFormatNum(subtotal.toString()), style: pw.TextStyle(fontSize: 6, font: boldFont), textAlign: pw.TextAlign.right),
            ),
          ],
        ),
      ),
    ];
  }

  pw.Widget _buildFinalAmountSection(pw.Font font, pw.Font boldFont) {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.1)),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                'Amount Chargeable (in words): ${FormatHelper.amountToWords(grandTotal.toString())}',
                style: pw.TextStyle(fontSize: 8, font: font),
              ),
            ),
          ),
          pw.Container(
            width: 150,
            child: pw.Table(
              border: pw.TableBorder.all(width: 0.1),
              children: [
                if (cgstTax > 0) _buildEstimateRow('Total CGST', FormatHelper.tryFormatNum(cgstTax), font),
                if (sgstTax > 0) _buildEstimateRow('Total SGST', FormatHelper.tryFormatNum(sgstTax), font),
                if (igstTax > 0) _buildEstimateRow('Total IGST', FormatHelper.tryFormatNum(igstTax), font),
                _buildEstimateRow('Final Amount', FormatHelper.tryFormatNum(grandTotal.toString()), boldFont, isBold: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTermsAndConditions(pw.Font boldFont, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Terms and Conditions', style: pw.TextStyle(fontSize: 10, font: boldFont, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(
            termsAndConditions.isNotEmpty ? termsAndConditions : 'All other terms condition as per standard practice & as per agreed',
            style: pw.TextStyle(fontSize: 8, font: font),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSignatureSection(pw.Font boldFont, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Authorized By', style: pw.TextStyle(fontSize: 9, font: boldFont)),
                pw.SizedBox(height: 40),
                pw.Text('For DHIPL Projects Pvt.Ltd.', style: pw.TextStyle(fontSize: 8, font: font)),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Text('Site Incharge(DHIPL)', style: pw.TextStyle(fontSize: 9, font: boldFont)),
          ),
          pw.Flexible(
            child: pw.Container(
              constraints: const pw.BoxConstraints(maxWidth: 100, minWidth: 100),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Contractors Acceptance', style: pw.TextStyle(fontSize: 9, font: boldFont)),
                  pw.SizedBox(height: 10),
                  pw.Text('Name:', style: pw.TextStyle(fontSize: 8, font: font)),
                  pw.SizedBox(height: 8),
                  pw.Text('Date:', style: pw.TextStyle(fontSize: 8, font: font)),
                  pw.SizedBox(height: 8),
                  pw.Text('Sign:', style: pw.TextStyle(fontSize: 8, font: font)),
                  pw.SizedBox(height: 8),
                  pw.Text('Stamp:', style: pw.TextStyle(fontSize: 8, font: font)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSignatureFooter(pw.Font boldFont, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      // decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(height: 40),
                pw.Text('Director-DHIPL', style: pw.TextStyle(fontSize: 8, font: font), textAlign: pw.TextAlign.left),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.SizedBox(height: 40),
                pw.Text('Project Manager', style: pw.TextStyle(fontSize: 8, font: font), textAlign: pw.TextAlign.center),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.SizedBox(height: 40),
                pw.Text('Acceptance By Labour Contractor', style: pw.TextStyle(fontSize: 8, font: font), textAlign: pw.TextAlign.right),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildJurisdiction(pw.Font font) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 4),
      child: pw.Center(
        child: pw.Text(
          'Subject to Mumbai Jurisdiction',
          style: pw.TextStyle(fontSize: 9, font: font),
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }

  pw.Widget _buildPdfDetailRowHeader(String label, String value, pw.Font font, pw.Font boldFont, {bool isRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.RichText(
        textAlign: isRight ? pw.TextAlign.right : pw.TextAlign.left,
        text: pw.TextSpan(
          style: pw.TextStyle(fontSize: 10, color: PdfColors.black, font: font),
          children: [
            pw.TextSpan(text: '$label : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: boldFont)),
            pw.TextSpan(text: value, style: pw.TextStyle(fontWeight: pw.FontWeight.normal, font: font)),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildPdfDetailRow(
    String label,
    String value,
    pw.Font font,
    pw.Font boldFont, {
    bool isRight = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.RichText(
        textAlign: isRight ? pw.TextAlign.right : pw.TextAlign.left,
        text: pw.TextSpan(
          style: pw.TextStyle(fontSize: 8, color: PdfColors.black, font: font),
          children: [
            pw.TextSpan(text: '$label : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: boldFont)),
            pw.TextSpan(text: value, style: pw.TextStyle(fontWeight: pw.FontWeight.normal, font: font)),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildPdfTableHeader(String text, {required int flex, required pw.Font font, pw.TextAlign textAlign = pw.TextAlign.center}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 0.5, vertical: 4),
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.1)),
        child: pw.Text(
          text,
          style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: PdfColors.black, font: font),
          textAlign: textAlign,
          softWrap: true,
        ),
      ),
    );
  }

  pw.BoxDecoration _getCellBorder({
    required bool isContinuation,
    required bool isFirstOfGroup,
    required bool isLastOfGroup,
  }) {
    if (isContinuation) {
      if (isLastOfGroup) {
        return const pw.BoxDecoration(
          border: pw.Border(
            left: pw.BorderSide(width: 0.1),
            right: pw.BorderSide(width: 0.1),
            bottom: pw.BorderSide(width: 0.1),
          ),
        );
      }
      return const pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(width: 0.1),
          right: pw.BorderSide(width: 0.1),
        ),
      );
    }
    if (isFirstOfGroup && !isLastOfGroup) {
      return const pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(width: 0.1),
          right: pw.BorderSide(width: 0.1),
          top: pw.BorderSide(width: 0.1),
        ),
      );
    }
    return pw.BoxDecoration(border: pw.Border.all(width: 0.1));
  }

  pw.Widget _buildPdfTableCell(
    String text, {
    required int flex,
    required pw.Font font,
    required pw.Font boldFont,
    bool isDescription = false,
    pw.TextAlign textAlign = pw.TextAlign.center,
    bool isBold = false,
    bool isContinuation = false,
    bool isFirstOfGroup = false,
    bool isLastOfGroup = false,
  }) {
    String displayText = text;
    if (!isDescription && isContinuation) {
      displayText = '';
    }

    pw.BoxDecoration decoration;
    if (isContinuation) {
      if (isLastOfGroup) {
        decoration = const pw.BoxDecoration(
          border: pw.Border(left: pw.BorderSide(width: 0.1), right: pw.BorderSide(width: 0.1), bottom: pw.BorderSide(width: 0.1)),
        );
      } else {
        decoration = const pw.BoxDecoration(
          border: pw.Border(left: pw.BorderSide(width: 0.1), right: pw.BorderSide(width: 0.1)),
        );
      }
    } else if (isFirstOfGroup && !isLastOfGroup) {
      decoration = const pw.BoxDecoration(
        border: pw.Border(left: pw.BorderSide(width: 0.1), right: pw.BorderSide(width: 0.1), top: pw.BorderSide(width: 0.1)),
      );
    } else {
      decoration = pw.BoxDecoration(border: pw.Border.all(width: 0.1));
    }

    return pw.Expanded(
      flex: flex,
      child: pw.Container(
        width: double.infinity,
        padding: pw.EdgeInsets.symmetric(horizontal: isDescription ? 1.0 : 0.5, vertical: isContinuation ? 0 : 2),
        decoration: decoration,
        child: pw.Text(
          displayText,
          style: pw.TextStyle(
            fontSize: 6,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: PdfColors.black,
            lineSpacing: isDescription ? 1.3 : 1.2,
            font: isBold ? boldFont : font,
          ),
          softWrap: true,
          overflow: pw.TextOverflow.clip,
          textAlign: textAlign,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final columnWidths = [
      const FlexColumnWidth(10),
      const FlexColumnWidth(20),
      const FlexColumnWidth(20),
      const FlexColumnWidth(10),
      const FlexColumnWidth(10),
      const FlexColumnWidth(10),
      if (gstType == 1) const FlexColumnWidth(8),
      if (gstType == 1) const FlexColumnWidth(8),
      if (gstType == 2) const FlexColumnWidth(8),
      const FlexColumnWidth(15),
    ];

    final terms = getTerms();

    return showPDFPreview
        ? PdfPreview(
            build: (_) async {
              final pdf = await _generatePDF(context);
              return pdf.save();
            },
            useActions: false,
            initialPageFormat: PdfPageFormat.a4,
          )
        : Expanded(
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(color: Color(0xFF1B365D)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 1, child: Image.asset(getImagePath('app_logo.png'), height: 100)),
                          const Expanded(flex: 1, child: SizedBox()),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "DHIPL PROJECTS PVT. LTD. (${entity.name})\n${getIndianFinancialYear(poDate: soDate.isEmpty ? null : soDate)}",
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.right,
                                ),
                                const SizedBox(height: 4),
                                Text(entity.address ?? 'NA', style: const TextStyle(color: Colors.white70, fontSize: 11), textAlign: TextAlign.right),
                                Text('GSTIN/UIN : ${entity.gst ?? 'NA'}', style: const TextStyle(color: Colors.white70, fontSize: 11), textAlign: TextAlign.right),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),

                    // SO Details
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 4, right: 4, left: 4),
                      child: Row(
                        children: [
                          Expanded(flex: 1, child: _buildDetailRowHeader("SO No", soNo)),
                          const Expanded(
                            flex: 1,
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 4),
                              child: Text("SERVICE ORDER", style: TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                            ),
                          ),
                          Expanded(flex: 1, child: _buildDetailRowHeader("Date", soDate.isEmpty ? 'NA' : FormatHelper.formatDateIST(soDate), isRight: true)),
                        ],
                      ),
                    ),

                    // Project Details
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('To,', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(contractor.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(contractor.address, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDetailRow('LR Ref.', soItems.map((e) => e['lrNo'] ?? '').toSet().join(', ')),
                                _buildDetailRow('Concern Person', concernPerson),
                                _buildDetailRow('Mobile', contractor.mobileNo.isEmpty ? 'NA' : contractor.mobileNo),
                                _buildDetailRow('PAN No.', contractor.pan.isEmpty ? 'NA' : contractor.pan),
                                _buildDetailRow('GST No.', contractor.gst == null || contractor.gst!.isEmpty ? 'NA' : contractor.pan),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                      child: _buildDetailRow("Type Of Work", typeOfWork.isEmpty ? 'NA' : typeOfWork),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Site', project.projectName),
                          _buildDetailRow('Location', "${siteLocation.isEmpty ? 'NA' : siteLocation}\n${project.siteAddress}"),
                          _buildDetailRow('Site Incharge', "${project.rawJson['site_supervisor'][0]['full_name']} - ${project.rawJson['site_supervisor'][0]['contact_no']}"),
                          _buildDetailRow('Email', (project.rawJson['site_supervisor'][0]['email']?.isEmpty ?? true) ? 'NA' : project.rawJson['site_supervisor'][0]['email']),
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                      child: _buildDetailRow("Project Manager", "${project.rawJson['project_manager_dhipl'][0]['full_name']} - ${project.rawJson['project_manager_dhipl'][0]['contact_no']}"),
                    ),
                    const SizedBox(height: 16),

                    // Work Estimate
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailRow('Work to be start on as', workStartDate.isEmpty ? 'NA' : workStartDate),
                              _buildDetailRow('Proposed Completion Date', proposedCompletionDate.isEmpty ? 'NA' : proposedCompletionDate),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Expanded(child: SizedBox()),
                              Flexible(
                                child: Container(
                                  constraints: const BoxConstraints(maxWidth: 350),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Center(child: Text('WORK ESTIMATE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                                      const SizedBox(height: 8),
                                      Table(
                                        border: const TableBorder(
                                          top: BorderSide(width: 1, color: Colors.black),
                                          right: BorderSide(width: 1, color: Colors.black),
                                          left: BorderSide(width: 1, color: Colors.black),
                                          bottom: BorderSide(width: 0.5, color: Colors.black),
                                          verticalInside: BorderSide(width: 1, color: Colors.black),
                                          horizontalInside: BorderSide(width: 1, color: Colors.black),
                                        ),
                                        columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
                                        children: [
                                          _buildPreviewEstimateRow('Total Value of Work', FormatHelper.tryFormatNum(subtotal.toString()), isBold: true),
                                          if (cgstTax > 0) _buildPreviewEstimateRow('Add CGST', FormatHelper.tryFormatNum(cgstTax)),
                                          if (sgstTax > 0) _buildPreviewEstimateRow('Add SGST', FormatHelper.tryFormatNum(sgstTax)),
                                          if (igstTax > 0) _buildPreviewEstimateRow('Add IGST', FormatHelper.tryFormatNum(igstTax)),
                                          _buildPreviewEstimateRow('Grand Total', FormatHelper.tryFormatNum(grandTotal.toString()), isBold: true),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                      child: const Text(firstPageCondition, style: TextStyle(fontWeight: FontWeight.normal, fontSize: 12)),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Authorized By', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                SizedBox(height: 60),
                                Text('For DHIPL Projects Pvt.Ltd.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          const Expanded(
                            child: Text('Site Incharge(DHIPL)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          ),
                          Flexible(
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 250, minWidth: 250),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Contractors Acceptance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                  SizedBox(height: 10),
                                  Text('Name:', style: TextStyle(fontSize: 11)),
                                  SizedBox(height: 10),
                                  Text('Date:', style: TextStyle(fontSize: 11)),
                                  SizedBox(height: 10),
                                  Text('Sign:', style: TextStyle(fontSize: 11)),
                                  SizedBox(height: 10),
                                  Text('Stamp:', style: TextStyle(fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Center(
                        child: Text('${project.projectName} $siteLocation', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: _buildDetailRow("Date", soDate.isEmpty ? 'NA' : soDate, isRight: true),
                    ),
                    Table(
                      columnWidths: columnWidths.asMap(),
                      defaultVerticalAlignment: TableCellVerticalAlignment.top,
                      border: TableBorder.all(width: 0.1),
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(color: Color(0xFFE8EAF6)),
                          children: [
                            _buildPreviewTableHeader('Sr No.'),
                            _buildPreviewTableHeader('Main Item', textAlign: TextAlign.left),
                            _buildPreviewTableHeader('Sub Item', textAlign: TextAlign.left),
                            _buildPreviewTableHeader('Qty'),
                            _buildPreviewTableHeader('Per'),
                            _buildPreviewTableHeader('Rate'),
                            if (gstType == 1) _buildPreviewTableHeader('CGST'),
                            if (gstType == 1) _buildPreviewTableHeader('SGST'),
                            if (gstType == 2) _buildPreviewTableHeader('IGST'),
                            _buildPreviewTableHeader('Amount', textAlign: TextAlign.right),
                          ],
                        ),
                        ...soItems.map((item) => TableRow(
                              children: [
                                _buildPreviewTableCell(item['slNo'].toString()),
                                _buildPreviewTableCell(item['mainDescription'].toString(), isDescription: true, textAlign: TextAlign.left),
                                _buildPreviewTableCell(item['subDescription'].toString(), isDescription: true, textAlign: TextAlign.left),
                                _buildPreviewTableCell(FormatHelper.tryFormatNum(item['qty'])),
                                _buildPreviewTableCell(item['per'].toString()),
                                _buildPreviewTableCell(FormatHelper.tryFormatNum(item['rate'])),
                                if (gstType == 1) _buildPreviewTableCell("${item['cgst'].toString()}%\n₹ ${FormatHelper.tryFormatNum(item['cgstAmount'].toString())}"),
                                if (gstType == 1) _buildPreviewTableCell("${item['sgst'].toString()}%\n₹ ${FormatHelper.tryFormatNum(item['sgstAmount'].toString())}"),
                                if (gstType == 2) _buildPreviewTableCell("${item['igst'].toString()}%\n₹ ${FormatHelper.tryFormatNum(item['igstAmount'].toString())}"),
                                _buildPreviewTableCell(FormatHelper.tryFormatNum(item['amount']), isBold: true, textAlign: TextAlign.right),
                              ],
                            ))
                      ],
                    ),
                    // Totals Row
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8EAF6),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPreviewTableTotalsCell('', flex: 96, isBold: true, textAlign: TextAlign.left),
                          _buildPreviewTableTotalsCell("Taxable Amount", flex: 15, isBold: true, textAlign: TextAlign.right),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPreviewTableTotalsCell('', flex: 96, isBold: true, textAlign: TextAlign.left),
                          _buildPreviewTableTotalsCell(FormatHelper.tryFormatNum(subtotal.toString()), flex: 15, isBold: true, textAlign: TextAlign.right),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Terms and Conditions
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(5),
                        1: FlexColumnWidth(95),
                      },
                      defaultVerticalAlignment: TableCellVerticalAlignment.top,
                      border: TableBorder.all(width: 0.1),
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(color: Color(0xFFE8EAF6)),
                          children: [
                            _buildPreviewTableHeader('Sr No.'),
                            _buildPreviewTableHeader('Terms & Conditions', textAlign: TextAlign.left),
                          ],
                        ),
                        ...terms.map((item) {
                          final bool isSubheader = item['_isSubheader'] == true;
                          if (isSubheader) {
                            return TableRow(
                              children: [
                                _buildPreviewTableCell(""),
                                _buildPreviewTableCell(item['description'].toString(), isDescription: true, textAlign: TextAlign.left, isBold: true),
                              ],
                            );
                          }
                          return TableRow(
                            children: [
                              _buildPreviewTableCell(item['srNo']),
                              _buildPreviewTableCell(item['description'].toString(), isDescription: true, textAlign: TextAlign.left),
                            ],
                          );
                        })
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 60),
                                Text('Director-DHIPL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(height: 60),
                                Text('Project Manager', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                SizedBox(height: 60),
                                Text('Acceptance By Labour Contractor', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
  }

  Widget _buildDetailRowHeader(String label, String value, {bool isRight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        textAlign: isRight ? TextAlign.right : TextAlign.left,
        text: TextSpan(
          style: const TextStyle(fontSize: 16, color: Colors.black87),
          children: [
            TextSpan(text: '$label : ', style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isRight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        textAlign: isRight ? TextAlign.right : TextAlign.left,
        text: TextSpan(
          style: const TextStyle(fontSize: 11, color: Colors.black87),
          children: [
            TextSpan(text: '$label : ', style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewTableHeader(String text, {TextAlign textAlign = TextAlign.center}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87), textAlign: textAlign, softWrap: true),
    );
  }

  Widget _buildPreviewTableCell(String text, {bool isDescription = false, TextAlign textAlign = TextAlign.center, bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: isBold ? FontWeight.w600 : FontWeight.normal, color: Colors.black87, height: isDescription ? 1.3 : 1.2),
        textAlign: textAlign,
      ),
    );
  }

  Widget _buildPreviewTableTotalsCell(
    String text, {
    required int flex,
    TextAlign textAlign = TextAlign.center,
    bool isBold = false,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 0),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            color: Colors.black87,
          ),
          textAlign: textAlign,
        ),
      ),
    );
  }

  TableRow _buildPreviewEstimateRow(String label, String value, {bool isBold = false}) {
    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.all(4), child: Text(label, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal))),
        Padding(padding: const EdgeInsets.all(4), child: Text(value, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal), textAlign: TextAlign.right)),
      ],
    );
  }
}
