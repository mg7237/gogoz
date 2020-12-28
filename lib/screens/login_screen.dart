import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gogoz/utilities/constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flushbar/flushbar.dart';
import 'dart:async';
import 'package:sms_otp_auto_verify/sms_otp_auto_verify.dart';
import '../animations.dart';
import '../mainScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OtpScreen extends StatefulWidget {
  @override
  _OtpScreenState createState() => _OtpScreenState();
}

var title;
var message;
String phoneNumber;
var knoxToken;
var resend = false;

class _OtpScreenState extends State<OtpScreen> {
  int _otpCodeLength = 6;
  bool _isLoadingButton = false;
  bool _enableButton = false;
  String _otpCode = "";

  /// get signature code

  _onSubmitOtp() {
    setState(() {
      _isLoadingButton = !_isLoadingButton;
      _verifyOtpCode();
    });
  }

  _onOtpCallBack(String otpCode, bool isAutofill) {
    setState(() {
      this._otpCode = otpCode;
      if (otpCode.length == _otpCodeLength && isAutofill) {
        _enableButton = false;
        _isLoadingButton = true;
        _verifyOtpCode();
      } else if (otpCode.length == _otpCodeLength && !isAutofill) {
        _enableButton = true;
        _isLoadingButton = false;
      } else {
        _enableButton = false;
      }
    });
  }

  _verifyOtpCode() {
    FocusScope.of(context).requestFocus(new FocusNode());
    Future _performLogin() async {
      Map data = {'phone_number': phoneNumber, 'password': _otpCode};
      String body = json.encode(data);
      http.Response response = await http.post(
        'https://02c8cb08d4e2.ngrok.io/api/auth/login',
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == HttpStatus.ok) {
        var data = jsonDecode(response.body);
        if (data["user"]["is_active"]) {
          knoxToken = data["token"];
          print("knox : " + knoxToken);
          setCredentials();
          gotoMainScreen(context);
        } else {
          title = "Error";
          message = "Permimssion Denied.";
          showInfoFlushbar(context);
        }
      } else if (response.statusCode == HttpStatus.badRequest) {
        title = "Error";
        message = "Incorrect OTP";
        showInfoFlushbar(context);
      } else {
        title = "Error";
        message = "Internal server error.";
        showInfoFlushbar(context);
      }
    }

    _performLogin();

    Timer(Duration(milliseconds: 4000), () {
      setState(() {
        _isLoadingButton = false;
        _enableButton = false;
      });
    });
  }

