# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package.json yarn.lock ./

# Install dependencies
RUN yarn install --frozen-lockfile

# Copy the rest of the source
COPY . .

# Build CSS and Zola site
RUN yarn build

# Serve stage
FROM nginx:alpine

# Copy built site to nginx
COPY --from=builder /app/public /usr/share/nginx/html

# Expose port 80
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
