#!/bin/bash
# Bicep Deployment Script for Neighborly Infrastructure
# This script deploys the complete Neighborly app infrastructure using Bicep

set -e

echo "🚀 Neighborly Infrastructure Deployment (Bicep)"
echo "================================================"
echo ""

# Configuration
RESOURCE_GROUP="${RESOURCE_GROUP:-neighborly-rg}"
LOCATION="${LOCATION:-eastus}"
NOTIFICATION_EMAIL="${NOTIFICATION_EMAIL:-}"
DEPLOY_AKS="${DEPLOY_AKS:-false}"
DEPLOY_ACR="${DEPLOY_ACR:-false}"

# Check if Azure CLI is logged in
if ! az account show &>/dev/null; then
    echo "❌ Not logged in to Azure CLI"
    echo "Please run: az login"
    exit 1
fi

SUBSCRIPTION=$(az account show --query name -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

echo "📋 Deployment Configuration:"
echo "  Subscription: $SUBSCRIPTION"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Location: $LOCATION"
echo "  Deploy AKS: $DEPLOY_AKS"
echo "  Deploy ACR: $DEPLOY_ACR"
echo ""

# Prompt for email if not set
if [ -z "$NOTIFICATION_EMAIL" ]; then
    read -p "Enter email for notifications (or press Enter to skip): " NOTIFICATION_EMAIL
fi

# Create resource group
echo "📦 Creating resource group..."
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output table

echo ""
echo "🔨 Validating Bicep template..."
az deployment group validate \
  --resource-group "$RESOURCE_GROUP" \
  --template-file neighborly-infrastructure.bicep \
  --parameters location="$LOCATION" \
               environment="dev" \
               notificationEmail="$NOTIFICATION_EMAIL" \
               deployAKS=$DEPLOY_AKS \
               deployACR=$DEPLOY_ACR

echo ""
echo "🚀 Deploying infrastructure (this takes 5-10 minutes)..."
DEPLOYMENT_OUTPUT=$(az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file neighborly-infrastructure.bicep \
  --parameters location="$LOCATION" \
               environment="dev" \
               notificationEmail="$NOTIFICATION_EMAIL" \
               deployAKS=$DEPLOY_AKS \
               deployACR=$DEPLOY_ACR \
  --output json)

echo ""
echo "✅ Infrastructure deployed successfully!"
echo ""

# Extract outputs
COSMOS_CONNECTION=$(echo $DEPLOYMENT_OUTPUT | jq -r '.properties.outputs.cosmosConnectionString.value')
FUNCTION_APP_NAME=$(echo $DEPLOYMENT_OUTPUT | jq -r '.properties.outputs.functionAppName.value')
FUNCTION_APP_URL=$(echo $DEPLOYMENT_OUTPUT | jq -r '.properties.outputs.functionAppUrl.value')
EVENT_GRID_ENDPOINT=$(echo $DEPLOYMENT_OUTPUT | jq -r '.properties.outputs.eventGridTopicEndpoint.value')
EVENT_GRID_KEY=$(echo $DEPLOYMENT_OUTPUT | jq -r '.properties.outputs.eventGridTopicKey.value')
LOGIC_APP_URL=$(echo $DEPLOYMENT_OUTPUT | jq -r '.properties.outputs.logicAppTriggerUrl.value')

# Save to deployment-vars.sh
cat > deployment-vars.sh <<EOF
# Neighborly Deployment Variables
# Generated: $(date)
export RESOURCE_GROUP="$RESOURCE_GROUP"
export LOCATION="$LOCATION"
export FUNCTION_APP_NAME="$FUNCTION_APP_NAME"
export CONNECTION_STRING="$COSMOS_CONNECTION"
export EVENT_GRID_ENDPOINT="$EVENT_GRID_ENDPOINT"
export EVENT_GRID_KEY="$EVENT_GRID_KEY"
export LOGIC_APP_URL="$LOGIC_APP_URL"
export API_URL="$FUNCTION_APP_URL/api"
EOF

echo "📝 Configuration saved to deployment-vars.sh"
echo ""
echo "📊 Deployment Outputs:"
echo "  Function App: $FUNCTION_APP_NAME"
echo "  API URL: $FUNCTION_APP_URL/api"
echo "  Event Grid Endpoint: $EVENT_GRID_ENDPOINT"
echo ""

# Import sample data
echo "📦 Importing sample data to Cosmos DB..."
if command -v mongoimport &> /dev/null; then
    mongoimport --uri="$COSMOS_CONNECTION" --db=neighborlydb --collection=advertisements --file=sample_data/sampleAds.json --jsonArray
    mongoimport --uri="$COSMOS_CONNECTION" --db=neighborlydb --collection=posts --file=sample_data/samplePosts.json --jsonArray
    echo "✅ Sample data imported"
else
    echo "⚠️  mongoimport not found. Install with: sudo apt-get install mongodb-clients"
    echo "   Then run manually:"
    echo "   mongoimport --uri=\"\$CONNECTION_STRING\" --db=neighborlydb --collection=advertisements --file=sample_data/sampleAds.json --jsonArray"
    echo "   mongoimport --uri=\"\$CONNECTION_STRING\" --db=neighborlydb --collection=posts --file=sample_data/samplePosts.json --jsonArray"
fi

echo ""
echo "🚀 Deploying Function App code..."
cd NeighborlyAPI
func azure functionapp publish "$FUNCTION_APP_NAME" --python
cd ..

echo ""
echo "✅ Deployment Complete!"
echo "======================="
echo ""
echo "🧪 Test the API:"
echo "  curl $FUNCTION_APP_URL/api/getAdvertisements"
echo "  curl $FUNCTION_APP_URL/api/getPosts"
echo ""
echo "🏠 Run frontend locally:"
echo "  source deployment-vars.sh"
echo "  cd NeighborlyFrontEnd"
echo "  export API_URL=\"$FUNCTION_APP_URL/api\""
echo "  export CONNECTION_STRING=\"\$CONNECTION_STRING\""
echo "  python3 app.py"
echo "  Open: http://localhost:5000"
echo ""
echo "💰 Cost Estimate:"
echo "  - Cosmos DB (400 RU/s): ~\$24/month"
echo "  - Function App (Consumption): ~\$0-5/month"
echo "  - Storage Account: ~\$1/month"
echo "  - Event Grid: ~\$0.60/million ops"
echo "  - Total: ~\$25-30/month"
echo ""
echo "🗑️  To delete all resources:"
echo "  az group delete --name $RESOURCE_GROUP --yes --no-wait"
echo ""
