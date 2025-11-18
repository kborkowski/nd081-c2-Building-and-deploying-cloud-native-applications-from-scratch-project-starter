# NeighborlyAPI - Azure Deployment Plan

## Overview
This document outlines the complete deployment plan for the NeighborlyAPI application to Azure, including all required resources and configuration steps.

## Application Review

### Azure Functions Inventory
The NeighborlyAPI contains 8 HTTP-triggered functions:

1. **getAdvertisements** (GET) - Retrieves all advertisements from MongoDB
2. **getAdvertisement** (GET) - Retrieves a single advertisement by ID
3. **createAdvertisement** (POST) - Creates a new advertisement
4. **updateAdvertisement** (PUT) - Updates an existing advertisement
5. **deleteAdvertisement** (DELETE) - Deletes an advertisement by ID
6. **getPosts** (GET) - Retrieves all posts from MongoDB
7. **getPost** (GET) - Retrieves a single post by ID
8. **eventHubTrigger** - Event Grid triggered function (currently configured but not fully implemented)

### Current Configuration
- **Runtime**: Python 3.x
- **Dependencies**: azure-functions==1.2.1, pymongo==3.10.1
- **Database**: MongoDB (to be hosted in CosmosDB)
- **Collections**: `advertisements` and `posts`
- **Authentication**: Anonymous (all HTTP triggers)

### Issues to Address
- All functions currently point to `localhost` for MongoDB connection
- Database name hardcoded as `azure`
- Security concern: Using `eval()` in createAdvertisement and updateAdvertisement (should be replaced)
- All functions need connection string updates

---

## Pre-Deployment Checklist

### Required Tools Installation

#### Step 0.1: Install Azure CLI
```bash
# Install Azure CLI in Codespace
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Verify installation
az --version

# Login to Azure (will open browser for authentication)
az login --use-device-code
```

#### Step 0.2: Install Azure Functions Core Tools
```bash
# Install Azure Functions Core Tools v4
wget -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install azure-functions-core-tools-4

# Verify installation
func --version
```

#### Step 0.3: Install MongoDB Database Tools
```bash
# Install MongoDB tools for data import
wget -qO - https://www.mongodb.org/static/pgp/server-7.0.asc | sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
sudo apt-get update
sudo apt-get install -y mongodb-database-tools

# Verify installation
mongoimport --version
```

#### Step 0.4: Verify Existing Tools
```bash
# Already installed in Codespace:
python --version      # Python 3.12.1 ✓
docker --version      # Docker ✓
kubectl version       # Kubernetes CLI ✓
git --version         # Git ✓
```

#### Step 0.5: Verify Azure Subscription
```bash
# Check your Azure subscription and credits
az account show
az account list-locations -o table

# Set default subscription if you have multiple
az account set --subscription "<subscription-id>"
```

---

## Deployment Plan (FREE/CHEAPEST Tiers Only)

### Phase 1: Azure Resource Provisioning (Free/Low Cost)

#### Step 1.1: Create Resource Group
```bash
# Define variables
RESOURCE_GROUP="neighborly-rg"
LOCATION="eastus"  # Free tier available in most regions

# Create resource group (FREE)
az group create --name $RESOURCE_GROUP --location $LOCATION
```

#### Step 1.2: Create Storage Account
```bash
# Define variables
STORAGE_ACCOUNT="neighborlysa$(openssl rand -hex 4)"  # Adds random suffix for uniqueness

# Create storage account with cheapest SKU (FREE tier available)
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS \
  --kind StorageV2 \
  --access-tier Hot
```

#### Step 1.3: Create Azure Function App (Consumption Plan - Pay per Execution)
```bash
# Define variables
FUNCTION_APP_NAME="neighborly-api-$(openssl rand -hex 4)"  # Adds random suffix for uniqueness

# Create Linux-based Function App with Python runtime
# Consumption plan = FREE grant of 1M requests/month + 400,000 GB-s execution time
az functionapp create \
  --name $FUNCTION_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --storage-account $STORAGE_ACCOUNT \
  --consumption-plan-location $LOCATION \
  --runtime python \
  --runtime-version 3.9 \
  --os-type Linux \
  --functions-version 4
```

