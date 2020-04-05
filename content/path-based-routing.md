---
title: "Pathに基づいたルーティング"
publishDate: "2019-12-31"
categories: ["Traffic Management"]
---

Istioと[Envoy](https://istio.io/docs/concepts/what-is-istio/#envoy)はアプリケーショントラフィックレイヤー（L7）で動作し、HTTPヘッダーなどの属性に基づいてトラフィックの転送および負荷分散できます。この例は、[リクエストURIパスに基づいた](https://istio.io/docs/concepts/traffic-management/#match-request-uri)トラフィックを転送する方法となります。

この例において、`myapp` はWebサイトのサーバーバックエンドであり、`frontend` によって使用されます。エンジニアリングチームは、新しいユーザー認証サービス `auth` を実装しました。authは現在、別のサービスとして動作しています。

Istio [match rule](https://istio.io/docs/reference/config/networking/virtual-service/#HTTPMatchRequest) を使用して、`/login` プレフィックスを含むすべてのリクエストを新しい `auth` サービスにリダイレクトし、他のすべての `myapp` リクエストを既存のバックエンドに転送します。

![URI Match with Istio](/images/path-based-urimatch.png)

```YAML
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: auth-redirect
spec:
  hosts:
  - myapp
  http:
  - match:
    - uri:
        prefix: "/login"
    route:
    - destination:
        host: auth
  - route:
    - destination:
        host: myapp
```
