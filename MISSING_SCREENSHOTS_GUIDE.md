# Missing Screenshots Guide - Reviewer Feedback

## 🎯 Required Screenshots (4 total)

---

## Screenshot 1: Frontend Running on localhost:5000 ✅

**Step 1: Start the frontend locally**
```bash
cd /workspaces/nd081-c2-Building-and-deploying-cloud-native-applications-from-scratch-project-starter/NeighborlyFrontEnd

# Kill any existing Python processes
pkill -9 python3 2>/dev/null || true

# Start the app
python3 app.py &
sleep 5

# Verify it's running
curl -s http://localhost:5000 | grep -o "<title>.*</title>"
```

**Step 2: Open in browser**
- Open your browser to: `http://localhost:5000`
- **TAKE SCREENSHOT** showing:
  - The Neighborly homepage with posts/advertisements
  - Browser address bar showing `localhost:5000`
  - The page content loaded

**Filename:** `screenshot-frontend-localhost.png`

---

## Screenshot 2: Dockerfile in Azure Container Registry ⭐

**Option A: Show in Azure Portal (Recommended)**
1. Go to: https://portal.azure.com
2. Navigate to: Resource Groups → `neighborly-rg` → `neighborlyacr975aba8a`
3. Click on "Repositories" in the left menu under Services
4. Click on `neighborly-frontend` repository
5. Click on the `v1` tag
6. **TAKE SCREENSHOT** showing:
   - Repository name: `neighborly-frontend`
   - Tag: `v1`
   - Digest/Size/Created date
   - Full image path: `neighborlyacr975aba8a.azurecr.io/neighborly-frontend:v1`

**Filename:** `screenshot-acr-dockerfile.png`

**Option B: Show via Azure CLI**
```bash
# Login to Azure
az login

# Show ACR repositories
echo "=== Azure Container Registry: neighborlyacr975aba8a ==="
az acr repository list --name neighborlyacr975aba8a --output table

echo -e "\n=== Image Tags for neighborly-frontend ==="
az acr repository show-tags --name neighborlyacr975aba8a --repository neighborly-frontend --output table

echo -e "\n=== Image Manifest ==="
az acr repository show --name neighborlyacr975aba8a --repository neighborly-frontend --output table
```
**Take screenshot of terminal output**

---

## Screenshot 3: AKS Cluster with One Node ⭐

**⚠️ IMPORTANT: This requires recreating the AKS cluster (costs ~$1/day)**

### Option A: Quick Recreation (if you need the screenshot urgently)

```bash
# Set environment
source deployment-vars.sh

# Create AKS cluster (takes 5-10 minutes)
az aks create \
  --resource-group neighborly-rg \
  --name neighborly-aks \
  --node-count 1 \
  --node-vm-size Standard_B2s \
  --enable-managed-identity \
  --generate-ssh-keys \
  --attach-acr neighborlyacr975aba8a \
  --yes

# Get credentials
az aks get-credentials --resource-group neighborly-rg --name neighborly-aks --overwrite-existing

# Verify cluster
kubectl get nodes
```

**Take Screenshot from Azure Portal:**
1. Go to: https://portal.azure.com
2. Navigate to: Resource Groups → `neighborly-rg` → `neighborly-aks`
3. Click on "Node pools" in the left menu
4. **TAKE SCREENSHOT** showing:
   - Node pool name: `agentpool` or `nodepool1`
   - Node count: **1**
   - VM size: `Standard_B2s`
   - Status: Running/Succeeded

**Filename:** `screenshot-aks-one-node.png`

**Take Screenshot from kubectl:**
```bash
echo "=== AKS Cluster Nodes ==="
kubectl get nodes -o wide

echo -e "\n=== Node Details ==="
kubectl describe nodes | grep -E "Name:|Roles:|Capacity:|Allocatable:|System Info"
```
**Take screenshot showing 1 node with Ready status**

**Filename:** `screenshot-kubectl-nodes.png`

---

