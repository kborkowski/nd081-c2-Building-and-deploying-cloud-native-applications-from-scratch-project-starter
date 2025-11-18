# Kubernetes Deployment Summary

## Resources Created

### Azure Container Registry (ACR)
- **Name**: neighborlyacr975aba8a
- **SKU**: Basic (~$5/month)
- **Login Server**: neighborlyacr975aba8a.azurecr.io
- **Image**: neighborly-frontend:v1
- **Status**: ✅ Image built and pushed successfully

### Azure Kubernetes Service (AKS)
- **Name**: neighborly-aks
- **Resource Group**: neighborly-rg
- **Location**: eastus
- **Node Count**: 1
- **Node Size**: Standard_B2s
- **Kubernetes Version**: 1.32
- **Cost**: ~$30/month
- **Status**: ✅ Cluster created and running
- **⚠️ ACTION REQUIRED**: DELETE IMMEDIATELY after screenshots to minimize costs

### Kubernetes Resources

#### ConfigMap
- **Name**: neighborly-frontend-config
- Contains:
  - API_URL: https://neighborly-api-975aba8a.azurewebsites.net/api
  - CONNECTION_STRING: CosmosDB MongoDB connection string

#### Deployment
- **Name**: neighborly-frontend
- **Replicas**: 1
- **Image**: neighborlyacr975aba8a.azurecr.io/neighborly-frontend:v1
- **Container Port**: 5000
- **Resources**:
  - Requests: 256Mi memory, 250m CPU
  - Limits: 512Mi memory, 500m CPU
- **Status**: ✅ Pod running successfully

#### Service
- **Name**: neighborly-frontend-service
- **Type**: LoadBalancer
- **External IP**: 172.171.175.253
- **Port Mapping**: 80 (external) → 5000 (container)
- **Status**: ✅ LoadBalancer provisioned and accessible

## Verification

✅ Pod Status: Running (1/1 Ready)
✅ Service Status: LoadBalancer IP assigned
✅ Application Access: http://172.171.175.253 (verified working)

## Screenshots Required

### Screenshot 9: Kubernetes Pods
**Command**: `kubectl get pods`
**Shows**: Pod name, Ready status (1/1), Status (Running)
**Filename**: 09-kubernetes-pods.png

### Screenshot 10: Frontend via LoadBalancer
**URL**: http://172.171.175.253
**Shows**: Neighborly frontend accessible via Azure LoadBalancer public IP
**Filename**: 10-kubernetes-frontend-loadbalancer.png

## Cleanup Commands

### Delete AKS Cluster (DO THIS IMMEDIATELY AFTER SCREENSHOTS)
```bash
az aks delete --resource-group neighborly-rg --name neighborly-aks --yes --no-wait
```

### Delete ACR (Optional - only costs $5/month)
```bash
az acr delete --resource-group neighborly-rg --name neighborlyacr975aba8a --yes
```

### Verify Deletion
```bash
az aks list --resource-group neighborly-rg
az acr list --resource-group neighborly-rg
```

## Files Created

- `/NeighborlyFrontEnd/Dockerfile` - Docker image definition
- `/NeighborlyFrontEnd/.dockerignore` - Excludes unnecessary files from image
- `/neighborly-deployment.yaml` - Complete Kubernetes deployment manifest

## Cost Summary

| Resource | Monthly Cost | Status |
|----------|--------------|--------|
| ACR (Basic) | ~$5 | Keep (optional) |
| AKS (1x Standard_B2s) | ~$30 | ⚠️ DELETE IMMEDIATELY |
| **Total** | **~$35** | **Action Required** |

## Next Steps

1. ✅ Take Screenshot 9 (kubectl get pods)
2. ✅ Take Screenshot 10 (browser at http://172.171.175.253)
3. ⚠️ **DELETE AKS CLUSTER IMMEDIATELY**
4. Submit all screenshots (1-10) for project completion

## Notes

- The AKS cluster was attached to ACR using managed identity
- LoadBalancer provisioned public IP automatically
- All environment variables configured via ConfigMap
- Application connects to existing Azure Functions API and CosmosDB
- Dockerfile uses Python 3.9-slim base image for smaller size
- Resource limits prevent pod from consuming too many resources

## Deployment Verification Log

```
✅ ACR Created: neighborlyacr975aba8a
✅ Docker Image Built: neighborly-frontend:v1
✅ Docker Image Pushed: sha256:17267b428eb623d1945e0adb363d51f40c0993bc138b35a873930d1177df7e45
✅ AKS Cluster Created: neighborly-aks
✅ kubectl Configured: Context set to neighborly-aks
✅ ConfigMap Applied: neighborly-frontend-config
✅ Deployment Applied: neighborly-frontend
✅ Service Applied: neighborly-frontend-service (LoadBalancer)
✅ Pod Running: neighborly-frontend-7c754dbd99-ml2hs (1/1 Ready)
✅ LoadBalancer IP: 172.171.175.253
✅ Application Verified: HTTP 200 response from http://172.171.175.253
```

---

**REMINDER**: The AKS cluster costs approximately **$1/day**. Delete it within hours of taking screenshots to minimize costs!
