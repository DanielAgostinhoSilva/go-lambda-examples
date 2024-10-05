STACK_NAME=go-lambda-examples
ENDPOINT_URL=http://localhost:4566

set-permission:
	chmod -R 777 aws \
	&& chmod -R 777 s3-to-sns

build-lambda-s3-to-sns:
	cd ./s3-to-sns \
	&& GOOS=linux GOARCH=amd64 go build -o lambda main.go \
	&& zip function.zip lambda

start:
	docker compose -p ${STACK_NAME} up -d

clean:
	docker compose -p ${STACK_NAME} down

s3-to-sns-lambda-setup:
	./s3-to-sns/init.sh

s3-put-file-to-s3ToSns-lambda:
	aws --endpoint-url=http://localhost:4566 \
	s3 cp ./s3-to-sns/test.txt s3://meu-bucket

read-lambda-sent-queue:
	aws --endpoint-url=http://localhost:4566 sqs receive-message \
	--queue-url http://localhost:4566/000000000000/lambda-sent-queue

log-s3ToSns-lambda:
	    aws --endpoint-url=http://localhost:4566 lambda invoke \
	    --function-name meu-lambda output.json