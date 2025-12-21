# Stage 1: Build
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
# Placeholder is used during build to be replaced at runtime
ENV VITE_API_URL=PLACEHOLDER_VITE_API_URL
RUN npm run build

# Stage 2: Serve with Nginx
FROM nginx:stable-alpine
# NEW: Copy the nginx.conf (Bridge) into the image
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
# AUTOMATION: Swap placeholder for real Azure URL on container start
# This will now swap the placeholder with "/api" based on your Bicep config
CMD ["/bin/sh", "-c", "sed -i 's|PLACEHOLDER_VITE_API_URL|'\"${VITE_API_URL}\"'|g' /usr/share/nginx/html/assets/*.js && nginx -g 'daemon off;'"]