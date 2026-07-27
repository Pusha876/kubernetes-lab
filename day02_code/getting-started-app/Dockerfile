FROM node:26-alpine3.23
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .
CMD ["node", "src/index.js"]
EXPOSE 3000
