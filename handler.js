const AWS = require('aws-sdk');
const s3 = new AWS.S3();

exports.handler = async (event) => {
    console.log('Lambda wurde gestartet.');

    try {
        console.log('lambda wurde ausgelöst mit Event:', JSON.stringify(event));

        const bucket = event.Records[0].s3.bucket.name;
        const key = decodeURIComponent(event.Records[0].s3.object.key.replace(/\+/g, ' '));
        const outBucket = process.env.OUT_BUCKET;

        if (!outBucket) {
            throw new Error("OUT_BUCKET umgebungsvariable nicht gesetzt.");
        }

        console.log(`Lese CSV-Datei: Bucket = ${bucket}, Key = ${key}`);
        const data = await s3.getObject({ Bucket: bucket, Key: key }).promise();
        const csvContent = data.Body.toString('utf-8');

        console.log('CSV-Inhalt geladen:\n' + csvContent);

        const lines = csvContent.trim().split('\n');
        const headers = lines[0].split(',');

        console.log('Header-Zeile erkannt:', headers);

        const jsonArray = lines.slice(1).map(line => {
            const values = line.split(',');
            const obj = {};
            headers.forEach((header, index) => {
                obj[header.trim()] = values[index]?.trim();
            });
            return obj;
        });

        console.log('Erzeugtes JSON:', JSON.stringify(jsonArray, null, 2));

        const jsonKey = 'data.json'; // fester dateiname

        console.log(`Speichere JSON in Bucket: ${outBucket}, Key: ${jsonKey}`);

        await s3.putObject({
            Bucket: outBucket,
            Key: jsonKey,
            Body: JSON.stringify(jsonArray, null, 2),
            ContentType: 'application/json'
        }).promise();

        console.log('Upload abgeschlossen.');

        return {
            statusCode: 200,
            body: `Erfolgreich konvertiert: ${outBucket}/${jsonKey}`
        };
    } catch (err) {
        console.error('Fehler bei der Verarbeitung:', err);
        return {
            statusCode: 500,
            body: 'Fehler bei der Verarbeitung.'
        };
    }
};
