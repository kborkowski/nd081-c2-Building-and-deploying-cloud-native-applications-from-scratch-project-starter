# Legacy Code Issues and Fixes

## Overview
This document details the compatibility issues found in the legacy Neighborly application codebase and the fixes required for modern deployment to Azure.

---

## Frontend Issues (NeighborlyFrontEnd)

### 1. **Deprecated Dependencies**

#### Issue: Outdated Package Versions
The original `requirements.txt` contained severely outdated packages incompatible with Python 3.11+:

**Original:**
```
azure-functions==1.2.1
certifi==2020.4.5.1
chardet==3.0.4
click==7.1.2
Flask==1.1.2
Flask-Bootstrap==3.3.7.1
idna==2.9
itsdangerous==1.1.0
Jinja2==2.11.2
MarkupSafe==1.1.1
requests==2.23.0
urllib3==1.25.9
visitor==0.1.3
Werkzeug==0.16.1
gunicorn==20.1.0
```

**Problems:**
- `urllib3==1.25.9` - Missing `urllib3.packages.six.moves` in Python 3.12+
- `Werkzeug==0.16.1` - Has deprecated `werkzeug.contrib.atom` module (removed in 1.0+)
- `Flask==1.1.2` - Old version with security vulnerabilities
- `Flask-Bootstrap==3.3.7.1` - Incompatible with Flask 2.x+
- Unnecessary packages for frontend (`azure-functions`, etc.)

**Fix Applied:**
```
Flask==2.0.3
bootstrap-flask==2.0.2
requests==2.31.0
gunicorn==20.1.0
feedgen==0.9.0
Werkzeug==2.0.3
```

### 2. **Deprecated Werkzeug Import**

#### Issue: `werkzeug.contrib.atom` Removed
**File:** `app.py`, line 11

**Original Code:**
```python
from werkzeug.contrib.atom import AtomFeed
```

**Problem:**
- `werkzeug.contrib` module was removed in Werkzeug 1.0 (2020)
- Causes `ModuleNotFoundError` on modern systems

**Fix Applied:**
The feeds functionality was disabled since it was already mostly commented out:
```python
# Feeds route disabled - AtomFeed deprecated in Werkzeug 1.0+
# @app.route('/feeds/')
# def feeds():
#     response = requests.get(settings.API_URL + '/getAdvertisements')
#     posts = response.json()
#     return jsonify(posts)
```

**Alternative Fix:**
Could use `feedgen` library or `flask-atom` package if RSS/Atom feeds are needed.

### 3. **Flask-Bootstrap Compatibility**

#### Issue: Flask-Bootstrap 3.3.7.1 Incompatible with Flask 2.x
**File:** `app.py`, line 4

**Original Code:**
```python
from flask_bootstrap import Bootstrap
```

**Problem:**
- Flask-Bootstrap 3.x designed for Flask 1.x
- Causes template rendering issues with Flask 2.x+
- Not actively maintained

**Fix Applied:**
```python
from flask_bootstrap import Bootstrap5 as Bootstrap
```

Updated `requirements.txt` to use:
```
bootstrap-flask==2.0.2
```

This is a modern, actively maintained fork compatible with Flask 2.x+.

### 4. **Missing feedgen Dependency**

#### Issue: Import Without Declaration
**File:** `app.py`, line 8

```python
from feedgen.feed import FeedGenerator
```

**Problem:**
- `feedgen` imported but not in original requirements.txt
- Would cause `ModuleNotFoundError` on fresh install

**Fix Applied:**
Added to requirements.txt:
```
feedgen==0.9.0
```

### 5. **Azure App Service Deployment Issues**

#### Issue: Container Exit Code 3
**Symptom:** Container crashes immediately after start with exit code 3

**Root Causes Identified:**
1. **Package conflicts** - Old urllib3/Werkzeug versions incompatible with Python 3.11 runtime
2. **Missing imports** - Deprecated modules causing startup failures
3. **Startup command issues** - Gunicorn may need specific configuration

