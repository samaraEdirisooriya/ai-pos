import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:toastification/toastification.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/active_scanner.dart';
import '../../../../core/services/scan_broadcast.dart';
import '../../data/models/stock_item.dart';
import '../../data/models/supplier.dart';
import '../bloc/stocks_bloc.dart';
import '../bloc/stocks_event.dart';
import '../bloc/stocks_state.dart';

class AddStockScreen extends StatefulWidget {
  final StockItem stockItem;
  final StocksBloc bloc;

  const AddStockScreen({
    super.key,
    required this.stockItem,
    required this.bloc,
  });

  @override
  State<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends State<AddStockScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityCtrl = TextEditingController();
  final _supplierCtrl = TextEditingController();
  final _retailPriceCtrl = TextEditingController();
  final _sellingPriceCtrl = TextEditingController();
  
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _supplierFocusNode = FocusNode();
  
  late StockItem _currentStockItem = widget.stockItem;
  Supplier? _selectedSupplier;
  List<Supplier> _suppliers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _sellingPriceCtrl.text = _currentStockItem.sellingValue.toStringAsFixed(2);
    _loadSuppliers();
    // Listen for external scan events to update selected product
    ScanBroadcast.stream.listen((item) async {
      if (mounted) {
        // Optionally reload suppliers if needed, or just reset to guest
        setState(() {
          _currentStockItem = item;
          _quantityCtrl.clear();
          _retailPriceCtrl.clear();
          _sellingPriceCtrl.text = item.sellingValue.toStringAsFixed(2);
          // Reset supplier to guest/default
          if (_suppliers.isNotEmpty) {
            _selectedSupplier = _suppliers.first;
          }
        });
        // Optionally, unfocus all fields
        FocusScope.of(context).unfocus();
        toastification.show(
          context: context,
          type: ToastificationType.info,
          style: ToastificationStyle.flatColored,
          title: Text('Scanned', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          description: Text('Switched to ${item.name}', style: GoogleFonts.inter()),
          alignment: Alignment.topCenter,
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    });
  }

  Future<void> _loadSuppliers() async {
    final list = await widget.bloc.fetchSuppliers();
    setState(() {
      _suppliers = [
        Supplier(supplierId: 'guest', name: 'Guest Supplier'),
        ...list,
      ];
      _selectedSupplier = _suppliers.first; // Default to Guest
    });
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final int qty = int.parse(_quantityCtrl.text.trim());
      final double retail = double.tryParse(_retailPriceCtrl.text.trim()) ?? 0;
      final double selling = double.tryParse(_sellingPriceCtrl.text.trim()) ?? 0;
      
      widget.bloc.add(AddStock(
        productId: _currentStockItem.productId, 
        quantity: qty,
        supplierId: _selectedSupplier?.supplierId == 'guest' ? null : _selectedSupplier?.supplierId,
        retailPrice: retail,
        sellingPrice: selling,
      ));
    }
  }

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _supplierCtrl.dispose();
    _retailPriceCtrl.dispose();
    _sellingPriceCtrl.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _supplierFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.bloc,
      child: BlocListener<StocksBloc, StocksState>(
        listener: (context, state) {
          if (state is StockAddError) {
            setState(() => _isLoading = false);
            toastification.show(
              context: context,
              type: ToastificationType.error,
              style: ToastificationStyle.flatColored,
              title: Text('Error adding stock', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              description: Text(state.message, style: GoogleFonts.inter()),
              alignment: Alignment.topCenter,
              autoCloseDuration: const Duration(seconds: 4),
              showProgressBar: true,
            );
          } else if (state is StockAddSuccess) {
            setState(() => _isLoading = false);
            toastification.show(
              context: context,
              type: ToastificationType.success,
              style: ToastificationStyle.flatColored,
              title: Text('Success!', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              description: Text(state.message, style: GoogleFonts.inter()),
              alignment: Alignment.topCenter,
              autoCloseDuration: const Duration(seconds: 4),
              showProgressBar: true,
            );
            Navigator.of(context).pop();
          } else if (state is StockAddLoading) {
            setState(() => _isLoading = true);
          }
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              // Futuristic Minimal Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 15,
                      offset: Offset(0, 10),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Text('Add Stock',
                        style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: Colors.white)),
                    const SizedBox(width: 32),
                    // Dropdown Search Bar for Products
                    Expanded(
                      child: BlocBuilder<StocksBloc, StocksState>(
                        builder: (context, state) {
                          List<StockItem> availableStocks = [];
                          if (state is StocksLoaded) {
                            availableStocks = state.stocks;
                          } else if (state is StockAddLoading) {
                            availableStocks = state.currentStocks;
                          }
                          return RawAutocomplete<StockItem>(
                            textEditingController: _searchController,
                            focusNode: _searchFocusNode,
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return const Iterable<StockItem>.empty();
                              }
                              return availableStocks.where((StockItem option) {
                                return option.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) || 
                                       option.productKey.toLowerCase().contains(textEditingValue.text.toLowerCase());
                              });
                            },
                            onSelected: (StockItem selection) {
                              _searchController.clear();
                              _searchFocusNode.unfocus();
                              setState(() {
                                _currentStockItem = selection;
                                _sellingPriceCtrl.text = selection.sellingValue.toStringAsFixed(2);
                              });
                            },
                            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                style: GoogleFonts.inter(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Search or scan product...',
                                  hintStyle: GoogleFonts.inter(color: Colors.white54),
                                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.1),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                              );
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 8,
                                  color: AppColors.secondary,
                                  borderRadius: BorderRadius.circular(12),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxHeight: 250, maxWidth: 400),
                                    child: ListView.builder(
                                      padding: const EdgeInsets.all(8),
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      itemBuilder: (BuildContext context, int index) {
                                        final StockItem option = options.elementAt(index);
                                        return InkWell(
                                          onTap: () => onSelected(option),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.inventory_2_outlined, color: Colors.white54, size: 20),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(option.name, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                                                      Text(option.productKey, style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 32),
                    if (_isLoading)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    else
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _submit,
                        child: Text('Save Stock', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                      ),
                  ],
                ),
              ),
              
              // Responsive Form Content
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 800),
                      padding: const EdgeInsets.all(40),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product Detail Section
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: _currentStockItem.productUrl.isNotEmpty
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: CachedNetworkImage(
                                                imageUrl: _currentStockItem.productUrl,
                                                fit: BoxFit.cover,
                                                placeholder: (c, u) => Container(color: Colors.grey.shade200),
                                                errorWidget: (c, u, e) => const Icon(Icons.image, size: 40, color: Colors.grey),
                                              ),
                                            )
                                          : const Icon(Icons.image, size: 40, color: Colors.grey),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _currentStockItem.name,
                                          style: GoogleFonts.inter(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.black87),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'QR Code: ${_currentStockItem.productKey}',
                                          style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade600),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Current Live Stock: ${_currentStockItem.liveStockCount}',
                                          style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.blueAccent.shade700),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Selling Price: LKR ${_currentStockItem.sellingValue.toStringAsFixed(2)}',
                                          style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            // Input Section
                            Text('Register Stock Entry',
                                style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87)),
                            const SizedBox(height: 24),
                            
                            // Form Fields
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Expanded(
                                          child: RawAutocomplete<Supplier>(
                                            textEditingController: _supplierCtrl,
                                            focusNode: _supplierFocusNode,
                                            optionsBuilder: (TextEditingValue textEditingValue) {
                                              if (textEditingValue.text.isEmpty) return const Iterable<Supplier>.empty();
                                              return _suppliers.where((s) => s.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                                            },
                                            displayStringForOption: (s) => s.name,
                                            onSelected: (Supplier selection) {
                                              setState(() {
                                                _selectedSupplier = selection;
                                                _supplierCtrl.text = selection.name;
                                              });
                                            },
                                            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                              return TextFormField(
                                                controller: controller,
                                                focusNode: focusNode,
                                                decoration: InputDecoration(
                                                  labelText: 'Supplier',
                                                  labelStyle: GoogleFonts.inter(color: Colors.grey.shade600),
                                                  filled: true,
                                                  fillColor: Colors.grey.shade50,
                                                  prefixIcon: const Icon(Icons.business_outlined, color: Colors.black54),
                                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black, width: 2)),
                                                ),
                                                validator: (val) => (val == null || val.isEmpty) ? 'Supplier is required' : null,
                                              );
                                            },
                                            optionsViewBuilder: (context, onSelected, options) {
                                              return Align(
                                                alignment: Alignment.topLeft,
                                                child: Material(
                                                  elevation: 8,
                                                  color: AppColors.secondary,
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: ConstrainedBox(
                                                    constraints: const BoxConstraints(maxHeight: 200, maxWidth: 400),
                                                    child: ListView.builder(
                                                      padding: const EdgeInsets.all(8),
                                                      shrinkWrap: true,
                                                      itemCount: options.length,
                                                      itemBuilder: (BuildContext context, int index) {
                                                        final Supplier option = options.elementAt(index);
                                                        return InkWell(
                                                          onTap: () => onSelected(option),
                                                          borderRadius: BorderRadius.circular(8),
                                                          child: Container(
                                                            padding: const EdgeInsets.all(12),
                                                            child: Text(option.name, style: GoogleFonts.inter(color: Colors.white)),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          height: 48,
                                          child: OutlinedButton(
                                            onPressed: () async {
                                              // open add supplier dialog
                                              final nameCtrl = TextEditingController();
                                              final emailCtrl = TextEditingController();
                                              final phoneCtrl = TextEditingController();
                                              final addrCtrl = TextEditingController();
                                              bool saving = false;
                                              await showDialog(
                                                context: context,
                                                builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
                                                  return AlertDialog(
                                                    backgroundColor: AppColors.secondary,
                                                    title: Text('Add Supplier', style: GoogleFonts.inter(color: Colors.white)),
                                                    content: SingleChildScrollView(
                                                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                                                        TextField(controller: nameCtrl, decoration: InputDecoration(hintText: 'Name', filled: true, fillColor: Colors.white, border: OutlineInputBorder())),
                                                        const SizedBox(height: 8),
                                                        TextField(controller: emailCtrl, decoration: InputDecoration(hintText: 'Email', filled: true, fillColor: Colors.white, border: OutlineInputBorder())),
                                                        const SizedBox(height: 8),
                                                        TextField(controller: phoneCtrl, decoration: InputDecoration(hintText: 'Phone', filled: true, fillColor: Colors.white, border: OutlineInputBorder())),
                                                        const SizedBox(height: 8),
                                                        TextField(controller: addrCtrl, decoration: InputDecoration(hintText: 'Address', filled: true, fillColor: Colors.white, border: OutlineInputBorder())),
                                                      ]),
                                                    ),
                                                    actions: [
                                                      TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary))),
                                                      ElevatedButton(
                                                        onPressed: saving ? null : () async {
                                                          final name = nameCtrl.text.trim();
                                                          if (name.isEmpty) return;
                                                          setState(() => saving = true);
                                                          try {
                                                            final dio = widget.bloc.dio;
                                                            final resp = await dio.post('https://pos-backend.posai.workers.dev/api/suppliers', data: { 'name': name, 'email': emailCtrl.text.trim(), 'phone_num': phoneCtrl.text.trim(), 'address': addrCtrl.text.trim() });
                                                            if (resp.statusCode == 201 && resp.data['success'] == true) {
                                                              final s = resp.data['data'];
                                                              final newSupplier = Supplier.fromJson(s);
                                                              setState(() {
                                                                _suppliers.insert(0, newSupplier);
                                                                _selectedSupplier = newSupplier;
                                                                _supplierCtrl.text = newSupplier.name;
                                                              });
                                                              toastification.show(
                                                                context: context,
                                                                type: ToastificationType.success,
                                                                style: ToastificationStyle.flatColored,
                                                                title: Text('Supplier added', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                                                description: Text('${newSupplier.name} added successfully', style: GoogleFonts.inter()),
                                                                alignment: Alignment.topCenter,
                                                                autoCloseDuration: const Duration(seconds: 3),
                                                                showProgressBar: true,
                                                              );
                                                              Navigator.pop(ctx);
                                                            } else {
                                                              toastification.show(
                                                                context: context,
                                                                type: ToastificationType.error,
                                                                style: ToastificationStyle.flatColored,
                                                                title: Text('Error', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                                                description: Text(resp.data['error'] ?? 'Failed', style: GoogleFonts.inter()),
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
                                                            setState(() => saving = false);
                                                          }
                                                        },
                                                        child: saving ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)) : Text('Save'),
                                                      )
                                                    ],
                                                  );
                                                }),
                                              );
                                            },
                                            child: const Icon(Icons.person_add),
                                          ),
                                        )
                                      ]),
                                      const SizedBox(height: 20),
                                      _buildTextField(
                                        label: 'Retail Price (LKR)',
                                        controller: _retailPriceCtrl,
                                        icon: Icons.monetization_on_outlined,
                                        keyboardType: TextInputType.number,
                                        validator: (val) {
                                          if (val == null || val.trim().isEmpty) return 'Retail price is required';
                                          if (double.tryParse(val) == null) return 'Invalid price';
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildTextField(
                                        label: 'Quantity',
                                        controller: _quantityCtrl,
                                        icon: Icons.add_box_outlined,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) return 'Quantity is required';
                                          if (int.tryParse(value.trim()) == null || int.parse(value.trim()) <= 0) {
                                            return 'Enter valid positive number';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 20),
                                      _buildTextField(
                                        label: 'Selling Price (LKR)',
                                        controller: _sellingPriceCtrl,
                                        icon: Icons.sell_outlined,
                                        keyboardType: TextInputType.number,
                                        validator: (val) {
                                          if (val == null || val.trim().isEmpty) return 'Selling price is required';
                                          if (double.tryParse(val) == null) return 'Invalid price';
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.grey.shade600),
        filled: true,
        fillColor: Colors.grey.shade50,
        prefixIcon: Icon(icon, color: Colors.black54),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black, width: 2),
        ),
      ),
      validator: validator,
    );
  }
}