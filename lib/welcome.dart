import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login.dart';
import 'package:lottie/lottie.dart';
class hii extends StatefulWidget {
  const hii({super.key});

  @override
  State<hii> createState() => _hiiState();
}

class _hiiState extends State<hii> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Container(
          height: double.infinity,
          width: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(image: MediaQuery.of(context).size.width>1000?AssetImage("pc.png"):AssetImage("assets/e.png"),fit: BoxFit.cover)
          ),
          child:
                SafeArea(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(
                          height:40,
                        ),
                        Container(
                          height:100,
                          width:400,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),

                            color:Colors.transparent.withOpacity(0.01),
                          ),
                          child: Center(child: Text("        GRADE \n CALCULATOR",style: GoogleFonts.alegreya(color: Colors.white,fontSize:33,fontWeight: FontWeight.bold ))),
                        ),
                         SizedBox(
                           height:90-50
                         ),
                        CircleAvatar(
                          radius: 100,
                            backgroundImage:AssetImage("assets/hii.png"),
                          
                        ),
                        SizedBox(
                          height: 100-30,
                        ),
                        FittedBox(
                          child: InkWell(
                            splashColor: Colors.white,
                            onTap: (){
                             Navigator.push(context, MaterialPageRoute(builder: (context)=>mee()));
                            },
                            child: Container(
                              height: 50,
                              width: 230,
                              child: Center(
                                child: Text("G e t   S t a r t e d",style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold ,
                                  fontSize: 19,
                                ),),
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(


                                  color: Colors.white,
                                ),
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(100),
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                )
        
        ),
      ),
    );
  }
}
