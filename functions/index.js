const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Scheduled function that runs every 5 minutes to delete expired messages
 * Messages are deleted when their 'expiresAt' timestamp is in the past
 */
exports.cleanupExpiredMessages = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    
    console.log('Starting cleanup of expired messages...');
    
    try {
      // Query for messages where expiresAt is less than current time
      const expiredMessagesQuery = db.collection('mensajes')
        .where('expiresAt', '<=', now)
        .limit(500); // Process in batches of 500
      
      const snapshot = await expiredMessagesQuery.get();
      
      if (snapshot.empty) {
        console.log('No expired messages found');
        return null;
      }
      
      console.log(`Found ${snapshot.size} expired messages to delete`);
      
      // Delete messages in batch
      const batch = db.batch();
      snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });
      
      await batch.commit();
      console.log(`Successfully deleted ${snapshot.size} expired messages`);
      
      return null;
    } catch (error) {
      console.error('Error cleaning up expired messages:', error);
      return null;
    }
  });

/**
 * Alternative: Firestore trigger that deletes a message when it expires
 * This runs on every message creation but only schedules deletion
 */
exports.scheduleMessageDeletion = functions.firestore
  .document('mensajes/{messageId}')
  .onCreate(async (snap, context) => {
    const messageData = snap.data();
    const expiresAt = messageData.expiresAt;
    
    if (!expiresAt) {
      console.log('Message has no expiresAt field, skipping');
      return null;
    }
    
    // Calculate delay in milliseconds
    const now = Date.now();
    const expiryTime = expiresAt.toDate().getTime();
    const delay = expiryTime - now;
    
    // Only schedule if expiry is in the future and within 5 minutes
    if (delay > 0 && delay <= 300000) {
      console.log(`Message ${context.params.messageId} will be deleted in ${delay}ms`);
      // Note: This approach requires Cloud Tasks or similar for precise scheduling
      // The scheduled cleanup function above is more reliable
    }
    
    return null;
  });
