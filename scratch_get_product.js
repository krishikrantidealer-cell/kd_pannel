const https = require('https');

https.get('https://api.krishikrantiorganics.com/api/products?limit=1', (res) => {
  let data = '';
  res.on('data', (chunk) => data += chunk);
  res.on('end', () => {
    try {
      const parsed = JSON.parse(data);
      console.log(JSON.stringify(parsed.products[0], null, 2));
    } catch (e) {
      console.log('Error parsing:', e);
    }
  });
});
