const {setGlobalOptions, logger} = require("firebase-functions/v2");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {defineSecret} = require("firebase-functions/params");
const functionsV1 = require("firebase-functions/v1");
const admin = require("firebase-admin");

let initialized = false;

function initializeFirebaseRuntime() {
  if (initialized) {
    return;
  }

  if (admin.apps.length === 0) {
    admin.initializeApp();
  }

  setGlobalOptions({region: "europe-west1", maxInstances: 10});
  initialized = true;
}

module.exports = {
  admin,
  defineSecret,
  functionsV1,
  HttpsError,
  initializeFirebaseRuntime,
  logger,
  onCall,
  onSchedule,
};
