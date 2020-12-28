import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:gogoz/utilities/constants.dart';
import 'package:flushbar/flushbar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'animations.dart';
import 'dart:math';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:carousel_slider/carousel_slider.dart';

import './model.dart';
import './map.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class MyApp extends StatefulWidget {
  // This widget is the root of your application.
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool logintoFirebase = true;
  bool tripStarted = false;
  var tripId = orderId;
  LatLng driverLatLng;
  LatLng targetLatLng;
  // hardcoded, this should come to app via Flutter background process so that it is synchronized between Driver and Client apps

  String firebaseUID;

  // void loginToFirebase() async {
  //   final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  //   AuthResult result = await _firebaseAuth.signInWithEmailAndPassword(
  //       email: 'customer@lokesh.com', password: "Password1234");
  //   FirebaseUser user = result.user;
  //   firebaseUID = user.uid;
  //   logintoFirebase = true;
  //   setState(() {});
  // }

  void getDriverLocation() async {
    final dbRefDriverLocation = FirebaseDatabase.instance
        .reference()
        .child(orderId)
        .child("driver_location");

    Query _driverLocationQuery =
        dbRefDriverLocation.orderByChild("tripId").equalTo(tripId);

    _driverLocationQuery.onChildAdded.listen((event) {
      DriverLocation _driverPosition =
          DriverLocation.fromSnapshot(event.snapshot);
      driverLatLng = LatLng(_driverPosition.lat, _driverPosition.long);
      targetLatLng =
          LatLng(_driverPosition.targetLat, _driverPosition.targetLong);

      if (targetLatLng != null) {
        tripStarted = true;
        setState(() {});
      }
    });
  }

  void doAsyncTasks() async {
    //await loginToFirebase();
    getDriverLocation();
  }

  @override
  void initState() {
    super.initState();
    doAsyncTasks();
  }

  @override
  Widget build(BuildContext context) {
    if (gotPermissions) {
      return (gotPermissions && logintoFirebase && tripStarted)
          ? MapScreen(
              tripId: tripId,
              driverLocation: driverLatLng,
              targetLatLng: targetLatLng)
          : TempPage(tripId);
    } else {
      permission_granted = false;
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.error, size: 50, color: Colors.red.shade600),
        SizedBox(
          height: 10,
        ),
        Center(
            child: Text(
          'Cannot use tracking service.',
          textAlign: TextAlign.left,
          style: TextStyle(
            fontSize: 20,
            color: Color(0xFF0E0038),
            fontWeight: FontWeight.w700,
          ),
        ))
      ]);
    }
  }
}

class TempPage extends StatelessWidget {
  final tripId;
  TempPage(this.tripId);
  @override
  Widget build(BuildContext context) {
    return Center(child: Text("Awaiting trip to start"));
  }
}

//=-= ------------------------------------------------------
//  Constants
//=-= ------------------------------------------------------

const ORDER_DATA = {
  "custID": "USER_1122334455",
  "custEmail": "someemail@gmail.com",
  "custPhone": ""
};

const STATUS_LOADING = "PAYMENT_LOADING";
const STATUS_SUCCESSFUL = "PAYMENT_SUCCESSFUL";
const STATUS_PENDING = "PAYMENT_PENDING";
const STATUS_FAILED = "PAYMENT_FAILED";
const STATUS_CHECKSUM_FAILED = "PAYMENT_CHECKSUM_FAILED";

//=-= ---------------------------------------------------------
//  Order Submit Loader
//=-= ---------------------------------------------------------

class OrderSubmitPageLoader extends StatefulWidget {
  @override
  _OrderSubmitPageLoader createState() => _OrderSubmitPageLoader();
}

class _OrderSubmitPageLoader extends State<OrderSubmitPageLoader> {
  var data = new Map<String, dynamic>();
  var loading = true;

  Position _currentPosition;

  void _getCurrentLocation() {
    if (gotPermissions) {
      Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best)
          .then((Position position) {
        setState(() {
          _currentPosition = position;
        });
      }).catchError((e) {
        print(e);
      });
    }
  }

  void handlerPaymentSuccess() async {
    var filteredList = List();
    if (menuJson != null) {
      for (var i = 0; i < menuJson["menu"].length; i++) {
        for (var item in menuJson["menu"][i]) {
          if (item["type"] == 1) {
            if (item["quantity"]["quantity"] != 0) {
              item.remove("time_start");
              item.remove("time_end");
              filteredList.add(item);
            }
          } else if (item["type"] == 2) {
            var present = false;
            if (item["quantity"]["10g"] != 0) {
              present = true;
            }
            if (item["quantity"]["25g"] != 0) {
              present = true;
            }
            if (item["quantity"]["50g"] != 0) {
              present = true;
            }
            if (item["quantity"]["100g"] != 0) {
              present = true;
            }
            if (item["quantity"]["250g"] != 0) {
              present = true;
            }
            if (item["quantity"]["500g"] != 0) {
              present = true;
            }
            if (item["quantity"]["1kg"] != 0) {
              present = true;
            }
            if (item["quantity"]["2kg"] != 0) {
              present = true;
            }

            if (present) {
              item.remove("time_start");
              item.remove("time_end");
              filteredList.add(item);
            }
          } else if (item["type"] == 3) {
            if (item["quantity"]["small"] != 0 ||
                item["quantity"]["medium"] != 0 ||
                item["quantity"]["large"] != 0) {
              item.remove("time_start");
              item.remove("time_end");
              filteredList.add(item);
            }
          }
        }
      }
    }
    var location = {};
    if (gotPermissions) {
      location['lat'] = _currentPosition.latitude;
      location['long'] = _currentPosition.longitude;
    } else {
      location['lat'] = 0.0;
      location['long'] = 0.0;
    }

    orderId = responseJSON["data"]["ORDERID"];
    data['phone_number'] = userPhone;
    data['address'] = saved["address"] = address;
    data['name'] = saved["name"] = name;
    data['email'] = saved["email"] = email;
    data['pincode'] = saved["pincode"] = pincode;
    data['token'] = token;
    data['order_id'] = responseJSON["data"]["ORDERID"];
    data['BANKTXNID'] = responseJSON["data"]["BANKTXNID"];
    data['TXNID'] = responseJSON["data"]["TXNID"];
    data['STATUS'] = responseJSON["data"]["STATUS"];
    data['order'] = json.encode(filteredList);
    data['total_init'] = getTotal().toString();
    data['total_vendor'] = getTotalVendor().toString();
    data['total_customer'] = getTotalFinal().toString();
    data['vendor_id'] = vendorIdMenu;
    data['location'] = json.encode(location);
    http.Response httpresponse = await http.post(
        'https://02c8cb08d4e2.ngrok.io/place_order',
        body: jsonEncode(data),
        headers: {
          'Content-type': 'application/json',
          'Accept': 'application/json'
        });

    if (httpresponse.statusCode == HttpStatus.ok) {
      loading = false;
      if (paymentSuccess) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => OrderSubmitPage()));
      } else {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => PaymentFailedScreen()));
      }
    } else {
      title = "Error";
      message = "Internal server error.";
      showInfoFlushbar(context);
    }
  }

  void showInfoFlushbar(BuildContext context) {
    Flushbar(
      title: title,
      message: message,
      icon: Icon(Icons.delete, size: 28, color: Colors.red.shade600),
      duration: Duration(seconds: 5),
      leftBarIndicatorColor: Colors.red.shade600,
    )..show(context);
  }

  @override
  Widget build(BuildContext context) {
    _getCurrentLocation();
    if (loading) {
      handlerPaymentSuccess();
      return Scaffold(
        body: Center(
            child: Container(
                margin: EdgeInsets.all(3),
                child: Image.asset(
                  "assets/images/logoload.gif",
                  width: 48,
                ))),
      );
    }
  }
}

//=-= ------------------------------------------------------
//  Payment Screen
//=-= ------------------------------------------------------

class PaymentScreen extends StatefulWidget {
  final String amount;

  PaymentScreen({this.amount});
  // Are you there

  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  WebViewController _webController;
  bool _loadingPayment = true;
  String _responseStatus = STATUS_LOADING;

  String _loadHTML() {
    return "<html> <body onload='document.f.submit();'> <form id='f' name='f' method='post' action='https://us-central1-gogoz-e3b55.cloudfunctions.net/customFunctions/payment'><input type='hidden' name='orderID' value='ORDER_${DateTime.now().millisecondsSinceEpoch}'/>" +
        "<input  type='hidden' name='custID' value='${DateTime.now().millisecondsSinceEpoch}' />" +
        "<input  type='hidden' name='amount' value='" +
        getTotalFinal().toString() +
        "' />" +
        "<input type='hidden' name='custEmail' value='{$email}' />" +
        "<input type='hidden' name='custPhone' value='{$userPhone}' />" +
        "</form> </body> </html>";
  }

  void getData() {
    _webController.evaluateJavascript("document.body.innerText").then((data) {
      var decodedJSON = jsonDecode(data);
      responseJSON = jsonDecode(decodedJSON);
      final checksumResult = responseJSON["status"];
      final paytmResponse = responseJSON["data"];
      if (paytmResponse["STATUS"] == "TXN_SUCCESS") {
        if (checksumResult == 0) {
          _responseStatus = STATUS_SUCCESSFUL;
        } else {
          _responseStatus = STATUS_CHECKSUM_FAILED;
        }
      } else if (paytmResponse["STATUS"] == "TXN_FAILURE") {
        _responseStatus = STATUS_FAILED;
      }
      this.setState(() {});
    });
  }

  Widget getResponseScreen() {
    switch (_responseStatus) {
      case STATUS_SUCCESSFUL:
        paymentSuccess = true;
        return OrderSubmitPageLoader();
      case STATUS_CHECKSUM_FAILED:
        return CheckSumFailedScreen();
      case STATUS_FAILED:
        paymentSuccess = false;
        return OrderSubmitPageLoader();
    }
    return PaymentFailedScreen();
  }

  @override
  void dispose() {
    _webController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
          body: Stack(
        children: <Widget>[
          Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: WebView(
              debuggingEnabled: false,
              javascriptMode: JavascriptMode.unrestricted,
              onWebViewCreated: (controller) {
                _webController = controller;
                _webController.loadUrl(
                    new Uri.dataFromString(_loadHTML(), mimeType: 'text/html')
                        .toString());
              },
              onPageFinished: (page) {
                if (page.contains("/process")) {
                  if (_loadingPayment) {
                    this.setState(() {
                      _loadingPayment = false;
                    });
                  }
                }
                if (page.contains("/paymentReceipt")) {
                  getData();
                }
              },
            ),
          ),
          (_loadingPayment)
              ? Center(
                  child: Container(
                      margin: EdgeInsets.all(3),
                      child: Image.asset(
                        "assets/images/logoload.gif",
                        width: 48,
                      )),
                )
              : Center(),
          (_responseStatus != STATUS_LOADING)
              ? Center(child: getResponseScreen())
              : Center()
        ],
      )),
    );
  }
}

class PaymentFailedScreen extends StatelessWidget {
  void showInfoFlushbar(BuildContext context) {
    Flushbar(
      title: title,
      message: message,
      icon: Icon(Icons.delete, size: 28, color: Colors.red.shade600),
      duration: Duration(seconds: 5),
      leftBarIndicatorColor: Colors.red.shade600,
    )..show(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                height: 10,
              ),
              Center(
                  child: Text(
                "Payment failed",
                style: TextStyle(fontSize: 30),
              )),
              SizedBox(
                height: 50,
              ),
              Center(
                  child: Text(
                "Your order id is",
                style: TextStyle(fontSize: 20),
              )),
              SizedBox(
                height: 10,
              ),
              Center(
                  child: Text(
                responseJSON["data"]["ORDERID"],
                style: TextStyle(fontSize: 30),
              )),
              SizedBox(
                height: 50,
              ),
              Center(
                  child: Text(
                "If any amount has been deducted from your account please mention the above order id while contacting customer service",
                style: TextStyle(fontSize: 15),
              )),
              SizedBox(
                height: 30,
              ),
              MaterialButton(
                  color: Color(0xFF0E0038),
                  child: Text(
                    "Press to try payment again",
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () => {
                        Navigator.pushReplacement(
                            context, SlideRightRoute(page: PaymentScreen()))
                      })
            ],
          ),
        ),
      ),
    );
  }
}

class CheckSumFailedScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                height: 10,
              ),
              Text(
                "Problem Verifying Payment, If you balance is deducted please contact our customer support and get your payment verified!",
                style: TextStyle(fontSize: 30),
              ),
              SizedBox(
                height: 10,
              ),
              MaterialButton(
                  color: Colors.black,
                  child: Text(
                    "Press to try payment again",
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () => {
                        Navigator.pushReplacement(
                            context, SlideRightRoute(page: PaymentScreen()))
                      })
            ],
          ),
        ),
      ),
    );
  }
}

//=-= ------------------------------------------------------
//  Global Variables
//=-= ------------------------------------------------------

var categoriesJson = [];
var orderTotal;
var title;
var message;
var name;
var email;
var address;
var pincode;
var userPhone;
var token;
var orderId;
var isLoadingCategories = true;
var isLoadingMenu = true;
var productsJson = [];
var vendorIdMenu;
var vendorNameMenu;
var menuJson;
var vendorsJson = [];
var cartItemCount = 0;
var categoryToLoad;
var categoryName;
var userSavedData;
var previouslySaved = false;
var appliedCoupon;
var deliveryCharges = 0;
var deliveryMessage = "Delivery charges";
var discountPercent = 0;
var maxDiscount = 0;
var discount = 0.0;
var freeDelivery = false;
var orderJson;
var orderListJson = [];
var paymentSuccess;
var pIndex;
var pIndex2;
var pType;
var pName;
var saved = new Map<String, dynamic>();
var offers = [];
var vendors = [];
var location_permission;
bool gotPermissions = false;
var permission_granted = true;
var heightvar = 1;
bool newOrder = false;
Map<String, dynamic> responseJSON;

DateTime now = new DateTime.now();
DateTime date = new DateTime(now.year, now.month, now.day);
const _chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890';
Random _rnd = Random();

String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
    length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

getCartNumberOfItems() {
  var filteredList = [];
  if (menuJson != null) {
    for (var i = 0; i < menuJson["menu"].length; i++) {
      for (var item in menuJson["menu"][i]) {
        if (item["type"] == 1) {
          if (item["quantity"]["quantity"] > 0) {
            filteredList.add(item);
          }
        } else if (item["type"] == 2) {
          if (item["quantity"]["10g"] > 0) {
            filteredList.add(item);
          }
          if (item["quantity"]["25g"] > 0) {
            filteredList.add(item);
          }
          if (item["quantity"]["50g"] > 0) {
            filteredList.add(item);
          }
          if (item["quantity"]["100g"] > 0) {
            filteredList.add(item);
          }
          if (item["quantity"]["250g"] > 0) {
            filteredList.add(item);
          }
          if (item["quantity"]["500g"] > 0) {
            filteredList.add(item);
          }
          if (item["quantity"]["1kg"] > 0) {
            filteredList.add(item);
          }
          if (item["quantity"]["2kg"] > 0) {
            filteredList.add(item);
          }
        } else if (item["type"] == 3) {
          if (item["quantity"]["small"] > 0) {
            filteredList.add(item);
          }
          if (item["quantity"]["medium"] > 0) {
            filteredList.add(item);
          }
          if (item["quantity"]["large"] > 0) {
            filteredList.add(item);
          }
        }
      }
    }
  }
  return filteredList.length;
}

getDeliveryCharges() {
  var total = getTotalInit();
  if (freeDelivery) {
    deliveryCharges = 0;
    deliveryMessage = "Delivery charges: FREE!";
  } else {
    if (total <= 49) {
      deliveryCharges = 49;
      deliveryMessage = "Delivery charges";
    } else if (total >= 50 && total <= 169) {
      deliveryCharges = 39;
      deliveryMessage = "Delivery charges";
    } else if (total >= 150 && total <= 249) {
      deliveryCharges = 29;
      deliveryMessage = "Delivery charges";
    } else if (total >= 250 && total <= 399) {
      deliveryCharges = 19;
      deliveryMessage = "Delivery charges";
    } else {
      deliveryCharges = 0;
      deliveryMessage = "Delivery charges: FREE!";
    }
  }
  return deliveryCharges;
}

getTotal() {
  if (menuJson != null) {
    var total = getTotalInit();
    if (appliedCoupon != null) {
      discount = (total * discountPercent / 100);

      if (discount < maxDiscount) {
        return (total - discount);
      } else {
        discount = maxDiscount * 1.0;
        return double.parse((total - discount).toStringAsFixed(2));
      }
    } else {
      return double.parse((total).toStringAsFixed(2));
    }
  }
}

getTotalInit() {
  if (menuJson != null) {
    var total = 0;
    for (var i = 0; i < menuJson["menu"].length; i++) {
      for (var item in menuJson["menu"][i]) {
        if (item["type"] == 1) {
          if (item["quantity"]["quantity"] > 0) {
            total = total +
                (item["original_price"]["original_price"] *
                    item["quantity"]["quantity"]);
            orderTotal = total;
          }
        } else if (item["type"] == 2) {
          if (item["quantity"]["10g"] > 0) {
            total = total +
                (item["original_price"]["10g"] * item["quantity"]["10g"]);
            orderTotal = total;
          }
          if (item["quantity"]["25g"] > 0) {
            total = total +
                (item["original_price"]["25g"] * item["quantity"]["25g"]);
            orderTotal = total;
          }
          if (item["quantity"]["50g"] > 0) {
            total = total +
                (item["original_price"]["50g"] * item["quantity"]["50g"]);
            orderTotal = total;
          }
          if (item["quantity"]["100g"] > 0) {
            total = total +
                (item["original_price"]["100g"] * item["quantity"]["100g"]);
            orderTotal = total;
          }
          if (item["quantity"]["250g"] > 0) {
            total = total +
                (item["original_price"]["250g"] * item["quantity"]["250g"]);
            orderTotal = total;
          }
          if (item["quantity"]["500g"] > 0) {
            total = total +
                (item["original_price"]["500g"] * item["quantity"]["500g"]);
            orderTotal = total;
          }
          if (item["quantity"]["1kg"] > 0) {
            total = total +
                (item["original_price"]["1kg"] * item["quantity"]["1kg"]);
            orderTotal = total;
          }
          if (item["quantity"]["2kg"] > 0) {
            total = total +
                (item["original_price"]["2kg"] * item["quantity"]["2kg"]);
            orderTotal = total;
          }
        } else if (item["type"] == 3) {
          if (item["quantity"]["small"] > 0) {
            total = total +
                (item["original_price"]["small"] * item["quantity"]["small"]);
            orderTotal = total;
          }
          if (item["quantity"]["medium"] > 0) {
            total = total +
                (item["original_price"]["medium"] * item["quantity"]["medium"]);
            orderTotal = total;
          }
          if (item["quantity"]["large"] > 0) {
            total = total +
                (item["original_price"]["large"] * item["quantity"]["large"]);
            orderTotal = total;
          }
        }
      }
    }
    return total;
  }
}

getTotalVendor() {
  if (menuJson != null) {
    var total = 0;
    for (var i = 0; i < menuJson["menu"].length; i++) {
      for (var item in menuJson["menu"][i]) {
        if (item["type"] == 1) {
          if (item["quantity"]["quantity"] > 0) {
            total = total +
                (item["vendor_price"]["vendor_price"] *
                    item["quantity"]["quantity"]);
            orderTotal = total;
          }
        } else if (item["type"] == 2) {
          if (item["quantity"]["10g"] > 0) {
            total =
                total + (item["vendor_price"]["10g"] * item["quantity"]["10g"]);
            orderTotal = total;
          }
          if (item["quantity"]["25g"] > 0) {
            total =
                total + (item["vendor_price"]["25g"] * item["quantity"]["25g"]);
            orderTotal = total;
          }
          if (item["quantity"]["50g"] > 0) {
            total =
                total + (item["vendor_price"]["50g"] * item["quantity"]["50g"]);
            orderTotal = total;
          }
          if (item["quantity"]["100g"] > 0) {
            total = total +
                (item["vendor_price"]["100g"] * item["quantity"]["100g"]);
            orderTotal = total;
          }
          if (item["quantity"]["250g"] > 0) {
            total = total +
                (item["vendor_price"]["250g"] * item["quantity"]["250g"]);
            orderTotal = total;
          }
          if (item["quantity"]["500g"] > 0) {
            total = total +
                (item["vendor_price"]["500g"] * item["quantity"]["500g"]);
            orderTotal = total;
          }
          if (item["quantity"]["1kg"] > 0) {
            total =
                total + (item["vendor_price"]["1kg"] * item["quantity"]["1kg"]);
            orderTotal = total;
          }
          if (item["quantity"]["2kg"] > 0) {
            total =
                total + (item["vendor_price"]["2kg"] * item["quantity"]["2kg"]);
            orderTotal = total;
          }
        } else if (item["type"] == 3) {
          if (item["quantity"]["small"] > 0) {
            total = total +
                (item["vendor_price"]["small"] * item["quantity"]["small"]);
            orderTotal = total;
          }
          if (item["quantity"]["medium"] > 0) {
            total = total +
                (item["vendor_price"]["medium"] * item["quantity"]["medium"]);
            orderTotal = total;
          }
          if (item["quantity"]["large"] > 0) {
            total = total +
                (item["vendor_price"]["large"] * item["quantity"]["large"]);
            orderTotal = total;
          }
        }
      }
    }
    return total;
  }
}

getTotalFinal() {
  return double.parse(
      (getTotal() + getGST() + deliveryCharges).toStringAsFixed(2));
}

getGST() {
  return double.parse((getTotal() * 0.18).toStringAsFixed(2));
}

//=-= ------------------------------------------------------
//  Cart items count Notifier
//=-= ------------------------------------------------------

class Total with ChangeNotifier {
  var totalButtonVal;
  getTotalButtonVal() {
    totalButtonVal = getTotalInit();
    notifyListeners();
  }
}

//=-= ------------------------------------------------------
//  Search items  Debouncer
//=-= ------------------------------------------------------

class Debouncer {
  final int milliseconds;
  VoidCallback action;
  Timer _timer;

  Debouncer({this.milliseconds});

  run(VoidCallback action) {
    if (null != _timer) {
      _timer.cancel();
    }
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}

//=-= ------------------------------------------------------
//  Delete Icon
//=-= ------------------------------------------------------

enum ConfirmAction { Cancel, Delete }
Future<ConfirmAction> _asyncConfirmDialog(BuildContext context) async {
  var total = getTotalInit();
  if (total == 0) {
    return ConfirmAction.Delete;
  } else {
    return showDialog<ConfirmAction>(
      context: context,
      barrierDismissible: false, // user must tap button for close dialog!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm action'),
          content: const Text(
              'This will delete all the items from your shopping cart.'),
          actions: <Widget>[
            FlatButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(ConfirmAction.Cancel);
              },
            ),
            FlatButton(
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop(ConfirmAction.Delete);
              },
            )
          ],
        );
      },
    );
  }
}

clearCart() {
  if (menuJson != null) {
    for (var i = 0; i < menuJson["menu"].length; i++) {
      for (var item in menuJson["menu"][i]) {
        if (item["type"] == 1) {
          item["quantity"]["quantity"] = 0;
        } else if (item["type"] == 2) {
          item["quantity"]["10g"] = 0;
          item["quantity"]["25g"] = 0;
          item["quantity"]["50g"] = 0;
          item["quantity"]["100g"] = 0;
          item["quantity"]["250g"] = 0;
          item["quantity"]["500g"] = 0;
          item["quantity"]["1kg"] = 0;
          item["quantity"]["2kg"] = 0;
        } else if (item["type"] == 3) {
          item["quantity"]["small"] = 0;
          item["quantity"]["medium"] = 0;
          item["quantity"]["large"] = 0;
        }
      }
    }
  }
}

class DeleteAllItems extends StatelessWidget {
  deleteAllItems(context) async {
    clearCart();
    await Navigator.push(
        context, MaterialPageRoute(builder: (context) => MyHomePage()));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppBar().preferredSize.height - 12,
      height: AppBar().preferredSize.height - 12,
      color: Color(0xFF0E0038),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppBar().preferredSize.height),
          child: IconButton(
            icon: Icon(
              Icons.delete_forever,
              color: Colors.white,
            ),
            onPressed: null,
          ),
          onTap: () async {
            final ConfirmAction action = await _asyncConfirmDialog(context);
            if (action == ConfirmAction.Cancel) {
            } else {
              deleteAllItems(context);
            }
          },
        ),
      ),
    );
  }
}