#### Step 1.4: Create CosmosDB Account (FREE TIER - 1000 RU/s)
```bash
# Define variables
COSMOSDB_ACCOUNT="neighborly-cosmos-$(openssl rand -hex 4)"

# Create CosmosDB account with MongoDB API and FREE TIER
# FREE TIER: First 1000 RU/s and 25 GB storage FREE forever
az cosmosdb create \
  --name $COSMOSDB_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --locations regionName=$LOCATION \
  --kind MongoDB \
  --server-version 4.2 \
  --default-consistency-level Session \
  --enable-free-tier true \
  --backup-policy-type Continuous

# Note: Only ONE free tier CosmosDB account per subscription
```

#### Step 1.5: Create MongoDB Database and Collections
```bash
# Define variables
DATABASE_NAME="neighborlydb"

# Wait for CosmosDB account to be fully provisioned
echo "Waiting for CosmosDB provisioning (this may take 5-10 minutes)..."
az cosmosdb show --name $COSMOSDB_ACCOUNT --resource-group $RESOURCE_GROUP --query "provisioningState"

# Create database with MINIMAL throughput
az cosmosdb mongodb database create \
  --account-name $COSMOSDB_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --name $DATABASE_NAME

# Create advertisements collection with minimal throughput
az cosmosdb mongodb collection create \
  --account-name $COSMOSDB_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --database-name $DATABASE_NAME \
  --name advertisements \
  --shard "_id" \
  --throughput 400

# Create posts collection with minimal throughput
az cosmosdb mongodb collection create \
  --account-name $COSMOSDB_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --database-name $DATABASE_NAME \
  --name posts \
  --shard "_id" \
  --throughput 400
```

#### Step 1.6: Retrieve CosmosDB Connection String
```bash
# Get the primary connection string
CONNECTION_STRING=$(az cosmosdb keys list \
  --name $COSMOSDB_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --type connection-strings \
  --query "connectionStrings[0].connectionString" \
  --output tsv)

echo "CosmosDB Connection String: $CONNECTION_STRING"
# SAVE THIS CONNECTION STRING - You'll need it for the next steps
```

#### Step 1.7: Configure Function App Settings
```bash
# Add CosmosDB connection string to Function App settings
az functionapp config appsettings set \
  --name $FUNCTION_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings "MyDbConnection=$CONNECTION_STRING"

# Verify settings
az functionapp config appsettings list \
  --name $FUNCTION_APP_NAME \
  --resource-group $RESOURCE_GROUP
```

---

### Phase 2: Data Import

#### Step 2.1: Install MongoDB Tools (if not already installed)
```bash
# For Ubuntu/Debian
sudo apt-get install mongodb-database-tools

# For macOS
brew install mongodb-database-tools
```

#### Step 2.2: Import Sample Data
```bash
# Navigate to the project directory
cd /workspaces/nd081-c2-Building-and-deploying-cloud-native-applications-from-scratch-project-starter

# Import advertisements
mongoimport \
  --uri "$CONNECTION_STRING" \
  --db neighborlydb \
  --collection advertisements \
  --file './sample_data/sampleAds.json' \
  --jsonArray

# Import posts
mongoimport \
  --uri "$CONNECTION_STRING" \
  --db neighborlydb \
  --collection posts \
  --file './sample_data/samplePosts.json' \
  --jsonArray
```

#### Step 2.3: Verify Data Import
```bash
# Connect to MongoDB and verify data
mongosh "$CONNECTION_STRING" --eval "use neighborlydb; db.advertisements.countDocuments(); db.posts.countDocuments();"
```

---

### Phase 3: Update Function Code

#### Step 3.1: Update Connection Strings in All Functions
Update the following files with the correct connection information:

**Files to update:**
- `NeighborlyAPI/createAdvertisement/__init__.py`
- `NeighborlyAPI/getAdvertisement/__init__.py`
- `NeighborlyAPI/getAdvertisements/__init__.py`
- `NeighborlyAPI/updateAdvertisement/__init__.py`
- `NeighborlyAPI/deleteAdvertisement/__init__.py`
- `NeighborlyAPI/getPost/__init__.py`
- `NeighborlyAPI/getPosts/__init__.py`

**Replace in each file:**
```python
# OLD CODE:
url = "localhost"  # TODO: Update with appropriate MongoDB connection information
client = pymongo.MongoClient(url)
database = client['azure']

# NEW CODE:
import os
url = os.environ.get('MyDbConnection')  # Connection string from app settings
client = pymongo.MongoClient(url)
database = client['neighborlydb']
```

**Collections mapping:**
- Advertisement functions → `database['advertisements']`
- Post functions → `database['posts']`

**Note:** Keep existing code as-is (including eval() usage). We're only updating connection strings for functionality, not making security improvements.

---

### Phase 4: Local Testing

