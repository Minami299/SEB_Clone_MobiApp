const express = require('express');
const router = express.Router();
const controller = require('../controllers/exam-execution.controller');
const { authenticate, authorize } = require('../middlewares/auth.middleware');

router.get('/my-submissions', authenticate, controller.getMySubmissions);
router.post('/start', authenticate, authorize('STUDENT'), controller.startAttempt);
router.post('/answer', authenticate, authorize('STUDENT'), controller.saveAnswer);
router.post('/violation', authenticate, authorize('STUDENT'), controller.reportViolation);
router.post('/:attempt_id/submit', authenticate, authorize('STUDENT'), controller.submitExam);
router.get('/:attemptId/result', authenticate, controller.getAttemptResult);
router.post('/:attemptId/force-suspend', authenticate, authorize('LECTURER', 'HEAD_OF_SUBJECT', 'ADMIN'), controller.forceSuspendAttempt);
router.get('/violations/:exam_id', authenticate, authorize('LECTURER', 'HEAD_OF_SUBJECT', 'ADMIN'), controller.getExamViolationLogs);

module.exports = router;

