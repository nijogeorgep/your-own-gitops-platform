FROM nginx:alpine

# Add metadata
LABEL maintainer="gitops-platform"
LABEL description="Nginx web server for GitOps platform demo"

# Copy custom nginx configuration (optional)
# COPY nginx.conf /etc/nginx/nginx.conf

# Copy static content (optional)
# COPY ./html /usr/share/nginx/html

# Create a custom index page
RUN echo '<!DOCTYPE html>\
<html>\
<head>\
    <title>GitOps Platform - Nginx</title>\
    <style>\
        body { font-family: Arial, sans-serif; margin: 50px; background: #f0f0f0; }\
        .container { background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }\
        h1 { color: #326CE5; }\
        .info { background: #e8f4f8; padding: 15px; border-radius: 5px; margin: 20px 0; }\
        .version { color: #666; font-size: 0.9em; }\
    </style>\
</head>\
<body>\
    <div class="container">\
        <h1>🚀 GitOps Platform</h1>\
        <div class="info">\
            <p><strong>Service:</strong> Nginx Web Server</p>\
            <p><strong>Environment:</strong> <span id="env">Loading...</span></p>\
            <p><strong>Version:</strong> <span class="version">BUILD_VERSION</span></p>\
        </div>\
        <p>This application is deployed using:</p>\
        <ul>\
            <li>✅ ArgoCD ApplicationSet (GitOps)</li>\
            <li>✅ Argo Events (Event-driven automation)</li>\
            <li>✅ Argo Workflows (CI/CD pipeline)</li>\
            <li>✅ Istio Service Mesh</li>\
            <li>✅ Kubernetes</li>\
        </ul>\
    </div>\
    <script>\
        fetch("/").then(() => {\
            const hostname = window.location.hostname;\
            const env = hostname.includes("dev") ? "Development" : \
                       hostname.includes("staging") ? "Staging" : \
                       hostname.includes("prod") ? "Production" : "Unknown";\
            document.getElementById("env").textContent = env;\
        });\
    </script>\
</body>\
</html>' > /usr/share/nginx/html/index.html

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:80/ || exit 1

# Expose port
EXPOSE 80

# Run nginx
CMD ["nginx", "-g", "daemon off;"]
