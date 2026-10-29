const Department = require('./department.model');
const User = require('./user.model');
const SystemConfig = require('./system-config.model');
const SystemLog = require('./system-log.model');
const Subject = require('./subject.model');
const Chapter = require('./chapter.model');
const SubjectAccess = require('./subject-access.model');
const Class = require('./class.model');
const ClassEnrollment = require('./class-enrollment.model');
const Question = require('./question.model');
const QuestionOption = require('./question-option.model');
const Exam = require('./exam.model');
const ExamChapterRule = require('./exam-chapter-rule.model');
const ExamQuestion = require('./exam-question.model');
const ExamEligibility = require('./exam-eligibility.model');
const ExamAttempt = require('./exam-attempt.model');
const StudentAnswer = require('./student-answer.model');
const ViolationLog = require('./violation-log.model');
const ImportBatch = require('./import-batch.model');
const ProctorAuthorization = require('./proctor-authorization.model');
const ProctorMessage = require('./proctor-message.model');

module.exports = {
  ImportBatch,
  ProctorAuthorization,
  ProctorMessage,
  Department,
  User,
  SystemConfig,
  SystemLog,
  Subject,
  Chapter,
  SubjectAccess,
  Class,
  ClassEnrollment,
  Question,
  QuestionOption,
  Exam,
  ExamChapterRule,
  ExamQuestion,
  ExamEligibility,
  ExamAttempt,
  StudentAnswer,
  ViolationLog
};

