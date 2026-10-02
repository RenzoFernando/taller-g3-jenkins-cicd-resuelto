#!/usr/bin/env sh
set -eu

: "${GITHUB_REPO:?Defina GITHUB_REPO=owner/repo}"
: "${GITHUB_TOKEN:?Defina GITHUB_TOKEN con permiso para administrar webhooks}"
: "${SMEE_CHANNEL_URL:?Defina SMEE_CHANNEL_URL=https://smee.io/...}"

curl -fsS -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/$GITHUB_REPO/hooks" \
  -d "{
    \"name\": \"web\",
    \"active\": true,
    \"events\": [\"push\"],
    \"config\": {
      \"url\": \"$SMEE_CHANNEL_URL\",
      \"content_type\": \"json\",
      \"insecure_ssl\": \"0\"
    }
  }"
