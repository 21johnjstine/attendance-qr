# Firebase setup for the final build

## Authentication

In Firebase Console:

1. Open **Authentication → Sign-in method**.
2. Enable **Email/Password**.
3. Create each teacher/student login under **Authentication → Users**.
4. Copy each Authentication user's UID.
5. In Firestore, create `users/{UID}` using that exact UID.

### Teacher example

`users/{teacher-auth-uid}`

```text
email: "teacher@example.com"
role: "teacher"
```

### Student example

`users/{student-auth-uid}`

```text
email: "student@example.com"
role: "student"
studentId: "06-2223-033305"
```

The `studentId` field is strongly recommended for deterministic account-to-student linking. The app also falls back to matching `students.email` to the Firebase Auth email if `studentId` is not present.

## Existing student collection

Keep the existing collection:

`students/{studentId}`

The document ID remains the existing student ID. The application reuses the current fields such as:

```text
email
fullName
program
section
studentType
year
```

No second student identity collection is required.

## Attendance sessions

The application creates `sessions/{randomSessionId}` automatically when a teacher generates a Session QR. You do not need to create this collection manually.

The session record contains the random session ID, date, class information, teacher UID, creation time, expiration time, active flag, and default attendance status.

## Firestore rules

The final project contains `firestore.rules`. Review it before publishing and deploy it using your normal Firebase workflow. Do not overwrite production rules blindly if your project has additional collections/rules not represented in this student-project build.
