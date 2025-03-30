# M346_Projekt

## Csv2Json AWS Lambda Service

Name: Ardit Ameti, Choaib Bourahla
Kurs: M346 – Cloud Computing
Datum: 2025-03-30

### Projektbeschreibung

Dieses Projekt stellt einen einfachen Serverless-Service bereit, der CSV-Dateien in JSON-Dateien umwandelt (automatisch über AWS S3 und AWS Lambda).

Sobald eine CSV-Datei in ein definiertes S3-Bucket hochgeladen wird, konvertiert eine Lambda-Funktion die Datei und speichert das Ergebnis als JSON in einem anderen Bucket.

#### Funktionen

- Automatischer CSV → JSON Konvertierungsservice
- Serverless mit AWS Lambda
- Trigger über S3 Upload
- Bereitstellung über ein Bash-Skript (`init.sh`)
- Logging über CloudWatch


## Ausführung:

### Schritt 1: 

chmod +x init.sh

### Schritt 2: 

./init.sh

### Cleanup: 

aws lambda delete-function --function-name CsvToJsonLambda

aws s3 rm s3://my-source-csv-bucket-m346-aacb --recursive
aws s3 rm s3://my-destination-json-bucket-m346-aacb --recursive

aws s3 rb s3://my-source-csv-bucket-m346-aacb
aws s3 rb s3://my-destination-json-bucket-m346-aacb

rm -f lambda-package.zip output.json data.csv notification.json

