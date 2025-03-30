#!/bin/bash

# Autor: Ardit Ameti, Choaib Bourahla
# Datum: 25.03.2025
# Version: 1.1

# Konfigurierbare Variablen
AWS_REGION="us-east-1"
SOURCE_BUCKET="my-source-csv-bucket-m346-aacb"
DEST_BUCKET="my-destination-json-bucket-m346-aacb"
FUNCTION_NAME="CsvToJsonLambda"
LAMBDA_ZIP="lambda-package.zip"
CSV_FILE="data.csv"

# Erstelle die S3-Buckets
echo "Erstelle S3-Buckets..."
aws s3 mb s3://$SOURCE_BUCKET --region $AWS_REGION || echo "Der Bucket $SOURCE_BUCKET existiert bereits."
aws s3 mb s3://$DEST_BUCKET --region $AWS_REGION || echo "Der Bucket $DEST_BUCKET existiert bereits."

# Erzeuge eine einfache CSV-Datei
echo "Erzeuge eine einfache CSV-Testdatei..."
echo -e "name,age,city\nJohn,28,Boston\nJane,24,Chicago" > $CSV_FILE

# Erstelle das Lambda Deployment-Paket
echo "Erstelle das Lambda Code-Paket..."
zip $LAMBDA_ZIP handler.js

# Prüfe, ob die ZIP-Datei erstellt wurde
if [ ! -f "$LAMBDA_ZIP" ]; then
    echo "Fehler: Die ZIP-Datei wurde nicht erstellt!"
    exit 1
else
    echo "ZIP-Datei erstellt: $LAMBDA_ZIP"
fi

# IAM-Rolle abrufen
ACCOUNTID=$(aws sts get-caller-identity --query "Account" --output text)
LABROLEARN="arn:aws:iam::$ACCOUNTID:role/LabRole"
echo "Verwende IAM-Rolle: $LABROLEARN"

# Lambda-Funktion erstellen oder aktualisieren
echo "Erstelle oder aktualisiere die Lambda-Funktion..."
if aws lambda get-function --function-name $FUNCTION_NAME --region $AWS_REGION >/dev/null 2>&1; then
    aws lambda update-function-code \
        --function-name $FUNCTION_NAME \
        --zip-file fileb://$(pwd)/$LAMBDA_ZIP \
        --region $AWS_REGION
else
    aws lambda create-function \
        --function-name $FUNCTION_NAME \
        --runtime nodejs18.x \
        --role $LABROLEARN \
        --handler handler.handler \
        --zip-file fileb://$(pwd)/$LAMBDA_ZIP \
        --region $AWS_REGION \
        --environment "Variables={OUT_BUCKET=$DEST_BUCKET}"
fi

# Warten, bis Lambda bereit ist
echo "Warte auf Aktivierung der Lambda-Funktion..."
while true; do
    STATE=$(aws lambda get-function-configuration \
        --function-name $FUNCTION_NAME \
        --query 'State' \
        --output text)

    if [ "$STATE" = "Active" ]; then
        echo "Lambda-Funktion ist jetzt aktiv."
        break
    fi

    echo "Aktueller Zustand: $STATE ... warte 5 Sekunden"
    sleep 5
done


# Berechtigungen für den S3-Trigger hinzufügen
echo "Füge Berechtigungen für den S3-Trigger hinzu..."
aws lambda add-permission \
    --function-name $FUNCTION_NAME \
    --statement-id s3-invocation \
    --action "lambda:InvokeFunction" \
    --principal s3.amazonaws.com \
    --source-arn arn:aws:s3:::$SOURCE_BUCKET || echo "Berechtigung existiert bereits."

# S3-Trigger konfigurieren
echo "Konfiguriere den S3-Trigger..."
aws s3api put-bucket-notification-configuration --bucket $SOURCE_BUCKET \
--notification-configuration "{
     \"LambdaFunctionConfigurations\": [
        {
            \"LambdaFunctionArn\": \"arn:aws:lambda:$AWS_REGION:$ACCOUNTID:function:$FUNCTION_NAME\",
            \"Events\": [\"s3:ObjectCreated:*\"] 
        }
    ]
}"

# Test: Lade CSV-Datei hoch
echo "Lade CSV-Datei hoch..."
aws s3 cp $CSV_FILE s3://$SOURCE_BUCKET/

# Warten auf JSON-Ergebnis
echo "Warte auf die JSON-Datei im Ziel-Bucket..."
attempts=0
while [ $attempts -lt 10 ]; do
    if aws s3 ls s3://$DEST_BUCKET/data.json >/dev/null 2>&1; then
        echo "JSON-Datei erfolgreich erstellt."
        break
    fi
    sleep 5
    ((attempts++))
done

# Ergebnis anzeigen
if aws s3 ls s3://$DEST_BUCKET/data.json >/dev/null 2>&1; then
    echo "Lade die JSON-Datei herunter..."
    aws s3 cp s3://$DEST_BUCKET/data.json output.json
    echo "Inhalt der JSON-Datei:"
    cat output.json
else
    echo "Fehler: JSON-Datei nicht gefunden. Überprüfe die Lambda-Funktion."
    exit 1
fi

echo "Vorgang abgeschlossen."