#### Step 4.1: Setup Local Environment
```bash
# Navigate to NeighborlyAPI directory
cd NeighborlyAPI

# Create virtual environment
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

#### Step 4.2: Configure local.settings.json
Create or update `NeighborlyAPI/local.settings.json`:
```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "python",
    "FUNCTIONS_EXTENSION_VERSION": "~3",
    "MyDbConnection": "<YOUR_COSMOSDB_CONNECTION_STRING>"
  }
}
```

#### Step 4.3: Run Functions Locally
```bash
# Start the function app locally
func start

# Test endpoints (in another terminal or browser):
# http://localhost:7071/api/getadvertisements
# http://localhost:7071/api/getposts
# http://localhost:7071/api/getadvertisement?id=5ec34b22b5f7f6eac5f2ec3e
```

#### Step 4.4: Test with Postman or curl
```bash
# Test GET advertisements
curl http://localhost:7071/api/getadvertisements

# Test GET posts
curl http://localhost:7071/api/getposts

# Test GET single advertisement
curl "http://localhost:7071/api/getadvertisement?id=5ec34b22b5f7f6eac5f2ec3e"

# Test POST create advertisement
curl -X POST http://localhost:7071/api/createAdvertisement \
  -H "Content-Type: application/json" \
  -d '{"title":"Test Ad","description":"Testing","price":"$100","city":"TestCity"}'
```

---

### Phase 5: Deploy to Azure

#### Step 5.1: Prepare for Deployment
```bash
# Ensure you're in the NeighborlyAPI directory
cd /workspaces/nd081-c2-Building-and-deploying-cloud-native-applications-from-scratch-project-starter/NeighborlyAPI

# Make sure local.settings.json has all required settings
# The deployment will sync these settings to Azure
```

#### Step 5.2: Deploy Function App
```bash
# Deploy using Azure Functions Core Tools
func azure functionapp publish $FUNCTION_APP_NAME --python

# Alternative: Deploy using Azure CLI with zip deployment
# zip -r function-app.zip .
# az functionapp deployment source config-zip \
#   --resource-group $RESOURCE_GROUP \
#   --name $FUNCTION_APP_NAME \
#   --src function-app.zip
```

#### Step 5.3: Verify Deployment
```bash
# Get the function app URL
FUNCTION_APP_URL="https://${FUNCTION_APP_NAME}.azurewebsites.net"
echo "Function App URL: $FUNCTION_APP_URL"

# Test the deployed functions
curl "${FUNCTION_APP_URL}/api/getadvertisements"
curl "${FUNCTION_APP_URL}/api/getposts"
```

#### Step 5.4: Save Function App URL
```bash
# Save this URL for frontend configuration
echo "API Base URL: https://${FUNCTION_APP_NAME}.azurewebsites.net/api/"
# This URL will be needed to update the NeighborlyFrontEnd application
```

---

### Phase 6: Post-Deployment Configuration

#### Step 6.1: Configure CORS (if needed for frontend)
```bash
# Allow specific origins or all origins (for development)
az functionapp cors add \
  --name $FUNCTION_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --allowed-origins "*"

# For production, use specific domain:
# --allowed-origins "https://your-frontend-domain.com"
```

**Note:** Application Insights and Authentication are optional features for security/monitoring. Skipping these to keep the project simple and minimize costs.

---

### Phase 7: Update Frontend Application

#### Step 7.1: Update Frontend API URLs
Update the NeighborlyFrontEnd application to use the deployed Function App URL:

**File to update:** `NeighborlyFrontEnd/settings.py` or relevant configuration file

```python
# Replace localhost URLs with Azure Function App URL
API_URL = "https://<FUNCTION_APP_NAME>.azurewebsites.net/api/"

