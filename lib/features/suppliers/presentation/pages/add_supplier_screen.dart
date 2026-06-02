import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:toastification/toastification.dart';
import '../../../../core/theme/app_colors.dart';

class AddSupplierScreen extends StatefulWidget {
  const AddSupplierScreen({super.key});

  @override
  State<AddSupplierScreen> createState() => _AddSupplierScreenState();
}

class _AddSupplierScreenState extends State<AddSupplierScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  bool _isSaving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final dio = Dio();
      final resp = await dio.post(
        'https://pos-backend.posai.workers.dev/api/suppliers',
        data: {
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'phone_num': _phoneCtrl.text.trim(),
          'address': _addressCtrl.text.trim(),
        },
      );
      final data = resp.data;
      if (data != null && data['success'] == true) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.flatColored,
          title: Text('Supplier added', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          description: Text(_nameCtrl.text.trim(), style: GoogleFonts.inter()),
          alignment: Alignment.topCenter,
          autoCloseDuration: const Duration(seconds: 3),
          showProgressBar: true,
        );
        Navigator.of(context).pop(true);
      } else {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.flatColored,
          title: Text('Error', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          description: Text(data?['error'] ?? 'Failed to add supplier', style: GoogleFonts.inter()),
          alignment: Alignment.topCenter,
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.flatColored,
        title: Text('Error', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        description: Text('$e', style: GoogleFonts.inter()),
        alignment: Alignment.topCenter,
        autoCloseDuration: const Duration(seconds: 4),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: const BoxDecoration(color: Colors.black, boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 15, offset: Offset(0,10))]),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
              const SizedBox(width: 24),
              Text('Add Supplier', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
              const Spacer(),
              _isSaving ? const SizedBox(width:24,height:24,child:CircularProgressIndicator(color: Colors.white,strokeWidth:2)) : ElevatedButton(onPressed: _save, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black), child: Text('Save'))
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                padding: const EdgeInsets.all(40),
                child: Form(
                  key: _formKey,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Supplier Details', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87)),
                      const SizedBox(height: 12),
                      TextFormField(controller: _nameCtrl, decoration: InputDecoration(labelText: 'Name', filled: true, fillColor: Colors.white, prefixIcon: const Icon(Icons.person)), validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null),
                      const SizedBox(height: 12),
                      TextFormField(controller: _emailCtrl, decoration: InputDecoration(labelText: 'Email', filled: true, fillColor: Colors.white, prefixIcon: const Icon(Icons.email)), keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 12),
                      TextFormField(controller: _phoneCtrl, decoration: InputDecoration(labelText: 'Phone', filled: true, fillColor: Colors.white, prefixIcon: const Icon(Icons.phone)), keyboardType: TextInputType.phone),
                      const SizedBox(height: 12),
                      TextFormField(controller: _addressCtrl, decoration: InputDecoration(labelText: 'Address', filled: true, fillColor: Colors.white, prefixIcon: const Icon(Icons.location_on)), maxLines: 3),
                    ])),
                  ]),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
