import 'dart:convert';

/// Job recording (VERSION 2 milestone — model + persistence, UI not wired).
///
/// Stores everything the spec asks for, locally, with no internet required.
/// The V2 UI will drive NEW/START/PAUSE/END and a job-history list.
class JobRecord {
  final DateTime startedAt;
  final DateTime? endedAt;

  final double targetGpa;
  final double avgActualGpa;
  final double avgSpeedMph;
  final double totalGallons;
  final double acresCovered;
  final double distanceFt;
  final double timeSprayingSec;

  final List<String> track; // sampled "lat,lon,speed,heading" points

  const JobRecord({
    required this.startedAt,
    this.endedAt,
    required this.targetGpa,
    required this.avgActualGpa,
    required this.avgSpeedMph,
    required this.totalGallons,
    required this.acresCovered,
    required this.distanceFt,
    required this.timeSprayingSec,
    this.track = const [],
  });

  Map<String, dynamic> toJson() => {
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt?.toIso8601String(),
    'targetGpa': targetGpa,
    'avgActualGpa': avgActualGpa,
    'avgSpeedMph': avgSpeedMph,
    'totalGallons': totalGallons,
    'acresCovered': acresCovered,
    'distanceFt': distanceFt,
    'timeSprayingSec': timeSprayingSec,
    'track': track,
  };

  String encode() => jsonEncode(toJson());
}

/// In-memory job store. On the real device this would be backed by a file or
/// a database; for the prototype the list keeps everything in memory.
class JobLogger {
  final List<JobRecord> _jobs = [];

  List<JobRecord> get jobs => List.unmodifiable(_jobs);

  void add(JobRecord job) => _jobs.add(job);

  void clear() => _jobs.clear();

  /// Serialize all jobs (e.g. for export or a future on-device file).
  String encodeAll() => jsonEncode(_jobs.map((j) => j.toJson()).toList());
}
