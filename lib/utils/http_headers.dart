import 'dart:math';

import 'package:kazumi/utils/constants.dart';

final _random = Random();

String getRandomUA() {
  return userAgentsList[_random.nextInt(userAgentsList.length)];
}

String getRandomAcceptedLanguage() {
  return acceptLanguageList[_random.nextInt(acceptLanguageList.length)];
}