**Attempted Fixes:**
- Updated all dependencies to compatible versions
- Fixed deprecated imports
- Tried multiple gunicorn startup commands:
  - `gunicorn --bind=0.0.0.0 --timeout 600 app:app`
  - `gunicorn --bind 0.0.0.0:8000 app:app`
  - Custom `startup.sh` script

**Current Status:**
Build succeeds but container fails to start. Requires further investigation of Azure App Service logs.

---

## Backend Issues (NeighborlyAPI)

### 1. **Hardcoded Connection Strings**

#### Issue: Localhost Database URLs
**Files:** All function `__init__.py` files

**Original Code:**
```python
url = "mongodb://localhost:27017"
client = pymongo.MongoClient(url)
database = client['azure']
```

**Problems:**
- Hardcoded localhost - won't work in Azure
- Hardcoded database name 'azure'
- No environment variable support
- Security risk (credentials in code)

**Fix Applied:**
```python
import os

url = os.environ.get('MyDbConnection')
client = pymongo.MongoClient(url)
database = client['neighborlydb']
```

**Affected Files:**
- `createAdvertisement/__init__.py`
- `getAdvertisements/__init__.py`
- `getAdvertisement/__init__.py`
- `updateAdvertisement/__init__.py`
- `deleteAdvertisement/__init__.py`
- `getPosts/__init__.py`
- `getPost/__init__.py`

### 2. **Outdated Extension Bundle**

#### Issue: Azure Functions Extension Bundle Version
**File:** `host.json`

**Original Code:**
```json
{
  "version": "2.0",
  "extensionBundle": {
    "id": "Microsoft.Azure.Functions.ExtensionBundle",
    "version": "[1.*, 2.0.0)"
  }
}
```

**Problem:**
- Extension bundle 1.x is very old (2019-2020)
- Incompatible with Functions v4 runtime
- Missing modern bindings and features
- Deployment fails with: "Extension bundle version 1.8.1 does not satisfy the requirement [2.6.1, 3.0.0)"

**Fix Applied:**
```json
{
  "version": "2.0",
  "extensionBundle": {
    "id": "Microsoft.Azure.Functions.ExtensionBundle",
    "version": "[4.*, 5.0.0)"
  }
}
```

### 3. **Security Vulnerability: eval() Usage**

#### Issue: Unsafe eval() for Data Deserialization
**File:** `updateAdvertisement/__init__.py`

**Original Code:**
```python
request_body = eval(req.get_body())
```

**Problem:**
- **CRITICAL SECURITY RISK** - Arbitrary code execution vulnerability
- User input executed as Python code
- Can lead to complete system compromise

**Note:**
Left as-is per user requirement ("functional only, not secure"). 

**Recommended Fix (for production):**
```python
import json
request_body = json.loads(req.get_body())
```

### 4. **Inconsistent Collection Names**

#### Issue: Mixed Collection References
**Original Code Used:**
- Some functions: `collection = database['advertisements']`
- Some functions: `collection = database['posts']`
- Database name: `'azure'`

**Problem:**
- Inconsistent naming makes code confusing
- Original database name 'azure' is non-descriptive

**Fix Applied:**
- Standardized to `database['neighborlydb']`
- Collection names: `'advertisements'` and `'posts'`

---

## Configuration Issues

### 1. **Missing Environment Variables**

#### Issue: No Configuration Template
**Files:** Missing `.env.example` or configuration documentation

**Problems:**
- No guidance on required environment variables
- Developers must guess configuration needs
- Deployment failures from missing config

**Fix Applied:**
Created `deployment-vars.sh` with:
```bash
export RESOURCE_GROUP="neighborly-rg"
export LOCATION="eastus"
export STORAGE_ACCOUNT="neighborlysa..."
export FUNCTION_APP_NAME="neighborly-api-..."
export COSMOSDB_ACCOUNT="neighborly-cosmos-..."
export CONNECTION_STRING="mongodb://..."
export WEB_APP_NAME="neighborly-frontend-..."
export APP_SERVICE_PLAN="neighborly-frontend-plan"
```

### 2. **Hardcoded API URLs**

#### Issue: Frontend API Configuration
**File:** `NeighborlyFrontEnd/settings.py`