  Future<void> setCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('phoneNumber', phoneNumber);
    await prefs.setString('knox_token', knoxToken);
    await prefs.setBool('loggedin', true);
    var data = new Map<String, dynamic>();
    data['phone_number'] = phoneNumber;
    await http.post(
      'https://02c8cb08d4e2.ngrok.io/clear_otp',
      body: data,
    );
  }

  Widget _buildResendOTPBtn() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 5.0, horizontal: 0),
      width: double.infinity,
      child: RaisedButton(
        elevation: 0.0,
        onPressed: () {
          resend = true;
          Navigator.pushReplacement(
              context, SlideRightRoute(page: LoginScreen()));
        },
        padding: EdgeInsets.all(15.0),
        color: Colors.transparent,
        child: Text(
          'Resend OTP',
          style: TextStyle(
            color: Colors.red,
            fontSize: 15.0,
            fontWeight: FontWeight.bold,
            fontFamily: 'Avenir',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ));
    return MaterialApp(
      theme: ThemeData.light(),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'Enter OTP',
                  style: TextStyle(
                    color: Colors.red,
                    fontFamily: 'Avenir',
                    fontSize: 40.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'One Time Password will be recieved via SMS.',
                  style: TextStyle(
                    color: Colors.red,
                    fontFamily: 'Avenir',
                    fontSize: 15.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(
                  height: 75.0,
                ),
                TextFieldPin(
                  filled: true,
                  filledColor: Colors.grey[300],
                  codeLength: _otpCodeLength,
                  boxSize: 46,
                  filledAfterTextChange: false,
                  textStyle: TextStyle(fontSize: 16),
                  borderStyle: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.circular(0)),
                  onOtpCallback: (code, isAutofill) =>
                      _onOtpCallBack(code, isAutofill),
                ),
                SizedBox(
                  height: 75,
                ),
                RaisedButton(
                    elevation: 5.0,
                    onPressed: _enableButton ? _onSubmitOtp : null,
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(0.0),
                    ),
                    color: Colors.indigo[900],
                    child: _setUpButtonChild()),
                SizedBox(
                  height: 20,
                ),
                Text("Did not recieve otp?"),
                SizedBox(
                  height: 20,
                ),
                _buildResendOTPBtn(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void gotoMainScreen(BuildContext context) {
    Navigator.pushReplacement(context, SlideRightRoute(page: MainScreen()));
  }

  void showInfoFlushbar(BuildContext context) {
    Flushbar(
      title: title,
      message: message,
      icon: Icon(Icons.info_outline, size: 28, color: Colors.red.shade600),
      duration: Duration(seconds: 5),
      leftBarIndicatorColor: Colors.red.shade600,
    )..show(context);
  }

  Widget _setUpButtonChild() {
    if (_isLoadingButton) {
      return Container(
          width: 30,
          height: 30,
          child: Container(
              margin: EdgeInsets.all(3),
              child: Image.asset(
                "assets/images/logoload.gif",
                width: 48,
              )));
    } else {
      return Text(
        'Verify',
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'Avenir',
          fontSize: 20.0,
          fontWeight: FontWeight.bold,
        ),
      );
    }
  }
}

var deviceToken;

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _textController = TextEditingController();

  var otpsent = false;
  var loading = false;

  void showInfoFlushbar(BuildContext context) {
    Flushbar(
      title: title,
      message: message,
      icon: Icon(Icons.info_outline, size: 28, color: Colors.red.shade600),
      duration: Duration(seconds: 5),
      leftBarIndicatorColor: Colors.red.shade600,
    )..show(context);
  }

  @override
  void initState() {
    if (resend) {
      getDeviceToken();
      _sendOTP();
    }
    super.initState();
  }

  getDeviceToken() async {
    final prefs = await SharedPreferences.getInstance();
    deviceToken = prefs.getString('device_token');
    print(
        "--------------------------------------------------------------------------------------------------------------");
    print("device: " + deviceToken);
  }

  Future _sendOTP() async {
    String signature = await SmsRetrieved.getAppSignature();
    print("signature is: $signature");

    loading = true;
    setState(() {});
    if (!resend) {
      phoneNumber = _textController.text;
    }
    if (phoneNumber.length == 10) {
      var data = new Map<String, dynamic>();
      data['phone_number'] = phoneNumber;
      data['signature'] = signature;
      data['device_token'] = deviceToken;
      print("device: " + deviceToken);

      http.Response response = await http.post(
        'https://02c8cb08d4e2.ngrok.io/checkuser',
        body: data,
      );
      if (response.statusCode == HttpStatus.ok) {
        otpsent = true;
        loading = false;
        setState(() {});
      }
    } else {
      title = "Error";
      message = "Enter 10 digit phone number";
      showInfoFlushbar(context);
      loading = false;
      setState(() {});
    }
  }

  Widget _buildPhoneTF() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Phone number',
          style: kLabelStyle,
        ),
        SizedBox(height: 10.0),
        Container(
          alignment: Alignment.centerLeft,
          decoration: kBoxDecorationStyle2,
          height: 60.0,
          child: TextField(
            controller: _textController,
            keyboardType: TextInputType.number,
            style: TextStyle(
              color: Colors.grey[700],
              fontFamily: 'OpenSans',
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(top: 14.0),
              prefixIcon: Icon(
                Icons.phone_android,
                color: Colors.grey[700],
              ),
              hintText: 'Phone number',
              hintStyle: kHintTextStyle2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSendOTPBtn() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 50),
      width: double.infinity,
      child: RaisedButton(
        elevation: 5.0,
        onPressed: () => _sendOTP(),
        padding: EdgeInsets.all(15.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0.0),
        ),
        color: Colors.indigo[900],
        child: Text(
          'Send OTP',
          style: TextStyle(
            color: Colors.white,
            letterSpacing: 1.5,
            fontSize: 20.0,
            fontWeight: FontWeight.bold,
            fontFamily: 'Avenir',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    getDeviceToken();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ));
    if (loading == true && otpsent == false) {
      return Scaffold(
        backgroundColor: Color(0xFF0E0038),
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Stack(
              children: <Widget>[
                Container(
                  height: MediaQuery.of(context).size.height,
                  width: double.infinity,
                  decoration: BoxDecoration(color: Colors.white),
                ),
                Container(
                  height: MediaQuery.of(context).size.height - 30,
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: 40.0,
                      vertical: 90.0,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        SizedBox(
                          height: 100.0,
                        ),
                        Center(
                            child: Container(
                                margin: EdgeInsets.all(3),
                                child: Image.asset(
                                  "assets/images/logoload.gif",
                                  width: 48,
                                ))),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      );
    } else if (loading == false && otpsent == false) {
      return Scaffold(
        backgroundColor: Color(0xFF0E0038),
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Stack(
              children: <Widget>[
                Container(
                  height: MediaQuery.of(context).size.height,
                  width: double.infinity,
                  decoration: BoxDecoration(color: Colors.white),
                ),
                Container(
                  height: MediaQuery.of(context).size.height - 30,
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: 40.0,
                      vertical: 90.0,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          'Sign In',
                          style: TextStyle(
                            color: Colors.red,
                            fontFamily: 'Avenir',
                            fontSize: 40.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 30.0),
                        _buildPhoneTF(),
                        SizedBox(
                          height: 50.0,
                        ),
                        _buildSendOTPBtn(),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      );
    } else if (otpsent == true) {
      return OtpScreen();
    }
  }
}
