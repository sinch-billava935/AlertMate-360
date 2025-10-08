// functions/index.js
module.exports = { onLocationWrite };
// Firebase Functions v2 + Firestore trigger
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions, https } = require("firebase-functions/v2");

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
const TWILIO_VERIFY_SERVICE_SID = "";
const TWILIO_FROM = "";

const twilioClient = twilio(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN);

// -------------------------------
// Firebase init & region
// -------------------------------
setGlobalOptions({ region: "asia-south1" });
admin.initializeApp();

// -------------------------------
// Utilities
// -------------------------------
const e164Regex = /^\+\d{7,15}$/; // simple E.164-ish check

// -------------------------------
// Express app for verify endpoints
// -------------------------------
const app = express();
app.use(cors({ origin: true }));
app.use(express.json({ limit: "1mb" }));

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
      err && err.message ? err.message : err
    );
    return res.status(401).json({ error: "Invalid ID token" });
  }
};

// Start verification (send OTP to phone)
app.post("/start-verification", requireAuth, async (req, res) => {
  try {
    const phone = (req.body.phone || "").toString().trim();
    if (!phone) {
      return res.status(400).json({ error: "Missing phone" });
    }
    if (!e164Regex.test(phone)) {
      return res.status(400).json({
        error: "Phone must be E.164 format (e.g., +911234567890)",
      });
    }

    const verification = await twilioClient.verify.v2
      .services(TWILIO_VERIFY_SERVICE_SID)
      .verifications.create({ to: phone, channel: "sms" });

    return res.json({
      status: verification.status || "pending",
    });
  } catch (err) {
    console.error(
      "start-verification error:",
      err && err.message ? err.message : err
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
      .verificationChecks.create({ to: phone, code });

    // Typical statuses: 'approved' or other
    return res.json({ status: verificationCheck.status });
  } catch (err) {
    console.error(
      "check-verification error:",
      err && err.message ? err.message : err
    );
    const msg = err && err.message ? err.message : "verification check failed";
    return res.status(500).json({ error: msg });
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
          authErr && authErr.message ? authErr.message : authErr
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
        e && e.message ? e.message : e
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
    const timeOpts = { timeZone: "Asia/Kolkata" };
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
          `⚠ No verified emergency contacts found for user ${userId}`
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
          " valid verified phone(s) to message."
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
  }
);
