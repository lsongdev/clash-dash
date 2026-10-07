# ClashHandy Privacy Policy

Last updated: October 7, 2026

ClashHandy (the ClashDash project) is a dashboard for a Clash-compatible controller that you configure. It does not operate a proxy or VPN service and does not require a developer-hosted account.

## Data handled on your device

The app stores your controller addresses, ports, names, authentication Secrets, preferences, and optional client labels on your device. The app and its Home Screen widget share the selected controller configuration and cached traffic and connection counts through an iOS App Group. Device backups may include app data according to your operating system settings.

Controller responses, including proxy and provider information, subscription usage, rules, connection details, traffic statistics, and logs, are used to display the dashboard and perform actions you request. The developer does not receive this information through the app.

## Network connections

The app and widget send requests directly to your configured controller. Authentication Secrets are sent to that controller to authorize requests. The controller's operator determines its own logging, retention, and privacy practices. Choose controllers you trust and use HTTPS where available.

When you run latency tests, the app asks your controller to test the configured destination URL. That destination may receive network requests from the controller or its proxies. The default test destination is Google's connectivity-check endpoint.

If you choose "View IP Information," the app opens an IP information page at ipinfo.io containing the selected destination IP address. That website receives the requested IP address and ordinary web-request information. Opening support or project links also connects to the corresponding third-party website. These websites apply their own privacy policies.

## Developer collection and tracking

The app does not send analytics, advertising identifiers, usage logs, controller credentials, or dashboard data to a developer-operated service. It includes no advertising or analytics SDK and does not track you across other apps or websites. The developer does not sell app data.

If you contact support or submit a GitHub issue, the information you choose to provide is handled by that communication service and used to address your request. Do not post controller Secrets or other private information in public issues.

## Your choices

You can edit or delete saved controllers and remove widgets. Removing the app removes its local app container; shared widget storage and backups are managed by iOS. The developer cannot access or delete information held by your controller operator, third-party websites, or your device backups.

## Changes and contact

This policy may be updated when the app's behavior changes. The current policy is published in the project repository. For privacy questions, contact the maintainer through [the project issue tracker](https://github.com/lsongdev/clash-dash/issues). Avoid including sensitive information in public messages.
