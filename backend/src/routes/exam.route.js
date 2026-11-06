const express = require('express');
const router = express.Router();
const controller = require('../controllers/exam.controller');
const { authenticate, authorize } = require('../middlewares/auth.middleware');

router.get('/', authenticate, controller.getExams);
router.get('/:id', authenticate, controller.getExamDetail);
router.post('/', authenticate, authorize('LECTURER', 'HEAD_OF_SUBJECT', 'ADMIN'), controller.createExam);
router.post('/:id/questions', authenticate, authorize('LECTURER', 'HEAD_OF_SUBJECT', 'ADMIN'), controller.assignQuestions);
router.post('/:id/students', authenticate, authorize('LECTURER', 'HEAD_OF_SUBJECT', 'ADMIN'), controller.assignStudents);
router.patch('/:id/publish', authenticate, authorize('LECTURER', 'HEAD_OF_SUBJECT', 'ADMIN'), controller.publishExam);

module.exports = router;

