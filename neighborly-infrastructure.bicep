// Neighborly Infrastructure - Complete Azure Deployment
// This Bicep template deploys all resources needed for the Neighborly app

@description('Location for all resources')
param location string = resourceGroup().location

@description('Unique suffix for resource names (auto-generated if not provided)')
param suffix string = uniqueString(resourceGroup().id)

@description('Environment name (dev, staging, prod)')
param environment string = 'dev'

@description('Cosmos DB account name')
param cosmosAccountName string = 'neighborly-cosmos-${suffix}'

@description('Database name')
param databaseName string = 'neighborlydb'

@description('Function App name')
param functionAppName string = 'neighborly-api-${suffix}'

@description('Storage account name for Function App (max 24 chars, lowercase + numbers only)')
param storageAccountName string = 'nsto${suffix}'

@description('App Service Plan name')
param appServicePlanName string = 'neighborly-plan-${suffix}'

@description('Event Grid Topic name')
param eventGridTopicName string = 'neighborly-events-${suffix}'

@description('Logic App name')
param logicAppName string = 'neighborly-notification-${suffix}'

@description('Email address for Logic App notifications')
param notificationEmail string = ''

@description('Container Registry name (5-50 chars, alphanumeric only)')
param containerRegistryName string = 'nacr${suffix}'

@description('AKS cluster name')
param aksClusterName string = 'neighborly-aks-${suffix}'

@description('Deploy AKS cluster (set to false for minimal cost)')
param deployAKS bool = false

@description('Deploy Container Registry (set to false if already exists)')
param deployACR bool = false

// ============================================
// Cosmos DB (MongoDB API)
// ============================================
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: cosmosAccountName
  location: location
  kind: 'MongoDB'
  tags: {
    environment: environment
    project: 'neighborly'
  }
  properties: {
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Eventual'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    capabilities: [
      {
        name: 'EnableMongo'
      }
    ]
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases@2023-04-15' = {
  parent: cosmosAccount
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
    options: {
      throughput: 400
    }
  }
}

resource advertisementsCollection 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases/collections@2023-04-15' = {
  parent: database
  name: 'advertisements'
  properties: {
    resource: {
      id: 'advertisements'
      shardKey: {
        _id: 'Hash'
      }
      indexes: [
        {
          key: {
            keys: [
              '_id'
            ]
          }
        }
      ]
    }
  }
}

resource postsCollection 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases/collections@2023-04-15' = {
  parent: database
  name: 'posts'
  properties: {
    resource: {
      id: 'posts'
      shardKey: {
        _id: 'Hash'
      }
      indexes: [
        {
          key: {
            keys: [
              '_id'
            ]
          }
        }
      ]
    }
  }
}

// ============================================
// Storage Account for Function App
// ============================================
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: {
    environment: environment
    project: 'neighborly'
  }
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

// ============================================
// App Service Plan (Consumption)
// ============================================
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  tags: {
    environment: environment
    project: 'neighborly'
  }
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  kind: 'functionapp'
  properties: {
    reserved: true // Required for Linux
  }
}

// ============================================
// Function App
// ============================================
resource functionApp 'Microsoft.Web/sites@2023-01-01' = {
  name: functionAppName
  location: location
  tags: {
    environment: environment
    project: 'neighborly'
  }
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'Python|3.9'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${az.environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${az.environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'CosmosDb'
          value: cosmosAccount.listConnectionStrings().connectionStrings[0].connectionString
        }
        {
          name: 'EVENT_GRID_TOPIC_ENDPOINT'
          value: eventGridTopic.properties.endpoint
        }
        {
          name: 'EVENT_GRID_TOPIC_KEY'
          value: eventGridTopic.listKeys().key1
        }
      ]
      cors: {
        allowedOrigins: [
          '*'
        ]
      }
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
    }
    httpsOnly: true
  }
}

// ============================================
// Event Grid Topic
// ============================================
resource eventGridTopic 'Microsoft.EventGrid/topics@2023-06-01-preview' = {
  name: eventGridTopicName
  location: location
  tags: {
    environment: environment
    project: 'neighborly'
  }
  properties: {
    inputSchema: 'EventGridSchema'
    publicNetworkAccess: 'Enabled'
  }
}

