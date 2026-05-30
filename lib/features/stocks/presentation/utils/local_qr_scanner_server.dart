import 'dart:io';
import 'dart:async';
import 'dart:convert';

class LocalQrScannerServer {
  HttpServer? _server;
  final StreamController<String> _scannedCodeController = StreamController.broadcast();

  Stream<String> get onCodeScanned => _scannedCodeController.stream;

  Future<String> start() async {
    // Attempt to get a local IP address
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    String ip = '127.0.0.1';
    for (var interface in interfaces) {
      if (interface.name.toLowerCase().contains('wlan') || 
          interface.name.toLowerCase().contains('en') || 
          interface.name.toLowerCase().contains('eth') ||
          interface.name.toLowerCase().contains('wi-fi')) {
        ip = interface.addresses.first.address;
        break;
      }
    }
    
    // Fallback if specific interface name strings not found
    if (ip == '127.0.0.1' && interfaces.isNotEmpty) {
      ip = interfaces.first.addresses.first.address;
    }

    _server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
    print('QR Scanner Server listening on localhost:\${_server!.port}');

    _server!.listen((HttpRequest request) {
      // Handle CORS
      request.response.headers.add('Access-Control-Allow-Origin', '*');
      request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      request.response.headers.add('Access-Control-Allow-Headers', 'Origin, Content-Type');

      if (request.method == 'OPTIONS') {
        request.response
          ..statusCode = HttpStatus.ok
          ..close();
        return;
      }

      if (request.uri.path == '/') {
        request.response
          ..headers.contentType = ContentType.html
          ..write(_htmlContent(ip))
          ..close();
      } else if (request.uri.path == '/scan' && request.method == 'POST') {
        _handleScan(request);
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..close();
      }
    });

    return 'http://$ip:8080';
  }

  Future<void> _handleScan(HttpRequest request) async {
    final content = await utf8.decoder.bind(request).join();
    try {
      final data = jsonDecode(content);
      if (data['code'] != null) {
        _scannedCodeController.add(data['code']);
      }
      request.response
        ..statusCode = HttpStatus.ok
        ..write(jsonEncode({'success': true}))
        ..close();
    } catch (e) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..close();
    }
  }

  void stop() {
    _server?.close();
    _scannedCodeController.close();
  }

  String _htmlContent(String ip) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>POS Scanner</title>
  <script src="https://unpkg.com/html5-qrcode"></script>
  <style>
    body { 
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
      display: flex; 
      flex-direction: column; 
      align-items: center; 
      justify-content: center; 
      height: 100vh; 
      margin: 0; 
      background: #121212; 
      color: #ffffff;
    }
    #reader-container {
      width: 100%;
      max-width: 400px;
      padding: 16px;
      box-sizing: border-box;
      background: #1e1e1e;
      border-radius: 16px;
      box-shadow: 0 8px 32px rgba(0,0,0,0.5);
    }
    #reader { width: 100%; border-radius: 8px; overflow: hidden; }
    h2 { margin-top: 0; margin-bottom: 16px; font-weight: 600; text-align: center; }
    #status { 
      margin-top: 24px; 
      padding: 12px 24px; 
      border-radius: 8px; 
      background: #333; 
      font-size: 16px; 
      text-align: center;
      transition: all 0.3s;
    }
    .success { background: #1b5e20 !important; color: #a5d6a7 !important; }
    .note { margin-top: 24px; font-size: 12px; color: #888; text-align: center; max-width: 300px; }
  </style>
</head>
<body>
  <div id="reader-container">
    <h2>Scan Product QR</h2>
    <div id="reader"></div>
    <div id="fallback-container" style="display: none; text-align: center; margin-top: 16px;">
      <p style="font-size: 13px; margin-bottom: 12px; color: #ffa726;">Live stream blocked on local network.<br>Tap below to take a picture of the QR instead:</p>
      <label for="qr-input-file" style="display: inline-block; padding: 12px 24px; background: #ab47bc; color: white; border-radius: 8px; font-weight: bold; cursor: pointer; box-shadow: 0 4px 12px rgba(0,0,0,0.3);">
        📸 Open Camera
      </label>
      <input type="file" id="qr-input-file" accept="image/*" capture="environment" style="display: none;">
    </div>
  </div>
  <p id="status">Initializing camera...</p>
  
  <p class="note">Make sure you are on the same WiFi network.</p>

  <script>
    const statusEl = document.getElementById('status');
    const fallbackContainer = document.getElementById('fallback-container');
    const fileInput = document.getElementById('qr-input-file');
    const readerEl = document.getElementById('reader');
    const html5QrCode = new Html5Qrcode("reader");

    function processScannedCode(decodedText) {
      statusEl.innerText = 'Found: ' + decodedText;
      statusEl.className = '';
      
      fetch('http://$ip:8080/scan', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({code: decodedText})
      }).then(response => {
        if(response.ok) {
          statusEl.innerText = 'Sent successfully!';
          statusEl.className = 'success';
          setTimeout(() => { 
            statusEl.innerText = 'Ready to scan...'; 
            statusEl.className = '';
            if (fileInput.value) fileInput.value = ''; // clear selection
          }, 3000);
        }
      }).catch(err => {
        statusEl.innerText = 'Network error sending code!';
        statusEl.className = '';
      });
    }
    
    // Slight delay to ensure DOM is fully ready
    setTimeout(() => {
      const config = { fps: 10, qrbox: { width: 250, height: 250 }, aspectRatio: 1.0 };
      
      html5QrCode.start({ facingMode: "environment" }, config,
        processScannedCode,
        (errorMessage) => { 
          // Ignore general read errors
        }
      ).then(() => {
        statusEl.innerText = 'Point camera at QR code';
      }).catch(err => {
        // Fallback for HTTP securely blocking live camera stream (e.g., non-HTTPS)
        console.error(err);
        readerEl.style.display = 'none';
        fallbackContainer.style.display = 'block';
        statusEl.innerText = 'Waiting for manual capture...';
      });
    }, 500);

    fileInput.addEventListener('change', e => {
      if (e.target.files.length == 0) {
        return;
      }
      statusEl.innerText = 'Scanning image...';
      const imageFile = e.target.files[0];
      html5QrCode.scanFile(imageFile, true)
        .then(processScannedCode)
        .catch(err => {
          statusEl.innerText = 'No QR found in image. Try again.';
          if (fileInput.value) fileInput.value = '';
        });
    });
  </script>
</body>
</html>
''';
  }
}
