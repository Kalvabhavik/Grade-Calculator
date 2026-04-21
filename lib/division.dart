import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import "dart:io";

class Super extends StatelessWidget {

  const Super({super.key,required this.s,required this.bu});

  final List<String> s;
  final List<String> bu;


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          elevation: 10,
          shadowColor: Colors.white60,
          leading:BackButton(
            color: Colors.white,
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(colors: [Colors.black,Colors.blue.shade900,Colors.blue.shade900,Colors.black])
            ),
          ),
          title:Center(child: Padding(
            padding: const EdgeInsets.fromLTRB(40,50,50,50),
            child: Text("Division",style: GoogleFonts.inconsolata(color:Colors.white,fontSize: MediaQuery.of(context).size.width>1000?MediaQuery.of(context).size.width*0.041:MediaQuery.of(context).size.width*0.098),),
          )),

        ),

        body: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(colors: [Colors.blue.shade900,Colors.black],
            radius: 0.63)
          ),
          height: double.infinity,
          width: double.infinity,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(35, 25, 8, 10),
                child: Row(
                  children: [
                    Container(
                      height:40,
                      width:100,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white),
                        borderRadius: BorderRadius.circular(50),
                          gradient: LinearGradient(colors: [Colors.black,Colors.blue.shade900,Colors.black]),
                        boxShadow: [BoxShadow(
                          blurRadius: 8,
                          spreadRadius: 1,
                          color: Colors.white,
                        )]
                      ),
                      child:Center(child: Text("DIVISION",style: TextStyle(color:Colors.white,fontSize: 18,),))
                    ),
                    SizedBox(
                      width:60
                    ),
                    Container(
                        height:40,
                        width:60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Colors.black,Colors.blue.shade900,Colors.black]),
                            border: Border.all(color: Colors.white),
                            borderRadius: BorderRadius.circular(50),
                          boxShadow: [BoxShadow(
                          blurRadius: 8,
                          spreadRadius: 1,
                          color: Colors.white,
                        )]
                    ),
                        child:Center(child: Text("%",style: TextStyle(color:Colors.white,fontSize: 18,),))
                    )
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  height: 400,
                  width: 400,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(3,0,8,0),
                    child: ListView.builder(
                      itemCount: s.length,
                      itemBuilder: (context,index){
                        return Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10,0,8,15),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white,
                                  ),
                                  borderRadius: BorderRadius.circular(20)
                                ),
                                height: 60,
                                width: 200,
                                child: Center(child: Text("${s[index]}",style: TextStyle(color: Colors.white,fontSize: 25),)),

                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Container(decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white,
                                  ),
                                  borderRadius: BorderRadius.circular(20)
                              ),

                                height: 50,
                                width: 80,
                                child: Center(child: Text("${bu[index]}",style: TextStyle(color:Colors.white),)),

                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