# Update all API endpoint references:
# GET_ADVERTISEMENTS_URL = f"{API_URL}getadvertisements"
# GET_POSTS_URL = f"{API_URL}getposts"
# etc.
```

---

## Cost Optimization Summary

### FREE or Near-FREE Resources
1. **Resource Group**: FREE
2. **Storage Account**: ~$0.02/GB (minimal usage = nearly FREE)
3. **Function App (Consumption Plan)**: FREE grant of 1M requests/month
4. **CosmosDB (Free Tier)**: FREE - First 1000 RU/s forever (ONE per subscription)
5. **App Service (F1 Tier)**: FREE - 60 CPU min/day
6. **Event Grid**: First 100,000 operations/month FREE
7. **Logic App (Consumption)**: First 4,000 actions/month FREE

### Low-Cost Resources (Only if needed for K8s)
8. **Container Registry (Basic)**: ~$5/month
9. **AKS (1 node, Standard_B2s)**: ~$30/month (OPTIONAL - for screenshots only)

### Total Estimated Cost
- **Without Kubernetes**: ~$0-2/month (mostly FREE)
- **With Kubernetes (for screenshots)**: ~$35/month
- **Recommendation**: Deploy everything except AKS first, test thoroughly, then create AKS cluster only when ready for K8s screenshots, and DELETE immediately after

### Cost Saving Tips
1. Delete AKS cluster immediately after taking screenshots
2. Use CosmosDB Free Tier (limit: 1 per subscription)
3. Stay within Function App free grant (1M requests)
4. Use F1 (Free) tier for App Service
5. Monitor costs daily in Azure Portal → Cost Management

---

## Resource Summary

### Resources Created (Cost-Optimized)
1. **Resource Group**: `neighborly-rg` (FREE)
2. **Storage Account**: `neighborlysa<random>` (Standard_LRS - cheapest)
3. **Function App**: `neighborly-api-<random>` (Consumption Plan - FREE grant)
4. **CosmosDB Account**: `neighborly-cosmos-<random>` (FREE TIER enabled)
5. **Database**: `neighborlydb`
6. **Collections**: `advertisements` (400 RU), `posts` (400 RU)
7. **App Service Plan**: `neighborly-frontend-plan` (F1 - FREE tier)
8. **Web App**: `neighborly-frontend-<random>` (FREE tier)
9. **Event Grid Topic**: `neighborly-events` (FREE tier)
10. **Logic App**: `neighborly-notification-logic` (Consumption - FREE tier)
11. **Container Registry**: `neighborlyacr<random>` (Basic - only if doing K8s)
12. **AKS Cluster**: `neighborly-aks-cluster` (OPTIONAL - delete after screenshots)

### Key Information to Save
- **Resource Group Name**: `neighborly-rg`
- **CosmosDB Connection String**: (Retrieved in Step 1.6)
- **Function App Name**: (Generated with random suffix)
- **Function App URL**: `https://<FUNCTION_APP_NAME>.azurewebsites.net/api/`
- **Storage Account Name**: (Generated with random suffix)

### API Endpoints (After Deployment)
- `GET` https://<FUNCTION_APP_NAME>.azurewebsites.net/api/getadvertisements
- `GET` https://<FUNCTION_APP_NAME>.azurewebsites.net/api/getadvertisement?id=<id>
- `POST` https://<FUNCTION_APP_NAME>.azurewebsites.net/api/createAdvertisement
- `PUT` https://<FUNCTION_APP_NAME>.azurewebsites.net/api/updateAdvertisement?id=<id>
- `DELETE` https://<FUNCTION_APP_NAME>.azurewebsites.net/api/deleteAdvertisement?id=<id>
- `GET` https://<FUNCTION_APP_NAME>.azurewebsites.net/api/getposts
- `GET` https://<FUNCTION_APP_NAME>.azurewebsites.net/api/getpost?id=<id>

---

## Project Notes

**This deployment focuses on FUNCTIONALITY ONLY, not security or production best practices.**

- Anonymous authentication on HTTP triggers (as per project requirements)
- No input validation or security hardening
- Default CORS settings (allows all origins)
- No rate limiting or advanced security features
- This is a learning project - not production-ready

---

## Troubleshooting

### Common Issues and Solutions

1. **Function fails to connect to CosmosDB**
   - Verify connection string in Function App settings
   - Check CosmosDB firewall rules (allow Azure services)
   - Verify database and collection names match code

2. **Deployment fails**
   - Ensure Python version compatibility (3.9)
   - Check requirements.txt for dependency conflicts
   - Verify Function App runtime settings

3. **Functions not appearing after deployment**
   - Check host.json version compatibility
   - Verify function.json bindings are correct
   - Review deployment logs in Azure Portal

4. **Data import fails**
   - Verify JSON file format (must be JSON array)
   - Check connection string includes database credentials
   - Ensure mongoimport tool is installed correctly

---

## Maintenance and Monitoring

### Regular Tasks
1. Monitor Application Insights for errors and performance
2. Review CosmosDB Request Units (RU) usage and optimize queries
3. Update Python runtime and dependencies regularly
4. Backup important data from CosmosDB
5. Review and rotate access keys periodically

