abstract class BaseSimpleVideoItemModel {
  late String title;
  String? bvid;
  int? cid;
  String? cover;
  int duration = -1;
  late BaseOwner owner;
  late BaseStat stat;
}

abstract class BaseVideoItemModel extends BaseSimpleVideoItemModel {
  int? aid;
  String? desc;
  int? pubdate;
  bool isFollowed = false;
}

abstract class BaseOwner {
  int? mid;
  String? name;
}

abstract class BaseStat {
  int? view;
  int? like;
  int? danmu;
  int? reply;
  num? coin;
  int? favorite;
}

class Stat extends BaseStat {
  Stat.fromJson(Map<String, dynamic> json) {
    view = _readInt(json["view"]);
    like = _readInt(json["like"]);
    danmu = _readInt(json['danmaku']);
    reply = _readInt(json['reply']);
    coin = _readNum(json['coin']);
    favorite = _readInt(json['favorite']);
  }
}

class PlayStat extends BaseStat {
  PlayStat.fromJson(Map<String, dynamic> json) {
    view = _readInt(json['play']);
    danmu = _readInt(json['danmaku']);
  }
}

int? _readInt(Object? value) => switch (value) {
  int value => value,
  num value => value.toInt(),
  String value => int.tryParse(value),
  _ => null,
};

num? _readNum(Object? value) => switch (value) {
  num value => value,
  String value => num.tryParse(value),
  _ => null,
};
