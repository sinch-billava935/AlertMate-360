// functions/index.js
/* eslint max-len: ["error", { "code": 120 }] */

// Firebase Functions v2 + Firestore trigger
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onValueWritten} = require("firebase-functions/v2/database");
const {setGlobalOptions, https} = require("firebase-functions/v2");

const admin = require("firebase-admin");
const express = require("express");
const cors = require("cors");
const twilio = require("twilio");

// -------------------------------
// CONFIG (HARDCODED — INSECURE)
// -------------------------------
// You asked to place credentials in the code. This is insecure — rotate
// these credentials as soon as possible and consider moving them to
// functions config.
const TWILIO_ACCOUNT_SID = "";
const TWILIO_AUTH_TOKEN = "";
const TWILIO_FROM = "";
const TWILIO_VERIFY_SERVICE_SID = "";

const twilioClient = twilio(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN);

// -------------------------------
// Firebase init & region
// -------------------------------
// setGlobalOptions({ region: "asia-south1" });
setGlobalOptions({region: "asia-southeast1"});

admin.initializeApp();

// -------------------------------
// Utilities
// -------------------------------
const e164Regex = /^\+\d{7,15}$/; // simple E.164-ish check

// -------------------------------
// Express app for verify endpoints
// -------------------------------
const app = express();
app.use(cors({origin: true}));
app.use(express.json({limit: "1mb"}));

// requireAuth middleware: expects Authorization: Bearer <ID_TOKEN>
const requireAuth = async (req, res, next) => {
  try {
    const auth = req.headers.authorization || "";
    if (!auth.startsWith("Bearer ")) {
      return res.status(401).json({
        error: "Missing or invalid Authorization header",
      });
    }
    const idToken = auth.split("Bearer ")[1];
    const decoded = await admin.auth().verifyIdToken(idToken);
    req.user = decoded;
    return next();
  } catch (err) {
    console.error(
        "Auth verification failed:",
      err && err.message ? err.message : err,
    );
    return res.status(401).json({error: "Invalid ID token"});
  }
};

// Start verification (send OTP to phone)
app.post("/start-verification", requireAuth, async (req, res) => {
  try {
    const phone = (req.body.phone || "").toString().trim();
    if (!phone) {
      return res.status(400).json({error: "Missing phone"});
    }
    if (!e164Regex.test(phone)) {
      return res.status(400).json({
        error: "Phone must be E.164 format (e.g., +911234567890)",
      });
    }

    const verification = await twilioClient.verify.v2
        .services(TWILIO_VERIFY_SERVICE_SID)
        .verifications.create({to: phone, channel: "sms"});

    return res.json({
      status: verification.status || "pending",
    });
  } catch (err) {
    console.error(
        "start-verification error:",
      err && err.message ? err.message : err,
    );
    return res.status(500).json({
      error: err.message || "start verification failed",
    });
  }
});

// Check verification (verify OTP code)
app.post("/check-verification", requireAuth, async (req, res) => {
  try {
    const phone = (req.body.phone || "").toString().trim();
    const code = (req.body.code || "").toString().trim();
    if (!phone || !code) {
      return res.status(400).json({
        error: "Missing phone or code",
      });
    }
    if (!e164Regex.test(phone)) {
      return res.status(400).json({
        error: "Phone must be E.164 format (e.g., +911234567890)",
      });
    }

    const verificationCheck = await twilioClient.verify.v2
        .services(TWILIO_VERIFY_SERVICE_SID)
        .verificationChecks.create({to: phone, code});

    // Typical statuses: 'approved' or other
    return res.json({status: verificationCheck.status});
  } catch (err) {
    console.error(
        "check-verification error:",
      err && err.message ? err.message : err,
    );
    const msg = err && err.message ? err.message : "verification check failed";
    return res.status(500).json({error: msg});
  }
});

// Export the Express app as a v2 HTTPS function named 'verify'
exports.verify = https.onRequest(app);

