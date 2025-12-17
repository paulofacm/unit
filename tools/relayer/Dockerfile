FROM node:18-alpine
WORKDIR /usr/src/app

# Install build deps for pkg (optional)
RUN apk add --no-cache python3 make g++ libc6-compat

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 8080
CMD ["node", "index.js"]