## Screenshot 4: Neighborly Web App with URL ⭐

**⚠️ REQUIRES: AKS cluster running (from Screenshot 3)**

### Step 1: Deploy the application to AKS

```bash
# Update deployment YAML with your actual values
cat > /tmp/neighborly-deployment-actual.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: neighborly-frontend-config
data:
  API_URL: "https://neighborly-api-975aba8a.azurewebsites.net/api"
  CONNECTION_STRING: "YOUR_ACTUAL_CONNECTION_STRING_HERE"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: neighborly-frontend
  labels:
    app: neighborly-frontend
spec:
  replicas: 1
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
        image: neighborlyacr975aba8a.azurecr.io/neighborly-frontend:v1
        ports:
        - containerPort: 5000
        env:
        - name: API_URL
          valueFrom:
            configMapKeyRef:
              name: neighborly-frontend-config
              key: API_URL
        - name: CONNECTION_STRING
          valueFrom:
            configMapKeyRef:
              name: neighborly-frontend-config
              key: CONNECTION_STRING
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: neighborly-frontend-service
spec:
  type: LoadBalancer
  selector:
    app: neighborly-frontend
  ports:
  - protocol: TCP
    port: 80
    targetPort: 5000
EOF

# Get actual connection string
source deployment-vars.sh
sed -i "s|YOUR_ACTUAL_CONNECTION_STRING_HERE|$CONNECTION_STRING|" /tmp/neighborly-deployment-actual.yaml

# Apply deployment
kubectl apply -f /tmp/neighborly-deployment-actual.yaml

# Wait for LoadBalancer IP (takes 2-5 minutes)
echo "Waiting for LoadBalancer IP..."
kubectl get svc neighborly-frontend-service --watch
```

### Step 2: Access and Screenshot

```bash
# Get the external IP
EXTERNAL_IP=$(kubectl get svc neighborly-frontend-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Application URL: http://$EXTERNAL_IP"

# Test the endpoint
curl -I http://$EXTERNAL_IP
```

**Take Screenshot from Browser:**
1. Open browser to: `http://[EXTERNAL_IP]`
2. **TAKE SCREENSHOT** showing:
   - The Neighborly web application loaded
   - **Browser address bar with the external IP URL visible**
   - Posts and advertisements displayed
   - All UI elements loaded correctly

**Filename:** `screenshot-aks-webapp-url.png`

**Take Screenshot from Azure Portal (LoadBalancer):**
1. Go to: https://portal.azure.com
2. Navigate to: Resource Groups → `MC_neighborly-rg_neighborly-aks_*` (AKS managed resource group)
3. Find the LoadBalancer resource
4. Click on it to see the public IP configuration
5. **TAKE SCREENSHOT** showing the public IP and configuration

**Filename:** `screenshot-loadbalancer-ip.png`

---

## 🎬 Quick Recreation Script (All at Once)

If you need all Kubernetes screenshots, run this complete script:

