const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

/**
 * 💧 1. Scheduled Hydration Reminders
 * Runs every 2 hours between 9 AM and 9 PM daily (IST timezone)
 * Broadcasts to all users subscribed to the 'water_reminders' FCM topic
 */
exports.scheduledWaterReminder = functions.pubsub
  .schedule("0 9,11,13,15,17,19,21 * * *")
  .timeZone("Asia/Kolkata")
  .onRun(async (context) => {
    const message = {
      notification: {
        title: "💧 Time to Hydrate!",
        body: "Drink a glass of water to keep your daily streak alive and stay healthy.",
      },
      topic: "water_reminders",
    };

    try {
      const response = await admin.messaging().send(message);
      console.log("Successfully sent water reminder push:", response);
    } catch (error) {
      console.error("Error sending water reminder push:", error);
    }
    return null;
  });

/**
 * 🔥 2. Scheduled Evening Habit Review (8:00 PM IST)
 * Reminds users who haven't completed their daily habits
 */
exports.scheduledDailyStreakReminder = functions.pubsub
  .schedule("0 20 * * *")
  .timeZone("Asia/Kolkata")
  .onRun(async (context) => {
    const message = {
      notification: {
        title: "🔥 Protect Your Streak!",
        body: "You have unfinished habits today. Complete them before midnight!",
      },
      topic: "daily_reminders",
    };

    try {
      const response = await admin.messaging().send(message);
      console.log("Successfully sent daily streak reminder:", response);
    } catch (error) {
      console.error("Error sending daily streak reminder:", error);
    }
    return null;
  });

/**
 * ⚡ 3. Automated Queue Dispatcher
 * Whenever a document is added to 'users/{userId}/notifications_queue',
 * this function automatically sends a targeted FCM message to that specific device.
 */
exports.dispatchUserLiveNotification = functions.firestore
  .document("users/{userId}/notifications_queue/{docId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data || data.status === "sent") return null;

    const userId = context.params.userId;
    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    const fcmToken = userDoc.data()?.fcmToken;

    if (!fcmToken) {
      console.warn(`No FCM token found for user: ${userId}`);
      return null;
    }

    const message = {
      token: fcmToken,
      notification: {
        title: data.title || "StreakUP Notification",
        body: data.body || "",
      },
      data: {
        type: data.type || "general",
      },
    };

    try {
      await admin.messaging().send(message);
      await snap.ref.update({
        status: "sent",
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`Dispatched live notification to ${userId}: ${data.title}`);
    } catch (err) {
      console.error(`Failed to dispatch notification to ${userId}:`, err);
      await snap.ref.update({ status: "failed", error: err.message });
    }

    return null;
  });
