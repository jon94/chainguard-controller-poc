#!/bin/sh

# Simple HTTP server for demo purposes
echo "Starting demo application server..."

# Create a simple response
cat > /tmp/response.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Chainguard Demo App</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { color: #2c3e50; }
        .version { background: #ecf0f1; padding: 10px; border-radius: 5px; }
    </style>
</head>
<body>
    <h1 class="header">🔐 Chainguard Demo Application</h1>
    <div class="version">
        <h3>Version Information:</h3>
        <p><strong>Build Time:</strong> $(date)</p>
        <p><strong>Container ID:</strong> $(hostname)</p>
        <p><strong>Purpose:</strong> Demonstrating image digest compliance monitoring</p>
    </div>
    <p>This application is monitored by the Chainguard Image Policy Controller.</p>
    <p>The controller ensures this deployment uses the latest signed image digest.</p>
</body>
</html>
EOF

# Start simple HTTP server
while true; do
    echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n$(cat /tmp/response.html)" | nc -l -p 8080
done
