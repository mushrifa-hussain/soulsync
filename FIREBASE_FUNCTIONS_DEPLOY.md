# Firebase Functions Deployment Guide

## Prerequisites
1. Firebase CLI installed: `npm install -g firebase-tools`
2. Firebase project initialized: `firebase login` and `firebase init`
3. Gemini API key from: https://makersuite.google.com/app/apikey

## Step 1: Install Dependencies
```bash
cd functions
npm install
```

## Step 2: Set Gemini API Key

### Option A: Environment Variable (Recommended for local development)
```bash
export GEMINI_API_KEY="your-api-key-here"
```

### Option B: Firebase Functions Config (Recommended for production)
```bash
firebase functions:config:set gemini.api_key="your-api-key-here"
```

## Step 3: Build Functions
```bash
cd functions
npm run build
```

## Step 4: Deploy Functions
```bash
# From project root
firebase deploy --only functions
```

Or deploy specific functions:
```bash
firebase deploy --only functions:geminiChat,functions:geminiSummarize
```

## Step 5: Verify Deployment
Check Firebase Console → Functions to see deployed functions.

## Troubleshooting

### If you get "function does not exist" error:
1. Make sure functions are deployed: `firebase deploy --only functions`
2. Check Firebase Console to verify functions are listed
3. Wait a few minutes after deployment for functions to be fully available

### If you get "API key not configured" error:
1. Set the API key using one of the methods above
2. Redeploy functions after setting the key

### To view function logs:
```bash
firebase functions:log
```

## Functions Included
- `geminiChat` - Handles AI chat conversations
- `geminiSummarize` - Creates diary entry summaries from conversations
- `syncLocalToCloud` - Syncs local diary entries to Firestore
- `backupNow` - Forces immediate backup
- `onAuthCreate` - Creates user document on signup

