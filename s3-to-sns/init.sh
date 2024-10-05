#!/bin/bash

# Definindo variáveis
BUCKET_NAME="meu-bucket"
SNS_TOPIC="meu-topico-sns"
SQS_QUEUE="minha-fila-sqs"
SNS_TOPIC_LAMBDA="topico-lambda"
AWS_PROFILE="localstack"
ENDPOINT_URL="http://localhost:4566"
SQS_LAMBDA_SENT="lambda-sent-queue"

# Criando um bucket S3
aws s3 mb s3://$BUCKET_NAME --endpoint-url=http://localhost:4566

# Criando um tópico SNS
SNS_TOPIC_ARN=$(aws sns create-topic --name $SNS_TOPIC --endpoint-url=$ENDPOINT_URL --query 'TopicArn' --output text)

# Criando uma fila SQS
SQS_QUEUE_URL=$(aws sqs create-queue --queue-name $SQS_QUEUE --endpoint-url=$ENDPOINT_URL --query 'QueueUrl' --output text)

# Obter o ARN da fila SQS
SQS_QUEUE_ARN=$(aws sqs get-queue-attributes --queue-url $SQS_QUEUE_URL --attribute-names QueueArn --endpoint-url=$ENDPOINT_URL --query 'Attributes.QueueArn' --output text)

# Adicionando permissão ao bucket S3 para enviar eventos à fila SQS via SNS
aws s3api put-bucket-notification-configuration --bucket $BUCKET_NAME --notification-configuration '{
  "QueueConfigurations": [
    {
      "QueueArn": "'"$SQS_QUEUE_ARN"'",
      "Events": ["s3:ObjectCreated:*"]
    }
  ]
}' --endpoint-url=http://localhost:4566

# Criando o tópico SNS para a Lambda (se necessário para outro propósito)
SNS_TOPIC_LAMBDA_ARN=$(aws sns create-topic --name $SNS_TOPIC_LAMBDA --endpoint-url=$ENDPOINT_URL --query 'TopicArn' --output text)

# Criando uma lambda SQS
SQS_LAMBDA_SENT_QUEUE_URL=$(aws --endpoint-url=$ENDPOINT_URL sqs create-queue --queue-name $SQS_LAMBDA_SENT --query 'QueueUrl' --output text)

# Obter o ARN da fila SQS
SQS_LAMBDA_SENT_QUEUE_ARN=$(aws --endpoint-url=$ENDPOINT_URL sqs get-queue-attributes --queue-url $SQS_LAMBDA_SENT_QUEUE_URL --attribute-names QueueArn --query 'Attributes.QueueArn' --output text)

# Inscrevendo a fila SQS no tópico SNS
aws --endpoint-url=$ENDPOINT_URL sns subscribe \
  --topic-arn $SNS_TOPIC_LAMBDA_ARN \
  --protocol sqs \
  --notification-endpoint $SQS_LAMBDA_SENT_QUEUE_ARN \
  --attributes "{\"RawMessageDelivery\":\"true\"}"

# Criando a função Lambda
LAMBDA_NAME="meu-lambda"

# Criação da função Lambda
aws lambda create-function --function-name $LAMBDA_NAME \
--zip-file fileb://s3-to-sns/function.zip --handler lambda --runtime go1.x \
--role arn:aws:iam::000000000000:role/lambda-role --endpoint-url=http://localhost:4566

# Configurando a trigger para invocar a Lambda a partir da fila SQS
aws lambda create-event-source-mapping \
--function-name $LAMBDA_NAME \
--batch-size 1 \
--event-source-arn $SQS_QUEUE_ARN \
--endpoint-url=http://localhost:4566

echo "Setup concluído!"
