#include <WiFi.h>
#include <HTTPClient.h>
#include <base64.h>
#include <TinyGPSPlus.h>
#include <Firebase_ESP_Client.h>
#include <DHT.h>
#include <Wire.h>
#include "MAX30100_PulseOximeter.h"
#include <OneWire.h>
#include <DallasTemperature.h>

// ====== Wi-Fi Credentials ======
#define WIFI_SSID "360"
#define WIFI_PASSWORD "123456789"

// ====== Firebase Credentials ======
#define API_KEY ""
#define DATABASE_URL "https://alertmatefb-a1c17-default-rtdb.asia-southeast1.firebasedatabase.app/"
#define USER_UID ""

// Firebase objects
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// ====== Twilio Credentials ======
const char* account_sid = "";
const char* auth_token  = "";
const char* from_number = "";
const char* to_number = "";

// ====== SOS Button Pin ======
const int SosButtonPin = 4;   // ⚠ DS18B20 uses GPIO15

// ====== GPS Setup ======
TinyGPSPlus gps;
static const int RXPin = 16;
static const int TXPin = 17;
static const uint32_t GPSBaud = 9600;

// ====== DHT22 Setup ======
#define DHTPIN 5
#define DHTTYPE DHT22
DHT dht(DHTPIN, DHTTYPE);

// ====== MAX30100 Setup ======
#define SDA_PIN 21
#define SCL_PIN 22
PulseOximeter pox;
uint32_t tsLastReport = 0;

// ====== DS18B20 Setup (Human Temperature) ======
#define ONE_WIRE_BUS 15   // DS18B20 Data pin → GPIO15
OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature sensors(&oneWire);

// ====== Beat detection callback ======
void onBeatDetected() {
  Serial.println("♥ Beat detected!");
}

void setup() {
  Serial.begin(115200);
  pinMode(SosButtonPin, INPUT_PULLUP);

  // Start GPS
  Serial2.begin(GPSBaud, SERIAL_8N1, RXPin, TXPin);
  Serial.println("🚀 GPS + Firebase + Twilio SOS System Starting...");

  // Wi-Fi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to Wi-Fi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\n✅ WiFi connected!");

  // Firebase setup
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  auth.user.email = ""; // dummy device login
  auth.user.password = "";
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  // Init DHT22
  dht.begin();
  Serial.println("🌡 DHT22 Sensor Ready!");

  // Init DS18B20
  sensors.begin();
  Serial.println("🌡 DS18B20 (Human Temp) Ready!");

  // Init MAX30100
  Wire.begin(SDA_PIN, SCL_PIN);
  Serial.println("Initializing MAX30100 Pulse Oximeter...");
  if (!pox.begin()) {
    Serial.println("❌ FAILED: MAX30100 not found");
    while (1);
  } else {
    Serial.println("✅ SUCCESS: MAX30100 found");
  }
  pox.setIRLedCurrent(MAX30100_LED_CURR_24MA);
  pox.setOnBeatDetectedCallback(onBeatDetected);
}

void loop() {
  // Feed GPS data
  while (Serial2.available() > 0) {
    gps.encode(Serial2.read());
  }

  // PulseOximeter update
  pox.update();

  // Every 5s → Send Firebase data
  if (millis() - tsLastReport > 5000) {
    tsLastReport = millis();

    // Read Environment (DHT22)
    float envTempC = dht.readTemperature();
    float envHum = dht.readHumidity();

    // Read Human Temp (DS18B20)
    sensors.requestTemperatures();
    float humanTempC = sensors.getTempCByIndex(0);
    float humanTempF = sensors.toFahrenheit(humanTempC);

    // Read MAX30100
    float heartRate = pox.getHeartRate();
    float spo2 = pox.getSpO2();

    // Handle invalid readings
    if (isnan(envTempC)) envTempC = 0;
    if (isnan(envHum)) envHum = 0;
    if (isnan(humanTempF)) humanTempF = 0;
    if (isnan(heartRate)) heartRate = 0;
    if (isnan(spo2)) spo2 = 0;

    Serial.printf("💓 HR: %.1f bpm | SpO₂: %.1f %% | 🌡 HTEMP: %.1f °F | 🌍 ETEMP: %.1f °C | 💧 HUM: %.1f %%\n",
                  heartRate, spo2, humanTempF, envTempC, envHum);

    FirebaseJson json;
    json.set("heartRate", heartRate);
    json.set("spo2", spo2);
    json.set("humanTemperature_F", humanTempF);       // Human temp in °F
    json.set("environmentTemperature_C", envTempC);  // Env temp in °C
    json.set("humidity", envHum);
    json.set("timestamp", millis());

    String path = "/users/" + String(USER_UID) + "/sensors";
    if (Firebase.RTDB.setJSON(&fbdo, path.c_str(), &json)) {
      Serial.println("✅ Data uploaded to Firebase");
    } else {
      Serial.println("❌ Upload FAILED: " + fbdo.errorReason());
    }
  }

  // SOS Button → Send Twilio SMS
  if (digitalRead(SosButtonPin) == LOW) {
    String message = "🚨SOS ALERT! ";

    // Only Google Maps link
    if (gps.location.isValid() && gps.location.lat() != 0 && gps.location.lng() != 0) {
      double lat = gps.location.lat();
      double lng = gps.location.lng();

      String mapsLink = "https://maps.google.com/?q=" + String(lat, 6) + "," + String(lng, 6);
      message += "Loc: " + mapsLink;
    } else {
      message += "Loc not ready.";
    }

    // Current sensor readings
    float envTempC = dht.readTemperature();
    float envHum = dht.readHumidity();
    sensors.requestTemperatures();
    float humanTempC = sensors.getTempCByIndex(0);
    float humanTempF = sensors.toFahrenheit(humanTempC);
    float hr = pox.getHeartRate();
    float spo2 = pox.getSpO2();

    // Handle invalid readings
    if (isnan(envTempC)) envTempC = 0;
    if (isnan(envHum)) envHum = 0;
    if (isnan(humanTempF)) humanTempF = 0;
    if (isnan(hr)) hr = 0;
    if (isnan(spo2)) spo2 = 0;

    // Compact sensor data with short labels
    message += "\nHR:" + String(hr, 0) + " | SpO2:" + String(spo2, 0);
    message += " | HTEMP:" + String(humanTempF, 0) + "F";
    message += " | ETEMP:" + String(envTempC, 0) + "C";
    message += " | HUM:" + String(envHum, 0) + "%";

    Serial.println("🚨 SOS Triggered! Sending compact SMS via Twilio...");
    sendSMS(message);

    delay(5000); // Prevent spamming
  }
}

// ====== Send Twilio SMS ======
void sendSMS(String message) {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    String url = "https://api.twilio.com/2010-04-01/Accounts/" + String(account_sid) + "/Messages.json";

    http.begin(url);
    String auth = base64::encode(String(account_sid) + ":" + String(auth_token));
    http.addHeader("Authorization", "Basic " + auth);
    http.addHeader("Content-Type", "application/x-www-form-urlencoded");

    String body = "To=" + String(to_number) +
                  "&From=" + String(from_number) +
                  "&Body=" + message;

    int httpResponseCode = http.POST(body);

    if (httpResponseCode > 0) {
      Serial.println("📩 SMS Sent! Response:");
      Serial.println(http.getString());
    } else {
      Serial.print("❌ Error sending SMS: ");
      Serial.println(httpResponseCode);
    }

    http.end();
  } else {
    Serial.println("⚠ WiFi not connected");
  }
}