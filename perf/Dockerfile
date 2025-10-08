FROM node:22-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy test files
COPY *.yaml ./
COPY *.sh ./
COPY perf/*.yaml ./

# Make script executable
RUN chmod +x run-scenario.sh

# Default command
CMD ["npm", "run", "api"]
