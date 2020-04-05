---
title: レスポンスヘッダーの変更
publishDate: "2019-12-31"
categories: ["Traffic Management"]
---

Istioでは、[HTTPリクエストヘッダー](https://istio.io/docs/tasks/traffic-management/request-routing/#route-based-on-user-identity)に基づいてルーティングするトラフィックルールを適用できます。 Istioを使用して[レスポンスヘッダーを変更](https://istio.io/docs/reference/config/networking/virtual-service/#Headers)することもできます。これは、アプリケーションで生成されたヘッダーを削除する場合、またはアプリケーションコードを変更せずにレスポンスヘッダーを追加する場合に便利です。

![](/images/modify-response-headers.png)

この例では、Istioの[VirtualService](https://istio.io/docs/concepts/traffic-management/#virtual-services)を適用して新しいヘッダー（`hello:world`）を追加して、`set-cookie` ヘッダーを削除します。次に、`デフォルト` ゲートウェイを介してサービスメッシュに入るすべてのクライアントリクエストは、変更されたヘッダーを受信します。

```YAML
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: frontend-ingress
spec:
  hosts:
  - "*"
  gateways:
  - frontend-gateway
  http:
  - route:
    - destination:
        host: frontend
        port:
          number: 80
      headers:
        response:
          add:
            hello: world
          remove:
          - "set-cookie"
```

VirtualServiceを適用する前に、`frontend` サービスは次の応答ヘッダーを返します。:

```
HTTP/1.1 200 OK
set-cookie: shop_session-id=432bef95-0d25-4754-80c8-3904c2e329e9; Max-Age=172800
date: Wed, 18 Sep 2019 16:26:01 GMT
content-type: text/html; charset=utf-8
x-envoy-upstream-service-time: 45
server: istio-envoy
transfer-encoding: chunked
```

次に、`kubectl apply` コマンドでVirtualServiceを実行すると、レスポンスヘッダーを変更するようにEnvoyが正常に構成されていることがわかります。:

```
HTTP/1.1 200 OK
date: Wed, 18 Sep 2019 16:26:24 GMT
content-type: text/html; charset=utf-8
x-envoy-upstream-service-time: 85
hello: world
server: istio-envoy
transfer-encoding: chunked
```