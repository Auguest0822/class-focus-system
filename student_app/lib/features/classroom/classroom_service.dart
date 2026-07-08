import '../../core/api_client.dart';
import 'app_usage.dart';
import 'classroom.dart';

class ClassroomService {
  ClassroomService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<Classroom>> getClassrooms() async {
    final data = await _apiClient.get('/student/classrooms') as List<dynamic>;
    return data
        .map((item) => Classroom.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Classroom> joinClassroom(String code) async {
    final data =
        await _apiClient.post(
              '/student/classrooms/join',
              data: {'code': code.trim().toUpperCase()},
            )
            as Map<String, dynamic>;
    return Classroom.fromJson(data);
  }

  Future<int> uploadUsageRecords({
    required int classroomId,
    required List<AppUsageRecord> records,
  }) async {
    final data = await _apiClient.post(
      '/student/usages',
      data: {
        'classroom_id': classroomId,
        'records': records.map((item) => item.toJson()).toList(),
      },
    );
    return data as int? ?? 0;
  }

  Future<List<AppUsageInfo>> getUsageRecords(int classroomId) async {
    final data =
        await _apiClient.get('/student/classrooms/$classroomId/usages')
            as List<dynamic>;
    return data
        .map((item) => AppUsageInfo.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ClassroomReport> getClassroomReport(int classroomId) async {
    final data =
        await _apiClient.get('/report/classrooms/$classroomId')
            as Map<String, dynamic>;
    return ClassroomReport.fromJson(data);
  }
}
