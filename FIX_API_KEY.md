# 🔧 Fix: API Key Not Working

If you're still seeing "AI service needs configuration" after setting up, try these steps:

## Method 1: Using Environment Variable (Recommended)

This is more reliable than config:

### Step 1: Get Your API Key
1. Go to: https://makersuite.google.com/app/apikey
2. Copy your API key

### Step 2: Set Environment Variable
Open terminal/PowerShell in your project root and run:

**For Windows (PowerShell):**
```powershell
$env:GEMINI_API_KEY="YOUR_API_KEY_HERE"
```

**For Windows (CMD):**
```cmd
set GEMINI_API_KEY=YOUR_API_KEY_HERE
```

**For Mac/Linux:**
```bash
export GEMINI_API_KEY="YOUR_API_KEY_HERE"
```

### Step 3: Deploy Functions
```bash
firebase deploy --only functions
```

**Note:** Environment variables set this way only work for the current session. For permanent setup, use Method 2.

---

## Method 2: Using Firebase Config (Permanent)

### Step 1: Set Config
```bash
firebase functions:config:set gemini.api_key="YOUR_API_KEY_HERE"
```

### Step 2: Verify Config is Set
```bash
firebase functions:config:get
```

You should see:
```json
{
  "gemini": {
    "api_key": "YOUR_API_KEY_HERE"
  }
}
```

### Step 3: Deploy Functions
```bash
cd functions
npm run build
cd ..
firebase deploy --only functions
```

---

## Method 3: Check Current Config

Run this to see what's currently set:
```bash
firebase functions:config:get
```

If you see `{}` or no `gemini` section, the config isn't set.

---

## Method 4: Use .env File (Alternative)

Create a `.env` file in the `functions` folder:

```env
GEMINI_API_KEY=YOUR_API_KEY_HERE
```

Then update `functions/package.json` to load it:
```json
{
  "scripts": {
    "build": "tsc",
    "deploy": "firebase deploy --only functions"
  }
}
```

And install `dotenv`:
```bash
cd functions
npm install dotenv
```

Then in `functions/src/index.ts`, add at the top:
```typescript
import * as dotenv from 'dotenv';
dotenv.config();
```

---

## Troubleshooting

### Check Function Logs
1. Go to Firebase Console
2. Functions → geminiChat → Logs
3. Look for "API Key check: Found" or "API Key check: Not found"

### Verify Deployment
1. Firebase Console → Functions
2. Should see `geminiChat` and `geminiSummarize` deployed
3. Check their status (should be green/active)

### Test the Config
After setting config, wait 1-2 minutes before testing again. Sometimes there's a delay.

---

## Quick Test Command

After setting up, test if the key is accessible:

```bash
# Check if config is set
firebase functions:config:get | grep gemini

# Should output something like:
# "gemini": {
#   "api_key": "AIza..."
```

If nothing shows, the config isn't set correctly.

