FROM ethereum/client-go:v1.13.15
WORKDIR /app
COPY genesis.json .
COPY run.sh .
RUN chmod +x run.sh
EXPOSE 8545 30315
ENTRYPOINT ["./run.sh"]