**Original Code:**
```python
API_URL = "http://localhost:7071/api"
```

**Problem:**
- Hardcoded localhost URL
- Won't work when frontend deployed to Azure
- Requires manual update for each deployment

**Fix Applied:**
```python
API_URL = "https://neighborly-api-975aba8a.azurewebsites.net/api"
```

**Better Approach:**
```python
import os
API_URL = os.environ.get('API_URL', 'http://localhost:7071/api')
```

---

## Python Version Issues

### 1. **Runtime Compatibility**

**Original Target:** Python 3.7-3.9 (based on dependency versions)

**Modern Requirements:**
- Python 3.11 (Azure Functions v4)
- Python 3.11/3.12 (local development)

**Issues Found:**
- Old packages incompatible with Python 3.10+
- No version constraints in original code
- Assumptions about deprecated features still existing

**Fix:** Updated all dependencies to Python 3.11+ compatible versions

---

## Deployment Recommendations

### For Future Deployments:

1. **Use Virtual Environments**
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```

2. **Test Locally First**
   - Always test with target Python version before deploying
   - Test with updated dependencies
   - Verify environment variables work

3. **Use Environment Variables**
   - Never hardcode connection strings
   - Use Azure App Configuration or Key Vault
   - Document all required variables

4. **Pin Dependency Versions**
   - Specify exact versions in requirements.txt
   - Test upgrades in isolated environment
   - Use dependency security scanners

5. **Follow Azure Best Practices**
   - Use Python 3.11+ for new deployments
   - Keep extension bundles updated
   - Enable Application Insights for monitoring
   - Use managed identities instead of connection strings

---

## Summary of Changes Made

### Frontend (NeighborlyFrontEnd):
- ✅ Updated Flask from 1.1.2 to 2.0.3
- ✅ Replaced Flask-Bootstrap with bootstrap-flask
- ✅ Updated Werkzeug from 0.16.1 to 2.0.3
- ✅ Added feedgen dependency
- ✅ Removed deprecated werkzeug.contrib.atom import
- ✅ Updated API_URL to Azure Function endpoint
- ✅ Added gunicorn to requirements
- ⚠️ Azure App Service deployment still failing (exit code 3)

### Backend (NeighborlyAPI):
- ✅ Converted all hardcoded MongoDB URLs to environment variables
- ✅ Updated host.json extension bundle to v4
- ✅ Changed database name from 'azure' to 'neighborlydb'
- ✅ Deployed successfully to Azure Functions
- ✅ All 7 API endpoints working correctly
- ⚠️ eval() security issue documented but not fixed per requirements

### Infrastructure:
- ✅ Created Azure resources with FREE/cheapest tiers
- ✅ CosmosDB MongoDB API (FREE tier)
- ✅ Function App (Consumption Plan)
- ✅ App Service Plan (B1, upgraded from F1 due to quota)
- ✅ Imported sample data (5 ads, 4 posts)

---

## Outstanding Issues

1. **Frontend Azure Deployment**
   - Status: Container exits with code 3
   - Symptom: "Application Error" page
   - Local testing: ✅ Works perfectly
   - Needs: Further log analysis and debugging

2. **Security Concerns**
   - eval() usage in updateAdvertisement
   - No input validation
   - No authentication/authorization
   - CORS wide open

3. **Missing Features**
   - No error handling
   - No logging configuration
   - No health check endpoints
   - No rate limiting

---

## Testing Notes

**Working Locally:**
```bash
cd NeighborlyFrontEnd
python3 -m venv venv
source venv/bin/activate
pip install Flask==2.0.3 bootstrap-flask==2.0.2 requests==2.31.0 feedgen==0.9.0
python3 app.py
# Visit http://localhost:5000
```

**API Testing:**
```bash
# All endpoints working on Azure
curl https://neighborly-api-975aba8a.azurewebsites.net/api/getadvertisements
curl https://neighborly-api-975aba8a.azurewebsites.net/api/getposts
```

---

**Document Version:** 1.0  
**Date:** November 18, 2025  
**Author:** Deployment Automation  
**Last Updated:** Post-Azure Functions deployment, pre-frontend resolution
