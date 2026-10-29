/**
 * Seed script for the SEB Clone database.
 *
 *   npm run seed          -> seeds only if every collection is empty
 *   npm run seed:reset    -> wipes the collections owned by this app, then seeds
 *
 * Mock data is deterministic (seeded PRNG); exam dates are relative to the run time.
 */
const mongoose = require('mongoose');
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const config = require('../config');
const M = require('../models');
const QUESTION_DATA = require('./question-data');

const DEFAULT_PASSWORD = 'Password@123';
const EXIT_PIN = '654321';

// ---------------------------------------------------------------- helpers
function mulberry32(seed) {
  let a = seed;
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rnd = mulberry32(20261029);
const pick = (arr) => arr[Math.floor(rnd() * arr.length)];
const oid = () => new mongoose.Types.ObjectId();
const round2 = (n) => Math.round(n * 100) / 100;

const NOW = new Date();
const MIN = 60 * 1000;
const DAY = 24 * 60 * MIN;
const at = (offsetMs) => new Date(NOW.getTime() + offsetMs);
const minAgo = (n) => at(-n * MIN);
const daysAgo = (n) => at(-n * DAY);
const daysAhead = (n) => at(n * DAY);

// ---------------------------------------------------------------- static data
const STUDENT_NAMES = [
  'Nguyễn Minh Khôi', 'Trần Thị Thu Hà', 'Lê Quốc Bảo', 'Phạm Ngọc Anh', 'Hoàng Gia Huy',
  'Võ Thị Mai Linh', 'Đặng Anh Tuấn', 'Bùi Thanh Tâm', 'Đỗ Hoài Nam', 'Huỳnh Đức Thịnh',
  'Ngô Thị Kim Ngân', 'Dương Văn Hiếu', 'Lý Bảo Châu', 'Phan Hữu Phước', 'Trương Thị Diễm My',
  'Vũ Minh Quân', 'Đinh Công Thành', 'Mai Thị Phương Thảo', 'Tạ Quang Vinh', 'Lâm Gia Hân',
  'Cao Văn Toàn', 'Hồ Thị Ngọc Diệp', 'Nguyễn Hải Đăng', 'Trần Đình Khang', 'Lê Thị Yến Nhi',
  'Phạm Quốc Việt', 'Hoàng Thị Bích Trâm', 'Võ Thanh Sơn', 'Đặng Thị Hồng Nhung', 'Bùi Tuấn Kiệt'
];

const CHAPTER_TITLES = {
  PRM393: ['Dart Fundamentals', 'Flutter Widgets & Layout', 'State Management', 'Navigation & Routing', 'Networking & Persistence'],
  DBI202: ['Relational Model & ER Design', 'SQL Basics (DDL/DML)', 'Joins & Subqueries', 'Normalization', 'Transactions & Indexing'],
  PRN231: ['C# & .NET Core Basics', 'ASP.NET Core Web API', 'Entity Framework Core', 'Authentication & Security'],
  CSD201: ['Arrays & Linked Lists', 'Stacks & Queues', 'Trees', 'Sorting & Searching'],
  MAD101: ['Logic & Proofs', 'Sets & Relations', 'Graph Theory']
};

const ESSAY_ANSWERS = [
  'setState rebuilds only the widget subtree that owns the state and is ideal for small, local UI state. Provider exposes a ChangeNotifier higher in the tree so many widgets can listen to it, which suits shared state such as the logged-in user or the exam timer.',
  'I would store answers in a local SQLite table with a synced flag, write every change immediately, and push unsynced rows in batches when connectivity returns. Conflicts are resolved by keeping the newest client timestamp because only the student edits their own answers.',
  'The table violates 2NF because CustomerName and CustomerPhone depend only on the order, and ProductName depends only on ProductID. Splitting into Orders, Customers, Products and OrderDetails removes the partial and transitive dependencies and reaches 3NF.',
  'A non-clustered index is a separate B-tree storing key values with row locators, so the engine can seek instead of scanning the table. Too many indexes slow down INSERT/UPDATE/DELETE because every index must be maintained, and they consume extra storage.',
  'Eager loading uses Include to fetch related data in the same query, lazy loading fetches it on first access through proxies, and explicit loading uses Entry().Collection().Load() on demand. Eager avoids N+1 queries while lazy can cause them.'
];

const DEVICES = [
  'Samsung Galaxy A34 / Android 14',
  'Xiaomi Redmi Note 12 / Android 13',
  'Google Pixel 6 / Android 14',
  'OPPO Reno8 / Android 13',
  'Realme C55 / Android 13'
];

const VIOLATION_DETAILS = {
  SCREEN_FOCUS_LOST: 'Screen focus lost for 4s',
  APP_MINIMIZED: 'App moved to background (Home button)',
  BLOCKED_SHORTCUT: 'Blocked shortcut: Recent Apps',
  SCREENSHOT_ATTEMPT: 'Screenshot attempt blocked (FLAG_SECURE)',
  FORCE_CLOSE: 'App force-closed, session recovered after restart'
};
const COMMON_VIOLATIONS = ['SCREEN_FOCUS_LOST', 'APP_MINIMIZED', 'BLOCKED_SHORTCUT'];

// ---------------------------------------------------------------- main
async function main() {
  const reset = process.argv.includes('--reset');
  await mongoose.connect(config.mongoUri);
  console.log(`Connected: ${mongoose.connection.host} / db "${mongoose.connection.name}"`);

  const models = Object.values(M);
  const counts = await Promise.all(
    models.map(async (m) => [m.collection.name, await m.estimatedDocumentCount()])
  );
  const nonEmpty = counts.filter(([, c]) => c > 0);
  if (nonEmpty.length && !reset) {
    console.error('Database already contains data, refusing to seed:');
    nonEmpty.forEach(([n, c]) => console.error(`  ${n}: ${c} documents`));
    console.error('Run "npm run seed:reset" to wipe these collections and seed again.');
    await mongoose.disconnect();
    process.exit(1);
  }
  if (reset) {
    for (const m of models) await m.deleteMany({});
    console.log('Existing documents removed (--reset).');
  }
  for (const m of models) {
    await m.createCollection().catch(() => {});
    await m.syncIndexes();
  }

  const passwordHash = bcrypt.hashSync(DEFAULT_PASSWORD, 10);
  const exitPinHash = bcrypt.hashSync(EXIT_PIN, 10);

  // ------------------------------------------------ departments
  const departments = [
    { _id: oid(), department_code: 'SE', department_name: 'Software Engineering' },
    { _id: oid(), department_code: 'AI', department_name: 'Artificial Intelligence' },
    { _id: oid(), department_code: 'IA', department_name: 'Information Assurance' }
  ];
  const dept = Object.fromEntries(departments.map((d) => [d.department_code, d]));

  // ------------------------------------------------ users
  const mkUser = (code, name, role, deptDoc, status = 'ACTIVE', createdDaysAgo = 150) => ({
    _id: oid(),
    user_code: code,
    email: `${code.toLowerCase()}@seb.edu.vn`,
    password_hash: passwordHash,
    full_name: name,
    role,
    department_id: deptDoc ? deptDoc._id : null,
    status,
    created_at: daysAgo(createdDaysAgo)
  });

  const admin = mkUser('AD001', 'System Administrator', 'ADMIN', null, 'ACTIVE', 200);
  const hos = {
    HOS001: mkUser('HOS001', 'Hoàng Thị Lan', 'HEAD_OF_SUBJECT', dept.SE, 'ACTIVE', 180),
    HOS002: mkUser('HOS002', 'Bùi Quang Minh', 'HEAD_OF_SUBJECT', dept.SE, 'ACTIVE', 180)
  };
  const lecturers = [
    mkUser('LEC001', 'Nguyễn Văn An', 'LECTURER', dept.SE),
    mkUser('LEC002', 'Trần Thị Bích', 'LECTURER', dept.SE),
    mkUser('LEC003', 'Lê Hoàng Cường', 'LECTURER', dept.SE),
    mkUser('LEC004', 'Phạm Minh Đức', 'LECTURER', dept.SE),
    mkUser('LEC005', 'Võ Thanh Hà', 'LECTURER', dept.AI),
    mkUser('LEC006', 'Đặng Quốc Huy', 'LECTURER', dept.IA, 'INACTIVE', 140)
  ];
  const lec = Object.fromEntries(lecturers.map((l) => [l.user_code, l]));
  const students = STUDENT_NAMES.map((name, i) =>
    mkUser(`SE18${String(i + 1).padStart(4, '0')}`, name, 'STUDENT', dept.SE, i === 28 ? 'INACTIVE' : 'ACTIVE', 60)
  );
  const users = [admin, ...Object.values(hos), ...lecturers, ...students];

  // ------------------------------------------------ system configs
  const cfgRows = [
    ['MAX_LOGIN_ATTEMPTS', '5', 'Failed logins before the account is temporarily locked'],
    ['MAX_VIOLATIONS', '3', 'Violations allowed before the exam is terminated (BR_SEC_04)'],
    ['QR_REFRESH_SECONDS', '30', 'Dynamic QR code refresh interval'],
    ['ACCESS_PIN_LENGTH', '6', 'Length of the exam access PIN and proctor exit PIN'],
    ['MAX_IMPORT_FILE_MB', '10', 'Maximum size of user import files (.xlsx/.csv)'],
    ['AUTOSAVE_INTERVAL_SECONDS', '15', 'Interval between answer autosaves on the mobile app'],
    ['EXIT_AUTH_METHODS', 'PIN,NFC', 'Allowed proctor authentication methods for emergency exit'],
    ['BLOCK_ROOTED_DEVICES', 'true', 'Reject login from rooted / jailbroken devices'],
    ['DEFAULT_PASS_PERCENTAGE', '50', 'Default minimum percentage required to pass an exam']
  ];
  const systemConfigs = cfgRows.map(([config_key, config_value, description]) => ({
    config_key, config_value, description, updated_by: admin._id, updated_at: daysAgo(60)
  }));

  // ------------------------------------------------ subjects + chapters
  const subjectDefs = [
    ['PRM393', 'Mobile Programming', 'Cross-platform mobile development with Flutter.', true, 'SE', 'ACTIVE', 'HOS001'],
    ['DBI202', 'Database Systems', 'Relational databases, SQL and normalization.', true, 'SE', 'ACTIVE', 'HOS002'],
    ['PRN231', 'Building Cross-Platform Back-End Applications With .NET', 'ASP.NET Core Web API and Entity Framework Core.', true, 'SE', 'ACTIVE', 'HOS001'],
    ['CSD201', 'Data Structures and Algorithms', 'Core data structures, trees and sorting.', true, 'SE', 'ACTIVE', 'HOS002'],
    ['MAD101', 'Discrete Mathematics', 'Logic, sets, relations and graphs.', false, 'IA', 'INACTIVE', 'HOS002']
  ];
  const subjects = subjectDefs.map(([code, name, description, auto, deptCode, status, owner]) => ({
    _id: oid(),
    subject_code: code,
    subject_name: name,
    description,
    allow_auto_grading: auto,
    status,
    department_id: dept[deptCode]._id,
    created_by: hos[owner]._id,
    created_at: daysAgo(170)
  }));
  const subj = Object.fromEntries(subjects.map((s) => [s.subject_code, s]));

  const chapters = [];
  const chap = {}; // chap[subjectCode][chapterNo] -> doc
  for (const [code, titles] of Object.entries(CHAPTER_TITLES)) {
    chap[code] = {};
    titles.forEach((title, i) => {
      const doc = { _id: oid(), subject_id: subj[code]._id, chapter_number: i + 1, chapter_title: title, created_at: daysAgo(170) };
      chapters.push(doc);
      chap[code][i + 1] = doc;
    });
  }

  // ------------------------------------------------ subject access (F18, F19)
  const mkAccess = (subjectCode, lecCode, grant, status, approver, createdDaysAgo) => ({
    _id: oid(),
    subject_id: subj[subjectCode]._id,
    lecturer_id: lec[lecCode]._id,
    grant_type: grant,
    status,
    approved_by: approver ? hos[approver]._id : null,
    created_at: daysAgo(createdDaysAgo)
  });
  const subjectAccess = [
    mkAccess('PRM393', 'LEC001', 'REQUEST', 'APPROVED', 'HOS001', 90),
    mkAccess('PRM393', 'LEC002', 'REQUEST', 'APPROVED', 'HOS001', 90),
    mkAccess('DBI202', 'LEC003', 'REQUEST', 'APPROVED', 'HOS002', 88),
    mkAccess('DBI202', 'LEC004', 'REQUEST', 'APPROVED', 'HOS002', 88),
    mkAccess('CSD201', 'LEC004', 'REQUEST', 'APPROVED', 'HOS002', 85),
    mkAccess('PRN231', 'LEC005', 'REQUEST', 'APPROVED', 'HOS001', 85),
    mkAccess('DBI202', 'LEC001', 'REQUEST', 'PENDING', null, 1),
    mkAccess('PRN231', 'LEC002', 'REQUEST', 'PENDING', null, 0.2),
    mkAccess('PRM393', 'LEC003', 'REQUEST', 'PENDING', null, 2),
    mkAccess('CSD201', 'LEC005', 'REQUEST', 'REJECTED', 'HOS002', 5),
    mkAccess('PRN231', 'LEC004', 'INVITATION', 'PENDING', null, 2)
  ];

  // ------------------------------------------------ classes + enrollments
  const classDefs = [
    ['PRM393_SE1801', 'PRM393', 'LEC001', 0, 14],
    ['PRM393_SE1802', 'PRM393', 'LEC002', 15, 29],
    ['DBI202_SE1801', 'DBI202', 'LEC003', 0, 14],
    ['DBI202_SE1802', 'DBI202', 'LEC004', 15, 29],
    ['PRN231_SE1803', 'PRN231', 'LEC005', 5, 24],
    ['CSD201_SE1801', 'CSD201', 'LEC004', 0, 14]
  ];
  const classes = [];
  const enrollments = [];
  const cls = {};
  for (const [classCode, subjectCode, lecCode, from, to] of classDefs) {
    const doc = {
      _id: oid(), class_code: classCode, subject_id: subj[subjectCode]._id,
      lecturer_id: lec[lecCode]._id, semester: 'FA26', created_at: daysAgo(75)
    };
    classes.push(doc);
    cls[classCode] = { doc, from, to };
    for (let i = from; i <= to; i++) {
      enrollments.push({ _id: oid(), class_id: doc._id, student_id: students[i]._id, created_at: daysAgo(70) });
    }
  }

  // ------------------------------------------------ questions + options (F16, F17)
  const questions = [];
  const questionOptions = [];
  const bank = {}; // bank[subjectCode] = { mcq: [{q, options}], essay: [{q, options: []}] }
  for (const [code, def] of Object.entries(QUESTION_DATA)) {
    bank[code] = { mcq: [], essay: [] };
    let n = 0;
    const base = (extra) => ({
      _id: oid(),
      subject_id: subj[code]._id,
      created_by: hos[def.owner]._id,
      question_code: `${def.prefix}-${String(++n).padStart(3, '0')}`,
      is_public: true,
      created_at: daysAgo(120),
      ...extra
    });
    for (const [chNo, diff, content, opts, correct] of def.mcq) {
      const q = base({
        chapter_id: chap[code][chNo]._id,
        question_type: 'MULTIPLE_CHOICE',
        difficulty_level: diff,
        content,
        description: '',
        learning_outcome: `LO${chNo}`,
        default_score: 1
      });
      const options = opts.map((text, i) => ({
        _id: oid(), question_id: q._id, option_content: text, is_correct: i === correct,
        hint: i === correct ? `See chapter ${chNo}: ${CHAPTER_TITLES[code][chNo - 1]}` : null,
        created_at: daysAgo(120)
      }));
      questions.push(q);
      questionOptions.push(...options);
      bank[code].mcq.push({ q, options });
    }
    for (const [chNo, diff, score, content] of def.essay) {
      const q = base({
        chapter_id: chap[code][chNo]._id,
        question_type: 'ESSAY',
        difficulty_level: diff,
        content,
        description: 'Answer in 5-8 sentences.',
        learning_outcome: `LO${chNo}`,
        default_score: score
      });
      questions.push(q);
      bank[code].essay.push({ q, options: [] });
    }
  }

  // ------------------------------------------------ exams (F21-F27)
  const venue = {
    venue_name: 'FPT University HCMC - Lab Building',
    venue_latitude: 10.8411,
    venue_longitude: 106.8099,
    venue_radius_meters: 300
  };
  const mkExam = (o) => {
    const secured = o.status !== 'DRAFT';
    return {
      _id: oid(),
      class_id: cls[o.classCode].doc._id,
      subject_id: subj[o.subjectCode]._id,
      created_by: lec[o.lecCode]._id,
      exam_title: o.title,
      description: o.description,
      importance_level: o.importance,
      start_time: o.start,
      end_time: o.end,
      duration_minutes: o.duration,
      mcq_grading_method: 'AUTO',
      min_pass_percentage: 50,
      question_source_mode: o.source,
      mcq_weight_percent: o.mcqWeight,
      essay_weight_percent: 100 - o.mcqWeight,
      shuffle_questions: true,
      shuffle_options: o.shuffleOptions !== false,
      max_violations: 3,
      access_pin: secured ? o.pin : null,
      exit_pin_hash: secured ? exitPinHash : null,
      qr_secret: secured ? crypto.randomBytes(16).toString('hex') : null,
      qr_refresh_seconds: 30,
      ...venue,
      url_whitelist: ['https://lms.seb.edu.vn', 'https://fap.seb.edu.vn'],
      status: o.status,
      created_at: new Date(o.start.getTime() - 7 * DAY)
    };
  };

  const exams = {
    E1: mkExam({
      title: 'PRM393 - Progress Test 1', description: 'Chapters 1-3. Closed book, 30 minutes.',
      classCode: 'PRM393_SE1801', subjectCode: 'PRM393', lecCode: 'LEC001', importance: 1,
      start: daysAgo(14), end: new Date(daysAgo(14).getTime() + 3 * 60 * MIN), duration: 30,
      source: 'FIXED', mcqWeight: 100, status: 'COMPLETED', pin: '112233'
    }),
    E2: mkExam({
      title: 'PRM393 - Midterm Exam', description: 'Chapters 1-5. 10 multiple choice + 2 essays. Exam window stays open for testing.',
      classCode: 'PRM393_SE1802', subjectCode: 'PRM393', lecCode: 'LEC002', importance: 2,
      start: minAgo(60), end: daysAhead(7), duration: 60,
      source: 'FIXED', mcqWeight: 80, status: 'ONGOING', pin: '123456'
    }),
    E3: mkExam({
      title: 'DBI202 - Midterm Exam', description: 'Randomized from the master question bank by chapter and difficulty.',
      classCode: 'DBI202_SE1801', subjectCode: 'DBI202', lecCode: 'LEC003', importance: 2,
      start: daysAhead(1), end: new Date(daysAhead(1).getTime() + 2 * 60 * MIN), duration: 60,
      source: 'RANDOM', mcqWeight: 80, status: 'SCHEDULED', pin: '482915'
    }),
    E4: mkExam({
      title: 'DBI202 - Quiz 1', description: 'Chapters 1-5 quiz.',
      classCode: 'DBI202_SE1802', subjectCode: 'DBI202', lecCode: 'LEC004', importance: 1,
      start: daysAgo(30), end: new Date(daysAgo(30).getTime() + 2 * 60 * MIN), duration: 45,
      source: 'FIXED', mcqWeight: 80, status: 'COMPLETED', pin: '778899'
    }),
    E5: mkExam({
      title: 'PRN231 - Practical Quiz', description: 'Draft - question rules not finalized yet.',
      classCode: 'PRN231_SE1803', subjectCode: 'PRN231', lecCode: 'LEC005', importance: 1,
      start: daysAhead(10), end: new Date(daysAhead(10).getTime() + 2 * 60 * MIN), duration: 45,
      source: 'RANDOM', mcqWeight: 70, status: 'DRAFT', pin: null
    })
  };

  // fixed question lists (F22) and random rules
  const examQuestionsByExam = {
    E1: bank.PRM393.mcq.slice(0, 10),
    E2: [...bank.PRM393.mcq.slice(4, 14), ...bank.PRM393.essay],
    E4: [...[0, 2, 3, 4, 5, 8, 10, 11].map((i) => bank.DBI202.mcq[i]), ...bank.DBI202.essay]
  };
  const examQuestions = [];
  for (const [key, list] of Object.entries(examQuestionsByExam)) {
    list.forEach((item) => examQuestions.push({ _id: oid(), exam_id: exams[key]._id, question_id: item.q._id, created_at: exams[key].created_at }));
  }

  const ruleRows = [
    ['E3', 'DBI202', 1, 'MULTIPLE_CHOICE', 'EASY', 2],
    ['E3', 'DBI202', 2, 'MULTIPLE_CHOICE', 'EASY', 2],
    ['E3', 'DBI202', 2, 'MULTIPLE_CHOICE', 'MEDIUM', 1],
    ['E3', 'DBI202', 3, 'MULTIPLE_CHOICE', 'MEDIUM', 2],
    ['E3', 'DBI202', 3, 'MULTIPLE_CHOICE', 'HARD', 1],
    ['E3', 'DBI202', 4, 'ESSAY', 'MEDIUM', 1],
    ['E3', 'DBI202', 5, 'ESSAY', 'HARD', 1],
    ['E5', 'PRN231', 2, 'MULTIPLE_CHOICE', 'EASY', 1],
    ['E5', 'PRN231', 2, 'MULTIPLE_CHOICE', 'MEDIUM', 1],
    ['E5', 'PRN231', 3, 'MULTIPLE_CHOICE', 'MEDIUM', 1],
    ['E5', 'PRN231', 3, 'ESSAY', 'MEDIUM', 1]
  ];
  const examChapterRules = ruleRows.map(([key, code, chNo, type, diff, count]) => ({
    _id: oid(), exam_id: exams[key]._id, chapter_id: chap[code][chNo]._id,
    question_type: type, difficulty_level: diff, question_count: count, created_at: exams[key].created_at
  }));

  // ------------------------------------------------ exam eligibility (F24)
  const eligibility = [];
  const addEligibility = (key, classCode, bannedIdx = []) => {
    const { from, to } = cls[classCode];
    for (let i = from; i <= to; i++) {
      eligibility.push({
        _id: oid(), exam_id: exams[key]._id, student_id: students[i]._id,
        is_banned: bannedIdx.includes(i), created_at: exams[key].created_at
      });
    }
  };
  addEligibility('E1', 'PRM393_SE1801');
  addEligibility('E2', 'PRM393_SE1802', [29]);
  addEligibility('E3', 'DBI202_SE1801', [12]);
  addEligibility('E4', 'DBI202_SE1802');

  // ------------------------------------------------ attempts, answers, violations (F30-F43, F44)
  const attempts = [];
  const studentAnswers = [];
  const violationLogs = [];
  const proctorAuths = [];
  const attemptOf = {}; // `${examKey}:${studentIdx}` -> attempt

  function buildAttempt(examKey, studentIdx, o) {
    const exam = exams[examKey];
    const list = examQuestionsByExam[examKey];
    const startedAt = new Date(exam.start_time.getTime() + o.startOffsetMin * MIN);
    const finished = o.status !== 'IN_PROGRESS';
    const usedMin = finished ? o.usedMin : Math.max(1, Math.round((NOW - startedAt) / MIN));
    const submittedAt = finished ? new Date(startedAt.getTime() + usedMin * MIN) : null;
    const scored = finished;

    const attempt = {
      _id: oid(), exam_id: exam._id, student_id: students[studentIdx]._id,
      started_at: startedAt, submitted_at: submittedAt, total_score: 0, is_passed: false,
      status: o.status, end_reason: o.endReason || null, violation_count: 0,
      device_info: pick(DEVICES),
      last_synced_at: finished ? submittedAt : minAgo(Math.floor(rnd() * 3)),
      created_at: startedAt
    };

    let mcqGot = 0, mcqMax = 0, essayGot = 0, essayMax = 0;
    list.forEach((item, idx) => {
      const q = item.q;
      const answeredAt = new Date(startedAt.getTime() + Math.round(((idx + 1) / list.length) * usedMin * MIN));
      const answered = rnd() < o.answeredRatio;
      if (q.question_type === 'MULTIPLE_CHOICE') {
        mcqMax += q.default_score;
        if (!answered) return;
        const correctOpt = item.options.find((x) => x.is_correct);
        const sel = rnd() < o.ability ? correctOpt : pick(item.options.filter((x) => !x.is_correct));
        const score = scored && sel.is_correct ? q.default_score : 0;
        mcqGot += score;
        studentAnswers.push({
          _id: oid(), attempt_id: attempt._id, question_id: q._id, selected_option_id: sel._id,
          answer_text: null, score_awarded: score, is_flagged: rnd() < 0.08, answered_at: answeredAt, created_at: answeredAt
        });
      } else {
        essayMax += q.default_score;
        if (!answered) return;
        const got = o.essayGraded ? Math.round((0.45 + rnd() * 0.5) * q.default_score * 2) / 2 : 0;
        essayGot += got;
        studentAnswers.push({
          _id: oid(), attempt_id: attempt._id, question_id: q._id, selected_option_id: null,
          answer_text: pick(ESSAY_ANSWERS), score_awarded: got, is_flagged: false, answered_at: answeredAt, created_at: answeredAt
        });
      }
    });

    if (scored) {
      const mcqPart = mcqMax ? (mcqGot / mcqMax) * 10 * (exam.mcq_weight_percent / 100) : 0;
      const essayPart = essayMax ? (essayGot / essayMax) * 10 * (exam.essay_weight_percent / 100) : 0;
      attempt.total_score = round2(mcqPart + essayPart);
      attempt.is_passed = o.status === 'GRADED' && attempt.total_score >= (10 * exam.min_pass_percentage) / 100;
    }

    const vTypes = o.violationTypes || [];
    vTypes.forEach((type, i) => {
      violationLogs.push({
        _id: oid(), attempt_id: attempt._id, violation_type: type,
        violation_details: VIOLATION_DETAILS[type],
        detected_at: new Date(startedAt.getTime() + Math.round(((i + 1) / (vTypes.length + 1)) * usedMin * MIN))
      });
    });
    attempt.violation_count = vTypes.length;

    attempts.push(attempt);
    attemptOf[`${examKey}:${studentIdx}`] = attempt;
    return attempt;
  }

  const randViolations = () => {
    const r = rnd();
    const n = r < 0.3 ? 1 : r < 0.4 ? 2 : 0;
    return Array.from({ length: n }, () => pick(COMMON_VIOLATIONS));
  };
  const finishedDefaults = (extra = {}) => ({
    status: 'GRADED', endReason: 'SUBMITTED', startOffsetMin: 3 + Math.floor(rnd() * 20),
    usedMin: 18 + Math.floor(rnd() * 11), ability: 0.5 + rnd() * 0.45, answeredRatio: 1,
    essayGraded: true, violationTypes: randViolations(), ...extra
  });

  // E1: PRM393 Progress Test 1 (students 0-14, three absent)
  for (let i = 0; i <= 14; i++) {
    if ([4, 9, 13].includes(i)) continue;
    let opts = finishedDefaults();
    if (i === 2) {
      opts = finishedDefaults({
        status: 'TERMINATED', endReason: 'TERMINATED_VIOLATION', usedMin: 12, answeredRatio: 0.6,
        violationTypes: ['SCREEN_FOCUS_LOST', 'APP_MINIMIZED', 'BLOCKED_SHORTCUT']
      });
    } else if (i === 6) {
      opts = finishedDefaults({ endReason: 'EMERGENCY_EXIT', usedMin: 9, answeredRatio: 0.5, violationTypes: [] });
    } else if (i === 11) {
      opts = finishedDefaults({ endReason: 'AUTO_SUBMIT_TIMEOUT', usedMin: 30, answeredRatio: 0.9 });
    }
    buildAttempt('E1', i, opts);
  }
  const a6 = attemptOf['E1:6'];
  proctorAuths.push({
    _id: oid(), attempt_id: a6._id, proctor_id: lec.LEC001._id, reason: 'MEDICAL_EMERGENCY', auth_method: 'PIN',
    action: 'UNLOCK_KIOSK', notes: 'Student felt dizzy, escorted to the medical room.', authorized_at: a6.submitted_at, created_at: a6.submitted_at
  });

  // E2: PRM393 Midterm (ongoing, students 15-22)
  const ongoing = (i, ratio, v = []) =>
    buildAttempt('E2', i, {
      status: 'IN_PROGRESS', startOffsetMin: 4 + (i - 15) * 5, ability: 0.55 + rnd() * 0.4,
      answeredRatio: ratio, essayGraded: false, violationTypes: v
    });
  ongoing(15, 0.7);
  ongoing(16, 0.5, ['SCREEN_FOCUS_LOST']);
  const a17 = ongoing(17, 0.4, ['FORCE_CLOSE']);
  ongoing(18, 0.6);
  ongoing(19, 0.3, ['APP_MINIMIZED']);
  ongoing(20, 0.5);
  ongoing(21, 0.45, ['SCREEN_FOCUS_LOST', 'BLOCKED_SHORTCUT']);
  const a22 = buildAttempt('E2', 22, {
    status: 'SUBMITTED', endReason: 'SUBMITTED', startOffsetMin: 8, usedMin: 25, ability: 0.8,
    answeredRatio: 1, essayGraded: false, violationTypes: []
  });
  const faultAt = new Date(a17.started_at.getTime() + 10 * MIN); // matches the chat: unlocked at minute 24
  proctorAuths.push(
    {
      _id: oid(), attempt_id: a17._id, proctor_id: lec.LEC002._id, reason: 'TECHNICAL_FAULT', auth_method: 'PIN',
      action: 'RESUME_EXAM', notes: 'App froze after force-close; exam resumed, timer unchanged.', authorized_at: faultAt, created_at: faultAt
    },
    {
      _id: oid(), attempt_id: a22._id, proctor_id: lec.LEC002._id, reason: 'EARLY_SUBMISSION', auth_method: 'NFC',
      action: 'UNLOCK_KIOSK', notes: 'Student finished early.', authorized_at: a22.submitted_at, created_at: a22.submitted_at
    }
  );

  // E4: DBI202 Quiz 1 (students 15-27)
  for (let i = 15; i <= 27; i++) {
    let opts = finishedDefaults({ usedMin: 30 + Math.floor(rnd() * 14) });
    if (i === 20) {
      opts = finishedDefaults({
        status: 'TERMINATED', endReason: 'TERMINATED_VIOLATION', usedMin: 20, answeredRatio: 0.6,
        violationTypes: ['APP_MINIMIZED', 'SCREENSHOT_ATTEMPT', 'SCREEN_FOCUS_LOST']
      });
    } else if (i === 24) {
      opts = finishedDefaults({ endReason: 'AUTO_SUBMIT_TIMEOUT', usedMin: 45, answeredRatio: 0.85 });
    }
    buildAttempt('E4', i, opts);
  }

  // ------------------------------------------------ proctor chat (F29)
  const msg = (examKey, from, to, content, minutesAfterStart, read = true) => ({
    _id: oid(), exam_id: exams[examKey]._id, sender_id: from._id, recipient_id: to._id, content, is_read: read,
    sent_at: new Date(exams[examKey].start_time.getTime() + minutesAfterStart * MIN),
    created_at: new Date(exams[examKey].start_time.getTime() + minutesAfterStart * MIN)
  });
  const proctorMessages = [
    msg('E2', students[17], lec.LEC002, 'Thầy ơi, ứng dụng của em bị đơ, em không bấm được đáp án.', 17),
    msg('E2', lec.LEC002, students[17], 'Em giữ nguyên máy, thầy đến kiểm tra ngay.', 18),
    msg('E2', students[17], lec.LEC002, 'Dạ em cảm ơn thầy.', 19),
    msg('E2', lec.LEC002, students[17], 'Thầy đã mở khóa, em tiếp tục làm bài nhé. Thời gian vẫn được tính tiếp.', 24),
    msg('E2', students[19], lec.LEC002, 'Em xin phép đi vệ sinh được không ạ?', 30),
    msg('E2', lec.LEC002, students[19], 'Không được rời phòng trong 15 phút đầu, em chờ thêm nhé.', 31),
    msg('E2', students[19], lec.LEC002, 'Dạ vâng ạ.', 32, false)
  ];

  // ------------------------------------------------ import batches (F08)
  const importBatches = [
    {
      _id: oid(), imported_by: admin._id, file_name: 'Students_SE18_FA26.xlsx', total_rows: 32, valid_rows: 30,
      duplicate_rows: 1, error_rows: 1, status: 'CONFIRMED', created_at: daysAgo(45),
      error_details: [{ row: 17, message: 'Duplicate user_code SE180016 (skipped)' }, { row: 24, message: 'Invalid email format' }]
    },
    {
      _id: oid(), imported_by: admin._id, file_name: 'Lecturers_Draft.csv', total_rows: 5, valid_rows: 4,
      duplicate_rows: 0, error_rows: 1, status: 'CANCELLED', created_at: daysAgo(12),
      error_details: [{ row: 3, message: 'Missing required column: full_name' }]
    }
  ];

  // ------------------------------------------------ system logs / audit (F10, F18, F19, OR_AUDIT_01)
  const log = (user, action, ago) => ({ _id: oid(), user_id: user._id, action, created_at: daysAgo(ago) });
  const systemLogs = [
    log(admin, 'Updated system config MAX_VIOLATIONS=3', 60),
    log(admin, 'Created user LEC006 (Đặng Quốc Huy)', 80),
    log(admin, 'Imported 30 users from Students_SE18_FA26.xlsx (1 duplicate skipped, 1 error)', 45),
    log(hos.HOS001, 'Approved subject access request: LEC001 -> PRM393', 90),
    log(hos.HOS001, 'Approved subject access request: LEC002 -> PRM393', 90),
    log(hos.HOS002, 'Approved subject access request: LEC003 -> DBI202', 88),
    log(hos.HOS002, 'Approved subject access request: LEC004 -> DBI202', 88),
    log(hos.HOS002, 'Approved subject access request: LEC004 -> CSD201', 85),
    log(hos.HOS001, 'Approved subject access request: LEC005 -> PRN231', 85),
    log(lec.LEC001, "Created exam 'PRM393 - Progress Test 1'", 21),
    log(lec.LEC001, "Exported encrypted violation report for exam 'PRM393 - Progress Test 1'", 13),
    log(hos.HOS002, 'Deactivated subject MAD101', 20),
    log(admin, 'Deactivated user LEC006', 10),
    log(admin, 'Reset password for user SE180005', 7),
    log(hos.HOS002, 'Rejected subject access request: LEC005 -> CSD201', 5),
    log(lec.LEC003, "Created exam and generated QR for 'DBI202 - Midterm Exam'", 3),
    log(lec.LEC002, "Created exam and generated QR for 'PRM393 - Midterm Exam'", 2),
    log(hos.HOS001, 'Invited lecturer LEC004 to subject PRN231', 2),
    log(lec.LEC005, "Saved draft 'PRN231 - Practical Quiz'", 1)
  ];

  // ------------------------------------------------ insert
  const plan = [
    [M.Department, departments], [M.User, users], [M.SystemConfig, systemConfigs], [M.SystemLog, systemLogs],
    [M.ImportBatch, importBatches], [M.Subject, subjects], [M.Chapter, chapters], [M.SubjectAccess, subjectAccess],
    [M.Class, classes], [M.ClassEnrollment, enrollments], [M.Question, questions], [M.QuestionOption, questionOptions],
    [M.Exam, Object.values(exams)], [M.ExamChapterRule, examChapterRules], [M.ExamQuestion, examQuestions],
    [M.ExamEligibility, eligibility], [M.ExamAttempt, attempts], [M.StudentAnswer, studentAnswers],
    [M.ViolationLog, violationLogs], [M.ProctorAuthorization, proctorAuths], [M.ProctorMessage, proctorMessages]
  ];
  for (const [model, docs] of plan) {
    await model.insertMany(docs);
    console.log(`  ${model.collection.name.padEnd(24)} ${docs.length}`);
  }

  console.log('\nSeed finished.');
  console.log(`Login (all users) password: ${DEFAULT_PASSWORD}`);
  console.log('  Admin:            AD001  (ad001@seb.edu.vn)');
  console.log('  Head of Subject:  HOS001, HOS002');
  console.log('  Lecturers:        LEC001-LEC005 (LEC006 inactive)');
  console.log('  Students:         SE180001-SE180030 (SE180029 inactive)');
  console.log(`Ongoing exam "${exams.E2.exam_title}": access PIN ${exams.E2.access_pin}, proctor exit PIN ${EXIT_PIN}`);
  console.log(`Scheduled exam "${exams.E3.exam_title}": access PIN ${exams.E3.access_pin}`);

  await mongoose.disconnect();
}

main().catch(async (err) => {
  console.error('Seed failed:', err);
  await mongoose.disconnect().catch(() => {});
  process.exit(1);
});
