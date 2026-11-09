const express = require('express');
const router = express.Router();
const controller = require('../controllers/exam.controller');
const { authenticate, authorize } = require('../middlewares/auth.middleware');

router.get('/classes/by-subject/:subject_id', authenticate, authorize('LECTURER', 'HEAD_OF_SUBJECT', 'ADMIN'), controller.getClassesBySubject);
router.get('/classes/:class_id/students', authenticate, authorize('LECTURER', 'HEAD_OF_SUBJECT', 'ADMIN'), controller.getClassStudents);
router.get('/students/search', authenticate, authorize('LECTURER', 'HEAD_OF_SUBJECT', 'ADMIN'), controller.searchStudents);
router.get('/', authenticate, controller.getExams);
router.get('/:id', authenticate, controller.getExamDetail);
router.get('/:id/live-pin', authenticate, controller.getLivePin);
router.post('/:id/refresh-pin', authenticate, authorize('LECTURER', 'HEAD_OF_SUBJECT', 'ADMIN'), controller.refreshPin);
router.get('/:id/statistics', authenticate, authorize('LECTURER', 'HEAD_OF_SUBJECT', 'ADMIN'), controller.getExamStatistics);
router.get('/:id/export', authenticate, authorize('LECTURER', 'HEAD_OF_SUBJECT', 'ADMIN'), controller.exportExamGrades);
router.post('/', authenticate, authorize('LECTURER', 'HEAD_OF_SUBJECT', 'ADMIN'), controller.createExam);
router.put('/:id', authenticate, authorize('LECTURER', 'HEAD_OF_SUBJECT', 'ADMIN'), controller.updateExam);
router.delete('/:id', authenticate, authorize('LECTURER', 'HEAD_OF_SUBJECT', 'ADMIN'), controller.deleteExam);
router.post('/:id/questions', authenticate, authorize('LECTURER', 'HEAD_OF_SUBJECT', 'ADMIN'), controller.assignQuestions);
router.post('/:id/students', authenticate, authorize('LECTURER', 'HEAD_OF_SUBJECT', 'ADMIN'), controller.assignStudents);
router.patch('/:id/publish', authenticate, authorize('LECTURER', 'HEAD_OF_SUBJECT', 'ADMIN'), controller.publishExam);
router.patch('/:id/close', authenticate, authorize('LECTURER', 'HEAD_OF_SUBJECT', 'ADMIN'), controller.closeExam);

module.exports = router;

