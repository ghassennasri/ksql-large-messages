# README

This script demonstrates how to produce records with large messages using ksqlDB and Kafka. It shows the process of setting up a Kafka and ksqlDB environment, creating a stream and a table, and producing records with large messages that could cause a `RecordTooLargeException`.

## Prerequisites

- Docker and Docker Compose installed on your machine
- `jq` command-line tool installed

## Usage

1. Clone this repository and navigate to the project directory.
2. Run the bash script `./large-message-demo.sh`.
3. The script will start the Kafka and ksqlDB using the `docker-compose.yml` file.
4. It will create a stream and a table with large messages.
5. Records will be produced to the stream and table topics.
6. A join between the stream and table will be performed, causing a `RecordTooLargeException`.
7. The script will then stop the Kafka and ksqlDB environment.
8. The script will start a new Kafka and ksqlDB environment with increased message limits using the `docker-compose-large-messages.yml` file.
9. The process from step 3 to step 6 will be repeated, but this time there should be no exception due to the increased message limits.

## Configuration

In the `docker-compose-large-messages.yml` file, the following configurations are modified to handle larger messages:

- `KAFKA_MESSAGE_MAX_BYTES: 2000000` : Sets the maximum message size for Kafka to 2MB.
- `KSQL_KSQL_STREAMS_PRODUCER_MAX_REQUEST_SIZE: 2000000` : Sets the maximum request size for the ksqlDB producer to 2MB.
- `KSQL_KSQL_STREAMS_CONSUMER_MAX_PARTITION_FETCH_BYTES: 2000000` : Sets the maximum fetch size for the ksqlDB consumer to 2MB.

These configurations allow the Kafka broker, ksqlDB producer, and ksqlDB consumer to handle messages up to 2MB in size.

And also;
- `KSQL_KSQL_LOGGING_PROCESSING_ROWS_INCLUDE: 'true'` : To print the contents of the row that caused the error but it's not applicable to
RecordTooLargeException as it's triggered at the producer level and reported to ksql as kafkaStreamsThreadError which does not 
give any information about the record that caused the failure. 
This parameter would be efficient to track serialization/deserialization or processing Errors 
Refer to https://docs.ksqldb.io/en/latest/reference/processing-log/

The current workaround based on https://github.com/a0x8o/kafka/blob/master/streams/src/main/java/org/apache/kafka/streams/processor/internals/RecordCollectorImpl.java#L257  would be to set the logger for `org.apache.kafka.streams.processor.internals.RecordCollectorImpl` to TRACE level and grep for `Failed record`
Example : `grep -E 'Failed record: \(key.*value.*timestamp.*\) topic=\[.*\] partition=\[.*\]'`






