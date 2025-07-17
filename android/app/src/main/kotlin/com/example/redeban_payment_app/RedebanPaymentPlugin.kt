package com.example.redeban_payment_app

import android.content.Context
import androidx.annotation.NonNull
import com.redeban.payment.Payment
import com.redeban.payment.model.Card
import com.redeban.payment.rest.TokenCallback
import com.redeban.payment.rest.model.RedebanError
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class RedebanPaymentPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.example.redeban_payment/redeban")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "initRedeban" -> {
                val testMode = call.argument<Boolean>("testMode") ?: true
                val clientAppCode = call.argument<String>("clientAppCode") ?: ""
                val clientAppKey = call.argument<String>("clientAppKey") ?: ""
                try {
                    Payment.setEnvironment(testMode, clientAppCode, clientAppKey)
                    result.success("SDK inicializado correctamente")
                } catch (e: Exception) {
                    result.error("INIT_ERROR", e.message, null)
                }
            }
            "getSessionId" -> {
                try {
                    val sessionId = Payment.getSessionId(context)
                    result.success(sessionId)
                } catch (e: Exception) {
                    result.error("SESSION_ERROR", e.message, null)
                }
            }
            "tokenizeCard" -> {
                val userId = call.argument<String>("userId") ?: ""
                val email = call.argument<String>("email") ?: ""
                val cardNumber = call.argument<String>("cardNumber") ?: ""
                val holderName = call.argument<String>("holderName") ?: ""
                val expMonth = call.argument<Int>("expMonth") ?: 0
                val expYear = call.argument<Int>("expYear") ?: 0
                val cvc = call.argument<String>("cvc") ?: ""

                // Validar que expMonth y expYear sean válidos
                if (expMonth == null || expMonth !in 1..12 || expYear == null || expYear < 0) {
                    result.error("VALIDATION_ERROR", "Mes o año de expiración inválido", null)
                    return
                }

                // Usar el Builder para crear el Card
                val card = Card.Builder(cardNumber, expMonth, expYear, cvc)
                    .name(holderName)
                    .build()

                // Validar datos de la tarjeta
                if (!card.validateNumber() || !card.validateExpiryDate() || !card.validateCVC()) {
                    result.error("VALIDATION_ERROR", "Datos de tarjeta inválidos", null)
                    return
                }

                Payment.addCard(context, userId, email, card, object : TokenCallback {
                    override fun onSuccess(card: Card?) {
                        if (card != null) {
                            val response = mapOf<String, Any>(
                                "last4" to (card.last4 ?: ""),
                                "type" to (card.type ?: ""),
                                "expiryMonth" to (card.expiryMonth ?: 0),
                                "expiryYear" to (card.expiryYear ?: 0),
                                "status" to (card.status ?: ""),
                                "token" to (card.token ?: ""),
                                "transactionReference" to (card.transactionReference ?: ""),
                                "cardId" to (card.id ?: ""),
                                "country" to (card.country ?: "")
                            )
                            result.success(response)
                        } else {
                            result.error("CARD_NULL", "La tarjeta es nula", null)
                        }
                    }

                    override fun onError(error: RedebanError?) {
                        result.error(
                            "TOKENIZE_ERROR",
                            error?.description ?: "Error desconocido",
                            mapOf<String, Any>(
                                "type" to (error?.type ?: ""),
                                "help" to (error?.help ?: ""),
                                "description" to (error?.description ?: "")
                            )
                        )
                    }
                })
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}