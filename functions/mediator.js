'use strict';
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {randomInt, createHash} = require('node:crypto');
const mediatorAction = require('./mediator-core.cjs');
exports.mediatorAction = onCall(request => mediatorAction(request, {
 database: getFirestore(), FieldValue, HttpsError, randomInt,
 hash: value => createHash('sha256').update(value).digest('hex'),
}));
