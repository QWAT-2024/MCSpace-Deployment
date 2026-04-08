import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class FirebaseRecaptchaVerifierModal extends StatefulWidget {
  final Map<String, String> firebaseConfig;
  final String firebaseVersion;
  final bool appVerificationDisabledForTesting;
  final String? languageCode;
  final Function? onLoad;
  final Function? onError;
  final Function(String token) onVerify;
  final Function? onFullChallenge;
  final bool attemptInvisibleVerification;

  FirebaseRecaptchaVerifierModal({
    required this.firebaseConfig,
    this.firebaseVersion = '8.0.0',
    this.appVerificationDisabledForTesting = false,
    this.languageCode,
    this.onLoad,
    this.onError,
    required this.onVerify,
    this.onFullChallenge,
    this.attemptInvisibleVerification = false,
  });

  @override
  State<FirebaseRecaptchaVerifierModal> createState() =>
      _FirebaseRecaptchaVerifierModalState();
}

class _FirebaseRecaptchaVerifierModalState
    extends State<FirebaseRecaptchaVerifierModal> {
  late bool _invisible;

  @override
  void initState() {
    super.initState();
    _invisible = widget.attemptInvisibleVerification;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Verification"),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Opacity(
        opacity: _invisible ? 0 : 1,
        child: FirebaseRecaptchaWidget(
          firebaseConfig: widget.firebaseConfig,
          firebaseVersion: widget.firebaseVersion,
          appVerificationDisabledForTesting:
              widget.appVerificationDisabledForTesting,
          languageCode: widget.languageCode,
          onLoad: () {
            widget.onLoad?.call();
          },
          onError: () {
            widget.onError?.call();
          },
          onVerify: (token) {
            widget.onVerify.call(token);
          },
          onFullChallenge: () {
            if (_invisible) {
              setState(() {
                _invisible = false;
              });
            }
            widget.onFullChallenge?.call();
          },
          invisible: _invisible,
        ),
      ),
    );
  }
}

class FirebaseRecaptchaWidget extends StatelessWidget {
  final Map<String, String> firebaseConfig;
  final String firebaseVersion;
  final bool appVerificationDisabledForTesting;
  final String? languageCode;
  final VoidCallback? onLoad;
  final VoidCallback? onError;
  final Function(String token) onVerify;
  final VoidCallback? onFullChallenge;
  final bool invisible;

  FirebaseRecaptchaWidget({
    required this.firebaseConfig,
    this.firebaseVersion = '8.0.0',
    this.appVerificationDisabledForTesting = false,
    this.languageCode,
    this.onLoad,
    this.onError,
    required this.onVerify,
    this.onFullChallenge,
    this.invisible = false,
  });

  String? get authDomain => firebaseConfig['authDomain'];

  String get html {
    return """
<!DOCTYPE html><html>
<head>
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
  <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">
  <meta name="HandheldFriendly" content="true">
  <script src="https://www.gstatic.com/firebasejs/${firebaseVersion}/firebase-app.js"></script>
  <script src="https://www.gstatic.com/firebasejs/${firebaseVersion}/firebase-auth.js"></script>
  <script type="text/javascript">firebase.initializeApp(${jsonEncode(firebaseConfig)});</script>
  <style>
    html, body {
      height: 100%;
      ${invisible ? 'padding: 0; margin: 0;' : ''}
    }
    #recaptcha-btn {
      width: 100%;
      height: 100%;
      padding: 0;
      margin: 0;
      border: 0;
      user-select: none;
      -webkit-user-select: none;
    }
  </style>
</head>
<body>
  ${invisible ? '<button id="recaptcha-btn" type="button" onclick="onClickButton()">Confirm reCAPTCHA</button>' : '<div id="recaptcha-cont" class="g-recaptcha"></div>'}
  <script>
    var fullChallengeTimer;
    function onVerify(token) {
      if (fullChallengeTimer) {
        clearInterval(fullChallengeTimer);
        fullChallengeTimer = undefined;
      }
      window.flutter_inappwebview.callHandler('verifyHandler', token);
    }
    function onLoad() {
      window.flutter_inappwebview.callHandler('loadHandler');
      firebase.auth().settings.appVerificationDisabledForTesting = ${appVerificationDisabledForTesting};
      ${languageCode != null ? 'firebase.auth().languageCode = \'${languageCode}\';' : ''}
      window.recaptchaVerifier = new firebase.auth.RecaptchaVerifier("${invisible ? 'recaptcha-btn' : 'recaptcha-cont'}", {
        size: "${invisible ? 'invisible' : 'normal'}",
        callback: onVerify
      });
      window.recaptchaVerifier.render();
    }
    function onError() {
      window.flutter_inappwebview.callHandler('errorHandler');
    }
    function onClickButton() {
      if (!fullChallengeTimer) {
        fullChallengeTimer = setInterval(function() {
          var iframes = document.getElementsByTagName("iframe");
          var isFullChallenge = false;
          for (i = 0; i < iframes.length; i++) {
            var parentWindow = iframes[i].parentNode ? iframes[i].parentNode.parentNode : undefined;
            var isHidden = parentWindow && parentWindow.style.opacity == 0;
            isFullChallenge = isFullChallenge || (
              !isHidden && 
              ((iframes[i].title === 'recaptcha challenge') ||
               (iframes[i].src.indexOf('google.com/recaptcha/api2/bframe') >= 0)));
          }
          if (isFullChallenge) {
            clearInterval(fullChallengeTimer);
            fullChallengeTimer = undefined;
            window.flutter_inappwebview.callHandler('fullChallengeHandler');
          }
        }, 100);
      }
    }
    ${invisible ? """
    window.addEventListener('message', function(event) {
      if (event.data === 'recaptcha-setup')
      {
        document.getElementById('recaptcha-btn').click();
      }
    });""" : ''}
  </script>
  <script src="https://www.google.com/recaptcha/api.js?onload=onLoad&render=explicit&hl=${languageCode ?? ''}" onerror="onError()"></script>
</body></html>""";
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialData: InAppWebViewInitialData(
        baseUrl: WebUri("https://${authDomain}"),
        data: html,
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        useHybridComposition: true,
        allowsInlineMediaPlayback: true,
      ),
      onWebViewCreated: (controller) {
        controller.addJavaScriptHandler(
          handlerName: 'verifyHandler',
          callback: (args) => onVerify(args[0]),
        );
        controller.addJavaScriptHandler(
          handlerName: 'loadHandler',
          callback: (args) => onLoad?.call(),
        );
        controller.addJavaScriptHandler(
          handlerName: 'errorHandler',
          callback: (args) => onError?.call(),
        );
        controller.addJavaScriptHandler(
          handlerName: 'fullChallengeHandler',
          callback: (args) => onFullChallenge?.call(),
        );
      },
    );
  }
}
