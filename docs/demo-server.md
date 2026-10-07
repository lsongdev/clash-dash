# Local demo controller

The built-in **Demo Server** is a real HTTP and WebSocket server bound only to
`127.0.0.1`, on an automatically assigned port. It is never exposed to the LAN
and never connects to a real controller or forwards network traffic.

The normal ClashAPI, URLSession clients, view models and screens are unchanged.
AppManager starts the listener and adds its endpoint to the server selector.
Selecting it exercises the same protocol and decoding paths as a remote server.
The selector labels its data as simulated. At launch, an empty server list presents
the welcome screen; **Get started** adds and selects Demo Server. This decision is
made once: deleting servers during the session keeps the dashboard open. Existing
installations keep their saved server selection. A saved demo endpoint is
updated to the listener's new port after each launch and foreground recovery.
On entering the background, the listener and all peers are closed. On returning
to the foreground, a new loopback listener is started before publishing its port.
A new connection generation also restarts clients if the OS reuses the same port.
The in-memory controller state survives these cycles; cancelled listener callbacks
cannot overwrite the new endpoint.

Supported features include proxy groups, node selection, simulated latency tests,
subscription usage, rule toggles, provider refresh, configuration changes, DNS
fixtures, connection closure, and live traffic/memory/connections/log streams.
All data is fictional. DNS and latency results are simulations, not real probes.
Changes are held in memory and reset when the app process restarts.

The listener serves bounded requests and WebSocket frames and limits active
connections. Streams stop when their client disconnects. Demo selection clears
the real-server widget configuration: an extension cannot depend on the main
app's foreground-only listener.

## Review instructions

Open the server selector and choose **Demo Server**. No account, password,
external controller or internet connection is required. All normal tabs can be
explored using fictional data, without affecting any real service.

## Tests

`DemoControllerTests` connects through ordinary URLSession HTTP and WebSocket
clients, including ping/pong, to verify payload decoding and local state changes.