//=-= ------------------------------------------------------
//  Searching Icon
//=-= ------------------------------------------------------

class SearchIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppBar().preferredSize.height - 12,
      height: AppBar().preferredSize.height - 12,
      color: Color(0xFF0E0038),
      child: Material(
        color: Colors.transparent,
        child: IconButton(
          icon: Icon(
            Icons.search,
            color: Colors.white,
          ),
          onPressed: () => {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => CategoryScreen()))
          },
        ),
      ),
    );
  }
}

//=-= ------------------------------------------------------
//  Categories Icon
//=-= ------------------------------------------------------

class Categories extends StatefulWidget {
  const Categories({Key key2}) : super(key: key2);

  @override
  _Categories createState() => _Categories();
}

class _Categories extends State<Categories> {
  void initState() {
    super.initState();
  }

  gotoCategory(i, name) {
    categoryToLoad = i + 1;
    categoryName = name;
    Navigator.push(context, MaterialPageRoute(builder: (context) => Vendors()));
  }

  gotoVendor(id, name) {
    vendorIdMenu = id;
    vendorNameMenu = name;
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => MenuScreen()));
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingCategories) {
      return Center(
          child: Container(
              margin: EdgeInsets.all(3),
              child: Image.asset(
                "assets/images/logoload.gif",
                width: 48,
              )));
    }
    return SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
            margin: EdgeInsets.only(top: 10, right: 0, left: 20),
            child: Text(
              'Offers',
              textAlign: TextAlign.left,
              style: TextStyle(
                fontFamily: "AvenirBold",
                fontSize: 20,
                color: Color(0xFF0E0038),
                fontWeight: FontWeight.w700,
              ),
            )),
        SizedBox(
          width: 10,
        ),
        Container(
          margin: EdgeInsets.only(top: 10),
          height: 1.0,
          width: MediaQuery.of(context).size.width * .751,
          color: Color(0xFF0E0038),
        )
      ]),
      Container(
          margin: EdgeInsets.only(top: 10, right: 0, left: 10, bottom: 10),
          width: MediaQuery.of(context).size.width * .95,
          transform: Matrix4.translationValues(0.0, 0.0, 0.0),
          child: CarouselSlider(
              options: CarouselOptions(
                autoPlay: true,
                autoPlayInterval: Duration(seconds: 3),
                autoPlayAnimationDuration: Duration(milliseconds: 800),
                viewportFraction: 1,
                height: MediaQuery.of(context).size.width * .40,
                enableInfiniteScroll: false,
              ),
              items: offers
                  .map(
                    (item) => InkWell(
                      splashColor: Colors.transparent,
                      child: Container(
                        alignment: Alignment.centerLeft,
                        width: MediaQuery.of(context).size.width,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(5)),
                          image: DecorationImage(
                              image:
                                  AssetImage("assets/images/" + item + ".jpeg"),
                              fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  )
                  .toList())),
      Row(children: [
        Container(
            margin: EdgeInsets.only(top: 5, right: 0, left: 20),
            child: Text(
              'Top Picks',
              textAlign: TextAlign.left,
              style: TextStyle(
                fontFamily: "AvenirBold",
                fontSize: 20,
                color: Color(0xFF0E0038),
                fontWeight: FontWeight.w700,
              ),
            )),
        SizedBox(
          width: 10,
        ),
        Container(
          margin: EdgeInsets.only(top: 5),
          height: 1.0,
          width: MediaQuery.of(context).size.width * .68,
          color: Color(0xFF0E0038),
        )
      ]),
      Container(
          width: MediaQuery.of(context).size.width * .95,
          margin: EdgeInsets.only(top: 10, right: 0, left: 10),
          child: CarouselSlider.builder(
              options: CarouselOptions(
                viewportFraction: 1.025,
                autoPlay: true,
                autoPlayInterval: Duration(seconds: 5),
                autoPlayAnimationDuration: Duration(milliseconds: 800),
                height: MediaQuery.of(context).size.width * .55,
                enableInfiniteScroll: false,
              ),
              itemCount: (vendors.length / 3).round(),
              itemBuilder: (context, index) {
                final int first = index * 3;
                final int second = first + 1;
                final int third = first + 2;
                return Row(
                    children: [first, second, third].map((idx) {
                  return Expanded(
                      flex: 1,
                      child: InkWell(
                          splashColor: Colors.transparent,
                          onTap: () {
                            gotoVendor(vendors[idx]["vendor_id"],
                                vendors[idx]["vendor_name"]);
                          },
                          child: Center(
                            child: Container(
                              margin: EdgeInsets.all(5),
                              width: MediaQuery.of(context).size.width,
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(5)),
                                image: DecorationImage(
                                    image: AssetImage("assets/images/" +
                                        vendors[idx]["vendor_id"] +
                                        ".jpg"),
                                    fit: BoxFit.cover),
                              ),
                            ),
                          )));
                }).toList());
              })),
      Row(children: [
        Container(
            margin: EdgeInsets.only(top: 10, right: 0, left: 20),
            child: Text(
              'Categories',
              textAlign: TextAlign.left,
              style: TextStyle(
                fontFamily: "AvenirBold",
                fontSize: 20,
                color: Color(0xFF0E0038),
                fontWeight: FontWeight.w700,
              ),
            )),
        SizedBox(
          width: 10,
        ),
        Container(
          margin: EdgeInsets.only(top: 10),
          height: 1.0,
          width: MediaQuery.of(context).size.width * .64,
          color: Color(0xFF0E0038),
        )
      ]),
      Center(
          child: Container(
              margin: EdgeInsets.only(right: 10, left: 10, bottom: 10),
              child: ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: 4,
                  itemBuilder: (context, index) {
                    var toload;
                    if (index == 1) {
                      toload = 2;
                    } else if (index == 2) {
                      toload = 4;
                    } else if (index == 3) {
                      toload = 6;
                    } else {
                      toload = 0;
                    }
                    if (toload <= 5) {
                      return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                                height: MediaQuery.of(context).size.width * .46,
                                width: MediaQuery.of(context).size.width * .46,
                                margin: EdgeInsets.only(top: 10),
                                child: InkWell(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(5)),
                                      image: DecorationImage(
                                          image: AssetImage("assets/images/" +
                                              categoriesJson[toload]
                                                      ["category_name"]
                                                  .toString() +
                                              ".jpg"),
                                          fit: BoxFit.cover),
                                    ),
                                  ),
                                  onTap: () => {
                                    gotoCategory(toload,
                                        categoriesJson[toload]["category_name"])
                                  },
                                )),
                            Container(
                                height: MediaQuery.of(context).size.width * .46,
                                width: MediaQuery.of(context).size.width * .46,
                                margin: EdgeInsets.only(top: 10, left: 10),
                                child: InkWell(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(5)),
                                      image: DecorationImage(
                                          image: AssetImage("assets/images/" +
                                              categoriesJson[toload + 1]
                                                      ["category_name"]
                                                  .toString() +
                                              ".jpg"),
                                          fit: BoxFit.cover),
                                    ),
                                  ),
                                  onTap: () => {
                                    gotoCategory(
                                        toload + 1,
                                        categoriesJson[toload + 1]
                                            ["category_name"])
                                  },
                                ))
                          ]);
                    } else {
                      return Row(children: [
                        Container(
                            margin: EdgeInsets.only(
                              top: 10,
                            ),
                            child: InkWell(
                              child: Container(
                                height: MediaQuery.of(context).size.width * .46,
                                width: MediaQuery.of(context).size.width * .46,
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(5)),
                                  image: DecorationImage(
                                      image: AssetImage("assets/images/" +
                                          categoriesJson[toload]
                                                  ["category_name"]
                                              .toString() +
                                          ".jpg"),
                                      fit: BoxFit.cover),
                                ),
                              ),
                              onTap: () => {
                                gotoCategory(toload,
                                    categoriesJson[toload]["category_name"])
                              },
                            )),
                        Container(
                            margin: EdgeInsets.only(top: 10, left: 10),
                            child: InkWell(
                              child: Container(
                                height: MediaQuery.of(context).size.width * .46,
                                width: MediaQuery.of(context).size.width * .46,
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(5)),
                                  image: DecorationImage(
                                      image: AssetImage(
                                          "assets/images/placeholder.jpg"),
                                      fit: BoxFit.cover),
                                ),
                              ),
                              onTap: () => {},
                            ))
                      ]);
                    }
                  })))
    ]));
  }
}

//=-= ---------------------------------------------------------
//  Main screen
//=-= ---------------------------------------------------------

class ShimmerList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    int offset = 0;
    int time = 800;
    return SafeArea(
      child: ListView.builder(
        itemCount: 7,
        itemBuilder: (BuildContext context, int index) {
          offset += 5;
          time = 800 + offset;
          return Padding(
              padding: EdgeInsets.only(left: 15, right: 15, top: 15),
              child: Shimmer.fromColors(
                highlightColor: Colors.white,
                baseColor: Colors.grey[300],
                child: ShimmerLayout(),
                period: Duration(milliseconds: time),
              ));
        },
      ),
    );
  }
}

class ShimmerLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    double containerWidth = MediaQuery.of(context).size.width * .70;
    double containerHeight = MediaQuery.of(context).size.width * .05;

    return Container(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Container(
            height: MediaQuery.of(context).size.width * .20,
            width: MediaQuery.of(context).size.width * .20,
            color: Colors.grey,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                height: containerHeight,
                width: containerWidth,
                color: Colors.grey,
              ),
              SizedBox(height: 5),
              Container(
                height: containerHeight,
                width: containerWidth,
                color: Colors.grey,
              ),
              SizedBox(height: 5),
              Container(
                height: containerHeight,
                width: containerWidth * 0.80,
                color: Colors.grey,
              )
            ],
          )
        ],
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  refreshState() {
    setState(() {});
  }

  AnimationController animationController;
  bool multiple = true;

  Future getCategories() async {
    if (isLoadingCategories) {
      http.Response offersResponse =
          await http.get('https://02c8cb08d4e2.ngrok.io/offers');
      offers = jsonDecode(offersResponse.body);
      http.Response vendorsResponse =
          await http.get('https://02c8cb08d4e2.ngrok.io/vendors_front');
      vendors = jsonDecode(vendorsResponse.body);
      http.Response response =
          await http.get("https://02c8cb08d4e2.ngrok.io/api/categories/");
      if (response.statusCode == HttpStatus.ok) {
        categoriesJson = jsonDecode(response.body);
        isLoadingCategories = false;
        setState(() {});
      }
    }
  }

  Future<void> getPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    userPhone = prefs.getString('phoneNumber');
    token = prefs.getString('knox_token');
    userSavedData = prefs.getString('saved');
    location_permission = await prefs.getString('location_permission');

    if (location_permission == "granted") {
      gotPermissions = true;
    }

    if (userSavedData != null) {
      userSavedData = jsonDecode(userSavedData);
      for (var item in userSavedData) {
        item["checked"] = false;
      }
      if (userSavedData.length > 0) {
        previouslySaved = true;
      }
    }
  }

  @override
  void initState() {
    getCategories();
    getPrefs();
    animationController = AnimationController(
        duration: const Duration(milliseconds: 2000), vsync: this);
    super.initState();
  }

  Future<bool> getData() async {
    await Future<dynamic>.delayed(const Duration(milliseconds: 0));
    return true;
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.dark));
    return Scaffold(
        backgroundColor: Colors.white,
        appBar: PreferredSize(
            preferredSize: Size.fromHeight(60),
            child: new AppBar(
                centerTitle: true,
                brightness: Brightness.dark,
                backgroundColor: Color(0xFF0E0038),
                title: Image.asset(
                  "assets/images/appbar.png",
                  height: 40,
                  width: 120,
                ),
                actions: [SearchIcon()])),
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: FutureBuilder<bool>(
              future: getData(),
              builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
                if (!snapshot.hasData) {
                  return ShimmerList();
                } else {
                  return Categories();
                }
              }),
        ));
  }
}

//=-= ---------------------------------------------------------
//  Cart page
//=-= ---------------------------------------------------------

class CartPage extends StatefulWidget {
  const CartPage({Key key2}) : super(key: key2);

  @override
  _CartPageState createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  var title;
  var message;

  gotoOrderConfirm() {
    if (getTotalInit() >= 10) {
      Navigator.push(
          context, MaterialPageRoute(builder: (context) => OrderConfirm()));
    } else {
      title = "Error";
      message = "Minimum order is \u{20B9}10";
      showInfoFlushbar(context);
    }
  }

  void showInfoFlushbar(BuildContext context) {
    Flushbar(
      title: title,
      message: message,
      icon: Icon(Icons.delete, size: 28, color: Colors.red.shade600),
      duration: Duration(seconds: 5),
      leftBarIndicatorColor: Colors.red.shade600,
    )..show(context);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness:
          Platform.isAndroid ? Brightness.dark : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    return MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => Total())],
        child: Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(60),
              child: new AppBar(
                brightness: Brightness.dark, // or use Brightness.dark
                backgroundColor: Color(0xFF0E0038),
                centerTitle: true,
                title: Text(
                  'Shopping Cart',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: "AvenirBold",
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                actions: [DeleteAllItems()],
              ),
            ),
            body: AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle.dark, child: CartPageExt()),
            bottomNavigationBar: getTotalInit() == 0 || getTotalInit() == null
                ? Container(
                    color: Colors.white,
                    height: MediaQuery.of(context).padding.bottom + 60,
                    child: Center(),
                  )
                : Container(
                    color: Colors.white,
                    height: MediaQuery.of(context).padding.bottom + 60,
                    child: Material(
                      color: Colors.red,
                      child: InkWell(
                        onTap: () => gotoOrderConfirm(),
                        child: Padding(
                            padding: EdgeInsets.all(15),
                            child: CartPageButton()),
                      ),
                    ),
                  )));
  }
}

class CartPageButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    context.watch<Total>().getTotalButtonVal();
    return Consumer<Total>(
        builder: (context, counter, child) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(' '),
                Text(
                  'Continue  \u{20B9} ' +
                      context.watch<Total>().totalButtonVal.toString(),
                  style: TextStyle(color: Colors.white, fontSize: 20),
                  textAlign: TextAlign.right,
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                ),
              ],
            ));
  }
}

class CartPageExt extends StatefulWidget {
  @override
  _CartPageStateExt createState() => _CartPageStateExt();
}

class _CartPageStateExt extends State<CartPageExt> {
  var title;
  var message;
  var filteredList = [];

  activeTap(index1, index, type) {
    menuJson["menu"][index1][index]["active"] =
        !menuJson["menu"][index1][index]["active"];
    plus(index1, index, type);
  }

  minus(index1, index, type) {
    var quant;
    if (type == "quantity") {
      menuJson["menu"][index1][index]["quantity"]["quantity"]--;
      quant = menuJson["menu"][index1][index]["quantity"]["quantity"];
      if (quant <= 0) {
        if (quant == 0) {
          menuJson["menu"][index1][index]["active"] = false;
        }
        menuJson["menu"][index1][index]["quantity"]["quantity"] = 0;
      }
    } else if (type == "10g") {
      menuJson["menu"][index1][index]["quantity"]["10g"]--;
      quant = menuJson["menu"][index1][index]["quantity"]["10g"];
      if (quant <= 0) {
        if (quant == 0) {
          menuJson["menu"][index1][index]["active"] = false;
        }
        menuJson["menu"][index1][index]["quantity"]["10g"] = 0;
      }
    } else if (type == "25g") {
      menuJson["menu"][index1][index]["quantity"]["25g"]--;
      quant = menuJson["menu"][index1][index]["quantity"]["25g"];
      if (quant <= 0) {
        if (quant == 0) {
          menuJson["menu"][index1][index]["active"] = false;
        }
        menuJson["menu"][index1][index]["quantity"]["25g"] = 0;
      }
    } else if (type == "50g") {
      menuJson["menu"][index1][index]["quantity"]["50g"]--;
      quant = menuJson["menu"][index1][index]["quantity"]["50g"];
      if (quant <= 0) {
        if (quant == 0) {
          menuJson["menu"][index1][index]["active"] = false;
        }
        menuJson["menu"][index1][index]["quantity"]["50g"] = 0;
      }
    } else if (type == "100g") {
      menuJson["menu"][index1][index]["quantity"]["100g"]--;
      quant = menuJson["menu"][index1][index]["quantity"]["100g"];
      if (quant <= 0) {
        if (quant == 0) {
          menuJson["menu"][index1][index]["active"] = false;
        }
        menuJson["menu"][index1][index]["quantity"]["100g"] = 0;
      }
    } else if (type == "250g") {
      menuJson["menu"][index1][index]["quantity"]["250g"]--;
      quant = menuJson["menu"][index1][index]["quantity"]["250g"];
      if (quant <= 0) {
        if (quant == 0) {
          menuJson["menu"][index1][index]["active"] = false;
        }
        menuJson["menu"][index1][index]["quantity"]["250g"] = 0;
      }
    } else if (type == "500g") {
      menuJson["menu"][index1][index]["quantity"]["500g"]--;
      quant = menuJson["menu"][index1][index]["quantity"]["500g"];
      if (quant <= 0) {
        if (quant == 0) {
          menuJson["menu"][index1][index]["active"] = false;
        }
        menuJson["menu"][index1][index]["quantity"]["500g"] = 0;
      }
    } else if (type == "1kg") {
      menuJson["menu"][index1][index]["quantity"]["1kg"]--;
      quant = menuJson["menu"][index1][index]["quantity"]["1kg"];
      if (quant <= 0) {
        if (quant == 0) {
          menuJson["menu"][index1][index]["active"] = false;
        }
        menuJson["menu"][index1][index]["quantity"]["1kg"] = 0;
      }
    } else if (type == "2kg") {
      menuJson["menu"][index1][index]["quantity"]["2kg"]--;
      quant = menuJson["menu"][index1][index]["quantity"]["2kg"];
      if (quant <= 0) {
        if (quant == 0) {
          menuJson["menu"][index1][index]["active"] = false;
        }
        menuJson["menu"][index1][index]["quantity"]["2kg"] = 0;
      }
    } else if (type == "small") {
      menuJson["menu"][index1][index]["quantity"]["small"]--;
      quant = menuJson["menu"][index1][index]["quantity"]["small"];
      if (quant <= 0) {
        if (quant == 0) {
          menuJson["menu"][index1][index]["active"] = false;
        }
        menuJson["menu"][index1][index]["quantity"]["small"] = 0;
      }
    } else if (type == "medium") {
      menuJson["menu"][index1][index]["quantity"]["medium"]--;
      quant = menuJson["menu"][index1][index]["quantity"]["medium"];
      if (quant <= 0) {
        if (quant == 0) {
          menuJson["menu"][index1][index]["active"] = false;
        }
        menuJson["menu"][index1][index]["quantity"]["medium"] = 0;
      }
    } else if (type == "large") {
      menuJson["menu"][index1][index]["quantity"]["large"]--;
      quant = menuJson["menu"][index1][index]["quantity"]["large"];
      if (quant <= 0) {
        if (quant == 0) {
          menuJson["menu"][index1][index]["active"] = false;
        }
        menuJson["menu"][index1][index]["quantity"]["large"] = 0;
      }
    }
    context.read<Total>().getTotalButtonVal();
    setState(() {});
  }

  plus(index1, index, type) {
    var quant;
    if (type == "quantity") {
      menuJson["menu"][index1][index]["quantity"]["quantity"]++;
      quant = menuJson["menu"][index1][index]["quantity"]["quantity"];

      if (quant > 15) {
        title = "Error";
        message = "Maximum quantity allowed is 15.";
        showInfoFlushbar3(context);
        menuJson["menu"][index1][index]["quantity"]["quantity"]--;
      }
    } else if (type == "10g") {
      menuJson["menu"][index1][index]["quantity"]["10g"]++;
      quant = menuJson["menu"][index1][index]["quantity"]["10g"];

      if (quant > 15) {
        title = "Error";
        message = "Maximum quantity allowed is 15.";
        showInfoFlushbar3(context);
        menuJson["menu"][index1][index]["quantity"]["10g"]--;
      }
    } else if (type == "25g") {
      menuJson["menu"][index1][index]["quantity"]["25g"]++;
      quant = menuJson["menu"][index1][index]["quantity"]["25g"];

      if (quant > 15) {
        title = "Error";
        message = "Maximum quantity allowed is 15.";
        showInfoFlushbar3(context);
        menuJson["menu"][index1][index]["quantity"]["25g"]--;
      }
    } else if (type == "50g") {
      menuJson["menu"][index1][index]["quantity"]["50g"]++;
      quant = menuJson["menu"][index1][index]["quantity"]["50g"];

      if (quant > 15) {
        title = "Error";
        message = "Maximum quantity allowed is 15.";
        showInfoFlushbar3(context);
        menuJson["menu"][index1][index]["quantity"]["50g"]--;
      }
    } else if (type == "100g") {
      menuJson["menu"][index1][index]["quantity"]["100g"]++;
      quant = menuJson["menu"][index1][index]["quantity"]["100g"];

      if (quant > 15) {
        title = "Error";
        message = "Maximum quantity allowed is 15.";
        showInfoFlushbar3(context);
        menuJson["menu"][index1][index]["quantity"]["100g"]--;
      }
    } else if (type == "250g") {
      menuJson["menu"][index1][index]["quantity"]["250g"]++;
      quant = menuJson["menu"][index1][index]["quantity"]["250g"];

      if (quant > 15) {
        title = "Error";
        message = "Maximum quantity allowed is 15.";
        showInfoFlushbar3(context);
        menuJson["menu"][index1][index]["quantity"]["250g"]--;
      }
    } else if (type == "500g") {
      menuJson["menu"][index1][index]["quantity"]["500g"]++;
      quant = menuJson["menu"][index1][index]["quantity"]["500g"];

      if (quant > 15) {
        title = "Error";
        message = "Maximum quantity allowed is 15.";
        showInfoFlushbar3(context);
        menuJson["menu"][index1][index]["quantity"]["500g"]--;
      }
    } else if (type == "1kg") {
      menuJson["menu"][index1][index]["quantity"]["1kg"]++;
      quant = menuJson["menu"][index1][index]["quantity"]["1kg"];

      if (quant > 15) {
        title = "Error";
        message = "Maximum quantity allowed is 15.";
        showInfoFlushbar3(context);
        menuJson["menu"][index1][index]["quantity"]["1kg"]--;
      }
    } else if (type == "2kg") {
      menuJson["menu"][index1][index]["quantity"]["2kg"]++;
      quant = menuJson["menu"][index1][index]["quantity"]["2kg"];

      if (quant > 15) {
        title = "Error";
        message = "Maximum quantity allowed is 15.";
        showInfoFlushbar3(context);
        menuJson["menu"][index1][index]["quantity"]["2kg"]--;
      }
    } else if (type == "small") {
      menuJson["menu"][index1][index]["quantity"]["small"]++;
      quant = menuJson["menu"][index1][index]["quantity"]["small"];

      if (quant > 15) {
        title = "Error";
        message = "Maximum quantity allowed is 15.";
        showInfoFlushbar3(context);
        menuJson["menu"][index1][index]["quantity"]["small"]--;
      }
    } else if (type == "medium") {
      menuJson["menu"][index1][index]["quantity"]["medium"]++;
      quant = menuJson["menu"][index1][index]["quantity"]["medium"];

      if (quant > 15) {
        title = "Error";
        message = "Maximum quantity allowed is 15.";
        showInfoFlushbar3(context);
        menuJson["menu"][index1][index]["quantity"]["medium"]--;
      }
    } else if (type == "large") {
      menuJson["menu"][index1][index]["quantity"]["large"]++;
      quant = menuJson["menu"][index1][index]["quantity"]["large"];

      if (quant > 15) {
        title = "Error";
        message = "Maximum quantity allowed is 15.";
        showInfoFlushbar3(context);
        menuJson["menu"][index1][index]["quantity"]["large"]--;
      }
    }
    context.read<Total>().getTotalButtonVal();
    setState(() {});
  }

