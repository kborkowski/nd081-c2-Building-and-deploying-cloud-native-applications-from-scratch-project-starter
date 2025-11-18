# Logic App & Event Grid Setup Guide

## Part 1: Configure Logic App with HTTP Trigger & Email

### Step 1: Open Logic App in Azure Portal
1. Go to Azure Portal: https://portal.azure.com
2. Navigate to Resource Groups → `neighborly-rg`
3. Click on Logic App: `neighborly-notification-logic`
4. Click "Logic app designer" in the left menu

### Step 2: Configure HTTP Trigger
1. Click "+ New step" or "Add a trigger"
2. Search for "HTTP" and select "When a HTTP request is received"
3. In "Request Body JSON Schema", paste:
```json
{
  "type": "object",
  "properties": {
    "title": {
      "type": "string"
    },
    "description": {
      "type": "string"
    },
    "eventType": {
      "type": "string"
    }
  }
}
```

### Step 3: Add Email Action
1. Click "+ New step"
2. Search for "Send an email" and select "Send an email (V2)" from Office 365 Outlook
3. Sign in with your Microsoft account (v-krbork@microsoft.com)
4. Configure the email:
   - **To**: v-krbork@microsoft.com
   - **Subject**: `New Advertisement Posted: ` (then add dynamic content `title`)
   - **Body**: 
     ```
     Advertisement Notification
     
     Title: [add dynamic content: title]
     Description: [add dynamic content: description]
     Event Type: [add dynamic content: eventType]
     
     This notification was triggered by the Neighborly application.
     ```

### Step 4: Save and Get Callback URL
1. Click "Save" at the top
2. Go back to the HTTP trigger
3. Copy the "HTTP POST URL" - this is your callback URL
4. Save this URL for testing

---

## Part 2: Create Event Grid Subscription

Once Logic App is configured, run these commands:

```bash
# Load variables
source deployment-vars.sh

# Get the eventHubTrigger function URL
FUNCTION_URL="https://${FUNCTION_APP_NAME}.azurewebsites.net/api/eventHubTrigger"
echo "Function URL: $FUNCTION_URL"

# Get function key
FUNCTION_KEY=$(az functionapp keys list \
  --name $FUNCTION_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query "functionKeys.default" \
  --output tsv)

# Create Event Grid subscription with Azure Function endpoint
az eventgrid event-subscription create \
  --name neighborly-function-subscription \
  --source-resource-id "/subscriptions/e2c7cd99-c3c5-4a90-9109-02e7d50f8311/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.EventGrid/topics/${EVENTGRID_TOPIC}" \
  --endpoint-type azurefunction \
  --endpoint "${FUNCTION_URL}?code=${FUNCTION_KEY}"
```

---

## Part 3: Update createAdvertisement Function to Publish Events

The createAdvertisement function will be updated to publish events to Event Grid when new advertisements are created.

---

## Testing Steps

### Test Logic App HTTP Trigger:
```bash
# Get your Logic App callback URL from Azure Portal
LOGIC_APP_URL="<paste-your-callback-url-here>"

# Test the Logic App
curl -X POST "$LOGIC_APP_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Advertisement",
    "description": "Testing Logic App email notification",
    "eventType": "advertisement.created"
  }'

# Check your email inbox for the notification
```

### Test Event Grid + Function:
After updating the createAdvertisement function, create a new advertisement to trigger the event flow.

---

## Screenshot Checklist

### Serverless Functions (Screenshots 1-5):
- [ ] 01: CosmosDB database & collections in Azure Portal
- [ ] 02: Terminal showing data import (5 ads, 4 posts) OR live website showing data
- [ ] 03: Function App endpoints list with URLs in Azure Portal
- [ ] 04: getAdvertisements API response (showing data)
- [ ] 05: Frontend on localhost showing posts

### Logic App & Event Grid (Screenshots 6-7):
- [ ] 06: Email notification in inbox from Logic App
- [ ] 07: Event Grid success count in Azure Function Monitor tab