### Cost Optimization
1. Use Consumption Plan for Function App (pay per execution)
2. Monitor CosmosDB RU usage and adjust provisioned throughput
3. Clean up unused resources
4. Use Azure Cost Management tools

---

## Next Steps

1. ✅ Execute Phase 1: Azure Resource Provisioning
2. ✅ Execute Phase 2: Data Import
3. ✅ Execute Phase 3: Update Function Code
4. ✅ Execute Phase 4: Local Testing
5. ✅ Execute Phase 5: Deploy to Azure
6. ✅ Execute Phase 6: Post-Deployment Configuration
7. ✅ Execute Phase 7: Update Frontend Application
8. ✅ Execute Phase 8: Setup Logic App & Event Grid
9. ✅ Execute Phase 9: Deploy Frontend to App Service
10. ✅ Execute Phase 10: Container & Kubernetes Deployment
11. ✅ Perform end-to-end testing
12. ✅ Document any customizations or deviations from plan
13. ✅ Capture all required screenshots for project submission

---

## Phase 8: Logic App & Event Grid Setup

### Overview
Configure Logic App to send email notifications when advertisements are created, and connect it to Event Grid for event-driven architecture.

### Step 8.1: Create Event Grid Topic
```bash
# Define variables
EVENTGRID_TOPIC="neighborly-events"

# Create Event Grid Topic
az eventgrid topic create \
  --name $EVENTGRID_TOPIC \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION

# Get Event Grid Topic endpoint and key
EVENTGRID_ENDPOINT=$(az eventgrid topic show \
  --name $EVENTGRID_TOPIC \
  --resource-group $RESOURCE_GROUP \
  --query "endpoint" \
  --output tsv)

EVENTGRID_KEY=$(az eventgrid topic key list \
  --name $EVENTGRID_TOPIC \
  --resource-group $RESOURCE_GROUP \
  --query "key1" \
  --output tsv)

echo "Event Grid Endpoint: $EVENTGRID_ENDPOINT"
echo "Event Grid Key: $EVENTGRID_KEY"
```

### Step 8.2: Create Logic App
```bash
# Create Logic App
LOGIC_APP_NAME="neighborly-notification-logic"

az logic workflow create \
  --name $LOGIC_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION
```

### Step 8.3: Configure Logic App Workflow (via Azure Portal)
1. Go to Azure Portal → Logic Apps → Select your Logic App
2. Click "Logic app designer"
3. Choose trigger: "When an Event Grid resource event occurs"
4. Configure Event Grid subscription:
   - Select your Event Grid Topic
   - Event Type: Custom event type (e.g., "advertisement.created")
5. Add action: "Send an email (V2)" (Office 365 Outlook or Gmail)
6. Configure email:
   - To: Your email address
   - Subject: `New Advertisement Posted: @{triggerBody()?['subject']}`
   - Body: Include event data from Event Grid
7. Save the Logic App

### Step 8.4: Update createAdvertisement Function to Publish Events (OPTIONAL - Skip if avoiding complexity)
**Note**: To keep the app simple and avoid additional dependencies, we'll configure Event Grid through the Azure Portal's built-in integration instead of code changes.

**Portal Configuration (Recommended for simplicity):**
1. Go to Function App → createAdvertisement function
2. Click "Integration" in the left menu
3. Add an Output binding → Event Grid
4. Select your Event Grid Topic
5. Events will be published automatically without code changes

**Alternative**: If you need manual Event Grid publishing, keep the existing simple code and configure Logic App to trigger on database changes via CosmosDB change feed instead.

### Step 8.5: Configure Event Grid Output Binding (Portal Method - No Code Changes)
```bash
# Simply configure the output binding through portal
# This avoids modifying code and adding dependencies

# OR use Azure CLI to add binding (keeps code unchanged):
az functionapp config appsettings set \
  --name $FUNCTION_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings \
    "EventGridTopicEndpoint=$EVENTGRID_ENDPOINT" \
    "EventGridTopicKey=$EVENTGRID_KEY"
```

### Step 8.6: Test Event Grid & Logic App
```bash
# Test by creating a new advertisement via API
curl -X POST https://${FUNCTION_APP_NAME}.azurewebsites.net/api/createAdvertisement \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Event Grid Advertisement",
    "description": "Testing Logic App notification",
    "price": "$50",
    "city": "Seattle"
  }'

# Check your email for notification
# Check Event Grid metrics in Azure Portal
```

---

## Phase 9: Deploy Frontend to Azure App Service

### Overview
Deploy the NeighborlyFrontEnd Flask application to Azure App Service for public access.