  getPrice(index, index2, type) {
    if (type == 1) {
      return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Container(
                child: Text(
              '\u{20B9}' +
                  menuJson["menu"][index][index2]["original_price"]
                          ["original_price"]
                      .toString(),
              style: TextStyle(color: Colors.black, fontSize: 16),
            )),
            Container(
                padding: EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: Colors.white,
                  border: Border.all(
                    color: Colors.grey,
                    width: 1,
                  ),
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      InkWell(
                          splashColor: Colors.transparent,
                          onTap: () {
                            plus(
                                index,
                                menuJson["menu"][index][index2]["index"],
                                "quantity");
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: Colors.red,
                            ),
                            width: 25.0,
                            height: 25.0,
                            child: new Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 20,
                            ),
                          )),
                      Container(
                        padding: EdgeInsets.only(
                          left: 15,
                        ),
                        child: Text(
                            menuJson["menu"][index][index2]["quantity"]
                                    ["quantity"]
                                .toString(),
                            style: new TextStyle(fontSize: 20.0)),
                      ),
                      Container(
                        padding: EdgeInsets.only(
                          left: 15,
                        ),
                        child: InkWell(
                            splashColor: Colors.transparent,
                            onTap: () {
                              minus(
                                  index,
                                  menuJson["menu"][index][index2]["index"],
                                  "quantity");
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5),
                                color: Colors.red,
                              ),
                              width: 25.0,
                              height: 25.0,
                              child: Icon(
                                Icons.remove,
                                color: Colors.white,
                                size: 20,
                              ),
                            )),
                      )
                    ])),
          ]);
    } else if (type == 2) {
      List<Widget> rowList = new List<Widget>();
      List<Widget> columnList = List<Widget>();

      if (menuJson["menu"][index][index2]["original_price"]["10g"] != 0 &&
          menuJson["menu"][index][index2]["original_price"]["10g"] != null) {
        rowList.add(
          Container(
              width: 150,
              padding: EdgeInsets.only(top: 5),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "10g",
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                    Text(
                      '\u{20B9}' +
                          menuJson["menu"][index][index2]["original_price"]
                                  ["10g"]
                              .toString(),
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    )
                  ])),
        );
        rowList.add(
          Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: Colors.white,
                border: Border.all(
                  color: Colors.grey,
                  width: 1,
                ),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    InkWell(
                        splashColor: Colors.transparent,
                        onTap: () {
                          plus(index, index2, "10g");
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.red,
                          ),
                          width: 25.0,
                          height: 25.0,
                          child: new Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        )),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: Text(
                          menuJson["menu"][index][index2]["quantity"]["10g"]
                              .toString(),
                          style: new TextStyle(fontSize: 20.0)),
                    ),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: InkWell(
                          splashColor: Colors.transparent,
                          onTap: () {
                            minus(index, index2, "10g");
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: Colors.red,
                            ),
                            width: 25.0,
                            height: 25.0,
                            child: Icon(
                              Icons.remove,
                              color: Colors.white,
                              size: 20,
                            ),
                          )),
                    )
                  ])),
        );
        columnList.add(Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rowList));
        columnList.add(SizedBox(
          height: 10,
        ));
        rowList = new List<Widget>();
      }
      if (menuJson["menu"][index][index2]["original_price"]["25g"] != 0 &&
          menuJson["menu"][index][index2]["original_price"]["25g"] != null) {
        rowList.add(
          Container(
              width: 150,
              padding: EdgeInsets.only(top: 5),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "25g",
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                    Text(
                      '\u{20B9}' +
                          menuJson["menu"][index][index2]["original_price"]
                                  ["25g"]
                              .toString(),
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    )
                  ])),
        );
        rowList.add(
          Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: Colors.white,
                border: Border.all(
                  color: Colors.grey,
                  width: 1,
                ),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    InkWell(
                        splashColor: Colors.transparent,
                        onTap: () {
                          plus(index, index2, "25g");
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.red,
                          ),
                          width: 25.0,
                          height: 25.0,
                          child: new Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        )),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: Text(
                          menuJson["menu"][index][index2]["quantity"]["25g"]
                              .toString(),
                          style: new TextStyle(fontSize: 20.0)),
                    ),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: InkWell(
                          splashColor: Colors.transparent,
                          onTap: () {
                            minus(index, index2, "25g");
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: Colors.red,
                            ),
                            width: 25.0,
                            height: 25.0,
                            child: Icon(
                              Icons.remove,
                              color: Colors.white,
                              size: 20,
                            ),
                          )),
                    )
                  ])),
        );
        columnList.add(Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rowList));
        columnList.add(SizedBox(
          height: 10,
        ));
        rowList = new List<Widget>();
      }
      if (menuJson["menu"][index][index2]["original_price"]["50g"] != 0 &&
          menuJson["menu"][index][index2]["original_price"]["50g"] != null) {
        rowList.add(
          Container(
              width: 150,
              padding: EdgeInsets.only(top: 5),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "50g",
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                    Text(
                      '\u{20B9}' +
                          menuJson["menu"][index][index2]["original_price"]
                                  ["50g"]
                              .toString(),
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    )
                  ])),
        );
        rowList.add(
          Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: Colors.white,
                border: Border.all(
                  color: Colors.grey,
                  width: 1,
                ),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    InkWell(
                        splashColor: Colors.transparent,
                        onTap: () {
                          plus(index, index2, "50g");
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.red,
                          ),
                          width: 25.0,
                          height: 25.0,
                          child: new Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        )),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: Text(
                          menuJson["menu"][index][index2]["quantity"]["50g"]
                              .toString(),
                          style: new TextStyle(fontSize: 20.0)),
                    ),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: InkWell(
                          splashColor: Colors.transparent,
                          onTap: () {
                            minus(index, index2, "50g");
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: Colors.red,
                            ),
                            width: 25.0,
                            height: 25.0,
                            child: Icon(
                              Icons.remove,
                              color: Colors.white,
                              size: 20,
                            ),
                          )),
                    )
                  ])),
        );
        columnList.add(Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rowList));
        columnList.add(SizedBox(
          height: 10,
        ));
        rowList = new List<Widget>();
      }

      if (menuJson["menu"][index][index2]["original_price"]["100g"] != 0 &&
          menuJson["menu"][index][index2]["original_price"]["100g"] != null) {
        rowList.add(
          Container(
              width: 150,
              padding: EdgeInsets.only(top: 5),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "100g",
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                    Text(
                      '\u{20B9}' +
                          menuJson["menu"][index][index2]["original_price"]
                                  ["100g"]
                              .toString(),
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    )
                  ])),
        );

        rowList.add(
          Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: Colors.white,
                border: Border.all(
                  color: Colors.grey,
                  width: 1,
                ),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    InkWell(
                        splashColor: Colors.transparent,
                        onTap: () {
                          plus(index, index2, "100g");
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.red,
                          ),
                          width: 25.0,
                          height: 25.0,
                          child: new Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        )),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: Text(
                          menuJson["menu"][index][index2]["quantity"]["100g"]
                              .toString(),
                          style: new TextStyle(fontSize: 20.0)),
                    ),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: InkWell(
                          splashColor: Colors.transparent,
                          onTap: () {
                            minus(index, index2, "100g");
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: Colors.red,
                            ),
                            width: 25.0,
                            height: 25.0,
                            child: Icon(
                              Icons.remove,
                              color: Colors.white,
                              size: 20,
                            ),
                          )),
                    )
                  ])),
        );
        columnList.add(Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rowList));
        columnList.add(SizedBox(
          height: 10,
        ));
        rowList = new List<Widget>();
      }
      if (menuJson["menu"][index][index2]["original_price"]["250g"] != 0 &&
          menuJson["menu"][index][index2]["original_price"]["250g"] != null) {
        rowList.add(
          Container(
              width: 150,
              padding: EdgeInsets.only(top: 5),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "250g",
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                    Text(
                      '\u{20B9}' +
                          menuJson["menu"][index][index2]["original_price"]
                                  ["250g"]
                              .toString(),
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    )
                  ])),
        );

        rowList.add(
          Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: Colors.white,
                border: Border.all(
                  color: Colors.grey,
                  width: 1,
                ),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    InkWell(
                        splashColor: Colors.transparent,
                        onTap: () {
                          plus(index, index2, "250g");
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.red,
                          ),
                          width: 25.0,
                          height: 25.0,
                          child: new Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        )),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: Text(
                          menuJson["menu"][index][index2]["quantity"]["250g"]
                              .toString(),
                          style: new TextStyle(fontSize: 20.0)),
                    ),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: InkWell(
                          splashColor: Colors.transparent,
                          onTap: () {
                            minus(index, index2, "250g");
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: Colors.red,
                            ),
                            width: 25.0,
                            height: 25.0,
                            child: Icon(
                              Icons.remove,
                              color: Colors.white,
                              size: 20,
                            ),
                          )),
                    )
                  ])),
        );
        columnList.add(Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rowList));
        columnList.add(SizedBox(
          height: 10,
        ));
        rowList = new List<Widget>();
      }
      if (menuJson["menu"][index][index2]["original_price"]["500g"] != 0 &&
          menuJson["menu"][index][index2]["original_price"]["500g"] != null) {
        rowList.add(
          Container(
              width: 150,
              padding: EdgeInsets.only(top: 5),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "500g",
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                    Text(
                      '\u{20B9}' +
                          menuJson["menu"][index][index2]["original_price"]
                                  ["500g"]
                              .toString(),
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    )
                  ])),
        );
        rowList.add(
          Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: Colors.white,
                border: Border.all(
                  color: Colors.grey,
                  width: 1,
                ),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    InkWell(
                        splashColor: Colors.transparent,
                        onTap: () {
                          plus(index, index2, "500g");
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.red,
                          ),
                          width: 25.0,
                          height: 25.0,
                          child: new Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        )),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: Text(
                          menuJson["menu"][index][index2]["quantity"]["500g"]
                              .toString(),
                          style: new TextStyle(fontSize: 20.0)),
                    ),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: InkWell(
                          splashColor: Colors.transparent,
                          onTap: () {
                            minus(index, index2, "500g");
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: Colors.red,
                            ),
                            width: 25.0,
                            height: 25.0,
                            child: Icon(
                              Icons.remove,
                              color: Colors.white,
                              size: 20,
                            ),
                          )),
                    )
                  ])),
        );
        columnList.add(Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rowList));
        columnList.add(SizedBox(
          height: 10,
        ));
        rowList = new List<Widget>();
      }
      if (menuJson["menu"][index][index2]["original_price"]["1kg"] != 0 &&
          menuJson["menu"][index][index2]["original_price"]["1kg"] != null) {
        rowList.add(
          Container(
              width: 150,
              padding: EdgeInsets.only(top: 5),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "1kg",
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                    Text(
                      '\u{20B9}' +
                          menuJson["menu"][index][index2]["original_price"]
                                  ["1kg"]
                              .toString(),
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    )
                  ])),
        );
        rowList.add(
          Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: Colors.white,
                border: Border.all(
                  color: Colors.grey,
                  width: 1,
                ),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    InkWell(
                        splashColor: Colors.transparent,
                        onTap: () {
                          plus(index, index2, "1kg");
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.red,
                          ),
                          width: 25.0,
                          height: 25.0,
                          child: new Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        )),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: Text(
                          menuJson["menu"][index][index2]["quantity"]["1kg"]
                              .toString(),
                          style: new TextStyle(fontSize: 20.0)),
                    ),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: InkWell(
                          splashColor: Colors.transparent,
                          onTap: () {
                            minus(index, index2, "1kg");
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: Colors.red,
                            ),
                            width: 25.0,
                            height: 25.0,
                            child: Icon(
                              Icons.remove,
                              color: Colors.white,
                              size: 20,
                            ),
                          )),
                    )
                  ])),
        );
        columnList.add(Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rowList));
        columnList.add(SizedBox(
          height: 10,
        ));
        rowList = new List<Widget>();
      }
      if (menuJson["menu"][index][index2]["original_price"]["2kg"] != 0 &&
          menuJson["menu"][index][index2]["original_price"]["2kg"] != null) {
        rowList.add(
          Container(
              width: 150,
              padding: EdgeInsets.only(top: 5),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "2kg",
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                    Text(
                      '\u{20B9}' +
                          menuJson["menu"][index][index2]["original_price"]
                                  ["2kg"]
                              .toString(),
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    )
                  ])),
        );
        rowList.add(
          Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: Colors.white,
                border: Border.all(
                  color: Colors.grey,
                  width: 1,
                ),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    InkWell(
                        splashColor: Colors.transparent,
                        onTap: () {
                          plus(index, index2, "2kg");
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.red,
                          ),
                          width: 25.0,
                          height: 25.0,
                          child: new Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        )),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: Text(
                          menuJson["menu"][index][index2]["quantity"]["2kg"]
                              .toString(),
                          style: new TextStyle(fontSize: 20.0)),
                    ),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                        right: 5,
                      ),
                      child: InkWell(
                          splashColor: Colors.transparent,
                          onTap: () {
                            minus(index, index2, "2kg");
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: Colors.red,
                            ),
                            width: 25.0,
                            height: 25.0,
                            child: Icon(
                              Icons.remove,
                              color: Colors.white,
                              size: 20,
                            ),
                          )),
                    )
                  ])),
        );
        columnList.add(Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rowList));
        columnList.add(SizedBox(
          height: 10,
        ));
        rowList = new List<Widget>();
      }
      return new Column(children: columnList);
    } else if (type == 3) {
      List<Widget> columnList = new List<Widget>();
      List<Widget> rowList = new List<Widget>();

      if (menuJson["menu"][index][index2]["original_price"]["small"] != 0) {
        rowList.add(
          Container(
              width: 150,
              padding: EdgeInsets.only(top: 5),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Small ",
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                    Text(
                      ' \u{20B9}' +
                          menuJson["menu"][index][index2]["original_price"]
                                  ["small"]
                              .toString(),
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    )
                  ])),
        );
        rowList.add(
          Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: Colors.white,
                border: Border.all(
                  color: Colors.grey,
                  width: 1,
                ),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    InkWell(
                        splashColor: Colors.transparent,
                        onTap: () {
                          plus(index, index2, "small");
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.red,
                          ),
                          width: 25.0,
                          height: 25.0,
                          child: new Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        )),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: Text(
                          menuJson["menu"][index][index2]["quantity"]["small"]
                              .toString(),
                          style: new TextStyle(fontSize: 20.0)),
                    ),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                        right: 5,
                      ),
                      child: InkWell(
                          splashColor: Colors.transparent,
                          onTap: () {
                            minus(index, index2, "small");
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: Colors.red,
                            ),
                            width: 25.0,
                            height: 25.0,
                            child: Icon(
                              Icons.remove,
                              color: Colors.white,
                              size: 20,
                            ),
                          )),
                    )
                  ])),
        );

        columnList.add(Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rowList));
        columnList.add(SizedBox(
          height: 10,
        ));
        rowList = new List<Widget>();
      }
      if (menuJson["menu"][index][index2]["original_price"]["medium"] != 0) {
        rowList.add(
          Container(
              width: 150,
              padding: EdgeInsets.only(top: 5),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Medium ",
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                    Text(
                      ' \u{20B9}' +
                          menuJson["menu"][index][index2]["original_price"]
                                  ["medium"]
                              .toString(),
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    )
                  ])),
        );
        rowList.add(
          Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: Colors.white,
                border: Border.all(
                  color: Colors.grey,
                  width: 1,
                ),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    InkWell(
                        splashColor: Colors.transparent,
                        onTap: () {
                          plus(index, index2, "medium");
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.red,
                          ),
                          width: 25.0,
                          height: 25.0,
                          child: new Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        )),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: Text(
                          menuJson["menu"][index][index2]["quantity"]["medium"]
                              .toString(),
                          style: new TextStyle(fontSize: 20.0)),
                    ),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                        right: 5,
                      ),
                      child: InkWell(
                          splashColor: Colors.transparent,
                          onTap: () {
                            minus(index, index2, "medium");
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: Colors.red,
                            ),
                            width: 25.0,
                            height: 25.0,
                            child: Icon(
                              Icons.remove,
                              color: Colors.white,
                              size: 20,
                            ),
                          )),
                    )
                  ])),
        );

        columnList.add(Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rowList));
        columnList.add(SizedBox(
          height: 10,
        ));
        rowList = new List<Widget>();
      }
      if (menuJson["menu"][index][index2]["original_price"]["large"] != 0) {
        rowList.add(
          Container(
              width: 150,
              padding: EdgeInsets.only(top: 5),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Large ",
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                    Text(
                      ' \u{20B9}' +
                          menuJson["menu"][index][index2]["original_price"]
                                  ["large"]
                              .toString(),
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    )
                  ])),
        );
        rowList.add(Container(
            padding: EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: Colors.white,
              border: Border.all(
                color: Colors.grey,
                width: 1,
              ),
            ),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  InkWell(
                      splashColor: Colors.transparent,
                      onTap: () {
                        plus(index, index2, "large");
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: Colors.red,
                        ),
                        width: 25.0,
                        height: 25.0,
                        child: new Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 20,
                        ),
                      )),
                  Container(
                    padding: EdgeInsets.only(
                      left: 15,
                    ),
                    child: Text(
                        menuJson["menu"][index][index2]["quantity"]["large"]
                            .toString(),
                        style: new TextStyle(fontSize: 20.0)),
                  ),
                  Container(
                    padding: EdgeInsets.only(
                      left: 15,
                      right: 5,
                    ),
                    child: InkWell(
                        splashColor: Colors.transparent,
                        onTap: () {
                          minus(index, index2, "large");
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.red,
                          ),
                          width: 25.0,
                          height: 25.0,
                          child: Icon(
                            Icons.remove,
                            color: Colors.white,
                            size: 20,
                          ),
                        )),
                  )
                ])));

        columnList.add(Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rowList));
        columnList.add(SizedBox(
          height: 10,
        ));
        rowList = new List<Widget>();
      }

      return new Column(children: columnList);
    }
  }

  returnContainer(index, index2) {
    if (menuJson["menu"][index][index2]["type"] == 1) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        height: 67,
                        padding: EdgeInsets.only(),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: FadeInImage.assetNetwork(
                            height: 150,
                            width: 100,
                            placeholder: 'assets/images/loader.gif',
                            image: 'https://02c8cb08d4e2.ngrok.io/static/img/' +
                                menuJson["menu"][index][index2]["product_id"] +
                                ".jpg",
                          ),
                        )),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              width: MediaQuery.of(context).size.width * .61,
                              padding: EdgeInsets.only(left: 10),
                              child: Text(
                                menuJson["menu"][index][index2]["product_name"],
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                                textAlign: TextAlign.left,
                              ),
                            ),
                          ]),
                          Container(
                              height: 51,
                              width: MediaQuery.of(context).size.width * .61,
                              padding: EdgeInsets.only(left: 10, top: 2),
                              child: Text(
                                menuJson["menu"][index][index2]["description"],
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 12),
                                textAlign: TextAlign.left,
                              )),
                        ]),
                  ],
                ),
              ]),
          Column(children: [
            getPrice(index, menuJson["menu"][index][index2]["index"],
                menuJson["menu"][index][index2]["type"])
          ])
        ],
      );
    } else if (menuJson["menu"][index][index2]["type"] == 2) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        height: 68,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: FadeInImage.assetNetwork(
                            height: 150,
                            width: 100,
                            placeholder: 'assets/images/loader.gif',
                            image: 'https://02c8cb08d4e2.ngrok.io/static/img/' +
                                menuJson["menu"][index][index2]["product_id"] +
                                ".jpg",
                          ),
                        )),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * .70,
                            padding: EdgeInsets.only(left: 10),
                            child: Text(
                              menuJson["menu"][index][index2]["product_name"],
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                          Container(
                              height: 51,
                              width: MediaQuery.of(context).size.width * .70,
                              padding: EdgeInsets.only(left: 10, top: 2),
                              child: Text(
                                menuJson["menu"][index][index2]["description"],
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 12),
                                textAlign: TextAlign.left,
                              )),
                        ]),
                  ],
                ),
              ],
            ),
            Container(
              margin: EdgeInsets.only(top: 5, left: 0, bottom: 10),
              child: getPrice(index, menuJson["menu"][index][index2]["index"],
                  menuJson["menu"][index][index2]["type"]),
            )
          ])
        ],
      );
    } else if (menuJson["menu"][index][index2]["type"] == 3) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        height: 67,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: FadeInImage.assetNetwork(
                            height: 150,
                            width: 100,
                            placeholder: 'assets/images/loader.gif',
                            image: 'https://02c8cb08d4e2.ngrok.io/static/img/' +
                                menuJson["menu"][index][index2]["product_id"] +
                                ".jpg",
                          ),
                        )),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * .70,
                            padding: EdgeInsets.only(left: 10),
                            child: Text(
                              menuJson["menu"][index][index2]["product_name"],
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                          Container(
                              height: 51,
                              width: MediaQuery.of(context).size.width * .70,
                              padding: EdgeInsets.only(left: 10, top: 2),
                              child: Text(
                                menuJson["menu"][index][index2]["description"],
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 12),
                                textAlign: TextAlign.left,
                              )),
                        ]),
                  ],
                ),
              ],
            ),
            Container(
              margin: EdgeInsets.only(top: 5, left: 0, bottom: 10),
              child: getPrice(index, menuJson["menu"][index][index2]["index"],
                  menuJson["menu"][index][index2]["type"]),
            )
          ])
        ],
      );
    }
  }

  void showInfoFlushbar3(BuildContext context) {
    Flushbar(
      title: title,
      message: message,
      icon: Icon(Icons.check, size: 28, color: Colors.green.shade300),
      duration: Duration(seconds: 5),
      leftBarIndicatorColor: Colors.green.shade300,
    )..show(context);
  }

  void showInfoFlushbar(BuildContext context) {
    Flushbar(
      title: title,
      message: message,
      icon: Icon(Icons.delete, size: 28, color: Colors.red.shade600),
      duration: Duration(seconds: 5),
      leftBarIndicatorColor: Colors.red.shade600,
    )..show(context);
  }

  @override
  Widget build(BuildContext context) {
    filteredList = [];
    if (menuJson != null) {
      for (var i = 0; i < menuJson["menu"].length; i++) {
        for (var item in menuJson["menu"][i]) {
          if (item["type"] == 1) {
            if (item["quantity"]["quantity"] > 0) {
              filteredList.add(item);
            }
          } else if (item["type"] == 2) {
            if (item["quantity"]["10g"] > 0) {
              filteredList.add(item);
            } else if (item["quantity"]["25g"] > 0) {
              filteredList.add(item);
            } else if (item["quantity"]["50g"] > 0) {
              filteredList.add(item);
            } else if (item["quantity"]["100g"] > 0) {
              filteredList.add(item);
            } else if (item["quantity"]["250g"] > 0) {
              filteredList.add(item);
            } else if (item["quantity"]["500g"] > 0) {
              filteredList.add(item);
            } else if (item["quantity"]["1kg"] > 0) {
              filteredList.add(item);
            } else if (item["quantity"]["2kg"] > 0) {
              filteredList.add(item);
            }
          } else if (item["type"] == 3) {
            if (item["quantity"]["small"] > 0) {
              filteredList.add(item);
            } else if (item["quantity"]["medium"] > 0) {
              filteredList.add(item);
            } else if (item["quantity"]["large"] > 0) {
              filteredList.add(item);
            }
          }
        }
      }
    }

    return Container(
        padding: EdgeInsets.only(top: 10, bottom: 10, left: 10, right: 5),
        color: Colors.white,
        child: filteredList.length > 0
            ? ListView.builder(
                itemCount: filteredList.length,
                itemBuilder: (context, index) {
                  return Container(
                      margin: EdgeInsets.only(bottom: 10),
                      child: Container(
                          // height: returnHeight(
                          //     filteredList[index]["filtered_index"],
                          //     filteredList[index]["index"]),
                          width: MediaQuery.of(context).size.width,
                          child: returnContainer(
                              filteredList[index]["filtered_index"],
                              filteredList[index]["index"])));
                })
            : Center(
                child: Container(
                    padding: EdgeInsets.only(left: 5, bottom: 10),
                    child: Column(children: [
                      Image.asset("assets/images/cartbg.png",
                          width: MediaQuery.of(context).size.width),
                      Text(
                        "Your cart is empty!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: "AvenirBold",
                          fontSize: 30,
                          color: Colors.red,
                        ),
                      ),
                      Text(
                        "Add items to your cart and enjoy quick home delivery",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: "Avenir",
                          fontSize: 15,
                          color: Colors.red,
                        ),
                      )
                    ])),
              ));
  }
}

//=-= ---------------------------------------------------------
//  Order Confirm page
//=-= ---------------------------------------------------------

class OrderConfirm extends StatefulWidget {
  const OrderConfirm({Key key2}) : super(key: key2);

  @override
  _OrderConfirm createState() => _OrderConfirm();
}

