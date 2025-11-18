# Neighborly Bicep Infrastructure

This directory contains Infrastructure as Code (IaC) using Azure Bicep to deploy the complete Neighborly application infrastructure.

## 📋 What Gets Deployed

The Bicep template (`neighborly-infrastructure.bicep`) deploys:

1. **Cosmos DB** (MongoDB API)
   - Database: `neighborlydb`
   - Collections: `advertisements`, `posts`
   - Throughput: 400 RU/s

2. **Azure Function App**
   - Runtime: Python 3.9
   - Plan: Consumption (Y1)
   - OS: Linux
   - Pre-configured with Cosmos DB connection

3. **Event Grid Topic**
   - For advertisement creation events
   - Integrated with Logic App

4. **Logic App**
   - HTTP trigger webhook
   - Email notifications for new ads
   - Event Grid subscription

5. **Storage Account**
   - For Function App backend storage

6. **Container Registry** (Optional)
   - Basic SKU
   - Admin access enabled

7. **AKS Cluster** (Optional)
   - 1 node, Standard_B2s
   - Integrated with ACR

## 🚀 Quick Deployment

### Prerequisites

```bash
# Install Azure CLI (if not already installed)
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login to Azure
az login

# Set your subscription (if you have multiple)
az account set --subscription "Your Subscription Name"

# Install MongoDB tools (for data import)
sudo apt-get update
sudo apt-get install -y mongodb-clients
```

### Option 1: Automated Script (Recommended)

```bash
# Make script executable
chmod +x deploy-bicep.sh

# Deploy with defaults (no AKS, no ACR)
./deploy-bicep.sh

# Or set custom parameters
RESOURCE_GROUP="my-neighborly-rg" \
LOCATION="westus2" \
NOTIFICATION_EMAIL="admin@example.com" \
DEPLOY_AKS=true \
DEPLOY_ACR=true \
./deploy-bicep.sh
```

### Option 2: Manual Azure CLI

```bash
# 1. Create resource group
az group create \
  --name neighborly-rg \
  --location eastus

# 2. Deploy template
az deployment group create \
  --resource-group neighborly-rg \
  --template-file neighborly-infrastructure.bicep \
  --parameters location=eastus \
               environment=dev \
               notificationEmail=your-email@example.com \
               deployAKS=false \
               deployACR=false

# 3. Get outputs
az deployment group show \
  --resource-group neighborly-rg \
  --name neighborly-infrastructure \
  --query properties.outputs

# 4. Deploy function code
cd NeighborlyAPI
func azure functionapp publish <function-app-name> --python

# 5. Import sample data (using connection string from outputs)
mongoimport --uri="<cosmos-connection-string>" \
  --db=neighborlydb \
  --collection=advertisements \
  --file=sample_data/sampleAds.json \
  --jsonArray

mongoimport --uri="<cosmos-connection-string>" \
  --db=neighborlydb \
  --collection=posts \
  --file=sample_data/samplePosts.json \
  --jsonArray
```

### Option 3: Azure Portal

1. Go to [Azure Portal](https://portal.azure.com)
2. Search for "Deploy a custom template"
3. Click "Build your own template in the editor"
4. Copy/paste contents of `neighborly-infrastructure.bicep`
5. Click "Save"
6. Fill in parameters
7. Click "Review + create" → "Create"

## 📝 Configuration

### Parameters File

Edit `neighborly-infrastructure.parameters.json`:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "location": {
      "value": "eastus"
    },
    "environment": {
      "value": "prod"
    },
    "notificationEmail": {
      "value": "admin@company.com"
    },
    "deployAKS": {
      "value": true
    },
    "deployACR": {
      "value": true
    }
  }
}
```

Then deploy with:

```bash
az deployment group create \
  --resource-group neighborly-rg \
  --template-file neighborly-infrastructure.bicep \
  --parameters @neighborly-infrastructure.parameters.json
```

### Environment Variables

The deployment script creates `deployment-vars.sh` with:

```bash
export RESOURCE_GROUP="neighborly-rg"
export FUNCTION_APP_NAME="neighborly-api-xyz123"
export CONNECTION_STRING="mongodb://..."
export API_URL="https://neighborly-api-xyz123.azurewebsites.net/api"
export EVENT_GRID_ENDPOINT="https://..."
export EVENT_GRID_KEY="..."
export LOGIC_APP_URL="https://..."
```

Load these variables:

```bash
source deployment-vars.sh
```

## 🧪 Testing the Deployment

After deployment completes:

```bash
# Load environment variables
source deployment-vars.sh

# Test Function App endpoints
curl $API_URL/getAdvertisements
curl $API_URL/getPosts

# Run frontend locally
cd NeighborlyFrontEnd
export API_URL=$API_URL
export CONNECTION_STRING=$CONNECTION_STRING
python3 app.py

