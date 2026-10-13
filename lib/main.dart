// ==========================================
// تطبيق ساعة التنبيه الذكية بلغة Flutter (Material 3)
// Al-Tanbeeh Flutter Alarm App - Production Grade
// ==========================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AlarmProvider()),
      ],
      child: const AlTanbeehAlarmApp(),
    ),
  );
}

// ------------------------------------------
// 1. التطبيق الرئيسي مع دعم الوضع المظلم والعربية
// ------------------------------------------
class AlTanbeehAlarmApp extends StatelessWidget {
  const AlTanbeehAlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    final alarmProvider = Provider.of<AlarmProvider>(context);

    return MaterialApp(
      title: 'ساعة التنبيه الذكية',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'SA'),
      themeMode: alarmProvider.themeMode,
      // الوضع الفاتح
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        cardColor: Colors.white,
        fontFamily: 'Cairo',
      ),
      // الوضع المظلم الليلي المريح للعين
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFF0B0F19), // كحلي داكن OLED
        cardColor: const Color(0xFF131B2E),
        fontFamily: 'Cairo',
      ),
      home: const HomeScreen(),
    );
  }
}

// ------------------------------------------
// 2. نموذج بيانات المنبه (Alarm Model)
// ------------------------------------------
class AlarmItem {
  final String id;
  TimeOfDay time;
  String label;
  bool isEnabled;
  List<int> repeatDays; // 0=الأحد, 1=الاثنين ... 6=السبت
  String ringtone;
  bool gradualVolume;
  bool autoSnooze;
  int snoozeMinutes;
  int maxSnoozeCount;

  AlarmItem({
    required this.id,
    required this.time,
    this.label = 'تنبيه',
    this.isEnabled = true,
    required this.repeatDays,
    this.ringtone = 'gentle_dawn.mp3',
    this.gradualVolume = true,
    this.autoSnooze = true,
    this.snoozeMinutes = 10,
    this.maxSnoozeCount = 3,
  });

  String get formattedTime {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'ص' : 'م';
    return '$hour:$minute $period';
  }

  String get repeatSummary {
    if (repeatDays.length == 7) return 'يومياً';
    if (repeatDays.isEmpty) return 'مرة واحدة';
    if (repeatDays.length == 5 && !repeatDays.contains(5) && !repeatDays.contains(6)) {
      return 'أيام العمل';
    }
    const dayNames = ['ح', 'ن', 'ث', 'ر', 'خ', 'ج', 'س'];
    return repeatDays.map((d) => dayNames[d]).join(' · ');
  }
}

// ------------------------------------------
// 3. مزود الحالة (Alarm Provider)
// ------------------------------------------
class AlarmProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  final List<AlarmItem> _alarms = [
    AlarmItem(
      id: '1',
      time: const TimeOfDay(hour: 5, minute: 0),
      label: 'صلاة الفجر وبداية اليوم',
      isEnabled: true,
      repeatDays: [0, 1, 2, 3, 4, 5, 6],
      ringtone: 'gentle_dawn.mp3',
      gradualVolume: true,
      autoSnooze: true,
      snoozeMinutes: 10,
    ),
    AlarmItem(
      id: '2',
      time: const TimeOfDay(hour: 7, minute: 30),
      label: 'الاستعداد للعمل والمهام',
      isEnabled: true,
      repeatDays: [0, 1, 2, 3, 4],
      ringtone: 'morning_pulse.mp3',
      gradualVolume: false,
      autoSnooze: true,
      snoozeMinutes: 5,
    ),
  ];

  List<AlarmItem> get alarms => _alarms;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void toggleAlarm(String id) {
    final index = _alarms.indexWhere((a) => a.id == id);
    if (index != -1) {
      _alarms[index].isEnabled = !_alarms[index].isEnabled;
      notifyListeners();
    }
  }

  void addAlarm(AlarmItem alarm) {
    _alarms.add(alarm);
    _alarms.sort((a, b) => (a.time.hour * 60 + a.time.minute).compareTo(b.time.hour * 60 + b.time.minute));
    notifyListeners();
  }

  void deleteAlarm(String id) {
    _alarms.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  void updateAlarm(AlarmItem updated) {
    final index = _alarms.indexWhere((a) => a.id == updated.id);
    if (index != -1) {
      _alarms[index] = updated;
      notifyListeners();
    }
  }
}

// ------------------------------------------
// 4. الشاشة الرئيسية لقائمة المنبهات
// ------------------------------------------
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AlarmProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ساعة التنبيه', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(provider.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'تغيير المظهر الليلي/النهاري',
            onPressed: provider.toggleTheme,
          ),
        ],
      ),
      body: provider.alarms.isEmpty
          ? const Center(child: Text('لا توجد منبهات مضافة بعد'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: provider.alarms.length,
              itemBuilder: (context, index) {
                final alarm = provider.alarms[index];
                return AlarmCardWidget(alarm: alarm);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAlarmDialog(context),
        icon: const Icon(Icons.add_alarm),
        label: const Text('منبه جديد'),
      ),
    );
  }

  void _openAlarmDialog(BuildContext context) {
    // فتح واجهة ضبط الوقت وخيارات التكرار والغفوة
  }
}

// ------------------------------------------
// 5. بطاقة المنبه الأنيقة (Alarm Card)
// ------------------------------------------
class AlarmCardWidget extends StatelessWidget {
  final AlarmItem alarm;
  const AlarmCardWidget({super.key, required this.alarm});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AlarmProvider>(context, listen: false);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alarm.formattedTime,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: alarm.isEnabled ? Theme.of(context).colorScheme.primary : Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${alarm.label} · ${alarm.repeatSummary}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                if (alarm.autoSnooze)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'غفوة تلقائية كل ${alarm.snoozeMinutes} دقيقة',
                      style: const TextStyle(fontSize: 11, color: Colors.indigoAccent),
                    ),
                  ),
              ],
            ),
            Switch(
              value: alarm.isEnabled,
              onChanged: (_) => provider.toggleAlarm(alarm.id),
            ),
          ],
        ),
      ),
    );
  }
}
