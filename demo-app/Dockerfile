FROM alpine:3.19

# Install curl for health checks
RUN apk add --no-cache curl

# Create a simple web server
COPY server.sh /server.sh
RUN chmod +x /server.sh

EXPOSE 8080

CMD ["/server.sh"]
