# NeighborlyAPI - Quick Start Guide

## Pre-Flight Checklist

### 1. Install Required Tools
```bash
# Run the setup script
./setup-environment.sh

# Or install manually:
# - Azure CLI
# - Azure Functions Core Tools v4
# - MongoDB Database Tools
```

### 2. Login to Azure
```bash
az login --use-device-code
az account show
```

### 3. Verify Your Email
Your Logic App notifications will be sent to: **v-krbork@microsoft.com**

---

## Cost-Optimized Deployment Summary

### Resources to Create (All FREE or Near-FREE)
- ✅ Resource Group (FREE)
- ✅ Storage Account (FREE tier)
- ✅ Function App - Consumption Plan (1M requests FREE/month)
- ✅ CosmosDB - **FREE TIER** (1000 RU/s FREE forever - ONE per subscription)
- ✅ App Service - F1 Tier (FREE)
- ✅ Event Hub - Basic Tier (~$20/month - DELETE after screenshots)
- ✅ Logic App - Consumption (4,000 actions FREE/month)
- ⚠️ Container Registry - Basic (~$5/month - only for K8s)
- ⚠️ AKS Cluster (~$30/month - **CREATE LAST, DELETE FIRST**)

### Estimated Total Cost
- **Without Kubernetes**: $0-2/month (mostly FREE)
- **With Kubernetes**: ~$35-55/month

### Cost Saving Strategy
1. Deploy everything EXCEPT AKS/ACR first
2. Test and take screenshots (except K8s)
3. When ready for K8s screenshots, create ACR + AKS
4. Take K8s screenshots immediately
5. **DELETE AKS and ACR right after** (saves $35/month)

---

## Deployment Order

### Phase 1: Azure Resources (30 minutes)
```bash
# Set variables
RESOURCE_GROUP="neighborly-rg"
LOCATION="eastus"

# Create all Azure resources
# Follow DEPLOYMENT_PLAN.md Phase 1 steps
```

### Phase 2: Import Data (10 minutes)
```bash
# Import sample data to CosmosDB
mongoimport --uri "$CONNECTION_STRING" --db neighborlydb --collection advertisements --file './sample_data/sampleAds.json' --jsonArray
mongoimport --uri "$CONNECTION_STRING" --db neighborlydb --collection posts --file './sample_data/samplePosts.json' --jsonArray
```

### Phase 3: Update Function Code (15 minutes)
Update all 7 function `__init__.py` files:
- Replace `url = "localhost"` with `url = os.environ.get('MyDbConnection')`
- Change `database = client['azure']` to `database = client['neighborlydb']`
- **NO OTHER CODE CHANGES** (keep eval(), etc. as-is)

### Phase 4: Test Locally (10 minutes)
```bash
cd NeighborlyAPI
func start
# Test: http://localhost:7071/api/getadvertisements
```

### Phase 5: Deploy Functions (10 minutes)
```bash
func azure functionapp publish $FUNCTION_APP_NAME --python
```

### Phase 6: Deploy Frontend (15 minutes)
```bash
cd NeighborlyFrontEnd
# Update settings.py with Function App URL
az webapp deployment source config-zip --name $WEB_APP_NAME --resource-group $RESOURCE_GROUP --src frontend-app.zip
```

### Phase 7: Event Hub & Logic App (20 minutes)
1. Create Event Hub namespace
2. Create Logic App with HTTP trigger
3. Configure email to: **v-krbork@microsoft.com**
4. Test with curl command

### Phase 8: Take Screenshots (30 minutes)
Take all 10 required screenshots (see DEPLOYMENT_PLAN.md)

### Phase 9: Kubernetes (OPTIONAL - 30 minutes)
⚠️ **Do this LAST and DELETE immediately after screenshots**
1. Create ACR
2. Build/push Docker image
3. Create AKS (1 node minimum)
4. Deploy to K8s
5. **Take screenshots**
6. **DELETE AKS and ACR immediately**

---

## Quick Commands Reference

### Check Resource Status
```bash
# List all resources in resource group
az resource list --resource-group $RESOURCE_GROUP --output table

# Check Function App
az functionapp show --name $FUNCTION_APP_NAME --resource-group $RESOURCE_GROUP

# Check CosmosDB
az cosmosdb show --name $COSMOSDB_ACCOUNT --resource-group $RESOURCE_GROUP
```

### Test Endpoints
```bash
# Get all advertisements
curl https://${FUNCTION_APP_NAME}.azurewebsites.net/api/getadvertisements

# Get all posts
curl https://${FUNCTION_APP_NAME}.azurewebsites.net/api/getposts

# Test Logic App HTTP trigger
curl -X POST "<LOGIC_APP_HTTP_URL>" -H "Content-Type: application/json" -d '{"title":"Test","description":"Testing","price":"$10","city":"Seattle"}'
```

### Cleanup (When Done)
```bash
# Delete EVERYTHING (saves money)
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

---

## Troubleshooting

### Function fails to connect to CosmosDB
```bash
# Check connection string is set
az functionapp config appsettings list --name $FUNCTION_APP_NAME --resource-group $RESOURCE_GROUP | grep MyDbConnection

# Test connection string locally
mongosh "$CONNECTION_STRING" --eval "db.adminCommand({ping:1})"
```

### Data not showing up
```bash
# Verify data was imported
mongosh "$CONNECTION_STRING" --eval "use neighborlydb; db.advertisements.countDocuments(); db.posts.countDocuments();"
```

### Deployment fails
```bash
# Check deployment logs
func azure functionapp logstream $FUNCTION_APP_NAME
```

### Logic App not sending email
1. Check you signed in with correct account in Logic App Designer
2. Verify email address: **v-krbork@microsoft.com**
3. Test with simple curl command
4. Check spam folder

---

## Important Notes

✅ **Use CosmosDB FREE TIER** (only 1 per subscription)
✅ **No code security improvements** (keep it simple)
✅ **Email notifications go to**: v-krbork@microsoft.com
✅ **Create AKS LAST** and delete immediately after screenshots
✅ **Monitor costs daily** in Azure Portal → Cost Management

---

## Screenshot Checklist

- [ ] 01 - CosmosDB database & collections
- [ ] 02 - Data import confirmation (5 ads, 4 posts)
- [ ] 03 - Function App endpoints
- [ ] 04 - getAdvertisements response
- [ ] 05 - Frontend on localhost
- [ ] 06 - Logic App email notification
- [ ] 07 - Event Hub success count
- [ ] 08 - Live App Service URL
- [ ] 09 - Docker image in ACR
- [ ] 10 - Kubernetes deployment

---

## Key URLs to Save

- Function App: `https://<FUNCTION_APP_NAME>.azurewebsites.net/api/`
- Frontend App: `https://<WEB_APP_NAME>.azurewebsites.net`
- Logic App HTTP Trigger: `https://prod-XX.eastus.logic.azure.com:443/workflows/...`
- Event Hub Namespace: `https://<EVENTHUB_NAMESPACE>.servicebus.windows.net/`

---

**Ready to deploy? Start with:** `./setup-environment.sh`
