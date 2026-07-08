import '../features/auth/student.dart';
import '../features/classroom/classroom.dart';

const mockStudent = Student(
  name: '李明',
  username: '2024010101',
  studentNo: '2024010101',
);

const mockClassrooms = [
  Classroom(
    id: 1,
    courseNo: '100001',
    courseName: '高等数学',
    lessonName: '第 3 次课',
    code: 'MA2027',
    startTime: '2026-07-10 08:00',
    durationText: '95 分钟',
    status: ClassroomStatus.running,
    focus1Minutes: 50,
    breakMinutes: 5,
    focus2Minutes: 40,
  ),
  Classroom(
    id: 2,
    courseNo: '100002',
    courseName: 'Python 基础',
    lessonName: '第 1 次课',
    code: 'PY2025',
    startTime: '2026-07-06 10:00',
    durationText: '95 分钟',
    status: ClassroomStatus.finished,
    focus1Minutes: 50,
    breakMinutes: 5,
    focus2Minutes: 40,
  ),
  Classroom(
    id: 3,
    courseNo: '100003',
    courseName: '程序设计',
    lessonName: '循环结构',
    code: 'CS6201',
    startTime: '2026-07-05 14:00',
    durationText: '90 分钟',
    status: ClassroomStatus.finished,
    focus1Minutes: 40,
    breakMinutes: 10,
    focus2Minutes: 40,
  ),
];
