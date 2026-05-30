import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:path_provider/path_provider.dart';

class StorageErrorPage extends StatelessWidget {
  const StorageErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Internal error'),
      ),
      body: Center(
        child: FutureBuilder<Directory>(
          future: getApplicationSupportDirectory(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              final supportDir = snapshot.data;
              final path = supportDir != null ? '$supportDir' : 'Unknown path';
              return GeneralErrorWidget(
                errMsg: 'Storage initialization error \n Current storage location $path \n Try deleting this directory to reset local storage',
                actions: [
                  GeneralErrorButton(
                    onPressed: () {
                      exit(0);
                    },
                    text: 'Exit app',
                  ),
                ],
              );
            } else {
              return const CircularProgressIndicator();
            }
          },
        ),
      ),
    );
  }
}
