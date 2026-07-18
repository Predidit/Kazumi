final RegExp _historySyncDeviceIdPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-'
  r'[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

bool isValidHistorySyncDeviceId(String value) {
  return _historySyncDeviceIdPattern.hasMatch(value);
}

bool isValidHistorySyncEventFileName(String value) {
  const suffix = '.jsonl';
  return value.endsWith(suffix) &&
      isValidHistorySyncDeviceId(
        value.substring(0, value.length - suffix.length),
      );
}

String historySyncEventFileName(String deviceId) {
  if (!isValidHistorySyncDeviceId(deviceId)) {
    throw const FormatException('Invalid history sync device identifier');
  }
  return '$deviceId.jsonl';
}
