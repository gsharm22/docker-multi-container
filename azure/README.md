# Azure App Service deployment

This deployment runs the client, Nginx, API, and worker as containers in one Linux App Service application. The one-time Bicep deployment also creates the managed PostgreSQL server and Redis cache. PostgreSQL Flexible Server supplies the default `postgres` database, so the template uses it without trying to create it again.

The Bicep template does not create an ACR or resource group. It creates/configures the App Service plan, web app, PostgreSQL server, Redis cache, and four site containers using images from an existing ACR.

## Reuse an existing ACR

Yes. The existing registry can be reused. The workflow pushes these repositories into it:

- `multi-client`
- `multi-nginx`
- `multi-server`
- `multi-worker`

The ACR user or repository token used by GitHub needs read/write access to these repositories. The credentials passed to Bicep need read access so App Service can pull the images.

## One-time App Service configuration

Deploy `container-group.bicep` once from an account that has permission to configure App Service:

```powershell
az deployment group create `
  --resource-group '<existing-resource-group>' `
  --name 'multi-react-appservice' `
  --template-file .\azure\container-group.bicep `
  --parameters `
    appName='multi-react-app' `
    postgresServerName='multi-react-app-postgres' `
    acrServer='<registry-name>.azurecr.io' `
    acrUsername='<acr-username-or-token-name>' `
    acrPassword='<acr-password-or-token-password>' `
    redisName='<globally-unique-redis-name>' `
    postgresUser='<postgres-user>' `
    postgresPassword='<postgres-password>'
```

For production, pass sensitive parameters through a secure deployment mechanism rather than putting them directly in shell history.

The template creates the PostgreSQL server, Redis cache, App Service plan, and web app, then configures these containers:

- Nginx as the public container on port 80
- Client on internal port 3000
- API on internal port 5000
- Worker as a background sidecar

The Nginx image uses `127.0.0.1:3000` and `127.0.0.1:5000`. App Service sidecars share a network namespace, so this matches the application routing configuration.

## App Service settings

The Bicep template supplies the database and Redis settings to the containers. If configuring the application through the portal instead, use:

- `WEBSITES_PORT=80`
- `REDIS_HOST`
- `REDIS_PORT=6380`
- `REDIS_TLS=true`
- `REDIS_PASSWORD`
- `PGHOST`
- `PGPORT=5432`
- `PGUSER`
- `PGPASSWORD`
- `PGDATABASE=postgres`

Keep passwords in App Service configuration or Key Vault.

## Continuous image publishing

The GitHub Actions workflow only builds and pushes images to ACR. Configure ACR continuous deployment or an ACR webhook in App Service so an image push restarts the app and pulls the new `latest` images.

The root development Compose file is not used for this deployment. The optional [docker-compose.appservice.yml](./docker-compose.appservice.yml) is provided for portal-based multi-container configuration.

## Important limitation

The worker runs as a sidecar, so it shares the App Service application's lifecycle and scaling. If it needs independent scaling, move it to a separate worker service such as Azure Container Apps Jobs.

## Validation

Validate the template before deployment:

```powershell
az bicep build --file .\azure\container-group.bicep --stdout | Out-Null
```