class _OrderConfirm extends State<OrderConfirm> {
  final _couponController = TextEditingController();

  var title;
  var message;

  gotoAddressPage() {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => AddressPage()));
  }

  applyCouponCode() async {
    getDeliveryCharges();
    appliedCoupon = _couponController.text;
    var dataCoupon = {};
    dataCoupon['phone_number'] = userPhone;
    dataCoupon['coupon_code'] = _couponController.text;

    http.Response httpresponse = await http.post(
      'https://02c8cb08d4e2.ngrok.io/check_coupon',
      body: dataCoupon,
    );

    if (httpresponse.statusCode == HttpStatus.ok) {
      var response = jsonDecode(httpresponse.body);
      if (response["success"]) {
        title = "Success!";
        message = response["message"];
        showInfoFlushbar(context);
        if (response["free_delivery"]) {
          deliveryCharges = 0;
          deliveryMessage = "Delivery charges: FREE!";
          freeDelivery = true;
        } else {
          freeDelivery = false;
        }
        discountPercent = response["discount"];
        maxDiscount = response["max_discount"];
      } else {
        title = "Error!";
        message = response["message"];
        showInfoFlushbar2(context);
      }
    } else {
      title = "Error";
      message = "Internal Server Error";
      showInfoFlushbar2(context);
    }
    setState(() {});
  }

  void showInfoFlushbar(BuildContext context) {
    Flushbar(
      title: title,
      message: message,
      icon: Icon(Icons.check, size: 28, color: Colors.green.shade300),
      duration: Duration(seconds: 5),
      leftBarIndicatorColor: Colors.green.shade300,
    )..show(context);
  }

  void showInfoFlushbar2(BuildContext context) {
    Flushbar(
      title: title,
      message: message,
      icon: Icon(Icons.delete, size: 28, color: Colors.red.shade600),
      duration: Duration(seconds: 5),
      leftBarIndicatorColor: Colors.red.shade600,
    )..show(context);
  }

  Future<void> getPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    userPhone = prefs.getString('phoneNumber');
    token = prefs.getString('knox_token');
    userSavedData = prefs.getString('saved');
    if (userSavedData.isNotEmpty) {
      userSavedData = jsonDecode(userSavedData);
      for (var item in userSavedData) {
        item["checked"] = false;
      }
      if (userSavedData.length > 0) {
        previouslySaved = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    getPrefs();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness:
          Platform.isAndroid ? Brightness.dark : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    return MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => Total())],
        child: Scaffold(
            backgroundColor: Colors.white,
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(60),
              child: new AppBar(
                brightness: Brightness.dark, // or use Brightness.dark
                backgroundColor: Color(0xFF0E0038),
                centerTitle: true,
                title: Text(
                  'Confirmation',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: "AvenirBold",
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            body: AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle.dark, child: OrderPageExt()),
            bottomNavigationBar: getTotal() == 0 || getTotal() == null
                ? Container(
                    color: Colors.white,
                    height: MediaQuery.of(context).padding.bottom + 60,
                    child: Center(),
                  )
                : Container(
                    color: Colors.white,
                    height: MediaQuery.of(context).padding.bottom + 111,
                    child: Column(children: [
                      Container(
                        color: Color(0xFF0E0038),
                        padding: EdgeInsets.all(10),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                width: MediaQuery.of(context).size.width * .73,
                                child: Container(
                                  alignment: Alignment.centerLeft,
                                  color: Colors.white,
                                  height: 37.0,
                                  child: TextField(
                                    controller: _couponController,
                                    keyboardType: TextInputType.text,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontFamily: 'OpenSans',
                                    ),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      prefixIcon: Icon(
                                        Icons.local_offer,
                                        color: Colors.grey[400],
                                      ),
                                      hintText: 'Enter Coupon Code',
                                      hintStyle: kHintTextStyle2,
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                width: 80,
                                height: 37,
                                child: RaisedButton(
                                  elevation: 0,
                                  onPressed: () => applyCouponCode(),
                                  padding: EdgeInsets.all(0.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                    ),
                                    padding: EdgeInsets.all(9.0),
                                    child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text('APPLY',
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.white)),
                                        ]),
                                  ),
                                ),
                              ),
                            ]),
                      ),
                      Material(
                        color: Colors.red,
                        child: InkWell(
                          onTap: () => gotoAddressPage(),
                          child: Padding(
                              padding: EdgeInsets.all(15),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Text(' '),
                                  Text(
                                    'PROCEED',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 20),
                                    textAlign: TextAlign.right,
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.white,
                                  ),
                                ],
                              )),
                        ),
                      ),
                    ]))));
  }
}

class OrderPageExt extends StatefulWidget {
  @override
  _OrderPageExt createState() => _OrderPageExt();
}

class _OrderPageExt extends State<OrderPageExt> {
  var title;
  var message;
  var filteredList = [];

  void showInfoFlushbar2(BuildContext context) {
    Flushbar(
      title: title,
      message: message,
      icon: Icon(Icons.delete, size: 28, color: Colors.red.shade600),
      duration: Duration(seconds: 5),
      leftBarIndicatorColor: Colors.red.shade600,
    )..show(context);
  }

  getContainer(index, type) {
    if (type == 1) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: MediaQuery.of(context).size.width * 0.45,
                  child: Text(
                    filteredList[index]["product_name"],
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ]),
            ],
          ),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: <Widget>[
            Container(
              padding: EdgeInsets.only(
                left: 10,
              ),
              child: Text(
                  filteredList[index]["original_price"]["original_price"]
                          .toString() +
                      " \u{00D7} " +
                      filteredList[index]["quantity"]["quantity"].toString(),
                  style: new TextStyle(fontSize: 15.0, color: Colors.grey)),
            ),
            SizedBox(
              width: 10,
            ),
            Container(
                padding: EdgeInsets.only(left: 10, top: 0),
                child: Text(
                  '\u{20B9} ' +
                      (filteredList[index]["original_price"]["original_price"] *
                              filteredList[index]["quantity"]["quantity"])
                          .toString(),
                  style: TextStyle(color: Colors.black, fontSize: 20),
                  textAlign: TextAlign.right,
                )),
          ])
        ],
      );
    } else if (type == 2) {
      List<Widget> rowList = new List<Widget>();
      if (filteredList[index]["quantity"]["10g"] != 0) {
        if (filteredList[index]["tenAdded"]) {
        } else {
          filteredList[index]["tenAdded"] = true;
          rowList.add(Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * 0.45,
                            child: Text(
                              filteredList[index]["product_name"] + " " + "10g",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ]),
                  ],
                ),
                Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.only(
                          left: 10,
                        ),
                        child: Text(
                            filteredList[index]["original_price"]["10g"]
                                    .toString() +
                                " \u{00D7} " +
                                filteredList[index]["quantity"]["10g"]
                                    .toString(),
                            style: new TextStyle(
                                fontSize: 15.0, color: Colors.grey)),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Container(
                          padding: EdgeInsets.only(left: 10, top: 0),
                          child: Text(
                            '\u{20B9} ' +
                                (filteredList[index]["original_price"]["10g"] *
                                        filteredList[index]["quantity"]["10g"])
                                    .toString(),
                            style: TextStyle(color: Colors.black, fontSize: 20),
                            textAlign: TextAlign.right,
                          )),
                    ])
              ]));
        }
      }
      if (filteredList[index]["quantity"]["25g"] != 0) {
        if (filteredList[index]["twentyfiveAdded"]) {
        } else {
          filteredList[index]["twentyfiveAdded"] = true;
          rowList.add(Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * 0.45,
                            child: Text(
                              filteredList[index]["product_name"] + " " + "25g",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ]),
                  ],
                ),
                Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.only(
                          left: 10,
                        ),
                        child: Text(
                            filteredList[index]["original_price"]["25g"]
                                    .toString() +
                                " \u{00D7} " +
                                filteredList[index]["quantity"]["25g"]
                                    .toString(),
                            style: new TextStyle(
                                fontSize: 15.0, color: Colors.grey)),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Container(
                          padding: EdgeInsets.only(left: 10, top: 0),
                          child: Text(
                            '\u{20B9} ' +
                                (filteredList[index]["original_price"]["25g"] *
                                        filteredList[index]["quantity"]["25g"])
                                    .toString(),
                            style: TextStyle(color: Colors.black, fontSize: 20),
                            textAlign: TextAlign.right,
                          )),
                    ])
              ]));
        }
      }
      if (filteredList[index]["quantity"]["50g"] != 0) {
        if (filteredList[index]["fiftyAdded"]) {
        } else {
          filteredList[index]["fiftyAdded"] = true;
          rowList.add(Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * 0.45,
                            child: Text(
                              filteredList[index]["product_name"] + " " + "50g",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ]),
                  ],
                ),
                Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.only(
                          left: 10,
                        ),
                        child: Text(
                            filteredList[index]["original_price"]["50g"]
                                    .toString() +
                                " \u{00D7} " +
                                filteredList[index]["quantity"]["50g"]
                                    .toString(),
                            style: new TextStyle(
                                fontSize: 15.0, color: Colors.grey)),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Container(
                          padding: EdgeInsets.only(left: 10, top: 0),
                          child: Text(
                            '\u{20B9} ' +
                                (filteredList[index]["original_price"]["50g"] *
                                        filteredList[index]["quantity"]["50g"])
                                    .toString(),
                            style: TextStyle(color: Colors.black, fontSize: 20),
                            textAlign: TextAlign.right,
                          )),
                    ])
              ]));
        }
      }
      if (filteredList[index]["quantity"]["100g"] != 0) {
        if (filteredList[index]["hundredAdded"]) {
        } else {
          filteredList[index]["hundredAdded"] = true;
          rowList.add(Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * 0.45,
                            child: Text(
                              filteredList[index]["product_name"] +
                                  " " +
                                  "100g",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ]),
                  ],
                ),
                Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.only(
                          left: 10,
                        ),
                        child: Text(
                            filteredList[index]["original_price"]["100g"]
                                    .toString() +
                                " \u{00D7} " +
                                filteredList[index]["quantity"]["100g"]
                                    .toString(),
                            style: new TextStyle(
                                fontSize: 15.0, color: Colors.grey)),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Container(
                          padding: EdgeInsets.only(left: 10, top: 0),
                          child: Text(
                            '\u{20B9} ' +
                                (filteredList[index]["original_price"]["100g"] *
                                        filteredList[index]["quantity"]["100g"])
                                    .toString(),
                            style: TextStyle(color: Colors.black, fontSize: 20),
                            textAlign: TextAlign.right,
                          )),
                    ])
              ]));
        }
      }
      if (filteredList[index]["quantity"]["250g"] != 0) {
        if (filteredList[index]["twofiftyAdded"]) {
        } else {
          filteredList[index]["twofiftyAdded"] = true;
          rowList.add(Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * 0.45,
                            child: Text(
                              filteredList[index]["product_name"] +
                                  " " +
                                  "250g",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ]),
                  ],
                ),
                Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.only(
                          left: 10,
                        ),
                        child: Text(
                            filteredList[index]["original_price"]["250g"]
                                    .toString() +
                                " \u{00D7} " +
                                filteredList[index]["quantity"]["250g"]
                                    .toString(),
                            style: new TextStyle(
                                fontSize: 15.0, color: Colors.grey)),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Container(
                          padding: EdgeInsets.only(left: 10, top: 0),
                          child: Text(
                            '\u{20B9} ' +
                                (filteredList[index]["original_price"]["250g"] *
                                        filteredList[index]["quantity"]["250g"])
                                    .toString(),
                            style: TextStyle(color: Colors.black, fontSize: 20),
                            textAlign: TextAlign.right,
                          )),
                    ])
              ]));
        }
      }
      if (filteredList[index]["quantity"]["500g"] != 0) {
        if (filteredList[index]["fivehundredAdded"]) {
        } else {
          filteredList[index]["fivehundredAdded"] = true;
          rowList.add(Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * 0.45,
                            child: Text(
                              filteredList[index]["product_name"] +
                                  " " +
                                  "500g",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ]),
                  ],
                ),
                Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.only(
                          left: 10,
                        ),
                        child: Text(
                            filteredList[index]["original_price"]["500g"]
                                    .toString() +
                                " \u{00D7} " +
                                filteredList[index]["quantity"]["500g"]
                                    .toString(),
                            style: new TextStyle(
                                fontSize: 15.0, color: Colors.grey)),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Container(
                          padding: EdgeInsets.only(left: 10, top: 0),
                          child: Text(
                            '\u{20B9} ' +
                                (filteredList[index]["original_price"]["500g"] *
                                        filteredList[index]["quantity"]["500g"])
                                    .toString(),
                            style: TextStyle(color: Colors.black, fontSize: 20),
                            textAlign: TextAlign.right,
                          )),
                    ])
              ]));
        }
      }
      if (filteredList[index]["quantity"]["1kg"] != 0) {
        if (filteredList[index]["kgAdded"]) {
        } else {
          filteredList[index]["kgAdded"] = true;
          rowList.add(Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * 0.45,
                            child: Text(
                              filteredList[index]["product_name"] + " " + "1kg",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ]),
                  ],
                ),
                Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.only(
                          left: 10,
                        ),
                        child: Text(
                            filteredList[index]["original_price"]["1kg"]
                                    .toString() +
                                " \u{00D7} " +
                                filteredList[index]["quantity"]["1kg"]
                                    .toString(),
                            style: new TextStyle(
                                fontSize: 15.0, color: Colors.grey)),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Container(
                          padding: EdgeInsets.only(left: 10, top: 0),
                          child: Text(
                            '\u{20B9} ' +
                                (filteredList[index]["original_price"]["1kg"] *
                                        filteredList[index]["quantity"]["1kg"])
                                    .toString(),
                            style: TextStyle(color: Colors.black, fontSize: 20),
                            textAlign: TextAlign.right,
                          )),
                    ])
              ]));
        }
      }
      if (filteredList[index]["quantity"]["2kg"] != 0) {
        if (filteredList[index]["twokgAdded"]) {
        } else {
          filteredList[index]["twokgAdded"] = true;
          rowList.add(Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * 0.45,
                            child: Text(
                              filteredList[index]["product_name"] + " " + "2kg",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ]),
                  ],
                ),
                Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.only(
                          left: 10,
                        ),
                        child: Text(
                            filteredList[index]["original_price"]["2kg"]
                                    .toString() +
                                " \u{00D7} " +
                                filteredList[index]["quantity"]["2kg"]
                                    .toString(),
                            style: new TextStyle(
                                fontSize: 15.0, color: Colors.grey)),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Container(
                          padding: EdgeInsets.only(left: 10, top: 0),
                          child: Text(
                            '\u{20B9} ' +
                                (filteredList[index]["original_price"]["2kg"] *
                                        filteredList[index]["quantity"]["2kg"])
                                    .toString(),
                            style: TextStyle(color: Colors.black, fontSize: 20),
                            textAlign: TextAlign.right,
                          )),
                    ])
              ]));
        }
      }

      return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rowList);
    } else if (type == 3) {
      List<Widget> rowList = new List<Widget>();
      if (filteredList[index]["quantity"]["small"] != 0) {
        if (filteredList[index]["smallAdded"]) {
        } else {
          filteredList[index]["smallAdded"] = true;
          rowList.add(Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * 0.45,
                            child: Text(
                              filteredList[index]["product_name"] +
                                  " " +
                                  "SMALL",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ]),
                  ],
                ),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: <
                    Widget>[
                  Container(
                    padding: EdgeInsets.only(
                      left: 10,
                    ),
                    child: Text(
                        filteredList[index]["original_price"]["small"]
                                .toString() +
                            " \u{00D7} " +
                            filteredList[index]["quantity"]["small"].toString(),
                        style:
                            new TextStyle(fontSize: 15.0, color: Colors.grey)),
                  ),
                  SizedBox(
                    width: 10,
                  ),
                  Container(
                      padding: EdgeInsets.only(left: 10, top: 0),
                      child: Text(
                        '\u{20B9} ' +
                            (filteredList[index]["original_price"]["small"] *
                                    filteredList[index]["quantity"]["small"])
                                .toString(),
                        style: TextStyle(color: Colors.black, fontSize: 20),
                        textAlign: TextAlign.right,
                      )),
                ])
              ]));
        }
      }
      if (filteredList[index]["quantity"]["medium"] != 0) {
        if (filteredList[index]["mediumAdded"]) {
        } else {
          filteredList[index]["mediumAdded"] = true;
          rowList.add(Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * 0.45,
                            child: Text(
                              filteredList[index]["product_name"] +
                                  " " +
                                  "MEDIUM",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ]),
                  ],
                ),
                Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.only(
                          left: 10,
                        ),
                        child: Text(
                            filteredList[index]["original_price"]["medium"]
                                    .toString() +
                                " \u{00D7} " +
                                filteredList[index]["quantity"]["medium"]
                                    .toString(),
                            style: new TextStyle(
                                fontSize: 15.0, color: Colors.grey)),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Container(
                          padding: EdgeInsets.only(left: 10, top: 0),
                          child: Text(
                            '\u{20B9} ' +
                                (filteredList[index]["original_price"]
                                            ["medium"] *
                                        filteredList[index]["quantity"]
                                            ["medium"])
                                    .toString(),
                            style: TextStyle(color: Colors.black, fontSize: 20),
                            textAlign: TextAlign.right,
                          )),
                    ])
              ]));
        }
      }
      if (filteredList[index]["quantity"]["large"] != 0) {
        if (filteredList[index]["largeAdded"]) {
        } else {
          filteredList[index]["largeAdded"] = true;
          rowList.add(Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * 0.45,
                            child: Text(
                              filteredList[index]["product_name"] +
                                  " " +
                                  "LARGE",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ]),
                  ],
                ),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: <
                    Widget>[
                  Container(
                    padding: EdgeInsets.only(
                      left: 10,
                    ),
                    child: Text(
                        filteredList[index]["original_price"]["large"]
                                .toString() +
                            " \u{00D7} " +
                            filteredList[index]["quantity"]["large"].toString(),
                        style:
                            new TextStyle(fontSize: 15.0, color: Colors.grey)),
                  ),
                  SizedBox(
                    width: 10,
                  ),
                  Container(
                      padding: EdgeInsets.only(left: 10, top: 0),
                      child: Text(
                        '\u{20B9} ' +
                            (filteredList[index]["original_price"]["large"] *
                                    filteredList[index]["quantity"]["large"])
                                .toString(),
                        style: TextStyle(color: Colors.black, fontSize: 20),
                        textAlign: TextAlign.right,
                      )),
                ])
              ]));
        }
      }
      return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rowList);
    }
  }

  @override
  Widget build(BuildContext context) {
    filteredList = [];
    if (menuJson != null) {
      for (var i = 0; i < menuJson["menu"].length; i++) {
        for (var item in menuJson["menu"][i]) {
          if (item["type"] == 1) {
            if (item["quantity"]["quantity"] > 0) {
              filteredList.add(item);
            }
          } else if (item["type"] == 2) {
            if (item["quantity"]["10g"] > 0) {
              item["tenAdded"] = false;
              filteredList.add(item);
            }
            if (item["quantity"]["25g"] > 0) {
              item["twentyfiveAdded"] = false;
              filteredList.add(item);
            }
            if (item["quantity"]["50g"] > 0) {
              item["fiftyAdded"] = false;
              filteredList.add(item);
            }
            if (item["quantity"]["100g"] > 0) {
              item["hundredAdded"] = false;
              filteredList.add(item);
            }
            if (item["quantity"]["250g"] > 0) {
              item["twofiftyAdded"] = false;
              filteredList.add(item);
            }
            if (item["quantity"]["500g"] > 0) {
              item["fivehundredAdded"] = false;
              filteredList.add(item);
            }
            if (item["quantity"]["1kg"] > 0) {
              item["kgAdded"] = false;
              filteredList.add(item);
            }
            if (item["quantity"]["2kg"] > 0) {
              item["twokgAdded"] = false;
              filteredList.add(item);
            }
          } else if (item["type"] == 3) {
            if (item["quantity"]["small"] > 0) {
              item["smallAdded"] = false;
              filteredList.add(item);
            }
            if (item["quantity"]["medium"] > 0) {
              item["mediumAdded"] = false;
              filteredList.add(item);
            }
            if (item["quantity"]["large"] > 0) {
              item["largeAdded"] = false;
              filteredList.add(item);
            }
          }
        }
      }
    }

    return SingleChildScrollView(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
          Column(mainAxisAlignment: MainAxisAlignment.start, children: [
            Container(
                padding: EdgeInsets.all(10),
                color: Colors.white,
                child: ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      return Container(
                          padding: const EdgeInsets.only(bottom: 5),
                          child:
                              getContainer(index, filteredList[index]["type"]));
                    })),
            Container(
                padding: EdgeInsets.only(top: 5, left: 10, right: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: MediaQuery.of(context).size.width * 0.45,
                                child: Text(
                                  deliveryMessage,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.red,
                                  ),
                                  textAlign: TextAlign.left,
                                ),
                              ),
                            ]),
                      ],
                    ),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          Container(
                              padding: EdgeInsets.only(left: 10, top: 0),
                              child: Text(
                                '\u{20B9} ' + getDeliveryCharges().toString(),
                                style:
                                    TextStyle(color: Colors.red, fontSize: 20),
                                textAlign: TextAlign.right,
                              )),
                        ])
                  ],
                )),
            Container(
                padding: EdgeInsets.only(top: 5, left: 10, right: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: MediaQuery.of(context).size.width * 0.45,
                                child: Text(
                                  "Discount",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.red,
                                  ),
                                  textAlign: TextAlign.left,
                                ),
                              ),
                            ]),
                      ],
                    ),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          Container(
                              padding: EdgeInsets.only(left: 10, top: 0),
                              child: Text(
                                '- \u{20B9} ' + discount.toString(),
                                style:
                                    TextStyle(color: Colors.red, fontSize: 20),
                                textAlign: TextAlign.right,
                              )),
                        ])
                  ],
                )),
            Container(
                padding: EdgeInsets.only(top: 5, left: 10, right: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: MediaQuery.of(context).size.width * 0.45,
                                child: Text(
                                  "GST",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.red,
                                  ),
                                  textAlign: TextAlign.left,
                                ),
                              ),
                            ]),
                      ],
                    ),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          Container(
                              padding: EdgeInsets.only(left: 10, top: 0),
                              child: Text(
                                '\u{20B9} ' + (getGST()).toString(),
                                style:
                                    TextStyle(color: Colors.red, fontSize: 20),
                                textAlign: TextAlign.right,
                              )),
                        ])
                  ],
                )),
            Container(
                padding:
                    EdgeInsets.only(top: 5, left: 10, right: 10, bottom: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: MediaQuery.of(context).size.width * 0.45,
                                child: Text(
                                  "TOTAL",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.red,
                                  ),
                                  textAlign: TextAlign.left,
                                ),
                              ),
                            ]),
                      ],
                    ),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          Container(
                              padding: EdgeInsets.only(left: 10, top: 0),
                              child: Text(
                                '\u{20B9} ' + (getTotalFinal()).toString(),
                                style:
                                    TextStyle(color: Colors.red, fontSize: 20),
                                textAlign: TextAlign.right,
                              )),
                        ])
                  ],
                ))
          ]),
        ]));
  }
}

//=-= ---------------------------------------------------------
//  Address Page
//=-= ---------------------------------------------------------

class AddressPage extends StatefulWidget {
  const AddressPage({Key key2}) : super(key: key2);

  @override
  _AddressPage createState() => _AddressPage();
}

class _AddressPage extends State<AddressPage> {
  bool saveAddress = false;
  var savedDataIndex;
  var saveDataIndexValue = false;

  void showInfoFlushbar(BuildContext context) {
    Flushbar(
      title: title,
      message: message,
      icon: Icon(Icons.info_outline, size: 28, color: Colors.red.shade600),
      duration: Duration(seconds: 5),
      leftBarIndicatorColor: Colors.red.shade600,
    )..show(context);
  }

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _pinCodeController = TextEditingController();

