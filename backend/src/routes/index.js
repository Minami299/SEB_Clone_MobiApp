const express = require('express');
const router = express.Router();

const healthRoute = require('./health.route');
const authRoute = require('./auth.route');
const subjectAccessRoute = require('./subject-access.route');
const questionRoute = require('./question.route');
const examRoute = require('./exam.route');
const examExecutionRoute = require('./exam-execution.route');
const notificationRoute = require('./notification.route');

router.use('/health', healthRoute);
router.use('/auth', authRoute);
router.use('/subject-access', subjectAccessRoute);
router.use('/questions', questionRoute);
router.use('/exams', examRoute);
router.use('/exam-execution', examExecutionRoute);
router.use('/notifications', notificationRoute);

module.exports = router;

