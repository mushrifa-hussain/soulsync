# ⚡ Quick Setup - AI Chat

## The Error You're Seeing
```
Invalid Gemini API key. Please check your configuration.
```

This means:
- ✅ Functions ARE deployed (good!)
- ❌ API key is NOT set (needs fixing)

## Fix in 3 Steps:

### Step 1: Get API Key
1. Go to: https://makersuite.google.com/app/apikey
2. Sign in
3. Click "Create API Key"
4. Copy the key

### Step 2: Set API Key
Open terminal/PowerShell in your project root and run:

```bash
firebase functions:config:set gemini.api_key="YOUR_API_KEY_HERE"
```

Replace `YOUR_API_KEY_HERE` with the key from Step 1.

### Step 3: Redeploy Functions
```bash
firebase deploy --only functions
```

Wait 2-3 minutes, then test the AI chat again!

---

## Full Setup (If Functions Aren't Deployed Yet)

If you see "function does not exist" error instead:

```bash
# 1. Install dependencies
cd functions
npm install
cd ..

# 2. Set API key
firebase functions:config:set gemini.api_key="YOUR_API_KEY_HERE"

# 3. Build
cd functions
npm run build
cd ..

# 4. Deploy
firebase deploy --only functions
```

---

## Verify It's Working

After deployment, check:
1. Firebase Console → Functions → Should see `geminiChat` and `geminiSummarize`
2. Test in app → Send "hi" → Should get AI response (not error)

