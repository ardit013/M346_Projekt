const AWS = require('aws-sdk');
const s3 = new AWS.S3();
const csv = require('csv-parser');
const stream = require('stream');

exports.handler = async (event) => {
  const bucket = event.Records[0].s3.bucket.name;
  const key = decodeURIComponent(event.Records[0].s3.object.key.replace(/\+/g, ' '));

  const s3Stream = s3.getObject({ Bucket: bucket, Key: key }).createReadStream();
  
  const csvResults = [];
  const csvStream = s3Stream.pipe(csv());

  // CSV-Datei in JSON umwandeln
  csvStream.on('data', (data) => {
    csvResults.push(data);
  });

  await new Promise((resolve, reject) => {
    csvStream.on('end', resolve);
    csvStream.on('error', reject);
  });

  // JSON-Datei im Out-Bucket speichern
  const jsonKey = key.replace('.csv', '.json');
  const outBucket = 'csv-to-json-out-bucket';

  const params = {
    Bucket: outBucket,
    Key: jsonKey,
    Body: JSON.stringify(csvResults),
    ContentType: 'application/json'
  };

  try {
    await s3.putObject(params).promise();
    return { statusCode: 200, body: 'CSV erfolgreich in JSON umgewandelt und hochgeladen!' };
  } catch (error) {
    console.error('Fehler beim Hochladen zu S3', error);
    return { statusCode: 500, body: 'Fehler beim Verarbeiten der Datei.' };
  }
};
