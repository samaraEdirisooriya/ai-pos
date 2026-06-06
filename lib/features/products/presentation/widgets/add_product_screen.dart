import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:toastification/toastification.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/product.dart';
import '../bloc/product_bloc.dart';

class AddProductScreen extends StatefulWidget {
  final ProductBloc bloc; // passing bloc to maintain context in dialog
  const AddProductScreen({super.key, required this.bloc});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _retailValueCtrl = TextEditingController();
  final _sellingValueCtrl = TextEditingController();
  final _offerPercentageCtrl = TextEditingController();
  final _productUrlCtrl = TextEditingController();

  bool _isLoading = false;

  void _submit() {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final newProduct = Product(
        productId: '', // DB generates it
        productKey: '', // DB generates it
        name: _nameCtrl.text,
        category: _categoryCtrl.text.isEmpty ? 'General' : _categoryCtrl.text,
        description: _descriptionCtrl.text,
        retailValue: double.parse(_retailValueCtrl.text),
        sellingValue: double.parse(_sellingValueCtrl.text),
        active: true,
        offerHave: _offerPercentageCtrl.text.isNotEmpty && double.parse(_offerPercentageCtrl.text) > 0,
        offerPercentage: _offerPercentageCtrl.text.isEmpty ? 0 : double.parse(_offerPercentageCtrl.text),
        productUrl: _productUrlCtrl.text.isEmpty ? 'https://via.placeholder.com/150' : _productUrlCtrl.text,
        createdUser: 'admin', // Hardcoded for now
      );

      widget.bloc.add(AddProductEvent(newProduct));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.bloc,
      child: BlocListener<ProductBloc, ProductState>(
        listener: (context, state) {
          if (state is ProductAddError) {
            setState(() => _isLoading = false);
            toastification.show(
              context: context,
              type: ToastificationType.error,
              style: ToastificationStyle.flatColored,
              title: Text('Error adding product', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              description: Text(state.message, style: GoogleFonts.inter()),
              alignment: Alignment.topCenter,
              autoCloseDuration: const Duration(seconds: 4),
              showProgressBar: true,
            );
          } else if (state is ProductAddSuccess) {
            setState(() => _isLoading = false);
            toastification.show(
              context: context,
              type: ToastificationType.success,
              style: ToastificationStyle.flatColored,
              title: Text('Success!', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              description: Text('${state.product.name} added successfully.', style: GoogleFonts.inter()),
              alignment: Alignment.topCenter,
              autoCloseDuration: const Duration(seconds: 4),
              showProgressBar: true,
            );
            Navigator.of(context).pop();
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
                child: Builder(
                  builder: (context) {
                    bool isMobileHeader = MediaQuery.of(context).size.width < 600;
                    return isMobileHeader
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white),
                                    onPressed: () => Navigator.of(context).pop(),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                                      padding: const EdgeInsets.all(12),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text('New Product',
                                        style: GoogleFonts.inter(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.5,
                                            color: Colors.white)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: _isLoading
                                    ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: _submit,
                                        child: Text('Save Product', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                                      ),
                              ),
                            ],
                          )
                        : Row(
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
                              Text('New Product',
                                  style: GoogleFonts.inter(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.5,
                                      color: Colors.white)),
                              const Spacer(),
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
                                  child: Text('Save Product', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                                ),
                            ],
                          );
                  }
                ),
              ),
              
              // Responsive Form Content
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 800), // Max width for responsiveness
                      padding: const EdgeInsets.all(40),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Product Details', style: GoogleFonts.inter(color: Colors.black, fontSize: 24, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 32),
                            
                            _buildTextField('Product Name', _nameCtrl, Icons.inventory_2, isRequired: true),
                            const SizedBox(height: 24),
                            
                            LayoutBuilder(
                              builder: (context, constraints) {
                                bool isMobile = MediaQuery.of(context).size.width < 600;
                                return isMobile
                                  ? Column(
                                      children: [
                                        _buildTextField('Category', _categoryCtrl, Icons.category),
                                        const SizedBox(height: 24),
                                        _buildTextField('Description', _descriptionCtrl, Icons.description, isMultiline: true),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        Expanded(child: _buildTextField('Category', _categoryCtrl, Icons.category)),
                                        const SizedBox(width: 24),
                                        Expanded(child: _buildTextField('Description', _descriptionCtrl, Icons.description, isMultiline: true)),
                                      ],
                                    );
                              }
                            ),
                            const SizedBox(height: 24),
                            
