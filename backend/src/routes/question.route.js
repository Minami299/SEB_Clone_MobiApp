const express = require('express');
const router = express.Router();
const controller = require('../controllers/question.controller');
const { authenticate, authorize } = require('../middlewares/auth.middleware');

router.post('/batch', authenticate, authorize('LECTURER', 'HEAD_OF_SUBJECT', 'ADMIN'), controller.createBatchQuestions);
router.post('/', authenticate, authorize('LECTURER', 'HEAD_OF_SUBJECT', 'ADMIN'), controller.createQuestion);
router.put('/:id', authenticate, authorize('LECTURER', 'HEAD_OF_SUBJECT', 'ADMIN'), controller.updateQuestion);
router.get('/chapters/subject/:subject_id', authenticate, controller.getChaptersBySubject);
router.get('/subject/:subject_id', authenticate, authorize('LECTURER', 'HEAD_OF_SUBJECT', 'ADMIN'), controller.getQuestionsBySubject);
router.get('/:id', authenticate, authorize('LECTURER', 'HEAD_OF_SUBJECT', 'ADMIN'), controller.getQuestionDetail);
router.delete('/:id', authenticate, authorize('LECTURER', 'HEAD_OF_SUBJECT', 'ADMIN'), controller.deleteQuestion);

module.exports = router;

