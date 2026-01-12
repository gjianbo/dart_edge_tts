/// 语音信息模型
class EdgeVoice {
  final String name;
  final String shortName;
  final String gender;
  final String locale;
  final String friendlyName;
  final String status;

  EdgeVoice({
    required this.name,
    required this.shortName,
    required this.gender,
    required this.locale,
    required this.friendlyName,
    required this.status,
  });

  factory EdgeVoice.fromJson(Map<String, dynamic> json) {
    return EdgeVoice(
      name: json['Name'] ?? '',
      shortName: json['ShortName'] ?? '',
      gender: json['Gender'] ?? '',
      locale: json['Locale'] ?? '',
      friendlyName: json['FriendlyName'] ?? '',
      status: json['Status'] ?? '',
    );
  }
}
