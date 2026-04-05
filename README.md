# VigilSpy

VigilSpy is a proxy-based DataModel activity-tracker utility.
**Version**: 1.0.1, Build 4520261035, Last updated 4/25/2026

# What does this do?

> Some features listed here are not usable at the moment.

- Tracks method calls on services, scripts, UI elements, remotes, and value objects using Proxies
- Tracks property changes with old and new values across every instance type
- Monitors instance events (deletion & creation) across the DataModel
- Logs player leaves & joins

# Settings global?

It is `getgenv().VigilConfiguration`
> Only setting available at the moment is "TrackInstanceMethods", which logs if a method from an Instance was called.
