const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const admin = require("firebase-admin");
const twilio = require("twilio");

// ✅ Set default options (region)
setGlobalOptions({region: "asia-south1"});

// ✅ Initialize Firebase Admin
admin.initializeApp();

// ✅ Twilio Config (unchanged as requested)
const twilioSid ="";
const twilioAuth ="";
const twilioFrom ="";
const twilioTo ="";

const client = twilio(twilioSid, twilioAuth);

// 📌 List of recipients
const recipients = [
  twilioTo,
  "",
  "",
  "",
];

// ✅ Firestore Trigger: Send SMS to multiple recipients
exports.sosAlert = onDocumentCreated(
    "users/{userId}/sos/{sosId}",
    async (event) => {
      const data = event.data.data();
      const userId = event.params.userId;

      const latitude = data.latitude || "Unknown";
      const longitude = data.longitude || "Unknown";

      // Format time in a more readable way
      let time = new Date();
      if (data.timestamp && data.timestamp.toDate) {
        time = data.timestamp.toDate();
      }
      const ft = time.toLocaleString("en-IN", {timeZone: "Asia/kolkata"});

      // 📌 Professional message format
      const message =
`🚨 Emergency SOS Alert 🚨
📌 User ID: ${userId}
🕒 Time: ${ft}
🔗 Google Maps: https://maps.google.com/?q=${latitude},${longitude}
`;

      try {
        await Promise.all(
            recipients.map((to) =>
              client.messages.create({
                body: message,
                from: twilioFrom,
                to,
              }),
            ),
        );

        console.log("✅ SOS SMS sent to all recipients successfully");
      } catch (err) {
        console.error("❌ Failed to send SMS to some recipients:", err);
      }
    },
);
