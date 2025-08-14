const {onDocumentCreated} =
  require("firebase-functions/v2/firestore");
const {setGlobalOptions} =
  require("firebase-functions/v2");
const admin = require("firebase-admin");
const twilio = require("twilio");

// ✅ Region
setGlobalOptions({region: "asia-south1"});

// ✅ Firebase Admin
admin.initializeApp();

// ✅ Twilio config
const twilioSid = "ACb25f2be6f66fac86e39071dacb554488";
const twilioAuth = "0c0682ac51bd2ca53d6ea831069d2546";
const twilioFrom = "+13157376760";

const client = twilio(twilioSid, twilioAuth);

// ✅ Firestore Trigger: Send SMS to all saved emergency contacts
exports.sosAlert = onDocumentCreated(
    "users/{userId}/sos/{sosId}",
    async (event) => {
      const data = event.data.data();
      const userId = event.params.userId;

      // ✅ Get user's name from Firestore
      const userDoc = await admin.firestore()
          .collection("users")
          .doc(userId)
          .get();

      let userName = "Unknown User";
      if (userDoc.exists && userDoc.data().name) {
        userName = String(userDoc.data().name).trim();
      }

      // Location (optional)
      let latitude = "";
      let longitude = "";
      if (data && typeof data.latitude !== "undefined" &&
        data.latitude !== null) {
        latitude = String(data.latitude).trim();
      }
      if (data && typeof data.longitude !== "undefined" &&
        data.longitude !== null) {
        longitude = String(data.longitude).trim();
      }

      // Time in IST
      let time = new Date();
      if (data && data.timestamp &&
        typeof data.timestamp.toDate === "function") {
        time = data.timestamp.toDate();
      }
      const timeOpts = {timeZone: "Asia/Kolkata"};
      const formattedTime = time.toLocaleString("en-IN", timeOpts);

      // SMS body
      let locationLine = "";
      if (latitude && longitude) {
        locationLine =
        "🔗 Google Maps: https://maps.google.com/?q=" +
        latitude + "," + longitude + "\n";
      }

      const message = [
        "🚨 Emergency SOS Alert 🚨",
        "📌 Name: " + userName,
        "🕒 Time: " + formattedTime,
        locationLine.trim(),
      ].filter(Boolean).join("\n") + "\n";

      try {
      // 🔎 Fetch emergency contacts
        const contactsSnap = await admin.firestore()
            .collection("users")
            .doc(userId)
            .collection("emergency_contacts")
            .get();

        if (contactsSnap.empty) {
          console.log("⚠ No emergency contacts found for user: " + userId);
          return;
        }

        // 📱 Send SMS to each valid phone number
        const recipients = [];
        contactsSnap.docs.forEach((d) => {
          let phone = d.get("phone");
          if (typeof phone !== "undefined" && phone !== null) {
            phone = String(phone).trim();
            if (phone && recipients.indexOf(phone) === -1) {
              recipients.push(phone);
            }
          }
        });

        if (recipients.length === 0) {
          console.log("⚠ No valid phone numbers for user: " + userId);
          return;
        }

        for (let i = 0; i < recipients.length; i++) {
          const to = recipients[i];
          try {
            const resp = await client.messages.create({
              body: message,
              from: twilioFrom,
              to: to,
            });
            console.log(
                "✅ SOS SMS sent to " + to + " (SID: " + resp.sid + ")",
            );
          } catch (e) {
            const emsg = (e && e.message) ? e.message : String(e);
            console.error("❌ Failed to send to " + to + ": " + emsg);
          }
        }
      } catch (err) {
        const msg = (err && err.message) ? err.message : String(err);
        console.error("❌ sosAlert failed: " + msg);
      }
    },
);
