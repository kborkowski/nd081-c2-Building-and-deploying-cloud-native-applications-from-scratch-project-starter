# Screenshot Guide for Neighborly Project

## ✅ Backend Setup Complete
- ✅ Event Grid Topic: `neighborly-events` created
- ✅ Event Grid Subscription: Connected to `eventHubTrigger` function  
- ✅ Functions updated and deployed with Event Grid support
- ✅ createAdvertisement now publishes events to Event Grid

---

## 📸 SCREENSHOTS REQUIRED (7 total)

### Part 1: Serverless Functions (5 screenshots)

#### Screenshot 1: CosmosDB Database & Collections
**Where to capture:**
1. Go to Azure Portal: https://portal.azure.com
2. Navigate to: Resource Groups → `neighborly-rg` → `neighborly-cosmos-31d11477`
3. Click on "Data Explorer" in the left menu
4. Expand `neighborlydb` to show both collections: `advertisements` and `posts`
5. **Take screenshot showing the database name and both collections**

#### Screenshot 2: Data Import Confirmation
**Terminal Command:**
```bash
source deployment-vars.sh

echo "=== Data Import Verification ==="
mongosh "$CONNECTION_STRING" --quiet --eval "
  db = db.getSiblingDB('neighborlydb');
  print('Advertisements count: ' + db.advertisements.countDocuments());
  print('Posts count: ' + db.posts.countDocuments());
  print('\\nSample Advertisement:');
  printjson(db.advertisements.findOne());
"
```
**Take screenshot of terminal output showing 5 advertisements and 4 posts**

#### Screenshot 3: Function App Endpoints
**Where to capture:**
1. Go to Azure Portal
2. Navigate to: Resource Groups → `neighborly-rg` → `neighborly-api-975aba8a`
3. Click on "Functions" in the left menu
4. **Take screenshot showing all 8 functions with their trigger types**

#### Screenshot 4: API Response from getAdvertisements
**Terminal Command:**
```bash
echo "=== getAdvertisements Endpoint Test ===" && \
echo "URL: https://neighborly-api-975aba8a.azurewebsites.net/api/getadvertisements" && \
echo "" && \
curl -s https://neighborly-api-975aba8a.azurewebsites.net/api/getadvertisements | jq '.[0:2]'
```
**Take screenshot showing JSON response with advertisement data**

#### Screenshot 5: Frontend on Localhost
```bash
cd /workspaces/nd081-c2-Building-and-deploying-cloud-native-applications-from-scratch-project-starter/NeighborlyFrontEnd
pkill -9 python3
python3 app.py &
sleep 5
```
**Then open port 5000 in browser and take screenshot showing posts**

---

### Part 2: Logic App & Event Grid (2 screenshots)

#### ⚠️ MANUAL STEP: Configure Logic App in Azure Portal

**YOU MUST DO THIS IN THE PORTAL FIRST:**

1. Go to: https://portal.azure.com
2. Navigate to: Resource Groups → `neighborly-rg` → `neighborly-notification-logic`
3. Click "Logic app designer"
4. Add HTTP Request trigger:
   - Click "Add a trigger" → Search "HTTP" → "When a HTTP request is received"
   - Add Request Body JSON Schema:
   ```json
   {
     "type": "object",
     "properties": {
       "title": {"type": "string"},
       "description": {"type": "string"},
       "eventType": {"type": "string"}
     }
   }
   ```
5. Add Email action:
   - Click "+ New step" → Search "Send an email" → "Send an email (V2)" (Office 365)
   - Sign in with: **v-krbork@microsoft.com**
   - To: `v-krbork@microsoft.com`
   - Subject: `New Advertisement: ` + dynamic content `title`
   - Body: Add dynamic content for title, description, eventType
6. Click "Save"
7. Copy the "HTTP POST URL" from the trigger

#### Screenshot 6: Logic App Email Notification
```bash
# Replace <URL> with your Logic App callback URL from above
LOGIC_APP_URL="<PASTE_YOUR_CALLBACK_URL_HERE>"

curl -X POST "$LOGIC_APP_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Advertisement from Neighborly",
    "description": "Testing Logic App email notification",
    "eventType": "test.notification"
  }'
```
**Check email inbox and take screenshot of the notification email**

#### Screenshot 7: Event Grid Success Count
```bash
# Create advertisement to trigger Event Grid
curl -X POST https://neighborly-api-975aba8a.azurewebsites.net/api/createadvertisement \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Event Grid Test Ad",
    "description": "Testing Event Grid integration",
    "price": "$100",
    "city": "Seattle"
  }'
```
**Then in Azure Portal:**
1. Go to: `neighborly-api-975aba8a` → Functions → `eventHubTrigger` → Monitor
2. Wait 1-2 minutes for invocations
3. **Take screenshot showing successful executions**

---

## 🔗 Quick Reference

| Resource | Name | URL |
|----------|------|-----|
| Function App | neighborly-api-975aba8a | https://neighborly-api-975aba8a.azurewebsites.net |
| CosmosDB | neighborly-cosmos-31d11477 | Portal → Data Explorer |
| Event Grid | neighborly-events | Portal → Metrics |
| Logic App | neighborly-notification-logic | Portal → Designer |
| Resource Group | neighborly-rg | Portal → Overview |

---

## ✅ Screenshot Checklist

- [ ] 01: CosmosDB - Database & Collections visible
- [ ] 02: Terminal - 5 ads + 4 posts confirmed
- [ ] 03: Function App - All 8 functions listed
- [ ] 04: Terminal - getAdvertisements JSON response
- [ ] 05: Browser - Frontend localhost showing posts
- [ ] 06: Email - Logic App notification received
- [ ] 07: Portal - eventHubTrigger Monitor showing success

---

## 🚨 Next: Kubernetes (Screenshots 8-10)

After completing these 7 screenshots, proceed to Phase 10 for Kubernetes deployment (Container Registry + AKS). **CREATE LAST, DELETE IMMEDIATELY** after screenshots to minimize costs (~$35/month).