```bash
#!/bin/bash
set -e

echo "🚀 Recreating AKS for Screenshots..."

# Load environment
source deployment-vars.sh

# 1. Create AKS cluster
echo "📦 Creating AKS cluster (5-10 minutes)..."
az aks create \
  --resource-group neighborly-rg \
  --name neighborly-aks \
  --node-count 1 \
  --node-vm-size Standard_B2s \
  --enable-managed-identity \
  --generate-ssh-keys \
  --attach-acr neighborlyacr975aba8a \
  --yes

# 2. Get credentials
echo "🔐 Getting AKS credentials..."
az aks get-credentials --resource-group neighborly-rg --name neighborly-aks --overwrite-existing

# 3. Verify cluster
echo "✅ Verifying cluster..."
kubectl get nodes

# 4. Create deployment with actual values
echo "📝 Creating deployment manifest..."
cat > /tmp/neighborly-deploy.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: neighborly-frontend-config
data:
  API_URL: "https://neighborly-api-975aba8a.azurewebsites.net/api"
  CONNECTION_STRING: "$CONNECTION_STRING"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: neighborly-frontend
  labels:
    app: neighborly-frontend
spec:
  replicas: 1
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
        image: neighborlyacr975aba8a.azurecr.io/neighborly-frontend:v1
        ports:
        - containerPort: 5000
        env:
        - name: API_URL
          valueFrom:
            configMapKeyRef:
              name: neighborly-frontend-config
              key: API_URL
        - name: CONNECTION_STRING
          valueFrom:
            configMapKeyRef:
              name: neighborly-frontend-config
              key: CONNECTION_STRING
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: neighborly-frontend-service
spec:
  type: LoadBalancer
  selector:
    app: neighborly-frontend
  ports:
  - protocol: TCP
    port: 80
    targetPort: 5000
EOF

# 5. Deploy application
echo "🚀 Deploying application..."
kubectl apply -f /tmp/neighborly-deploy.yaml

# 6. Wait for pod
echo "⏳ Waiting for pod to be ready..."
kubectl wait --for=condition=ready pod -l app=neighborly-frontend --timeout=300s

# 7. Wait for LoadBalancer IP
echo "⏳ Waiting for LoadBalancer IP (2-5 minutes)..."
while true; do
  EXTERNAL_IP=$(kubectl get svc neighborly-frontend-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
  if [ ! -z "$EXTERNAL_IP" ]; then
    echo "✅ LoadBalancer IP: $EXTERNAL_IP"
    break
  fi
  echo "Still waiting for IP..."
  sleep 10
done

# 8. Test endpoint
echo "🧪 Testing application..."
sleep 15  # Give app time to fully start
curl -I http://$EXTERNAL_IP

echo ""
echo "========================"
echo "✅ READY FOR SCREENSHOTS"
echo "========================"
echo ""
echo "Application URL: http://$EXTERNAL_IP"
echo ""
echo "NOW TAKE THESE SCREENSHOTS:"
echo "1. Azure Portal: Show AKS node pool (1 node)"
echo "2. Browser: Open http://$EXTERNAL_IP and capture the app with URL visible"
echo "3. Terminal: Run 'kubectl get nodes' and capture output"
echo ""
echo "⚠️  After screenshots, DELETE AKS to stop billing:"
echo "    az aks delete --resource-group neighborly-rg --name neighborly-aks --yes --no-wait"
echo ""
```

Save this as `recreate-aks-for-screenshots.sh` and run:
```bash
chmod +x recreate-aks-for-screenshots.sh
./recreate-aks-for-screenshots.sh
```

---

## 💰 Cost Management

**Current costs:**
- AKS: ~$1/day (~$30/month) - ONLY when running
- ACR: $5/month (already running, keep it)

**After taking screenshots:**
```bash
# DELETE AKS immediately to stop billing
az aks delete --resource-group neighborly-rg --name neighborly-aks --yes --no-wait
```

---

## 📋 Screenshot Checklist

Upload these files to the `screenshots/` folder:

- [ ] `screenshot-frontend-localhost.png` - Frontend on localhost:5000
- [ ] `screenshot-acr-dockerfile.png` - ACR repository showing Docker image
- [ ] `screenshot-aks-one-node.png` - AKS node pool with 1 node (Portal)
- [ ] `screenshot-kubectl-nodes.png` - kubectl get nodes output (optional)
- [ ] `screenshot-aks-webapp-url.png` - Deployed app with LoadBalancer URL
- [ ] `screenshot-loadbalancer-ip.png` - LoadBalancer IP from Portal (optional)

---

## 🆘 Troubleshooting

### Issue: Can't get LoadBalancer IP
```bash
kubectl get svc neighborly-frontend-service -o yaml | grep -A 5 status
```

### Issue: Pod not starting
```bash
kubectl get pods
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Issue: 403 Forbidden from ACR
```bash
az aks update --resource-group neighborly-rg --name neighborly-aks --attach-acr neighborlyacr975aba8a
```

### Issue: Connection to Azure
```bash
az login
az account show
```
