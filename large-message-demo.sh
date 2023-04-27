#!/bin/bash

# Function to create and produce records
produce_records() {
  COMPOSE_FILE=$1
  echo "Starting Kafka and ksqlDB using $COMPOSE_FILE..."
  docker-compose -f $COMPOSE_FILE up -d

  echo "Waiting for Kafka to be ready..."
  sleep 60

  # Create a stream using the large_stream_topic
  docker-compose exec ksqldb-cli bash -c "ksql  http://$KSQL_SERVER <<EOF
CREATE STREAM large_stream (id VARCHAR, large_array ARRAY<VARCHAR>)
  WITH (kafka_topic='large_stream_topic', value_format='JSON', partitions=1);
EOF"

  # Create a table using the large_table_topic
  docker-compose exec ksqldb-cli bash -c "ksql  http://$KSQL_SERVER <<EOF
CREATE TABLE large_table (id VARCHAR PRIMARY KEY, large_array ARRAY<VARCHAR>)
  WITH (kafka_topic='large_table_topic', value_format='JSON', partitions=1);
EOF"

  # Produce records with large messages 
  echo "Producing large stream record..."
  
  # Function to generate a large array
  generate_large_array() {
    local size=$1
    local array="["
    for ((i=0; i<size; i++)); do
      array+="\"$i\""
      if [ $i -lt $((size-1)) ]; then
        array+=","
      fi
    done
    array+="]"
    echo "$array"
  }
  echo "writing to $STREAM_FILE" and $TABLE_FILE
  
  # Produce records with smaller arrays
  for ((id=1; id<=NUM_RECORDS; id++)); do
    large_array=$(generate_large_array $ARRAY_SIZE)
    echo "large_array is generated"
    stream_record=$(printf '%s*{"id":"%s", "large_array":%s}' "$id" "$id" "$large_array")
    table_record=$(printf '%s*{"id":"%s", "large_array":%s}' "$id" "$id" "$large_array")
  
    echo "Producing stream record: $id"
    echo $stream_record >> $STREAM_FILE
    echo "Producing table record: $id"
    echo $table_record >> $TABLE_FILE
  done
  
  echo "Records saved to $STREAM_FILE and $TABLE_FILE."
  #sleep 60
  #get the network name of the docker-compose network
  KAFKA_CONTAINER_NETWORK=$(docker container inspect broker | jq -r '.[].NetworkSettings.Networks | keys[]')
  
  # Produce records with large messages to topic large_table_topic
  echo "Producing records to large_table_topic..."
  docker run --rm --network $KAFKA_CONTAINER_NETWORK -v "$(pwd)":/data confluentinc/cp-kafkacat:latest  kafkacat  -b $KAFKA_BROKER -t large_table_topic -P  -K* -l /data/large_table_message.json
  
  # Wait for a moment to let the records be produced
  sleep 5
  
  # Create a join between the stream and the table, which will cause the RecordTooLargeException
  docker-compose exec ksqldb-cli bash -c "ksql  http://$KSQL_SERVER <<EOF
  CREATE STREAM joined_stream AS
    SELECT s.id, s.large_array AS s_array, t.large_array AS t_array
    FROM large_stream s
    JOIN large_table t ON s.id = t.id;
  EOF"
  
  # Wait for a moment to let the exception occur
  sleep 5
  # Produce records with large messages to topic large_stream_topic
  echo "Producing records to large_stream_topic..."
  docker run --rm --network $KAFKA_CONTAINER_NETWORK -v "$(pwd)":/data confluentinc/cp-kafkacat:latest  kafkacat -b $KAFKA_BROKER -t large_stream_topic -P  -K* -l /data/large_stream_message.json
  
  # Query KSQL_PROCESSING_LOG for exceptions
  #docker-compose exec ksqldb-cli bash -c "ksql  http://$KSQL_SERVER <<EOF
  #SELECT * FROM KSQL_PROCESSING_LOG EMIT CHANGES;
  #EOF"
  
  # Wait for a moment to let the exception occur
  # You should see the RecordTooLargeException in the output
  # you can type Ctrl-C to stop the query and exit the ksqlDB CLI and test the next scenario
  echo "Waiting 3min for the exception to occur...\n"
  echo "Press Ctrl-C to stop the query and exit the ksqlDB CLI and test the next scenario\n"
  #consume from ksql_processing_log_asgard
  timeout 180s docker run --rm --network $KAFKA_CONTAINER_NETWORK -v "$(pwd)":/data confluentinc/cp-kafkacat:latest  kafkacat -b $KAFKA_BROKER -t ksql_processing_log_asgard -C -o beginning

  
  echo "Printing failed records, press CTRL+c to skip...\n"
  echo "------------------------failed records------------------------\n"
  timeout 30s docker logs ksqldb-server | grep -E 'Failed record: \(key.*value.*timestamp.*\) topic=\[.*\] partition=\[.*\]'


  
  # Stop the Kafka and ksqlDB
  docker-compose -f docker-compose.yml down
  
  # Remove the large_stream_message.json and large_table_message.json
  rm $STREAM_FILE
  rm $TABLE_FILE
  
  # Stop the Kafka and ksqlDB
  docker-compose -f $COMPOSE_FILE down
}

# Set up environment variables for the Kafka and ksqlDB
KAFKA_BROKER='broker:9092'
KSQL_SERVER='ksqldb-server:8088'
STREAM_FILE=large_stream_message.json
TABLE_FILE=large_table_message.json
NUM_RECORDS=2
ARRAY_SIZE=100000

# Start the Kafka and ksqlDB
# Call the produce_records function with the normal setup
produce_records "docker-compose.yml"

# Call the produce_records function with the large messages setup
produce_records "docker-compose-large-messages.yml"