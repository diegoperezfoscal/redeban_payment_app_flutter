import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
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
      TextEditingController(text: 'Producto de prueba');
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

  // Paso 1: Generar token de autorización
  Future<String> generateAuthToken() async {
    String serverAppCode = dotenv.env['SERVER_APP_CODE']!;
    String serverAppKey = dotenv.env['SERVER_APP_KEY']!;
    final credentials = '$serverAppCode:$serverAppKey';
    final token = base64Encode(utf8.encode(credentials));
    setState(() {
      authToken = token;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Token de autorización generado: $token')),
    );
    return token;
  }

  // Paso 2: Inicializar SDK
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
        SnackBar(content: Text('SDK inicializado. Session ID: $sessionId')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al inicializar SDK: $e')),
      );
    }
  }

  // Paso 2: Tokenizar tarjeta
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
            SnackBar(content: Text('Tarjeta tokenizada. Token: $cardToken')),
          );
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al tokenizar: $e')),
        );
      }
    }
  }

  // Paso 3: Procesar pago
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
    // Simular delay de red
    await Future.delayed(Duration(seconds: 2));
    // Simular respuesta exitosa
    return {
      'transaction': {
        'status': 'success',
        'current_status': 'APPROVED',
        'payment_date': DateTime.now().toIso8601String(),
        'amount': amount,
        'authorization_code': '088428',
        'installments': 1,
        'dev_reference': devReference,
        'message': 'Operación exitosa',
        'carrier_code': '6',
        'id': 'CI-${Random().nextInt(1000)}',
        'status_detail': 3,
        'installments_type': 'Crédito rotativo',
        'payment_method_type': '0',
        'product_description': description,
      },
      'card': {
        'bin': '450700',
        'expiry_year': '2025',
        'expiry_month': '12',
        'transaction_reference': 'CI-${Random().nextInt(1000)}',
        'type': 'vi',
        'number': '1234',
        'origin': 'GlobalPay',
      },
    };
  }

  // Paso 4: Mostrar resumen de la transacción
  void showTransactionSummary(Map<String, dynamic> response) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Resumen de la Transacción'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Detalles de la Transacción',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text('ID: ${response['transaction']['id']}'),
              Text('Estado: ${response['transaction']['current_status']}'),
              Text('Monto: \$${response['transaction']['amount']}'),
              Text(
                  'Código de Autorización: ${response['transaction']['authorization_code']}'),
              Text('Fecha: ${response['transaction']['payment_date']}'),
              Text('Referencia: ${response['transaction']['dev_reference']}'),
              SizedBox(height: 10),
              Text('Detalles de la Tarjeta',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Tipo: ${response['card']['type'].toUpperCase()}'),
              Text('BIN: ${response['card']['bin']}'),
              Text('Últimos 4 dígitos: ****${response['card']['number']}'),
              Text(
                  'Expiración: ${response['card']['expiry_month']}/${response['card']['expiry_year']}'),
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
      appBar: AppBar(title: Text('Pago con Redeban')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: generateAuthToken,
                  child: Text('Generar Token de Autorización'),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: initRedebanSDK,
                  child: Text('Inicializar SDK'),
                ),
                SizedBox(height: 20),
                TextFormField(
                  decoration: InputDecoration(labelText: 'Número de Tarjeta'),
                  validator: (value) =>
                      value!.length < 16 ? 'Número de tarjeta inválido' : null,
                  onSaved: (value) => cardNumber = value!.replaceAll(' ', ''),
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'Nombre del Titular'),
                  validator: (value) =>
                      value!.isEmpty ? 'Ingrese el nombre del titular' : null,
                  onSaved: (value) => holderName = value!,
                ),
                TextFormField(
                  decoration:
                      InputDecoration(labelText: 'Mes de Expiración (MM)'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value!.isEmpty ||
                        int.parse(value) < 1 ||
                        int.parse(value) > 12) {
                      return 'Mes inválido';
                    }
                    return null;
                  },
                  onSaved: (value) => expMonth = int.parse(value!),
                ),
                TextFormField(
                  decoration:
                      InputDecoration(labelText: 'Año de Expiración (YYYY)'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value!.isEmpty ||
                        int.parse(value) < DateTime.now().year) {
                      return 'Año inválido';
                    }
                    return null;
                  },
                  onSaved: (value) => expYear = int.parse(value!),
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'CVC'),
                  keyboardType: TextInputType.number,
                  validator: (value) =>
                      value!.length < 3 ? 'CVC inválido' : null,
                  onSaved: (value) => cvc = value!,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: tokenizeCard,
                  child: Text('Tokenizar Tarjeta'),
                ),
                SizedBox(height: 20),
                TextFormField(
                  controller: amountController,
                  decoration: InputDecoration(labelText: 'Monto a Cobrar'),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) =>
                      value!.isEmpty ? 'Ingrese un monto' : null,
                ),
                TextFormField(
                  controller: descriptionController,
                  decoration: InputDecoration(labelText: 'Descipción'),
                  validator: (value) =>
                      value!.isEmpty ? 'Ingrese una descripción' : null,
                ),
                TextFormField(
                  controller: devReferenceController,
                  decoration:
                      InputDecoration(labelText: 'Referencia del Comercio'),
                  validator: (value) =>
                      value!.isEmpty ? 'Ingrese una referencia' : null,
                ),
                TextFormField(
                  controller: vatController,
                  decoration: InputDecoration(labelText: 'IVA'),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) =>
                      value!.isEmpty ? 'Ingrese el IVA' : null,
                ),
                TextFormField(
                  controller: cvcController,
                  decoration: InputDecoration(labelText: 'CVC (Opcional)'),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      if (authToken.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Primero genere el token de autorización')),
                        );
                        return;
                      }
                      if (cardToken.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Primero tokenice una tarjeta')),
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
                  child: Text('Procesar Pago'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
