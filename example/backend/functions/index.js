const path = require("path");
const os = require("os");
const fs = require("fs");
const functions = require("firebase-functions");
const Busboy = require("busboy");
const md5File = require('md5-file');
const crypto = require("crypto");

exports.upload = functions.https.onRequest(async (req, res) => {
  const uploads = [];
  const methods = ["POST", "PUT", "PATCH"];
  if (!methods.includes(req.method, 0)) {
    return res.status(405).json({
      errorMessage: "Method is not allowed"
    });
  }

  const simulate = req.query.simulate !== undefined ? req.query.simulate : 'ok200';

  const busboy = new Busboy({ headers: req.headers, highWaterMark: 2 * 1024 });

  busboy.on("file", (fieldname, file, filename, encoding, mimetype) => {
    console.log("File [" + fieldname + "]: filename: " + filename);

    let length = 0;
    let totalLength = 0; // Track total data length for this file

    file.on("data", data => {
      console.log("File [" + fieldname + "] got " + data.length + " bytes");
      length = data.length;
      totalLength += data.length; // Accumulate data length

    });
    file.on("end", () => {
      console.log(`File [${fieldname}] Finished. Total size: ${totalLength} bytes`);
    });

    const filepath = path.join(os.tmpdir(), filename);
    uploads.push({
      file: filepath,
      fieldname: fieldname,
      filename: filename,
      mimetype: mimetype,
      encoding: encoding,
      length: length,
    });
    console.log(`Saving '${fieldname}' to ${filepath}`);
    file.pipe(fs.createWriteStream(filepath));
  });

  const fields = {};

  busboy.on("field", (fieldname, val, fieldnameTruncated, valTruncated) => {
    console.log("Field [" + fieldname + "]: value: " + val);
    fields[fieldname] = val;
  });
  busboy.on("finish", () => {
    const statusCode = statusCodeForSimulation(simulate);

    if (statusCode === 201) {
      return res.status(statusCode).end();
    }

    let response = {
      uploads: uploads,
      fields: fields,
      headers: req.headers,
      method: req.method,
    };

    // Simple random data added to each request to test for issue https://github.com/BlueChilli/flutter_uploader/issues/53.
    if (simulate === 'ok200randomdata') {
      response.random = crypto.randomBytes(10240).toString('hex');
    }

    return res.status(statusCode).json({
      message: jsonMessageForSimulation(simulate),
      request: response
    }).end();
  });
  busboy.on("error", error => {
    res.status(500).json({
      errorMessage: error.toString(),
      error: error
    }).end();
  });
  busboy.end(req.rawBody);
  return req.pipe(busboy);
});

exports.uploadBinary = functions.https.onRequest(async (req, res) => {
  const methods = ["POST", "PUT", "PATCH"];
  if (!methods.includes(req.method, 0)) {
    return res.status(405).json({
      errorMessage: "Method is not allowed"
    });
  }

  const simulate = req.query.simulate !== undefined ? req.query.simulate : 'ok200';
  const filename = [...Array(10)].map(i => (~~(Math.random() * 36)).toString(36)).join('');
  const filepath = path.join(os.tmpdir(), filename);

  console.log(`File [${filename}]: filepath: ${filepath}, ${JSON.stringify(req.headers)}`);

  try {
    await writeToFile(filepath, req.rawBody);
  } catch (e) {
    console.error(e);
    return res.status(500).json({
      message: "Invalid request",
    }).end();
  }

  const md5hash = md5File.sync(filepath);
  const stats = fs.statSync(filepath);
  const fileSizeInBytes = stats.size;

  fs.unlinkSync(filepath);

  const statusCode = statusCodeForSimulation(simulate);

  if (statusCode === 201) {
    return res.status(statusCode).end();
  }

  return res.status(statusCode).json({
    message: "Successfully uploaded",
    length: fileSizeInBytes,
    md5: md5hash,
    headers: req.headers,
    method: req.method,
  }).end();
});



function statusCodeForSimulation(simulation) {
  switch (simulation) {
    case 'ok200':
    case 'ok200randomdata':
      return 200;
    case 'ok201':
      return 201;
    case 'error401':
      return 401;
    case 'error403':
      return 403;
    case 'error500':
      return 500;
    default:
      console.error('Unknown simulation, returning 500');
      return 500;
  }
}

function jsonMessageForSimulation(simulation) {
  switch (simulation) {
    case 'error401':
      return 401;
    case 'error403':
      return 403;
    case 'error500':
      return 500;
    default:
      return "Successfully uploaded"
  }
}

function writeToFile(filePath, rawBody) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(filePath);
    file.write(rawBody);
    file.end();
    file.on("finish", () => { resolve(); });
    file.on("error", reject);
  });
}
