class Device {
  final String name;
  final String platform;
  final String chip;
  final String firmwareVersion;

  final bool connection;

  final String connectionType;
  final String address;

  final int flashSize;
  final int ramUage;

  final double temperature;
  final double cpuUsage;

  const Device({
    required this.name,
    required this.platform,
    required this.chip,
    required this.firmwareVersion,

    required this.connection,

    required this.connectionType,
    required this.address,

    required this.flashSize,
    required this.ramUage,

    required this.temperature,
    required this.cpuUsage,
  });

  Device copyWith(
    String? name,
    String? platform,
    String? chip,
    String? firmwareVersion,

    bool? connection,

    String? connectionType,
    String? address,

    int? flashSize,
    int? ramUage,

    double? temperature,
    double? cpuUsage,
  ) {
    return Device(
      name: name ?? this.name,
      platform: platform ?? this.platform,
      chip: chip ?? this.chip,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,

      connection: connection ?? this.connection,

      connectionType: connectionType ?? this.connectionType,
      address: address ?? this.address,

      flashSize: flashSize ?? this.flashSize,
      ramUage: ramUage ?? this.ramUage,

      temperature: temperature ?? this.temperature,
      cpuUsage: cpuUsage ?? this.cpuUsage,
    );
  }
}