### Step 9.1: Update Frontend Configuration
Update `NeighborlyFrontEnd/settings.py` with deployed API endpoints:

```python
# Replace with your Function App URL
API_URL = "https://<FUNCTION_APP_NAME>.azurewebsites.net/api/"

# API Endpoints
GET_ADVERTISEMENTS_URL = f"{API_URL}getadvertisements"
GET_ADVERTISEMENT_URL = f"{API_URL}getadvertisement"
CREATE_ADVERTISEMENT_URL = f"{API_URL}createAdvertisement"
UPDATE_ADVERTISEMENT_URL = f"{API_URL}updateAdvertisement"
DELETE_ADVERTISEMENT_URL = f"{API_URL}deleteAdvertisement"
GET_POSTS_URL = f"{API_URL}getposts"
GET_POST_URL = f"{API_URL}getpost"
```

### Step 9.2: Create App Service Plan (FREE TIER)
```bash
# Define variables
APP_SERVICE_PLAN="neighborly-frontend-plan"
WEB_APP_NAME="neighborly-frontend-$(openssl rand -hex 4)"

# Create App Service Plan with FREE tier (F1)
# FREE TIER: 60 CPU minutes/day, 1 GB RAM, 1 GB storage
az appservice plan create \
  --name $APP_SERVICE_PLAN \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --is-linux \
  --sku F1

# Create Web App with Python runtime
az webapp create \
  --name $WEB_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --plan $APP_SERVICE_PLAN \
  --runtime "PYTHON:3.9"
```

### Step 9.3: Configure Web App Deployment
```bash
# Navigate to frontend directory
cd /workspaces/nd081-c2-Building-and-deploying-cloud-native-applications-from-scratch-project-starter/NeighborlyFrontEnd

# Create startup command file
echo "gunicorn --bind=0.0.0.0 --timeout 600 app:app" > startup.txt

# Update requirements.txt to include gunicorn
echo "gunicorn>=20.1.0" >> requirements.txt

# Configure startup command
az webapp config set \
  --name $WEB_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --startup-file "gunicorn --bind=0.0.0.0 --timeout 600 app:app"
```

### Step 9.4: Deploy Frontend via Local Git
```bash
# Configure deployment source
az webapp deployment source config-local-git \
  --name $WEB_APP_NAME \
  --resource-group $RESOURCE_GROUP

# Get deployment URL
GIT_URL=$(az webapp deployment source show \
  --name $WEB_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query "repoUrl" \
  --output tsv)

# Deploy using zip (alternative method)
cd /workspaces/nd081-c2-Building-and-deploying-cloud-native-applications-from-scratch-project-starter/NeighborlyFrontEnd
zip -r frontend-app.zip . -x "*.git*" "*.venv*" "__pycache__*"

az webapp deployment source config-zip \
  --name $WEB_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --src frontend-app.zip
```

### Step 9.5: Verify Deployment
```bash
# Get the web app URL
WEB_APP_URL="https://${WEB_APP_NAME}.azurewebsites.net"
echo "Frontend URL: $WEB_APP_URL"

# Test the deployment
curl $WEB_APP_URL
```

---

## Phase 10: Container & Kubernetes Deployment

### Overview
Create Docker container for the application and deploy to Azure Kubernetes Service (AKS).

### Step 10.1: Create Dockerfile for Frontend
Create `NeighborlyFrontEnd/Dockerfile`:

```dockerfile
FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY . .

# Expose port
EXPOSE 5000

# Run the application
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--timeout", "600", "app:app"]
```

### Step 10.2: Create Azure Container Registry (BASIC Tier - Cheapest)
```bash
# Define variables
ACR_NAME="neighborlyacr$(openssl rand -hex 4)"

# Create Azure Container Registry with BASIC tier (cheapest option)
# BASIC: ~$5/month, 10 GB storage, includes 10 webhooks
az acr create \
  --name $ACR_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Basic \
  --admin-enabled true

# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show \
  --name $ACR_NAME \
  --resource-group $RESOURCE_GROUP \
  --query "loginServer" \
  --output tsv)

echo "ACR Login Server: $ACR_LOGIN_SERVER"
```

### Step 10.3: Build and Push Docker Image
```bash
# Navigate to frontend directory
cd /workspaces/nd081-c2-Building-and-deploying-cloud-native-applications-from-scratch-project-starter/NeighborlyFrontEnd

# Login to ACR
az acr login --name $ACR_NAME

# Build and push image using ACR build
az acr build \
  --registry $ACR_NAME \
  --image neighborly-frontend:v1 \
  --file Dockerfile \
  .

# Verify image in ACR
az acr repository list --name $ACR_NAME --output table
az acr repository show-tags --name $ACR_NAME --repository neighborly-frontend --output table
```

