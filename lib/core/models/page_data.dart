import 'json_readers.dart';
import 'json_types.dart';

class PageData<T> {
  const PageData({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });
  factory PageData.fromJson(JsonMap json, T Function(JsonMap json) decode) {
    final total = readInt(json, 'total');
    final page = json['pageNum'] == null
        ? readInt(json, 'page', fallback: 1)
        : readInt(json, 'pageNum', fallback: 1);
    final pageSize = readInt(json, 'pageSize', fallback: 20);
    if (total < 0 || page < 1 || pageSize < 1) {
      throw const FormatException('Invalid pagination bounds');
    }
    return PageData(
      items: readMapList(json, 'list').map(decode).toList(growable: false),
      total: total,
      page: page,
      pageSize: pageSize,
    );
  }
  final List<T> items;
  final int total;
  final int page;
  final int pageSize;
}
