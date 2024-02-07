# Zoom Chat Publisher

## What is this?

Monitors Zoom chat messages in the macOS Zoom client, and makes a simple HTTP
calls for each message detected.

## How do I run it?

Build and run:
```shell
swift run -c release zoom-chat-publisher --destination-url (url to destination endpoint)
```

Build then run:
```shell
make
.build/release/zoom-chat-publisher --destination-url (url to destination endpoint)
```