### Step 10.4: Create Azure Kubernetes Service (MINIMAL Cost Configuration)
```bash
# Define variables
AKS_CLUSTER_NAME="neighborly-aks-cluster"

# Create AKS cluster with MINIMAL configuration
# Using 1 node with smallest VM size to minimize costs
az aks create \
  --name $AKS_CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --node-count 1 \
  --node-vm-size Standard_B2s \
  --enable-cluster-autoscaler \
  --min-count 1 \
  --max-count 2 \
  --generate-ssh-keys \
  --attach-acr $ACR_NAME \
  --tier free

# Note: Standard_B2s is one of the cheapest options (~$30/month)
# Consider using --spot-instances for even lower costs (up to 90% savings)

# Get AKS credentials
az aks get-credentials \
  --name $AKS_CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --overwrite-existing

# Verify connection
kubectl get nodes
```

### Step 10.5: Create Kubernetes Deployment Manifests
Create `NeighborlyFrontEnd/k8s-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: neighborly-frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: neighborly-frontend
  template:
    metadata:
      labels:
        app: neighborly-frontend
    spec:
      containers:
      - name: neighborly-frontend
        image: <ACR_LOGIN_SERVER>/neighborly-frontend:v1
        ports:
        - containerPort: 5000
        env:
        - name: API_URL
          value: "https://<FUNCTION_APP_NAME>.azurewebsites.net/api/"
---
apiVersion: v1
kind: Service
metadata:
  name: neighborly-frontend-service
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 5000
  selector:
    app: neighborly-frontend
```

### Step 10.6: Deploy to Kubernetes
```bash
# Update k8s-deployment.yaml with actual ACR and Function App URLs
sed -i "s|<ACR_LOGIN_SERVER>|${ACR_LOGIN_SERVER}|g" k8s-deployment.yaml
sed -i "s|<FUNCTION_APP_NAME>|${FUNCTION_APP_NAME}|g" k8s-deployment.yaml

# Apply deployment
kubectl apply -f k8s-deployment.yaml

# Check deployment status
kubectl get deployments
kubectl get pods
kubectl get services

# Get external IP (may take a few minutes)
kubectl get service neighborly-frontend-service --watch

# Once EXTERNAL-IP is assigned, save it
KUBERNETES_EXTERNAL_IP=$(kubectl get service neighborly-frontend-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Kubernetes Application URL: http://${KUBERNETES_EXTERNAL_IP}"
```

### Step 10.7: Verify Kubernetes Deployment
```bash
# Check pod logs
kubectl logs -l app=neighborly-frontend

# Test the application
curl http://${KUBERNETES_EXTERNAL_IP}

# Scale deployment if needed
kubectl scale deployment neighborly-frontend --replicas=3
```

---

## Project Documentation & Screenshots

### Required Screenshots for Project Submission

#### 1. Serverless Functions

**A. Database**
- [ ] **Screenshot 1**: Azure Portal showing CosmosDB database & collections
  - Navigate to: Azure Portal → CosmosDB Account → Data Explorer
  - Show: Database name (`neighborlydb`) and collections (`advertisements`, `posts`)
  - **File**: `screenshots/01-cosmosdb-database-collections.png`

- [ ] **Screenshot 2**: Terminal confirmation of data import
  ```bash
  # Run these commands and capture output:
  mongosh "$CONNECTION_STRING" --eval "use neighborlydb; db.advertisements.countDocuments();"
  mongosh "$CONNECTION_STRING" --eval "use neighborlydb; db.posts.countDocuments();"
  mongosh "$CONNECTION_STRING" --eval "use neighborlydb; db.advertisements.find().limit(2).pretty();"
  ```
  - Show: 5 advertisements and 4 posts imported successfully
  - **File**: `screenshots/02-data-import-confirmation.png`

**B. Triggers in Azure**
- [ ] **Screenshot 3**: Azure Portal showing Function App endpoints (live triggers)
  - Navigate to: Azure Portal → Function App → Functions
  - Show: All HTTP triggered functions listed with their URLs
  - Include: Function App URL in the screenshot
  - **File**: `screenshots/03-function-triggers-endpoints.png`

