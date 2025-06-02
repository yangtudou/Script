$httpClient.get('http://httpbin.org/get', (error, response, data) => {
  if (error) {
    console.log(error)
  } else {
    $done({
      title: '测试脚本',
      content: data,
      backgroundColor: '#663399',
      icon: 'network',
    })
  }
})