import 'package:flutter/material.dart';

import '../core/byte_color.dart';

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final double? progress;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
    this.progress
  });

  @override
  Widget build(BuildContext context){
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ByteColor.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ByteColor.border
        )
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xff132738),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: Colors.cyanAccent
                )
              ),
              if(progress != null)
                Text(
                  "${(progress! * 100).toInt()}%",
                  style: const TextStyle(
                    color: ByteColor.secondsaryText,
                    fontSize: 12
                  )
                )
            ]
          ),
          const SizedBox(height: 18),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: ByteColor.secondsaryText,
              fontSize: 11,
              letterSpacing: 1.5
            )
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold
            )
          ),
          if(subtitle != null)...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 11
              )
            )
          ],
          if(progress != null)...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xff172A3A),
              color: Colors.cyanAccent,
              minHeight: 4
            )
          ]
        ]
      )
    );
  }
}