  _proceedToPayment() {
    if (previouslySaved == false) {
      name = _nameController.text;
      email = _emailController.text;
      address = _addressController.text;
      pincode = _pinCodeController.text;
    }
    var allok;

    bool emailValid =
        RegExp(r"^[a-z0-9.a-z0-9]+@[a-z0-9]+\.[a-z]+").hasMatch(email);

    bool addressValid =
        RegExp(r"^[a-zA-Z0-9.!#$%&'*+-/=?^_`,{|}~]").hasMatch(address);

    bool isNumeric(String s) {
      if (s == null) {
        return false;
      }
      return double.parse(s, (e) => null) != null;
    }

    var pincodeValid = isNumeric(pincode);

    if (emailValid == true) {
      if (addressValid == true) {
        if (pincodeValid == true) {
          if (pincode != "562101") {
            title = "Error";
            message = "Deliveries only available in 562101.";
            allok = false;
          } else {
            allok = true;
          }
        } else {
          title = "Error";
          message = "Deliveries only available in 562101.";
          allok = false;
        }
      } else {
        title = "Error";
        message = "Enter address.";
        allok = false;
      }
    } else {
      title = "Error";
      message = "Enter a correct email address.";
      allok = false;
    }

    if (allok == true) {
      if (saveAddress == true) {
        saved["address"] = address;
        saved["name"] = name;
        saved["email"] = email;
        saved["pincode"] = pincode;
        setSaved(saved);
      }
      Navigator.pushReplacement(
          context, SlideRightRoute(page: PaymentScreen()));
    } else {
      showInfoFlushbar(context);
    }
  }

  setAddress(index, value) {
    if (value) {
      for (var item in userSavedData) {
        item["checked"] = false;
      }
      userSavedData[index]["checked"] = true;
      name = userSavedData[index]["name"];
      email = userSavedData[index]["email"];
      address = userSavedData[index]["address"];
      pincode = userSavedData[index]["pincode"];
    } else {
      for (var item in userSavedData) {
        item["checked"] = false;
      }
    }
    setState(() {});
  }

  Widget _buildAddressTF() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(height: 10.0),
        Container(
          alignment: Alignment.centerLeft,
          decoration: kBoxDecorationStyle2,
          height: 50.0,
          child: TextField(
            controller: _nameController,
            keyboardType: TextInputType.text,
            style: TextStyle(
              color: Colors.grey[600],
              fontFamily: 'OpenSans',
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(top: 16.0),
              prefixIcon: Icon(
                Icons.person,
                color: Colors.grey[400],
              ),
              hintText: 'Full Name',
              hintStyle: kHintTextStyle2,
            ),
          ),
        ),
        SizedBox(height: 10.0),
        Container(
          alignment: Alignment.centerLeft,
          decoration: kBoxDecorationStyle2,
          height: 50.0,
          child: TextField(
            controller: _emailController,
            keyboardType: TextInputType.text,
            style: TextStyle(
              color: Colors.grey[600],
              fontFamily: 'OpenSans',
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(top: 16.0),
              prefixIcon: Icon(
                Icons.mail,
                color: Colors.grey[400],
              ),
              hintText: 'E-mail',
              hintStyle: kHintTextStyle2,
            ),
          ),
        ),
        SizedBox(height: 10.0),
        Container(
          alignment: Alignment.centerLeft,
          decoration: kBoxDecorationStyle2,
          height: 50.0,
          child: TextField(
            controller: _addressController,
            keyboardType: TextInputType.text,
            style: TextStyle(
              color: Colors.grey[600],
              fontFamily: 'OpenSans',
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(top: 16.0),
              prefixIcon: Icon(
                Icons.home,
                color: Colors.grey[400],
              ),
              hintText: 'Address',
              hintStyle: kHintTextStyle2,
            ),
          ),
        ),
        SizedBox(height: 10.0),
        Container(
          alignment: Alignment.centerLeft,
          decoration: kBoxDecorationStyle2,
          height: 50.0,
          child: TextField(
            controller: _pinCodeController,
            keyboardType: TextInputType.number,
            style: TextStyle(
              color: Colors.grey[600],
              fontFamily: 'OpenSans',
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(top: 16.0),
              prefixIcon: Icon(
                Icons.home,
                color: Colors.grey[400],
              ),
              hintText: 'Enter Pincode',
              hintStyle: kHintTextStyle2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProceedBtn() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 25.0),
      width: double.infinity,
      child: RaisedButton(
        elevation: 5.0,
        onPressed: () => _proceedToPayment(),
        padding: EdgeInsets.all(15.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0.0),
        ),
        color: Color(0xFF0E0038),
        child: Text(
          'Proceed to Payment',
          style: TextStyle(
            color: Colors.white,
            letterSpacing: 1.5,
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
            fontFamily: 'Avenir',
          ),
        ),
      ),
    );
  }

  Widget getIfSaved() {
    if (previouslySaved == false) {
      return Column(children: [
        SizedBox(height: 10.0),
        _buildAddressTF(),
        SizedBox(
          height: 30.0,
        ),
        Container(
          margin: EdgeInsets.only(right: 30),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Checkbox(
              value: saveAddress,
              onChanged: (bool value) {
                setState(() {
                  saveAddress = value;
                });
              },
            ),
            Text("Save details for future reference"),
          ]),
        ),
        SizedBox(
          height: 20,
        ),
        Container(
          width: 200,
          height: 30,
          margin: EdgeInsets.only(right: 5),
          child: RaisedButton(
            elevation: 0,
            onPressed: () => {
              setState(() {
                previouslySaved = !previouslySaved;
              })
            },
            textColor: Colors.black,
            padding: EdgeInsets.all(0.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: Colors.red,
                  width: 1,
                ),
              ),
              padding: EdgeInsets.all(9.0),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('SAVED ADDRESSES',
                    style: TextStyle(fontSize: 10, color: Colors.red)),
              ]),
            ),
          ),
        ),
        SizedBox(
          height: 10,
        ),
      ]);
    } else {
      if (userSavedData == null) {
        return Column(children: [
          Center(child: Text("No previously saved addresses")),
          SizedBox(
            height: 30,
          ),
          Container(
            width: 200,
            height: 30,
            margin: EdgeInsets.only(right: 5),
            child: RaisedButton(
              elevation: 0,
              onPressed: () => {
                setState(() {
                  previouslySaved = !previouslySaved;
                })
              },
              textColor: Colors.black,
              padding: EdgeInsets.all(0.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: Colors.red,
                    width: 1,
                  ),
                ),
                padding: EdgeInsets.all(9.0),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('ADD NEW ADDRESS',
                      style: TextStyle(fontSize: 10, color: Colors.red)),
                ]),
              ),
            ),
          ),
          SizedBox(
            height: 20,
          ),
        ]);
      } else {
        return Column(children: [
          ListView.builder(
              shrinkWrap: true,
              itemCount: userSavedData.length,
              itemBuilder: (context, index) {
                return Container(
                  child: CheckboxListTile(
                    title: Text(userSavedData[index]["name"]),
                    subtitle: Text(userSavedData[index]["address"]),
                    value: userSavedData[index]["checked"],
                    onChanged: (bool value) {
                      setAddress(index, value);
                    },
                  ),
                );
              }),
          SizedBox(
            height: 30,
          ),
          Container(
            width: 200,
            height: 30,
            margin: EdgeInsets.only(right: 5),
            child: RaisedButton(
              elevation: 0,
              onPressed: () => {
                setState(() {
                  previouslySaved = !previouslySaved;
                })
              },
              textColor: Colors.black,
              padding: EdgeInsets.all(0.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: Colors.red,
                    width: 1,
                  ),
                ),
                padding: EdgeInsets.all(9.0),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('ADD NEW ADDRESS',
                      style: TextStyle(fontSize: 10, color: Colors.red)),
                ]),
              ),
            ),
          ),
          SizedBox(
            height: 20,
          ),
        ]);
      }
    }
  }

  Future<void> setSaved(userData) async {
    final prefs = await SharedPreferences.getInstance();
    var userSavedDataString = prefs.getString('saved');
    if (userSavedDataString == null) {
      userSavedDataString = "[]";
    }
    userSavedData = jsonDecode(userSavedDataString);

    userSavedData.add(userData);
    await prefs.setString('saved', jsonEncode(userSavedData));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: <Widget>[
              Container(
                height: double.infinity,
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.white),
              ),
              Container(
                height: double.infinity,
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: 40.0,
                    vertical: 40.0,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      SizedBox(height: 10.0),
                      Text(
                        'Delivery Details',
                        style: TextStyle(
                          color: Colors.red,
                          fontFamily: 'Avenir',
                          fontSize: 40.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 30.0),
                      getIfSaved(),
                      _buildProceedBtn(),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

//=-= ---------------------------------------------------------
//  Order Submit Loader
//=-= ---------------------------------------------------------

class OrderSubmitPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.dark));
    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: WillPopScope(
            onWillPop: () async {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => MyHomePage()));
            },
            child: Scaffold(
                backgroundColor: Color(0xFF0E0038),
                body: Container(
                    child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height - 30,
                      child: Column(
                        children: <Widget>[
                          Image.asset("assets/images/intro1.png",
                              width: MediaQuery.of(context).size.width),
                          Container(
                            margin: EdgeInsets.only(left: 24, right: 24),
                            child: Center(
                              child: new RichText(
                                  textAlign: TextAlign.center,
                                  text: new TextSpan(
                                      style: new TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                      ),
                                      children: <TextSpan>[
                                        new TextSpan(
                                            text:
                                                "Thank you for choosing Gogoz.\nWe will keep you notified about your order.",
                                            style: new TextStyle(
                                                fontFamily: 'Avenir')),
                                      ])),
                            ),
                          ),
                          SizedBox(
                            height: 30,
                          ),
                          Container(
                              decoration: BoxDecoration(
                                color: const Color(0xff7c94b6),
                                border: Border.all(
                                  color: Colors.indigo[900],
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: RaisedButton(
                                elevation: 5.0,
                                onPressed: () async {
                                  clearCart();
                                  newOrder = true;
                                  Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                          builder: (BuildContext context) =>
                                              PastOrders()),
                                      (Route<dynamic> route) => false);
                                },
                                padding: EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(0.0),
                                ),
                                color: Colors.indigo[900],
                                child: Text(
                                  'ORDER DETAILS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    letterSpacing: 1.5,
                                    fontSize: 20.0,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Avenir',
                                  ),
                                ),
                              )),
                          Container(
                            margin: EdgeInsets.symmetric(
                                horizontal: 24, vertical: 24),
                            child: Center(
                              child: new RichText(
                                  textAlign: TextAlign.center,
                                  text: new TextSpan(
                                      style: new TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                      ),
                                      children: <TextSpan>[
                                        new TextSpan(
                                            text: "Your order id is : " +
                                                responseJSON["data"]["ORDERID"],
                                            style: new TextStyle(
                                                fontFamily: 'Avenir')),
                                      ])),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )))));
  }
}

//=-= ---------------------------------------------------------
//  Vendors page
//=-= ---------------------------------------------------------

class Vendors extends StatefulWidget {
  @override
  _Vendors createState() => _Vendors();
}

class _Vendors extends State<Vendors> {
  @override
  Widget build(BuildContext context) {
    return VendorsExt();
  }
}

class VendorsExt extends StatefulWidget {
  @override
  _VendorsExt createState() => _VendorsExt();
}

class _VendorsExt extends State<VendorsExt> {
  var isLoadingProducts = true;

  refreshState() {
    setState(() {});
  }

  var title;
  var message;
  var filteredResults = [];
  @override
  void initState() {
    super.initState();
    loadProducts().then((usersFromServer) {
      setState(() {
        filteredResults = vendorsJson;
      });
    });
  }

  void gotoVendorMenuScreen(BuildContext context, vendorId, vendorName) async {
    vendorIdMenu = vendorId;
    vendorNameMenu = vendorName;
    await Navigator.push(context, SlideRightRoute(page: MenuScreen()));
    setState(() {});
  }

  loadProducts() async {
    http.Response httpresponse = await http.get(
      'https://02c8cb08d4e2.ngrok.io/get_vendors?category=' +
          categoryToLoad.toString(),
    );

    if (httpresponse.statusCode == HttpStatus.ok) {
      vendorsJson = jsonDecode(httpresponse.body);
      isLoadingProducts = false;
    }
  }

  getPriceLevel(level) {
    if (level == 1) {
      return Row(children: [
        Text(
          "\u{20B9} ",
          style: TextStyle(color: Colors.green, fontSize: 20),
          textAlign: TextAlign.left,
        ),
        Text(
          "\u{20B9} ",
          style: TextStyle(color: Colors.grey[300], fontSize: 20),
          textAlign: TextAlign.left,
        ),
        Text(
          "\u{20B9}",
          style: TextStyle(color: Colors.grey[300], fontSize: 20),
          textAlign: TextAlign.left,
        )
      ]);
    } else if (level == 2) {
      return Row(children: [
        Text(
          "\u{20B9} ",
          style: TextStyle(color: Colors.green, fontSize: 20),
          textAlign: TextAlign.left,
        ),
        Text(
          "\u{20B9} ",
          style: TextStyle(color: Colors.green, fontSize: 20),
          textAlign: TextAlign.left,
        ),
        Text(
          "\u{20B9}",
          style: TextStyle(color: Colors.grey[300], fontSize: 20),
          textAlign: TextAlign.left,
        )
      ]);
    } else if (level == 3) {
      return Row(children: [
        Text(
          "\u{20B9} ",
          style: TextStyle(color: Colors.green, fontSize: 20),
          textAlign: TextAlign.left,
        ),
        Text(
          "\u{20B9} ",
          style: TextStyle(color: Colors.green, fontSize: 20),
          textAlign: TextAlign.left,
        ),
        Text(
          "\u{20B9}",
          style: TextStyle(color: Colors.green, fontSize: 20),
          textAlign: TextAlign.left,
        )
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingProducts) {
      return Scaffold(
          backgroundColor: Colors.white,
          appBar: PreferredSize(
              preferredSize: Size.fromHeight(60),
              child: new AppBar(
                brightness: Brightness.dark,
                backgroundColor: Color(0xFF0E0038),
                centerTitle: true,
                title: Text(
                  categoryName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: "AvenirBold",
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )),
          body: AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle.dark, child: ShimmerList()));
    } else {
      return Scaffold(
          backgroundColor: Colors.white,
          appBar: PreferredSize(
              preferredSize: Size.fromHeight(60),
              child: new AppBar(
                centerTitle: true,
                brightness: Brightness.dark,
                backgroundColor: Color(0xFF0E0038),
                title: Text(
                  categoryName,
                  style: TextStyle(
                    fontFamily: "AvenirBold",
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                actions: [
                  SearchIcon(),
                ],
              )),
          body: AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle.dark,
              child: Container(
                  color: Colors.white,
                  child: ListView.builder(
                      itemCount: vendorsJson.length,
                      itemBuilder: (context, index) {
                        return Container(
                            margin:
                                EdgeInsets.only(top: 10, bottom: 10, right: 2),
                            child: Container(
                                child: Center(
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.80,
                                                    padding: EdgeInsets.only(
                                                        left: 10),
                                                    child: Text(
                                                      vendorsJson[index]
                                                          ["vendor_name"],
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        color: Colors.black,
                                                      ),
                                                      textAlign: TextAlign.left,
                                                    ),
                                                  ),
                                                  Container(
                                                      width:
                                                          MediaQuery.of(context)
                                                                  .size
                                                                  .width *
                                                              0.80,
                                                      padding: EdgeInsets.only(
                                                          left: 10, top: 5),
                                                      child: Text(
                                                        vendorsJson[index][
                                                                "vendor_address"]
                                                            .toString(),
                                                        style: TextStyle(
                                                            color: Colors.grey,
                                                            fontSize: 12),
                                                        textAlign:
                                                            TextAlign.left,
                                                      )),
                                                  Row(children: [
                                                    Container(
                                                        padding:
                                                            EdgeInsets.only(
                                                                left: 7,
                                                                top: 5),
                                                        child:
                                                            RatingBarIndicator(
                                                          rating: double.parse(
                                                              filteredResults[
                                                                      index][
                                                                  "vendor_avg_rating"]),
                                                          itemBuilder: (context,
                                                                  index) =>
                                                              Icon(
                                                            Icons.star,
                                                            color: Colors.amber,
                                                          ),
                                                          itemCount: 5,
                                                          itemSize: 20.0,
                                                          unratedColor: Colors
                                                              .amber
                                                              .withAlpha(50),
                                                          direction:
                                                              Axis.horizontal,
                                                        )),
                                                    Container(
                                                        width: MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .width *
                                                            0.5,
                                                        padding:
                                                            EdgeInsets.only(
                                                                left: 10,
                                                                top: 5),
                                                        child: Text(
                                                          "( " +
                                                              vendorsJson[index]
                                                                      [
                                                                      "vendor_ratings_number"]
                                                                  .toString() +
                                                              " )",
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.grey,
                                                              fontSize: 12),
                                                          textAlign:
                                                              TextAlign.left,
                                                        ))
                                                  ])
                                                ]),
                                          ],
                                        ),
                                        Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Container(
                                                width: 68,
                                                height: 30,
                                                margin: EdgeInsets.only(
                                                    bottom: 25, right: 10),
                                                child: RaisedButton(
                                                  elevation: 5,
                                                  onPressed: () => {
                                                    gotoVendorMenuScreen(
                                                        context,
                                                        vendorsJson[index]
                                                            ["vendor_id"],
                                                        vendorsJson[index]
                                                            ["vendor_name"])
                                                  },
                                                  textColor: Colors.black,
                                                  padding: EdgeInsets.all(0.0),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                        color: Colors.red),
                                                    padding:
                                                        EdgeInsets.all(10.0),
                                                    child: Row(children: [
                                                      Text('SEE MENU',
                                                          style: TextStyle(
                                                              fontSize: 10,
                                                              color: Colors
                                                                  .white)),
                                                    ]),
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                  width: 70,
                                                  padding: EdgeInsets.only(
                                                    left: 5,
                                                  ),
                                                  child: getPriceLevel(
                                                      vendorsJson[index]
                                                          ["price_level"]))
                                            ])
                                      ],
                                    )
                                  ]),
                            )));
                      }))));
    }
  }
}

//=-= ---------------------------------------------------------
//  Category screen
//=-= ---------------------------------------------------------

class CategoryScreen extends StatefulWidget {
  @override
  _CategoryScreen createState() => _CategoryScreen();
}

class _CategoryScreen extends State<CategoryScreen> {
  @override
  Widget build(BuildContext context) {
    return CategoryScreenExt();
  }
}

class CategoryScreenExt extends StatefulWidget {
  @override
  _CategoryScreenExt createState() => _CategoryScreenExt();
}

class _CategoryScreenExt extends State<CategoryScreenExt> {
  var isLoadingProducts = false;

  var title;
  var message;
  var searched = false;

  var empty = false;

  @override
  void initState() {
    loadProducts("a");
    super.initState();
  }

  void gotoMenuScreen(BuildContext context, vendorId, vendorName) {
    vendorIdMenu = vendorId;
    vendorNameMenu = vendorName;
    Navigator.pushReplacement(context, SlideRightRoute(page: MenuScreen()));
  }

  loadProducts(searchtext) async {
    setState(() {
      isLoadingProducts = true;
    });

    http.Response httpresponse = await http.get(
      'https://02c8cb08d4e2.ngrok.io/get_products?search=' + searchtext,
    );

    if (httpresponse.statusCode == HttpStatus.ok) {
      productsJson = jsonDecode(httpresponse.body);

      setState(() {
        if (productsJson.isEmpty) {
          empty = true;
        } else {
          empty = false;
        }
        isLoadingProducts = false;
      });
    }
  }

  returnContainer(index) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    height: 67,
                    padding: EdgeInsets.only(
                      left: 10,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: FadeInImage.assetNetwork(
                        height: 150,
                        width: 100,
                        placeholder: 'assets/images/loader.gif',
                        image: 'https://02c8cb08d4e2.ngrok.io/static/img/' +
                            productsJson[index]["product_id"] +
                            ".jpg",
                      ),
                    )),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: MediaQuery.of(context).size.width * 0.45,
                    padding: EdgeInsets.only(left: 10),
                    child: Text(
                      productsJson[index]["product_name"],
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  Container(
                      height: 51,
                      width: MediaQuery.of(context).size.width * .5,
                      padding: EdgeInsets.only(left: 10, top: 2),
                      child: Text(
                        productsJson[index]["description"],
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                        textAlign: TextAlign.left,
                      )),
                ]),
              ],
            ),
            Column(children: [
              Container(
                width: 68,
                height: 30,
                margin: EdgeInsets.only(bottom: 5, right: 10),
                child: RaisedButton(
                  elevation: 5,
                  onPressed: () => {
                    gotoMenuScreen(context, productsJson[index]["vendor_id"],
                        productsJson[index]["vendor_name"])
                  },
                  textColor: Colors.black,
                  padding: EdgeInsets.all(0.0),
                  child: Container(
                    decoration: BoxDecoration(color: Colors.red),
                    padding: EdgeInsets.all(10.0),
                    child: Row(children: [
                      Text('SEE MENU',
                          style: TextStyle(fontSize: 10, color: Colors.white)),
                    ]),
                  ),
                ),
              ),
            ])
          ],
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        appBar: PreferredSize(
            preferredSize: Size.fromHeight(120),
            child: new AppBar(
              brightness: Brightness.dark,
              backgroundColor: Color(0xFF0E0038),
              centerTitle: true,
              title: Text(
                "Search",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: "AvenirBold",
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              flexibleSpace: Container(
                color: Colors.white,
                margin: const EdgeInsets.only(top: 90),
                child: TextField(
                  style: TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.all(15.0),
                    hintText: 'Search for restaurants or dishes',
                    hintStyle: TextStyle(
                      fontSize: 15.0,
                      color: Colors.black,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.black,
                    ),
                  ),
                  cursorColor: Colors.white,
                  onChanged: (string) {
                    loadProducts(string);
                  },
                ),
              ),
            )),
        body: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.dark,
            child: empty == false
                ? isLoadingProducts
                    ? Center(
                        child: Container(
                            margin: EdgeInsets.all(3),
                            child: Image.asset(
                              "assets/images/logoload.gif",
                              width: 48,
                            )))
                    : Container(
                        color: Colors.white,
                        child: ListView.builder(
                            itemCount: productsJson.length,
                            itemBuilder: (context, index) {
                              return Container(
                                  padding: EdgeInsets.only(top: 10),
                                  child: returnContainer(index));
                            }))
                : Center(child: Text("Nothing found!"))));
  }
}

//=-= ---------------------------------------------------------
//  Counter Screen
//=-= ---------------------------------------------------------

class MenuScreen extends StatefulWidget {
  @override
  _MenuScreen createState() => _MenuScreen();
}

class _MenuScreen extends State<MenuScreen> {
  @override
  Widget build(BuildContext context) {
    return MenuScreenExt();
  }
}

class MenuScreenExt extends StatefulWidget {
  @override
  _MenuScreenExt createState() => _MenuScreenExt();
}

