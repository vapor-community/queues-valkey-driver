# Queues Valkey Driver

This project provides [valkey-swift](https://github.com/valkey-io/valkey-swift) as a driver for [Vapor Queues](https://github.com/vapor/queues), by integrating with [VaporValkey](https://github.com/vapor-community/valkey).

## Usage

To use this package, add it as a dependency. Then assign a Valkey client to `Application.valkey`, and configure Queues to use Valkey via `Application.queues.use(.valkey())`:

```swift
import Queues
import QueuesValkeyDriver
import Valkey
import Vapor
import VaporValkey

let app = Application.make(.detect)

// Attach a valkey client using https://github.com/vapor-community/valkey
app.valkey = ValkeyClient(
    .hostname("localhost", port: 6379),
    eventLoopGroup: app.eventLoopGroup,
    logger: app.logger
)

// Register valkey as the queues driver
try app.queues.use(.valkey())
```
