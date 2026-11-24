const admin = require('./functions/node_modules/firebase-admin');
const serviceAccount = require('./service-account.json');

// Initialize Firebase Admin with credentials
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const messaging = admin.messaging();

console.log('🚀 FCM Live Queue Dispatcher Service Started on Spark (Free Tier)...');

// ---------------------------------------------------------------------------
// 1. Listen to all notifications_queue across all users
// ---------------------------------------------------------------------------
db.collectionGroup('notifications_queue').onSnapshot(
  (snapshot) => {
    snapshot.docChanges().forEach(async (change) => {
      if (change.type === 'added') {
        const data = change.doc.data();
        if (data.status === 'pending') {
          // Get parent user
          const userDocRef = change.doc.ref.parent.parent;
          if (!userDocRef) return;

          const userDoc = await userDocRef.get();
          const fcmToken = userDoc.data()?.fcmToken;

          if (!fcmToken) {
            console.log(`⚠️ User ${userDocRef.id} has no FCM token.`);
            await change.doc.ref.update({ status: 'no_token' });
            return;
          }

          const message = {
            token: fcmToken,
            notification: {
              title: data.title || 'StreakUP Alert',
              body: data.body || '',
            },
            data: {
              type: data.type || 'general',
            },
            android: {
              priority: 'high',
              notification: {
                sound: 'default',
                priority: 'max',
                channelId: 'fcm_live_channel',
                icon: 'ic_notification',
              },
            },
          };

          try {
            const res = await messaging.send(message);
            console.log(`✅ [FCM PUSH SENT] to ${userDocRef.id}: "${data.title}" -> ${res}`);
            await change.doc.ref.update({
              status: 'sent',
              fcmMessageId: res,
              sentAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          } catch (err) {
            console.error(`❌ [FCM PUSH FAILED] to ${userDocRef.id}:`, err);
            await change.doc.ref.update({
              status: 'failed',
              error: err.message,
            });
          }
        }
      }
    });
  },
  (err) => {
    console.error('Snapshot error:', err);
  }
);

// ---------------------------------------------------------------------------
// 2. Scheduled Cron Timers (Water reminders & 8 PM habit protection)
// ---------------------------------------------------------------------------
async function broadcastTopic(topic, title, body) {
  const message = {
    topic: topic,
    notification: { title, body },
    android: {
      priority: 'high',
      notification: {
        sound: 'default',
        priority: 'max',
        channelId: 'fcm_live_channel',
        icon: 'ic_notification',
      },
    },
  };

  try {
    const res = await messaging.send(message);
    console.log(`⏰ [SCHEDULED PUSH] sent to topic "${topic}": "${title}" -> ${res}`);
  } catch (e) {
    console.error(`Error sending scheduled push to ${topic}:`, e);
  }
}

let lastWaterHour = -1;
let lastStreakDate = '';

// Check every minute
setInterval(async () => {
  const now = new Date();
  // Adjust to IST (+5:30)
  const istOffset = 5.5 * 60 * 60 * 1000;
  const istDate = new Date(now.getTime() + istOffset);
  const hour = istDate.getUTCHours();
  const minute = istDate.getUTCMinutes();
  const todayStr = istDate.toISOString().substring(0, 10);

  // 1. Water Reminders: Every 2 hours between 9 AM and 9 PM (9, 11, 13, 15, 17, 19, 21)
  if (minute === 0 && [9, 11, 13, 15, 17, 19, 21].includes(hour) && lastWaterHour !== hour) {
    lastWaterHour = hour;
    await broadcastTopic(
      'water_reminders',
      '💧 Time to Hydrate!',
      'Drink a glass of water to keep your daily streak alive and stay healthy.'
    );
  }

  // 2. Evening Habit Protection: 8:00 PM IST (20:00)
  if (hour === 20 && minute === 0 && lastStreakDate !== todayStr) {
    lastStreakDate = todayStr;
    await broadcastTopic(
      'daily_reminders',
      '🔥 Protect Your Streak!',
      'You have unfinished habits today. Complete them before midnight!'
    );
  }
}, 60 * 1000);