// -------------------------------
// sosAlert Firestore trigger (v2)
// Path: users/{userId}/sos/{sosId}
// -------------------------------
exports.sosAlert = onDocumentCreated(
    "users/{userId}/sos/{sosId}",
    async (event) => {
      const data = event.data.data();
      const userId = event.params.userId;

      // Get user name (preferred: FirebaseAuth displayName).
      // Falls back to Firestore fields if needed.
      let userName = "Unknown User";
      try {
      // Try to read the auth user's displayName first
      // (authoritative).
        try {
          const userRecord = await admin.auth().getUser(userId);
          if (userRecord && userRecord.displayName) {
            userName = String(userRecord.displayName).trim();
          }
        } catch (authErr) {
        // If getUser fails (very unlikely), fall back below.
          console.warn(
              "admin.auth().getUser failed:",
          authErr && authErr.message ? authErr.message : authErr,
          );
        }

        // If displayName is still empty/Unknown, try Firestore
        // document fields.
        if (!userName || userName === "Unknown User") {
          const userDoc = await admin
              .firestore()
              .collection("users")
              .doc(userId)
              .get();
          if (userDoc.exists && userDoc.data()) {
            const userData = userDoc.data();
            // Prefer 'username' field (Firestore-backed).
            // Fall back to legacy 'name' field.
            if (userData.username) {
              userName = String(userData.username).trim();
            } else if (userData.name) {
              userName = String(userData.name).trim();
            }
          }
        }
      } catch (e) {
        console.warn(
            "Could not fetch user name:",
        e && e.message ? e.message : e,
        );
      }

      // Extract location if present
      let latitude = "";
      let longitude = "";
      if (
        data &&
      typeof data.latitude !== "undefined" &&
      data.latitude !== null
      ) {
        latitude = String(data.latitude).trim();
      }
      if (
        data &&
      typeof data.longitude !== "undefined" &&
      data.longitude !== null
      ) {
        longitude = String(data.longitude).trim();
      }

      // Time (IST)
      let time = new Date();
      if (data && data.timestamp && typeof data.timestamp.toDate === "function") {
        time = data.timestamp.toDate();
      }
      const timeOpts = {timeZone: "Asia/Kolkata"};
      const formattedTime = time.toLocaleString("en-IN", timeOpts);

      // Build message
      let locationLine = "";
      if (latitude && longitude) {
        locationLine =
        "🔗 Google Maps: " +
        "https://maps.google.com/?q=" +
        latitude +
        "," +
        longitude +
        "\n";
      }
      const message =
      [
        "🚨 Emergency SOS Alert 🚨",
        `📌 Name: ${userName}`,
        `🕒 Time: ${formattedTime}`,
        locationLine.trim(),
      ]
          .filter(Boolean)
          .join("\n") + "\n";

      try {
      // Only fetch verified contacts
        const contactsSnap = await admin
            .firestore()
            .collection("users")
            .doc(userId)
            .collection("emergency_contacts")
            .where("verified", "==", true)
            .get();

        if (contactsSnap.empty) {
          console.log(
              `⚠ No verified emergency contacts found for user ${userId}`,
          );
          return;
        }

        // Build recipient list with E.164 validation and dedupe
        const recipients = [];
        contactsSnap.docs.forEach((d) => {
          let phone = d.get("phone");
          if (typeof phone !== "undefined" && phone !== null) {
            phone = String(phone).trim();
            if (
              phone &&
            e164Regex.test(phone) &&
            recipients.indexOf(phone) === -1
            ) {
              recipients.push(phone);
            } else if (phone && !e164Regex.test(phone)) {
              console.warn("Skipping non-E.164 phone:", phone, "doc:", d.id);
            }
          }
        });

        console.log(
            "Found " +
          contactsSnap.size +
          " contacts, " +
          recipients.length +
          " valid verified phone(s) to message.",
        );

        if (recipients.length === 0) {
          console.log("⚠ No valid recipients after validation.");
          return;
        }

        // Send messages sequentially (could be parallelized)
        for (let i = 0; i < recipients.length; i++) {
          const to = recipients[i];
          try {
            if (!twilioClient) {
              throw new Error("Twilio client not initialized.");
            }
            const resp = await twilioClient.messages.create({
              body: message,
              from: TWILIO_FROM,
              to: to,
            });
            console.log(`✅ SOS SMS sent to ${to} (SID: ${resp.sid})`);
          } catch (e) {
            const emsg = e && e.message ? e.message : String(e);
            console.error(`❌ Failed to send to ${to}: ${emsg}`);
          }
        }
      } catch (err) {
        const msg = err && err.message ? err.message : String(err);
        console.error("❌ sosAlert failed:", msg);
      }
    },
);

// -------------------------------
// Geofence RTDB trigger (v2)
// Path: /users/{userId}/sensors
// Sends FCM when user leaves/enters geofence
// (RTDB primary token, Firestore fallback)
// -------------------------------

