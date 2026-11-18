import 'package:intl/intl.dart';

import '../../models/live_tv.dart';
import '../../models/xmltv_epg.dart';

/// Maps XMLTV ids to IPTV channels only through an explicit `tvg-id` match.
/// No fuzzy name matching is performed.
class XmlTvEpgMapper {
  const XmlTvEpgMapper._();

  static List<Channel> enrichChannels(
    List<Channel> channels,
    List<XmlTvGuide> guides, {
    DateTime? at,
  }) {
    if (guides.isEmpty) return channels;
    final instant = (at ?? DateTime.now()).toUtc();
    return channels
        .map((channel) {
          final tvgId = channel.tvgId?.trim();
          if (tvgId == null || tvgId.isEmpty) return channel;
          final programmes = guides
              .expand((guide) => guide.programmes)
              .where((programme) => programme.channelId == tvgId)
              .toList(growable: false);
          XmlTvProgramme? now;
          XmlTvProgramme? next;
          for (final programme in programmes) {
            if (!programme.startUtc.isAfter(instant) &&
                programme.stopUtc.isAfter(instant)) {
              if (now == null || programme.startUtc.isAfter(now.startUtc)) {
                now = programme;
              }
            } else if (programme.startUtc.isAfter(instant) &&
                (next == null || programme.startUtc.isBefore(next.startUtc))) {
              next = programme;
            }
          }
          return channel.copyWith(nowPlaying: now?.title, nextUp: next?.title);
        })
        .toList(growable: false);
  }

  /// Converts only explicitly matched XMLTV programmes into the legacy guide
  /// shape consumed by the existing Mobile/TV schedule views.
  static DaddyLiveEpg toLegacyGuide(
    List<Channel> channels,
    List<XmlTvGuide> guides,
  ) {
    if (channels.isEmpty || guides.isEmpty) {
      return const DaddyLiveEpg(timezone: 'UTC', days: <DaddyLiveEpgDay>[]);
    }
    final channelsByTvgId = <String, List<Channel>>{};
    for (final channel in channels) {
      final id = channel.tvgId?.trim();
      if (id == null || id.isEmpty) continue;
      channelsByTvgId.putIfAbsent(id, () => <Channel>[]).add(channel);
    }

    final eventBuckets = <String, _XmlTvDayBucket>{};
    for (final guide in guides) {
      for (final programme in guide.programmes) {
        final matchedChannels = channelsByTvgId[programme.channelId];
        if (matchedChannels == null || matchedChannels.isEmpty) continue;
        final localStart = programme.startUtc.toLocal();
        final dayKey = DateFormat('yyyy-MM-dd').format(localStart);
        final dayLabel = DateFormat.yMMMd().format(localStart);
        final categoryNames = programme.categories.isEmpty
            ? const <String>['General']
            : programme.categories.take(8).toList(growable: false);
        final eventIdentity = <String>[
          programme.startUtc.toIso8601String(),
          programme.stopUtc.toIso8601String(),
          programme.title,
          matchedChannels.map((channel) => channel.id).join(','),
        ].join('|');
        final bucket = eventBuckets.putIfAbsent(
          dayKey,
          () => _XmlTvDayBucket(dayLabel),
        );
        for (final category in categoryNames) {
          final events = bucket.categories.putIfAbsent(
            category,
            () => <String, DaddyLiveEpgEvent>{},
          );
          events.putIfAbsent(
            eventIdentity,
            () => DaddyLiveEpgEvent(
              time: DateFormat.jm().format(localStart),
              title: programme.title,
              startsAt: programme.startUtc,
              channels: matchedChannels,
            ),
          );
        }
      }
    }

    final dayEntries = eventBuckets.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final days = dayEntries
        .map((entry) {
          final categories = entry.value.categories.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key));
          return DaddyLiveEpgDay(
            label: entry.value.label,
            categories: categories
                .map(
                  (category) => DaddyLiveEpgCategory(
                    name: category.key,
                    events: category.value.values.toList()
                      ..sort((a, b) => a.startsAt!.compareTo(b.startsAt!)),
                  ),
                )
                .toList(growable: false),
          );
        })
        .toList(growable: false);
    return DaddyLiveEpg(timezone: 'Device local time', days: days);
  }
}

class _XmlTvDayBucket {
  _XmlTvDayBucket(this.label);

  final String label;
  final Map<String, Map<String, DaddyLiveEpgEvent>> categories =
      <String, Map<String, DaddyLiveEpgEvent>>{};
}
