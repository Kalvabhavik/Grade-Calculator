import "package:flutter/material.dart";
import 'login.dart';
import 'welcome.dart';
void main() => runApp(myapp());

class myapp extends StatefulWidget {
  const myapp({super.key});

  @override
  State<myapp> createState() => _myappState();
}

class _myappState extends State<myapp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
     title:"Grade Calculator",
      debugShowCheckedModeBanner: false,
      home: hii(),
    );
  }
}

