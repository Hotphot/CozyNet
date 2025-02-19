import 'package:flutter/material.dart';

Widget buildControlTile(IconData icon, String label, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[850],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: Colors.white),
          SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 14, color: Colors.white)),
        ],
      ),
    ),
  );
}