exports.onLocationWrite = onValueWritten(
    "/users/{userId}/sensors",
    async (event) => {
      try {
        const userId = event.params.userId;
        const after =
        event.data && event.data.after ? event.data.after.val() : null;
        if (!after) {
          console.log(`[geofence] No 'after' value for user ${userId}`);
          return;
        }

        // Extract latitude and longitude from sensors node
        const latitude = Number(after.latitude);
        const longitude = Number(after.longitude);
        if (!isFinite(latitude) || !isFinite(longitude)) {
          console.log(`[geofence] Invalid coordinates for ${userId}:`, after);
          return;
        }

        // Get geofence config from RTDB
        const gfSnap = await admin
            .database()
            .ref(`/users/${userId}/geofence`)
            .get();

        if (!gfSnap.exists()) {
          console.log(`[geofence] No geofence configured for ${userId}`);
          return;
        }

        const gf = gfSnap.val();
        const centerLat = Number(gf.latitude);
        const centerLng = Number(gf.longitude);
        const radius = Number(gf.radius) || 100;
        const hysteresisMeters = gf.hysteresisMeters ?
        Number(gf.hysteresisMeters) :
        10;
        const notifyCooldownMs = gf.notifyCooldownMs ?
        Number(gf.notifyCooldownMs) :
        5 * 60 * 1000;

        // Haversine formula for distance in meters
        const toRad = (deg) => (deg * Math.PI) / 180;
        const R = 6371000; // Earth radius in meters
        const dLat = toRad(latitude - centerLat);
        const dLon = toRad(longitude - centerLng);
        const a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(toRad(centerLat)) *
          Math.cos(toRad(latitude)) *
          Math.sin(dLon / 2) *
          Math.sin(dLon / 2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        const distanceMeters = R * c;

        console.log(
            `[geofence] ${userId} is ${distanceMeters.toFixed(
                1,
            )} m from center (radius ${radius}m)`,
        );

        // Read geofence_status node
        const statusRef = admin
            .database()
            .ref(`/users/${userId}/geofence_status`);
        const statusSnap = await statusRef.get();
        const prevStatus = statusSnap.exists() ?
        statusSnap.val() :
        {inside: true, lastNotifiedAt: 0};

        // Determine inside/outside with hysteresis
        let nowInside;
        if (prevStatus.inside === true) {
          nowInside = distanceMeters <= radius + hysteresisMeters;
        } else {
          nowInside = distanceMeters <= radius - hysteresisMeters;
        }

        // If state unchanged — update distance and exit
        if (
          typeof prevStatus.inside !== "undefined" &&
        nowInside === prevStatus.inside
        ) {
          await statusRef.update({
            lastDistance: distanceMeters,
            lastLocationAt: admin.database.ServerValue.TIMESTAMP,
          });
          console.log(
              `[geofence] No state change for ${userId} (inside=${nowInside}).`,
          );
          return;
        }

        // Check notification cooldown
        const lastNotifiedAt = prevStatus.lastNotifiedAt ?
        Number(prevStatus.lastNotifiedAt) :
        0;
        const nowMs = Date.now();
        if (nowMs - lastNotifiedAt < notifyCooldownMs) {
          console.log(
              `[geofence] Cooldown active for ${userId}, skipping notify`,
          );
          await statusRef.update({
            inside: nowInside,
            lastTransitionAt: admin.database.ServerValue.TIMESTAMP,
            lastDistance: distanceMeters,
          });
          return;
        }

        // -----------------------------------
        // Fetch FCM token (RTDB primary)
        // -----------------------------------
        let tokens = [];
        try {
          const tokenSnap = await admin
              .database()
              .ref(`/users/${userId}/fcmToken`)
              .get();
          if (tokenSnap.exists()) {
            const t = tokenSnap.val();
            if (typeof t === "string") {
              tokens.push(t);
            } else if (typeof t === "object") {
              tokens = tokens.concat(
                  Object.values(t).filter((x) => typeof x === "string"),
              );
            }
          }
        } catch (e) {
          console.warn(`[geofence] RTDB token fetch failed: ${e}`);
        }

        // Firestore fallback if no token in RTDB
        if (tokens.length === 0) {
          try {
            const userDoc = await admin
                .firestore()
                .collection("users")
                .doc(userId)
                .get();
            if (userDoc.exists) {
              const data = userDoc.data() || {};
              const f = data.fcmToken || data.fcmTokens;
              if (typeof f === "string") tokens.push(f);
              else if (typeof f === "object") {
                tokens = tokens.concat(
                    Object.values(f).filter((x) => typeof x === "string"),
                );
              }
            }
          } catch (e) {
            console.warn(`[geofence] Firestore token fetch failed: ${e}`);
          }
        }

        if (tokens.length === 0) {
          console.warn(
              `[geofence] No FCM token found for ${userId}; skipping notification.`,
          );
          await statusRef.update({
            inside: nowInside,
            lastTransitionAt: admin.database.ServerValue.TIMESTAMP,
            lastDistance: distanceMeters,
          });
          return;
        }

        // -----------------------------------
        // Send FCM Notification (single token)
        // -----------------------------------
        const title = nowInside ?
        "✅ Safe: back inside area" :
        "⚠️ Geofence alert: left safe area";

        const body = nowInside ?
        "You have re-entered your safe zone." :
        `You are ${Math.round(
            distanceMeters,
        )} m away from your safe zone center.`;

        const message = {
          token: tokens[0], // ✅ single token
          notification: {title, body},
          data: {
            type: nowInside ? "geofence_enter" : "geofence_exit",
            latitude: String(latitude),
            longitude: String(longitude),
            distance: String(Math.round(distanceMeters)),
          },
        };

        try {
          const response = await admin.messaging().send(message);
          console.log(`[geofence] Notification sent to ${userId}:`, response);
        } catch (err) {
          console.error(`[geofence] FCM send error for ${userId}:`, err);
        }

        // Update geofence_status
        await statusRef.set({
          inside: nowInside,
          lastTransitionAt: admin.database.ServerValue.TIMESTAMP,
          lastNotifiedAt: nowMs,
          lastDistance: distanceMeters,
        });

        console.log(`[geofence] Completed for ${userId}. nowInside=${nowInside}`);
      } catch (err) {
        console.error("[geofence] onLocationWrite unexpected error:", err);
      }
    },
);
