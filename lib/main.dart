import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:app/firebase_options.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'student_menu.dart';
import 'snack_bar_menu.dart';
import 'staff_menu.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';

class Content {
  List<String> menuLines;
  String selectedDate;
  String selectedLocation;
  int time;

  Content({
    required this.menuLines,
    required this.selectedDate,
    required this.selectedLocation,
    required this.time,
  });

  Content.fromJson(Map<String, dynamic> json)
      : menuLines = (json['menuLines'] as List<dynamic>)
      .map((e) => e.toString())
      .toList(),
        selectedDate = json['selectedDate'],
        selectedLocation = json['selectedLocation'],
        time = json['time'];

  Map<String, dynamic> toJson() => {
    'menuLines': menuLines,
    'selectedDate': selectedDate,
    'selectedLocation': selectedLocation,
    'time': time,
  };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  try {
    _initLocalNotification();
    await weeklyMondayPushAlarm();
    await scheduleWeeklyAlarm();
  } catch (e) {
    print('Error scheduling alarm: $e');
  }
  await initializeDateFormatting();
  runApp(MaterialApp(
    home: MyHomePage(title: '학식 캘린더'),
    theme: ThemeData(fontFamily: 'text'),
  ));
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required String title});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool showButtons = false;
  DateTime? _selectedDate;
  String? formattedDate;
  int _currentIndex = 0;
  DateTime? _focusedDay = DateTime.now(); //다른 달의 날짜 클릭하면 이번 달로 회귀하는 거 짜증나서 만듬
  DateTime? selectedDate = DateTime.now(); //날짜 클릭하면 파란색 동그라미 쓸려고 추가함
  late SharedPreferences _prefs;

  void _toggleButtons(DateTime selectedDate, DateTime focusedDate) {
    setState(() {
      _selectedDate = selectedDate;
      showButtons = true; // 학식, 교직, 분식 버튼이 표시하도록 변경
    });
  }

  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text(
            '학식 캘린더',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
        ),
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          TableCalendar(
            locale: 'ko_KR',
            firstDay: DateTime.utc(2010, 10, 16),
            lastDay: DateTime.utc(2030, 3, 14),
            focusedDay: _focusedDay!,
            selectedDayPredicate: (DateTime day) {
              return isSameDay(_selectedDate, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              if (isSameDay(selectedDay, focusedDay)) {
                // 선택된 날짜와 현재 월의 날짜가 같을 때만 처리
                setState(() {
                  _selectedDate = selectedDay;
                  _focusedDay = focusedDay;
                  _toggleButtons(selectedDay, focusedDay);
                });
              }
            },
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle:
              TextStyle(fontWeight: FontWeight.w700, fontSize: 20.0),
            ),
            calendarStyle: const CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: Colors.lightGreen,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.lightGreen,
              ),
              //tableBorder: TableBorder(
              //  verticalInside: BorderSide(
              //  color: Colors.lightGreen,
              //  width: 1.0,
              //),
              //),
              weekendTextStyle: TextStyle(
                color: Colors.red, // 토요일 텍스트 스타일 설정
              ),
            ),
          ),
          if (showButtons)
            Padding(
                padding: const EdgeInsets.only(top: 20), // 버튼 아래로 조절
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildButton(
                      '학식당',
                      screenWidth * 0.25,
                      Colors.grey,
                    ),
                    const SizedBox(
                      width: 20,
                    ),
                    _buildButton('교직원', screenWidth * 0.25, Colors.grey),
                    const SizedBox(
                      width: 20,
                    ),
                    _buildButton('분식당', screenWidth * 0.25, Colors.grey),
                  ],
                )),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.green,
        selectedLabelStyle: TextStyle(color: Colors.green),
        currentIndex: _currentIndex,
        onTap: (int index) {
          setState(() {
            _currentIndex = index;

            if (index == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AlarmListPage(),
                ),
              );
            } else if (index == 2) {
              // 추가: 지도 아이콘을 누르면 지도 페이지로 이동
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LocationPage(),
                ),
              );
            }
          });
        },
        items: [
          BottomNavigationBarItem(
            icon:
            Image.asset('assets/calendar1.png', width: 50.0, height: 50.0),
            label: '캘린더',
            backgroundColor: const Color.fromRGBO(172, 237, 79, 1.0),
          ),
          BottomNavigationBarItem(
            icon: Image.asset('assets/noti.png', width: 50.0, height: 50.0),
            label: '알림',
          ),
          BottomNavigationBarItem(
            icon: Image.asset('assets/location.png', width: 50.0, height: 50.0),
            label: '지도',
          ),
        ],
      ),
    );
  }

  Widget _buildButton(String label, double width, Color buttonColor) {
    return SizedBox(
      width: width,
      child: ElevatedButton(
        onPressed: () {
          if (label == '학식당') {
            // '학식당' 버튼을 눌렀을 때 화면을 전환
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    MyListWidget(selectedDate: _selectedDate!), // 학식당 메뉴 보기 기능
              ),
            );
          } else if (label == '분식당') {
            // '분식당' 버튼을 눌렀을 때 화면을 전환
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    MyListWidget3(selectedDate: _selectedDate!), // 분식당 메뉴 보기 기능
              ),
            );
          } else if (label == '교직원') {
            // '교직원' 버튼을 눌렀을 때 화면을 전환
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    MyListWidget2(selectedDate: _selectedDate!), // 교직원 메뉴 보기 기능
              ),
            );
          }
        },
        style: OutlinedButton.styleFrom(
          // background 속성이 없다.
          primary: Colors.lightGreen,
          backgroundColor: Colors.white,
          side: BorderSide(
            // 테두리 바꾸는 속성
            color: Colors.lightGreen,
            width: 1.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.0),
          ),
        ),
        child: Text(label),
      ),
    );
  }

  void onDaySelected(DateTime selectedDate, DateTime focusedDate) {
    setState(() {
      _selectedDate =
          selectedDate; // _selectedDate가 null이거나 다른 달로 이동한 경우에만 업데이트함
      _toggleButtons(
          selectedDate, focusedDate); // 선택된 달이 현재 월이 아닌 경우에만 페이지 업데이트하는 부분을 제거
    });
  }

  // 각 식당 페이지 연결 코드
  void showAlertDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }
}

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '식당 위치',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.normal),
        ),
        backgroundColor: Colors.lightGreen,
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              _buildLocationCard(
                "학생회관 지하 1층\n휴무일: 주말, 공휴일",
                'images/img_skyview.png',
              ),
              _buildLocationCard(
                "학식당,교직원식당 입구\n(학식당/교직원식당: (054)478-7049)\n08:20~09:20/11:30~13:30/17:00~18:30",
                'images/img_cafeteria_out.jpg',
              ),
              _buildLocationCard(
                "학식당 내부\n08:20~09:20/11:30~13:30/17:00~18:30",
                'images/img_cafeteria_in.png',
              ),
              _buildLocationCard(
                "교직원식당 내부\n08:20~09:20/11:30~13:30/17:00~18:30",
                'images/img_cafeteria_in2.jpeg',
              ),
              _buildLocationCard(
                "분식당 입구\n(분식당: (054)478-6979)\n11:00~14:00/16:00~18:30",
                'images/img_cafeteria_out1.jpg',
              ),
              _buildLocationCard(
                "분식당 내부\n11:00~14:00/16:00~18:30",
                'images/img_cafeteria_in3.jpg',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard(String locationName, String imagePath) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.asset(
              imagePath,
              fit: BoxFit.cover,
            ),
          ),
          ListTile(
            title: Text(locationName),
          ),
        ],
      ),
    );
  }
}

