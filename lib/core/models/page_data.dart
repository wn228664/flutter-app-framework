// 分页模型：从中性 list/total/pageNum/page/pageSize 契约解码；类型或分页边界错误直接抛出，不猜业务字段。

import 'json_readers.dart';
import 'json_types.dart';

/// 单页数据及分页元信息；T 由调用方解码，fromJson 约束 total 非负、page 与 pageSize 为正。
class PageData<T> {
  /// 接收调用方已验证的分页值；此直接构造器不重复执行 JSON 边界校验。
  /// items：当前页已解码条目，不在构造器内复制列表。
  /// total：全部结果数，调用方直接构造时负责提供非负值。
  /// page：从 1 开始的当前页码。
  /// pageSize：正数分页容量，不表示本页实际条目数。
  const PageData({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  /// 严格解析分页对象；优先 pageNum，其次 page；缺省页码为 1、容量为 20，越界抛 FormatException。
  /// json：包含 list 与分页元信息的响应对象。
  /// decode：将单条 JSON 对象转换成 T，转换异常原样向上传递。
  /// json：decode 每次收到的一条 String 键条目对象。
  factory PageData.fromJson(JsonMap json, T Function(JsonMap json) decode) {
    // total：严格读取的总数，缺失时为 0，负数会被拒绝。
    final total = readInt(json, 'total');
    // page：pageNum 优先、page 回退的页码，缺省 1，必须大于等于 1。
    final page = json['pageNum'] == null
        ? readInt(json, 'page', fallback: 1)
        : readInt(json, 'pageNum', fallback: 1);
    // pageSize：严格整数分页容量，缺失为 20，零和负数会被拒绝。
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

  /// 当前页条目；fromJson 创建不可增长列表，直接构造时沿用传入列表。
  final List<T> items;

  /// 全部匹配结果数，用于调用方计算剩余页数。
  final int total;

  /// 当前页码，fromJson 保证从 1 开始。
  final int page;

  /// 每页容量，fromJson 保证为正整数。
  final int pageSize;
}
