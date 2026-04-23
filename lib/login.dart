import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math';
import "dashboard.dart";

import 'package:emailjs/emailjs.dart' as emailjs;
import 'dart:math';

void main() {
  runApp(mee());
}

class mee extends StatefulWidget {
  const mee({super.key});

  @override
  State<mee> createState() => _meeState();
}

class _meeState extends State<mee> with TickerProviderStateMixin{
  late AnimationController _controller;
  late AnimationController _donecont;
  TextEditingController _email=TextEditingController();
  TextEditingController _otp=TextEditingController();
  String generatedOtp = (Random().nextInt(9000) + 1000).toString();



  @override
  void initState() {
    super.initState();

    _controller=AnimationController(vsync: this,duration: Duration.zero);
    _donecont=AnimationController(vsync: this,duration: Duration.zero);
    _donecont.addStatusListener((status){
      if(status==AnimationStatus.completed){
        Navigator.pop(context);
      }
    });


  }
  @override
  void dispose() {
    _donecont.dispose();
    _controller.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      home: Scaffold(
        body: Container(

          height: double.infinity,
          width: double.infinity,
          decoration: BoxDecoration(
              image: DecorationImage(image: MediaQuery.of(context).size.width>1000?AssetImage("assets/pc.png"):AssetImage("assets/e.png"),fit: BoxFit.cover)
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    children: [
                      BackButton(
                        onPressed: (){
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  SizedBox(
                    height:100+30,
                  ),
                  Text("H i  T h e r e !",style: GoogleFonts.ebGaramond(
                    fontSize: 45,
              
                    color: Colors.white,
                  ),),
                  SizedBox(
                    height:100-30,
                  ),
              
                  Padding(
                    padding: const EdgeInsets.fromLTRB(15,0,10,0),
                    child: Container(
                      height: 40,
                      width:double.infinity,
                      decoration:BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(100),
                          border:Border.all(
                            color:Colors.white54,
                          )
              
                      ) ,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12,0,0,0),
                        child: TextField(
                          style: GoogleFonts.slabo27px(
                            fontSize:18.5,
                            color: Colors.white,
                          ),
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                              border: InputBorder.none,
              
              
              
                              prefix: Container(
                                width: 50,
                                child: Row(
                                    children: [
                                      Icon(Icons.email_outlined,color: Colors.white70),
                                      SizedBox(width: 10,),
                                      Text("|"),
                                    ]
                                ),
                              ),
                              hintText: "Enter your Email id",
                              hintStyle: TextStyle(
                                color: Colors.white,
                              )
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height:10,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white10,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        onPressed: () async {
              
                          showAdaptiveDialog(context: context, builder:(BuildContext context){
                            return Dialog(
                              backgroundColor: Colors.transparent,
                              child:Padding(
                                padding: const EdgeInsets.all(50.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                      color:Colors.white,
                                    borderRadius: BorderRadius.circular(50),
              
                                  ),
                                  height:180,
                                  width: 70,
                                  child:Lottie.asset("assets/otp.json",repeat: true,controller: _controller,onLoaded: (c){
                                    _controller.duration=c.duration;
                                    _controller.forward();
              
                                  })
                                ),
                              )
                            );
                          });
              
                          if (_email.text.trim().isEmpty || !_email.text.contains("@")) {
                            print(" Please enter a valid email address.");
                            return;
                          }
              



                          print("Attempting to send OTP to: ${_email.text.trim()}");
              
              
                          final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
              
                          try {
                            final response = await http.post(
                              url,
                              headers: {
                                'origin': 'http://localhost',
                                'Content-Type': 'application/json',
                              },
                              body: json.encode({
                                'service_id': 'service_6jsjjec',
                                'template_id': 'template_7xu6zwj',
                                'user_id': 'M8VZdJ98YyGSxse7o',
                                'template_params': {
                                  'email': _email.text.trim(),
                                  'passcode': generatedOtp,
                                }
                              }),
                            );
              
              
                            if (response.statusCode == 200) {
                              print("Notification Sent");
                              Navigator.pop(context);
                            } else {
                              print("❌ Failed with status: ${response.statusCode}");
                              print("❌ Error Details: ${response.body}");
                            }
                          } catch (error) {
                            print("❌ Network Error: $error");
                          }
                        },
              
              
                        child: Container(
                          child: Center(child: Text("SEND OTP",style: TextStyle(
                            color: Colors.white70,
                          ),)),
                        ),
                      )
              
                    ],
                  ),
              
                  Padding(
                    padding: const EdgeInsets.fromLTRB(15,0,10,0),
                    child: Container(
                      height: 40,
                      width:double.infinity,
                      decoration:BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(100),
                          border:Border.all(
                            color:Colors.white54,
                          )
              
                      ) ,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12,0,0,0),
                        child: TextField(
                          controller: _otp,
                          style: GoogleFonts.aboreto(
                            color: Colors.white60,
                          ),
                          onSubmitted: (val) {
                            // Validate OTP on keyboard submit — same logic as LOGIN button
                            if (val.trim() == generatedOtp) {
                              showAdaptiveDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return Dialog(
                                    backgroundColor: Colors.transparent,
                                    child: Container(
                                      height: 140,
                                      width: 120,
                                      child: Lottie.asset(
                                        "assets/done.json",
                                        controller: _donecont,
                                        onLoaded: (c) {
                                          _donecont.duration = c.duration;
                                          _donecont.forward();
                                        },
                                      ),
                                    ),
                                  );
                                },
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('❌ Incorrect OTP. Please try again.'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          },
              
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                              border: InputBorder.none,
              
              
              
              
                              prefix: Container(
                                width: 44,
                                child: Row(
                                    children: [
                                      Icon(Icons.key,color: Colors.white70),
                                      SizedBox(width: 10,),
                                      Text("|"),
                                    ]
                                ),
                              ),

              
                              hintText: "Enter your 4 Digit OTP",
                              hintStyle: GoogleFonts.slabo27px(
                            fontSize:18,
                            color: Colors.white,
                          ),
                          )

                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height:70,
                  ),
              
                  InkWell(
                    onTap: ()  {

                      if(_otp.text.trim().isEmpty || _otp.text.trim().toString()!=generatedOtp){

                        showAdaptiveDialog(context: context, builder: (BuildContext context){
                          return Dialog(
                            backgroundColor: Colors.transparent,
                            child:Padding(
                              padding: const EdgeInsets.all(50.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color:Colors.transparent,
                                  borderRadius: BorderRadius.circular(50),),
                                    child: Column(
                                      children: [

                                        Lottie.asset("assets/error.json"),
                                      ],
                                    ),
                              ))
              
                          );
              
                        }
                        );
              
              
              
                      }
                      if (_otp.text.trim() == generatedOtp) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => dash()),
                        );
                      }
              
                      },
                    child: Container(
                      width: 160,
                      height: 50,
                      child:Center(child: Text("L O G I N",style:TextStyle(color:Colors.black87,fontSize: 19),)),
                      decoration: BoxDecoration(
                        borderRadius:BorderRadius.circular(100),
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade900,Colors.white],
                        ),
                        boxShadow:[BoxShadow(
                          color:Colors.white60,
                          spreadRadius: 2,
                          blurRadius:2,
                          offset: Offset(7,2)
                      )]
                    ),
              
                      ),

                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
