@description('Name of the Linux App Service web app.')
param appName string = 'multi-react-app'

@description('Name of the Linux App Service plan.')
param appServicePlanName string = '${appName}-plan'

param location string = resourceGroup().location
param skuName string = 'B1'

@description('Existing ACR login server, without https://, for example myregistry.azurecr.io.')
param acrServer string

@description('Existing ACR username or repository token name.')
param acrUsername string

@secure()
@description('Existing ACR password or repository token password.')
param acrPassword string

@description('Image tag to deploy. Use latest for ACR webhook deployment or a commit SHA for an explicit revision.')
param imageTag string = 'latest'

@description('Globally unique name for the Azure Cache for Redis instance.')
param redisName string = '${appName}-cache'

param redisPort string = '6380'
param redisTls string = 'true'

param postgresUser string = 'appadmin'

@description('Name of the PostgreSQL Flexible Server.')
param postgresServerName string = '${appName}-postgres'

@secure()
param postgresPassword string

param postgresPort string = '5432'

var registryUrl = 'https://${acrServer}'
var appSettings = [
  {
    name: 'WEBSITES_PORT'
    value: '80'
  }
  {
    name: 'DOCKER_REGISTRY_SERVER_URL'
    value: registryUrl
  }
  {
    name: 'DOCKER_REGISTRY_SERVER_USERNAME'
    value: acrUsername
  }
  {
    name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
    value: acrPassword
  }
  {
    name: 'REDIS_HOST'
    value: redis.properties.hostName
  }
  {
    name: 'REDIS_PORT'
    value: redisPort
  }
  {
    name: 'REDIS_PASSWORD'
    value: redis.listKeys().primaryKey
  }
  {
    name: 'REDIS_TLS'
    value: redisTls
  }
  {
    name: 'PGHOST'
    value: postgres.properties.fullyQualifiedDomainName
  }
  {
    name: 'PGPORT'
    value: postgresPort
  }
  {
    name: 'PGUSER'
    value: postgresUser
  }
  {
    name: 'PGPASSWORD'
    value: postgresPassword
  }
  {
    name: 'PGDATABASE'
    value: 'postgres'
  }
]

resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'
  sku: {
    name: skuName
    tier: skuName == 'B1' ? 'Basic' : 'Standard'
  }
  properties: {
    reserved: true
  }
}

resource postgres 'Microsoft.DBforPostgreSQL/flexibleServers@2022-12-01' = {
  name: postgresServerName
  location: location
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    version: '16'
    administratorLogin: postgresUser
    administratorLoginPassword: postgresPassword
    storage: {
      storageSizeGB: 32
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
  }
}

resource postgresAzureFirewall 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2022-12-01' = {
  parent: postgres
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource redis 'Microsoft.Cache/Redis@2023-08-01' = {
  name: redisName
  location: location
  properties: {
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    redisConfiguration: {
      'maxmemory-policy': 'volatile-lru'
    }
    sku: {
      name: 'Basic'
      family: 'C'
      capacity: 0
    }
  }
}

resource app 'Microsoft.Web/sites@2024-04-01' = {
  name: appName
  location: location
  kind: 'app,linux,container'
  dependsOn: [
    postgresAzureFirewall
  ]
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      alwaysOn: true
      linuxFxVersion: 'sitecontainers'
      appSettings: appSettings
    }
  }
}

resource nginx 'Microsoft.Web/sites/sitecontainers@2025-03-01' = {
  parent: app
  name: 'nginx'
  kind: 'sitecontainer'
  properties: {
    image: '${acrServer}/multi-nginx:${imageTag}'
    isMain: true
    targetPort: '80'
    authType: 'UserCredentials'
    userName: acrUsername
    passwordSecret: acrPassword
    inheritAppSettingsAndConnectionStrings: true
  }
}

resource client 'Microsoft.Web/sites/sitecontainers@2025-03-01' = {
  parent: app
  name: 'client'
  kind: 'sitecontainer'
  properties: {
    image: '${acrServer}/multi-client:${imageTag}'
    isMain: false
    targetPort: '3000'
    authType: 'UserCredentials'
    userName: acrUsername
    passwordSecret: acrPassword
    inheritAppSettingsAndConnectionStrings: true
  }
}

resource server 'Microsoft.Web/sites/sitecontainers@2025-03-01' = {
  parent: app
  name: 'server'
  kind: 'sitecontainer'
  properties: {
    image: '${acrServer}/multi-server:${imageTag}'
    isMain: false
    targetPort: '5000'
    authType: 'UserCredentials'
    userName: acrUsername
    passwordSecret: acrPassword
    inheritAppSettingsAndConnectionStrings: true
  }
}

resource worker 'Microsoft.Web/sites/sitecontainers@2025-03-01' = {
  parent: app
  name: 'worker'
  kind: 'sitecontainer'
  properties: {
    image: '${acrServer}/multi-worker:${imageTag}'
    isMain: false
    authType: 'UserCredentials'
    userName: acrUsername
    passwordSecret: acrPassword
    inheritAppSettingsAndConnectionStrings: true
  }
}

output appUrl string = 'https://${app.properties.defaultHostName}'
output appName string = app.name
