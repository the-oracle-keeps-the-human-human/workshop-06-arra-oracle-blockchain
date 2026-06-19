FROM node:18-alpine

WORKDIR /app

# Copy dependency files
COPY package.json package-lock.json ./

# Install only production dependencies
RUN npm ci --only=production

# Copy source code
COPY floodboy-ingest.cjs ./

# Ensure data directory exists
RUN mkdir -p data

# Set entrypoint to the ingest script
ENTRYPOINT ["node", "floodboy-ingest.cjs"]
CMD ["incremental"]
