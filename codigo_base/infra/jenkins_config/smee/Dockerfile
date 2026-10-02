FROM node:20-alpine

RUN npm install -g smee-client

USER node
ENV SMEE_TARGET=http://jenkins:8080/github-webhook/

ENTRYPOINT ["sh", "-c", "smee -u \"$SMEE_URL\" -t \"$SMEE_TARGET\""]
