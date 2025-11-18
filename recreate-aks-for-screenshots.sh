#!/bin/bash
set -e

echo "🚀 Quick AKS Recreation for Screenshots"
echo "========================================"
echo ""
echo "⚠️  This will:"
echo "  - Create AKS cluster (~$1/day while running)"
echo "  - Deploy your containerized app"
echo "  - Show you the URLs for screenshots"
echo "  - YOU must delete AKS after screenshots to stop billing"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Load environment
if [ ! -f deployment-vars.sh ]; then
    echo "❌ Error: deployment-vars.sh not found"
    exit 1
fi

source deployment-vars.sh

# Verify required variables
if [ -z "$CONNECTION_STRING" ]; then
    echo "❌ Error: CONNECTION_STRING not set in deployment-vars.sh"
    exit 1
fi

# 1. Create AKS cluster
echo ""
echo "📦 Step 1/7: Creating AKS cluster (5-10 minutes)..."
az aks create \
  --resource-group neighborly-rg \
  --name neighborly-aks \
  --node-count 1 \
  --node-vm-size Standard_B2s \
  --enable-managed-identity \
  --generate-ssh-keys \
  --attach-acr neighborlyacr975aba8a \
  --yes \
  --output table

# 2. Get credentials
echo ""
echo "🔐 Step 2/7: Getting AKS credentials..."
az aks get-credentials \
  --resource-group neighborly-rg \
  --name neighborly-aks \
  --overwrite-existing

# 3. Verify cluster
echo ""
echo "✅ Step 3/7: Verifying cluster..."
kubectl get nodes -o wide

# 4. Create deployment with actual values
echo ""
echo "📝 Step 4/7: Creating deployment manifest..."
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
echo ""
echo "🚀 Step 5/7: Deploying application to AKS..."
kubectl apply -f /tmp/neighborly-deploy.yaml

# 6. Wait for pod
echo ""
echo "⏳ Step 6/7: Waiting for pod to be ready (up to 5 minutes)..."
kubectl wait --for=condition=ready pod -l app=neighborly-frontend --timeout=300s || true

echo ""
echo "Pod status:"
kubectl get pods -l app=neighborly-frontend

# 7. Wait for LoadBalancer IP
echo ""
echo "⏳ Step 7/7: Waiting for LoadBalancer IP (2-5 minutes)..."
echo "This creates a public IP address in Azure..."

COUNTER=0
MAX_WAIT=60  # 10 minutes max

while [ $COUNTER -lt $MAX_WAIT ]; do
  EXTERNAL_IP=$(kubectl get svc neighborly-frontend-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
  
  if [ ! -z "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "" ]; then
    echo ""
    echo "✅ LoadBalancer IP assigned: $EXTERNAL_IP"
    break
  fi
  
  echo -n "."
  sleep 10
  COUNTER=$((COUNTER+1))
done

if [ -z "$EXTERNAL_IP" ]; then
    echo ""
    echo "⚠️  LoadBalancer IP not assigned yet. Check status with:"
    echo "    kubectl get svc neighborly-frontend-service --watch"
    exit 1
fi

# 8. Test endpoint
echo ""
echo "🧪 Testing application endpoint..."
sleep 15  # Give app time to fully start

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$EXTERNAL_IP)

if [ "$HTTP_CODE" == "200" ]; then
    echo "✅ Application responding successfully (HTTP $HTTP_CODE)"
else
    echo "⚠️  Application returned HTTP $HTTP_CODE (may need more time to start)"
fi

# Final summary
echo ""
echo "========================================"
echo "✅ READY FOR SCREENSHOTS!"
echo "========================================"
echo ""
echo "📸 SCREENSHOT 1: AKS Node Pool"
echo "   1. Go to: https://portal.azure.com"
echo "   2. Navigate: Resource Groups → neighborly-rg → neighborly-aks"
echo "   3. Click: 'Node pools' in left menu"
echo "   4. Screenshot showing: 1 node, Standard_B2s, Running status"
echo "   5. Save as: screenshot-aks-one-node.png"
echo ""
echo "📸 SCREENSHOT 2: kubectl nodes"
echo "   Run: kubectl get nodes -o wide"
echo "   Save as: screenshot-kubectl-nodes.png"
echo ""
echo "📸 SCREENSHOT 3: Deployed Application"
echo "   1. Open browser: http://$EXTERNAL_IP"
echo "   2. Wait for page to load completely"
echo "   3. Screenshot showing: App UI + URL in address bar"
echo "   4. Save as: screenshot-aks-webapp-url.png"
echo ""
echo "📸 SCREENSHOT 4: LoadBalancer (Optional)"
echo "   1. Go to: https://portal.azure.com"
echo "   2. Navigate: Resource Groups → MC_neighborly-rg_neighborly-aks_* (managed RG)"
echo "   3. Find and click the LoadBalancer resource"
echo "   4. Screenshot showing: Public IP configuration"
echo "   5. Save as: screenshot-loadbalancer-ip.png"
echo ""
echo "🔗 Application URL: http://$EXTERNAL_IP"
echo ""
echo "⚠️  IMPORTANT: After screenshots, DELETE AKS to stop $1/day billing:"
echo "    az aks delete --resource-group neighborly-rg --name neighborly-aks --yes --no-wait"
echo ""
echo "💡 Current costs while AKS is running:"
echo "    - AKS cluster: ~$1/day"
echo "    - LoadBalancer: ~$0.02/hour"
echo "    Total: ~$30/month if left running"
echo ""
