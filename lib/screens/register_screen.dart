import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _authService = AuthService();
  
  final _adController = TextEditingController();
  final _soyadController = TextEditingController();
  final _firmaController = TextEditingController();
  final _tcknController = TextEditingController();
  final _telefonController = TextEditingController();
  final _emailController = TextEditingController();
  final _aciklamaController = TextEditingController();
  final _addressController = TextEditingController();
  
  bool _isLoading = false;

  void _register() async {
    final ad = _adController.text.trim();
    final soyad = _soyadController.text.trim();
    final firma = _firmaController.text.trim();
    final tckn = _tcknController.text.trim();
    final telefon = _telefonController.text.trim();
    final email = _emailController.text.trim();
    final aciklama = _aciklamaController.text.trim();
    final address = _addressController.text.trim();

    if (ad.isEmpty || soyad.isEmpty || email.isEmpty || telefon.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen zorunlu alanları doldurun.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final success = await _authService.register({
      'ad': ad,
      'soyad': soyad,
      'firma_unvan': firma,
      'tckn_vkn': tckn,
      'telefon': telefon,
      'email': email,
      'aciklama': aciklama,
      'address': address,
    });

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Başvurunuz Alındı'),
            content: const Text('Bayilik başvurunuz başarıyla alınmıştır. En kısa sürede sizinle iletişime geçeceğiz.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Go back to login
                },
                child: const Text('Tamam'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Başvuru sırasında bir hata oluştu. Lütfen tekrar deneyin.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {TextInputType type = TextInputType.text, int maxLines = 1}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: type,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.blueGrey.shade400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFD700),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bayi Başvurusu',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Lütfen bilgilerinizi eksiksiz doldurun.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 32),

              _buildTextField(_adController, 'Ad', CupertinoIcons.person),
              _buildTextField(_soyadController, 'Soyad', CupertinoIcons.person),
              _buildTextField(_firmaController, 'Firma Ünvanı', CupertinoIcons.building_2_fill),
              _buildTextField(_tcknController, 'TCKN / VKN', CupertinoIcons.doc_text),
              _buildTextField(_telefonController, 'Telefon Numarası', CupertinoIcons.phone, type: TextInputType.phone),
              _buildTextField(_emailController, 'E-posta Adresi', CupertinoIcons.mail, type: TextInputType.emailAddress),
              _buildTextField(_aciklamaController, 'Açıklama', CupertinoIcons.text_alignleft, maxLines: 3),
              _buildTextField(_addressController, 'Adres', CupertinoIcons.location, maxLines: 3),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Başvuruyu Gönder',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
