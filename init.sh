#!/bin/bash

# Region und Bucket-Namen
REGION="eu-central-1"
IN_BUCKET="csv-to-json-in-bucket"
OUT_BUCKET="csv-to-json-out-bucket"
LAMBDA_FUNCTION_NAME="CsvToJsonLambda"

# 1. Erstelle die S3-Buckets
echo "Erstelle In- und Out-Buckets..."
aws s3 mb s3://$IN_BUCKET --region $REGION
aws s3 mb s3://$OUT_BUCKET --region $REGION

# 2. Erstelle die ZIP-Datei für die Lambda-Funktion
echo "Erstelle die ZIP-Datei für die Lambda-Funktion..."
zip -r lambda_function.zip index.js node_modules

# 3. Bereitstellung der Lambda-Funktion
echo "Erstelle Lambda-Funktion..."
aws lambda create-function --function-name $LAMBDA_FUNCTION_NAME \
  --runtime nodejs14.x \
  --role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/lambda-role \
  --handler index.handler \
  --zip-file fileb://lambda_function.zip \
  --timeout 15 --memory-size 128 \
  --region $REGION

# 4. Setze den S3-Trigger für Lambda
echo "Setze S3-Trigger für Lambda..."
aws lambda add-permission --function-name $LAMBDA_FUNCTION_NAME \
  --principal s3.amazonaws.com \
  --statement-id $(uuidgen) \
  --action "lambda:InvokeFunction" \
  --resource arn:aws:lambda:$REGION:$(aws sts get-caller-identity --query Account --output text):function:$LAMBDA_FUNCTION_NAME \
  --region $REGION

aws s3api put-bucket-notification-configuration --bucket $IN_BUCKET \
  --notification-configuration '{
    "LambdaFunctionConfigurations": [
      {
        "LambdaFunctionArn": "arn:aws:lambda:'$REGION':'$(aws sts get-caller-identity --query Account --output text)':function:'$LAMBDA_FUNCTION_NAME'",
        "Events": ["s3:ObjectCreated:*"]
      }
    ]
  }' --region $REGION

echo "Die CSV-Datei wurde erfolgreich hochgeladen. Die Lambda-Funktion wird nun ausgeführt."
