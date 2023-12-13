// create_menu_fb.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:html/parser.dart';
import 'package:intl/intl.dart';
import '../firebase_options.dart';
import 'package:http/http.dart' as http;

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
        'menuLines': menuLines
            .map((line) => line.replaceAll(RegExp(r'[\[\]]'), ''))
            .toList(),
        'selectedDate': selectedDate,
        'selectedLocation': selectedLocation,
        'time': time,
      };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  var fcmToken = await FirebaseMessaging.instance.getToken(
      vapidKey:
          "BOeBIiobFfeKVQ3t6ReVyADtG1fotxDYBKPGStWyWFupULdt5w_RloOk56x3z4NqTLoHkM9DGC84rxf4KXVDj_U");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Remove the debug banner
      debugShowCheckedModeBanner: false,
      title: 'Kindacode.com',
      home: InputScreen(selectedDate: DateTime.now()),
    );
  }
}

class InputScreen extends StatefulWidget {
  final DateTime selectedDate;

  InputScreen({required this.selectedDate});

  @override
  InputScreenState createState() => InputScreenState();
}

class InputScreenState extends State<InputScreen> {
  List<String>? menuLines;
  String? selectedDate;
  String? selectedLocation;
  int? time;

  final CollectionReference<Map<String, dynamic>> _menu =
      FirebaseFirestore.instance.collection('Menu');

  Future getData() async {
    List<String> Locations = ["student", "staff", "snack"];
    var checkLocation = 0;
    final currentDate = widget.selectedDate;
    DateTime monday =
        currentDate.subtract(Duration(days: currentDate.weekday - 1));
    List<DateTime> weekdays = [];
    for (int i = 0; i < 5; i++) {
      weekdays.add(monday.add(Duration(days: i)));
    }

    for (String location in Locations) {
      if (location == "student") {
        checkLocation = 1;
      } else if (location == "staff") {
        checkLocation = 2;
      } else if (location == "snack") {
        checkLocation = 4;
      }

      for (DateTime date in weekdays) {
        final yyyy = DateFormat('yyyy').format(date);
        final mm = DateFormat('MM').format(date);
        final dd = DateFormat('dd').format(date);

        for (int time = 1; time <= 2; time++) {
          if (time == 2 && checkLocation == 4) {
            break;
          }

          final QuerySnapshot<Map<String, dynamic>> existingData = await _menu
              .where('selectedDate',
                  isEqualTo: DateFormat('MM-dd').format(date))
              .where('selectedLocation', isEqualTo: location)
              .where('time', isEqualTo: time)
              .get();

          if (existingData.docs.isEmpty) {
            final response = await http.get(
              Uri.parse(
                  'https://www.kumoh.ac.kr/ko/restaurant0${checkLocation}.do?mode=menuList&srDt=${yyyy}-${mm}-${dd}'),
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36',
              },
            );

            if (response.statusCode == 200) {
              final document = parse(response.body);
              final foodElements = document.querySelectorAll(
                  ".menu-list-box table tbody tr:nth-child(${time * 2 - 1}) td:nth-child(${date.weekday * 2 - 1})");

              if (foodElements.isNotEmpty) {
                final foodMenu = foodElements[0].text;
                final modifiedFoodMenu =
                    foodMenu.replaceAll(RegExp(r'\s{2,}'), '\n');
                List<String> foodMenuLines = modifiedFoodMenu.split('\n');
                foodMenuLines.removeWhere((element) => element.trim().isEmpty);
                menuLines = foodMenuLines;
                selectedDate = DateFormat('MM-dd').format(date);
                selectedLocation = location;

                // 각 날짜에 대한 데이터를 Firestore에 추가
                await _menu.add({
                  'menuLines': menuLines
                      ?.map((line) => line.replaceAll(RegExp(r'[\[\]]'), ''))
                      .toList(),
                  'selectedDate': selectedDate,
                  'selectedLocation': selectedLocation,
                  'time': time,
                });
              }
            }
          }
        }
      }
    }
  }

  List<Content> todayContents = [];

  Future<void> getTodayMenu() async {
    final today = DateFormat('MM-dd').format(widget.selectedDate);

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _menu.where('selectedDate', isEqualTo: today).get();

    if (snapshot.docs.isNotEmpty) {
      setState(() {
        todayContents = snapshot.docs
            .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
          return Content.fromJson(doc.data());
        }).toList();
      });
    } else {
      print('No data available for today.');
    }
  }

  Future deleteAllData() async {
    // 현재 날짜를 가져옴
    final currentDate = widget.selectedDate;

    // 현재 날짜가 포함된 주의 월요일을 찾음
    DateTime monday =
        currentDate.subtract(Duration(days: currentDate.weekday - 1));

    // 월요일부터 금요일까지의 날짜를 담을 리스트
    List<DateTime> weekdays = [];

    // 주의 월요일부터 금요일까지의 날짜를 리스트에 추가
    for (int i = 0; i < 5; i++) {
      weekdays.add(monday.add(Duration(days: i)));
    }

    // 모든 문서를 삭제
    for (DateTime date in weekdays) {
      await _menu
          .where('selectedDate', isEqualTo: DateFormat('MM-dd').format(date))
          .get()
          .then((snapshot) {
        for (QueryDocumentSnapshot doc in snapshot.docs) {
          doc.reference.delete();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    getTodayMenu();
    return Scaffold(
      appBar: AppBar(
        title: const Text('파이어베이스 데이터 추가 및 삭제'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: getData,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: deleteAllData,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: todayContents.length,
        itemBuilder: (context, index) {
          final content = todayContents[index];
          return ListTile(
            title: Text('Date: ${content.selectedDate}'),
            subtitle: Text('Menu Lines: ${content.menuLines}'),
          );
        },
      ),
    );
  }
}
