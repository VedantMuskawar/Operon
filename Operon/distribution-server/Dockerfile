FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install production dependencies
RUN npm ci --only=production

# Copy application code
COPY . .

# Cloud Run uses PORT environment variable (default 8080)
EXPOSE 8080

# Start the application
CMD ["node", "server.js"]
