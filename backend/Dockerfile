FROM node:22-alpine AS deps
WORKDIR /app/backend
COPY package*.json ./
RUN npm ci

FROM deps AS build
COPY tsconfig.json ./tsconfig.json
COPY src ./src
RUN npm run build

FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY --from=deps /app/backend/node_modules ./backend/node_modules
COPY --from=build /app/backend/dist ./backend/dist
COPY package.json ./backend/package.json
WORKDIR /app/backend
EXPOSE 3000
CMD ["node", "dist/server.js"]
