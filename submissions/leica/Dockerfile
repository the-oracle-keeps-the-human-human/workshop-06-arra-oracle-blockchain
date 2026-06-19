FROM docker:27-cli
RUN apk add --no-cache bash openssl curl jq
WORKDIR /app
COPY . .
RUN chmod +x run.sh
ENTRYPOINT ["./run.sh"]