class AlarmListPage extends StatefulWidget {
  const AlarmListPage({super.key});

  @override
  State<AlarmListPage> createState() => _AlarmListPageState();
}

// 데이터 저장은 크롬에선 X, 안드로이드등의 디바이스에서만 가능
class _AlarmListPageState extends State<AlarmListPage> {
  late SharedPreferences _prefs;
  final TextEditingController _alarmTextController = TextEditingController();

  List<Map<String, dynamic>> _foundAlarms = [];
  final List<Map<String, dynamic>> _alarmList = [];

  @override
  void initState() {
    super.initState();
    _initSharedPreferences();
  }

  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _loadAlarmData();
  }

  void _loadAlarmData() {
    final List<String>? alarmListJson = _prefs.getStringList('alarmList');

    if (alarmListJson != null) {
      print("_loadAlarmData: Loaded alarms - $alarmListJson");
      setState(() {
        _alarmList.clear();
        _alarmList.addAll(alarmListJson.map((jsonString) => json.decode(jsonString)));
        _foundAlarms = List.from(_alarmList);
      });
    } else {
      print("_loadAlarmData: No alarms found");
    }
  }

  void _runFilter(String enteredKeyword) {
    setState(() {
      if (enteredKeyword.isEmpty) {
        _foundAlarms = List.from(_alarmList);
      } else {
        _foundAlarms = _alarmList
            .where((menu) => menu["menu"]
            .toLowerCase()
            .contains(enteredKeyword.toLowerCase()))
            .toList();
      }
    });
  }

  void _addAlarm() {
    final String newAlarm = _alarmTextController.text;
    if (newAlarm.isNotEmpty) {
      // 현재까지 등록된 선호 메뉴 중 가장 큰 ID 찾기
      int maxId = 0;
      for (var alarm in _alarmList) {
        if (alarm['id'] > maxId) {
          maxId = alarm['id'];
        }
      }

      // 새로운 ID 할당
      final int newId = maxId + 1;

      // 새로운 선호 메뉴 추가
      final Map<String, dynamic> newAlarmItem = {"id": newId, "menu": newAlarm};
      setState(() {
        _alarmList.add(newAlarmItem);
        _foundAlarms.add(newAlarmItem);
        _alarmTextController.clear();
      });
      print("_addAlarm : ${newAlarmItem}");

      // 추가된 알람을 저장하는 기능 추가
      List<String>? alarmListJson = _prefs.getStringList('alarmList');
      print("_addAlarm : 저장전 $alarmListJson");
      if (alarmListJson == null) {
        alarmListJson = []; // 저장된 알람 목록이 없으면 새로 생성함
      }

      // 새로 추가된 알람을 JSON 형식으로 변환하여 목록에 추가
      final String newAlarmJson = json.encode(newAlarmItem);
      alarmListJson.add(newAlarmJson);

      print("_addAlarm : 저장후 $alarmListJson");
      // 변경된 알람 목록을 다시 SharedPreferences에 저장
      _prefs.setStringList('alarmList', alarmListJson);
      _loadAlarmData();
    }
  }


  void _deleteAlarm(Map<String, dynamic> alarm) {
    setState(() {
      _foundAlarms.remove(alarm);
      _alarmList.remove(alarm);
    });

    // 삭제된 알람을 저장하는 기능 추가
    List<String>? alarmListJson = _prefs.getStringList('alarmList');

    if (alarmListJson != null) {
      // 삭제할 알람을 JSON 형식으로 변환하여 목록에서 제거합니다.
      final String alarmJson = json.encode(alarm);
      alarmListJson.remove(alarmJson);
      // 변경된 알람 목록을 다시 SharedPreferences에 저장합니다.
      _prefs.setStringList('alarmList', alarmListJson);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('선호 메뉴 알람 설정', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.lightGreen,
      ),
      body: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            // const Text(
            //   "선호 메뉴 추가",
            //   style: TextStyle(
            //     fontSize: 22,
            //   ),
            //),
            TextField(
              controller: _alarmTextController,
              decoration: InputDecoration(
                hintText: "선호메뉴",
                // labelText: ,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addAlarm,
                  color: Colors.lightGreen,
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.lightGreen),
                ),
              ),
              cursorColor: Colors.grey,
            ),
            const SizedBox(height: 20),
            TextField(
              onChanged: (value) => _runFilter(value),
              decoration: const InputDecoration(
                hintText: "검색",
                suffixIcon: Icon(
                  Icons.search,
                  color: Colors.lightGreen,
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.lightGreen),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "<아래 메뉴가 있는 날에는 알람이 전송됩니다>",
              style: TextStyle(
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _foundAlarms.isNotEmpty
                  ? ListView.builder(
                itemCount: _foundAlarms.length,
                itemBuilder: (context, index) {
                  final alarm = _foundAlarms[index];
                  return Card(
                    key: ValueKey(alarm["id"]),
                    color: Colors.white,
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    child: ListTile(
                      title: Text(
                        alarm['menu'],
                        style: const TextStyle(fontSize: 18),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          // 삭제 버튼이 눌렸을 때 _deleteAlarm 함수 호출
                          _deleteAlarm(alarm);
                        },
                      ),
                    ),
                  );
                },
              )
                  : const Text(
                '추가한 메뉴가 없어요 :(\n좋아하는 메뉴를 추가해주세요',
                style: TextStyle(
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

tz.TZDateTime _timeZoneSetting({
  required int hour,
  required int minute,
  required int day,
  required int month,
  required int year,
}) {
  tz.TZDateTime scheduledDate =
  tz.TZDateTime(tz.local, year, month, day, hour, minute);
  return scheduledDate;
}

Future<void> _initLocalNotification() async {
  FlutterLocalNotificationsPlugin _localNotification =
  FlutterLocalNotificationsPlugin();
  AndroidInitializationSettings initSettingsAndroid =
  const AndroidInitializationSettings('@mipmap/ic_launcher');
  DarwinInitializationSettings initSettingsIOS =
  const DarwinInitializationSettings(
    requestSoundPermission: false,
    requestBadgePermission: false,
    requestAlertPermission: false,
  );
  InitializationSettings initSettings = InitializationSettings(
    android: initSettingsAndroid,
    iOS: initSettingsIOS,
  );
  await _localNotification.initialize(
    initSettings,
  );
}

NotificationDetails _details = const NotificationDetails(
  android: AndroidNotificationDetails(
    'alarm 1',
    '1번 푸시',
    styleInformation: BigTextStyleInformation(''),
  ),
  iOS: DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  ),
);

Future<void> scheduleWeeklyAlarm() async {
  FlutterLocalNotificationsPlugin _localNotification =
  FlutterLocalNotificationsPlugin();

  // 현재 날짜 및 시간 가져오기
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  tz.TZDateTime now = tz.TZDateTime.now(tz.local);
  for (int i = 0; i <= 5 - now.weekday; i++) {
    int dayToAdd = i;

    int nextMonth = now.month;
    int nextYear = now.year;

    // 달이 넘어가거나 년도가 바뀌는 경우에 대한 처리
    if (now.day + i > DateTime(now.year, now.month + 1, 0).day) {
      dayToAdd = dayToAdd - DateTime(now.year, now.month + 1, 0).day;
      nextMonth += 1;
      if (nextMonth > 12) {
        nextMonth = 1;
        nextYear += 1;
      }
    }

    int nextDay = now.day + dayToAdd;

    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      nextYear,
      nextMonth,
      nextDay,
      10, //이건 당일날 좋아하는 메뉴 있으면 당일에 울리는 시간 설정
      50, //이건 당일날 좋아하는 메뉴 있으면 당일에 울리는 분 설정
    );

    // 해당 일자에 울릴 알람 예약
    await _localNotification.zonedSchedule(
      i, // 고유한 ID로 일자를 사용
      '오늘 당신이 좋아하는 메뉴가 있어요!',
      await getMenuNotificationMessage(scheduledDate), // 알림 내용 생성
      scheduledDate,
      _details,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      androidAllowWhileIdle: true,
    );

    print(
        "${scheduledDate.year}년/${scheduledDate.month}월/${scheduledDate.day}일/10:50 에 알람이 설정됩니다.");
  }
}

String getFullMenuLines(List<String> menuLines) {
  return menuLines.join('\n');
}

Future<String> getMenuNotificationMessage(tz.TZDateTime scheduledDate) async {
  List<Content> menuList = await getMenuDataFromFirestore(scheduledDate);
  late SharedPreferences _prefs;
  _prefs = await SharedPreferences.getInstance();
  final List<String>? alarmListJson = _prefs.getStringList('alarmList');

  if (alarmListJson != null && alarmListJson.isNotEmpty) {
    String likedMenu = "";

    for (String alarmJson in alarmListJson) {
      Map<String, dynamic> alarm = json.decode(alarmJson);

      bool isMenuIncluded = menuList.any((content) => content.menuLines.any(
              (line) => line.toLowerCase().contains(alarm['menu'].toLowerCase())));

      if (isMenuIncluded) {
        print("좋아하는 메뉴가 포함된걸 확인했습니다.");

        // 선택한 식당에 따라 알림 메시지 구성
        likedMenu += menuList
            .where((content) => content.menuLines.any((line) =>
            line.toLowerCase().contains(alarm['menu'].toLowerCase())))
            .map((content) =>
        '날짜: ${content.selectedDate}\n식당: ${getContentLocationName(content.selectedLocation)}\n${getFullMenuLines(content.menuLines)}')
            .join('\n\n');
        print('식단 정보: $likedMenu');
      }
    }

    return likedMenu; // 수정된 부분: 최종 결과 반환
  }
  print("메뉴가 포함안된걸 확인했습니다.");

  // 모든 식단 문서의 메뉴 정보 반환
  return menuList
      .map((content) =>
  '날짜: ${content.selectedDate}\n식당: ${getContentLocationName(content.selectedLocation)}\n${getFullMenuLines(content.menuLines)}')
      .join('\n\n');
}


// 식당 이름에 따라 출력될 문자열 반환
String getContentLocationName(String selectedLocation) {
  switch (selectedLocation) {
    case 'student':
      return '학식당';
    case 'staff':
      return '교직원식당';
    case 'snack':
      return '분식당';
    default:
      return selectedLocation;
  }
}

Future<List<Content>> getMenuDataFromFirestore(
    tz.TZDateTime scheduledDate) async {
  var firestore = FirebaseFirestore.instance;

  var query = firestore.collection('Menu').where('selectedDate',
      isEqualTo: DateFormat('MM-dd').format(scheduledDate));

  var snapshot = await query.get();

  List<Content> menuList = snapshot.docs
      .map((doc) => Content.fromJson(doc.data() as Map<String, dynamic>))
      .toList();

  print(menuList);
  return menuList;
}

Future<void> weeklyMondayPushAlarm() async {
  FlutterLocalNotificationsPlugin _localNotification =
  FlutterLocalNotificationsPlugin();

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

  // 현재 날짜 및 시간 가져오기
  tz.TZDateTime now = tz.TZDateTime.now(tz.local);

  // 현재 시간을 기준으로 다음 주 월요일로 설정
  tz.TZDateTime nextMonday = tz.TZDateTime(
    tz.local,
    now.year,
    now.month,
    now.day + (8 - now.weekday),
    09,
    00,
  );

  // 해당 일자에 울릴 알람 예약
  await _localNotification.zonedSchedule(
    1,
    '매주 월요일 9시 알림',
    '매주 월요일 9시에 전송되는 알림',
    nextMonday,
    _details,
    uiLocalNotificationDateInterpretation:
    UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    androidAllowWhileIdle: true,
  );
}