class _MenuScreenExt extends State<MenuScreenExt>
    with SingleTickerProviderStateMixin {
  var title;
  var message;

  @override
  void initState() {
    loadProducts();
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _boxAnimation = Tween<double>(
      begin: 1,
      end: 0.2,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(
          0,
          0.5,
          curve: Curves.decelerate,
        ),
      ),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.decelerate,
    ))
      ..addStatusListener((status) {
        if (status == AnimationStatus.forward) {
          toggleOpen();
        } else if (status == AnimationStatus.dismissed) {
          toggleClose();
        }
      });
    _fadeAnimation = Tween<double>(
      begin: 1,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.decelerate,
    ));

    super.initState();
  }

  AnimationController _controller;
  Animation<Offset> _offsetAnimation;
  Animation<double> _fadeAnimation;
  Animation<double> _boxAnimation;

  bool toggle = false;
  void toggleOpen() {
    _controller.forward();
    setState(() {
      toggle = true;
    });
  }

  void toggleClose() {
    _controller.reverse();
    resetProduct();
    setState(() {
      toggle = false;
    });
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  refreshState() {
    setState(() {});
  }

  activeTap(index1, index, type) {
    menuJson["menu"][index1][index]["active"] =
        !menuJson["menu"][index1][index]["active"];
  }

  minus(index1, index, type) {
    var quant;
    if (type == "quantity") {
      menuJson["menu"][index1][index]["quantity"]["quantity"]--;
      quant = menuJson["menu"][index1][index]["quantity"]["quantity"];
      if (quant <= 0) {
        if (quant == 0) {
          menuJson["menu"][index1][index]["active"] = false;
        }
        menuJson["menu"][index1][index]["quantity"]["quantity"] = 0;
      }
    } else if (type == "10g") {
      menuJson["menu"][index1][index]["quantity"]["10g"]--;
      quant = menuJson["menu"][index1][index]["quantity"]["10g"];
      if (quant <= 0) {
        if (quant == 0) {
          menuJson["menu"][index1][index]["active"] = false;
        }
        menuJson["menu"][index1][index]["quantity"]["10g"] = 0;
      }
    } else if (type == "25g") {
      menuJson["menu"][index1][index]["quantity"]["25g"]--;
      quant = menuJson["menu"][index1][index]["quantity"]["25g"];
      if (quant <= 0) {
        if (quant == 0) {
          menuJson["menu"][index1][index]["active"] = false;
        }
        menuJson["menu"][index1][index]["quantity"]["25g"] = 0;
      }
    } else if (type == "50g") {
      menuJson["menu"][index1][index]["quantity"]["50g"]--;
      quant = menuJson["menu"][index1][index]["quantity"]["50g"];
      if (quant <= 0) {
        if (quant == 0) {
          menuJson["menu"][index1][index]["active"] = false;
        }
        menuJson["menu"][index1][index]["quantity"]["50g"] = 0;
      }
    } else if (type == "100g") {
      menuJson["menu"][index1][index]["quantity"]["100g"]--;
      quant = menuJson["menu"][index1][index]["quantity"]["100g"];
      if (quant <= 0) {
        if (quant == 0) {
          menuJson["menu"][index1][index]["active"] = false;
        }
        menuJson["menu"][index1][index]["quantity"]["100g"] = 0;
      }
    } else if (type == "250g") {
      menuJson["menu"][index1][index]["quantity"]["250g"]--;
      quant = menuJson["menu"][index1][index]["quantity"]["250g"];
      if (quant <= 0) {
        if (quant == 0) {
          menuJson["menu"][index1][index]["active"] = false;
        }
        menuJson["menu"][index1][index]["quantity"]["250g"] = 0;
      }
    } else if (type == "500g") {
      menuJson["menu"][index1][index]["quantity"]["500g"]--;
      quant = menuJson["menu"][index1][index]["quantity"]["500g"];
      if (quant <= 0) {
        if (quant == 0) {
          menuJson["menu"][index1][index]["active"] = false;
        }
        menuJson["menu"][index1][index]["quantity"]["500g"] = 0;
      }
    } else if (type == "1kg") {
      menuJson["menu"][index1][index]["quantity"]["1kg"]--;
      quant = menuJson["menu"][index1][index]["quantity"]["1kg"];
      if (quant <= 0) {
        if (quant == 0) {
          menuJson["menu"][index1][index]["active"] = false;
        }
        menuJson["menu"][index1][index]["quantity"]["1kg"] = 0;
      }
    } else if (type == "2kg") {
      menuJson["menu"][index1][index]["quantity"]["2kg"]--;
      quant = menuJson["menu"][index1][index]["quantity"]["2kg"];
      if (quant <= 0) {
        if (quant == 0) {
          menuJson["menu"][index1][index]["active"] = false;
        }
        menuJson["menu"][index1][index]["quantity"]["2kg"] = 0;
      }
    } else if (type == "small") {
      menuJson["menu"][index1][index]["quantity"]["small"]--;
      quant = menuJson["menu"][index1][index]["quantity"]["small"];
      if (quant <= 0) {
        if (quant == 0) {
          menuJson["menu"][index1][index]["active"] = false;
        }
        menuJson["menu"][index1][index]["quantity"]["small"] = 0;
      }
    } else if (type == "medium") {
      menuJson["menu"][index1][index]["quantity"]["medium"]--;
      quant = menuJson["menu"][index1][index]["quantity"]["medium"];
      if (quant <= 0) {
        if (quant == 0) {
          menuJson["menu"][index1][index]["active"] = false;
        }
        menuJson["menu"][index1][index]["quantity"]["medium"] = 0;
      }
    } else if (type == "large") {
      menuJson["menu"][index1][index]["quantity"]["large"]--;
      quant = menuJson["menu"][index1][index]["quantity"]["large"];
      if (quant <= 0) {
        if (quant == 0) {
          menuJson["menu"][index1][index]["active"] = false;
        }
        menuJson["menu"][index1][index]["quantity"]["large"] = 0;
      }
    }
    setState(() {});
  }

  plus(index1, index, type) {
    var quant;
    if (type == "quantity") {
      menuJson["menu"][index1][index]["quantity"]["quantity"]++;
      quant = menuJson["menu"][index1][index]["quantity"]["quantity"];

      if (quant > 15) {
        title = "Error";
        message = "Maximum quantity allowed is 15.";
        showInfoFlushbar(context);
        menuJson["menu"][index1][index]["quantity"]["quantity"]--;
      }
    } else if (type == "10g") {
      menuJson["menu"][index1][index]["quantity"]["10g"]++;
      quant = menuJson["menu"][index1][index]["quantity"]["10g"];

      if (quant > 15) {
        title = "Error";
        message = "Maximum quantity allowed is 15.";
        showInfoFlushbar(context);
        menuJson["menu"][index1][index]["quantity"]["10g"]--;
      }
    } else if (type == "25g") {
      menuJson["menu"][index1][index]["quantity"]["25g"]++;
      quant = menuJson["menu"][index1][index]["quantity"]["25g"];

      if (quant > 15) {
        title = "Error";
        message = "Maximum quantity allowed is 15.";
        showInfoFlushbar(context);
        menuJson["menu"][index1][index]["quantity"]["25g"]--;
      }
    } else if (type == "50g") {
      menuJson["menu"][index1][index]["quantity"]["50g"]++;
      quant = menuJson["menu"][index1][index]["quantity"]["50g"];

      if (quant > 15) {
        title = "Error";
        message = "Maximum quantity allowed is 15.";
        showInfoFlushbar(context);
        menuJson["menu"][index1][index]["quantity"]["50g"]--;
      }
    } else if (type == "100g") {
      menuJson["menu"][index1][index]["quantity"]["100g"]++;
      quant = menuJson["menu"][index1][index]["quantity"]["100g"];

      if (quant > 15) {
        title = "Error";
        message = "Maximum quantity allowed is 15.";
        showInfoFlushbar(context);
        menuJson["menu"][index1][index]["quantity"]["100g"]--;
      }
    } else if (type == "250g") {
      menuJson["menu"][index1][index]["quantity"]["250g"]++;
      quant = menuJson["menu"][index1][index]["quantity"]["250g"];

      if (quant > 15) {
        title = "Error";
        message = "Maximum quantity allowed is 15.";
        showInfoFlushbar(context);
        menuJson["menu"][index1][index]["quantity"]["250g"]--;
      }
    } else if (type == "500g") {
      menuJson["menu"][index1][index]["quantity"]["500g"]++;
      quant = menuJson["menu"][index1][index]["quantity"]["500g"];

      if (quant > 15) {
        title = "Error";
        message = "Maximum quantity allowed is 15.";
        showInfoFlushbar(context);
        menuJson["menu"][index1][index]["quantity"]["500g"]--;
      }
    } else if (type == "1kg") {
      menuJson["menu"][index1][index]["quantity"]["1kg"]++;
      quant = menuJson["menu"][index1][index]["quantity"]["1kg"];

      if (quant > 15) {
        title = "Error";
        message = "Maximum quantity allowed is 15.";
        showInfoFlushbar(context);
        menuJson["menu"][index1][index]["quantity"]["1kg"]--;
      }
    } else if (type == "2kg") {
      menuJson["menu"][index1][index]["quantity"]["2kg"]++;
      quant = menuJson["menu"][index1][index]["quantity"]["2kg"];

      if (quant > 15) {
        title = "Error";
        message = "Maximum quantity allowed is 15.";
        showInfoFlushbar(context);
        menuJson["menu"][index1][index]["quantity"]["2kg"]--;
      }
    } else if (type == "small") {
      menuJson["menu"][index1][index]["quantity"]["small"]++;
      quant = menuJson["menu"][index1][index]["quantity"]["small"];

      if (quant > 15) {
        title = "Error";
        message = "Maximum quantity allowed is 15.";
        showInfoFlushbar(context);
        menuJson["menu"][index1][index]["quantity"]["small"]--;
      }
    } else if (type == "medium") {
      menuJson["menu"][index1][index]["quantity"]["medium"]++;
      quant = menuJson["menu"][index1][index]["quantity"]["medium"];

      if (quant > 15) {
        title = "Error";
        message = "Maximum quantity allowed is 15.";
        showInfoFlushbar(context);
        menuJson["menu"][index1][index]["quantity"]["medium"]--;
      }
    } else if (type == "large") {
      menuJson["menu"][index1][index]["quantity"]["large"]++;
      quant = menuJson["menu"][index1][index]["quantity"]["large"];

      if (quant > 15) {
        title = "Error";
        message = "Maximum quantity allowed is 15.";
        showInfoFlushbar(context);
        menuJson["menu"][index1][index]["quantity"]["large"]--;
      }
    }
    setState(() {});
  }

  void showInfoFlushbar(BuildContext context) {
    Flushbar(
      title: title,
      message: message,
      icon: Icon(Icons.check, size: 28, color: Colors.green.shade300),
      duration: Duration(seconds: 5),
      leftBarIndicatorColor: Colors.green.shade300,
    )..show(context);
  }

  void showInfoFlushbar2(BuildContext context) {
    Flushbar(
      title: title,
      message: message,
      icon: Icon(Icons.delete, size: 28, color: Colors.red.shade600),
      duration: Duration(seconds: 5),
      leftBarIndicatorColor: Colors.red.shade600,
    )..show(context);
  }

  loadProducts() async {
    http.Response httpresponse = await http.get(
      'https://02c8cb08d4e2.ngrok.io/get_products_restaurant?vendor_id=' +
          vendorIdMenu.toString(),
    );
    if (httpresponse.statusCode == HttpStatus.ok) {
      menuJson = jsonDecode(httpresponse.body);
      isLoadingMenu = false;
      if (menuJson != null) {
        for (var i = 0; i < menuJson["menu"].length; i++) {
          for (var j = 0; j < menuJson["menu"][i].length; j++) {
            if (menuJson["menu"][i][j]["type"] == 1) {
              menuJson["menu"][i][j]["quantity"] = {};
              menuJson["menu"][i][j]["quantity"]["quantity"] = 0;
            } else if (menuJson["menu"][i][j]["type"] == 2) {
              menuJson["menu"][i][j]["quantity"] = {};
              menuJson["menu"][i][j]["quantity"]["10g"] = 0;
              menuJson["menu"][i][j]["quantity"]["25g"] = 0;
              menuJson["menu"][i][j]["quantity"]["50g"] = 0;
              menuJson["menu"][i][j]["quantity"]["100g"] = 0;
              menuJson["menu"][i][j]["quantity"]["250g"] = 0;
              menuJson["menu"][i][j]["quantity"]["500g"] = 0;
              menuJson["menu"][i][j]["quantity"]["1kg"] = 0;
              menuJson["menu"][i][j]["quantity"]["2kg"] = 0;
            } else if (menuJson["menu"][i][j]["type"] == 3) {
              menuJson["menu"][i][j]["quantity"] = {};
              menuJson["menu"][i][j]["quantity"]["small"] = 0;
              menuJson["menu"][i][j]["quantity"]["medium"] = 0;
              menuJson["menu"][i][j]["quantity"]["large"] = 0;
            }
            menuJson["menu"][i][j]["index"] = j;
            menuJson["menu"][i][j]["filtered_index"] = i;
            menuJson["menu"][i][j]["active"] = false;

            for (var k = 0;
                k < menuJson["menu"][i][j]["time_start"].length;
                k++) {
              var time;

              if (menuJson["menu"][i][j]["time_start"][k]
                      .toString()
                      .split(":")[2] ==
                  "PM") {
                if (int.parse(menuJson["menu"][i][j]["time_start"][k]
                        .toString()
                        .split(":")[0]) ==
                    12) {
                  time = new DateTime(
                      DateTime.now().year,
                      DateTime.now().month,
                      DateTime.now().day,
                      int.parse(menuJson["menu"][i][j]["time_start"][k]
                          .toString()
                          .split(":")[0]),
                      int.parse(menuJson["menu"][i][j]["time_start"][k]
                          .toString()
                          .split(":")[1]),
                      0);
                } else {
                  time = new DateTime(
                      DateTime.now().year,
                      DateTime.now().month,
                      DateTime.now().day,
                      int.parse(menuJson["menu"][i][j]["time_start"][k]
                              .toString()
                              .split(":")[0]) +
                          12,
                      int.parse(menuJson["menu"][i][j]["time_start"][k]
                          .toString()
                          .split(":")[1]),
                      0);
                }
              } else {
                time = new DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                    DateTime.now().day,
                    int.parse(menuJson["menu"][i][j]["time_start"][k]
                        .toString()
                        .split(":")[0]),
                    int.parse(menuJson["menu"][i][j]["time_start"][k]
                        .toString()
                        .split(":")[1]),
                    0);
              }
              menuJson["menu"][i][j]["time_start"][k] = time;
            }

            for (var l = 0;
                l < menuJson["menu"][i][j]["time_start"].length;
                l++) {
              var time;
              if (menuJson["menu"][i][j]["time_end"][l]
                      .toString()
                      .split(":")[2] ==
                  "PM") {
                time = new DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                    DateTime.now().day,
                    int.parse(menuJson["menu"][i][j]["time_end"][l]
                            .toString()
                            .split(":")[0]) +
                        12,
                    int.parse(menuJson["menu"][i][j]["time_end"][l]
                        .toString()
                        .split(":")[1]),
                    0);
              } else {
                time = new DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                    DateTime.now().day,
                    int.parse(menuJson["menu"][i][j]["time_end"][l]
                        .toString()
                        .split(":")[0]),
                    int.parse(menuJson["menu"][i][j]["time_end"][l]
                        .toString()
                        .split(":")[1]),
                    0);
              }
              menuJson["menu"][i][j]["time_end"][l] = time;
            }
          }
        }
      }
      setState(() {});
    }
  }

  returnType(i, j) {
    if (menuJson["menu"][i][j]["type"] == 1) {
      return "quantity";
    } else if (menuJson["menu"][i][j]["type"] == 2) {
      if (menuJson["menu"][i][j]["original_price"]["10g"] != 0 &&
          menuJson["menu"][i][j]["original_price"]["10g"] != null) {
        return "10g";
      } else if (menuJson["menu"][i][j]["original_price"]["25g"] != 0 &&
          menuJson["menu"][i][j]["original_price"]["25g"] != null) {
        return "25g";
      } else if (menuJson["menu"][i][j]["original_price"]["50g"] != 0 &&
          menuJson["menu"][i][j]["original_price"]["50g"] != null) {
        return "50g";
      } else if (menuJson["menu"][i][j]["original_price"]["100g"] != 0 &&
          menuJson["menu"][i][j]["original_price"]["100g"] != null) {
        return "100g";
      } else if (menuJson["menu"][i][j]["original_price"]["250g"] != 0 &&
          menuJson["menu"][i][j]["original_price"]["250g"] != null) {
        return "250g";
      } else if (menuJson["menu"][i][j]["original_price"]["500g"] != 0 &&
          menuJson["menu"][i][j]["original_price"]["500g"] != null) {
        return "500g";
      } else if (menuJson["menu"][i][j]["original_price"]["1kg"] != 0 &&
          menuJson["menu"][i][j]["original_price"]["1kg"] != null) {
        return "1kg";
      } else if (menuJson["menu"][i][j]["original_price"]["2kg"] != 0 &&
          menuJson["menu"][i][j]["original_price"]["2kg"] != null) {
        return "2kg";
      }
    } else if (menuJson["menu"][i][j]["type"] == 3) {
      if (menuJson["menu"][i][j]["original_price"]["medium"] != 0) {
        return "medium";
      } else if (menuJson["menu"][i][j]["original_price"]["small"] != 0) {
        return "small";
      } else if (menuJson["menu"][i][j]["original_price"]["large"] != 0) {
        return "large";
      }
    }
  }

  getPrice(index, index2, type) {
    if (type == 1) {
      return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(
            width: MediaQuery.of(context).size.width * .60,
            child: Text(
              pName +
                  '  ' +
                  '  \u{20B9}' +
                  menuJson["menu"][index][index2]["original_price"]
                          ["original_price"]
                      .toString(),
              style: TextStyle(color: Colors.black, fontSize: 16),
            )),
        Container(
            padding: EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: Colors.white,
              border: Border.all(
                color: Colors.grey,
                width: 1,
              ),
            ),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  InkWell(
                      splashColor: Colors.transparent,
                      onTap: () {
                        plus(index, menuJson["menu"][index][index2]["index"],
                            "quantity");
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: Colors.red,
                        ),
                        width: 25.0,
                        height: 25.0,
                        child: new Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 20,
                        ),
                      )),
                  Container(
                    padding: EdgeInsets.only(
                      left: 15,
                    ),
                    child: Text(
                        menuJson["menu"][index][index2]["quantity"]["quantity"]
                            .toString(),
                        style: new TextStyle(fontSize: 20.0)),
                  ),
                  Container(
                    padding: EdgeInsets.only(
                      left: 15,
                    ),
                    child: InkWell(
                        splashColor: Colors.transparent,
                        onTap: () {
                          minus(index, menuJson["menu"][index][index2]["index"],
                              "quantity");
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.red,
                          ),
                          width: 25.0,
                          height: 25.0,
                          child: Icon(
                            Icons.remove,
                            color: Colors.white,
                            size: 20,
                          ),
                        )),
                  )
                ])),
      ]);
    } else if (type == 2) {
      List<Widget> rowList = new List<Widget>();
      List<Widget> columnList = List<Widget>();

      if (menuJson["menu"][index][index2]["original_price"]["10g"] != 0 &&
          menuJson["menu"][index][index2]["original_price"]["10g"] != null) {
        rowList.add(
          Container(
              width: 150,
              padding: EdgeInsets.only(top: 5),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "10g",
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                    Text(
                      '\u{20B9}' +
                          menuJson["menu"][index][index2]["original_price"]
                                  ["10g"]
                              .toString(),
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    )
                  ])),
        );
        rowList.add(
          Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: Colors.white,
                border: Border.all(
                  color: Colors.grey,
                  width: 1,
                ),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    InkWell(
                        splashColor: Colors.transparent,
                        onTap: () {
                          plus(index, index2, "10g");
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.red,
                          ),
                          width: 25.0,
                          height: 25.0,
                          child: new Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        )),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: Text(
                          menuJson["menu"][index][index2]["quantity"]["10g"]
                              .toString(),
                          style: new TextStyle(fontSize: 20.0)),
                    ),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: InkWell(
                          splashColor: Colors.transparent,
                          onTap: () {
                            minus(index, index2, "10g");
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: Colors.red,
                            ),
                            width: 25.0,
                            height: 25.0,
                            child: Icon(
                              Icons.remove,
                              color: Colors.white,
                              size: 20,
                            ),
                          )),
                    )
                  ])),
        );
        columnList.add(Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rowList));
        columnList.add(SizedBox(
          height: 10,
        ));
        rowList = new List<Widget>();
      }
      if (menuJson["menu"][index][index2]["original_price"]["25g"] != 0 &&
          menuJson["menu"][index][index2]["original_price"]["25g"] != null) {
        rowList.add(
          Container(
              width: 150,
              padding: EdgeInsets.only(top: 5),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "25g",
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                    Text(
                      '\u{20B9}' +
                          menuJson["menu"][index][index2]["original_price"]
                                  ["25g"]
                              .toString(),
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    )
                  ])),
        );
        rowList.add(
          Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: Colors.white,
                border: Border.all(
                  color: Colors.grey,
                  width: 1,
                ),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    InkWell(
                        splashColor: Colors.transparent,
                        onTap: () {
                          plus(index, index2, "25g");
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.red,
                          ),
                          width: 25.0,
                          height: 25.0,
                          child: new Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        )),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: Text(
                          menuJson["menu"][index][index2]["quantity"]["25g"]
                              .toString(),
                          style: new TextStyle(fontSize: 20.0)),
                    ),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: InkWell(
                          splashColor: Colors.transparent,
                          onTap: () {
                            minus(index, index2, "25g");
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: Colors.red,
                            ),
                            width: 25.0,
                            height: 25.0,
                            child: Icon(
                              Icons.remove,
                              color: Colors.white,
                              size: 20,
                            ),
                          )),
                    )
                  ])),
        );
        columnList.add(Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rowList));
        columnList.add(SizedBox(
          height: 10,
        ));
        rowList = new List<Widget>();
      }
      if (menuJson["menu"][index][index2]["original_price"]["50g"] != 0 &&
          menuJson["menu"][index][index2]["original_price"]["50g"] != null) {
        rowList.add(
          Container(
              width: 150,
              padding: EdgeInsets.only(top: 5),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "50g",
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                    Text(
                      '\u{20B9}' +
                          menuJson["menu"][index][index2]["original_price"]
                                  ["50g"]
                              .toString(),
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    )
                  ])),
        );
        rowList.add(
          Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: Colors.white,
                border: Border.all(
                  color: Colors.grey,
                  width: 1,
                ),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    InkWell(
                        splashColor: Colors.transparent,
                        onTap: () {
                          plus(index, index2, "50g");
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.red,
                          ),
                          width: 25.0,
                          height: 25.0,
                          child: new Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        )),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: Text(
                          menuJson["menu"][index][index2]["quantity"]["50g"]
                              .toString(),
                          style: new TextStyle(fontSize: 20.0)),
                    ),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: InkWell(
                          splashColor: Colors.transparent,
                          onTap: () {
                            minus(index, index2, "50g");
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: Colors.red,
                            ),
                            width: 25.0,
                            height: 25.0,
                            child: Icon(
                              Icons.remove,
                              color: Colors.white,
                              size: 20,
                            ),
                          )),
                    )
                  ])),
        );
        columnList.add(Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rowList));
        columnList.add(SizedBox(
          height: 10,
        ));
        rowList = new List<Widget>();
      }

      if (menuJson["menu"][index][index2]["original_price"]["100g"] != 0 &&
          menuJson["menu"][index][index2]["original_price"]["100g"] != null) {
        rowList.add(
          Container(
              width: 150,
              padding: EdgeInsets.only(top: 5),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "100g",
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                    Text(
                      '\u{20B9}' +
                          menuJson["menu"][index][index2]["original_price"]
                                  ["100g"]
                              .toString(),
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    )
                  ])),
        );

        rowList.add(
          Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: Colors.white,
                border: Border.all(
                  color: Colors.grey,
                  width: 1,
                ),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    InkWell(
                        splashColor: Colors.transparent,
                        onTap: () {
                          plus(index, index2, "100g");
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.red,
                          ),
                          width: 25.0,
                          height: 25.0,
                          child: new Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        )),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: Text(
                          menuJson["menu"][index][index2]["quantity"]["100g"]
                              .toString(),
                          style: new TextStyle(fontSize: 20.0)),
                    ),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: InkWell(
                          splashColor: Colors.transparent,
                          onTap: () {
                            minus(index, index2, "100g");
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: Colors.red,
                            ),
                            width: 25.0,
                            height: 25.0,
                            child: Icon(
                              Icons.remove,
                              color: Colors.white,
                              size: 20,
                            ),
                          )),
                    )
                  ])),
        );
        columnList.add(Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rowList));
        columnList.add(SizedBox(
          height: 10,
        ));
        rowList = new List<Widget>();
      }
      if (menuJson["menu"][index][index2]["original_price"]["250g"] != 0 &&
          menuJson["menu"][index][index2]["original_price"]["250g"] != null) {
        rowList.add(
          Container(
              width: 150,
              padding: EdgeInsets.only(top: 5),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "250g",
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                    Text(
                      '\u{20B9}' +
                          menuJson["menu"][index][index2]["original_price"]
                                  ["250g"]
                              .toString(),
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    )
                  ])),
        );

        rowList.add(
          Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: Colors.white,
                border: Border.all(
                  color: Colors.grey,
                  width: 1,
                ),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    InkWell(
                        splashColor: Colors.transparent,
                        onTap: () {
                          plus(index, index2, "250g");
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.red,
                          ),
                          width: 25.0,
                          height: 25.0,
                          child: new Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        )),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: Text(
                          menuJson["menu"][index][index2]["quantity"]["250g"]
                              .toString(),
                          style: new TextStyle(fontSize: 20.0)),
                    ),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: InkWell(
                          splashColor: Colors.transparent,
                          onTap: () {
                            minus(index, index2, "250g");
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: Colors.red,
                            ),
                            width: 25.0,
                            height: 25.0,
                            child: Icon(
                              Icons.remove,
                              color: Colors.white,
                              size: 20,
                            ),
                          )),
                    )
                  ])),
        );
        columnList.add(Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rowList));
        columnList.add(SizedBox(
          height: 10,
        ));
        rowList = new List<Widget>();
      }
      if (menuJson["menu"][index][index2]["original_price"]["500g"] != 0 &&
          menuJson["menu"][index][index2]["original_price"]["500g"] != null) {
        rowList.add(
          Container(
              width: 150,
              padding: EdgeInsets.only(top: 5),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "500g",
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                    Text(
                      '\u{20B9}' +
                          menuJson["menu"][index][index2]["original_price"]
                                  ["500g"]
                              .toString(),
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    )
                  ])),
        );
        rowList.add(
          Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: Colors.white,
                border: Border.all(
                  color: Colors.grey,
                  width: 1,
                ),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    InkWell(
                        splashColor: Colors.transparent,
                        onTap: () {
                          plus(index, index2, "500g");
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.red,
                          ),
                          width: 25.0,
                          height: 25.0,
                          child: new Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        )),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: Text(
                          menuJson["menu"][index][index2]["quantity"]["500g"]
                              .toString(),
                          style: new TextStyle(fontSize: 20.0)),
                    ),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: InkWell(
                          splashColor: Colors.transparent,
                          onTap: () {
                            minus(index, index2, "500g");
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: Colors.red,
                            ),
                            width: 25.0,
                            height: 25.0,
                            child: Icon(
                              Icons.remove,
                              color: Colors.white,
                              size: 20,
                            ),
                          )),
                    )
                  ])),
        );
        columnList.add(Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rowList));
        columnList.add(SizedBox(
          height: 10,
        ));
        rowList = new List<Widget>();
      }
      if (menuJson["menu"][index][index2]["original_price"]["1kg"] != 0 &&
          menuJson["menu"][index][index2]["original_price"]["1kg"] != null) {
        rowList.add(
          Container(
              width: 150,
              padding: EdgeInsets.only(top: 5),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "1kg",
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                    Text(
                      '\u{20B9}' +
                          menuJson["menu"][index][index2]["original_price"]
                                  ["1kg"]
                              .toString(),
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    )
                  ])),
        );
        rowList.add(
          Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: Colors.white,
                border: Border.all(
                  color: Colors.grey,
                  width: 1,
                ),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    InkWell(
                        splashColor: Colors.transparent,
                        onTap: () {
                          plus(index, index2, "1kg");
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.red,
                          ),
                          width: 25.0,
                          height: 25.0,
                          child: new Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        )),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: Text(
                          menuJson["menu"][index][index2]["quantity"]["1kg"]
                              .toString(),
                          style: new TextStyle(fontSize: 20.0)),
                    ),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: InkWell(
                          splashColor: Colors.transparent,
                          onTap: () {
                            minus(index, index2, "1kg");
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: Colors.red,
                            ),
                            width: 25.0,
                            height: 25.0,
                            child: Icon(
                              Icons.remove,
                              color: Colors.white,
                              size: 20,
                            ),
                          )),
                    )
                  ])),
        );
        columnList.add(Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rowList));
        columnList.add(SizedBox(
          height: 10,
        ));
        rowList = new List<Widget>();
      }
      if (menuJson["menu"][index][index2]["original_price"]["2kg"] != 0 &&
          menuJson["menu"][index][index2]["original_price"]["2kg"] != null) {
        rowList.add(
          Container(
              width: 150,
              padding: EdgeInsets.only(top: 5),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "2kg",
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                    Text(
                      '\u{20B9}' +
                          menuJson["menu"][index][index2]["original_price"]
                                  ["2kg"]
                              .toString(),
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    )
                  ])),
        );
        rowList.add(
          Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: Colors.white,
                border: Border.all(
                  color: Colors.grey,
                  width: 1,
                ),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    InkWell(
                        splashColor: Colors.transparent,
                        onTap: () {
                          plus(index, index2, "2kg");
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.red,
                          ),
                          width: 25.0,
                          height: 25.0,
                          child: new Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        )),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: Text(
                          menuJson["menu"][index][index2]["quantity"]["2kg"]
                              .toString(),
                          style: new TextStyle(fontSize: 20.0)),
                    ),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                        right: 5,
                      ),
                      child: InkWell(
                          splashColor: Colors.transparent,
                          onTap: () {
                            minus(index, index2, "2kg");
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: Colors.red,
                            ),
                            width: 25.0,
                            height: 25.0,
                            child: Icon(
                              Icons.remove,
                              color: Colors.white,
                              size: 20,
                            ),
                          )),
                    )
                  ])),
        );
        columnList.add(Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rowList));
        columnList.add(SizedBox(
          height: 10,
        ));
        rowList = new List<Widget>();
      }
      return new Column(children: columnList);
    } else if (type == 3) {
      List<Widget> columnList = new List<Widget>();
      List<Widget> rowList = new List<Widget>();

      if (menuJson["menu"][index][index2]["original_price"]["small"] != 0) {
        rowList.add(
          Container(
              width: 150,
              padding: EdgeInsets.only(top: 5),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Small ",
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                    Text(
                      ' \u{20B9}' +
                          menuJson["menu"][index][index2]["original_price"]
                                  ["small"]
                              .toString(),
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    )
                  ])),
        );
        rowList.add(
          Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: Colors.white,
                border: Border.all(
                  color: Colors.grey,
                  width: 1,
                ),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    InkWell(
                        splashColor: Colors.transparent,
                        onTap: () {
                          plus(index, index2, "small");
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.red,
                          ),
                          width: 25.0,
                          height: 25.0,
                          child: new Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        )),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: Text(
                          menuJson["menu"][index][index2]["quantity"]["small"]
                              .toString(),
                          style: new TextStyle(fontSize: 20.0)),
                    ),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                        right: 5,
                      ),
                      child: InkWell(
                          splashColor: Colors.transparent,
                          onTap: () {
                            minus(index, index2, "small");
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: Colors.red,
                            ),
                            width: 25.0,
                            height: 25.0,
                            child: Icon(
                              Icons.remove,
                              color: Colors.white,
                              size: 20,
                            ),
                          )),
                    )
                  ])),
        );

        columnList.add(Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rowList));
        columnList.add(SizedBox(
          height: 10,
        ));
        rowList = new List<Widget>();
      }
      if (menuJson["menu"][index][index2]["original_price"]["medium"] != 0) {
        rowList.add(
          Container(
              width: 150,
              padding: EdgeInsets.only(top: 5),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Medium ",
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                    Text(
                      ' \u{20B9}' +
                          menuJson["menu"][index][index2]["original_price"]
                                  ["medium"]
                              .toString(),
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    )
                  ])),
        );
        rowList.add(
          Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: Colors.white,
                border: Border.all(
                  color: Colors.grey,
                  width: 1,
                ),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    InkWell(
                        splashColor: Colors.transparent,
                        onTap: () {
                          plus(index, index2, "medium");
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.red,
                          ),
                          width: 25.0,
                          height: 25.0,
                          child: new Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        )),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                      ),
                      child: Text(
                          menuJson["menu"][index][index2]["quantity"]["medium"]
                              .toString(),
                          style: new TextStyle(fontSize: 20.0)),
                    ),
                    Container(
                      padding: EdgeInsets.only(
                        left: 15,
                        right: 5,
                      ),
                      child: InkWell(
                          splashColor: Colors.transparent,
                          onTap: () {
                            minus(index, index2, "medium");
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: Colors.red,
                            ),
                            width: 25.0,
                            height: 25.0,
                            child: Icon(
                              Icons.remove,
                              color: Colors.white,
                              size: 20,
                            ),
                          )),
                    )
                  ])),
        );

        columnList.add(Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rowList));
        columnList.add(SizedBox(
          height: 10,
        ));
        rowList = new List<Widget>();
      }
      if (menuJson["menu"][index][index2]["original_price"]["large"] != 0) {
        rowList.add(
          Container(
              width: 150,
              padding: EdgeInsets.only(top: 5),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Large ",
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                    Text(
                      ' \u{20B9}' +
                          menuJson["menu"][index][index2]["original_price"]
                                  ["large"]
                              .toString(),
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    )
                  ])),
        );
        rowList.add(Container(
            padding: EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: Colors.white,
              border: Border.all(
                color: Colors.grey[300],
                width: 1,
              ),
            ),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  InkWell(
                      splashColor: Colors.transparent,
                      onTap: () {
                        plus(index, index2, "large");
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: Colors.red,
                        ),
                        width: 25.0,
                        height: 25.0,
                        child: new Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 20,
                        ),
                      )),
                  Container(
                    padding: EdgeInsets.only(
                      left: 15,
                    ),
                    child: Text(
                        menuJson["menu"][index][index2]["quantity"]["large"]
                            .toString(),
                        style: new TextStyle(fontSize: 20.0)),
                  ),
                  Container(
                    padding: EdgeInsets.only(
                      left: 15,
                      right: 5,
                    ),
                    child: InkWell(
                        splashColor: Colors.transparent,
                        onTap: () {
                          minus(index, index2, "large");
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.red,
                          ),
                          width: 25.0,
                          height: 25.0,
                          child: Icon(
                            Icons.remove,
                            color: Colors.white,
                            size: 20,
                          ),
                        )),
                  )
                ])));

        columnList.add(Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rowList));
        columnList.add(SizedBox(
          height: 10,
        ));
        rowList = new List<Widget>();
      }

      return new Column(children: columnList);
    }
  }

  getAvailability(index, index2) {
    var available = false;
    for (var u = 0;
        u < menuJson["menu"][index][index2]["time_start"].length;
        u++) {
      if (menuJson["menu"][index][index2]["available"]) {
        if (DateTime.now()
                .isAfter(menuJson["menu"][index][index2]["time_start"][u]) &&
            DateTime.now()
                .isBefore(menuJson["menu"][index][index2]["time_end"][u])) {
          available = true;
        }
      }
    }
    return available;
  }

  returnHeight(heightvar) {
    if (heightvar == 1) {
      return 150.0;
    } else if (heightvar == 2) {
      return 180.0;
    } else if (heightvar == 3) {
      return 230.0;
    } else if (heightvar == 4) {
      return 270.0;
    } else if (heightvar == 5) {
      return 310.0;
    } else if (heightvar == 6) {
      return 350.0;
    } else if (heightvar == 7) {
      return 390.0;
    }
  }

  setProduct(index, index2, type) {
    pIndex = index;
    pIndex2 = index2;
    pType = type;
    pName = menuJson["menu"][index][index2]["product_name"];

    if (type == 1) {
      heightvar = 1;
    } else if (type == 2) {
      heightvar = 0;
      if (menuJson["menu"][index][index2]["original_price"]["10g"] != 0) {
        heightvar++;
      }
      if (menuJson["menu"][index][index2]["original_price"]["25g"] != 0) {
        heightvar++;
      }
      if (menuJson["menu"][index][index2]["original_price"]["50g"] != 0) {
        heightvar++;
      }
      if (menuJson["menu"][index][index2]["original_price"]["100g"] != 0) {
        heightvar++;
      }
      if (menuJson["menu"][index][index2]["original_price"]["500g"] != 0) {
        heightvar++;
      }
      if (menuJson["menu"][index][index2]["original_price"]["250g"] != 0) {
        heightvar++;
      }
      if (menuJson["menu"][index][index2]["original_price"]["1kg"] != 0) {
        heightvar++;
      }
      if (menuJson["menu"][index][index2]["original_price"]["2kg"] != 0) {
        heightvar++;
      }
      print("HEIGHT");
      print(heightvar);
    } else if (type == 3) {
      heightvar = 0;
      if (menuJson["menu"][index][index2]["original_price"]["small"] != 0) {
        heightvar++;
      }
      if (menuJson["menu"][index][index2]["original_price"]["medium"] != 0) {
        heightvar++;
      }
      if (menuJson["menu"][index][index2]["original_price"]["large"] != 0) {
        heightvar++;
      }
    }
  }

  resetProduct() {
    pIndex = null;
    pIndex2 = null;
    pType = null;
    pName = null;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingMenu) {
      return Scaffold(
          backgroundColor: Colors.white,
          appBar: PreferredSize(
              preferredSize: Size.fromHeight(60),
              child: new AppBar(
                brightness: Brightness.dark, // or use Brightness.dark
                backgroundColor: Color(0xFF0E0038),
                centerTitle: true,
                title: Text(
                  vendorNameMenu,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: "AvenirBold",
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )),
          body: AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle.dark, child: ShimmerList()));
    } else {
      return WillPopScope(
          onWillPop: () async {
            final ConfirmAction action = await _asyncConfirmDialog(context);
            if (action == ConfirmAction.Cancel) {
            } else {
              clearCart();
              isLoadingMenu = true;
              Navigator.of(context).pop(true);
            }
          },
          child: Scaffold(
              backgroundColor: Colors.white,
              appBar: PreferredSize(
                  preferredSize: Size.fromHeight(60),
                  child: new AppBar(
                      brightness: Brightness.dark,
                      backgroundColor: Color(0xFF0E0038),
                      centerTitle: true,
                      title: Text(
                        vendorNameMenu,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: "AvenirBold",
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      actions: [
                        Container(
                          width: AppBar().preferredSize.height - 12,
                          height: AppBar().preferredSize.height - 12,
                          color: Color(0xFF0E0038),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(
                                  AppBar().preferredSize.height),
                              child: Stack(
                                children: <Widget>[
                                  IconButton(
                                    icon: Icon(
                                      Icons.shopping_cart,
                                      color: Colors.white,
                                    ),
                                    onPressed: null,
                                  ),
                                  getCartNumberOfItems() == null
                                      ? Container()
                                      : Positioned(
                                          bottom: 30.0,
                                          right: 20.0,
                                          child: Stack(
                                            children: <Widget>[
                                              Icon(Icons.brightness_1,
                                                  size: 25.0,
                                                  color: Colors.red),
                                              Positioned(
                                                  top: 5.0,
                                                  right: 8.0,
                                                  child: Text(
                                                    "${getCartNumberOfItems()}",
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 13.0,
                                                        fontWeight:
                                                            FontWeight.w500),
                                                  ))
                                            ],
                                          )),
                                ],
                              ),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => CartPage()),
                                );
                                refreshState();
                              },
                            ),
                          ),
                        ),
                      ])),
              body: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle.dark,
                  child: Stack(alignment: Alignment.bottomCenter, children: [
                    FadeTransition(
                        opacity: _boxAnimation,
                        child: Container(
                            color: Colors.white,
                            child: ListView.builder(
                                itemCount: menuJson["count"],
                                itemBuilder: (context, index) {
                                  return Column(children: [
                                    Container(
                                        margin: EdgeInsets.only(bottom: 5),
                                        height: 40,
                                        color: Colors.red,
                                        child: Center(
                                          child: Text(
                                            menuJson["menu_categories"][index],
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.oxygen(
                                              fontSize: 20,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        )),
                                    Column(children: [
                                      ListView.builder(
                                          physics: ScrollPhysics(),
                                          shrinkWrap: true,
                                          itemCount:
                                              menuJson["menu"][index].length,
                                          itemBuilder: (context, index2) {
                                            return Container(
                                                margin: EdgeInsets.only(
                                                    right: 5,
                                                    left: 5,
                                                    bottom: 5),
                                                child: Container(
                                                    height: 90,
                                                    width:
                                                        MediaQuery.of(context)
                                                            .size
                                                            .width,
                                                    child: InkWell(
                                                        splashColor:
                                                            Colors.transparent,
                                                        onTap: () {
                                                          if (!toggle) {
                                                            setProduct(
                                                                index,
                                                                menuJson["menu"]
                                                                            [
                                                                            index]
                                                                        [index2]
                                                                    ["index"],
                                                                menuJson["menu"]
                                                                            [
                                                                            index]
                                                                        [index2]
                                                                    ["type"]);
                                                            toggleOpen();
                                                          }
                                                        },
                                                        borderRadius: BorderRadius
                                                            .circular(AppBar()
                                                                .preferredSize
                                                                .height),
                                                        child: Card(
                                                            child: Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceBetween,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Container(
                                                                    height: 68,
                                                                    padding:
                                                                        EdgeInsets
                                                                            .only(
                                                                      left: 5,
                                                                      top: 5,
                                                                    ),
                                                                    child:
                                                                        ClipRRect(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              8.0),
                                                                      child: FadeInImage
                                                                          .assetNetwork(
                                                                        height:
                                                                            150,
                                                                        width:
                                                                            100,
                                                                        placeholder:
                                                                            'assets/images/loader.gif',
                                                                        image: 'https://02c8cb08d4e2.ngrok.io/static/img/' +
                                                                            menuJson["menu"][index][index2]["product_id"] +
                                                                            ".jpg",
                                                                      ),
                                                                    )),
                                                                Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      Row(
                                                                          crossAxisAlignment: CrossAxisAlignment
                                                                              .center,
                                                                          mainAxisAlignment:
                                                                              MainAxisAlignment.spaceAround,
                                                                          children: [
                                                                            Container(
                                                                              width: MediaQuery.of(context).size.width * 0.635,
                                                                              padding: EdgeInsets.only(left: 10, top: 2),
                                                                              child: Text(
                                                                                menuJson["menu"][index][index2]["product_name"],
                                                                                style: TextStyle(
                                                                                  fontSize: 16,
                                                                                  color: Colors.black,
                                                                                ),
                                                                                textAlign: TextAlign.left,
                                                                              ),
                                                                            ),
                                                                            menuJson["menu"][index][index2]["nonveg"]
                                                                                ? Container(
                                                                                    margin: EdgeInsets.all(3),
                                                                                    child: Image.asset(
                                                                                      "assets/images/nonveg.png",
                                                                                      width: 15,
                                                                                    ))
                                                                                : Container(
                                                                                    margin: EdgeInsets.all(3),
                                                                                    child: Image.asset(
                                                                                      "assets/images/veg.png",
                                                                                      width: 15,
                                                                                    ))
                                                                          ]),
                                                                      Container(
                                                                          height:
                                                                              30,
                                                                          width: MediaQuery.of(context).size.width *
                                                                              .5,
                                                                          padding: EdgeInsets.only(
                                                                              left:
                                                                                  10,
                                                                              top:
                                                                                  2),
                                                                          child:
                                                                              Text(
                                                                            menuJson["menu"][index][index2]["description"],
                                                                            style:
                                                                                TextStyle(color: Colors.grey, fontSize: 12),
                                                                            textAlign:
                                                                                TextAlign.left,
                                                                          )),
                                                                    ]),
                                                              ],
                                                            ),
                                                          ],
                                                        )))));
                                          })
                                    ]),
                                  ]);
                                }))),
                    pName != null
                        ? SlideTransition(
                            position: _offsetAnimation,
                            child: Container(
                              child: Container(
                                  width: MediaQuery.of(context).size.width,
                                  child: Column(children: [
                                    Container(
                                        child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                          Container(
                                            height: 70,
                                            margin: EdgeInsets.only(
                                                right: 5, left: 20, top: 10),
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                .75,
                                            color: Colors.white,
                                            child: Text(
                                              pName,
                                              textAlign: TextAlign.left,
                                              style: GoogleFonts.oxygen(
                                                fontSize: 20,
                                                color: Colors.black,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Center(
                                              child: Container(
                                                  margin:
                                                      EdgeInsets.only(right: 5),
                                                  color: Colors.transparent,
                                                  child: IconButton(
                                                    splashColor:
                                                        Colors.transparent,
                                                    icon:
                                                        const Icon(Icons.close),
                                                    color: Colors.grey[600],
                                                    onPressed: () {
                                                      toggleClose();
                                                    },
                                                  ))),
                                        ])),
                                    getAvailability(pIndex, pIndex2)
                                        ? Container(
                                            margin: EdgeInsets.only(
                                                right: 5,
                                                bottom: 5,
                                                left: 20,
                                                top: 5),
                                            child: getPrice(
                                                pIndex, pIndex2, pType))
                                        : Container(
                                            margin: EdgeInsets.only(
                                                right: 5,
                                                bottom: 5,
                                                left: 20,
                                                top: 5),
                                            child: Text(
                                                "Product not available at this time"))
                                  ])),
                              height: returnHeight(heightvar),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.grey[300],
                                        spreadRadius: 2),
                                  ],
                                  borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(20),
                                      topRight: Radius.circular(20))),
                            ))
                        : Center()
                  ]))));
    }
  }
}

