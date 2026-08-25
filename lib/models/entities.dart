class ContactEntities {
  String name;
  String org;
  String des;
  String phone;
  String email;
  String web;

  ContactEntities({
    this.name = '',
    this.org = '',
    this.des = '',
    this.phone = '',
    this.email = '',
    this.web = '',
  });

  factory ContactEntities.fromJson(Map<String, dynamic> json) {
    String pick(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
      return '';
    }

    return ContactEntities(
      name: pick(['NAME', 'name']),
      org: pick(['ORG', 'org', 'ORGANIZATION']),
      des: pick(['DES', 'des', 'DESIGNATION', 'TITLE', 'title']),
      phone: pick(['PHONE', 'phone']),
      email: pick(['EMAIL', 'email']),
      web: pick(['WEB', 'web', 'WEBSITE', 'website']),
    );
  }

  String asCopyText() {
    final lines = <String>[];
    if (name.isNotEmpty) lines.add('Name: $name');
    if (org.isNotEmpty) lines.add('Organization: $org');
    if (des.isNotEmpty) lines.add('Designation: $des');
    if (phone.isNotEmpty) lines.add('Phone: $phone');
    if (email.isNotEmpty) lines.add('Email: $email');
    if (web.isNotEmpty) lines.add('Website: $web');
    return lines.join('\n');
  }

  String toVCard() {
    String escape(String value) {
      return value
          .replaceAll('\\', '\\\\')
          .replaceAll('\r', '')
          .replaceAll('\n', '\\n')
          .replaceAll(';', '\\;')
          .replaceAll(',', '\\,');
    }

    final displayName = name.isEmpty ? 'Unknown' : name;
    final parts = displayName.split(' ');
    final first = parts.isNotEmpty ? parts.first : '';
    final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    final lines = <String>[
      'BEGIN:VCARD',
      'VERSION:3.0',
      'FN:${escape(displayName)}',
      'N:${escape(last)};${escape(first)};;;',
    ];
    if (org.isNotEmpty) lines.add('ORG:${escape(org)}');
    if (des.isNotEmpty) lines.add('TITLE:${escape(des)}');
    for (final p in phone.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty)) {
      lines.add('TEL;TYPE=CELL:${escape(p)}');
    }
    for (final e in email.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty)) {
      lines.add('EMAIL;TYPE=INTERNET:${escape(e)}');
    }
    for (var w in web.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty)) {
      if (!w.startsWith('http://') && !w.startsWith('https://')) {
        w = 'https://$w';
      }
      lines.add('URL:${escape(w)}');
    }
    lines.add('END:VCARD');
    return lines.join('\r\n');
  }
}
