import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  print(dotenv.env);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: PaymentScreen(),
    );
  }
}

class PaymentScreen extends StatefulWidget {
  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final platform = MethodChannel('com.example.redeban_payment/redeban');
  final _formKey = GlobalKey<FormState>();
  String cardNumber = '';
  String holderName = '';
  int expMonth = 0;
  int expYear = 0;
  String cvc = '';
  String userId = 'user123';
  String email = 'usuario@ejemplo.com';
  String sessionId = '';
  String cardToken = '';
  String authToken = '';

  final TextEditingController amountController =
      TextEditingController(text: '99.00');
  final TextEditingController descriptionController =
      TextEditingController(text: 'Test product');
  final TextEditingController devReferenceController =
      TextEditingController(text: 'REF-001');
  final TextEditingController vatController =
      TextEditingController(text: '0.00');
  final TextEditingController cvcController = TextEditingController();

  @override
  void initState() {
    super.initState();
    initRedebanSDK();
  }

  Future<String> generateAuthToken() async {
    String? serverAppCode = dotenv.env['SERVER_APP_CODE'];
    String? serverAppKey = dotenv.env['SERVER_APP_KEY'];
    final credentials = '$serverAppCode:$serverAppKey';
    final token = base64Encode(utf8.encode(credentials));
    setState(() {
      authToken = token;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Authorization token generated: $token')),
    );
    return token;
  }

  Future<void> initRedebanSDK() async {
    try {
      await platform.invokeMethod('initRedeban', {
        'testMode': true,
        'clientAppCode': dotenv.env['CLIENT_APP_CODE'],
        'clientAppKey': dotenv.env['CLIENT_APP_KEY'],
      });
      sessionId = await platform.invokeMethod('getSessionId');
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('SDK initialized. Session ID: $sessionId')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initializing SDK: $e')),
      );
    }
  }

  Future<void> tokenizeCard() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      try {
        final result = await platform.invokeMethod('tokenizeCard', {
          'userId': userId,
          'email': email,
          'cardNumber': cardNumber,
          'holderName': holderName,
          'expMonth': expMonth,
          'expYear': expYear,
          'cvc': cvc,
        });
        setState(() {
          cardToken = result['token'] ?? '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Card tokenized. Token: $cardToken')),
          );
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tokenization error: $e')),
        );
      }
    }
  }

  Future<Map<String, dynamic>> processPayment({
    required String sessionId,
    required String userId,
    required String email,
    required double amount,
    required String description,
    required String devReference,
    required double vat,
    required String cardToken,
    String? cvc,
  }) async {
    await Future.delayed(Duration(seconds: 2));
    return {
      'transaction': {
        'status': 'success',
        'current_status': 'APPROVED',
        'payment_date': DateTime.now().toIso8601String(),
        'amount': amount,
        'authorization_code': '088428',
        'installments': 1,
        'dev_reference': devReference,
        'message': 'Transaction successful',
        'carrier_code': '6',
        'id': 'CI-${Random().nextInt(1000)}',
        'status_detail': 3,
        'installments_type': 'Revolving credit',
        'payment_method_type': '0',
        'product_description': description,
      },
      'card': {
        'bin': '450700',
        'transaction_reference': 'CI-${Random().nextInt(1000)}',
        'type': 'vi',
        'number': '1234',
        'origin': 'GlobalPay',
      },
    };
  }

  void showTransactionSummary(Map<String, dynamic> response) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Transaction Summary'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Transaction Details',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text('ID: ${response['transaction']['id']}'),
              Text('Status: ${response['transaction']['current_status']}'),
              Text('Amount: \$${response['transaction']['amount']}'),
              Text(
                  'Authorization Code: ${response['transaction']['authorization_code']}'),
              Text('Date: ${response['transaction']['payment_date']}'),
              Text('Reference: ${response['transaction']['dev_reference']}'),
              SizedBox(height: 10),
              Text('Card Details',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Type: ${response['card']['type'].toUpperCase()}'),
              Text('BIN: ${response['card']['bin']}'),
              Text('Last 4 digits: ****${response['card']['number']}'),
              Text(
                  'Expiry: ${response['card']['expiry_month']}/${response['card']['expiry_year']}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Payment with Redeban')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: generateAuthToken,
                  child: Text('Generate Authorization Token'),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: initRedebanSDK,
                  child: Text('Initialize SDK'),
                ),
                SizedBox(height: 20),
                TextFormField(
                  decoration: InputDecoration(labelText: 'Card Number'),
                  validator: (value) =>
                      value!.length < 16 ? 'Invalid card number' : null,
                  onSaved: (value) => cardNumber = value!.replaceAll(' ', ''),
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'Cardholder Name'),
                  validator: (value) =>
                      value!.isEmpty ? 'Enter cardholder name' : null,
                  onSaved: (value) => holderName = value!,
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'Expiry Month (MM)'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value!.isEmpty ||
                        int.parse(value) < 1 ||
                        int.parse(value) > 12) {
                      return 'Invalid month';
                    }
                    return null;
                  },
                  onSaved: (value) => expMonth = int.parse(value!),
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'Expiry Year (YYYY)'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value!.isEmpty ||
                        int.parse(value) < DateTime.now().year) {
                      return 'Invalid year';
                    }
                    return null;
                  },
                  onSaved: (value) => expYear = int.parse(value!),
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'CVC'),
                  keyboardType: TextInputType.number,
                  validator: (value) =>
                      value!.length < 3 ? 'Invalid CVC' : null,
                  onSaved: (value) => cvc = value!,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: tokenizeCard,
                  child: Text('Tokenize Card'),
                ),
                SizedBox(height: 20),
                TextFormField(
                  controller: amountController,
                  decoration: InputDecoration(labelText: 'Amount to Charge'),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) =>
                      value!.isEmpty ? 'Enter an amount' : null,
                ),
                TextFormField(
                  controller: descriptionController,
                  decoration: InputDecoration(labelText: 'Description'),
                  validator: (value) =>
                      value!.isEmpty ? 'Enter a description' : null,
                ),
                TextFormField(
                  controller: devReferenceController,
                  decoration: InputDecoration(labelText: 'Merchant Reference'),
                  validator: (value) =>
                      value!.isEmpty ? 'Enter a reference' : null,
                ),
                TextFormField(
                  controller: vatController,
                  decoration: InputDecoration(labelText: 'VAT'),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) => value!.isEmpty ? 'Enter VAT' : null,
                ),
                TextFormField(
                  controller: cvcController,
                  decoration: InputDecoration(labelText: 'CVC (Optional)'),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      if (authToken.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('Please generate the auth token first')),
                        );
                        return;
                      }
                      if (cardToken.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Please tokenize a card first')),
                        );
                        return;
                      }
                      final paymentResponse = await processPayment(
                        sessionId: sessionId,
                        userId: userId,
                        email: email,
                        amount: double.parse(amountController.text),
                        description: descriptionController.text,
                        devReference: devReferenceController.text,
                        vat: double.parse(vatController.text),
                        cardToken: cardToken,
                        cvc: cvcController.text.isNotEmpty
                            ? cvcController.text
                            : null,
                      );
                      showTransactionSummary(paymentResponse);
                    }
                  },
                  child: Text('Process Payment'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