class PastOrders extends StatefulWidget {
  @override
  _PastOrders createState() => _PastOrders();
}

class _PastOrders extends State<PastOrders> {
  @override
  void initState() {
    super.initState();
    getOrders();
  }

  var isLoading = true;

  Future getOrders() async {
    isLoading = true;
    var data = new Map<String, dynamic>();
    data['phone_number'] = userPhone;

    http.Response response = await http.post(
      'https://02c8cb08d4e2.ngrok.io/user_orders',
      body: data,
    );

    if (response.statusCode == HttpStatus.ok) {
      orderListJson = jsonDecode(response.body);
      isLoading = false;
      for (var i = 0; i < orderListJson.length; i++) {
        orderListJson[i]["index"] = i;
      }
    }
    setState(() {});
  }

  activeTap(index) {
    orderId = orderListJson[index]["order_id"];
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => OrderDetails()));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (orderId != null && newOrder) {
      newOrder = false;
      Navigator.push(
          context, MaterialPageRoute(builder: (context) => OrderDetails()));
    }
    return isLoading == true
        ? Scaffold(
            body: Center(
                child: Container(
                    margin: EdgeInsets.all(3),
                    child: Image.asset(
                      "assets/images/logoload.gif",
                      width: 48,
                    ))),
          )
        : Scaffold(
            appBar: AppBar(
              iconTheme: IconThemeData(color: Colors.white),
              title: Padding(
                  padding: const EdgeInsets.only(
                    top: 10,
                  ),
                  child: Center(
                    child: Text(
                      'Past Orders',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: "AvenirBold",
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )),
              backgroundColor: Color(0xFF0E0038),
            ),
            body: Container(
                color: Colors.white,
                child: ListView.builder(
                    itemCount: orderListJson.length,
                    itemBuilder: (context, index) {
                      return Material(
                          color: Colors.white,
                          child: InkWell(
                              onTap: () =>
                                  activeTap(orderListJson[index]["index"]),
                              child: Card(
                                  child: Container(
                                      padding: EdgeInsets.all(15),
                                      child: Column(children: [
                                        Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                orderListJson[index]
                                                    ["order_id"],
                                                style: TextStyle(
                                                  fontFamily: "Avenir",
                                                  fontSize: 16,
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                orderListJson[index]
                                                    ["created_at"],
                                                style: TextStyle(
                                                  fontFamily: "Avenir",
                                                  fontSize: 16,
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              )
                                            ]),
                                        Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                "\u{20B9} " +
                                                    orderListJson[index]
                                                        ["total_customer"],
                                                style: TextStyle(
                                                  fontFamily: "Avenir",
                                                  fontSize: 18,
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              orderListJson[index]["rated"] ==
                                                      false
                                                  ? Container(
                                                      width: 80,
                                                      height: 25,
                                                      margin: EdgeInsets.only(
                                                          top: 10, right: 8),
                                                      child: RaisedButton(
                                                        elevation: 5,
                                                        onPressed: () {
                                                          orderId =
                                                              orderListJson[
                                                                      index]
                                                                  ["order_id"];

                                                          Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                  builder:
                                                                      (context) =>
                                                                          FeedbackScreen()));
                                                        },
                                                        textColor: Colors.black,
                                                        padding:
                                                            EdgeInsets.all(0.0),
                                                        child: Container(
                                                          decoration:
                                                              BoxDecoration(
                                                                  color: Colors
                                                                      .red),
                                                          padding:
                                                              EdgeInsets.all(
                                                                  5.0),
                                                          child: Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceBetween,
                                                              children: [
                                                                Container(
                                                                    margin: EdgeInsets
                                                                        .only(
                                                                            right:
                                                                                2),
                                                                    child: Icon(
                                                                      Icons
                                                                          .feedback,
                                                                      color: Colors
                                                                          .white,
                                                                      size: 15,
                                                                    )),
                                                                Text('FEEDBACK',
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            10,
                                                                        color: Colors
                                                                            .white)),
                                                              ]),
                                                        ),
                                                      ),
                                                    )
                                                  : Text("")
                                            ]),
                                      ])))));
                    })));
  }
}

class FeedbackScreen extends StatefulWidget {
  @override
  _FeedbackScreen createState() => _FeedbackScreen();
}

