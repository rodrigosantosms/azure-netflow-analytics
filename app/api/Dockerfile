# API Dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY app/api/ ./
RUN dotnet restore ./api.csproj
RUN dotnet publish ./api.csproj -c Release -o /out

FROM base AS final
WORKDIR /app
COPY --from=build /out ./
ENTRYPOINT ["dotnet", "api.dll"]
