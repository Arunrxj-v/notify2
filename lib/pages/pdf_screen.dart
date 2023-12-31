import 'dart:convert';
import 'dart:io';
import 'dart:developer';


import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notify2/model/chat_model.dart';
import 'package:notify2/constants/api_consts.dart';
import 'package:read_pdf_text/read_pdf_text.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:http/http.dart' as http;

class PdfScreen extends StatefulWidget {
  PdfScreen({super.key});

  @override
  State<PdfScreen> createState() => _PdfScreenState();
}

class _PdfScreenState extends State<PdfScreen> {
  FilePickerResult? result;

  String? fileName;

  PlatformFile? pickedFile;

  bool isLoading = false;

  File? fileToDisplay;

  void pickFile() async {
    try {
      setState(() {
        isLoading = true;
      });
      // String initialDirectory =
      //     await FilePicker.getPlatform().getDirectoryPath();

      // String initialDirectory = await FilePicker.platform.pickFiles().toString();
      // print('${initialDirectory.characters} initialDirectory');
      result = await FilePicker.platform.pickFiles(
        // allowedExtensions: ['pdf']
      );

      if (result != null) {
        fileName = result!.files.first.name;
        pickedFile = result!.files.first;
        fileToDisplay = File(pickedFile!.path.toString());

        print('file name $fileToDisplay');
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print(e);
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text(
        'AI PDF SUMMARIZER',
        style: TextStyle(fontSize: 19, letterSpacing: 3),
      )),
      body: isLoading
          ? const Loading()
          : Column(
              children: [
                if (result == null)
                  const Expanded(
                      child: Center(
                    child: Text(
                      'Click the icon below and add select a pdf file\n to summerise',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20),
                    ),
                  )),
                if (result != null)
                  Expanded(
                    child:
                        // child: Image.file(fileToDisplay!),
                        // SfPdfViewer.file(fileToDisplay!),
                        FutureBuilder<String>(
                      future: getPDFtext(pickedFile!.path.toString()),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Text(snapshot.data.toString());
                        } else if (snapshot.hasError) {
                          return Text('');
                        }
                        return const Loading();
                      },
                    ),
                  ),
              ],
            ),

      floatingActionButton: FloatingActionButton(
        onPressed: pickFile,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class Loading extends StatefulWidget {
  const Loading({super.key});

  @override
  State<Loading> createState() => _LoadingState();
}

class _LoadingState extends State<Loading> {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

Future<String> getPDFtext(String path) async {
  String text = "";

  List<ChatModel>? chat;

  try {
    text = await ReadPdfText.getPDFtext(path);
    String currentModel = "ft:gpt-3.5-turbo-0613:personal::80K3UOD5";

    chat = await sendMessageGPT(message: text, modelId: currentModel);
  } on PlatformException {
    print('Failed to get PDF text.');
  }

  return chat![0].msg;
}

Future<List<ChatModel>> sendMessageGPT(
      {required String message, required String modelId}) async {
    try {
      log("modelId $modelId");
      var response = await http.post(
        Uri.parse("$BASE_URL/chat/completions"),
        headers: {
          'Authorization': 'Bearer $API_KEY',
          "Content-Type": "application/json"
        },
        body: jsonEncode(
          {
            "model": modelId,
            "messages": [
              {
                "role": "user",
                "content": message,
              }
            ]
          },
        ),
      );

      // Map jsonResponse = jsonDecode(response.body);
      Map jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      if (jsonResponse['error'] != null) {
        // print("jsonResponse['error'] ${jsonResponse['error']["message"]}");
        throw HttpException(jsonResponse['error']["message"]);
      }
      List<ChatModel> chatList = [];
      if (jsonResponse["choices"].length > 0) {
        // log("jsonResponse[choices]text ${jsonResponse["choices"][0]["text"]}");
        chatList = List.generate(
          jsonResponse["choices"].length,
          (index) => ChatModel(
            msg: jsonResponse["choices"][index]["message"]["content"],
            chatIndex: 1,
          ),
        );
      }
      // print(chatList[0].msg);
      return chatList;
    } catch (error) {
      log("error $error");
      rethrow;
    }
  }
