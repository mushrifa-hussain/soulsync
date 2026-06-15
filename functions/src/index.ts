import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

/**
 * Cloud Function: syncLocalToCloud
 * Accepts an array of local entries and upserts them in Firestore
 * Returns mapping { localId: cloudId }
 */
export const syncLocalToCloud = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to sync entries'
    );
  }

  const uid = context.auth.uid;
  const entries = data.entries || [];
  const mapping: { [key: string]: string } = {};

  try {
    const db = admin.firestore();
    const batch = db.batch();
    const entriesRef = db.collection(`users/${uid}/entries`);

    for (const entry of entries) {
      // Use cloudId if exists, otherwise use local id
      const cloudId = entry.cloudId || entry.id;
      const docRef = entriesRef.doc(cloudId);

      // Prepare entry data with server timestamps
      const entryData = {
        ...entry,
        serverUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        serverCreatedAt: entry.serverCreatedAt || admin.firestore.FieldValue.serverTimestamp(),
      };

      batch.set(docRef, entryData, { merge: true });
      mapping[entry.id] = cloudId;
    }

    await batch.commit();

    return { mapping };
  } catch (error: any) {
    console.error('Error syncing entries:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to sync entries',
      error.message
    );
  }
});

/**
 * Cloud Function: onAuthCreate
 * Creates users/{uid} document when a new user signs up
 */
export const onAuthCreate = functions.auth.user().onCreate(async (user) => {
  try {
    const db = admin.firestore();
    const userRef = db.collection('users').doc(user.uid);

    await userRef.set({
      email: user.email || '',
      uid: user.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    console.log(`User document created for: ${user.uid}`);
  } catch (error) {
    console.error('Error creating user document:', error);
  }
});

/**
 * Cloud Function: backupNow
 * Forces immediate backup of all user entries
 */
export const backupNow = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to backup'
    );
  }

  // User is authenticated (uid available via context.auth.uid if needed)
  try {
    // This function can trigger a sync operation
    // The actual sync is handled client-side, but this can be used
    // to trigger server-side operations if needed
    return { success: true, message: 'Backup initiated' };
  } catch (error: any) {
    console.error('Error in backupNow:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to initiate backup',
      error.message
    );
  }
});

/**
 * Cloud Function: geminiChat
 * Handles AI chat conversations using Google Gemini API
 */
export const geminiChat = functions.https.onCall(async (data, context) => {

  require("firebase-functions/logger/compat");

  console.log('<<< hello');
  console.log('<<< process.env.GEMINI_API_KEY', process.env.GEMINI_API_KEY);
  console.log('<<< process.env', process.env);

  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to use AI chat'
    );
  }

  try {
    const { GoogleGenerativeAI } = require('@google/generative-ai');

    // Get Gemini API key from environment or config
    // Try environment variable first, then Firebase config (deprecated but still works)
    let apiKey = process.env.GEMINI_API_KEY;

    // Log for debugging (don't log the actual key)
    console.log('API Key check:', apiKey ? 'Found' : 'Not found');

    if (!apiKey || apiKey.trim() === '') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Gemini API key is not configured. Please set GEMINI_API_KEY environment variable or configure it in Firebase Functions config.'
      );
    }

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });

    const conversationHistory = data.conversationHistory || [];

    if (conversationHistory.length === 0) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Conversation history is required'
      );
    }

    // Get the last user message
    const lastMessage = conversationHistory[conversationHistory.length - 1];
    if (!lastMessage || lastMessage.role !== 'user') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Last message must be from user'
      );
    }

    // Build conversation history for context (all messages except the last one)
    const historyMessages = conversationHistory.slice(0, -1).map((msg: any) => ({
      role: msg.role === 'user' ? 'user' : 'model',
      parts: [{ text: msg.text }],
    }));

    // System instruction for AI personality - SIMPLE AND DIRECT
    const systemInstruction = `You are SoulSync AI - a friendly friend who texts like a real person.

    MANDATORY RULES - NO EXCEPTIONS:
    1. EVERY message MUST have 6-10 emojis. Put them throughout the message, not just at the end.
    2. NEVER use asterisks (** or *). NO bold, NO markdown. Just plain text with emojis.
    3. Keep messages SHORT - maximum 2-3 sentences. Like a text message.
    4. Be friendly and supportive.

    GOOD: "Hey! 💜 I'm sorry you're not feeling well. 🌸 That really sucks! ✨ What's going on? I'm here for you. 💖"
    
    BAD - DO NOT DO THIS:
    - Messages without emojis
    - Using ** or * asterisks anywhere
    - Long paragraphs or multiple sentences

    Format: Short text + lots of emojis + no asterisks. Always.`;

    // Start chat with history and system instruction
    const chat = model.startChat({
      history: historyMessages,
      systemInstruction: systemInstruction,
      generationConfig: {
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 512,
      },
    });

    // Send the last user message and get response
    const result = await chat.sendMessage(lastMessage.text);
    const response = result.response;
    const text = response.text();

    return { response: text };
  } catch (error: any) {
    console.error('Error in geminiChat:', error);

    // Handle specific Gemini API errors
    if (error.message?.includes('API key')) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Invalid Gemini API key. Please check your configuration.'
      );
    }

    throw new functions.https.HttpsError(
      'internal',
      'Failed to get AI response',
      error.message
    );
  }
});

