import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";
import "package:pragnaleader/division.dart";
class dash extends StatefulWidget {

  const dash({super.key});


  @override
  State<dash> createState() => _dashState();
}

class _dashState extends State<dash> {
  TextEditingController _divcontroller=TextEditingController();
  TextEditingController _percontroller=TextEditingController();
  bool com=false;
  int buc=0;


  int count=0;

  int num=5;
  int b =4;
  int c=3;
  List<String> s=[];
  List<String> bu=[];


  @override
  Widget build(BuildContext context) {


    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home:Scaffold(
        backgroundColor: Colors.black87,

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
            child: Text("Dashboard",style: GoogleFonts.inconsolata(color:Colors.white,fontSize: MediaQuery.of(context).size.width>1000?MediaQuery.of(context).size.width*0.041:MediaQuery.of(context).size.width*0.098),),
          )),
          
        ),
        body:Container(
          height: double.infinity,
          width:double.infinity,
          decoration: BoxDecoration(
              image: DecorationImage(image: MediaQuery.of(context).size.width>1000?AssetImage("assets/pc.png"):AssetImage("assets/e.png"),fit: BoxFit.cover,
              ),
          ),
          child: ListView(
            children: [
              SizedBox(
                height: 30,
              ),
              Container(
                height: 50,
                width: 500,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    InkWell(onTap: (
                        ){
                      setState(() {
                        if(num!=0){
                        num=0;}
                        else{
                          num=5;
                        }
                      });
                    },
                      child: Container(
                        height: 50,
                        width: 85,
                        decoration: BoxDecoration(
                            color: num==0?Colors.white.withOpacity(0.4):Colors.blue.shade900.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(60),
                          border: Border.all(color:Colors.white)
                        ),
                        child:Center(child: Text("22-26",style:TextStyle(color:Colors.white,fontSize: 20)))
                      ),
                    ),
                    SizedBox(
                      width:25,
                    ),
                    InkWell(
                      onTap:(){
                        setState(() {
                          if(num!=1){
                            num=1;
                          }
                          else{
                            num=5;
                          }
                        });
                      },
                      child: Container(
                          height: 50,
                          width: 85,
                          decoration: BoxDecoration(
                              color: num==1?Colors.white.withOpacity(0.4):Colors.blue.shade900.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(60),
                              border: Border.all(color:Colors.white)
                          ),
                          child:Center(child: Text("23-27",style:TextStyle(color:Colors.white,fontSize: 20)))
                      ),
                    ),
                    SizedBox(
                      width:25,
                    ),
                    InkWell(
                      onTap:(){
                        setState(() {
                          if (num!=2){
                            num=2;
                          }
                          else{
                            num=5;
                          }
                        });
                      },
                      child: Container(
                          height: 50,
                          width: 85,
                          decoration: BoxDecoration(
                              color: num==2?Colors.white.withOpacity(0.4):Colors.blue.shade900.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(60),
                              border: Border.all(color:Colors.white)
                          ),
                          child:Center(child: Text("24-28",style:TextStyle(color:Colors.white,fontSize: 20)))
                      ),
                    ),
                    SizedBox(
                      width:25,
                    ),
                    InkWell(
                      onTap: (){
                        setState(() {
                          if (num!=3){
                            num=3;
                          }
                          else{
                            num=5;
                          }
                        });
                      },
                      child: Container(
                          height: 50,
                          width: 85,
                          decoration: BoxDecoration(
                              color: num==3?Colors.white.withOpacity(0.4):Colors.blue.shade900.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(60),
                              border: Border.all(color:Colors.white)
                          ),
                          child:Center(child: Text("25-29",style:TextStyle(color:Colors.white,fontSize: 20)))
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 20,
              ),
              Container(
                height: 30,
                width: double.infinity,
                color: Colors.transparent,
                child: num!=5?Container(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      InkWell(
                        onTap:(){
                          setState(() {
                            if(b!=0){
                              b=0;
                            }
                            else{
                              b=4;
                            }
                          });
                        },
                        child: Container(
                            height: 25,
                            width: 130,
                            decoration: BoxDecoration(
                                color: b==0?Colors.white.withOpacity(0.4):Colors.blue.shade900.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(60),
                                border: Border.all(color:Colors.white)
                            ),
                            child:Center(child: Text("CSE",style:TextStyle(color:Colors.white,fontSize: 20)))
                        ),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      InkWell(
                        onTap:(){
                          setState(() {
                            com=true;
                            if(b!=1){
                              b=1;
                            }
                            else{
                              b=4;
                              com=false;
                            }
                          });
                        },
                        child: Container(
                            height: 50,
                            width: 130,
                            decoration: BoxDecoration(
                                color: b==1?Colors.white.withOpacity(0.4):Colors.blue.shade900.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(60),
                                border: Border.all(color:Colors.white)
                            ),
                            child:Center(child: Text("ECE",style:TextStyle(color:Colors.white,fontSize: 20)))
                        ),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      InkWell(
                        onTap:(){
                          setState(() {
                            com=true;
                            if(b!=2){
                              b=2;
                            }
                            else{
                              b=4;
                              com=false;
                            }
                          });
                        },
                        child: Container(
                            height: 25,
                            width: 130,
                            decoration: BoxDecoration(
                                color: b==2?Colors.white.withOpacity(0.4):Colors.blue.shade900.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(60),
                                border: Border.all(color:Colors.white)
                            ),
                            child:Center(child: Text("DSAI",style:TextStyle(color:Colors.white,fontSize: 20)))
                        ),
                      ),
                    ],
                  ),
                ):Container(),
              ),
              SizedBox(
                height: 20,
              ),
              Container(
                height: 35,
                width: double.infinity,
                color: Colors.transparent,
                child: b==0&&num!=5?Container(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      InkWell(
                        onTap:(){
                          setState(() {
                            com=true;
                            if(c!=0){
                              c=0;
                            }
                            else{
                              c=3;
                              com=false;
                            }
                          });
                        },
                        child: Container(
                            height: 50,
                            width: 85,
                            decoration: BoxDecoration(
                                color: c==0?Colors.white.withOpacity(0.4):Colors.blue.shade900.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(60),
                                border: Border.all(color:Colors.white)
                            ),
                            child:Center(child: Text("CSE-A",style:TextStyle(color:Colors.white,fontSize: 20)))
                        ),
                      ),
                      SizedBox(width: 10,),
                      InkWell(
                        onTap:(){
                          setState(() {
                            com=true;
                            if(c!=1){
                              c=1;
                            }
                            else{
                              c=3;
                              com=false;
                            }
                          });
                        },
                        child: Container(
                            height: 50,
                            width: 85,
                            decoration: BoxDecoration(
                                color: c==1?Colors.white.withOpacity(0.4):Colors.blue.shade900.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(60),
                                border: Border.all(color:Colors.white)
                            ),
                            child:Center(child: Text("CSE-B",style:TextStyle(color:Colors.white,fontSize: 20)))
                        ),
                      ),
                      SizedBox(width: 10,),
                      InkWell(
                        onTap:(){
                          setState(() {
                            com=true;
                            if(c!=2){
                              c=2;
                            }
                            else{
                              c=3;
                              com=false;
                            }
                          });
                        },
                        child: Container(
                            height: 50,
                            width: 85,
                            decoration: BoxDecoration(
                                color: c==2?Colors.white.withOpacity(0.4):Colors.blue.shade900.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(60),
                                border: Border.all(color:Colors.white)
                            ),
                            child:Center(child: Text("BOTH",style:TextStyle(color:Colors.white,fontSize: 20)))
                        ),
                      ),
                    ],
                  ),
                ):Container(),
              ),
              SizedBox(
                height:35
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal:35,),
              child: com?Container(
                height:340,
                decoration: BoxDecoration(
                    color:Colors.white70,
                   border: Border.all(color:Colors.black26),
                  borderRadius: BorderRadius.circular(60),

                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0,vertical: 60),
                    child: ListView(
                      children: [

                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white,
                            ),
                            color: Colors.white54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                            child: Center(child: Text("No of Divisions You have done ${count}",style: GoogleFonts.acme(
                                  fontSize: 18,
                            ),))),
                        SizedBox(
                          height: 10,
                        ),
                        TextField(
                          controller: _divcontroller,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20)
                            ),
                            hintText:"Enter the division",
                          ),


                        ),
                        SizedBox(
                          height: 10,
                        ),
                        TextField(
                          controller: _percontroller,




                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20)
                            ),
                            hintText:"Enter the percentage for the division",
                          ),


                        ),
                        ElevatedButton(onPressed: (){
                          setState(() {




                            String div=_divcontroller.text;
                            String per=_percontroller.text;
                            buc+=int.parse(per);
                            count++;
                            s.add("$div");
                            bu.add("$per");
                            _divcontroller.text="";
                            _percontroller.text="";
                          });

                        }, child: Text("Next Division"))
                      ],
                    ),
                  ),
                ),
              ):Container(),
            ),
              Container(
                child: com?ElevatedButton(onPressed: (){
                  print(s);


                  setState(() {
                    if(buc==100||buc==20){
                    Navigator.push(context,MaterialPageRoute(builder: (BuildContext context)=>Super(s:s,bu:bu)));}
                    else{
                      _percontroller.text="$buc";
                    };
                  });

                }, child: Text("Next Step")):Container(),
              )




            ],
          ),
        )
      )
    );
  }
}

