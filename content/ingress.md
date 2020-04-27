---
title: Ingress
publishDate: "2019-12-31"
categories: ["Traffic Management"]
---

Ingress トラフィックはクラスター外からメッシュへ入ってくるトラフィックのことを指します。 Kubernetes は Ingress トラフィックを扱う方法を [LoadBalancer タイプ](https://kubernetes.io/ja/docs/concepts/services-networking/service/#loadbalancer) や [Ingress](https://kubernetes.io/ja/docs/concepts/services-networking/ingress/) 
で提供しています。
Istio では、代わりに **Gateway** で Ingress トラフィック を管理することができます。

[Gateway](https://istio.io/docs/reference/config/networking/v1alpha3/gateway/) はクラスターへ到着するトラフィックのロードバランシングを担う Envoy プロキシです。Istio はパブリックIPを持ったデフォルトの `IngressGateway` をデプロイします。これを使用することで、サービスメッシュ内のアプリケーションをインターネットに公開することができます。

Istio の Gateway は Kubernetes の Igress に比べて２つの点で優れています。 Gateway は Envoy プロキシです。そのため Istio を使用することで、 East-West トラフィック(トラフィックスプリットやリダイレクト、リトライなど) を扱うのと同じ方法で Gateway トラフィックを設定することができます。

また Gateways は、[サイドカー](https://istio.io/docs/concepts/what-is-istio/#envoy) と同じようにリクエストレートやエラーレートなどのメトリクスを転送します。これにより[サービスグラフ](https://istio.io/docs/tasks/telemetry/kiali/#generating-a-service-graph)でIngress トラフィックを見ることや、クライアントに直接配信しているフロントエンドサービスの細かい[SLOs](https://landing.google.com/sre/sre-book/chapters/service-level-objectives/)を設定することができます。

では実際に Gateways を見てみましょう。


![ingress](/images/ingress.png)

ここでは `hello` アプリケーションが Pod 内のコンテナとして動いています。Pod には Istio のサイドカープロキシが挿入されています。`hello` という Kubernetes のサービスがこの Pod に向けられています。`hello.com` から入ってくるトラフィックをこの `hello` サービスに向けたいと思います。

まず Istio デフォルトの `IngressGateway` 内に `hello.com` ドメインから名前解決された ポート `80` を開放する `Gateway` リソースが必要です。

```YAML
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: hello-gateway
spec:
  selector:
    istio: ingressgateway # デフォルトの IngressGateway を使用します
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "hello.com"
```

(**注意**: `IngressGateway` の外部IPアドレスに対しては自身でDNSの名前解決をする必要があります。

次に `IngressGateway` から `default` の Namespace にポート `80` で動いている `hello` のバックエンドサービスにトラフィックを向ける [`VirtualService`](https://istio.io/docs/tasks/traffic-management/ingress/ingress-control/) を用意します。

```YAML
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: frontend-ingress
spec:
  hosts:
  - "hello.com"
  gateways:
  - hello-gateway
  http:
  - route:
    - destination:
        host: hello.default.svc.cluster.local
        port:
          number: 80
```
