import 'package:flutter/material.dart';
import '../services/payment_service.dart';
import '../widgets/gradient_scaffold.dart';

/// Screen for processing payments with multiple payment methods
class PaymentScreen extends StatefulWidget {
  final String supportType;
  final int amountCents;
  final String description;

  const PaymentScreen({
    super.key,
    required this.supportType,
    required this.amountCents,
    required this.description,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PaymentService _paymentService = PaymentService();
  bool _isProcessing = false;
  bool _isPlatformPayAvailable = false;

  @override
  void initState() {
    super.initState();
    _initializePayment();
  }

  Future<void> _initializePayment() async {
    await _paymentService.initialize();
    final platformPayAvailable = await _paymentService.isPlatformPayAvailable();
    setState(() {
      _isPlatformPayAvailable = platformPayAvailable;
    });
  }

  Future<void> _processCardPayment() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final result = await _paymentService.processCardPayment(
        context: context,
        amountCents: widget.amountCents,
        supportType: widget.supportType,
        description: widget.description,
      );

      if (mounted) {
        setState(() => _isProcessing = false);

        if (result.success) {
          _showSuccessDialog();
        } else if (!result.cancelled) {
          _showErrorDialog(result.error ?? 'Payment failed');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showErrorDialog('An unexpected error occurred');
      }
    }
  }

  Future<void> _processGooglePayPayment() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final result = await _paymentService.processGooglePayPayment(
        context: context,
        amountCents: widget.amountCents,
        supportType: widget.supportType,
        description: widget.description,
      );

      if (mounted) {
        setState(() => _isProcessing = false);

        if (result.success) {
          _showSuccessDialog();
        } else if (!result.cancelled) {
          _showErrorDialog(result.error ?? 'Google Pay payment failed');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showErrorDialog('An unexpected error occurred');
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text(
              'Payment Successful',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your payment has been processed successfully.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Text(
              'Amount: \$${(widget.amountCents / 100).toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Support Type: ${_formatSupportType(widget.supportType)}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(
                  context, true); // Return to previous screen with success
            },
            child: const Text(
              'Continue',
              style: TextStyle(color: Color(0xFF4EC7F3)),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text(
              'Payment Failed',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Text(
          error,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFF4EC7F3)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSupportType(String type) {
    switch (type) {
      case 'text':
        return 'Text Chat';
      case 'phone':
        return 'Phone Support';
      case 'video':
        return 'Video Call';
      case 'emergency':
        return 'Emergency Support';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.payment,
                    size: 48,
                    color: Color(0xFF4EC7F3),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Payment Method',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Amount: \$${(widget.amountCents / 100).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4EC7F3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatSupportType(widget.supportType),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),

            // Payment Options
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Google Pay option (if available)
                      if (_isPlatformPayAvailable) ...[
                        _buildPaymentMethodCard(
                          icon: Icons.account_balance_wallet,
                          title: 'Google Pay',
                          subtitle: 'Fast and secure payment',
                          color: const Color(0xFF4285F4),
                          onTap:
                              _isProcessing ? null : _processGooglePayPayment,
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Card payment
                      _buildPaymentMethodCard(
                        icon: Icons.credit_card,
                        title: 'Credit/Debit Card',
                        subtitle: 'Enter your card details',
                        color: const Color(0xFF7C3AED),
                        onTap: _isProcessing ? null : _processCardPayment,
                      ),
                      const SizedBox(height: 12),

                      // Security info
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.security,
                              size: 20,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Secure payment via Stripe. Your card information is encrypted and never stored on our servers.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Loading indicator
            if (_isProcessing)
              Container(
                padding: const EdgeInsets.all(16),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF4EC7F3),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Processing payment...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

            // Cancel Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _isProcessing ? null : () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.8),
              color.withOpacity(0.5),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: Colors.white,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                  color: Colors.white,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
