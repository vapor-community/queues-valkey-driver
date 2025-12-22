import Queues
import QueuesValkeyDriver
import Testing
import Valkey
import Vapor
import VaporTesting
import VaporValkey

@Suite
struct QueuesValkeyDriverTests {
    @Test func application() async throws {
        try await withApp { app in
            let client = ValkeyClient(
                .hostname(valkeyHostname(), port: valkeyPort()),
                eventLoopGroup: app.eventLoopGroup,
                logger: app.logger
            )
            app.valkey = client
            app.queues.configuration.persistenceKey = "\(UUID())"
            try app.queues.use(.valkey())

            let email = Email()
            app.queues.add(email)

            app.get("send-email") { req in
                try await req.queue.dispatch(Email.self, .init(to: "person@example.com"))
                return HTTPStatus.ok
            }

            try await app.testing().test(.GET, "send-email") { res in
                #expect(res.status == .ok)
            }

            #expect(email.sent == [])
            try await app.queues.queue.worker.run()
            #expect(email.sent == [.init(to: "person@example.com")])
        }
    }

    @Test func failedJobLoss() async throws {
        try await withApp { app in
            let client = ValkeyClient(
                .hostname(valkeyHostname(), port: valkeyPort()),
                eventLoopGroup: app.eventLoopGroup,
                logger: app.logger
            )
            app.valkey = client
            app.queues.configuration.persistenceKey = "\(UUID())"
            try app.queues.use(.valkey())

            app.queues.add(FailingJob())
            let jobId = JobIdentifier()
            app.get("test") { req in
                try await req.queue.dispatch(FailingJob.self, ["foo": "bar"], id: jobId)
                return HTTPStatus.ok
            }

            try await app.testing().test(.GET, "test") { res in
                #expect(res.status == .ok)
            }

            do {
                try await app.queues.queue.worker.run()
            } catch is FailingJob.Failure {
                // pass
            } catch {
                Issue.record("unexpected error: \(error)")
            }

            // ensure this failed job is still in storage
            let result = try #require(await client.get(.init(jobId.key)))
            let job = try JSONDecoder().decode(JobData.self, from: ByteBuffer(result))
            #expect(job.jobName == "FailingJob")
        }
    }

    @Test func dateEncoding() async throws {
        try await withApp { app in
            let client = ValkeyClient(
                .hostname(valkeyHostname(), port: valkeyPort()),
                eventLoopGroup: app.eventLoopGroup,
                logger: app.logger
            )
            app.valkey = client
            app.queues.configuration.persistenceKey = "\(UUID())"
            try app.queues.use(.valkey())

            app.queues.add(DelayedJob())
            let jobId = JobIdentifier()
            app.get("delay-job") { req in
                try await req.queue.dispatch(
                    DelayedJob.self,
                    .init(name: "vapor"),
                    delayUntil: Date(timeIntervalSince1970: 1_609_477_200), // Jan 1, 2021
                    id: jobId
                )
                return HTTPStatus.ok
            }

            try await app.testing().test(.GET, "delay-job") { res in
                #expect(res.status == .ok)
            }

            // Verify the delayUntil date is encoded as the correct epoch time
            let result = try #require(await client.get(.init(jobId.key)))
            let dict = try JSONSerialization.jsonObject(with: ByteBuffer(result), options: .allowFragments) as! [String: Any]

            #expect(dict["jobName"] as! String == "DelayedJob")
            #expect(dict["delayUntil"] as! Int == 1_609_477_200)
        }
    }

    @Test func delayedJobIsRemovedFromProcessingQueue() async throws {
        try await withApp { app in
            let client = ValkeyClient(
                .hostname(valkeyHostname(), port: valkeyPort()),
                eventLoopGroup: app.eventLoopGroup,
                logger: app.logger
            )
            app.valkey = client
            let persistenceKey = "\(UUID())"
            app.queues.configuration.persistenceKey = persistenceKey
            try app.queues.use(.valkey())

            app.queues.add(DelayedJob())
            let jobId = JobIdentifier()
            app.get("delay-job") { req in
                try await req.queue.dispatch(
                    DelayedJob.self,
                    .init(name: "vapor"),
                    delayUntil: Date().addingTimeInterval(3600),
                    id: jobId
                )
                return HTTPStatus.ok
            }

            try await app.testing().test(.GET, "delay-job") { res in
                #expect(res.status == .ok)
            }

            // Verify that a delayed job isn't still in processing after it's been put back in the queue
            try await app.queues.queue.worker.run()
            let value = try await client.lrange(
                .init("\(persistenceKey)[default]-processing"),
                start: 0,
                stop: 10
            ).decode(as: [String].self)
            let originalQueue = try await client.lrange(
                .init("\(persistenceKey)[default]"),
                start: 0,
                stop: 10
            ).decode(as: [String].self)
            #expect(value.count == 0)
            #expect(originalQueue.contains(jobId.string))
        }
    }
}

final class Email: Job, @unchecked Sendable {
    struct Message: Codable, Equatable {
        let to: String
    }

    var sent: [Message]

    init() {
        sent = []
    }

    func dequeue(_ context: QueueContext, _ message: Message) -> EventLoopFuture<Void> {
        sent.append(message)
        context.logger.info("sending email \(message)")
        return context.eventLoop.makeSucceededFuture(())
    }
}

final class DelayedJob: Job {
    struct Message: Codable, Equatable {
        let name: String
    }

    init() {}

    func dequeue(_ context: QueueContext, _ message: Message) -> EventLoopFuture<Void> {
        context.logger.info("Hello \(message.name)")
        return context.eventLoop.makeSucceededFuture(())
    }
}

struct FailingJob: Job {
    struct Failure: Error {}

    init() {}

    func dequeue(_ context: QueueContext, _: [String: String]) -> EventLoopFuture<Void> {
        return context.eventLoop.makeFailedFuture(Failure())
    }

    func error(_ context: QueueContext, _: Error, _: [String: String]) -> EventLoopFuture<Void> {
        return context.eventLoop.makeFailedFuture(Failure())
    }
}