/**
 * Cloud Function: geminiSummarize
 * Summarizes a conversation into a diary entry format using Google Gemini API
 */
export const geminiSummarize = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to generate summary'
    );
  }

  try {
    const { GoogleGenerativeAI } = require('@google/generative-ai');

    // Get Gemini API key from environment or config
    // Try environment variable first, then Firebase config (deprecated but still works)
    let apiKey = process.env.GEMINI_API_KEY;

    if (!apiKey) {
      try {
        const config = functions.config();
        // Try multiple possible config paths
        apiKey = config.gemini?.api_key ||
          config.ai?.gemini_key ||
          config.gemini?.key;
      } catch (configError) {
        console.error('Error reading Firebase config:', configError);
      }
    }

    // Log for debugging (don't log the actual key)
    console.log('API Key check (summarize):', apiKey ? 'Found' : 'Not found');

    if (!apiKey || apiKey.trim() === '') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Gemini API key is not configured. Please set GEMINI_API_KEY environment variable or configure it in Firebase Functions config.'
      );
    }

    const genAI = new GoogleGenerativeAI(apiKey);
    // Use gemini-pro-vision if images are provided, otherwise use gemini-pro
    const imagePaths = data.imagePaths || [];
    const hasImages = Array.isArray(imagePaths) && imagePaths.length > 0;
    const modelName = hasImages ? 'gemini-pro-vision' : 'gemini-pro';
    const model = genAI.getGenerativeModel({ model: modelName });

    const conversationText = data.conversationText || '';

    if (!conversationText || conversationText.trim().length === 0) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Conversation text is required'
      );
    }

    // Build prompt
    let prompt = `Please summarize the following conversation into a thoughtful, reflective diary entry. 
The summary should:
- Capture the main themes and emotions discussed
- Be written in first person (as if the user wrote it)
- Be warm, reflective, and personal
- Maintain the emotional tone of the conversation
- Be well-structured and readable
- Feel like a natural journal entry`;

    if (hasImages) {
      prompt += `\n- Include descriptions of any images shared in the conversation
- Connect the visual content with the emotional themes discussed`;
    }

    prompt += `\n\nConversation:
${conversationText}

Please provide a summary that feels like a personal diary entry reflecting on this conversation.`;

    let result;
    if (hasImages) {
      // For vision model, we need to read images and convert to base64
      // Note: This requires images to be accessible from the function
      // For now, we'll use text-only but structure it for future image support
      const fs = require('fs');
      const parts: any[] = [{ text: prompt }];

      // Try to read images if they're file paths (for local testing)
      // In production, images should be uploaded to Firebase Storage first
      for (const imagePath of imagePaths) {
        try {
          if (fs.existsSync(imagePath)) {
            const imageData = fs.readFileSync(imagePath);
            const base64Image = imageData.toString('base64');
            parts.push({
              inlineData: {
                data: base64Image,
                mimeType: 'image/jpeg', // Default, should detect from file
              },
            });
          }
        } catch (err) {
          console.warn(`Could not read image at ${imagePath}:`, err);
        }
      }

      result = await model.generateContent(parts);
    } else {
      result = await model.generateContent(prompt);
    }

    const response = result.response;
    const summary = response.text();

    if (!summary || summary.trim().length === 0) {
      throw new functions.https.HttpsError(
        'internal',
        'Summary generation returned empty result'
      );
    }

    return { summary: summary.trim() };
  } catch (error: any) {
    console.error('Error in geminiSummarize:', error);
    console.error('Error details:', JSON.stringify(error, null, 2));

    // Handle specific Gemini API errors
    if (error.message?.includes('API key') || error.message?.includes('GEMINI_API_KEY')) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Invalid Gemini API key. Please check your configuration.'
      );
    }

    // Handle timeout errors
    if (error.message?.includes('timeout') || error.message?.includes('timed out')) {
      throw new functions.https.HttpsError(
        'deadline-exceeded',
        'Summary generation timed out. Please try again.'
      );
    }

    throw new functions.https.HttpsError(
      'internal',
      'Failed to generate summary',
      error.message || 'Unknown error occurred'
    );
  }
});
