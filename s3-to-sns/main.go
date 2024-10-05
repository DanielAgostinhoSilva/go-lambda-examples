package main

import (
	"context"
	"encoding/json"
	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/sns"
	"log"
)

type S3EventPayload struct {
	BucketName string `json:"bucketName"`
	BucketKey  string `json:"bucketKey"`
}

func handler(ctx context.Context, sqsEvent events.SQSEvent) error {
	log.Printf("Iniciando o handler")

	sess := session.Must(session.NewSession(&aws.Config{
		Region:   aws.String("us-east-1"),
		Endpoint: aws.String("http://localstack:4566"),
	}))

	svc := sns.New(sess)

	for _, message := range sqsEvent.Records {
		log.Printf("Processando mensagem SQS: %s", message.MessageId)

		var s3Event events.S3Event
		if err := json.Unmarshal([]byte(message.Body), &s3Event); err != nil {
			log.Printf("Erro ao desserializar evento S3: %v", err)
			return err
		}

		for _, record := range s3Event.Records {
			bucketName := record.S3.Bucket.Name
			bucketKey := record.S3.Object.Key

			log.Printf("Processando evento S3 - Bucket: %s, Key: %s", bucketName, bucketKey)

			payload := S3EventPayload{
				BucketName: bucketName,
				BucketKey:  bucketKey,
			}

			message, _ := json.Marshal(payload)
			_, err := svc.Publish(&sns.PublishInput{
				Message:  aws.String(string(message)),
				TopicArn: aws.String("arn:aws:sns:us-east-1:000000000000:topico-lambda"),
			})
			if err != nil {
				log.Printf("Erro ao publicar no SNS: %v", err)
				return err
			}

			log.Printf("Mensagem publicada com sucesso no SNS - Payload: %s", string(message))
		}
	}

	log.Printf("Handler finalizado com sucesso")
	return nil
}

func main() {
	lambda.Start(handler)
}
