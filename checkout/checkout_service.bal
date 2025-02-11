// Copyright (c) 2022 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/grpc;
import ballerina/uuid;
import ballerina/log;

configurable string cartHost = "localhost";
configurable string catalogHost = "localhost";
configurable string currencyHost = "localhost";
configurable string shippingHost = "localhost";
configurable string paymentHost = "localhost";
configurable string emailHost = "localhost";

# The service retrieves the user cart, prepares the order, and orchestrates the payment, shipping, and email notification.
@display {
    label: "Checkout",
    id: "checkout"
}
@grpc:Descriptor {value: DEMO_DESC}
service "CheckoutService" on new grpc:Listener(9094) {
    @display {
        label: "Cart",
        id: "cart"
    }
    private final CartServiceClient cartClient;

    @display {
        label: "Catalog",
        id: "catalog"
    }
    private final ProductCatalogServiceClient catalogClient;

    @display {
        label: "Currency",
        id: "currency"
    }
    private final CurrencyServiceClient currencyClient;

    @display {
        label: "Shipping",
        id: "shipping"
    }
    private final ShippingServiceClient shippingClient;
    @display {
        label: "Payment",
        id: "payment"
    }
    private final PaymentServiceClient paymentClient;

    @display {
        label: "Email",
        id: "email"
    }
    private final EmailServiceClient emailClient;

    function init() returns error? {
        self.cartClient = check new (string `http://${cartHost}:9092`, timeout = 3);
        self.catalogClient = check new (string `http://${catalogHost}:9091`, timeout = 3);
        self.currencyClient = check new (string `http://${currencyHost}:9093`, timeout = 3);
        self.shippingClient = check new (string `http://${shippingHost}:9095`, timeout = 3);
        self.paymentClient = check new (string `http://${paymentHost}:9096`, timeout = 3);
        self.emailClient = check new (string `http://${emailHost}:9097`, timeout = 3);
    }

    # Places the order and process payment, shipping and email notification.
    #
    # + request - `PlaceOrderRequest` containing user details
    # + return - returns `PlaceOrderResponse` containing order details
    remote function PlaceOrder(PlaceOrderRequest request) returns PlaceOrderResponse|error {
        string orderId = uuid:createType1AsString();
        CartItem[] userCartItems = check self.getUserCart(request.user_id, request.user_currency);
        OrderItem[] orderItems = check self.prepOrderItems(userCartItems, request.user_currency);
        Money shippingPrice = check self.convertCurrency(check self.quoteShipping(request.address, userCartItems), request.user_currency);

        Money totalCost = {
            currency_code: request.user_currency,
            units: 0,
            nanos: 0
        };
        totalCost = sum(totalCost, shippingPrice);
        foreach OrderItem item in orderItems {
            Money itemCost = multiplySlow(item.cost, item.item.quantity);
            totalCost = sum(totalCost, itemCost);
        }

        string transactionId = check self.chargeCard(totalCost, request.credit_card);
        log:printInfo("payment went through " + transactionId);
        string shippingTrackingId = check self.shipOrder(request.address, userCartItems);
        check self.emptyUserCart(request.user_id);

        OrderResult 'order = {
            order_id: orderId,
            shipping_tracking_id: shippingTrackingId,
            shipping_cost: shippingPrice,
            shipping_address: request.address,
            items: orderItems
        };

        error? err = self.sendConfirmationMail(request.email, 'order);
        if err is error {
            log:printWarn(string `failed to send order confirmation to ${request.email}`, 'error = err);
        } else {
            log:printInfo(string `order confirmation email sent to ${request.email}`);
        }

        return {'order};
    }

    function getUserCart(string userId, string userCurrency) returns CartItem[]|error {
        GetCartRequest getCartRequest = {user_id: userId};
        Cart|grpc:Error cartResponse = self.cartClient->GetCart(getCartRequest);
        if cartResponse is grpc:Error {
            log:printError("failed to call getCart of cart service", 'error = cartResponse);
            return cartResponse;
        }
        return cartResponse.items;
    }

    function prepOrderItems(CartItem[] cartItems, string userCurrency) returns OrderItem[]|error {
        OrderItem[] orderItems = [];
        foreach CartItem item in cartItems {
            GetProductRequest productRequest = {id: item.product_id};
            Product|grpc:Error productResponse = self.catalogClient->GetProduct(productRequest);
            if productResponse is grpc:Error {
                log:printError("failed to call getProduct from catalog service", 'error = productResponse);
                return error grpc:InternalError(
                                    string `failed to get product ${item.product_id}`, productResponse);
            }

            CurrencyConversionRequest conversionRequest = {
                'from: productResponse.price_usd,
                to_code: userCurrency
            };

            Money|grpc:Error conversionResponse = self.currencyClient->Convert(conversionRequest);
            if conversionResponse is grpc:Error {
                log:printError("failed to call convert from currency service", 'error = conversionResponse);
                return error grpc:InternalError(string `failed to convert price of ${item.product_id} to ${userCurrency}`, conversionResponse);
            }
            orderItems.push({
                item,
                cost: conversionResponse
            });
        }
        return orderItems;
    }

    function quoteShipping(Address address, CartItem[] items) returns Money|error {
        GetQuoteRequest quoteRequest = {
            address: address,
            items
        };
        GetQuoteResponse|grpc:Error getQuoteResponse = self.shippingClient->GetQuote(quoteRequest);
        if getQuoteResponse is grpc:Error {
            log:printError("failed to call getQuote from shipping service", 'error = getQuoteResponse);
            return error grpc:InternalError(
                string `failed to get shipping quote: ${getQuoteResponse.message()}`, getQuoteResponse);
        }
        return getQuoteResponse.cost_usd;
    }

    function convertCurrency(Money usd, string userCurrency) returns Money|error {
        CurrencyConversionRequest conversionRequest = {
            'from: usd,
            to_code: userCurrency
        };
        Money|grpc:Error convertionResponse = self.currencyClient->Convert(conversionRequest);
        if convertionResponse is grpc:Error {
            log:printError("failed to call convert from currency service", 'error = convertionResponse);
            return error grpc:InternalError(
                string `failed to convert currency: ${convertionResponse.message()}`, convertionResponse);
        }
        return convertionResponse;
    }

    function chargeCard(Money total, CreditCardInfo card) returns string|error {
        ChargeRequest chargeRequest = {
            amount: total,
            credit_card: card
        };
        ChargeResponse|grpc:Error chargeResponse = self.paymentClient->Charge(chargeRequest);
        if chargeResponse is grpc:Error {
            log:printError("failed to call charge from payment service", 'error = chargeResponse);
            return error grpc:InternalError(
                string `could not charge the card: ${chargeResponse.message()}`, chargeResponse);
        }
        return chargeResponse.transaction_id;
    }

    function shipOrder(Address address, CartItem[] items) returns string|error {
        ShipOrderRequest orderRequest = {};
        ShipOrderResponse|grpc:Error shipOrderResponse = self.shippingClient->ShipOrder(orderRequest);
        if shipOrderResponse is grpc:Error {
            log:printError("failed to call shipOrder from shipping service", 'error = shipOrderResponse);
            return error grpc:UnavailableError(
                string `shipment failed: ${shipOrderResponse.message()}`, shipOrderResponse);
        }
        return shipOrderResponse.tracking_id;
    }

    function emptyUserCart(string userId) returns error? {
        EmptyCartRequest request = {
            user_id: userId
        };
        Empty|grpc:Error emptyCart = self.cartClient->EmptyCart(request);
        if emptyCart is grpc:Error {
            log:printError("failed to call emptyCart from cart service", 'error = emptyCart);
            return error grpc:InternalError(
                string `failed to empty user cart during checkout: ${emptyCart.message()}`, emptyCart);
        }
    }

    function sendConfirmationMail(string email, OrderResult orderRes) returns error? {
        SendOrderConfirmationRequest orderConfirmRequest = {
            email,
            'order: orderRes
        };
        _ = check self.emailClient->SendOrderConfirmation(orderConfirmRequest);
    }
}
