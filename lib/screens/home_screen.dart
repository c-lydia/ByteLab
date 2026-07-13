import 'package:flutter/material.dart';

import '../widgets/action_tile.dart';
import '../widgets/byte_card.dart';
import '../widgets/device_header.dart';
import '../widgets/device_tile.dart';
import '../widgets/event_tile.dart';
import '../widgets/metric_chip.dart';


class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}


class _OverviewPageState extends State<OverviewPage> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (_, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(
                0,
                20 * (1-value),
              ),
              child: child,
            ),
          );
        },

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DeviceHeader(),
            const SizedBox(height:24),
            Wrap(
              spacing:12,
              runSpacing:12,
              children: [
                animatedChip(
                  MetricChip(
                    icon:Icons.memory,
                    title:"CPU",
                    value:"31%",
                  ),
                ),

                animatedChip(
                  MetricChip(
                    icon:Icons.storage,
                    title:"RAM",
                    value:"64 KB",
                  ),
                ),

                animatedChip(
                  MetricChip(
                    icon:Icons.sd_storage,
                    title:"FLASH",
                    value:"1.2 MB",
                  ),
                ),

                animatedChip(
                  MetricChip(
                    icon:Icons.thermostat,
                    title:"TEMP",
                    value:"36°C",
                  ),
                ),
              ],
            ),
            const SizedBox(height:24),

            animatedCard(
              ByteCard(
                title:"Telemetry",
                child: Container(
                  height:320,
                  decoration:BoxDecoration(
                    borderRadius:BorderRadius.circular(12),
                    gradient:const LinearGradient(
                      colors:[
                        Color(0xff0E1824),
                        Color(0xff101C29),
                      ],
                    ),
                  ),
                  child:Stack(
                    children:[
                      Positioned.fill(
                        child:CustomPaint(
                          painter:GridPainter(),
                        ),
                      ),

                      const Center(
                        child:Icon(
                          Icons.show_chart,
                          size:64,
                          color:Colors.white24,
                        ),
                      ),

                      const Positioned(
                        bottom:16,
                        left:16,
                        child:Text(
                          "Waiting for telemetry...",
                          style:TextStyle(
                            color:Colors.white54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height:24),
            Row(
              crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                Expanded(
                  flex:2,
                  child:animatedCard(
                    ByteCard(
                      title:"Events",
                      child:Column(
                        children:[
                          stagger(
                            const EventTile(
                              icon:Icons.usb,
                              color:Colors.greenAccent,
                              title:"Device Connected",
                              time:"Now",
                            ),
                            0,
                          ),
                          const SizedBox(height:12),
                          stagger(
                            const EventTile(
                              icon:Icons.build,
                              color:Colors.cyanAccent,
                              title:"Build Completed",
                              time:"2 min ago",
                            ),
                            100,
                          ),
                          const SizedBox(height:12),
                          stagger(
                            const EventTile(
                              icon:Icons.flash_on,
                              color:Colors.orangeAccent,
                              title:"Firmware Flashed",
                              time:"5 min ago",
                            ),
                            200,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width:20),
                Expanded(
                  child:animatedCard(
                    ByteCard(
                      title:"Quick Actions",
                      child:Column(
                        children:[
                          MouseRegion(
                            cursor:SystemMouseCursors.click,
                            child:ActionTile(
                              icon:Icons.build,
                              title:"Build",
                              subtitle:"Compile firmware",
                              onTap:(){},
                            ),
                          ),
                          const SizedBox(height:12),
                          MouseRegion(
                            cursor:SystemMouseCursors.click,
                            child:ActionTile(
                              icon:Icons.flash_on,
                              title:"Flash",
                              subtitle:"Upload firmware",
                              onTap:(){},
                            ),
                          ),
                          const SizedBox(height:12),
                          MouseRegion(
                            cursor:SystemMouseCursors.click,
                            child:ActionTile(
                              icon:Icons.terminal,
                              title:"Monitor",
                              subtitle:"Open serial console",
                              onTap:(){},
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height:20),
            Row(
              crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                Expanded(
                  child:animatedCard(
                    ByteCard(
                      title:"Connected Devices",
                      child:Column(
                        children:[
                          stagger(
                            const DeviceTile(
                              name:"ESP32 Main",
                              status:"/dev/ttyUSB0",
                            ),
                            0,
                          ),
                          stagger(
                            const DeviceTile(
                              name:"STM32 Motor",
                              status:"/dev/ttyUSB1",
                            ),
                            150,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width:20),
                Expanded(
                  child:animatedCard(
                    ByteCard(
                      title:"Build Status",
                      child:Column(
                        crossAxisAlignment:CrossAxisAlignment.start,
                        children:[
                          const Text(
                            "Release Build",
                            style:TextStyle(
                              color:Colors.white,
                            ),
                          ),
                          const SizedBox(height:16),
                          TweenAnimationBuilder<double>(
                            tween:Tween(
                              begin:0,
                              end:.72,
                            ),
                            duration:const Duration(
                              milliseconds:1200,
                            ),
                            builder:(_,value,__){
                              return ClipRRect(
                                borderRadius:
                                BorderRadius.circular(6),
                                child:LinearProgressIndicator(
                                  value:value,
                                  minHeight:8,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height:12),
                          const Text(
                            "Compiling motor_controller.cpp",
                            style:TextStyle(
                              color:Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height:40),
          ],
        ),
      ),
    );
  }

  Widget animatedChip(Widget child){
    return TweenAnimationBuilder<double>(
      tween:Tween(
        begin:.95,
        end:1,
      ),
      duration:const Duration(
        milliseconds:250,
      ),
      curve:Curves.easeOutBack,
      builder:(_,scale,child){
        return Transform.scale(
          scale:scale,
          child:child,
        );
      },
      child:child,
    );
  }

  Widget animatedCard(Widget child){
    return TweenAnimationBuilder<double>(
      tween:Tween(
        begin:0,
        end:1,
      ),
      duration:const Duration(
        milliseconds:600,
      ),
      curve:Curves.easeOutQuart,
      builder:(_,value,child){
        return Opacity(
          opacity:value,
          child:Transform.scale(
            scale:.97 + value*.03,
            child:child,
          ),
        );
      },
      child:child,
    );
  }

  Widget stagger(
    Widget child,
    int delay,
  ){
    return TweenAnimationBuilder<double>(
      tween:Tween(
        begin:0,
        end:1,
      ),
      duration:Duration(
        milliseconds:500 + delay,
      ),
      curve:Curves.easeOutCubic,
      builder:(_,value,child){
        return Opacity(
          opacity:value,
          child:Transform.translate(
            offset:Offset(
              0,
              20*(1-value),
            ),
            child:child,
          ),
        );
      },
      child:child,
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size){
    final paint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1;
    const gap = 32.0;
    for(double x=0; x<size.width; x+=gap){
      canvas.drawLine(
        Offset(x,0),
        Offset(x,size.height),
        paint,
      );
    }
    for(double y=0; y<size.height; y+=gap){
      canvas.drawLine(
        Offset(0,y),
        Offset(size.width,y),
        paint,
      );
    }
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate)=>false;
}