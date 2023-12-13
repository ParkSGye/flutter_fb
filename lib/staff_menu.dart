import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:intl/intl.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyListWidget2(selectedDate: DateTime.now()),
      theme: ThemeData(
        appBarTheme: AppBarTheme(
          color: Colors.transparent,
          toolbarTextStyle: TextTheme(
            headline6: TextStyle(
              color: Colors.brown,
              fontSize: 10.0,
            ),
          ).bodyText2,
          titleTextStyle: TextTheme(
            headline6: TextStyle(
              color: Colors.brown,
              fontSize: 25.0,
            ),
          ).headline6,
        ),
      ),
    );
  }
}

class MyListWidget2 extends StatefulWidget {
  final DateTime selectedDate;

  MyListWidget2({required this.selectedDate});

  @override
  State<StatefulWidget> createState() {
    return _MyListWidgetState();
  }
}

class _MyListWidgetState extends State<MyListWidget2> {
  String lunchData = "로딩 중..."; // 상단 컨테이너 데이터
  String dinnerData = "로딩 중..."; // 하단 컨테이너 데이터

  @override
  void initState() {
    super.initState();
    fetchMenuData();
  }

  void fetchMenuData() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://www.kumoh.ac.kr/ko/restaurant02.do?mode=menuList&srDt=${DateFormat('yyyy').format(widget.selectedDate)}-${DateFormat('MM').format(widget.selectedDate)}-${DateFormat('dd').format(widget.selectedDate)}',
        ),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36',
        },
      );

      if (response.statusCode == 200) {
        final document = parse(response.body);
        final lunchElements = document.querySelectorAll(
            ".menu-list-box table tbody tr:nth-child(1) td:nth-child(${widget.selectedDate.weekday * 2 - 1})");
        final dinnerElements = document.querySelectorAll(
            ".menu-list-box table tbody tr:nth-child(3) td:nth-child(${widget.selectedDate.weekday * 2 - 1})");

        if (lunchElements.isNotEmpty) {
          final breakfastMenu = lunchElements[0].text;
          final modifiedBreakfastMenu = breakfastMenu
              .replaceAll(RegExp(r'\s{2,}'), '\n')
              .replaceAll('중식', '')
              .replaceAll('[정식: 5500원]', '')
              .trim(); // "중식" 및 "정식" 삭제
          setState(() {
            lunchData = modifiedBreakfastMenu;
          });
        } else {
          setState(() {
            lunchData = "데이터가 존재하지 않습니다.";
          });
        }

        if (dinnerElements.isNotEmpty) {
          final lunchMenu = dinnerElements[0].text;
          final modifiedLunchMenu = lunchMenu
              .replaceAll(RegExp(r'\s{2,}'), '\n')
              .replaceAll('석식', '')
              .replaceAll('[정식: 5500원]', '')
              .trim(); // "석식" 및 "정식" 삭제
          setState(() {
            dinnerData = modifiedLunchMenu;
          });
        } else {
          setState(() {
            dinnerData = "데이터가 존재하지 않습니다.";
          });
        }

        // Convert menu data to JSON format
        Map<String, dynamic> jsonData = {
          'lunchData': lunchData,
          'dinnerData': dinnerData,
          'selectedDate': DateFormat('yyyy-MM-dd').format(widget.selectedDate),
        };
        String jsonString = jsonEncode(jsonData);
        print(jsonString);
      } else {
        setState(() {
          lunchData = "데이터를 가져오는 중 오류가 발생했습니다.";
          dinnerData = "데이터를 가져오는 중 오류가 발생했습니다.";
        });
      }
    } catch (e) {
      setState(() {
        lunchData = "오류: $e";
        dinnerData = "오류: $e";
      });
    }
  }

  Widget _buildPriceWidget(String price,
      {double fontSize = 16.0, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        price,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal, // 폰트 굵기 설정
          color: Colors.black,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(48.0),
        child: AppBar(
          title: Column(
            children: [
              Text('교직원식당',
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
              icon: Icon(
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
          backgroundColor:
              Colors.lightGreen, // 이 부분을 추가하여 AppBar의 배경색을 녹색으로 변경합니다.
        ),
      ),
      body: Column(
        children: [
          SizedBox(height: 20.0),
          Container(
            width: double.infinity,
            height: 250.0,
            margin: EdgeInsets.symmetric(horizontal: 10.0),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.lightGreen,
                width: 2.0,
              ),
              color: Colors.white,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPriceWidget("중식", fontSize: 20.0, isBold: true),
                    _buildPriceWidget("5500원", fontSize: 20.0, isBold: true),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        lunchData,
                        style: TextStyle(fontSize: 16.0, color: Colors.black),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.0),
          Divider(
            color: Colors.lightGreen,
            thickness: 3.0,
          ),
          SizedBox(height: 20.0),
          Container(
            width: double.infinity,
            height: 250.0,
            margin: EdgeInsets.symmetric(horizontal: 10.0),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.lightGreen,
                width: 2.0,
              ),
              color: Colors.white,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPriceWidget("석식", fontSize: 20.0, isBold: true),
                    _buildPriceWidget("5500원", fontSize: 20.0, isBold: true),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        dinnerData,
                        style: TextStyle(fontSize: 16.0, color: Colors.black),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
