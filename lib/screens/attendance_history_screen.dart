import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  List<dynamic> attendanceList = [];
  bool isLoading = true;
  int currentPage = 1;
  int lastPage = 1;

  DateTime startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime endDate = DateTime.now();
  String statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    fetchHistory();
  }

  Future<void> fetchHistory() async {
    setState(() => isLoading = true);
    try {
      final String sDate = DateFormat('yyyy-MM-dd').format(startDate);
      final String eDate = DateFormat('yyyy-MM-dd').format(endDate);
      final String url =
          '/attendance/my?start_date=$sDate&end_date=$eDate&page=$currentPage&per_page=20${statusFilter != 'all' ? '&status=$statusFilter' : ''}';

      final res = await ApiService.get(url);
      if (res.statusCode == 200) {
        final jsonData = jsonDecode(res.body);
        setState(() {
          attendanceList = jsonData['data'] ?? [];
          lastPage = jsonData['last_page'] ?? 1;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  // Excel Export Logic FIXED
  Future<void> exportToExcel() async {
    try {
      var excel = Excel.createExcel();
      // Naye version mein sheet name aise access karte hain
      String sheetName = "Attendance";
      excel.rename("Sheet1", sheetName);
      Sheet sheetObject = excel[sheetName];

      // Headers
      sheetObject.appendRow([
        TextCellValue('Date'),
        TextCellValue('Status'),
        TextCellValue('In'),
        TextCellValue('Out'),
        TextCellValue('Late'),
        TextCellValue('OT'),
        TextCellValue('Worked'),
      ]);

      for (var item in attendanceList) {
        sheetObject.appendRow([
          TextCellValue(item['date']?.toString() ?? ''),
          TextCellValue(item['status']?.toString() ?? ''),
          TextCellValue(item['check_in_time']?.toString() ?? '--'),
          TextCellValue(item['check_out_time']?.toString() ?? '--'),
          TextCellValue(item['late_time']?.toString() ?? '00:00'),
          TextCellValue(item['overtime_time']?.toString() ?? '00:00'),
          TextCellValue(item['worked_time']?.toString() ?? '00:00'),
        ]);
      }

      var fileBytes = excel.save();
      final directory = await getApplicationDocumentsDirectory();
      final filePath =
          '${directory.path}/Attendance_${DateFormat('MMM_yyyy').format(startDate)}.xlsx';
      final file = File(filePath);
      
      await file.writeAsBytes(fileBytes!);

      // Fixed Share Logic
      await Share.shareXFiles([XFile(filePath)], text: 'My Attendance Report');
    } catch (e) {
      debugPrint("Excel Export Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Export failed: $e")),
        );
      }
    }
  }

  String formatDuration(String? timeStr) {
    if (timeStr == null || timeStr == "00:00:00" || timeStr.isEmpty) return "-";
    try {
      List<String> parts = timeStr.split(':');
      int h = int.parse(parts[0]);
      int m = int.parse(parts[1]);
      return h > 0 ? "${h}h ${m}m" : "${m}m";
    } catch (e) {
      return "-";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: const Text("ATTENDANCE LOG",
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: exportToExcel,
            icon: const Icon(Icons.description,
                color: Colors.greenAccent, size: 20),
            tooltip: "Export Excel",
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          _buildQuickFilters(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : attendanceList.isEmpty
                    ? const Center(child: Text("No records found", style: TextStyle(color: Colors.white24)))
                    : _buildProfessionalList(),
          ),
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildQuickFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          _filterChip("This Month", () {
            setState(() {
              startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
              endDate = DateTime.now();
              currentPage = 1;
            });
            fetchHistory();
          }),
          const SizedBox(width: 8),
          _filterChip("Custom Range", () async {
            final range = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2023),
              lastDate: DateTime.now(),
              builder: (context, child) => Theme(
                data: ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(primary: Colors.blueAccent),
                ),
                child: child!,
              ),
            );
            if (range != null) {
              setState(() {
                startDate = range.start;
                endDate = range.end;
                currentPage = 1;
              });
              fetchHistory();
            }
          }, isIcon: true),
        ],
      ),
    );
  }

  Widget _filterChip(String label, VoidCallback onTap, {bool isIcon = false}) {
    return ActionChip(
      onPressed: onTap,
      backgroundColor: Colors.white.withOpacity(0.05),
      avatar: isIcon
          ? const Icon(Icons.calendar_today, size: 12, color: Colors.blueAccent)
          : null,
      label: Text(label,
          style: const TextStyle(color: Colors.white70, fontSize: 11)),
      shape: const StadiumBorder(side: BorderSide(color: Colors.white10)),
    );
  }

  Widget _buildProfessionalList() {
    return ListView.builder(
      itemCount: attendanceList.length,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemBuilder: (context, index) {
        final item = attendanceList[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            // border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      DateFormat('EEE, dd MMM yyyy')
                          .format(DateTime.parse(item['date'])),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                  _statusBadge(item['status']?.toString() ?? 'N/A'),
                ],
              ),
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: Colors.white10, height: 1)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _timeColumn("IN/OUT",
                      "${item['check_in_time'] != null ? DateFormat('HH:mm').format(DateTime.parse(item['check_in_time'])) : '--'} / ${item['check_out_time'] != null ? DateFormat('HH:mm').format(DateTime.parse(item['check_out_time'])) : '--'}"),
                  _timeColumn("LATE", formatDuration(item['late_time']),
                      color: Colors.redAccent),
                  _timeColumn("OT", formatDuration(item['overtime_time']),
                      color: Colors.greenAccent),
                  _timeColumn("TOTAL", item['worked_time']?.toString().substring(0, 5) ?? "00:00",
                      isBold: true),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _timeColumn(String label, String value,
      {Color color = Colors.white70, bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white24,
                fontSize: 8,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
      ],
    );
  }

  Widget _statusBadge(String status) {
    Color badgeColor = Colors.blueAccent;
    if (status.toLowerCase() == 'absent') badgeColor = Colors.redAccent;
    if (status.toLowerCase() == 'late') badgeColor = Colors.orangeAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: badgeColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4)),
      child: Text(status.toUpperCase(),
          style: TextStyle(
              color: badgeColor, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Page $currentPage / $lastPage",
              style: const TextStyle(color: Colors.white24, fontSize: 11)),
          Row(
            children: [
              _pageIcon(Icons.arrow_back_ios, currentPage > 1 ? () {
                setState(() => currentPage--);
                fetchHistory();
              } : null),
              const SizedBox(width: 10),
              _pageIcon(Icons.arrow_forward_ios, currentPage < lastPage ? () {
                setState(() => currentPage++);
                fetchHistory();
              } : null),
            ],
          )
        ],
      ),
    );
  }

  Widget _pageIcon(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon,
            size: 14,
            color: onTap == null ? Colors.white10 : Colors.blueAccent),
      ),
    );
  }
}