**C. Triggers Connect to Database**
- [ ] **Screenshot 4**: getAdvertisements endpoint response
  ```bash
  # Test and capture response:
  curl https://${FUNCTION_APP_NAME}.azurewebsites.net/api/getadvertisements
  ```
  - Show: JSON response with advertisement data from database
  - Include: Full URL in screenshot
  - **File**: `screenshots/04-getadvertisements-response.png`

**D. Flask Front End: Localhost**
- [ ] **Screenshot 5**: Frontend running on localhost showing posts
  ```bash
  # Run locally and capture browser screenshot:
  cd NeighborlyFrontEnd
  python app.py
  # Visit: http://localhost:5000
  ```
  - Show: Homepage displaying posts pulled from API
  - **File**: `screenshots/05-frontend-localhost.png`

#### 2. Logic App & Event Grid

**A. Logic App**
- [ ] **Screenshot 6**: Email notification from Logic App
  - Create a new advertisement via API (triggers Logic App)
  - Show: Email inbox with notification received
  - Include: Email subject and body showing advertisement details
  - **File**: `screenshots/06-logic-app-email-notification.png`

**B. Event Grid**
- [ ] **Screenshot 7**: Azure Function Monitor showing successful Event Grid events
  - Navigate to: Azure Portal → Function App → createAdvertisement → Monitor
  - Show: Success count of events processed
  - Include: Execution history with successful runs
  - **File**: `screenshots/07-event-grid-success-count.png`

#### 3. Deploying Your Application

**A. App Service Deployment**
- [ ] **Screenshot 8**: Live App Service URL
  - Show: Browser with frontend application running on Azure App Service
  - Include: Full URL (https://<webapp-name>.azurewebsites.net) in address bar
  - Show: Application functionality (displaying posts/advertisements)
  - **File**: `screenshots/08-app-service-live-url.png`

**B. Dockerfile in Azure Container Registry**
- [ ] **Screenshot 9**: Dockerfile in Azure Container Registry
  - Navigate to: Azure Portal → Container Registry → Repositories
  - Show: Repository with image tags
  - Alternative: Show Dockerfile content in ACR or terminal confirmation
  ```bash
  az acr repository show --name $ACR_NAME --repository neighborly-frontend
  az acr repository show-tags --name $ACR_NAME --repository neighborly-frontend
  ```
  - **File**: `screenshots/09-acr-dockerfile-evidence.png`

**C. Kubernetes**
- [ ] **Screenshot 10**: Kubernetes deployment confirmation
  ```bash
  # Run these commands and capture output:
  kubectl get deployments
  kubectl get pods
  kubectl get services
  kubectl describe deployment neighborly-frontend
  ```
  - Show: Successful deployment with running pods and LoadBalancer service
  - Include: External IP address assigned
  - **File**: `screenshots/10-kubernetes-deployment-confirmation.png`

### Screenshot Checklist Summary

Create a `screenshots/` directory in your project root and capture all required screenshots:

```bash
# Create screenshots directory
mkdir -p /workspaces/nd081-c2-Building-and-deploying-cloud-native-applications-from-scratch-project-starter/screenshots

# Checklist:
# □ 01-cosmosdb-database-collections.png
# □ 02-data-import-confirmation.png
# □ 03-function-triggers-endpoints.png
# □ 04-getadvertisements-response.png
# □ 05-frontend-localhost.png
# □ 06-logic-app-email-notification.png
# □ 07-event-grid-success-count.png
# □ 08-app-service-live-url.png
# □ 09-acr-dockerfile-evidence.png
# □ 10-kubernetes-deployment-confirmation.png
```

### Documentation Guidelines

1. **Name screenshots clearly** following the naming convention above
2. **Include URLs** in screenshots where applicable (browser address bar, Azure Portal)
3. **Show timestamps** where relevant (logs, email notifications)
4. **Capture full context** (don't crop important information)
5. **Use high resolution** (screenshots should be readable)
6. **Annotate if needed** (add arrows or highlights to important elements)

---

## Additional Resources

- [Azure Functions Python Developer Guide](https://docs.microsoft.com/azure/azure-functions/functions-reference-python)
- [Azure CosmosDB MongoDB API Documentation](https://docs.microsoft.com/azure/cosmos-db/mongodb-introduction)
- [Azure Functions Core Tools](https://docs.microsoft.com/azure/azure-functions/functions-run-local)
- [Azure CLI Reference](https://docs.microsoft.com/cli/azure/)

---

**Document Version**: 1.0  
**Created**: November 18, 2025  
**Last Updated**: November 18, 2025
