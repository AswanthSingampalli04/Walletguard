import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'email_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OCRReceiptScreen extends StatefulWidget {
  @override
  _OCRReceiptScreenState createState() => _OCRReceiptScreenState();
}

class _OCRReceiptScreenState extends State<OCRReceiptScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _image;
  bool _isProcessing = false;
  String _extractedText = '';
  String _errorMessage = '';

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
          _extractedText = '';
          _errorMessage = '';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking image: $e';
      });
    }
  }

  Future<void> _extractTextFromImage() async {
    if (_image == null) {
      setState(() {
        _errorMessage = 'Please select an image first';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = '';
      _extractedText = '';
    });

    try {
      // Convert image to base64
      List<int> imageBytes = await _image!.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      // Send to OCR API (assuming your Flask API is running on localhost:5000)
      final response = await http.post(
        Uri.parse('https://nondenotatively-unterse-rickey.ngrok-free.dev/scan_receipt'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'image_base64': base64Image,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        print('🔹 API Response: $result'); // Debug log
        
        if (result['status'] == 'success') {
          setState(() {
            _extractedText = result['text'] ?? 'No text found';
            print('🔹 Extracted Text: $_extractedText'); // Debug log
          });
        } else {
          setState(() {
            _errorMessage = result['message'] ?? 'OCR processing failed';
            print('❌ OCR Error: $_errorMessage'); // Debug log
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Server error: ${response.statusCode} - ${response.body}';
          print('❌ Server Error: ${response.statusCode} - ${response.body}'); // Debug log
        });
      }
    } catch (e) {
      print('❌ Exception Error: $e'); // Debug log
      setState(() {
        _errorMessage = 'Error processing image: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_camera),
                title: Text('Camera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan Receipt (OCR)'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image display area
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _image != null
                  ? Image.file(_image!, fit: BoxFit.cover)
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long, size: 50, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('No image selected', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
            ),
            SizedBox(height: 16),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showImagePicker,
                    icon: Icon(Icons.image),
                    label: Text('Select Image'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _extractTextFromImage,
                    icon: _isProcessing 
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(Icons.text_fields),
                    label: Text(_isProcessing ? 'Processing...' : 'Extract Text'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Error message
            if (_errorMessage.isNotEmpty)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(_errorMessage, style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 16),

            // Debug Information (remove in production)
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.yellow.shade50,
                border: Border.all(color: Colors.yellow.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Debug Info:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                  Text('Processing: $_isProcessing', style: TextStyle(fontSize: 10)),
                  Text('Has Image: ${_image != null}', style: TextStyle(fontSize: 10)),
                  Text('Text Length: ${_extractedText.length}', style: TextStyle(fontSize: 10)),
                  if (_errorMessage.isNotEmpty)
                    Text('Error: $_errorMessage', style: TextStyle(fontSize: 10, color: Colors.red)),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Extracted text
            if (_extractedText.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Extracted Text:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _extractedText.isEmpty ? 'No text found in image' : _extractedText,
                      style: TextStyle(
                        fontSize: 14,
                        color: _extractedText.isEmpty ? Colors.grey : Colors.black,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _extractedText.isNotEmpty ? () {
                            // Copy to clipboard functionality
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Text copied to clipboard')),
                            );
                          } : null,
                          icon: Icon(Icons.copy),
                          label: Text('Copy Text'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _extractedText.isNotEmpty ? _sendEmailWithReceipt : null,
                          icon: Icon(Icons.email),
                          label: Text('Email Receipt'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _sendEmailWithReceipt() async {
    if (_extractedText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No text to send')),
      );
      return;
    }

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        bool success = await EmailService.sendReceiptEmail(
          recipientEmail: user.email!,
          userName: user.displayName ?? 'User',
          extractedText: _extractedText,
          receiptDate: DateTime.now().toString().split(' ')[0],
        );

        if (success) {
          EmailService.showEmailSentDialog(context, 'Receipt has been sent to your email');
        } else {
          EmailService.showEmailErrorDialog(context, 'Failed to send email. Please check your settings.');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User email not found')),
        );
      }
    } catch (e) {
      EmailService.showEmailErrorDialog(context, e.toString());
    }
  }
}
