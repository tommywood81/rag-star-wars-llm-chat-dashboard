# Frontend Service Dockerfile - Optimized Multi-stage Build
FROM node:20-alpine AS build

# Set working directory
WORKDIR /app

# Copy package files first for better caching
COPY package*.json ./

# Install dependencies
RUN npm install --omit=dev

# Copy source code
COPY src/ ./src/
COPY public/ ./public/

# Set environment variables for build
ARG REACT_APP_API_URL=http://209.38.89.159:8002
ARG REACT_APP_STT_URL=http://209.38.89.159:5001
ARG REACT_APP_TTS_URL=http://209.38.89.159:5002
ARG REACT_APP_LLM_URL=http://209.38.89.159:5003

ENV REACT_APP_API_URL=$REACT_APP_API_URL
ENV REACT_APP_STT_URL=$REACT_APP_STT_URL
ENV REACT_APP_TTS_URL=$REACT_APP_TTS_URL
ENV REACT_APP_LLM_URL=$REACT_APP_LLM_URL

# Build the application
RUN npm run build

# Production stage - Lightweight static server
FROM node:20-alpine

# Install lightweight static file server
RUN npm install -g serve@14.2.3

# Set working directory
WORKDIR /app

# Copy built assets from build stage
COPY --from=build /app/build ./build

# Expose port
EXPOSE 3000

# Start static server
CMD ["serve", "-s", "build", "-l", "3000"]
