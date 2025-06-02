$httpClient.get('http://httpbin.org/get', (error, response, data) => {
  if (error) {
    $done({
      title: '测试脚本',
      content: data,
      backgroundColor: '#663399',
      icon: 'network',
    })
  } else {
    $done({
      title: '测试脚本',
      content: data,
      backgroundColor: '#663399',
      icon: 'network',
    })
  }
})