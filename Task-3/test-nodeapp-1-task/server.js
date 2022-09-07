'use strict';

const express = require('express');

// Constants
const PORT = 8080;
const HOST = 'cp123-lb-253816681.us-east-1.elb.amazonaws.com';

// App
const app = express();
app.get('/app', (req, res) => {
  res.send('Hello World');
});

app.listen(PORT, () => {
  console.log('Running on http://${HOST}:${PORT}');
});
