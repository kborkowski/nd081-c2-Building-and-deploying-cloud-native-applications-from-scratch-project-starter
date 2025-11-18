#!/bin/bash

# Neighborly Screenshot Helper Script
# This script provides easy commands for capturing screenshots

source deployment-vars.sh

show_menu() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║        NEIGHBORLY SCREENSHOT HELPER                            ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Choose a screenshot to prepare:"
    echo ""
    echo "  1) Screenshot 2: Verify data import (5 ads + 4 posts)"
    echo "  2) Screenshot 4: Test getAdvertisements API"
    echo "  3) Screenshot 5: Start frontend on localhost"
    echo "  4) Screenshot 6: Test Logic App (requires callback URL)"
    echo "  5) Screenshot 7: Create ad to trigger Event Grid"
    echo ""
    echo "  6) Show all resource URLs"
    echo "  7) Check Event Grid status"
    echo "  0) Exit"
    echo ""
    read -p "Enter choice [0-7]: " choice
}

verify_data() {
    echo ""
    echo "═══ Screenshot 2: Data Import Verification ═══"
    echo ""
    mongosh "$CONNECTION_STRING" --quiet --eval "
      db = db.getSiblingDB('neighborlydb');
      print('Advertisements count: ' + db.advertisements.countDocuments());
      print('Posts count: ' + db.posts.countDocuments());
      print('');
      print('Sample Advertisement:');
      printjson(db.advertisements.findOne());
      print('');
      print('Sample Post:');
      printjson(db.posts.findOne());
    "
    echo ""
    echo "✓ Take screenshot of this output"
}

test_api() {
    echo ""
    echo "═══ Screenshot 4: API Response Test ═══"
    echo ""
    echo "URL: https://${FUNCTION_APP_NAME}.azurewebsites.net/api/getadvertisements"
    echo ""
    curl -s "https://${FUNCTION_APP_NAME}.azurewebsites.net/api/getadvertisements" | jq '.[0:2]'
    echo ""
    echo "Total count:"
    curl -s "https://${FUNCTION_APP_NAME}.azurewebsites.net/api/getadvertisements" | jq 'length'
    echo ""
    echo "✓ Take screenshot of this output"
}

start_frontend() {
    echo ""
    echo "═══ Screenshot 5: Starting Frontend ═══"
    echo ""
    cd NeighborlyFrontEnd
    pkill -9 python3 2>/dev/null
    sleep 2
    python3 app.py > /tmp/flask.log 2>&1 &
    sleep 5
    echo "✓ Frontend started on port 5000"
    echo ""
    echo "Next steps:"
    echo "1. Go to VS Code → Ports tab"
    echo "2. Find port 5000"
    echo "3. Click globe icon to open in browser"
    echo "4. Take screenshot showing posts"
}

test_logic_app() {
    echo ""
    echo "═══ Screenshot 6: Testing Logic App ═══"
    echo ""
    echo "⚠️  FIRST: Configure Logic App in Azure Portal"
    echo "   See SCREENSHOT_GUIDE.md for instructions"
    echo ""
    read -p "Have you configured the Logic App? (y/n): " configured
    if [[ "$configured" != "y" ]]; then
        echo "Please configure Logic App first, then run this again"
        return
    fi
    echo ""
    read -p "Enter your Logic App callback URL: " LOGIC_APP_URL
    echo ""
    echo "Sending test request..."
    curl -X POST "$LOGIC_APP_URL" \
      -H "Content-Type: application/json" \
      -d '{
        "title": "Test Advertisement from Neighborly",
        "description": "Testing Logic App email notification",
        "eventType": "test.notification"
      }'
    echo ""
    echo ""
    echo "✓ Request sent!"
    echo "Check email inbox for v-krbork@microsoft.com"
    echo "Take screenshot of the email"
}

trigger_event_grid() {
    echo ""
    echo "═══ Screenshot 7: Triggering Event Grid ═══"
    echo ""
    echo "Creating advertisement to trigger Event Grid..."
    echo ""
    curl -X POST "https://${FUNCTION_APP_NAME}.azurewebsites.net/api/createadvertisement" \
      -H "Content-Type: application/json" \
      -d '{
        "title": "Event Grid Test Advertisement",
        "description": "Testing Event Grid and Function integration",
        "price": "$100",
        "city": "Seattle"
      }'
    echo ""
    echo ""
    echo "✓ Advertisement created!"
    echo ""
    echo "Next steps:"
    echo "1. Wait 1-2 minutes"
    echo "2. Go to Azure Portal"
    echo "3. Navigate to: ${FUNCTION_APP_NAME} → Functions → eventHubTrigger → Monitor"
    echo "4. Take screenshot showing successful invocations"
}

show_urls() {
    echo ""
    echo "═══ Resource URLs ═══"
    echo ""
    echo "Azure Portal: https://portal.azure.com"
    echo "Resource Group: ${RESOURCE_GROUP}"
    echo ""
    echo "Function App:"
    echo "  Name: ${FUNCTION_APP_NAME}"
    echo "  URL: https://${FUNCTION_APP_NAME}.azurewebsites.net"
    echo ""
    echo "CosmosDB:"
    echo "  Account: ${COSMOSDB_ACCOUNT}"
    echo "  Portal: Resource Groups → ${RESOURCE_GROUP} → ${COSMOSDB_ACCOUNT}"
    echo ""
    echo "Event Grid:"
    echo "  Topic: ${EVENTGRID_TOPIC}"
    echo "  Portal: Resource Groups → ${RESOURCE_GROUP} → ${EVENTGRID_TOPIC}"
    echo ""
    echo "Logic App:"
    echo "  Name: ${LOGIC_APP_NAME}"
    echo "  Portal: Resource Groups → ${RESOURCE_GROUP} → ${LOGIC_APP_NAME}"
    echo ""
}

check_event_grid() {
    echo ""
    echo "═══ Event Grid Status ═══"
    echo ""
    echo "Event Grid Topic: ${EVENTGRID_TOPIC}"
    az eventgrid topic show \
      --name ${EVENTGRID_TOPIC} \
      --resource-group ${RESOURCE_GROUP} \
      --query "{name:name, provisioningState:provisioningState, endpoint:endpoint}" \
      --output table
    echo ""
    echo "Event Subscription:"
    az eventgrid event-subscription show \
      --name neighborly-function-subscription \
      --source-resource-id "/subscriptions/e2c7cd99-c3c5-4a90-9109-02e7d50f8311/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.EventGrid/topics/${EVENTGRID_TOPIC}" \
      --query "{name:name, provisioningState:provisioningState, destination:destination.endpointType}" \
      --output table
    echo ""
}

# Main loop
while true; do
    show_menu
    case $choice in
        1) verify_data ;;
        2) test_api ;;
        3) start_frontend ;;
        4) test_logic_app ;;
        5) trigger_event_grid ;;
        6) show_urls ;;
        7) check_event_grid ;;
        0) echo "Goodbye!"; exit 0 ;;
        *) echo "Invalid choice" ;;
    esac
    read -p "Press Enter to continue..."
done