                            LayoutBuilder(
                              builder: (context, constraints) {
                                bool isMobile = MediaQuery.of(context).size.width < 600;
                                return isMobile
                                  ? Column(
                                      children: [
                                        _buildTextField('Retail Value (\$)', _retailValueCtrl, Icons.attach_money, isNumber: true, isRequired: true),
                                        const SizedBox(height: 24),
                                        _buildTextField('Selling Value (\$)', _sellingValueCtrl, Icons.price_check, isNumber: true, isRequired: true),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        Expanded(child: _buildTextField('Retail Value (\$)', _retailValueCtrl, Icons.attach_money, isNumber: true, isRequired: true)),
                                        const SizedBox(width: 24),
                                        Expanded(child: _buildTextField('Selling Value (\$)', _sellingValueCtrl, Icons.price_check, isNumber: true, isRequired: true)),
                                      ],
                                    );
                              }
                            ),
                            const SizedBox(height: 24),
                            
                            LayoutBuilder(
                              builder: (context, constraints) {
                                bool isMobile = MediaQuery.of(context).size.width < 600;
                                return isMobile
                                  ? Column(
                                      children: [
                                        _buildTextField('Offer Percentage (%)', _offerPercentageCtrl, Icons.local_offer, isNumber: true),
                                        const SizedBox(height: 24),
                                        _buildTextField('Image URL', _productUrlCtrl, Icons.link),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        Expanded(child: _buildTextField('Offer Percentage (%)', _offerPercentageCtrl, Icons.local_offer, isNumber: true)),
                                        const SizedBox(width: 24),
                                        Expanded(child: _buildTextField('Image URL', _productUrlCtrl, Icons.link)),
                                      ],
                                    );
                              }
                            ),
                            const SizedBox(height: 40),
                            
                            // Image Live Preview
                            Text('Image Preview', style: GoogleFonts.inter(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 16),
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _productUrlCtrl,
                              builder: (context, value, child) {
                                final url = value.text;
                                if (url.isEmpty || !Uri.parse(url).isAbsolute) {
                                  return Container(
                                    width: double.infinity,
                                    height: 200,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.black, width: 2, style: BorderStyle.solid),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.image, size: 48, color: Colors.black),
                                          const SizedBox(height: 16),
                                          Text('No Image URL provided', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                                
                                return Container(
                                  width: double.infinity,
                                  height: 240,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.black, width: 2),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: CachedNetworkImage(
                                    imageUrl: kIsWeb ? 'https://corsproxy.io/?${Uri.encodeComponent(url)}' : url,
                                    fit: BoxFit.contain,
                                    placeholder: (c, u) => Center(child: CircularProgressIndicator(color: Colors.black)),
                                    errorWidget: (c, u, e) => Container(
                                      color: Colors.white,
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.broken_image, size: 48, color: Colors.black),
                                            const SizedBox(height: 16),
                                            Text('Failed to load image', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
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

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isNumber = false, bool isRequired = false, bool isMultiline = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: isMultiline ? 3 : 1,
          keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : (isMultiline ? TextInputType.multiline : TextInputType.text),
          style: GoogleFonts.inter(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600),
          cursorColor: Colors.black,
          decoration: InputDecoration(
            prefixIcon: isMultiline ? null : Icon(icon, color: Colors.black),
            icon: isMultiline ? Icon(icon, color: Colors.black) : null,
            filled: true,
            fillColor: Colors.white, // solid white fill
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.black, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.black, width: 4), // High contrast focus
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent, width: 4),
            ),
            hintText: 'Enter $label',
            hintStyle: GoogleFonts.inter(color: Colors.black38, fontWeight: FontWeight.w500),
            contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16), // Thick padded look
          ),
          validator: isRequired ? (val) {
            if (val == null || val.isEmpty) return 'Required field';
            if (isNumber && double.tryParse(val) == null) return 'Invalid number';
            return null;
          } : (val) {
            if (val != null && val.isNotEmpty && isNumber && double.tryParse(val) == null) return 'Invalid number';
            return null;
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _descriptionCtrl.dispose();
    _retailValueCtrl.dispose();
    _sellingValueCtrl.dispose();
    _offerPercentageCtrl.dispose();
    _productUrlCtrl.dispose();
    super.dispose();
  }
}
