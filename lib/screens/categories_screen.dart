import 'package:flutter/material.dart';

import 'restaurants_screen.dart';


class CategoriesScreen extends StatelessWidget {

  final String title;
  final String image;
  final String description;


  const CategoriesScreen({

    super.key,

    required this.title,

    required this.image,

    required this.description,

  });


  @override
  Widget build(BuildContext context) {


    return Scaffold(

      appBar: AppBar(

        title: Text(title),

        centerTitle:true,

        backgroundColor:Colors.black,

      ),


      body: Column(

        children:[


          Image.asset(

            image,

            height:200,

            width:double.infinity,

            fit:BoxFit.cover,

          ),


          Padding(

            padding:const EdgeInsets.all(20),

            child:Text(

              description,

              style:const TextStyle(

                fontSize:18,

              ),

            ),

          ),



          ElevatedButton(

            onPressed:(){

              Navigator.push(

                context,

                MaterialPageRoute(

                  builder:(context)=>const RestaurantsScreen(),

                ),

              );

            },


            child:const Text(

              "عرض المطاعم",

            ),

          ),


        ],

      ),

    );


  }

}