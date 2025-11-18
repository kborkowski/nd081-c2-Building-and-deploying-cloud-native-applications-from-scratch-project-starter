#!/bin/bash
set -e

echo "🚀 Quick Deployment: Functions + Local Frontend Setup"
echo "====================================================="

# Load or create deployment variables
if [ ! -f deployment-vars.sh ]; then
    echo "📝 Creating deployment-vars.sh..."
    SUFFIX=$(echo $RANDOM | md5sum | head -c 8)
    cat > deployment-vars.sh <<EOF
export RESOURCE_GROUP="neighborly-rg"
export LOCATION="eastus"
export COSMOS_ACCOUNT="neighborly-cosmos-$SUFFIX"
export DATABASE_NAME="neighborlydb"
export FUNCTION_APP_NAME="neighborly-api-$SUFFIX"
export STORAGE_ACCOUNT="neighborlysto$SUFFIX"
export EVENT_GRID_TOPIC="neighborly-events"
export CONNECTION_STRING=""
EOF
fi

source deployment-vars.sh

echo ""
echo "🔧 Configuration:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Location: $LOCATION"
echo "  Function App: $FUNCTION_APP_NAME"
echo "  Cosmos DB: $COSMOS_ACCOUNT"
echo ""

# 1. Create Resource Group
echo "📦 Step 1/7: Creating resource group..."
az group create --name $RESOURCE_GROUP --location $LOCATION --output table

# 2. Create Cosmos DB
echo "📦 Step 2/7: Creating Cosmos DB (3-5 minutes)..."
az cosmosdb create \
  --name $COSMOS_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --kind MongoDB \
  --default-consistency-level Eventual \
  --enable-automatic-failover false \
  --output table

# Get connection string
echo "🔐 Getting Cosmos DB connection string..."
CONNECTION_STRING=$(az cosmosdb keys list \
  --name $COSMOS_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --type connection-strings \
  --query "connectionStrings[0].connectionString" \
  --output tsv)

# Update deployment-vars.sh
sed -i "s|export CONNECTION_STRING=.*|export CONNECTION_STRING=\"$CONNECTION_STRING\"|" deployment-vars.sh

# 3. Create database and collections
echo "📦 Step 3/7: Creating database and collections..."
az cosmosdb mongodb database create \
  --account-name $COSMOS_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --name $DATABASE_NAME

az cosmosdb mongodb collection create \
  --account-name $COSMOS_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --database-name $DATABASE_NAME \
  --name advertisements \
  --shard "_id"

az cosmosdb mongodb collection create \
  --account-name $COSMOS_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --database-name $DATABASE_NAME \
  --name posts \
  --shard "_id"

# 4. Import sample data
echo "📦 Step 4/7: Importing sample data..."
if command -v mongoimport &> /dev/null; then
    mongoimport --uri="$CONNECTION_STRING" --db=neighborlydb --collection=advertisements --file=sample_data/sampleAds.json --jsonArray
    mongoimport --uri="$CONNECTION_STRING" --db=neighborlydb --collection=posts --file=sample_data/samplePosts.json --jsonArray
else
    echo "⚠️  mongoimport not available, install with: sudo apt-get install mongodb-clients"
fi

# 5. Create Storage Account
echo "📦 Step 5/7: Creating storage account..."
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS \
  --output table

# 6. Create Function App
echo "📦 Step 6/7: Creating Function App..."
az functionapp create \
  --name $FUNCTION_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --storage-account $STORAGE_ACCOUNT \
  --consumption-plan-location $LOCATION \
  --runtime python \
  --runtime-version 3.9 \
  --functions-version 4 \
  --os-type Linux \
  --output table

# Set connection string
echo "🔐 Configuring Function App settings..."
az functionapp config appsettings set \
  --name $FUNCTION_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings "CosmosDb=$CONNECTION_STRING" \
  --output table

# 7. Deploy Functions
echo "📦 Step 7/7: Deploying functions to Azure..."
cd NeighborlyAPI
func azure functionapp publish $FUNCTION_APP_NAME --python

echo ""
echo "✅ Deployment Complete!"
echo "======================="
echo ""
echo "🌐 Function App URL: https://$FUNCTION_APP_NAME.azurewebsites.net"
echo ""
echo "📋 Testing endpoints:"
echo "  curl https://$FUNCTION_APP_NAME.azurewebsites.net/api/getAdvertisements"
echo "  curl https://$FUNCTION_APP_NAME.azurewebsites.net/api/getPosts"
echo ""
echo "🏠 Now run the frontend locally:"
echo "  cd NeighborlyFrontEnd"
echo "  python3 app.py"
echo "  Open: http://localhost:5000"
echo ""