// ============================================
// Logic App (Workflow)
// ============================================
resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: logicAppName
  location: location
  tags: {
    environment: environment
    project: 'neighborly'
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {}
      triggers: {
        manual: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {
              type: 'object'
              properties: {
                subject: {
                  type: 'string'
                }
                data: {
                  type: 'object'
                }
              }
            }
          }
        }
      }
      actions: {
        Parse_JSON: {
          type: 'ParseJson'
          inputs: {
            content: '@triggerBody()?[\'data\']'
            schema: {
              type: 'object'
              properties: {
                title: {
                  type: 'string'
                }
                description: {
                  type: 'string'
                }
              }
            }
          }
          runAfter: {}
        }
        Send_an_email: {
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
              }
            }
            method: 'post'
            path: '/v2/Mail'
            body: {
              To: notificationEmail
              Subject: 'New Advertisement: @{body(\'Parse_JSON\')?[\'title\']}'
              Body: 'A new advertisement has been posted:\n\nTitle: @{body(\'Parse_JSON\')?[\'title\']}\nDescription: @{body(\'Parse_JSON\')?[\'description\']}'
            }
          }
          runAfter: {
            Parse_JSON: [
              'Succeeded'
            ]
          }
        }
      }
      outputs: {}
    }
  }
}

// ============================================
// Event Grid Subscription (Topic -> Logic App)
// ============================================
resource eventGridSubscription 'Microsoft.EventGrid/eventSubscriptions@2023-06-01-preview' = {
  name: 'neighborly-subscription'
  scope: eventGridTopic
  properties: {
    destination: {
      endpointType: 'WebHook'
      properties: {
        endpointUrl: listCallbackUrl(resourceId('Microsoft.Logic/workflows/triggers', logicApp.name, 'manual'), '2019-05-01').value
      }
    }
    filter: {
      includedEventTypes: [
        'Advertisement.Created'
      ]
    }
    eventDeliverySchema: 'EventGridSchema'
  }
}

// ============================================
// Container Registry (Optional)
// ============================================
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = if (deployACR) {
  name: containerRegistryName
  location: location
  tags: {
    environment: environment
    project: 'neighborly'
  }
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
    publicNetworkAccess: 'Enabled'
  }
}

// ============================================
// AKS Cluster (Optional)
// ============================================
resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-10-01' = if (deployAKS) {
  name: aksClusterName
  location: location
  tags: {
    environment: environment
    project: 'neighborly'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: '${aksClusterName}-dns'
    agentPoolProfiles: [
      {
        name: 'agentpool'
        count: 1
        vmSize: 'Standard_B2s'
        osType: 'Linux'
        mode: 'System'
      }
    ]
    networkProfile: {
      networkPlugin: 'kubenet'
      loadBalancerSku: 'standard'
    }
  }
}

// Grant AKS access to ACR
resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployAKS && deployACR) {
  name: guid(resourceGroup().id, aksClusterName, 'acrpull')
  scope: containerRegistry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull role
    principalId: deployAKS ? aksCluster.identity.principalId : ''
    principalType: 'ServicePrincipal'
  }
}

// ============================================
// Outputs
// ============================================
output cosmosConnectionString string = cosmosAccount.listConnectionStrings().connectionStrings[0].connectionString
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output functionAppName string = functionApp.name
output eventGridTopicEndpoint string = eventGridTopic.properties.endpoint
output eventGridTopicKey string = eventGridTopic.listKeys().key1
output logicAppTriggerUrl string = listCallbackUrl(resourceId('Microsoft.Logic/workflows/triggers', logicApp.name, 'manual'), '2019-05-01').value
output storageAccountName string = storageAccount.name
output resourceGroupName string = resourceGroup().name
@description('Container Registry login server (empty if not deployed)')
output containerRegistryLoginServer string = deployACR ? containerRegistry.properties.loginServer : ''

@description('Container Registry name (empty if not deployed)')
output containerRegistryName string = deployACR ? containerRegistry.name : ''

@description('AKS cluster name (empty if not deployed)')
output aksClusterName string = deployAKS ? aksCluster.name : ''
