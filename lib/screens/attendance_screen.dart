import 'package:atom_attendance/layout/support_footer.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart'; 
import 'package:dart_ipify/dart_ipify.dart'; 
import '../services/api_service.dart';
import 'login_screen.dart';
import 'attendance_history_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  Map? attendance;
  Map? userData;
  bool isLoading = false;
  Timer? _timer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    loadUser();
    fetchAttendance();
  }

  // --- FIXED: Location logic for Mobile (Android/iOS) ---
  Future<Map<String, dynamic>> _getSecurityPayload() async {
    double lat = 0.0;
    double lng = 0.0;
    String ipv4 = "0.0.0.0";

    // 1. IP Fetching
    try {
      ipv4 = await Ipify.ipv4();
    } catch (e) {
      debugPrint("IP Error: $e");
    }

    // 2. Mobile Native Location (Using Geolocator)
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("Location services disabled");
      } else {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          lat = position.latitude;
          lng = position.longitude;
          debugPrint("Location Success: $lat, $lng");
        }
      }
    } catch (e) {
      debugPrint("Location Error: $e");
    }

    if (lat == 0.0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Location not found! Please enable GPS."),
          backgroundColor: Colors.red,
        ),
      );
    }

    return {"latitude": lat, "longitude": lng, "ip_address": ipv4};
  }

  void loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userData = jsonDecode(prefs.getString('auth_user') ?? '{}');
    });
  }

  String formatHMS(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    int h = totalSeconds ~/ 3600;
    int m = (totalSeconds % 3600) ~/ 60;
    int s = totalSeconds % 60;
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  int parseTimeToSeconds(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 0;
    List<String> parts = timeStr.split(':');
    if (parts.length != 3) return 0;
    return int.parse(parts[0]) * 3600 +
        int.parse(parts[1]) * 60 +
        int.parse(parts[2]);
  }

  Future<void> fetchAttendance() async {
    setState(() => isLoading = true);
    try {
      final res = await ApiService.get('/attendance/today');
      if (res.statusCode == 200) {
        final rawData = jsonDecode(res.body)['data'] ?? jsonDecode(res.body);
        setState(() {
          attendance = _processAttendanceData(rawData);
          isLoading = false;
        });
        _initTimer();
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Map _processAttendanceData(Map att) {
    att['worked_seconds_computed'] = parseTimeToSeconds(att['worked_time']);
    att['display_shift'] =
        "${att['shift_start_for_json'] ?? '--'} - ${att['shift_end_for_json'] ?? '--'}";
    att['display_late'] = att['is_late'] == true
        ? (att['late_time'] ?? "00:00:00")
        : "00:00:00";

    if (att['check_in_time'] != null) {
      try {
        att['in_time_only'] = DateFormat('hh:mm a').format(DateTime.parse(att['check_in_time']));
      } catch (e) {
        att['in_time_only'] = "--:--";
      }
    }
    if (att['check_out_time'] != null) {
      try {
        att['out_time_only'] = DateFormat('hh:mm a').format(DateTime.parse(att['check_out_time']));
      } catch (e) {
        att['out_time_only'] = "--:--";
      }
    }
    return att;
  }

  void _initTimer() {
    _timer?.cancel();
    if (attendance?['check_in_time'] != null &&
        attendance?['check_out_time'] == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            attendance!['worked_seconds_computed'] =
                (attendance!['worked_seconds_computed'] ?? 0) + 1;
          });
        }
      });
    }
  }

  Future<void> _handleAttendanceAction() async {
    setState(() => isLoading = true);
    final securityData = await _getSecurityPayload();

    String endPoint = attendance?['check_in_time'] == null
        ? '/attendance/check-in'
        : '/attendance/check-out';

    try {
      final res = await ApiService.post(endPoint, securityData);
      if (res.statusCode == 200 || res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Attendance Marked Successfully!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await fetchAttendance();
      } else {
        final msg = jsonDecode(res.body)['message'] ?? "Security verification failed";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text(msg)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Network Error")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isCheckedIn = attendance?['check_in_time'] != null;
    final bool isCheckedOut = attendance?['check_out_time'] != null;
    final bool isWorking = isCheckedIn && !isCheckedOut;

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: _buildOrb(Colors.blueAccent.withOpacity(0.08), 200),
          ),
          SafeArea(
            child: RefreshIndicator(
              color: Colors.blueAccent,
              onRefresh: fetchAttendance,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildHeader(),
                    const SizedBox(height: 30),
                    _buildMainTimer(isWorking, isCheckedOut),
                    const SizedBox(height: 30),
                    _buildBentoGrid(),
                    const SizedBox(height: 30),
                    _buildActionButton(isCheckedIn, isCheckedOut),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const SupportFooter(),
    );
  }

  Widget _buildOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 80, spreadRadius: 40)],
      ),
    );
  }

  Widget _buildHeader() {
    String formattedDate = DateFormat('EEEE, d MMM').format(DateTime.now());
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formattedDate.toUpperCase(),
              style: TextStyle(
                color: Colors.blueAccent.withOpacity(0.8),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              userData?['name'] ?? "Employee",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AttendanceHistoryScreen()),
                );
              },
              icon: const Icon(Icons.history_rounded, color: Colors.white70, size: 22),
            ),
            IconButton(
              onPressed: fetchAttendance,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white24),
            ),
            GestureDetector(
              onTap: _showLogoutDialog,
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white.withOpacity(0.05),
                backgroundImage: (userData?['image_url'] != null) ? NetworkImage(userData!['image_url']) : null,
                child: (userData?['image_url'] == null) ? const Icon(Icons.person, color: Colors.white24, size: 20) : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainTimer(bool active, bool finished) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: active ? Colors.blueAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          Text(
            active ? "SESSION ACTIVE" : (finished ? "SHIFT COMPLETED" : "READY TO WORK"),
            style: TextStyle(
              color: active ? Colors.blueAccent : Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            formatHMS(attendance?['worked_seconds_computed'] ?? 0),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 52,
              fontWeight: FontWeight.w200,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _timeLabel("PUNCH IN", attendance?['in_time_only'] ?? "--:--"),
              const SizedBox(width: 30),
              Container(width: 1, height: 25, color: Colors.white10),
              const SizedBox(width: 30),
              _timeLabel("PUNCH OUT", attendance?['out_time_only'] ?? "--:--"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeLabel(String label, String time) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(time, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildBentoGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _bentoCard("Today Shift", attendance?['display_shift'] ?? "--", Icons.watch_later_outlined, Colors.purpleAccent),
        _bentoCard("Today Late", attendance?['display_late'] ?? "00:00:00", Icons.history_toggle_off_rounded, Colors.redAccent),
        _bentoCard("Monthly Late", "${attendance?['month_late_count'] ?? 0}", Icons.calendar_today_outlined, Colors.orangeAccent),
        _bentoCard("Overtime", attendance?['month_overtime'] ?? "00:00:00", Icons.bolt_rounded, Colors.greenAccent),
      ],
    );
  }

  Widget _bentoCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color.withOpacity(0.8), size: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(bool inTime, bool outTime) {
    bool isFinished = inTime && outTime;
    return InkWell(
      onTap: (isLoading || isFinished) ? null : _handleAttendanceAction,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 65,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isFinished ? Colors.white.withOpacity(0.05) : Colors.transparent,
          border: Border.all(
            color: isFinished ? Colors.transparent : (inTime ? Colors.redAccent : Colors.blueAccent),
            width: 1.5,
          ),
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(
                  !inTime ? "START CHECK IN" : (outTime ? "SHIFT FINISHED" : "FINISH CHECK OUT"),
                  style: TextStyle(
                    color: !inTime ? Colors.blueAccent : (outTime ? Colors.white24 : Colors.redAccent),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontSize: 14,
                  ),
                ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Colors.white10)),
        title: const Text("Logout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to logout?", style: TextStyle(color: Colors.white60)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              _timer?.cancel();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
            },
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }
}