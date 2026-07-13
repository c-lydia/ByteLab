import 'package:flutter/material.dart';

class FirmwareNavRail extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onChanged;

  const FirmwareNavRail({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  State<FirmwareNavRail> createState() => _FirmwareNavRailState();

}

class _FirmwareNavRailState extends State<FirmwareNavRail> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose(){
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context){
    return Container(
      width:240,
      decoration: const BoxDecoration(
        color:Color(0xff080F17),
        border:Border(right:BorderSide(color:Color(0xff172A3A))),
      ),
      child:Column(
        children:[
          _buildHeader(),
          Expanded(
            child:Scrollbar(
              controller:_scrollController,
              thumbVisibility:true,
              child:ListView(
                controller:_scrollController,
                padding:EdgeInsets.zero,
                children:[
                  _section("WORKSPACE"),
                  _item(Icons.dashboard_outlined, "Overview", 0),
                  _item(Icons.folder_open, "Project", 1),
                  _section("FIRMWARE"),
                  _item(Icons.build_circle_outlined, "Build", 2),
                  _item(Icons.bolt_outlined, "Flash", 3,),
                  _item(Icons.terminal, "Monitor", 4),
                  _section("TOOLS"),
                  _item(Icons.tune, "Configuration", 5),
                  _item(Icons.memory, "Diagnostics", 6),
                  _item(Icons.hub_outlined, "Protocol", 7),
                  _item(Icons.menu_book_outlined, "Documentation", 8),
                  _section("SYSTEM"),
                  _item(Icons.settings_outlined, "Settings", 9),
                  const SizedBox(height:20)
                ],
              ),
            ),
          ),
          _buildDeviceCard(),
          const SizedBox(height: 15),
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding:const EdgeInsets.only(left: 22, top: 15, bottom: 8),
      child:Align(
        alignment:Alignment.centerLeft,
        child:Text(
          title,
          style:const TextStyle(
            color:Colors.grey,
            fontSize: 11,
            letterSpacing: 1.5,
            fontWeight:FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _item(IconData icon, String text, int index) {
    final active = widget.selectedIndex == index;

    return AnimatedContainer(
      duration:
      const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 3
      ),
      decoration:BoxDecoration(
        borderRadius:
        BorderRadius.circular(10),
        color:active? const Color(0xff132738): Colors.transparent,
        border:active? const Border(left:BorderSide(color: Colors.cyanAccent, width: 3)): null,
      ),
      child: InkWell(
        borderRadius:
        BorderRadius.circular(10),
        onTap: () {
          widget.onChanged(index);
        },
        child: Padding(
          padding:const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 21,
                color: active? Colors.cyanAccent: Colors.blueGrey
              ),
              const SizedBox(width: 14),
              Text(
                text,
                style:TextStyle(
                  color: active? Colors.white: Colors.blueGrey,
                  fontWeight:active? FontWeight.bold: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(){
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 35),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: [Colors.cyanAccent, Color(0xff7C3AED),],
              ),
            ),
            child: const Icon(Icons.memory, color: Colors.black,),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "BYTE",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                "LAB",
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(){
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff101C29),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.circle,
            size: 10,
            color: Colors.greenAccent,
          ),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "ESP32 ONLINE",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "/dev/ttyUSB0",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}