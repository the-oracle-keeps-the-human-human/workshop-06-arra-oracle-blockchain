FROM alpine:3.20
RUN apk add --no-cache bash coreutils python3
WORKDIR /app
COPY run.sh .
RUN chmod +x run.sh
ENV ORACLE_NAME=leica ORACLE_ROLE=orchestrator
VOLUME ["/data"]
CMD ["./run.sh"]