# Open browser to http://localhost:5000
```

## 🎯 Deployment Scenarios

### Scenario 1: Development (Minimal Cost)

```bash
# No AKS, no ACR - ~$25-30/month
DEPLOY_AKS=false DEPLOY_ACR=false ./deploy-bicep.sh
```

### Scenario 2: Full Production Setup

```bash
# With AKS and ACR - ~$60-70/month
DEPLOY_AKS=true DEPLOY_ACR=true ./deploy-bicep.sh
```

### Scenario 3: Use Existing ACR

```bash
# Deploy core services, use existing ACR
DEPLOY_AKS=false DEPLOY_ACR=false ./deploy-bicep.sh

# Then manually configure with existing ACR
```

## 📊 Outputs

After deployment, you'll get:

- `cosmosConnectionString`: MongoDB connection string
- `functionAppUrl`: Function App base URL
- `functionAppName`: Name for deployment
- `eventGridTopicEndpoint`: Event Grid topic URL
- `eventGridTopicKey`: Event Grid access key
- `logicAppTriggerUrl`: Logic App webhook URL
- `containerRegistryLoginServer`: ACR login server (if deployed)
- `aksClusterName`: AKS cluster name (if deployed)

## 🔧 Customization

### Change Cosmos DB Throughput

Edit `neighborly-infrastructure.bicep`:

```bicep
options: {
  throughput: 400  // Change to 1000 for more RU/s
}
```

### Change Function App SKU

```bicep
sku: {
  name: 'Y1'  // Change to 'EP1' for Premium plan
  tier: 'Dynamic'  // Change to 'ElasticPremium'
}
```

### Add More Collections

```bicep
resource myNewCollection 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases/collections@2023-04-15' = {
  parent: database
  name: 'mycollection'
  properties: {
    resource: {
      id: 'mycollection'
      shardKey: {
        _id: 'Hash'
      }
    }
  }
}
```

## 🗑️ Cleanup

### Delete Everything

```bash
az group delete --name neighborly-rg --yes --no-wait
```

### Delete Specific Resources

```bash
# Delete AKS only
az aks delete --name neighborly-aks-xyz123 --resource-group neighborly-rg --yes

# Delete Function App only
az functionapp delete --name neighborly-api-xyz123 --resource-group neighborly-rg
```

## 💰 Cost Estimate

| Resource | SKU | Estimated Cost |
|----------|-----|----------------|
| Cosmos DB | 400 RU/s | $24/month |
| Function App | Consumption | $0-5/month |
| Storage Account | Standard LRS | $1/month |
| Event Grid | Pay per operation | $0.60/million ops |
| Logic App | Consumption | $0-1/month |
| **Minimal Total** | | **~$25-30/month** |
| ACR | Basic | +$5/month |
| AKS | 1x Standard_B2s | +$30/month |
| **Full Total** | | **~$60-70/month** |

## 🐛 Troubleshooting

### Deployment Fails

```bash
# Validate template first
az deployment group validate \
  --resource-group neighborly-rg \
  --template-file neighborly-infrastructure.bicep \
  --parameters location=eastus

# Check deployment logs
az deployment group show \
  --resource-group neighborly-rg \
  --name neighborly-infrastructure
```

### Function App Won't Deploy

```bash
# Check if app exists
az functionapp show --name <app-name> --resource-group neighborly-rg

# Restart function app
az functionapp restart --name <app-name> --resource-group neighborly-rg

# View logs
az functionapp log tail --name <app-name> --resource-group neighborly-rg
```

### Cosmos DB Connection Issues

```bash
# Get connection string
az cosmosdb keys list \
  --name neighborly-cosmos-xyz123 \
  --resource-group neighborly-rg \
  --type connection-strings

# Test connection
mongosh "<connection-string>"
```

## 📚 Additional Resources

- [Azure Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure Functions with Python](https://learn.microsoft.com/azure/azure-functions/functions-reference-python)
- [Cosmos DB MongoDB API](https://learn.microsoft.com/azure/cosmos-db/mongodb/mongodb-introduction)
- [Event Grid Overview](https://learn.microsoft.com/azure/event-grid/overview)

## 🔐 Security Notes

- Storage account has `allowBlobPublicAccess: false`
- Function App requires HTTPS only
- Minimum TLS version is 1.2
- Cosmos DB uses automatic failover disabled (for cost)
- Consider enabling Azure Key Vault for production secrets

## 🚀 CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy Infrastructure

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Deploy Bicep
        uses: azure/arm-deploy@v1
        with:
          resourceGroupName: neighborly-rg
          template: ./neighborly-infrastructure.bicep
          parameters: location=eastus environment=prod
```

## 📞 Support

For issues or questions:
1. Check deployment logs: `az deployment group show`
2. Review Azure Portal for resource status
3. Check Function App logs: `func azure functionapp logstream <app-name>`
4. Verify sample data imported correctly in Cosmos DB Data Explorer
