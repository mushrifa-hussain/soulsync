# 🚀 SoulSync AI Chat - Complete Setup Guide

## ✅ What's Already Done
- ✅ AI Chat UI implemented
- ✅ Firebase Functions code written (`geminiChat` and `geminiSummarize`)
- ✅ Chat history storage implemented
- ✅ Error handling improved
- ✅ Keyboard overflow fixed
- ✅ Chat clears on back/summarize

## 📋 What You Need to Do

### Step 1: Install Firebase CLI (if not already installed)
```bash
npm install -g firebase-tools
```

### Step 2: Login to Firebase
```bash
firebase login
```
This will open a browser for authentication.

### Step 3: Get Gemini API Key
1. Go to: https://makersuite.google.com/app/apikey
2. Sign in with your Google account
3. Click "Create API Key"
4. Copy the API key (you'll need it in Step 5)

### Step 4: Install Function Dependencies
```bash
cd functions
npm install
cd ..
```

### Step 5: Set Gemini API Key
**Option A: Firebase Functions Config (Recommended for production)**
```bash
firebase functions:config:set gemini.api_key="YOUR_API_KEY_HERE"
```
Replace `YOUR_API_KEY_HERE` with the key from Step 3.

**Option B: Environment Variable (For local testing)**
```bash
# Windows PowerShell
$env:GEMINI_API_KEY="YOUR_API_KEY_HERE"

# Windows CMD
set GEMINI_API_KEY=YOUR_API_KEY_HERE

# Mac/Linux
export GEMINI_API_KEY="YOUR_API_KEY_HERE"
```

### Step 6: Build Functions
```bash
cd functions
npm run build
cd ..
```

### Step 7: Deploy Functions
```bash
firebase deploy --only functions
```

This will deploy:
- `geminiChat` - For AI conversations
- `geminiSummarize` - For creating diary summaries
- Other existing functions (syncLocalToCloud, backupNow, etc.)

**Expected output:**
```
✔  functions[geminiChat(us-central1)] Successful create operation.
✔  functions[geminiSummarize(us-central1)] Successful create operation.
✔  Deploy complete!
```

### Step 8: Verify Deployment
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `soulsync-dairyapp`
3. Navigate to **Functions** in the left menu
4. You should see `geminiChat` and `geminiSummarize` listed

### Step 9: Test the AI Chat
1. Run your Flutter app
2. Navigate to AI Chat (tap the AI face icon on home screen)
3. Send a message like "hi"
4. You should get a response from SoulSync AI!

## 🔧 Troubleshooting

### Error: "function does not exist"
**Solution:**
- Make sure you completed Step 7 (deploy functions)
- Wait 2-3 minutes after deployment
- Check Firebase Console to verify functions are deployed

### Error: "API key not configured"
**Solution:**
- Make sure you completed Step 5 (set API key)
- If using config method, redeploy: `firebase deploy --only functions`
- Verify key is set: `firebase functions:config:get`

### Error: "unauthenticated" or "permission denied"
**Solution:**
- Make sure you're logged in to Firebase in your app
- Check that Firebase Auth is properly initialized

### Functions won't build
**Solution:**
```bash
cd functions
rm -rf node_modules package-lock.json
npm install
npm run build
```

### To view function logs (for debugging)
```bash
firebase functions:log
```

## 📝 Quick Command Reference

```bash
# Install dependencies
cd functions && npm install && cd ..

# Set API key
firebase functions:config:set gemini.api_key="YOUR_KEY"

# Build
cd functions && npm run build && cd ..

# Deploy
firebase deploy --only functions

# View logs
firebase functions:log
```

## ✅ Checklist

Before testing, make sure:
- [ ] Firebase CLI installed
- [ ] Logged in to Firebase (`firebase login`)
- [ ] Gemini API key obtained
- [ ] Function dependencies installed (`npm install` in functions folder)
- [ ] API key configured (`firebase functions:config:set`)
- [ ] Functions built (`npm run build` in functions folder)
- [ ] Functions deployed (`firebase deploy --only functions`)
- [ ] Functions visible in Firebase Console

## 🎉 Once Everything is Deployed

Your AI chat will:
- ✅ Respond to messages with supportive, empathetic responses
- ✅ Remember conversation context
- ✅ Generate diary entry summaries after 3+ messages
- ✅ Clear chat history on back button or after summarizing
- ✅ Handle errors gracefully with helpful messages

---

**Need Help?** Check the logs: `firebase functions:log`

