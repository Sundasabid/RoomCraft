import 'strings.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "just now", "N min ago", "N h ago", "yesterday", then "12 Oct".
String editedAgo(DateTime at, DateTime now) {
  final a = at.toLocal(), n = now.toLocal();
  final diff = n.difference(a);
  if (diff.inMinutes < 1) return S.justNow;
  if (diff.inMinutes < 60) return S.minAgo(diff.inMinutes);
  final today = DateTime(n.year, n.month, n.day);
  if (!a.isBefore(today)) return S.hoursAgo(diff.inHours);
  if (!a.isBefore(today.subtract(const Duration(days: 1)))) return S.yesterday;
  return '${a.day} ${_months[a.month - 1]}';
}
