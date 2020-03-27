---
title: "gRPC"
publishDate: "2019-12-31"
categories: ["Traffic Management"]
---

[gRPC](https://grpc.io/) はサービス間通信のプロトコルで、[HTTP/2](https://www.cncf.io/blog/2018/08/31/grpc-on-http-2-engineering-a-robust-high-performance-protocol/) 上で動作します。[resources](https://en.wikipedia.org/wiki/Representational_state_transfer) ベースの HTTP/1 上で動作する REST と異なり、gRPC は [Service Definitions](https://grpc.io/docs/guides/concepts/) ベースです。データの通信や永続化のための小さなバイナリフォーマットへシリアライズすることができる [protocol buffers](https://developers.google.com/protocol-buffers/) ("proto") と呼ばれるフォーマットで service definitions を指定します。

gRPC では `.proto` ファイルから [multiple programming languages](https://grpc.io/docs/quickstart/) へのボイラープレートコードを生成することができます。このため、gRPC は 多言語での microservices のための理想的な選択となるでしょう。

gRPC は [TLS](https://grpc.io/docs/guides/auth/) や [client-side load balancing](https://grpc.io/blog/loadbalancing/) のようなユースケースをサポートしています。さらに gRPC のアーキテクチャに Istio を組み込むことはメトリクスの収集、トラフィックルールの追加、[RPC-level authorization](https://istio.io/blog/2018/istio-authorization/#rpc-level-authorization) といった利点があります。すべてのトラフィックタイプに同一の Istio API を使用できるため、トラフィックが HTTP, TCP, gRPC, そして データベースプロトコルの間で混在している場合でも、Istio は 便利な管理レイヤーを追加できます。

[Istio](https://istio.io/about/feature-stages/#traffic-management) とそのデータプレーンプロキシーである [Envoy](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/other_protocols/grpc#arch-overview-grpc) の両方が gRPC をサポートします。Istio を用いてどのように gRPC トラフィックを管理するか見てみましょう。

![grpc](/images/grpc.png)

このように、`client` と `server` の2つの gRPC サービスがあります。`client` は RPC コールを `server` の `/SayHello` 関数へ2秒ごとに行います。

Istio を gRPC Kubernetes サービスへ追加するためには要件があります。Kubernetes の Service ports の [labeling](https://istio.io/docs/setup/kubernetes/additional-setup/requirements/) です。server のポートは以下のようにラベル付けされます。

```YAML
apiVersion: v1
kind: Service
metadata:
  name: server
spec:
  selector:
    app: server
  type: ClusterIP
  ports:
  - name: grpc # important!
    protocol: TCP
    port: 8080
```

アプリケーションをデプロイすると、[service graph](https://www.kiali.io/) で client と server の間のトラフィックを見ることができます。

![kiali](/images/grpc-kiali.png)

server の gRPC トラフィックメトリクスを Grafana でも見ることができます。

![](/images/grpc-server-healthy.png)

また、10秒の delay [fault](https://istio.io/docs/tasks/traffic-management/fault-injection/) を `server` へ挿入するための Istio のトラフィックルールを適用できます。アプリケーションの回復性をテストするために、カオステストシナリオでこのルールを適用できるかもしれません。

```YAML
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: server-fault
spec:
  hosts:
  - server
  http:
  - fault:
      delay:
        percentage:
          value: 100.0
        fixedDelay: 10s
    route:
    - destination:
        host: server
        subset: v1
```

これは client RPC にタイムアウト(`Outgoing Request Duration`)を起こします。

![](/images/grpc-grafana-client-fault-inject.png)

gRPC と Istio についてさらに学ぶために:
- [Istio docs - Traffic Management](https://istio.io/docs/concepts/traffic-management/#traffic-routing-and-configuration)
- [Blog post - gRPC + Istio + Cloud Internal Load Balancer](https://cloud.google.com/solutions/using-istio-for-internal-load-balancing-of-grpc-services)
