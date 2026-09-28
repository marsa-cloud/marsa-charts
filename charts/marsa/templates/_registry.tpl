{{- define "marsa.registryConfig" -}}
{
  "distSpecVersion": "1.1.1",
  "storage": {
    "rootDirectory": "/var/lib/registry",
    "gc": true,
    "gcDelay": "1h",
    "gcInterval": "1h",
    "retention": {
      "delay": "24h",
      "policies": [
        {
          "repositories": ["**"],
          "deleteReferrers": true,
          "deleteUntagged": true,
          "keepTags": [{ "mostRecentlyPushedCount": {{ .Values.registry.keepImages }} }]
        }
      ]
    }
  },
  "http": {
    "address": "0.0.0.0",
    "port": "5000",
    "auth": { "htpasswd": { "path": "/etc/zot/auth/htpasswd" } },
    "accessControl": {
      "repositories": {
        "**": {
          "policies": [
            { "users": ["marsa-push"], "actions": ["read", "create", "update", "delete"] },
            { "users": ["marsa-pull"], "actions": ["read"] }
          ],
          "defaultPolicy": []
        }
      }
    }
  },
  "log": { "level": "info" }
}
{{- end }}
