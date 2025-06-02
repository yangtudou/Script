$httpClient.get('http://httpbin.org/get', (error, response, data) => {
  if (error) {
    console.log(error)
  } else {
    console.log(data)
  }
})
 
const yourProxyName = 'a fancy name with 😄'
 
$httpClient.post(
  {
    url: 'http://httpbin.org/post',
    headers: {
      'X-Header-Key': 'headerValue',
      'X-Stash-Selected-Proxy': encodeURIComponent(yourProxyName),
    },
    body: '{}', // can be object or string
    timeout: 5,
    insecure: false,
    'binary-mode': true,
    'auto-cookie': true,
    'auto-redirect': true,
  },
  (error, response, data) => {
    if (error) {
      console.log(error)
    } else {
      console.log(data)
    }
  }
)