class _FeedbackScreen extends State<FeedbackScreen> {
  double _rating = 3.0;
  var question1 = true;
  var question2 = true;
  var question3 = true;
  var question4 = true;
  var question5 = true;
  var rated = false;

  void showInfoFlushbar(BuildContext context) {
    Flushbar(
      title: title,
      message: message,
      icon: Icon(Icons.delete, size: 28, color: Colors.green),
      duration: Duration(seconds: 5),
      leftBarIndicatorColor: Colors.red.shade600,
    )..show(context);
  }

  void showInfoFlushbar2(BuildContext context) {
    Flushbar(
      title: title,
      message: message,
      icon: Icon(Icons.delete, size: 28, color: Colors.red.shade600),
      duration: Duration(seconds: 5),
      leftBarIndicatorColor: Colors.red.shade600,
    )..show(context);
  }

  _proceedToFeedback() async {
    var data = {};
    var questions = {};
    questions["question1"] = question1;
    questions["question2"] = question2;
    questions["question3"] = question3;
    questions["question4"] = question4;
    questions["question5"] = question5;
    data["feedback"] = questions;
    data["order_id"] = orderId;
    data["rating"] = _rating;
    http.Response httpresponse = await http.post(
        'https://02c8cb08d4e2.ngrok.io/feedback',
        body: jsonEncode(data),
        headers: {
          'Content-type': 'application/json',
          'Accept': 'application/json'
        });
    if (httpresponse.statusCode == HttpStatus.ok) {
      title = "Thanks!";
      message = "Thank you for your feedback!";
      showInfoFlushbar(context);
    } else {
      title = "Error.";
      message = "Error submitting feedback, try again later.";
      showInfoFlushbar2(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        title: Container(
            padding: const EdgeInsets.only(
              top: 5,
            ),
            margin: const EdgeInsets.only(
              right: 55,
            ),
            child: Center(
              child: Text(
                'Feedback Screen',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: "AvenirBold",
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )),
        backgroundColor: Color(0xFF0E0038),
      ),
      body: Container(
          child: Column(
        children: [
          SizedBox(
            height: 30,
          ),
          Center(
            child: Text(
              'Please rate your experience',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.black,
              ),
            ),
          ),
          SizedBox(
            height: 20,
          ),
          Center(
              child: RatingBar(
            initialRating: 2,
            minRating: 1,
            direction: Axis.horizontal,
            allowHalfRating: true,
            unratedColor: Colors.amber.withAlpha(50),
            itemCount: 5,
            itemSize: 50.0,
            itemPadding: EdgeInsets.symmetric(horizontal: 4.0),
            itemBuilder: (context, _) => Icon(
              Icons.star,
              color: Colors.amber,
            ),
            onRatingUpdate: (rating) {
              setState(() {
                _rating = rating;
                rated = true;
              });
            },
          )),
          SizedBox(
            height: 40,
          ),
          rated
              ? _rating > 4.0
                  ? Center(
                      child: Container(
                          width: 230,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Center(
                                  child: Text(
                                'What did you love?',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.black,
                                ),
                              )),
                              SizedBox(
                                height: 20,
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Delivery time '),
                                  Checkbox(
                                    value: question1,
                                    onChanged: (bool value) {
                                      setState(() {
                                        question1 = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Quality of food '),
                                  Checkbox(
                                    value: question2,
                                    onChanged: (bool value) {
                                      setState(() {
                                        question2 = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Quantity of food'),
                                  Checkbox(
                                    value: question3,
                                    onChanged: (bool value) {
                                      setState(() {
                                        question3 = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Pricing '),
                                  Checkbox(
                                    value: question4,
                                    onChanged: (bool value) {
                                      setState(() {
                                        question4 = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Ordering experience '),
                                  Checkbox(
                                    value: question5,
                                    onChanged: (bool value) {
                                      setState(() {
                                        question5 = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              SizedBox(
                                height: 20,
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(vertical: 25.0),
                                width: double.infinity,
                                child: RaisedButton(
                                  elevation: 5.0,
                                  onPressed: () => _proceedToFeedback(),
                                  padding: EdgeInsets.all(15.0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(0.0),
                                  ),
                                  color: Color(0xFF0E0038),
                                  child: Text(
                                    'SUBMIT FEEDBACK',
                                    style: TextStyle(
                                      color: Colors.white,
                                      letterSpacing: 1.5,
                                      fontSize: 18.0,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Avenir',
                                    ),
                                  ),
                                ),
                              )
                            ],
                          )))
                  : Center(
                      child: Container(
                      width: 230,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Center(
                              child: Text(
                            'What can we improve?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.black,
                            ),
                          )),
                          SizedBox(
                            height: 20,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Delivery time '),
                              Checkbox(
                                value: question1,
                                onChanged: (bool value) {
                                  setState(() {
                                    question1 = value;
                                  });
                                },
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Quality of food '),
                              Checkbox(
                                value: question2,
                                onChanged: (bool value) {
                                  setState(() {
                                    question2 = value;
                                  });
                                },
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Quantity of food'),
                              Checkbox(
                                value: question3,
                                onChanged: (bool value) {
                                  setState(() {
                                    question3 = value;
                                  });
                                },
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Pricing '),
                              Checkbox(
                                value: question4,
                                onChanged: (bool value) {
                                  setState(() {
                                    question4 = value;
                                  });
                                },
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Ordering experience '),
                              Checkbox(
                                value: question5,
                                onChanged: (bool value) {
                                  setState(() {
                                    question5 = value;
                                  });
                                },
                              ),
                            ],
                          ),
                          SizedBox(
                            height: 20,
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(vertical: 25.0),
                            width: double.infinity,
                            child: RaisedButton(
                              elevation: 5.0,
                              onPressed: () => _proceedToFeedback(),
                              padding: EdgeInsets.all(15.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(0.0),
                              ),
                              color: Color(0xFF0E0038),
                              child: Text(
                                'SUBMIT FEEDBACK',
                                style: TextStyle(
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Avenir',
                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                    ))
              : Center()
        ],
      )),
    );
  }
}

//=-= ---------------------------------------------------------
//  Order Details
//=-= ---------------------------------------------------------

class OrderDetails extends StatefulWidget {
  @override
  _OrderDetails createState() => _OrderDetails();
}

class _OrderDetails extends State<OrderDetails> {
  @override
  void initState() {
    super.initState();
    getOrderDetails();
  }

  var isLoading = true;

  Future refreshList() async {
    isLoading = true;
    getOrderDetails();
  }

  Future getOrderDetails() async {
    if (isLoading) {
      var data = new Map<String, dynamic>();
      data['order_id'] = orderId;
      http.Response response = await http.post(
        'https://02c8cb08d4e2.ngrok.io/order_details',
        body: data,
      );
      if (response.statusCode == HttpStatus.ok) {
        orderJson = jsonDecode(response.body);
        isLoading = false;
        for (var i = 0; i < orderJson["order"].length; i++) {
          if (orderJson["order"][i]["type"] == 2) {
            orderJson["order"][i]["tenAdded"] = false;
            orderJson["order"][i]["twentyfiveAdded"] = false;
            orderJson["order"][i]["fiftyAdded"] = false;
            orderJson["order"][i]["hundredAdded"] = false;
            orderJson["order"][i]["twofiftyAdded"] = false;
            orderJson["order"][i]["fivehundredAdded"] = false;
            orderJson["order"][i]["kgAdded"] = false;
            orderJson["order"][i]["twokgAdded"] = false;
          } else if (orderJson["order"][i]["type"] == 3) {
            orderJson["order"][i]["smallAdded"] = false;
            orderJson["order"][i]["mediumAdded"] = false;
            orderJson["order"][i]["largeAdded"] = false;
          }
        }
        setState(() {});
      }
    }
  }

  getContainer(index, type) {
    if (type == 1) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: MediaQuery.of(context).size.width * 0.45,
                  child: Text(
                    orderJson["order"][index]["product_name"],
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ]),
            ],
          ),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: <Widget>[
            Container(
              padding: EdgeInsets.only(
                left: 10,
              ),
              child: Text(
                  orderJson["order"][index]["original_price"]["original_price"]
                          .toString() +
                      " \u{00D7} " +
                      orderJson["order"][index]["quantity"]["quantity"]
                          .toString(),
                  style: new TextStyle(fontSize: 15.0, color: Colors.grey)),
            ),
            SizedBox(
              width: 10,
            ),
            Container(
                padding: EdgeInsets.only(left: 10, top: 0),
                child: Text(
                  '\u{20B9} ' +
                      (orderJson["order"][index]["original_price"]
                                  ["original_price"] *
                              orderJson["order"][index]["quantity"]["quantity"])
                          .toString(),
                  style: TextStyle(color: Colors.black, fontSize: 20),
                  textAlign: TextAlign.right,
                )),
          ])
        ],
      );
    } else if (type == 2) {
      List<Widget> rowList = new List<Widget>();
      if (orderJson["order"][index]["quantity"]["10g"] != 0) {
        if (orderJson["order"][index]["tenAdded"]) {
        } else {
          orderJson["order"][index]["tenAdded"] = true;
          rowList.add(Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * 0.45,
                            child: Text(
                              orderJson["order"][index]["product_name"] +
                                  " " +
                                  "10g",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ]),
                  ],
                ),
                Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.only(
                          left: 10,
                        ),
                        child: Text(
                            orderJson["order"][index]["original_price"]["10g"]
                                    .toString() +
                                " \u{00D7} " +
                                orderJson["order"][index]["quantity"]["10g"]
                                    .toString(),
                            style: new TextStyle(
                                fontSize: 15.0, color: Colors.grey)),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Container(
                          padding: EdgeInsets.only(left: 10, top: 0),
                          child: Text(
                            '\u{20B9} ' +
                                (orderJson["order"][index]["original_price"]
                                            ["10g"] *
                                        orderJson["order"][index]["quantity"]
                                            ["10g"])
                                    .toString(),
                            style: TextStyle(color: Colors.black, fontSize: 20),
                            textAlign: TextAlign.right,
                          )),
                    ])
              ]));
        }
      }
      if (orderJson["order"][index]["quantity"]["25g"] != 0) {
        if (orderJson["order"][index]["twentyfiveAdded"]) {
        } else {
          orderJson["order"][index]["twentyfiveAdded"] = true;
          rowList.add(Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * 0.45,
                            child: Text(
                              orderJson["order"][index]["product_name"] +
                                  " " +
                                  "25g",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ]),
                  ],
                ),
                Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.only(
                          left: 10,
                        ),
                        child: Text(
                            orderJson["order"][index]["original_price"]["25g"]
                                    .toString() +
                                " \u{00D7} " +
                                orderJson["order"][index]["quantity"]["25g"]
                                    .toString(),
                            style: new TextStyle(
                                fontSize: 15.0, color: Colors.grey)),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Container(
                          padding: EdgeInsets.only(left: 10, top: 0),
                          child: Text(
                            '\u{20B9} ' +
                                (orderJson["order"][index]["original_price"]
                                            ["25g"] *
                                        orderJson["order"][index]["quantity"]
                                            ["25g"])
                                    .toString(),
                            style: TextStyle(color: Colors.black, fontSize: 20),
                            textAlign: TextAlign.right,
                          )),
                    ])
              ]));
        }
      }
      if (orderJson["order"][index]["quantity"]["50g"] != 0) {
        if (orderJson["order"][index]["fiftyAdded"]) {
        } else {
          orderJson["order"][index]["fiftyAdded"] = true;
          rowList.add(Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * 0.45,
                            child: Text(
                              orderJson["order"][index]["product_name"] +
                                  " " +
                                  "50g",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ]),
                  ],
                ),
                Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.only(
                          left: 10,
                        ),
                        child: Text(
                            orderJson["order"][index]["original_price"]["50g"]
                                    .toString() +
                                " \u{00D7} " +
                                orderJson["order"][index]["quantity"]["50g"]
                                    .toString(),
                            style: new TextStyle(
                                fontSize: 15.0, color: Colors.grey)),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Container(
                          padding: EdgeInsets.only(left: 10, top: 0),
                          child: Text(
                            '\u{20B9} ' +
                                (orderJson["order"][index]["original_price"]
                                            ["50g"] *
                                        orderJson["order"][index]["quantity"]
                                            ["50g"])
                                    .toString(),
                            style: TextStyle(color: Colors.black, fontSize: 20),
                            textAlign: TextAlign.right,
                          )),
                    ])
              ]));
        }
      }
      if (orderJson["order"][index]["quantity"]["100g"] != 0) {
        if (orderJson["order"][index]["hundredAdded"]) {
        } else {
          orderJson["order"][index]["hundredAdded"] = true;
          rowList.add(Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * 0.45,
                            child: Text(
                              orderJson["order"][index]["product_name"] +
                                  " " +
                                  "100g",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ]),
                  ],
                ),
                Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.only(
                          left: 10,
                        ),
                        child: Text(
                            orderJson["order"][index]["original_price"]["100g"]
                                    .toString() +
                                " \u{00D7} " +
                                orderJson["order"][index]["quantity"]["100g"]
                                    .toString(),
                            style: new TextStyle(
                                fontSize: 15.0, color: Colors.grey)),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Container(
                          padding: EdgeInsets.only(left: 10, top: 0),
                          child: Text(
                            '\u{20B9} ' +
                                (orderJson["order"][index]["original_price"]
                                            ["100g"] *
                                        orderJson["order"][index]["quantity"]
                                            ["100g"])
                                    .toString(),
                            style: TextStyle(color: Colors.black, fontSize: 20),
                            textAlign: TextAlign.right,
                          )),
                    ])
              ]));
        }
      }
      if (orderJson["order"][index]["quantity"]["250g"] != 0) {
        if (orderJson["order"][index]["twofiftyAdded"]) {
        } else {
          orderJson["order"][index]["twofiftyAdded"] = true;
          rowList.add(Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * 0.45,
                            child: Text(
                              orderJson["order"][index]["product_name"] +
                                  " " +
                                  "250g",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ]),
                  ],
                ),
                Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.only(
                          left: 10,
                        ),
                        child: Text(
                            orderJson["order"][index]["original_price"]["250g"]
                                    .toString() +
                                " \u{00D7} " +
                                orderJson["order"][index]["quantity"]["250g"]
                                    .toString(),
                            style: new TextStyle(
                                fontSize: 15.0, color: Colors.grey)),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Container(
                          padding: EdgeInsets.only(left: 10, top: 0),
                          child: Text(
                            '\u{20B9} ' +
                                (orderJson["order"][index]["original_price"]
                                            ["250g"] *
                                        orderJson["order"][index]["quantity"]
                                            ["250g"])
                                    .toString(),
                            style: TextStyle(color: Colors.black, fontSize: 20),
                            textAlign: TextAlign.right,
                          )),
                    ])
              ]));
        }
      }
      if (orderJson["order"][index]["quantity"]["500g"] != 0) {
        if (orderJson["order"][index]["fivehundredAdded"]) {
        } else {
          orderJson["order"][index]["fivehundredAdded"] = true;
          rowList.add(Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * 0.45,
                            child: Text(
                              orderJson["order"][index]["product_name"] +
                                  " " +
                                  "500g",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ]),
                  ],
                ),
                Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.only(
                          left: 10,
                        ),
                        child: Text(
                            orderJson["order"][index]["original_price"]["500g"]
                                    .toString() +
                                " \u{00D7} " +
                                orderJson["order"][index]["quantity"]["500g"]
                                    .toString(),
                            style: new TextStyle(
                                fontSize: 15.0, color: Colors.grey)),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Container(
                          padding: EdgeInsets.only(left: 10, top: 0),
                          child: Text(
                            '\u{20B9} ' +
                                (orderJson["order"][index]["original_price"]
                                            ["500g"] *
                                        orderJson["order"][index]["quantity"]
                                            ["500g"])
                                    .toString(),
                            style: TextStyle(color: Colors.black, fontSize: 20),
                            textAlign: TextAlign.right,
                          )),
                    ])
              ]));
        }
      }
      if (orderJson["order"][index]["quantity"]["1kg"] != 0) {
        if (orderJson["order"][index]["kgAdded"]) {
        } else {
          orderJson["order"][index]["kgAdded"] = true;
          rowList.add(Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * 0.45,
                            child: Text(
                              orderJson["order"][index]["product_name"] +
                                  " " +
                                  "1kg",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ]),
                  ],
                ),
                Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.only(
                          left: 10,
                        ),
                        child: Text(
                            orderJson["order"][index]["original_price"]["1kg"]
                                    .toString() +
                                " \u{00D7} " +
                                orderJson["order"][index]["quantity"]["1kg"]
                                    .toString(),
                            style: new TextStyle(
                                fontSize: 15.0, color: Colors.grey)),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Container(
                          padding: EdgeInsets.only(left: 10, top: 0),
                          child: Text(
                            '\u{20B9} ' +
                                (orderJson["order"][index]["original_price"]
                                            ["1kg"] *
                                        orderJson["order"][index]["quantity"]
                                            ["1kg"])
                                    .toString(),
                            style: TextStyle(color: Colors.black, fontSize: 20),
                            textAlign: TextAlign.right,
                          )),
                    ])
              ]));
        }
      }
      if (orderJson["order"][index]["quantity"]["2kg"] != 0) {
        if (orderJson["order"][index]["twokgAdded"]) {
        } else {
          orderJson["order"][index]["twokgAdded"] = true;
          rowList.add(Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * 0.45,
                            child: Text(
                              orderJson["product_name"] + " " + "2kg",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ]),
                  ],
                ),
                Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.only(
                          left: 10,
                        ),
                        child: Text(
                            orderJson["order"][index]["original_price"]["2kg"]
                                    .toString() +
                                " \u{00D7} " +
                                orderJson["order"][index]["quantity"]["2kg"]
                                    .toString(),
                            style: new TextStyle(
                                fontSize: 15.0, color: Colors.grey)),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Container(
                          padding: EdgeInsets.only(left: 10, top: 0),
                          child: Text(
                            '\u{20B9} ' +
                                (orderJson["order"][index]["original_price"]
                                            ["2kg"] *
                                        orderJson["order"][index]["quantity"]
                                            ["2kg"])
                                    .toString(),
                            style: TextStyle(color: Colors.black, fontSize: 20),
                            textAlign: TextAlign.right,
                          )),
                    ])
              ]));
        }
      }

      return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rowList);
    } else if (type == 3) {
      List<Widget> rowList = new List<Widget>();
      if (orderJson["order"][index]["quantity"]["small"] != 0) {
        if (orderJson["order"][index]["smallAdded"]) {
        } else {
          orderJson["smallAdded"] = true;
          rowList.add(Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * 0.45,
                            child: Text(
                              orderJson["order"][index]["product_name"] +
                                  " " +
                                  "SMALL",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ]),
                  ],
                ),
                Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.only(
                          left: 10,
                        ),
                        child: Text(
                            orderJson["order"][index]["original_price"]["small"]
                                    .toString() +
                                " \u{00D7} " +
                                orderJson["order"][index]["quantity"]["small"]
                                    .toString(),
                            style: new TextStyle(
                                fontSize: 15.0, color: Colors.grey)),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Container(
                          padding: EdgeInsets.only(left: 10, top: 0),
                          child: Text(
                            '\u{20B9} ' +
                                (orderJson["order"][index]["original_price"]
                                            ["small"] *
                                        orderJson["order"][index]["quantity"]
                                            ["small"])
                                    .toString(),
                            style: TextStyle(color: Colors.black, fontSize: 20),
                            textAlign: TextAlign.right,
                          )),
                    ])
              ]));
        }
      }
      if (orderJson["order"][index]["quantity"]["medium"] != 0) {
        if (orderJson["order"][index]["mediumAdded"]) {
        } else {
          orderJson["order"][index]["mediumAdded"] = true;
          rowList.add(Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * 0.45,
                            child: Text(
                              orderJson["order"][index]["product_name"] +
                                  " " +
                                  "MEDIUM",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ]),
                  ],
                ),
                Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.only(
                          left: 10,
                        ),
                        child: Text(
                            orderJson["order"][index]["original_price"]
                                        ["medium"]
                                    .toString() +
                                " \u{00D7} " +
                                orderJson["order"][index]["quantity"]["medium"]
                                    .toString(),
                            style: new TextStyle(
                                fontSize: 15.0, color: Colors.grey)),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Container(
                          padding: EdgeInsets.only(left: 10, top: 0),
                          child: Text(
                            '\u{20B9} ' +
                                (orderJson["order"][index]["original_price"]
                                            ["medium"] *
                                        orderJson["order"][index]["quantity"]
                                            ["medium"])
                                    .toString(),
                            style: TextStyle(color: Colors.black, fontSize: 20),
                            textAlign: TextAlign.right,
                          )),
                    ])
              ]));
        }
      }
      if (orderJson["order"][index]["quantity"]["large"] != 0) {
        if (orderJson["order"][index]["largeAdded"]) {
        } else {
          orderJson["largeAdded"] = true;
          rowList.add(Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * 0.45,
                            child: Text(
                              orderJson["order"][index]["product_name"] +
                                  " " +
                                  "LARGE",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ]),
                  ],
                ),
                Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.only(
                          left: 10,
                        ),
                        child: Text(
                            orderJson["order"][index]["original_price"]["large"]
                                    .toString() +
                                " \u{00D7} " +
                                orderJson["order"][index]["quantity"]["large"]
                                    .toString(),
                            style: new TextStyle(
                                fontSize: 15.0, color: Colors.grey)),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Container(
                          padding: EdgeInsets.only(left: 10, top: 0),
                          child: Text(
                            '\u{20B9} ' +
                                (orderJson["order"][index]["original_price"]
                                            ["large"] *
                                        orderJson["order"][index]["quantity"]
                                            ["large"])
                                    .toString(),
                            style: TextStyle(color: Colors.black, fontSize: 20),
                            textAlign: TextAlign.right,
                          )),
                    ])
              ]));
        }
      }
      return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rowList);
    }
  }

  returnStatus() {
    if (orderJson["approved"] &&
        !orderJson["prepared"] &&
        !orderJson["delivered"]) {
      return Container(
          height: 50,
          width: MediaQuery.of(context).size.width,
          color: Colors.green,
          child: Center(
              child: Text(
            'APPROVED',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "AvenirBold",
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          )));
    } else if (orderJson["approved"] &&
        orderJson["prepared"] &&
        orderJson["issued"] &&
        !orderJson["delivered"]) {
      return Column(children: [
        Container(
            height: 50,
            width: MediaQuery.of(context).size.width,
            color: Colors.orange,
            child: Center(
                child: Text(
              'PREPARED',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: "AvenirBold",
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ))),
        Container(
          height: MediaQuery.of(context).size.width,
          width: MediaQuery.of(context).size.width,
          child: MyApp(),
        ),
        SizedBox(
          height: 30,
        ),
      ]);
    } else if (orderJson["approved"] && orderJson["delivered"]) {
      return Container(
          height: 50,
          width: MediaQuery.of(context).size.width,
          color: Colors.indigo[900],
          child: Center(
              child: Text(
            'DELIVERED',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "AvenirBold",
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          )));
    } else if (orderJson["cancelled"]) {
      return Container(
        height: 50,
        width: MediaQuery.of(context).size.width,
        color: Colors.red[900],
        child: Center(
            child: Text(
          'CANCELLED',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: "AvenirBold",
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        )),
      );
    } else {
      return Container(
          height: 50,
          width: MediaQuery.of(context).size.width,
          color: Colors.grey,
          child: Center(
              child: Text(
            'PENDING',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "AvenirBold",
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          )));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        title: Padding(
            padding: const EdgeInsets.only(
              top: 10,
              right: 50,
            ),
            child: Center(
              child: Text(
                'Order Details',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: "AvenirBold",
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )),
        backgroundColor: Color(0xFF0E0038),
      ),
      body: isLoading == false
          ? RefreshIndicator(
              onRefresh: refreshList,
              child: Container(
                  color: Colors.white,
                  child: Column(children: [
                    returnStatus(),
                    ListView.builder(
                        shrinkWrap: true,
                        itemCount: orderJson["order"].length,
                        itemBuilder: (context, index) {
                          return Container(
                              padding:
                                  EdgeInsets.only(top: 10, left: 10, right: 10),
                              child: getContainer(
                                  index, orderJson["order"][index]["type"]));
                        })
                  ])))
          : Center(
              child: Container(
                  margin: EdgeInsets.all(3),
                  child: Image.asset(
                    "assets/images/logoload.gif",
                    width: 48,
                  ))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          refreshList();
        },
        label: Text('Refresh'),
        icon: Icon(Icons.refresh),
        backgroundColor: Color(0xFF0E0038),
      ),
    );
  }
}
