# Web Dockerfile
FROM node:20-alpine AS build
WORKDIR /app
COPY app/web/package.json ./
RUN npm ci || npm install
COPY app/web/ ./
RUN npm run build

FROM node:20-alpine AS runtime
WORKDIR /app
ENV PORT=3000
ENV NODE_ENV=production
COPY --from=build /app/.next ./.next
COPY --from=build /app/package.json ./
RUN npm i next
EXPOSE 3000
CMD ["npx","next","start","-p","3000"]
