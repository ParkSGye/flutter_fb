// snack_bar_menu.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:html/parser.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyListWidget3(selectedDate: DateTime.now()),
      theme: ThemeData(fontFamily: 'text'),
    );
  }
}

class MyListWidget3 extends StatefulWidget {
  final DateTime selectedDate;

  const MyListWidget3({super.key, required this.selectedDate});

  @override
  State<StatefulWidget> createState() {
    return _MyListWidgetState();
  }
}

class _MyListWidgetState extends State<MyListWidget3> {
  String foodData = "로딩 중...";

  @override
  void initState() {
    super.initState();
    fetchMenuData();
  }

  void fetchMenuData() async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://www.kumoh.ac.kr/ko/restaurant04.do?mode=menuList&srDt=${DateFormat('yyyy').format(widget.selectedDate)}-${DateFormat('MM').format(widget.selectedDate)}-${DateFormat('dd').format(widget.selectedDate)}'),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36',
        },
      );

      if (response.statusCode == 200) {
        final document = parse(response.body);
        final foodElements = document.querySelectorAll(
            ".menu-list-box table tbody tr:nth-child(1) td:nth-child(${widget.selectedDate.weekday * 2 - 1})");

        if (foodElements.isNotEmpty) {
          final foodMenu = foodElements[0].text;
          final modifiedFoodMenu = foodMenu.replaceAll(RegExp(r'\s{2,}'), '\n');
          setState(() {
            foodData = modifiedFoodMenu;
          });
        } else {
          setState(() {
            foodData = "데이터가 존재하지 않습니다.";
          });
        }
        // Convert menu data to JSON format
        Map<String, dynamic> jsonData = {
          'foodData': foodData,
          'selectedDate': DateFormat('yyyy-MM-dd').format(widget.selectedDate),
        };
        String jsonString = jsonEncode(jsonData);
        print(jsonString);
      } else {
        setState(() {
          foodData = "데이터를 가져오는 중 오류가 발생했습니다.";
        });
      }
    } catch (e) {
      setState(() {
        foodData = "오류: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, String> menuPrices = {
      "부대찌개": "7000",
      "치즈부대찌개": "7500",
      "제주흑돼지김치찌개": "7000",
      "제주흑돼지스팸김치찌개": "7500",
      "제주흑돼지참치김치찌개": "7500",
      "설렁탕": "5000",
      "육회비빔밥": "7000",
      "삼겹살비빔밥": "7000",
      "쭈꾸미삼겹살비빔밥": "7500",
      "고추장불백비빔밥": "7000",
      "가라아게덮밥": "6500",
      "라면류": "2500~3500",
      "돈가스류": "4000~4200",
    };

    List<String> selectedMenuPrices = [];

    for (String menu in menuPrices.keys) {
      if (foodData.contains(menu)) {
        selectedMenuPrices.add("$menu: ${menuPrices[menu]}원");
      }
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48.0),
        child: AppBar(
          title: Column(
            children: [
              Text('분식당',
                  style: TextStyle(fontSize: 18.0, color: Colors.white)),
              Text(
                DateFormat('yyyy-MM-dd').format(widget.selectedDate),
                style: TextStyle(fontSize: 18.0, color: Colors.white),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(
                Icons.close,
                color: Colors.lightGreen,
              ),
              onPressed: () {
                // 닫기 버튼을 눌렀을 때 수행할 동작
                // 여기에 원하는 동작을 추가할 수 있습니다.
              },
            )
          ],
          elevation: 0,
          backgroundColor: Colors.lightGreen, // 여기에 추가
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20.0),
          const Divider(
            color: Colors.lightGreen,
            thickness: 3.0,
          ),
          const SizedBox(height: 20.0),
          Container(
            width: double.infinity,
            margin: EdgeInsets.symmetric(horizontal: 10.0),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.lightGreen,
                width: 2.0,
              ),
              color: Colors.white,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      foodData,
                      style: TextStyle(
                          fontSize: 16.0,
                          color: Colors.black,
                          fontWeight: FontWeight.normal),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: selectedMenuPrices
                        .map((item) => Text(item,
                            style:
                                TextStyle(fontSize: 16.0, color: Colors.black)))
                        .toList(),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
