# 测试固件（fixtures）

这些文件不是手工编辑的产物，**改一次就要整组重生成**，否则证书与私钥不匹配、
或 CN/SAN 与测试里用的域名对不上，`hosts_network_test.dart` 的真实 TLS 握手会以
一句很难读的握手失败报错。

## mapped_test.crt / mapped_test.key

`hosts_network_test.dart` 起一个本地 HTTPS 服务器，用它们证明「hosts 映射作用在
连接层」：请求 URL 里的域名是 `mapped.test`，而 TCP 连接实际打到映射后的 IP。
证书的 `CN` 与 `subjectAltName` 必须是 `mapped.test`，与 [openssl.cnf](openssl.cnf) 一致。

重新生成（在 `test/fixtures/` 目录内执行）：

```bash
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -config openssl.cnf \
  -keyout mapped_test.key -out mapped_test.crt
```

生成后跑一次 `flutter test test/hosts_network_test.dart` 确认握手仍然通过。

> 有效期 3650 天是刻意的：这类固件会长期躺在仓库里，短有效期会让 CI 在某天
> 毫无改动地变红。
