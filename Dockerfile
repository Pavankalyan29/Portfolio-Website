# Dockerfile - static portfolio served by nginx
FROM nginx:stable-alpine

# Remove default nginx content
RUN rm -rf /usr/share/nginx/html/*

# Copy site files (assumes your site is in the repo root or adjust path)
COPY . /usr/share/nginx/html

# Expose port
EXPOSE 80

# Healthcheck (optional)
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s CMD wget --no-verbose --spider http://localhost/ || exit 1

# Start nginx (nginx is the default CMD in the base image)
