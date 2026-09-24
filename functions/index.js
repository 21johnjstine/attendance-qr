const { onSchedule } = require('firebase-functions/scheduler');
const { logger } = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const TZ = 'Asia/Manila';
const ALLOWED_PRESENT_WINDOWS = new Set([10, 20, 30]);
const LATE_WINDOW_MINUTES = 60;
const BATCH_LIMIT = 400;

function formatTime(date) {
  return new Intl.DateTimeFormat('en-GB', {
    timeZone: TZ,
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).format(date);
}

exports.finalizeExpiredAttendanceSessions = onSchedule(
  {
    schedule: 'every 1 minutes',
    timeZone: TZ,
  },
  async () => {
    const now = admin.firestore.Timestamp.now();
    const nowDate = now.toDate();

    const sessionsSnap = await db
      .collection('sessions')
      .where('active', '==', true)
      .get();

    if (sessionsSnap.empty) {
      logger.info('No active attendance sessions found.');
      return;
    }

    const studentsSnap = await db.collection('students').get();
    let finalizedSessions = 0;
    let finalizedStudents = 0;

    for (const sessionDoc of sessionsSnap.docs) {
      const session = sessionDoc.data();
      const sessionId = sessionDoc.id;
      const expiresAt = session.expiresAt;
      const presentWindow = Number(session.presentWindowMinutes);
      const lateWindow = Number(session.lateWindowMinutes);

      if (!expiresAt || expiresAt.toDate() > nowDate) continue;
      if (session.type !== 'attendance_session') continue;
      if (Number(session.version) !== 2) continue;
      if (!ALLOWED_PRESENT_WINDOWS.has(presentWindow)) continue;
      if (lateWindow !== LATE_WINDOW_MINUTES) continue;

      const date = String(session.date || '');
      const program = String(session.program || '');
      const year = String(session.year || '');
      const section = String(session.section || '');

      if (!date || !program || !year || !section) {
        logger.warn(`Skipping incomplete session ${sessionId}.`);
        continue;
      }

      const attendanceSnap = await db
        .collection('attendance')
        .where('date', '==', date)
        .get();

      const loggedStudentIds = new Set(
        attendanceSnap.docs
          .map((doc) => doc.data().studentId)
          .filter((id) => typeof id === 'string' && id.length > 0),
      );

      const candidates = studentsSnap.docs.filter((doc) => {
        const student = doc.data();
        return String(student.program || '') === program &&
          String(student.year || '') === year &&
          String(student.section || '') === section;
      });

      const writes = [];

      for (const studentDoc of candidates) {
        const student = studentDoc.data();
        const studentId = studentDoc.id;

        if (loggedStudentIds.has(studentId)) continue;

        const studentType = String(student.studentType || 'Student');
        const status =
          studentType === 'OJT' || studentType === 'Working Student'
            ? studentType
            : 'Absent';

        const attendanceId = `${studentId}_${sessionId}`;
        writes.push({
          ref: db.collection('attendance').doc(attendanceId),
          data: {
            studentId,
            fullName: student.fullName || '',
            attendanceStatus: status,
            program: student.program || '',
            year: student.year || '',
            section: student.section || '',
            date,
            time: formatTime(nowDate),
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            selfScanned: false,
            sessionId,
            classId: session.classId || '',
            scanMethod: 'session_auto_finalize',
          },
        });
      }

      for (let start = 0; start < writes.length; start += BATCH_LIMIT) {
        const batch = db.batch();
        const end = Math.min(start + BATCH_LIMIT, writes.length);

        for (let i = start; i < end; i++) {
          batch.set(writes[i].ref, writes[i].data);
        }

        batch.update(sessionDoc.ref, {
          active: false,
          finalizedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        await batch.commit();
      }

      if (writes.length === 0) {
        await sessionDoc.ref.update({
          active: false,
          finalizedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      finalizedSessions++;
      finalizedStudents += writes.length;

      logger.info(
        `Finalized session ${sessionId}: ${writes.length} remaining student(s) processed.`,
      );
    }

    logger.info(
      `Session finalization run complete: ${finalizedSessions} session(s), ${finalizedStudents} student record(s).`,
    );
  },
);
