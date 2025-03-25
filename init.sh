#!/bin/bash

# Autor: Ardit Ameti
# Datum: 25.03.2025
# Version: 1.0

# Konfigurierbare Variablen
AWS_REGION="us-east-1"
SOURCE_BUCKET="my-source-csv-bucket-m346"
DEST_BUCKET="my-destination-json-bucket-m346"
FUNCTION_NAME="CsvToJsonLambda"
LAMBDA_ZIP="lambda-package.zip"
CSV_FILE="data.csv"

# Erstelle die S3-Buckets
echo "🚀 Erstelle S3-Buckets..."
aws s3 mb s3://$SOURCE_BUCKET --region $AWS_REGION || echo "⚠ Der Bucket $SOURCE_BUCKET existiert bereits."
aws s3 mb s3://$DEST_BUCKET --region $AWS_REGION || echo "⚠ Der Bucket $DEST_BUCKET existiert bereits."

# Erstelle eine einfache CSV-Testdatei
echo "Erzeuge eine einfache CSV-Datei..."
echo -e "name,age,city\nJohn,28,Boston\nJane,24,Chicago" > $CSV_FILE

# Überprüfen, ob node_modules existiert, und dann ZIP erstellen
echo "📦 Erstelle das Lambda Code-Paket..."
if [ -d "node_modules" ]; then
    zip -r $LAMBDA_ZIP handler.js node_modules
else
    zip -r $LAMBDA_ZIP handler.js
fi

# Überprüfe, ob die ZIP-Datei erstellt wurde
if [ ! -f "$LAMBDA_ZIP" ]; then
    echo "❌ Fehler: Die ZIP-Datei wurde nicht erstellt!"
    exit 1
else
    echo "✅ ZIP-Datei erstellt: $LAMBDA_ZIP"
fi

# Abrufen der AWS-Account-ID und der ARN der IAM-Rolle
ACCOUNTID=$(aws sts get-caller-identity --query "Account" --output text)
LABROLEARN="arn:aws:iam::$ACCOUNTID:role/LabRole"
echo "Verwende IAM-Rolle: $LABROLEARN"

# Prüfe, ob die Lambda-Funktion existiert und erstelle oder aktualisiere sie
echo "🚀 Erstelle oder aktualisiere die Lambda-Funktion..."

# Prüfe, ob die Lambda-Funktion bereits existiert
if aws lambda get-function --function-name $FUNCTION_NAME --region $AWS_REGION >/dev/null 2>&1; then
    # Wenn die Funktion existiert, update die Funktion mit der neuen ZIP-Datei
    aws lambda update-function-code --function-name $FUNCTION_NAME --zip-file fileb://$(pwd)/$LAMBDA_ZIP --region $AWS_REGION
else
    # Wenn die Funktion nicht existiert, erstelle sie
    aws lambda create-function --function-name $FUNCTION_NAME \
    --runtime nodejs18.x \
    --role $LABROLEARN \
    --handler handler.main \
    --zip-file fileb://$(pwd)/$LAMBDA_ZIP \
    --region $AWS_REGION
fi

# Hinzufügen eines S3-Triggers zur Lambda-Funktion
echo "🔑 Berechtigungen für den S3-Trigger hinzufügen..."
aws lambda add-permission --function-name $FUNCTION_NAME \
  --statement-id s3-invocation \
  --action "lambda:InvokeFunction" \
  --principal s3.amazonaws.com \
  --source-arn arn:aws:s3:::$SOURCE_BUCKET || echo "⚠ Berechtigung existiert bereits."

# S3-Trigger für Lambda konfigurieren
echo "🔄 Konfiguriere den S3-Trigger..."
aws s3api put-bucket-notification-configuration --bucket $SOURCE_BUCKET \
--notification-configuration "{
     \"LambdaFunctionConfigurations\": [
        {
            \"LambdaFunctionArn\": \"arn:aws:lambda:$AWS_REGION:$ACCOUNTID:function:$FUNCTION_NAME\",
            \"Events\": [\"s3:ObjectCreated:*\"] 
        }
    ]
}"

# Lade die CSV-Datei in den S3-Bucket hoch
echo "⬆ Lade CSV-Datei hoch..."
aws s3 cp $CSV_FILE s3://$SOURCE_BUCKET/

# Warte auf die erzeugte JSON-Datei
echo "⏳ Warte auf die JSON-Datei im Ziel-Bucket..."
attempts=0
while [ $attempts -lt 10 ]; do
    if aws s3 ls s3://$DEST_BUCKET/data.json >/dev/null 2>&1; then
        echo "✅ JSON-Datei erfolgreich erstellt!"
        break
    fi
    sleep 5
    ((attempts++))
done

# Wenn die Datei vorhanden ist, lade sie herunter und zeige den Inhalt an
if aws s3 ls s3://$DEST_BUCKET/data.json >/dev/null 2>&1; then
    echo "⬇ Lade die JSON-Datei herunter..."
    aws s3 cp s3://$DEST_BUCKET/data.json output.json
    echo "📜 Inhalt der JSON-Datei:"
    cat output.json
else
    echo "❌ Fehler: JSON-Datei nicht gefunden. Überprüfe die Lambda-Funktion."
fi

# Abschlussmeldung
echo "✅ Vorgang abgeschlossen!"
