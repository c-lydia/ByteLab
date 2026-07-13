import 'package:flutter/material.dart';

import '../widgets/byte_card.dart';
import '../widgets/metric_card.dart';

class TestPage extends StatelessWidget {
  const TestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xff080F17),
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            "BYTECARD TEST",
            style: TextStyle(
              color: Colors.white,
              fontSize:26,
              fontWeight:FontWeight.bold,
            ),
          ),
          const SizedBox(height:30),
          Row(
            children:[
              Expanded(
                child: MetricCard(
                  title:"CPU",
                  value:"42%",
                  subtitle:"+3% last minute",
                  icon:Icons.memory,
                  progress:0.42,
                ),
              ),
              const SizedBox(width:16),
              Expanded(
                child: MetricCard(
                  title:"RAM",
                  value:"128KB",
                  subtitle:"Free: 64KB",
                  icon:Icons.storage,
                  progress:0.65,
                ),
              ),
              const SizedBox(width:16),
              Expanded(
                child: MetricCard(
                  title:"FLASH",
                  value:"4MB",
                  subtitle:"Used: 72%",
                  icon:Icons.save,
                  progress:0.72,
                ),
              ),
            ],
          ),
          const SizedBox(height:30),
          ByteCard(
            title:"Serial Monitor",
            icon:Icons.terminal,
            trailing:IconButton(
              icon:const Icon(
                Icons.clear,
                color:Colors.grey
              ),
              onPressed:null,
            ),
            child:const Text(
              "> ESP32 Connected\n"
              "> Sensor initialized\n"
              "> Waiting for data...",
              style:TextStyle(
                color:Colors.white,
                fontFamily:"monospace"
              )
            )
          )
        ]
      )
    );
  }
}