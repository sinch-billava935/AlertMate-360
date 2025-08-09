
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const admin = require("firebase-admin");
const twilio = require("twilio");

// ✅ Set default options (region)
setGlobalOptions({region: "asia-south1"});

// ✅ Initialize Firebase Admin
admin.initializeApp();

// ✅ Twilio Config
const twilioSid = 
const twilioAuth = 
const twilioFrom = // Twilio phone number
const twilioTo = 


const client = twilio(twilioSid, twilioAuth);

// ✅ Firestore Trigger: Send SMS when SOS doc is created
exports.sosAlert = onDocumentCreated(
    "users/{userId}/sos/{sosId}",
    async (event) => {
      const data = event.data.data();
      const userId = event.params.userId;

      const latitude = data.latitude || "Unknown";
      const longitude = data.longitude || "Unknown";

      // Handle timestamp safely
      let time = new Date();
      if (data.timestamp && data.timestamp.toDate) {
        time = data.timestamp.toDate();
      }

      const message = `🚨 SOS Alert!\nUser: ${userId}\nTime: ${time}\n` +
      `Location: ${latitude}, ${longitude}`;

      try {
        await client.messages.create({
          body: message,
          from: twilioFrom,
          to: twilioTo,
        });

        console.log("✅ SOS SMS sent successfully");
      } catch (err) {
        console.error("❌ Failed to send SMS:", err);
      }
    },
);
